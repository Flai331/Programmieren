# Regeln für alle Projekte unter Programmieren\

## Build-Ablage (immer!)

- Jede fertige **Windows-exe** (kompletter Release-Ordner: exe + DLLs + `data\`)
  nach `C:\Users\klaas\Desktop\Programmieren\APKs\Windows` kopieren.
  Installierte Apps liegen dort unter `Programmdateien\<AppName>\`,
  Verknüpfungen daneben. Läuft die App gerade, vorher Prozess beenden;
  danach über `explorer.exe <pfad>` neu starten (nicht direkt starten —
  AppData-Virtualisierung).
- Jede fertige **Android-apk** nach
  `C:\Users\klaas\Desktop\Programmieren\APKs\Android` kopieren.
  Dort liegt je App immer nur die NEUSTE apk — aeltere Versionen der App vorher loeschen.

## Android-Test im Emulator (immer!)

Jede Android-App, die testfertig ist, wird vor der Übergabe im Emulator
getestet — nicht nur gebaut.

- AVD: `Pixel_8_API_35` (Android 15, google_apis_playstore, x86_64)
- Starten:
  ```powershell
  & "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Pixel_8_API_35
  ```
  Im Hintergrund starten, dann auf Boot warten:
  ```powershell
  $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
  & $adb wait-for-device
  & $adb shell getprop sys.boot_completed   # muss 1 sein
  ```
- Deployen: `flutter run -d emulator-5554` bzw. `adb install -r <apk>`.
- Läuft schon ein Emulator (`adb devices`), diesen nutzen statt neu starten.
- `JAVA_HOME` ist systemweit leer/falsch — vor `sdkmanager`/`avdmanager`/Gradle
  auf `C:\Program Files\Android\Android Studio\jbr` setzen.
