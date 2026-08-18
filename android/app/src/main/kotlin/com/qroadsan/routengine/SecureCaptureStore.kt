package com.qroadsan.routengine

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

class SecureCaptureStore(context: Context) :
    SQLiteOpenHelper(context, "route_engine_capture_vault.db", null, 1) {

    private val crypto = CryptoBox()

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE captures (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              created_at INTEGER NOT NULL,
              kind TEXT NOT NULL,
              fingerprint_hash TEXT NOT NULL,
              payload_iv BLOB NOT NULL,
              payload_ct BLOB NOT NULL,
              screenshot_iv BLOB,
              screenshot_ct BLOB,
              screenshot_mime TEXT,
              screenshot_width INTEGER,
              screenshot_height INTEGER,
              decision_iv BLOB,
              decision_ct BLOB
            )
            """.trimIndent(),
        )
        db.execSQL(
            "CREATE INDEX idx_captures_created_at ON captures(created_at DESC)",
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    fun insertCapture(
        kind: String,
        fingerprint: String,
        payloadJson: String,
        screenshot: ByteArray?,
        width: Int?,
        height: Int?,
    ): Long {
        val createdAt = System.currentTimeMillis()
        val fingerprintHash = sha256(fingerprint)
        val payloadAad = aad(createdAt, kind, fingerprintHash, "payload")
        val payload = crypto.seal(payloadJson.toByteArray(Charsets.UTF_8), payloadAad)

        val values = ContentValues().apply {
            put("created_at", createdAt)
            put("kind", kind)
            put("fingerprint_hash", fingerprintHash)
            put("payload_iv", payload.iv)
            put("payload_ct", payload.ciphertext)
            put("screenshot_mime", if (screenshot == null) null else "image/png")
            put("screenshot_width", width)
            put("screenshot_height", height)
        }

        if (screenshot != null) {
            val sealedScreenshot =
                crypto.seal(screenshot, aad(createdAt, kind, fingerprintHash, "screenshot"))
            values.put("screenshot_iv", sealedScreenshot.iv)
            values.put("screenshot_ct", sealedScreenshot.ciphertext)
        }

        val id = writableDatabase.insertOrThrow("captures", null, values)
        prune(120)
        return id
    }

    fun updateDecision(id: Long, decisionJson: String) {
        readableDatabase.rawQuery(
            "SELECT created_at, kind, fingerprint_hash FROM captures WHERE id=?",
            arrayOf(id.toString()),
        ).use { cursor ->
            if (!cursor.moveToFirst()) return
            val createdAt = cursor.getLong(0)
            val kind = cursor.getString(1)
            val fingerprintHash = cursor.getString(2)
            val sealed = crypto.seal(
                decisionJson.toByteArray(Charsets.UTF_8),
                aad(createdAt, kind, fingerprintHash, "decision"),
            )
            writableDatabase.update(
                "captures",
                ContentValues().apply {
                    put("decision_iv", sealed.iv)
                    put("decision_ct", sealed.ciphertext)
                },
                "id=?",
                arrayOf(id.toString()),
            )
        }
    }

    fun list(limit: Int): List<Map<String, Any?>> {
        val bounded = limit.coerceIn(1, 200)
        val result = mutableListOf<Map<String, Any?>>()
        readableDatabase.rawQuery(
            """
            SELECT id, created_at, kind, fingerprint_hash,
                   payload_iv, payload_ct,
                   screenshot_ct,
                   decision_iv, decision_ct
            FROM captures
            ORDER BY created_at DESC
            LIMIT ?
            """.trimIndent(),
            arrayOf(bounded.toString()),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                val createdAt = cursor.getLong(1)
                val kind = cursor.getString(2)
                val fingerprintHash = cursor.getString(3)
                val payload = decryptJson(
                    cursor.getBlob(4),
                    cursor.getBlob(5),
                    aad(createdAt, kind, fingerprintHash, "payload"),
                )
                val decision = if (cursor.isNull(7) || cursor.isNull(8)) {
                    null
                } else {
                    decryptJson(
                        cursor.getBlob(7),
                        cursor.getBlob(8),
                        aad(createdAt, kind, fingerprintHash, "decision"),
                    )
                }
                result += mapOf(
                    "id" to id,
                    "createdAt" to createdAt,
                    "kind" to kind,
                    "hasScreenshot" to !cursor.isNull(6),
                    "payload" to jsonObjectToMap(payload),
                    "decision" to decision?.let(::jsonObjectToMap),
                )
            }
        }
        return result
    }

    fun load(id: Long): Map<String, Any?>? {
        readableDatabase.rawQuery(
            """
            SELECT created_at, kind, fingerprint_hash,
                   payload_iv, payload_ct,
                   screenshot_iv, screenshot_ct,
                   decision_iv, decision_ct
            FROM captures WHERE id=?
            """.trimIndent(),
            arrayOf(id.toString()),
        ).use { cursor ->
            if (!cursor.moveToFirst()) return null
            val createdAt = cursor.getLong(0)
            val kind = cursor.getString(1)
            val fingerprintHash = cursor.getString(2)
            val payload = decryptJson(
                cursor.getBlob(3),
                cursor.getBlob(4),
                aad(createdAt, kind, fingerprintHash, "payload"),
            )
            val screenshot = if (cursor.isNull(5) || cursor.isNull(6)) {
                null
            } else {
                crypto.open(
                    cursor.getBlob(5),
                    cursor.getBlob(6),
                    aad(createdAt, kind, fingerprintHash, "screenshot"),
                )
            }
            val decision = if (cursor.isNull(7) || cursor.isNull(8)) {
                null
            } else {
                decryptJson(
                    cursor.getBlob(7),
                    cursor.getBlob(8),
                    aad(createdAt, kind, fingerprintHash, "decision"),
                )
            }
            return mapOf(
                "id" to id,
                "createdAt" to createdAt,
                "kind" to kind,
                "hasScreenshot" to (screenshot != null),
                "payload" to jsonObjectToMap(payload),
                "decision" to decision?.let(::jsonObjectToMap),
                "screenshot" to screenshot,
            )
        }
    }

    fun clearAll() {
        writableDatabase.delete("captures", null, null)
    }

    private fun prune(maxRecords: Int) {
        writableDatabase.execSQL(
            """
            DELETE FROM captures
            WHERE id NOT IN (
              SELECT id FROM captures
              ORDER BY created_at DESC
              LIMIT $maxRecords
            )
            """.trimIndent(),
        )
    }

    private fun decryptJson(iv: ByteArray, ct: ByteArray, aad: ByteArray): JSONObject {
        val bytes = crypto.open(iv, ct, aad)
        return JSONObject(bytes.toString(Charsets.UTF_8))
    }

    private fun aad(
        createdAt: Long,
        kind: String,
        fingerprintHash: String,
        slot: String,
    ): ByteArray =
        "$createdAt|$kind|$fingerprintHash|$slot".toByteArray(Charsets.UTF_8)

    private fun sha256(value: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

    private fun jsonObjectToMap(obj: JSONObject): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        obj.keys().forEach { key ->
            result[key] = jsonValue(obj.opt(key))
        }
        return result
    }

    private fun jsonValue(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> (0 until value.length()).map { jsonValue(value.opt(it)) }
        else -> value
    }
}
