pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // SceneView 4.30 собран с Kotlin 2.4.x — версии плагинов должны совпадать.
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
    // Compose Compiler — отдельный плагин Kotlin 2.x; версия должна совпадать с Kotlin.
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.10" apply false
}

include(":app")
