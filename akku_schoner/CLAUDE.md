# Akku-Schoner – Hinweise für Claude

- Flutter-App ohne Plugins; alles Native über den MethodChannel `akku_schoner/native` (`lib/native.dart` ↔ `MainActivity.kt`).
- `lib/logic.dart` – reine Logik (Modelle, Sortierung, Kandidaten, Hinweise), getestet in `test/logic_test.dart`.
- Kotlin (`android/app/src/main/kotlin/de/klaas/akku_schoner/`):
  `Policy` (Stufen keep/soft/full nach Nutzungstagen – einzige Quelle der Regel), `Apps` (Liste, Nutzungsdaten, Stufe, sanft beenden, geschützte Pakete), `ForceStopService` (Bedienungshilfe,
  Ablauf vom Parkplatz-Merker übernommen, prüft danach `FLAG_STOPPED`), `WatcherService` (Vordergrunddienst
  `specialUse`: Akku-Wächter + Automatik bei Bildschirm aus/Entsperren), `BatteryInfo`, `Prefs`, `BootReceiver`.
- Eingecheckt sind nur `build.gradle.kts`, Manifest, Kotlin und `res/xml`, `res/values/strings.xml`;
  den Rest von `android/` erzeugt der Workflow per `flutter create` (überschreibt nichts).
- Signatur wie Laufplan/Parkplatz-Merker (`MERKER_KEYSTORE_PASSWORD`).
- Kein Android-SDK im Container: Kotlin kompiliert erst GitHub Actions (`akku-schoner-apk.yml`).
- Texte Deutsch, Anrede „du“. Neue Funktionen auch in der Hilfe (`HelpPage` in `lib/save_page.dart`) und im README erklären.
- Sicherheit: Startbildschirm, Tastatur und die App selbst nie beenden; System-Apps automatisch „keep“.
- Musik-Apps (Spotify) höchstens „soft“: nach „Beenden erzwingen“ startet Play am Kopfhörer sie nicht mehr.
- Nutzer hat ein Samsung-Handy.
