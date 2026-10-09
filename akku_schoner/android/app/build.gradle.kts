plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Nur diese Datei ist eingecheckt; den Rest von android/ erzeugt der Workflow
// per `flutter create` (überschreibt vorhandene Dateien nicht).
android {
    namespace = "de.klaas.akku_schoner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "de.klaas.akku_schoner"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Fester Signaturschlüssel (derselbe wie beim Parkplatz-Merker), damit sich
    // jede neue APK als Update über die alte installieren lässt. Die Datei ist
    // passwortgeschützt; das Passwort liegt nur als GitHub-Secret
    // MERKER_KEYSTORE_PASSWORD vor. Fehlt es (z. B. lokal), wird mit dem
    // Debug-Schlüssel signiert.
    val keystorePassword = System.getenv("MERKER_KEYSTORE_PASSWORD")
    signingConfigs {
        create("release") {
            storeFile = file("../../../spotify_merker_android/android/app/merker-release.p12")
            storeType = "pkcs12"
            storePassword = keystorePassword
            keyAlias = "merker"
            keyPassword = keystorePassword
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePassword.isNullOrEmpty()) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
