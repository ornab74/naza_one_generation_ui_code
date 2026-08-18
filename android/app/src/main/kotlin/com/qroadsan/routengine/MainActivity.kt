package com.qroadsan.routengine

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val methodChannelName = "route_engine/doordash_control"
    private val eventChannelName = "route_engine/doordash_events"
    private val io = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeEventBus.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    NativeEventBus.attach(null)
                }
            },
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }

                "setMonitoringEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    NativeSettings(this).update(mapOf("monitorEnabled" to enabled))
                    result.success(null)
                }

                "getNativeSettings" -> {
                    result.success(NativeSettings(this).snapshot().toMap(includeToken = true))
                }

                "saveNativeSettings" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
                    val normalized = args.entries.associate {
                        it.key.toString() to it.value
                    }
                    NativeSettings(this).update(normalized)
                    result.success(null)
                }

                "runtimeStatus" -> {
                    result.success(
                        mapOf(
                            "platformBridge" to true,
                            "accessibilityEnabled" to isAccessibilityEnabled(),
                            "serviceConnected" to
                                (DoorDashAccessibilityService.instance != null),
                            "packageName" to packageName,
                        ),
                    )
                }

                "previewOverlay" -> {
                    val verdict = call.argument<String>("verdict") ?: "PREVIEW"
                    val weather = call.argument<String>("weather") ?: "WX --"
                    val argb = call.argument<Int>("argb") ?: 0xff45e6ff.toInt()
                    DoorDashAccessibilityService.instance
                        ?.previewOverlay(verdict, weather, argb)
                    result.success(null)
                }

                "listCaptures" -> {
                    val limit = call.argument<Int>("limit") ?: 80
                    background(result) {
                        SecureCaptureStore(applicationContext).use {
                            it.list(limit)
                        }
                    }
                }

                "loadCapture" -> {
                    val id = call.argument<Number>("id")?.toLong()
                    if (id == null) {
                        result.error("bad_args", "Missing capture id", null)
                    } else {
                        background(result) {
                            SecureCaptureStore(applicationContext).use {
                                it.load(id)
                            }
                        }
                    }
                }

                "clearCaptures" -> {
                    background(result) {
                        SecureCaptureStore(applicationContext).use {
                            it.clearAll()
                        }
                        null
                    }
                }

                "saveManualCapture" -> {
                    val screenshot = call.argument<ByteArray>("screenshot")
                    val fileName = call.argument<String>("fileName") ?: "manual-screenshot"
                    val decisionRaw = call.argument<Map<String, Any?>>("decision")
                    if (screenshot == null || screenshot.isEmpty() || decisionRaw == null) {
                        result.error(
                            "bad_args",
                            "Manual capture requires screenshot bytes and a decision.",
                            null,
                        )
                    } else {
                        background(result) {
                            val payload = JSONObject(
                                mapOf(
                                    "source" to "manual_screenshot",
                                    "fileName" to fileName,
                                ),
                            ).toString()
                            val decisionJson = JSONObject(decisionRaw).toString()
                            SecureCaptureStore(applicationContext).use { store ->
                                val id = store.insertCapture(
                                    kind = "MANUAL_SCREENSHOT",
                                    fingerprint = "manual:${System.currentTimeMillis()}:$fileName:${screenshot.size}",
                                    payloadJson = payload,
                                    screenshot = screenshot,
                                    width = null,
                                    height = null,
                                )
                                store.updateDecision(id, decisionJson)
                                id
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun background(
        result: MethodChannel.Result,
        block: () -> Any?,
    ) {
        io.execute {
            try {
                val value = block()
                runOnUiThread { result.success(value) }
            } catch (t: Throwable) {
                runOnUiThread {
                    result.error(
                        "native_error",
                        t.message ?: t.javaClass.simpleName,
                        null,
                    )
                }
            }
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expected = ComponentName(this, DoorDashAccessibilityService::class.java)
            .flattenToString()
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expected, ignoreCase = true)) return true
        }
        return false
    }

    override fun onDestroy() {
        NativeEventBus.attach(null)
        io.shutdownNow()
        super.onDestroy()
    }
}
