package com.alamat.test_google_mlkit.arcore

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.google.android.filament.MaterialInstance
import com.google.ar.core.AugmentedFace
import com.google.ar.core.Config
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import io.flutter.embedding.android.FlutterFragmentActivity
import io.github.sceneview.ar.ARPermissionHandler
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.node.AugmentedFaceNode
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import io.github.sceneview.math.colorOf
import io.github.sceneview.node.ModelNode
import io.github.sceneview.rememberEngine
import io.github.sceneview.rememberFillLightNode
import io.github.sceneview.rememberMainLightNode
import io.github.sceneview.rememberMaterialLoader
import io.github.sceneview.rememberModelInstance
import io.github.sceneview.rememberModelLoader
import io.github.sceneview.rememberOnGestureListener
import io.github.sceneview.SurfaceType

/**
 * Compose-сцена: фронтальный ARCore + MESH3D + GLB на face pose.
 *
 * Поток матриц лица во Flutter не отправляем — tracking и render остаются
 * на native/GL. EventChannel получает только переходы состояний.
 */
@Composable
fun ArCoreFaceScene(
    activity: FlutterFragmentActivity,
    permissionHandler: ARPermissionHandler,
    sessionModel: ArCoreFaceSessionModel,
    events: ArCoreFaceEventSink,
    resolveAsset: (String) -> String,
) {
    val engine = rememberEngine()
    val modelLoader = rememberModelLoader(engine)
    val materialLoader = rememberMaterialLoader(engine)
    val config = sessionModel.config
    val assetPath = remember(config.assetKey) { resolveAsset(config.assetKey) }

    var trackedFace by remember { mutableStateOf<AugmentedFace?>(null) }
    var noseLocal by remember { mutableStateOf(Position(0f, 0f, 0f)) }

    // Depth-only: сетка лица пишет z-buffer, но не цвет камеры.
    // Дужки/переносица не просвечивают сквозь лицо там, где есть mesh.
    val occluderMaterial = remember(materialLoader) {
        materialLoader.createColorInstance(colorOf(0f, 0f, 0f, 1f)).asFaceOccluder()
    }

    val modelInstance = rememberModelInstance(modelLoader, assetPath)
    LaunchedEffect(assetPath) {
        events.emit("model", mapOf("state" to "loading"))
    }
    LaunchedEffect(modelInstance) {
        if (modelInstance != null) {
            events.emit("model", mapOf("state" to "ready"))
        }
    }

    // key(restartToken): retrySession полностью пересоздаёт ARSceneView
    // (после установки ARCore / выдачи CAMERA).
    key(sessionModel.restartToken) {
        ARSceneView(
            modifier = Modifier.fillMaxSize(),
            engine = engine,
            modelLoader = modelLoader,
            materialLoader = materialLoader,
            surfaceType = SurfaceType.TextureSurface,
            sessionFeatures = setOf(Session.Feature.FRONT_CAMERA),
            sessionCameraConfig = ::selectFrontCameraConfig,
            planeRenderer = false,
            planeFindingMode = Config.PlaneFindingMode.DISABLED,
            depthMode = Config.DepthMode.DISABLED,
            instantPlacementMode = Config.InstantPlacementMode.DISABLED,
            geospatialMode = Config.GeospatialMode.DISABLED,
            augmentedFaceMode = Config.AugmentedFaceMode.MESH3D,
            permissionHandler = permissionHandler,
            lifecycle = activity.lifecycle,
            mainLightNode = rememberMainLightNode(engine) {
                intensity = 45_000f
            },
            fillLightNode = rememberFillLightNode(engine) {
                intensity = 18_000f
            },
            // Фронтальная сессия не даёт Environmental HDR — IBL оставляем,
            // но свет фиксированный, чтобы PBR-оправа не проваливалась в чёрный.
            sessionConfiguration = { _, sessionConfig ->
                sessionConfig.lightEstimationMode = Config.LightEstimationMode.DISABLED
            },
            onGestureListener = rememberOnGestureListener(),
            onSessionCreated = {
                events.emit("availability", mapOf("state" to "ready"))
                events.emit("session", mapOf("state" to "starting"))
            },
            onSessionResumed = {
                events.emit("session", mapOf("state" to "running"))
            },
            onSessionPaused = {
                events.emit("session", mapOf("state" to "paused"))
            },
            onSessionFailed = { error ->
                events.emit(
                    "session",
                    mapOf(
                        "state" to "failed",
                        "message" to (error.message ?: error.toString()),
                    ),
                )
            },
            onSessionUpdated = { session, _ ->
                val faces = session.getAllTrackables(AugmentedFace::class.java)
                val tracking = faces.firstOrNull { it.trackingState == TrackingState.TRACKING }
                trackedFace = tracking
                val trackingState = when {
                    tracking != null -> "tracking"
                    faces.any { it.trackingState == TrackingState.PAUSED } -> "lost"
                    else -> "searching"
                }
                events.emit("tracking", mapOf("state" to trackingState))
            },
        ) {
            val face = trackedFace ?: return@ARSceneView
            AugmentedFaceNode(
                augmentedFace = face,
                meshMaterialInstance = occluderMaterial,
                onUpdated = { updated ->
                    if (config.anchor == ArCoreGlassesConfig.FaceAnchor.NOSE) {
                        val relative = updated.centerPose.inverse()
                            .compose(updated.getRegionPose(AugmentedFace.RegionType.NOSE_TIP))
                        noseLocal = Position(relative.tx(), relative.ty(), relative.tz())
                    } else {
                        noseLocal = Position(0f, 0f, 0f)
                    }
                },
            ) {
                val instance = modelInstance ?: return@AugmentedFaceNode
                val extra = if (config.anchor == ArCoreGlassesConfig.FaceAnchor.NOSE) {
                    noseLocal
                } else {
                    Position(0f, 0f, 0f)
                }
                ModelNode(
                    modelInstance = instance,
                    scaleToUnits = config.widthMeters,
                    centerOrigin = Position(0f, 0f, 0f),
                    position = Position(
                        extra.x + config.offsetX,
                        extra.y + config.offsetY,
                        extra.z + config.offsetZ,
                    ),
                    rotation = Rotation(
                        config.rotationX,
                        config.rotationY,
                        config.rotationZ,
                    ),
                    autoAnimate = false,
                )
            }
        }
    }
}

/**
 * Occluder для 468-точечной сетки ARCore: depth write без color write.
 * Рендер раньше оправы (меньший Filament priority), чтобы дужки клипались по z.
 */
private fun MaterialInstance.asFaceOccluder(): MaterialInstance {
    setColorWrite(false)
    setDepthWrite(true)
    return this
}
