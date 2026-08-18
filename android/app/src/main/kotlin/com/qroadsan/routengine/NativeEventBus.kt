package com.qroadsan.routengine

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object NativeEventBus {
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attach(value: EventChannel.EventSink?) {
        sink = value
    }

    fun emit(event: Map<String, Any?>) {
        main.post {
            sink?.success(event)
        }
    }

    fun error(code: String, message: String) {
        main.post {
            sink?.error(code, message, null)
        }
    }
}
