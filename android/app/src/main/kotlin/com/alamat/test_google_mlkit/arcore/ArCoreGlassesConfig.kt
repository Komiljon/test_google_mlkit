package com.alamat.test_google_mlkit.arcore

import com.google.ar.core.CameraConfig
import com.google.ar.core.CameraConfigFilter
import com.google.ar.core.Session

/**
 * Метрическая калибровка GLB-очков для ARCore Augmented Faces.
 *
 * Единица ARCore — метр. Origin модели должен совпасть с выбранным якорем
 * (`centerPose` за переносицей или `NOSE_TIP`). Offset/rotation — локальные
 * к этому pose, не к экрану.
 */
data class ArCoreGlassesConfig(
    val assetKey: String,
    val widthMeters: Float,
    val offsetX: Float,
    val offsetY: Float,
    val offsetZ: Float,
    val rotationX: Float,
    val rotationY: Float,
    val rotationZ: Float,
    val anchor: FaceAnchor,
) {
    enum class FaceAnchor {
        CENTER,
        NOSE,
        ;

        companion object {
            fun fromWire(value: String): FaceAnchor {
                return if (value.equals("nose", ignoreCase = true)) NOSE else CENTER
            }
        }
    }

    companion object {
        const val DEFAULT_ASSET_KEY = "assets/sunglasses.glb"
        const val DEFAULT_WIDTH_METERS = 0.14f

        fun fromMap(raw: Map<*, *>?): ArCoreGlassesConfig {
            val map = raw ?: emptyMap<Any, Any>()
            return ArCoreGlassesConfig(
                assetKey = map.string("assetKey", DEFAULT_ASSET_KEY),
                widthMeters = map.float("widthMeters", DEFAULT_WIDTH_METERS),
                offsetX = map.float("offsetX", 0f),
                offsetY = map.float("offsetY", 0.015f),
                offsetZ = map.float("offsetZ", 0.045f),
                rotationX = map.float("rotationX", 0f),
                rotationY = map.float("rotationY", 0f),
                rotationZ = map.float("rotationZ", 0f),
                anchor = FaceAnchor.fromWire(map.string("anchor", "center")),
            )
        }
    }
}

/**
 * StandardMessageCodec шлёт int как [Int], double как [Double] — читаем через [Number].
 */
internal fun Map<*, *>.float(key: String, default: Float): Float {
    val value = this[key]
    return if (value is Number) value.toFloat() else default
}

internal fun Map<*, *>.string(key: String, default: String): String {
    val value = this[key]
    return if (value is String && value.isNotBlank()) value else default
}

/**
 * FRONT_CAMERA в sessionFeatures только *разрешает* селфи-камеру.
 * Пока не выбрать FRONT [CameraConfig], сессия остаётся на задней камере
 * и `MESH3D` не даёт лиц.
 *
 * SceneView ожидает `(Session) -> CameraConfig` без null — при отсутствии
 * фронтальной конфигурации возвращаем текущую, чтобы сессия не упала.
 */
internal fun selectFrontCameraConfig(session: Session): CameraConfig {
    val filter = CameraConfigFilter(session)
    filter.facingDirection = CameraConfig.FacingDirection.FRONT
    return session.getSupportedCameraConfigs(filter).firstOrNull()
        ?: session.cameraConfig
}
