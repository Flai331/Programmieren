import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signatur für Veröffentlichungen.
//
// Android lässt eine installierte App nur durch ein Paket mit DERSELBEN
// Signatur ersetzen. Ohne festen Schlüssel erzeugt sich jeder Bau-Rechner
// seinen eigenen Debug-Schlüssel – zwei Bauten derselben App könnten sich
// dann gegenseitig nicht aktualisieren, und genau das macht einen
// Aktualisierungsknopf in der App unmöglich.
//
// `android/key.properties` liegt NICHT im Repository (siehe .gitignore); die
// CI schreibt sie aus den Repo-Secrets. Fehlt sie, fällt der Bau auf die
// Debug-Signatur zurück: Ein lokales `flutter build` läuft damit weiter, das
// Ergebnis kann aber keine vorhandene Installation ersetzen.
val signaturDatei = rootProject.file("key.properties")
val signatur = Properties().apply {
    if (signaturDatei.exists()) {
        FileInputStream(signaturDatei).use { load(it) }
    }
}
val eigeneSignatur = signatur.getProperty("storeFile") != null

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

    signingConfigs {
        if (eigeneSignatur) {
            create("veroeffentlichung") {
                // Der Pfad gilt ab diesem Modul-Ordner (android/app).
                storeFile = file(signatur.getProperty("storeFile"))
                storePassword = signatur.getProperty("storePassword")
                keyAlias = signatur.getProperty("keyAlias")
                keyPassword = signatur.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Keine x86_64-Bibliotheken ins Paket. Das ist nicht dasselbe
            // wie `--target-platform` beim Bau-Befehl, und beides ist
            // nötig:
            //
            //   --target-platform  bestimmt, welche Flutter-Engine
            //                      eingepackt wird
            //   abiFilters         bestimmt, welche nativen Bibliotheken
            //                      der Pakete (ML Kit, sqflite …) aus
            //                      ihren AARs mitkommen
            //
            // Gemessen: Mit `--target-platform` allein blieben in Build 14
            // noch 11,2 MB lib/x86_64 übrig — die Engine war weg, die
            // Pakete nicht. Auf einem Handy ist das durchweg toter Ballast.
            //
            // Nur hier, nicht in defaultConfig: Ein Debug-Bau soll weiter
            // alle Architekturen enthalten, damit er im Emulator läuft.
            ndk {
                abiFilters += listOf("arm64-v8a", "armeabi-v7a")
            }

            signingConfig = if (eigeneSignatur) {
                signingConfigs.getByName("veroeffentlichung")
            } else {
                // Kein Schlüssel hinterlegt: bauen ja, ersetzen nein.
                signingConfigs.getByName("debug")
            }
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

dependencies {
    // Für androidx.core.content.FileProvider in MainActivity.kt. Die
    // Flutter-Einbettung zieht androidx.core zwar mit herein, aber als
    // durchgereichte Abhängigkeit — darauf zu bauen heißt, dass der Bau
    // bricht, sobald Flutter daran etwas ändert. Gradle nimmt ohnehin die
    // höchste geforderte Fassung, diese Zeile kann also nichts verdrängen.
    implementation("androidx.core:core:1.13.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
