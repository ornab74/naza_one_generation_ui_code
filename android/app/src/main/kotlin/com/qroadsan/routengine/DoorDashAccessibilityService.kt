package com.qroadsan.routengine

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityService.ScreenshotResult
import android.accessibilityservice.AccessibilityService.TakeScreenshotCallback
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicLong

class DoorDashAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile var instance: DoorDashAccessibilityService? = null
        private const val DOORDASH_PACKAGE = "com.doordash.driverapp"
    }

    private lateinit var store: SecureCaptureStore
    private lateinit var overlay: OverlayController
    private lateinit var pipeline: OnlineDecisionPipeline
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lastCaptureAt = AtomicLong(0)
    private var lastFingerprint: String = ""

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        store = SecureCaptureStore(applicationContext)
        overlay = OverlayController(this).also { it.ensure() }
        pipeline = OnlineDecisionPipeline(applicationContext, store, overlay)
        NativeEventBus.emit(
            mapOf(
                "status" to "DoorDash accessibility service connected",
                "serviceConnected" to true,
            ),
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        val packageName = event.packageName?.toString() ?: return
        val isDoorDash = packageName == DOORDASH_PACKAGE
        if (::overlay.isInitialized) overlay.setDoorDashVisible(isDoorDash)
        if (!isDoorDash) return

        val settings = NativeSettings(this).snapshot()
        if (!settings.monitorEnabled) return

        if (
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            return
        }

        val root = rootInActiveWindow ?: return
        val lines = collectText(root)
        if (lines.isEmpty()) return

        val classification = classify(lines)
        if (classification == "OTHER") return

        val normalized = lines.joinToString("\n") { it.trim() }.take(12_000)
        val fingerprint = sha256("$classification\n$normalized")
        if (fingerprint == lastFingerprint) return

        val now = System.currentTimeMillis()
        if (now - lastCaptureAt.get() < 1_500) return
        lastFingerprint = fingerprint
        lastCaptureAt.set(now)

        val payload = JSONObject()
            .put("package", packageName)
            .put("kind", classification)
            .put("event_type", event.eventType)
            .put("captured_at", now)
            .put("text", JSONArray(lines.take(180)))
            .put("merchant", guessMerchant(lines))
            .put("offer_pay", guessMoney(lines))
            .put("displayed_miles", guessMiles(lines))

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            captureScreenshot(event.windowId, classification, fingerprint, payload)
        } else {
            persistAndAnalyze(classification, fingerprint, payload, null, null, null)
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        instance = null
        if (::pipeline.isInitialized) pipeline.shutdown()
        if (::overlay.isInitialized) overlay.destroy()
        if (::store.isInitialized) store.close()
        super.onDestroy()
    }

    fun previewOverlay(verdict: String, weather: String, argb: Int) {
        if (::overlay.isInitialized) {
            overlay.setDoorDashVisible(true)
            overlay.update(verdict, weather, argb)
        }
    }

    private fun captureScreenshot(
        windowId: Int,
        kind: String,
        fingerprint: String,
        payload: JSONObject,
    ) {
        val wasVisible = overlay.temporarilyHide()
        mainHandler.postDelayed({
            if (!isExpectedDoorDashWindow(windowId)) {
                payload.put("screenshot_error", "foreground_window_changed")
                persistAndAnalyze(kind, fingerprint, payload, null, null, null)
                overlay.restoreAfterCapture(wasVisible)
                return@postDelayed
            }
            if (Build.VERSION.SDK_INT >= 34) {
                takeScreenshotOfWindow(
                    windowId,
                    mainExecutor,
                    callback(windowId, kind, fingerprint, payload, wasVisible),
                )
            } else {
                @Suppress("DEPRECATION")
                takeScreenshot(
                    Display.DEFAULT_DISPLAY,
                    mainExecutor,
                    callback(windowId, kind, fingerprint, payload, wasVisible),
                )
            }
        }, 90)
    }

    private fun callback(
        expectedWindowId: Int,
        kind: String,
        fingerprint: String,
        payload: JSONObject,
        wasVisible: Boolean,
    ) = object : TakeScreenshotCallback {
        override fun onSuccess(screenshot: ScreenshotResult) {
            try {
                if (!isExpectedDoorDashWindow(expectedWindowId)) {
                    payload.put("screenshot_error", "foreground_window_changed")
                    persistAndAnalyze(kind, fingerprint, payload, null, null, null)
                    return
                }
                val buffer = screenshot.hardwareBuffer
                val wrapped = Bitmap.wrapHardwareBuffer(buffer, screenshot.colorSpace)
                val bitmap = wrapped?.copy(Bitmap.Config.ARGB_8888, false)
                buffer.close()

                if (bitmap == null) {
                    persistAndAnalyze(kind, fingerprint, payload, null, null, null)
                    return
                }

                val maxWidth = 1440
                val finalBitmap = if (bitmap.width > maxWidth) {
                    val ratio = maxWidth.toDouble() / bitmap.width.toDouble()
                    Bitmap.createScaledBitmap(
                        bitmap,
                        maxWidth,
                        (bitmap.height * ratio).toInt().coerceAtLeast(1),
                        true,
                    ).also { bitmap.recycle() }
                } else {
                    bitmap
                }
                val output = ByteArrayOutputStream()
                finalBitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                val bytes = output.toByteArray()
                val width = finalBitmap.width
                val height = finalBitmap.height
                finalBitmap.recycle()
                persistAndAnalyze(kind, fingerprint, payload, bytes, width, height)
            } catch (t: Throwable) {
                payload.put("screenshot_error", t.message ?: t.javaClass.simpleName)
                persistAndAnalyze(kind, fingerprint, payload, null, null, null)
            } finally {
                overlay.restoreAfterCapture(wasVisible)
            }
        }

        override fun onFailure(errorCode: Int) {
            payload.put("screenshot_error_code", errorCode)
            persistAndAnalyze(kind, fingerprint, payload, null, null, null)
            overlay.restoreAfterCapture(wasVisible)
        }
    }

    private fun isExpectedDoorDashWindow(expectedWindowId: Int): Boolean {
        val root = rootInActiveWindow ?: return false
        return root.packageName?.toString() == DOORDASH_PACKAGE &&
            root.windowId == expectedWindowId
    }

    private fun persistAndAnalyze(
        kind: String,
        fingerprint: String,
        payload: JSONObject,
        screenshot: ByteArray?,
        width: Int?,
        height: Int?,
    ) {
        val id = store.insertCapture(
            kind = kind,
            fingerprint = fingerprint,
            payloadJson = payload.toString(),
            screenshot = screenshot,
            width = width,
            height = height,
        )
        NativeEventBus.emit(
            mapOf(
                "recordId" to id,
                "kind" to kind,
                "status" to "DoorDash $kind securely captured",
                "text" to payload.optJSONArray("text")?.let { arr ->
                    (0 until arr.length()).map { arr.optString(it) }
                },
                "hasScreenshot" to (screenshot != null),
            ),
        )
        pipeline.analyze(id, kind, payload, screenshot)
    }

    private fun collectText(root: AccessibilityNodeInfo): List<String> {
        val output = LinkedHashSet<String>()
        fun walk(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || depth > 24 || output.size >= 220) return
            node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let {
                output += it.take(500)
            }
            node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let {
                output += it.take(500)
            }
            for (i in 0 until node.childCount) {
                walk(node.getChild(i), depth + 1)
            }
        }
        walk(root, 0)
        return output.toList()
    }

    private fun classify(lines: List<String>): String {
        val all = lines.joinToString(" ").lowercase()
        val hasMoney = Regex("""\$\s*\d+(?:\.\d{1,2})?""").containsMatchIn(all)
        val hasMiles = Regex("""\d+(?:\.\d+)?\s*(?:mi|miles)\b""").containsMatchIn(all)
        val hasAccept = all.contains("accept")
        if (hasMoney && hasMiles && hasAccept) return "OFFER"

        val activeMarkers = listOf(
            "arrived at",
            "pick up",
            "pickup",
            "deliver to",
            "complete delivery",
            "confirm pickup",
            "customer",
            "directions",
            "drop-off",
            "drop off",
        )
        if (activeMarkers.count { all.contains(it) } >= 2) return "ORDER_STATE"
        return "OTHER"
    }

    private fun guessMerchant(lines: List<String>): String {
        val rejected = Regex(
            """(?i)(accept|decline|deliver|mile|miles|mi|customer|directions|pickup|drop)""",
        )
        return lines.firstOrNull {
            it.length in 3..90 &&
                !it.contains("$") &&
                !rejected.containsMatchIn(it)
        } ?: ""
    }

    private fun guessMoney(lines: List<String>): Double? {
        val match = Regex("""\$\s*(\d+(?:\.\d{1,2})?)""")
            .find(lines.joinToString(" "))
        return match?.groupValues?.getOrNull(1)?.toDoubleOrNull()
    }

    private fun guessMiles(lines: List<String>): Double? {
        val match = Regex("""(?i)(\d+(?:\.\d+)?)\s*(?:mi|miles)\b""")
            .find(lines.joinToString(" "))
        return match?.groupValues?.getOrNull(1)?.toDoubleOrNull()
    }

    private fun sha256(value: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
}
