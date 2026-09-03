import java.util.Properties

// Eigener Release-Schlüssel statt des Debug-Schlüssels von Android Studio.
// Der Debug-Schlüssel gehört dem Werkzeug, nicht dem Projekt: bei einer
// Neuinstallation von Android Studio wird er neu erzeugt, und danach lehnt
// Android jedes Update mit „App nicht installiert" ab.
//
// Datei und Passwort liegen außerhalb des Projektverzeichnisses und sind
// zusätzlich über .gitignore ausgeschlossen. Geht der Keystore verloren, lässt
// sich die App nie wieder aktualisieren — nur noch frisch installieren.
val keystoreProperties = Properties().apply {
    val datei = rootProject.file("key.properties")
    if (datei.exists()) datei.inputStream().use { load(it) }
}

// Der Rückfall auf den Debug-Schlüssel darf nicht stillschweigend passieren:
// eine so signierte APK lässt sich nicht über eine bestehende Installation
// legen, und der Geräteadministrator verweigert die dann nötige Deinstallation.
if (keystoreProperties.getProperty("storeFile") == null) {
    logger.warn(
        "Riegel: key.properties fehlt - es wird mit dem Debug-Schluessel signiert. " +
            "Diese APK laesst sich nicht ueber eine bestehende Installation legen.",
    )
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.klaas.nfc_riegel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.klaas.nfc_riegel"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keystoreProperties.getProperty("storeFile")?.let {
                storeFile = file(it)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Fehlt key.properties — etwa auf einem frisch geklonten Rechner —
        // bleibt es beim Debug-Schlüssel, damit der Build nicht scheitert.
        val schluessel = if (keystoreProperties.getProperty("storeFile") != null) {
            signingConfigs.getByName("release")
        } else {
            signingConfigs.getByName("debug")
        }

        release {
            signingConfig = schluessel
        }

        // Derselbe Schlüssel auch für den Debug-Build. Sonst unterscheiden sich
        // die Signaturen, und Android verlangt beim Wechsel zwischen
        // `flutter run` und der abgelegten APK eine Deinstallation — die der
        // Geräteadministrator verweigert. Der Deinstallationsschutz stünde damit
        // jedem Update im Weg, obwohl er nur die Deinstallation meint.
        debug {
            signingConfig = schluessel
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
    testImplementation("junit:junit:4.13.2")
}
