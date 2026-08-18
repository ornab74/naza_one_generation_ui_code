package com.qroadsan.routengine

import android.accessibilityservice.AccessibilityService
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

class OverlayController(private val service: AccessibilityService) {
    private val wm = service.getSystemService(WindowManager::class.java)
    private var root: LinearLayout? = null
    private var dot: View? = null
    private var status: TextView? = null
    private var weather: TextView? = null
    private var visibleForDoorDash = false

    fun ensure() {
        if (root != null) return
        val density = service.resources.displayMetrics.density
        val container = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(
                (12 * density).toInt(),
                (8 * density).toInt(),
                (12 * density).toInt(),
                (8 * density).toInt(),
            )
            background = rounded(Color.argb(232, 13, 17, 26), 18f * density)
            elevation = 10f * density
        }
        val indicator = View(service).apply {
            layoutParams = LinearLayout.LayoutParams(
                (12 * density).toInt(),
                (12 * density).toInt(),
            ).also { it.marginEnd = (8 * density).toInt() }
            background = rounded(Color.rgb(69, 230, 255), 999f)
        }
        val statusText = TextView(service).apply {
            text = "NAZA • MONITORING"
            setTextColor(Color.WHITE)
            textSize = 12f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 1
        }
        val weatherText = TextView(service).apply {
            text = "WX --"
            setTextColor(Color.rgb(170, 180, 198))
            textSize = 11f
            setPadding((10 * density).toInt(), 0, 0, 0)
            maxLines = 1
        }
        container.addView(indicator)
        container.addView(statusText)
        container.addView(weatherText)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            android.graphics.PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = (54 * density).toInt()
        }

        wm.addView(container, params)
        container.visibility = View.GONE
        root = container
        dot = indicator
        status = statusText
        weather = weatherText
    }

    fun setDoorDashVisible(value: Boolean) {
        visibleForDoorDash = value
        val enabled = NativeSettings(service).snapshot().overlayEnabled
        root?.visibility = if (value && enabled) View.VISIBLE else View.GONE
    }

    fun update(
        verdict: String,
        weatherLabel: String,
        color: Int,
    ) {
        service.mainExecutor.execute {
            ensure()
            dot?.background = rounded(color, 999f)
            status?.text = "NAZA • $verdict"
            weather?.text = weatherLabel
            root?.visibility =
                if (visibleForDoorDash && NativeSettings(service).snapshot().overlayEnabled) {
                    View.VISIBLE
                } else {
                    View.GONE
                }
        }
    }

    fun temporarilyHide(): Boolean {
        val view = root ?: return false
        val wasVisible = view.visibility == View.VISIBLE
        view.visibility = View.GONE
        return wasVisible
    }

    fun restoreAfterCapture(wasVisible: Boolean) {
        if (wasVisible && visibleForDoorDash && NativeSettings(service).snapshot().overlayEnabled) {
            service.mainExecutor.execute { root?.visibility = View.VISIBLE }
        }
    }

    fun destroy() {
        val view = root ?: return
        try {
            wm.removeView(view)
        } catch (_: Throwable) {
        }
        root = null
    }

    private fun rounded(color: Int, radius: Float): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = radius
        }
}
