package com.alamat.test_google_mlkit.arcore

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * EventChannel с реплеем последнего события каждого [type].
 *
 * Flutter подписывается в `onPlatformViewCreated`, а native callbacks
 * (availability, session) могут прийти раньше. Без реплея первый event теряется.
 * Кадры face pose сюда не кладём — только переходы состояния.
 */
class ArCoreFaceEventSink : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lastByType = linkedMapOf<String, Map<String, Any?>>()
    private var sink: EventChannel.EventSink? = null

    @Synchronized
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        lastByType.values.forEach { event -> events?.success(event) }
    }

    @Synchronized
    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun emit(type: String, payload: Map<String, Any?>) {
        val event = HashMap<String, Any?>(payload.size + 1)
        event["type"] = type
        event.putAll(payload)
        synchronized(this) {
            // Не спамим EventChannel на 30/60 FPS: только смена state.
            if (lastByType[type] == event) {
                return
            }
            lastByType[type] = event
        }
        mainHandler.post {
            synchronized(this) {
                sink?.success(event)
            }
        }
    }

    fun snapshot(): Map<String, Any?> {
        synchronized(this) {
            return HashMap(lastByType)
        }
    }

    fun cancel() {
        mainHandler.removeCallbacksAndMessages(null)
        synchronized(this) {
            sink = null
            lastByType.clear()
        }
    }
}
