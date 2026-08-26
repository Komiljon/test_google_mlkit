package com.alamat.test_google_mlkit.arcore

import android.view.View
import android.widget.FrameLayout
import androidx.activity.setViewTreeOnBackPressedDispatcherOwner
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.github.sceneview.ar.ARPermissionHandler
import io.github.sceneview.ar.ActivityARPermissionHandler

/**
 * Состояние сессии, которое Compose читает как snapshot state.
 * MethodChannel мутирует поля с UI-потока — ARSceneView пересобирается реактивно.
 */
class ArCoreFaceSessionModel(initial: ArCoreGlassesConfig) {
    var config by mutableStateOf(initial)
    var restartToken by mutableIntStateOf(0)

    fun retry() {
        restartToken += 1
    }
}

/**
 * ComposeView + per-view MethodChannel/EventChannel.
 *
 * Камеру пакету `camera` на этом экране не открываем: ARCore забирает
 * фронтальный сенсор целиком и не делится им с CameraX.
 */
class ArCoreFacePlatformView(
    private val activity: FlutterFragmentActivity,
    messenger: BinaryMessenger,
    viewId: Int,
    creationParams: Map<String, Any?>?,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val events = ArCoreFaceEventSink()
    private val sessionModel = ArCoreFaceSessionModel(ArCoreGlassesConfig.fromMap(creationParams))
    private val permissionHandler: ARPermissionHandler = ActivityARPermissionHandler(activity)
    private val methodChannel = MethodChannel(messenger, ArCoreFaceChannels.methodChannelName(viewId))
    private val eventChannel = EventChannel(messenger, ArCoreFaceChannels.eventChannelName(viewId))
    private val composeView: ComposeView
    private val container: FrameLayout

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(events)
        emitAvailabilityFromApk()

        composeView = ComposeView(activity).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            // Flutter PlatformView часто даёт Context без ViewTree owners —
            // без этого Compose и ARSceneView падают на LocalLifecycleOwner.
            setViewTreeLifecycleOwner(activity)
            setViewTreeViewModelStoreOwner(activity)
            setViewTreeSavedStateRegistryOwner(activity)
            setViewTreeOnBackPressedDispatcherOwner(activity)
            setContent {
                ArCoreFaceScene(
                    activity = activity,
                    permissionHandler = permissionHandler,
                    sessionModel = sessionModel,
                    events = events,
                    resolveAsset = ::resolveFlutterAsset,
                )
            }
        }
        container = FrameLayout(activity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
            addView(
                composeView,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        events.cancel()
        composeView.disposeComposition()
        container.removeAllViews()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> result.success(events.snapshot())
            "setModelAsset" -> {
                val assetKey = call.argument<String>("assetKey")
                    ?: call.arguments as? String
                if (assetKey.isNullOrBlank()) {
                    result.error("bad_args", "assetKey обязателен", null)
                    return
                }
                sessionModel.config = sessionModel.config.copy(assetKey = assetKey)
                result.success(null)
            }
            "setCalibration" -> {
                @Suppress("UNCHECKED_CAST")
                val map = call.arguments as? Map<String, Any?>
                if (map == null) {
                    result.error("bad_args", "ожидалась карта калибровки", null)
                    return
                }
                val current = sessionModel.config
                sessionModel.config = ArCoreGlassesConfig.fromMap(
                    map + ("assetKey" to (map["assetKey"] ?: current.assetKey)),
                )
                result.success(null)
            }
            "retrySession" -> {
                emitAvailabilityFromApk()
                sessionModel.retry()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Ключ Flutter-ассета (`assets/sunglasses.glb`) → путь внутри APK
     * (`flutter_assets/assets/sunglasses.glb`). Копировать GLB во временный файл не нужно.
     */
    private fun resolveFlutterAsset(assetKey: String): String {
        return io.flutter.FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetKey)
    }

    private fun emitAvailabilityFromApk() {
        events.emit("availability", mapOf("state" to "checking"))
        val availability = permissionHandler.checkARCoreAvailability()
        val state = when (availability) {
            ArCoreApk.Availability.SUPPORTED_INSTALLED -> "ready"
            ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED,
            ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD,
            -> "installRequested"
            ArCoreApk.Availability.UNSUPPORTED_DEVICE_NOT_CAPABLE -> "unsupported"
            ArCoreApk.Availability.UNKNOWN_CHECKING -> "checking"
            ArCoreApk.Availability.UNKNOWN_ERROR,
            ArCoreApk.Availability.UNKNOWN_TIMED_OUT,
            -> "unsupported"
        }
        events.emit("availability", mapOf("state" to state))
        events.emit("session", mapOf("state" to "starting"))
        events.emit("tracking", mapOf("state" to "searching"))
        events.emit("model", mapOf("state" to "loading"))
    }
}
