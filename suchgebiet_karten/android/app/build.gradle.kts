plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "de.klaas.suchgebiet"
    compileSdk = 35

    defaultConfig {
        applicationId = "de.klaas.suchgebiet"
        minSdk = 24
        targetSdk = 34
        // Fortlaufende Versionsnummer aus dem CI (-PversionCode=...), damit jede APK ein Update ist
        versionCode = (project.findProperty("versionCode") as String?)?.toInt() ?: 1
        versionName = "1.0." + versionCode
        // Release-Tag, aus dem sich die App aktualisiert (-PupdateTag=... im CI); leer = kein Update-Check
        val updateTag = ((project.findProperty("updateTag") as String?) ?: "").replace("\"", "")
        buildConfigField("String", "UPDATE_TAG", "\"$updateTag\"")
    }

    buildFeatures {
        buildConfig = true
    }

    // Die App zeigt die Web-App aus suchgebiet_karten/web – keine doppelte Pflege.
    sourceSets["main"].assets.srcDirs("../../web")

    // Fester Signaturschlüssel (derselbe wie bei den anderen Apps), damit sich jede neue
    // APK als Update installieren lässt. Passwort nur als GitHub-Secret
    // MERKER_KEYSTORE_PASSWORD; fehlt es (z. B. lokal), wird mit dem Debug-Schlüssel signiert.
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
            isMinifyEnabled = false
            signingConfig = if (keystorePassword.isNullOrEmpty()) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("androidx.webkit:webkit:1.12.1")
}
