import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Standard Android release-signing setup per
// https://docs.flutter.dev/deployment/android#signing-the-app.
// Credentials live in `android/key.properties` (gitignored). Template
// at `android/key.properties.example`. If the file is missing, release
// builds fall back to the debug signing config so `flutter run --release`
// still works — but those APKs are not distributable.
val keystoreProperties = Properties().apply {
    val propsFile = rootProject.file("key.properties")
    if (propsFile.exists()) {
        load(FileInputStream(propsFile))
    }
}
val hasReleaseKeystore = !keystoreProperties.getProperty("storeFile").isNullOrBlank()

android {
    namespace = "dev.digitalgrease.signet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "dev.digitalgrease.signet"
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // F-Droid's APK scanner flags AGP 8.5+'s "Dependency metadata"
    // signing block as an extra signature anomaly. Disable to keep the
    // signature surface clean. Play Console accepts AABs without this
    // block (it's metadata for Play Console's app-bundle integrity
    // tooling, not a hard requirement).
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    // Per-ABI versionCode override for F-Droid distribution.
    //
    // F-Droid wants per-ABI APK splits with distinct versionCodes so
    // each architecture installs the slimmest binary that runs on it.
    // The convention (per fdroiddata's templates/build-flutter.yml and
    // adopted by app.bitbag, com.carriez.flutter_hbb, etc.):
    //
    //   final-versionCode = pubspec-versionCode * 10 + abi-suffix
    //
    // Suffix mapping: armeabi-v7a=1, arm64-v8a=2, x86_64=3.
    //
    // The override only fires for outputs that have an ABI filter,
    // i.e. APK builds with `--split-per-abi`. AAB builds (universal,
    // sent to Play) have no ABI filter, so the override doesn't
    // apply and the AAB ships with the unmodified pubspec versionCode.
    // This means Play and F-Droid versionCode lineages diverge after
    // v0.3.2: Play stays on 30001, 30002, 30003 (small numbers); F-Droid
    // sees 300021, 300022, 300023, 300031, ... (each pubspec value *10
    // + ABI suffix). Both lineages are independently monotonic.
    val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
    applicationVariants.configureEach {
        val variant = this
        variant.outputs.forEach { output ->
            val abiVersionCode = abiCodes[
                output.filters.find { it.filterType == "ABI" }?.identifier
            ]
            if (abiVersionCode != null) {
                (output as ApkVariantOutputImpl).versionCodeOverride =
                    variant.versionCode * 10 + abiVersionCode
            }
        }
    }
}

flutter {
    source = "../.."
}
