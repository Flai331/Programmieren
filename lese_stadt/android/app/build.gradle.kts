plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.klaasotte.lese_stadt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.klaasotte.lese_stadt"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Fester Signaturschlüssel, damit sich jede neue APK als Update über die
    // alte installieren lässt (sonst gehen beim Neuinstallieren die Lesedaten
    // verloren). Die Datei ist passwortgeschützt; das Passwort liegt nur als
    // GitHub-Secret LESE_STADT_KEYSTORE_PASSWORD vor. Fehlt es (z. B. lokal),
    // wird mit dem Debug-Schlüssel signiert.
    val keystorePassword = System.getenv("LESE_STADT_KEYSTORE_PASSWORD")
    signingConfigs {
        create("release") {
            storeFile = file("lese-stadt-release.p12")
            storeType = "pkcs12"
            storePassword = keystorePassword
            keyAlias = "lesestadt"
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
