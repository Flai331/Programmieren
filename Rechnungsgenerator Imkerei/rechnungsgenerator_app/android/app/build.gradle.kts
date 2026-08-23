plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.klaasotte.beebrain"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        // Nötig für die resValue-Einträge in den Build-Typen weiter unten,
        // über die der App-Name je Variante gesetzt wird. Ab AGP 9 ist diese
        // Funktion standardmäßig abgeschaltet; ohne sie bricht die
        // Konfiguration ab mit „Build Type debug contains custom resource
        // values, but the feature is disabled".
        resValues = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.klaasotte.beebrain"
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

    buildTypes {
        release {
            // TODO: Eigenen Signaturschlüssel für Veröffentlichungen anlegen.
            // Vorerst mit dem Debug-Schlüssel, damit `flutter run --release`
            // funktioniert.
            signingConfig = signingConfigs.getByName("debug")
            resValue("string", "app_name", "BeeBrain")
        }
        debug {
            // Eigene Anwendungs-ID für Testbauten: Die App wird damit NEBEN
            // einer bereits installierten BeeBrain installiert und bekommt
            // einen eigenen Datenbestand.
            //
            // Ohne das würde ein Testbau die vorhandene App ersetzen und
            // deren Datenbank erben. Liegt die auf einer höheren
            // Schema-Version als dieser Stand kennt, bricht sqflite beim
            // Start ab – und die Daten wären nur noch über ein Backup
            // erreichbar.
            applicationIdSuffix = ".test"
            resValue("string", "app_name", "BeeBrain Test")
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
