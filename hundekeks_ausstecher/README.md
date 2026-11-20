# Hundekeks-Ausstecher

Web-App, die aus einem Hundefoto (Gesicht frontal, Profil oder ganzer Hund) zwei 3D-Druckteile erzeugt:

- **Ausstecher** in der Silhouette des Hundes (Schneide + Griffrand)
- **Prägestempel** mit Augen, Nase, Ohren, Fellzeichnung und optional Name (schon gespiegelt)

Export: ZIP mit zwei STL-Dateien. Alles läuft lokal im Browser, das Foto wird nirgends hochgeladen.

- `app.html` – Quelltext (Artifact-Fassung ohne `<html>`-Gerüst)
- `build.sh` – erzeugt daraus `docs/hundekeks/index.html` (GitHub Pages)
