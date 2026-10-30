# Plan v103: ⬇️ App aktualisiert sich selbst (APK) · Tipp ins Leere schließt Offenes

Mit Klaas abgestimmt (30.10.2026).

## 1. Selbst-Update der Android-App
Android erlaubt kein Update ganz ohne Tipp: Android zeigt immer sein „Aktualisieren?“-Fenster (1 Tipp „Installieren“),
beim allerersten Mal zusätzlich „Unbekannte Apps installieren“ erlauben. Daten bleiben erhalten (gleicher Schlüssel, versionCode steigt).

### CI (`.github/workflows/suchgebiet-karten-apk.yml`)
- Build mit `-PupdateTag=$TAG` (main → `suchgebiet-karten`, `claude/suchgebiet-beta` → `suchgebiet-karten-beta`, sonst leer).
- Beim Release zusätzlich `version.json` hochladen: `{"code": <run_number>, "name": "1.0.<run_number>", "at": "<ISO-Zeit>"}`
  (gleiche Upload-Zeile wie die APK, `--clobber`).

### Android (`android/app`)
- `build.gradle.kts`: `buildConfigField("String", "UPDATE_TAG", …)` aus `updateTag` (leer = kein Update-Check, z. B. lokale Builds).
- Manifest: `REQUEST_INSTALL_PACKAGES`. FileProvider ist da – `res/xml/file_paths.xml` um den Download-Ordner ergänzen.
- Neues `Updater.kt`:
  - `check()`: lädt `https://github.com/Flai331/Programmieren/releases/download/<UPDATE_TAG>/version.json`
    (Redirects folgen, Timeout 10 s, Fehler still ignorieren), vergleicht `code` mit `BuildConfig.VERSION_CODE`.
  - `download(code)`: lädt `Suchgebiet-Karten.apk` aus demselben Release in `cacheDir/update/` (Fortschritt an JS melden),
    prüft per `PackageManager.getPackageArchiveInfo`, dass Paketname gleich und versionCode > installiert ist.
  - `install()`: falls `!packageManager.canRequestPackageInstalls()` → Einstellung `ACTION_MANAGE_UNKNOWN_APP_SOURCES`
    für dieses Paket öffnen (Hinweis vorher in der Web-App), sonst Installer-Intent mit FileProvider-URI.
- Bridge (`AndroidBridge`): `updateCheck()`, `updateDownload()`, `updateInstall()`, `appVersion()`; Rückmeldungen an JS über
  `window.sgkUpdate({state: 'available'|'progress'|'ready'|'error'|'none', code, pct, msg})`.

### Web-App (`web/app.js`, nur wenn `AndroidBridge` vorhanden)
- **Bei jedem App-Start** automatisch prüfen (einige Sekunden nach dem Laden).
- **Im Einsatz unterdrücken**: Der Hinweis kommt nur, wenn **kein Einsatz offen** ist –
  EL: `isFree()` oder `isClosed()`; HF: kein Auftrag geladen. Ist gerade ein Einsatz offen, wird die verfügbare Version
  gemerkt und der Hinweis erscheint, sobald der Einsatz abgeschlossen/kein Einsatz mehr offen ist (oder beim nächsten Start ohne Einsatz).
- Hinweis-Dialog: „⬇️ Neue Version 1.0.N verfügbar (installiert 1.0.M). Jetzt aktualisieren? Daten bleiben erhalten.“
  → „Jetzt aktualisieren“ / „Später“ („Später“ = bis zum nächsten App-Start nicht wieder fragen).
- Ablauf nach „Jetzt“: Fortschritt „Lädt … 42 %“ → ggf. Hinweis „Android fragt jetzt einmalig, ob Suchgebiet-Karten
  Apps installieren darf – bitte erlauben und zurückkommen“ → Android-Installer. Fehler → Toast + Hinweis auf den Download-Link.
- Unter ⚙️ Mehr (bei „App herunterladen“): installierte Version anzeigen und Knopf **„⬇️ Nach Update suchen“** (immer
  erlaubt, auch im Einsatz – dann mit Warnung „Einsatz läuft – trotzdem aktualisieren?“).

## 2. Tipp ins Leere schließt, was offen ist
- Ist ein Fenster der Randleiste (`.panel`), das HF-Menü, die Team-Liste/Infofenster (v98), die Suchergebnisse oder ein
  kleines Info-Popup offen, schließt ein Tipp auf die **Karte bzw. eine leere Fläche** es.
  Dieser Tipp macht **nichts anderes** (kein Punkt setzen, kein Feld färben, kein Werkzeug auslösen).
- Dialoge (`openDlg`) mit „Abbrechen“/„Schließen“: Tipp auf den abgedunkelten Hintergrund = Abbrechen/Schließen.
  **Ausnahmen** (bleiben offen): Dringend-Dialog Fund/Hilfe, Warnungen vor dem Löschen/Ändern (🔒), Dialoge mit
  Texteingabe, in die schon etwas getippt wurde, laufende Vorgänge (QR-Scanner, PDF-Erzeugung, Update-Download).
- Umsetzung zentral (z. B. ein `pointerdown`-Listener in der Capture-Phase auf `document`, der prüft, ob außerhalb des
  offenen Elements getippt wurde, dann schließt und das Ereignis schluckt) statt in jedem Fenster einzeln.
  Bestehendes `onAnyTap` (Ungelesen-Liste, v98) einbeziehen, nicht doppeln.

## Tests
- Unit: Versionsvergleich/„Einsatz offen?“-Logik als reine Funktion (`shouldOfferUpdate({installed, latest, einsatzOffen, later})`).
- Playwright (Scratchpad `tapclose-e2e.mjs`, `update-e2e.mjs`, 1280×800 + 412×860, Screenshots ansehen):
  Fenster offen → Tipp auf Karte → zu, und es wurde nichts gezeichnet/gefärbt; Dialog → Hintergrund → Abbrechen;
  Dringend-Dialog bleibt; Update mit gemockter `AndroidBridge`: kein Einsatz → Dialog; Einsatz offen → kein Dialog,
  nach Abschließen → Dialog; „Später“; Knopf in Mehr.
- Android: `gradle assembleRelease` baut (CI), Emulator-Starttest bleibt grün; `version.json` erscheint im Release.
- Alle bisherigen Tests/E2E grün, Versionen v100.
