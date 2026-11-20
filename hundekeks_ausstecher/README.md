# Hundekeks-Ausstecher

Web-App, die aus einem Hundefoto (Gesicht frontal, Profil oder ganzer Hund) zwei 3D-Druckteile erzeugt:

- **Ausstecher** in der Silhouette des Hundes (Schneide + Griffrand)
- **Prägestempel** mit Augen, Nase, Ohren, Fellzeichnung und optional Name (schon gespiegelt)

Export: ZIP mit zwei STL-Dateien. Alles läuft lokal im Browser, das Foto wird nirgends hochgeladen.

- `app.html` – Quelltext (Artifact-Fassung ohne `<html>`-Gerüst)
- `build.sh` – erzeugt daraus `docs/hundekeks/index.html` (GitHub Pages)

## Android-App

`android/` enthält eine kleine WebView-App, die die Seite offline mitbringt (three.js liegt in `android/vendor/`).
Fotos kommen über die Galerie oder per „Teilen → Hundekeks“, das ZIP wird über „Speichern unter“ abgelegt.

Bauen (ohne Gradle, nur Android-Build-Tools): `ANDROID_SDK=/pfad/zum/sdk android/build_apk.sh <versionCode>`
Benötigt `platforms;android-34` und `build-tools;35.0.0`. Ergebnis: `android/Hundekeks.apk`.
Der Signaturschlüssel `android/hundekeks.p12` liegt bewusst im Repo, damit neue Versionen als Update installiert werden können.
