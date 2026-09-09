package com.alamat.test_google_mlkit.arcore

import android.util.Log
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.google.android.filament.MaterialInstance
import com.google.ar.core.AugmentedFace
import com.google.ar.core.CameraConfig
import com.google.ar.core.Config
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import io.flutter.embedding.android.FlutterFragmentActivity
import io.github.sceneview.ar.ARConfigDowngrade
import io.github.sceneview.ar.ARPermissionHandler
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.ARSessionFailure
import io.github.sceneview.ar.frontCameraConfig
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

private const val TAG = "ArCoreFace"

/**
 * Compose-сцена: фронтальный ARCore + MESH3D + GLB на face pose.
 *
 * Поток матриц лица во Flutter не отправляем — tracking и render остаются
 * на native/GL. EventChannel получает только переходы состояний.
 *
 * ВАЖНО (см. план `arcore_glasses_fix`): [AugmentedFaceNode] сам НЕ едет за лицом —
 * его `update(Session, Frame)` не вызывает `super.update` и не назначает pose себе.
 * За лицом синхронизируются только его `centerNode` / `regionNodes` (PoseNode).
 * Поэтому очки нельзя вешать в content-лямбду узла лица (это ребёнок самого
 * AugmentedFaceNode) — их вешаем императивно на `centerNode`/`regionNodes[NOSE_TIP]`.
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

    // Depth-only occluder: сетка лица пишет z-buffer, но не цвет камеры.
    // createUnlitColorInstance (не createColorInstance/PBR) — ARFaceDemo использует
    // именно unlit для маски лица, PBR-освещение сетке не нужно и дороже на 30 FPS.
    val occluderMaterial = remember(materialLoader) {
        materialLoader.createUnlitColorInstance(colorOf(0f, 0f, 0f, 1f)).asFaceOccluder()
    }

    val modelInstance = rememberModelInstance(modelLoader, assetPath)

    // Честная диагностика загрузки GLB: rememberModelInstance возвращает null и во
    // время загрузки, и при провале — без явной проверки assets.open() эти два
    // состояния неразличимы, а ArCoreModelPhase.failed недостижим.
    LaunchedEffect(assetPath) {
        events.emit("model", mapOf("state" to "loading"))
        try {
            activity.assets.open(assetPath).close()
            Log.i(TAG, "GLB найден в APK: $assetPath")
        } catch (e: java.io.IOException) {
            Log.w(TAG, "GLB отсутствует в APK: $assetPath", e)
            events.emit(
                "model",
                mapOf("state" to "failed", "message" to "нет в APK: $assetPath"),
            )
        }
    }
    LaunchedEffect(modelInstance) {
        if (modelInstance != null) {
            Log.i(TAG, "GLB загружен: $assetPath")
            events.emit("model", mapOf("state" to "ready"))
        }
    }

    // Заглушка "ждём первый кадр камеры" во Flutter держится, пока не придёт первый
    // onSessionUpdated текущей сессии — сбрасывается на каждый retrySession/пересоздание.
    var firstFrameSeen by remember(sessionModel.restartToken) { mutableStateOf(false) }
    LaunchedEffect(sessionModel.restartToken) {
        firstFrameSeen = false
        events.emit("frame", mapOf("state" to "pending"))
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
            // FRONT_CAMERA в sessionFeatures только *разрешает* селфи-камеру. Без явного
            // выбора FRONT CameraConfig сессия остаётся на задней камере и MESH3D не даёт
            // лиц. io.github.sceneview.ar.frontCameraConfig — библиотечный селектор
            // максимального разрешения (проверено по arsceneview-4.30.0-api.jar), с
            // фолбэком на session.cameraConfig, если FRONT недоступен.
            sessionCameraConfig = ::loggingFrontCameraConfig,
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
                Log.i(TAG, "AR-сессия создана")
                events.emit("availability", mapOf("state" to "ready"))
                events.emit("session", mapOf("state" to "starting"))
            },
            onSessionResumed = { session ->
                Log.i(
                    TAG,
                    "AR-сессия возобновлена, cameraConfig=" +
                        "${session.cameraConfig.facingDirection} ${session.cameraConfig.imageSize}",
                )
                events.emit("session", mapOf("state" to "running"))
            },
            onSessionPaused = {
                Log.i(TAG, "AR-сессия на паузе")
                events.emit("session", mapOf("state" to "paused"))
            },
            onSessionFailed = { error ->
                Log.w(TAG, "AR-сессия не стартовала (legacy-канал)", error)
                events.emit(
                    "session",
                    mapOf(
                        "state" to "failed",
                        "message" to (error.message ?: error.toString()),
                    ),
                )
            },
            // Типизированный канал 4.30: точная причина отказа сразу в logcat,
            // Flutter получает то же сообщение через onSessionFailed (см. docs — оба
            // колбэка вызываются вместе, старый оставлен для обратной совместимости).
            onSessionFailure = { failure: ARSessionFailure ->
                Log.w(TAG, "AR-сессия: типизированная причина отказа — $failure")
            },
            onConfigDowngraded = { downgrade: ARConfigDowngrade ->
                Log.w(
                    TAG,
                    "ARCore тихо понизил конфигурацию: $downgrade — запрошенная " +
                        "возможность недоступна на этом устройстве",
                )
            },
            onTrackingFailureChanged = { reason ->
                Log.i(TAG, "Причина потери трекинга камеры: $reason")
            },
            onSessionUpdated = { session, _ ->
                if (!firstFrameSeen) {
                    firstFrameSeen = true
                    Log.i(TAG, "Получен первый кадр AR-сессии")
                    events.emit("frame", mapOf("state" to "first"))
                }
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
            val faceNodeRef = remember { NodeRef<AugmentedFaceNode>() }
            val glassesNodeRef = remember { NodeRef<ModelNode>() }

            // key(occlusionEnabled): meshMaterialInstance у AugmentedFaceNode неизменяем
            // после создания (private val в классе) — чтобы чекбокс "оккlusion" в
            // калибровке реально работал, пересоздаём узел лица целиком.
            key(config.occlusionEnabled) {
                AugmentedFaceNode(
                    augmentedFace = face,
                    meshMaterialInstance = if (config.occlusionEnabled) occluderMaterial else null,
                    computeTangents = false, // материал unlit — TANGENTS не сэмплируются
                    apply = { faceNodeRef.value = this },
                )
            }

            // scaleToUnits/centerOrigin у ModelNode не реактивны (применяются один раз
            // при создании) — узел очков пересоздаём вручную при смене этих параметров,
            // ассета, якоря или переключении оккlusion (см. выше — новый faceNode).
            DisposableEffect(
                face,
                modelInstance,
                config.anchor,
                config.widthMeters,
                config.keepAuthoredPivot,
                config.occlusionEnabled,
            ) {
                val parentNode = when (config.anchor) {
                    ArCoreGlassesConfig.FaceAnchor.NOSE ->
                        faceNodeRef.value?.regionNodes?.get(AugmentedFace.RegionType.NOSE_TIP)
                    ArCoreGlassesConfig.FaceAnchor.CENTER ->
                        faceNodeRef.value?.centerNode
                }
                val instance = modelInstance
                if (parentNode == null || instance == null) {
                    return@DisposableEffect onDispose { }
                }
                // Полное имя класса обязательно: внутри NodeScope-лямбды простое имя
                // "ModelNode" резолвится в @Composable SceneScope.ModelNode(...), а не
                // в конструктор класса — нужен именно императивный класс без Compose.
                val node = io.github.sceneview.node.ModelNode(
                    modelInstance = instance,
                    autoAnimate = false,
                    scaleToUnits = config.widthMeters,
                    centerOrigin = if (config.keepAuthoredPivot) null else Position(0f, 0f, 0f),
                ).also { it.parent = parentNode }
                glassesNodeRef.value = node
                Log.i(
                    TAG,
                    "Очки прикреплены к " +
                        if (config.anchor == ArCoreGlassesConfig.FaceAnchor.NOSE) {
                            "regionNodes[NOSE_TIP]"
                        } else {
                            "centerNode"
                        },
                )
                onDispose {
                    node.parent = null
                    node.destroy()
                    glassesNodeRef.value = null
                }
            }

            // offset/rotation реактивны как обычные свойства Node — пишем прямо в узел
            // на каждой рекомпозиции калибровки, без пересоздания и без лишней работы.
            SideEffect {
                glassesNodeRef.value?.let { node ->
                    node.position = Position(config.offsetX, config.offsetY, config.offsetZ)
                    node.rotation = Rotation(config.rotationX, config.rotationY, config.rotationZ)
                }
            }
        }
    }
}

/**
 * Простой holder без snapshot-состояния: писать состояние Compose во время
 * композиции (в теле content-лямбды) нельзя — а ссылка на узел лица/очков
 * нужна именно императивно, между apply/DisposableEffect/SideEffect.
 */
private class NodeRef<T> {
    var value: T? = null
}

/**
 * sessionCameraConfig с логированием фактически выбранной камеры: если FRONT
 * конфигурации нет, библиотека молча остаётся на session.cameraConfig — раньше
 * это было не видно в logcat и выглядело как "камера включилась, лиц нет".
 */
private fun loggingFrontCameraConfig(session: Session): CameraConfig {
    val config = frontCameraConfig(session)
    Log.i(
        TAG,
        "CameraConfig выбран: facing=${config.facingDirection} size=${config.imageSize}",
    )
    return config
}

/**
 * Occluder для 468-точечной сетки ARCore: depth write без color write.
 */
private fun MaterialInstance.asFaceOccluder(): MaterialInstance {
    setColorWrite(false)
    setDepthWrite(true)
    return this
}
