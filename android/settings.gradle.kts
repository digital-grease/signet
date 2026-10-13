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
    id("com.android.application") version "9.2.1" apply false
    // Not applied to any module (built-in Kotlin), but load-bearing: it puts
    // KGP 2.4.21 on the settings classpath, which AGP 9's built-in Kotlin
    // then uses instead of its own older default (2.3.x).
    id("org.jetbrains.kotlin.android") version "2.4.21" apply false
}

include(":app")
