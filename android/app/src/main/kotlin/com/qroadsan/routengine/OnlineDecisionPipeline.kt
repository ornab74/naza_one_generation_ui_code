package com.qroadsan.routengine

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.speech.tts.TextToSpeech
import android.util.Base64
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.ByteArrayOutputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.tan

class OnlineDecisionPipeline(
    private val context: Context,
    private val store: SecureCaptureStore,
    private val overlay: OverlayController,
) {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    @Volatile private var tts: TextToSpeech? = null

    init {
        tts = TextToSpeech(context.applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.US
                tts?.setSpeechRate(1.0f)
            }
        }
    }

    fun analyze(
        recordId: Long,
        kind: String,
        payload: JSONObject,
        screenshot: ByteArray?,
    ) {
        executor.execute {
            try {
                val settings = NativeSettings(context).snapshot()
                if (settings.relayUrl.isBlank()) {
                    overlay.update("CAPTURED", "RELAY --", Color.rgb(255, 207, 92))
                    NativeEventBus.emit(
                        mapOf(
                            "recordId" to recordId,
                            "kind" to kind,
                            "status" to "Capture stored; configure Luna relay",
                        ),
                    )
                    return@execute
                }

                val location = bestLastKnownLocation()
                val weather = location?.let { fetchWeather(it) }
                val radar = if (settings.radarEnabled && location != null) {
                    fetchRadar(location)
                } else {
                    null
                }

                val request = JSONObject()
                    .put("model", "gpt-5.6-luna")
                    .put("mode", "motorcycle_delivery_foresight")
                    .put("capture", JSONObject()
                        .put("record_id", recordId)
                        .put("kind", kind)
                        .put("accessibility", payload)
                        .put(
                            "screenshot",
                            screenshot?.let {
                                JSONObject()
                                    .put("mime_type", "image/png")
                                    .put("base64", Base64.encodeToString(it, Base64.NO_WRAP))
                            } ?: JSONObject.NULL,
                        ),
                    )
                    .put(
                        "location",
                        location?.let {
                            JSONObject()
                                .put("latitude", it.latitude)
                                .put("longitude", it.longitude)
                                .put("accuracy_m", it.accuracy)
                        } ?: JSONObject.NULL,
                    )
                    .put("weather", weather ?: JSONObject.NULL)
                    .put(
                        "radar",
                        radar?.let {
                            JSONObject()
                                .put("mime_type", "image/png")
                                .put("captured_at", it.first)
                                .put("base64", Base64.encodeToString(it.second, Base64.NO_WRAP))
                        } ?: JSONObject.NULL,
                    )
                    .put("rules", settings.rulesJson())

                val decision = postRelay(settings, request)
                store.updateDecision(recordId, decision.toString())

                val verdict = decision.optString("verdict", "BORDERLINE").uppercase(Locale.US)
                val weatherGate = decision.optString("weather_gate", "UNKNOWN").uppercase(Locale.US)
                val confidence = decision.optDouble("confidence", 0.0)
                val color = when {
                    weatherGate == "NO_GO" -> Color.rgb(255, 90, 114)
                    verdict == "TAKE" || verdict == "STRONG_TAKE" -> Color.rgb(102, 255, 178)
                    verdict == "SKIP" || verdict == "HARD_SKIP" -> Color.rgb(255, 90, 114)
                    else -> Color.rgb(255, 207, 92)
                }
                overlay.update(verdict, "WX $weatherGate", color)

                if (settings.speakDecisions) {
                    val spoken = decision.optString(
                        "spoken_summary",
                        "$verdict. Weather $weatherGate.",
                    )
                    speak(spoken)
                }

                NativeEventBus.emit(
                    mapOf(
                        "recordId" to recordId,
                        "kind" to kind,
                        "status" to "Luna decision complete",
                        "decision" to jsonObjectToMap(decision),
                    ),
                )

                if (
                    settings.autoNavigate &&
                    (verdict == "TAKE" || verdict == "STRONG_TAKE") &&
                    weatherGate == "GO" &&
                    confidence.isFinite() && confidence >= 0.75
                ) {
                    val query = decision.optString("navigation_query", "")
                        .replace(Regex("[\\u0000-\\u001F\\u007F]"), " ")
                        .trim()
                        .take(240)
                    if (query.isNotBlank()) {
                        openGoogleNavigation(query)
                    }
                }
            } catch (t: Throwable) {
                overlay.update("ERROR", "WX --", Color.rgb(255, 90, 114))
                NativeEventBus.emit(
                    mapOf(
                        "recordId" to recordId,
                        "kind" to kind,
                        "status" to "Background analysis failed",
                        "error" to (t.message ?: t.javaClass.simpleName),
                    ),
                )
            }
        }
    }

    private fun bestLastKnownLocation(): Location? {
        val fine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) return null

        val manager = context.getSystemService(LocationManager::class.java)
        val candidates = mutableListOf<Location>()
        for (provider in manager.getProviders(true)) {
            try {
                manager.getLastKnownLocation(provider)?.let(candidates::add)
            } catch (_: SecurityException) {
            }
        }
        return candidates.maxByOrNull { it.time }
    }

    private fun fetchWeather(location: Location): JSONObject {
        val lat = "%.5f".format(Locale.US, location.latitude)
        val lon = "%.5f".format(Locale.US, location.longitude)
        val variables = listOf(
            "temperature_2m",
            "apparent_temperature",
            "precipitation",
            "rain",
            "showers",
            "weather_code",
            "cloud_cover",
            "wind_speed_10m",
            "wind_gusts_10m",
            "visibility",
        ).joinToString(",")
        val url =
            "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon" +
                "&current=$variables&timezone=auto&wind_speed_unit=kmh"
        val json = JSONObject(getText(url))
        return json.optJSONObject("current") ?: JSONObject()
    }

    private fun fetchRadar(location: Location): Pair<Long, ByteArray>? {
        val meta = JSONObject(getText("https://api.rainviewer.com/public/weather-maps.json"))
        val frames = meta.optJSONObject("radar")?.optJSONArray("past") ?: return null
        if (frames.length() == 0) return null
        val frame = frames.optJSONObject(frames.length() - 1) ?: return null
        val path = frame.optString("path")
        val timestamp = frame.optLong("time")
        if (!Regex("^/v2/radar/[A-Za-z0-9_-]+$").matches(path) || timestamp <= 0L) return null
        val tile = latLonToTile(location.latitude, location.longitude, 7)
        val radarUrl = "https://tilecache.rainviewer.com$path/256/7/${tile.first}/${tile.second}/2/1_1.png"
        return timestamp to getBytes(radarUrl)
    }

    private fun latLonToTile(latitude: Double, longitude: Double, zoom: Int): Pair<Int, Int> {
        val n = 2.0.pow(zoom)
        val safeLat = latitude.coerceIn(-85.05112878, 85.05112878)
        val x = floor((longitude + 180.0) / 360.0 * n).toInt().coerceIn(0, n.toInt() - 1)
        val latRad = safeLat * PI / 180.0
        val y = floor((1.0 - ln(tan(latRad) + 1.0 / cos(latRad)) / PI) / 2.0 * n)
            .toInt().coerceIn(0, n.toInt() - 1)
        return x to y
    }

    private fun postRelay(
        settings: NativeSettings.Snapshot,
        payload: JSONObject,
    ): JSONObject {
        val base = settings.relayUrl.trimEnd('/')
        require(base.startsWith("https://") || isDebugLocalHttp(base)) {
            "Relay must use HTTPS. Debug loopback HTTP is allowed for local testing."
        }
        val connection = URL("$base/v1/route-engine/analyze").openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = false
        connection.requestMethod = "POST"
        connection.connectTimeout = 15_000
        connection.readTimeout = 70_000
        connection.doOutput = true
        connection.setRequestProperty("Content-Type", "application/json")
        connection.setRequestProperty("Accept", "application/json")
        if (settings.relayToken.isNotBlank()) {
            connection.setRequestProperty("Authorization", "Bearer ${settings.relayToken}")
        }
        connection.outputStream.use { out ->
            out.write(payload.toString().toByteArray(Charsets.UTF_8))
        }
        val code = connection.responseCode
        val source = if (code in 200..299) connection.inputStream else connection.errorStream
        val body = readTextLimited(source, 1_000_000)
        if (code !in 200..299) {
            error("Relay HTTP $code: ${body.take(240)}")
        }
        return JSONObject(body)
    }

    private fun isDebugLocalHttp(base: String): Boolean {
        if (!BuildConfig.DEBUG) return false
        return try {
            val uri = Uri.parse(base)
            uri.scheme == "http" && uri.userInfo == null && uri.fragment == null &&
                uri.host in setOf("127.0.0.1", "::1", "localhost", "10.0.2.2")
        } catch (_: Throwable) {
            false
        }
    }

    private fun getText(url: String): String {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = false
        connection.connectTimeout = 12_000
        connection.readTimeout = 15_000
        connection.setRequestProperty("Accept", "application/json")
        val code = connection.responseCode
        if (code !in 200..299) error("HTTP $code from ${URL(url).host}")
        return readTextLimited(connection.inputStream, 1_000_000)
    }

    private fun getBytes(url: String): ByteArray {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = false
        connection.connectTimeout = 12_000
        connection.readTimeout = 15_000
        val code = connection.responseCode
        if (code !in 200..299) error("HTTP $code from ${URL(url).host}")
        val output = ByteArrayOutputStream()
        connection.inputStream.use { input ->
            val buffer = ByteArray(16 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                output.write(buffer, 0, read)
                if (output.size() > 2_500_000) error("Radar image exceeded 2.5 MB")
            }
        }
        return output.toByteArray()
    }

    private fun readTextLimited(input: java.io.InputStream, maxBytes: Int): String {
        val output = ByteArrayOutputStream()
        input.use { source ->
            val buffer = ByteArray(16 * 1024)
            while (true) {
                val read = source.read(buffer)
                if (read <= 0) break
                output.write(buffer, 0, read)
                if (output.size() > maxBytes) error("Response exceeded safety limit")
            }
        }
        return output.toString(Charsets.UTF_8.name())
    }

    private fun speak(text: String) {
        if (text.isBlank()) return
        tts?.speak(text.take(360), TextToSpeech.QUEUE_FLUSH, null, "route-engine-decision")
    }

    private fun openGoogleNavigation(query: String) {
        val nav = Uri.parse("google.navigation:q=${Uri.encode(query)}&mode=d")
        val intent = Intent(Intent.ACTION_VIEW, nav).apply {
            setPackage("com.google.android.apps.maps")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (_: Throwable) {
            val fallback = Intent(
                Intent.ACTION_VIEW,
                Uri.parse(
                    "https://www.google.com/maps/dir/?api=1&destination=${Uri.encode(query)}",
                ),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(fallback)
        }
    }

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

    fun shutdown() {
        executor.shutdownNow()
        tts?.shutdown()
    }
}
