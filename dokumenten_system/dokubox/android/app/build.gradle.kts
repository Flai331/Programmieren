plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "de.flai.dokubox"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Benötigt von flutter_local_notifications (java.time-Backport).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "de.flai.dokubox"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Fester Signaturschlüssel, damit sich jede neue APK als Update über die
    // alte installieren lässt (Daten bleiben erhalten). Die Datei ist
    // passwortgeschützt; das Passwort liegt nur als GitHub-Secret
    // DOKUBOX_KEYSTORE_PASSWORD vor. Fehlt es (z. B. lokal), wird mit dem
    // Debug-Schlüssel signiert.
    val keystorePassword = System.getenv("DOKUBOX_KEYSTORE_PASSWORD")
    signingConfigs {
        create("release") {
            storeFile = file("dokubox-release.p12")
            storeType = "pkcs12"
            storePassword = keystorePassword
            keyAlias = "dokubox"
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
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
