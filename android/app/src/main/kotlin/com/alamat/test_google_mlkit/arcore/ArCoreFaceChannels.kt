package com.alamat.test_google_mlkit.arcore

/**
 * Имена viewType и per-view каналов. Должны совпадать с Dart
 * (`lib/arcore/arcore_face_view.dart` / `arcore_face_controller.dart`).
 */
object ArCoreFaceChannels {
    const val VIEW_TYPE = "com.alamat.test_google_mlkit/arcore_face_view"

    fun methodChannelName(viewId: Int): String {
        return "com.alamat.test_google_mlkit/arcore_face/method_$viewId"
    }

    fun eventChannelName(viewId: Int): String {
        return "com.alamat.test_google_mlkit/arcore_face/events_$viewId"
    }
}
