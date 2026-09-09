package com.alamat.test_google_mlkit.arcore

/**
 * Метрическая калибровка GLB-очков для ARCore Augmented Faces.
 *
 * Единица ARCore — метр. Origin модели должен совпасть с выбранным якорем
 * (`centerPose` за переносицей или `NOSE_TIP`). Offset/rotation — локальные
 * к этому pose, не к экрану.
 *
 * Дефолты подобраны под фактический AABB `assets/sunglasses.glb`
 * (ширина 1.304 / высота 0.422 / глубина 1.080 в исходных единицах модели,
 * заушники уходят в -Z). Авторский pivot GLB уже стоит на переносице, поэтому
 * [keepAuthoredPivot] = true по умолчанию — `centerOrigin` пересчитывать не нужно.
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
    // Авторский pivot GLB (на переносице) вместо центра AABB — см. calibration-defaults в плане.
    val keepAuthoredPivot: Boolean,
    // Depth-occluder сетки лица выключен по умолчанию: приоритет отрисовки не задан,
    // а материалы GLB (линзы/накладки) используют alphaMode=BLEND — порядок надо разбирать отдельно.
    val occlusionEnabled: Boolean,
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
                offsetY = map.float("offsetY", 0.012f),
                offsetZ = map.float("offsetZ", 0.03f),
                rotationX = map.float("rotationX", 0f),
                rotationY = map.float("rotationY", 0f),
                rotationZ = map.float("rotationZ", 0f),
                anchor = FaceAnchor.fromWire(map.string("anchor", "center")),
                keepAuthoredPivot = map.bool("keepAuthoredPivot", true),
                occlusionEnabled = map.bool("occlusionEnabled", false),
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

internal fun Map<*, *>.bool(key: String, default: Boolean): Boolean {
    val value = this[key]
    return if (value is Boolean) value else default
}
