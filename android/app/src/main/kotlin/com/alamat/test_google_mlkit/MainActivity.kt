package com.alamat.test_google_mlkit

import com.alamat.test_google_mlkit.arcore.ArCoreFaceChannels
import com.alamat.test_google_mlkit.arcore.ArCoreFaceViewFactory
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * FragmentActivity = ComponentActivity: нужен [io.github.sceneview.ar.ActivityARPermissionHandler]
 * и ViewTree Lifecycle для ComposeView внутри PlatformView.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                ArCoreFaceChannels.VIEW_TYPE,
                ArCoreFaceViewFactory(this, flutterEngine.dartExecutor.binaryMessenger),
            )
    }
}
