package com.alamat.test_google_mlkit.arcore

import android.content.Context
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Фабрика PlatformView для живой ARCore-примерки.
 *
 * Activity передаём явно: у Flutter [Context] часто [android.content.MutableContextWrapper]
 * без Lifecycle/SavedState, а [io.github.sceneview.ar.ARSceneView] и ComposeView
 * читают owner'ов из ViewTree, завязанного на Activity.
 */
class ArCoreFaceViewFactory(
    private val activity: FlutterFragmentActivity,
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?>
        return ArCoreFacePlatformView(
            activity = activity,
            messenger = messenger,
            viewId = viewId,
            creationParams = params,
        )
    }
}
