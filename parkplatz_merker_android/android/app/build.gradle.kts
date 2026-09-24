plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.klaasotte.parkplatz_merker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.klaasotte.parkplatz_merker"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Fester Signaturschlüssel, damit sich jede neue APK als Update über die
    // alte installieren lässt. Die Datei ist passwortgeschützt; das Passwort
    // liegt nur als GitHub-Secret MERKER_KEYSTORE_PASSWORD vor. Fehlt es
    // (z. B. lokal), wird mit dem Debug-Schlüssel signiert.
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

dependencies {
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("androidx.core:core-ktx:1.16.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
