package com.qroadsan.routengine

import android.content.Context
import android.util.Base64
import org.json.JSONObject

class NativeSettings(context: Context) {
    private val prefs =
        context.getSharedPreferences("route_engine_native_settings_v2", Context.MODE_PRIVATE)
    private val crypto = CryptoBox()

    data class Snapshot(
        val relayUrl: String,
        val relayToken: String,
        val monitorEnabled: Boolean,
        val radarEnabled: Boolean,
        val speakDecisions: Boolean,
        val autoNavigate: Boolean,
        val overlayEnabled: Boolean,
        val minimumPayout: Double,
        val minimumDollarsPerMile: Double,
        val targetHourly: Double,
        val maxWindGustKph: Double,
        val maxPrecipitationMm: Double,
        val minVisibilityKm: Double,
        val maxRadarSeverity: Double,
        val autoTakeThreshold: Double,
        val autoSkipThreshold: Double,
    ) {
        fun toMap(includeToken: Boolean = false): Map<String, Any?> = mapOf(
            "relayUrl" to relayUrl,
            "relayToken" to if (includeToken) relayToken else "",
            "monitorEnabled" to monitorEnabled,
            "radarEnabled" to radarEnabled,
            "speakDecisions" to speakDecisions,
            "autoNavigate" to autoNavigate,
            "overlayEnabled" to overlayEnabled,
            "minimumPayout" to minimumPayout,
            "minimumDollarsPerMile" to minimumDollarsPerMile,
            "targetHourly" to targetHourly,
            "maxWindGustKph" to maxWindGustKph,
            "maxPrecipitationMm" to maxPrecipitationMm,
            "minVisibilityKm" to minVisibilityKm,
            "maxRadarSeverity" to maxRadarSeverity,
            "autoTakeThreshold" to autoTakeThreshold,
            "autoSkipThreshold" to autoSkipThreshold,
        )

        fun rulesJson(): JSONObject = JSONObject()
            .put("minimum_payout", minimumPayout)
            .put("minimum_dollars_per_mile", minimumDollarsPerMile)
            .put("target_hourly", targetHourly)
            .put(
                "motorcycle_weather_limits",
                JSONObject()
                    .put("max_wind_gust_kph", maxWindGustKph)
                    .put("max_precipitation_mm", maxPrecipitationMm)
                    .put("min_visibility_km", minVisibilityKm)
                    .put("max_radar_severity", maxRadarSeverity),
            )
    }

    fun snapshot(): Snapshot = Snapshot(
        relayUrl = prefs.getString("relayUrl", "") ?: "",
        relayToken = readSecret("relayToken"),
        monitorEnabled = prefs.getBoolean("monitorEnabled", true),
        radarEnabled = prefs.getBoolean("radarEnabled", true),
        speakDecisions = prefs.getBoolean("speakDecisions", true),
        autoNavigate = prefs.getBoolean("autoNavigate", true),
        overlayEnabled = prefs.getBoolean("overlayEnabled", true),
        minimumPayout = prefs.getFloat("minimumPayout", 8f).toDouble(),
        minimumDollarsPerMile =
            prefs.getFloat("minimumDollarsPerMile", 1.75f).toDouble(),
        targetHourly = prefs.getFloat("targetHourly", 22f).toDouble(),
        maxWindGustKph = prefs.getFloat("maxWindGustKph", 55f).toDouble(),
        maxPrecipitationMm =
            prefs.getFloat("maxPrecipitationMm", 2.5f).toDouble(),
        minVisibilityKm = prefs.getFloat("minVisibilityKm", 4f).toDouble(),
        maxRadarSeverity = prefs.getFloat("maxRadarSeverity", 0.65f).toDouble(),
        autoTakeThreshold = prefs.getFloat("autoTakeThreshold", 0.82f).toDouble(),
        autoSkipThreshold = prefs.getFloat("autoSkipThreshold", 0.30f).toDouble(),
    )

    fun update(args: Map<String, Any?>) {
        val editor = prefs.edit()
        args["relayUrl"]?.toString()?.let { editor.putString("relayUrl", it.trim()) }
        args["monitorEnabled"]?.let { editor.putBoolean("monitorEnabled", it as Boolean) }
        args["radarEnabled"]?.let { editor.putBoolean("radarEnabled", it as Boolean) }
        args["speakDecisions"]?.let { editor.putBoolean("speakDecisions", it as Boolean) }
        args["autoNavigate"]?.let { editor.putBoolean("autoNavigate", it as Boolean) }
        args["overlayEnabled"]?.let { editor.putBoolean("overlayEnabled", it as Boolean) }
        putFloat(editor, args, "minimumPayout")
        putFloat(editor, args, "minimumDollarsPerMile")
        putFloat(editor, args, "targetHourly")
        putFloat(editor, args, "maxWindGustKph")
        putFloat(editor, args, "maxPrecipitationMm")
        putFloat(editor, args, "minVisibilityKm")
        putFloat(editor, args, "maxRadarSeverity")
        putFloat(editor, args, "autoTakeThreshold")
        putFloat(editor, args, "autoSkipThreshold")
        editor.apply()

        if (args.containsKey("relayToken")) {
            writeSecret("relayToken", args["relayToken"]?.toString() ?: "")
        }
    }

    private fun putFloat(
        editor: android.content.SharedPreferences.Editor,
        args: Map<String, Any?>,
        key: String,
    ) {
        val value = args[key] as? Number ?: return
        editor.putFloat(key, value.toFloat())
    }

    private fun writeSecret(name: String, value: String) {
        if (value.isBlank()) {
            prefs.edit().remove("${name}_iv").remove("${name}_ct").apply()
            return
        }
        val aad = "route-engine-pref:$name".toByteArray(Charsets.UTF_8)
        val sealed = crypto.seal(value.toByteArray(Charsets.UTF_8), aad)
        prefs.edit()
            .putString("${name}_iv", Base64.encodeToString(sealed.iv, Base64.NO_WRAP))
            .putString("${name}_ct", Base64.encodeToString(sealed.ciphertext, Base64.NO_WRAP))
            .apply()
    }

    private fun readSecret(name: String): String {
        val iv = prefs.getString("${name}_iv", null) ?: return ""
        val ct = prefs.getString("${name}_ct", null) ?: return ""
        return try {
            val aad = "route-engine-pref:$name".toByteArray(Charsets.UTF_8)
            val opened = crypto.open(
                Base64.decode(iv, Base64.NO_WRAP),
                Base64.decode(ct, Base64.NO_WRAP),
                aad,
            )
            opened.toString(Charsets.UTF_8)
        } catch (_: Throwable) {
            ""
        }
    }
}
