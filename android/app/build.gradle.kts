import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// GOOGLE_MAPS_KEY para el meta-data nativo de AndroidManifest.xml (el SDK de
// Maps lo lee antes de que arranque Dart, así que no puede venir de
// --dart-define). Se resuelve, en orden:
//   1) variable de entorno GOOGLE_MAPS_KEY (la usa también CI), o
//   2) el archivo .env en la raíz del repo (mismo archivo que alimenta
//      --dart-define-from-file=.env para el lado Dart — ver docs/setup_env.md).
// Antes la key estaba pegada literal en AndroidManifest.xml.
val repoEnvFile = rootProject.file("../.env")
val repoEnvProperties = Properties().apply {
    if (repoEnvFile.exists()) {
        FileInputStream(repoEnvFile).use { load(it) }
    }
}
val googleMapsKey: String =
    System.getenv("GOOGLE_MAPS_KEY") ?: repoEnvProperties.getProperty("GOOGLE_MAPS_KEY") ?: ""

android {
    namespace = "pe.lleva.app"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "pe.lleva.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_KEY"] = googleMapsKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
