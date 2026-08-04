# Riegel — Fehlermeldesystem: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fehlerberichte aus der App landen samt Riegel-Zustand direkt in der Notion-Datenbank „🐛 Fehlerberichte Riegel".

**Architecture:** Das vorhandene Paket `Programmieren\feedback` wird als Pfad-Abhängigkeit eingebunden — dieselbe Quelle wie in den anderen Apps, kein Nachbau. Es schickt an Notion und fällt bei Fehlschlag automatisch auf E-Mail zurück. Neu ist nur die Zulieferung: eine native Diagnose-Funktion liefert den Sperrzustand, damit ein Bericht die Frage „was war eingestellt?" von selbst beantwortet.

**Tech Stack:** Flutter 3.44 / Dart 3.12, Kotlin (JVM 17), Paket `feedback` 0.2.0.

**Projekt:** `C:\Users\klaas\Desktop\Programmieren\nfc_riegel`
**Branch:** `feature/nfc-riegel`

---

## Vorbedingungen — bereits erledigt, nicht erneut anlegen

- Notion-Datenbank `d1dc9af960734132b96d3a08c3d3ce9b`, Schema passt zum Paket
- Integration hat Lese- und Schreibzugriff, mit `curl` geprüft
- `lib/secrets.dart` liegt lokal mit dem Token und steht in `.gitignore`
- `lib/secrets.template.dart` ist committet

`secrets.dart` **nicht** ins Repo aufnehmen und **nicht** verändern.

## Prüf-Kommandos

```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
```

| Zweck | Kommando |
|---|---|
| Dart-Analyse | `flutter analyze` |
| Dart-Tests | `flutter test` |
| Kotlin-Tests | `android/gradlew.bat -p android testDebugUnitTest` |

**Ausgangslage:** 67 Kotlin-Tests, 8 Dart-Tests, `flutter analyze` sauber.

---

### Task 1: Abhängigkeit und Build-Nummer

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/build_info.dart`

- [ ] **Step 1: Paket eintragen**

In `pubspec.yaml` den `dependencies`-Block ergänzen:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  installed_apps: ^1.5.2
  permission_handler: ^11.3.1
  feedback:
    path: ../feedback
```

- [ ] **Step 2: Build-Nummer anlegen**

`lib/build_info.dart`:

```dart
/// Wird bei jeder Veröffentlichung von Hand erhöht und in `pubspec.yaml`
/// gespiegelt. Erscheint in jedem Fehlerbericht.
const int kBuildNumber = 1;
```

- [ ] **Step 3: Abhängigkeiten holen und prüfen**

```bash
cd "/c/Users/klaas/Desktop/Programmieren/nfc_riegel"
flutter pub get
flutter analyze
```

Erwartet: `flutter pub get` läuft durch, `flutter analyze` meldet `No issues found!`.

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/pubspec.yaml nfc_riegel/pubspec.lock nfc_riegel/lib/build_info.dart
git commit -m "chore: Feedback-Paket eingebunden"
```

---

### Task 2: Diagnose nativ erheben

Der Zustand, der einen Riegel-Bericht überhaupt auswertbar macht.

**Files:**
- Create: `android/app/src/main/kotlin/com/klaas/nfc_riegel/Diagnostics.kt`
- Test: `android/app/src/test/kotlin/com/klaas/nfc_riegel/DiagnosticsTest.kt`

- [ ] **Step 1: Failing Test schreiben**

`android/app/src/test/kotlin/com/klaas/nfc_riegel/DiagnosticsTest.kt`:

```kotlin
package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DiagnosticsTest {

    private val now = 1_000_000L

    private val arbeit = Profile(
        id = "p1",
        name = "Arbeit",
        blockedPackages = setOf("com.a", "com.b"),
        defaultMode = LockMode.TIMER,
        durationMinutes = 45,
    )
    private val nacht = Profile(id = "p2", name = "Nacht", defaultMode = LockMode.OPEN)

    @Test
    fun `ohne Sperre steht offen im Bericht`() {
        val state = LockState(profiles = listOf(arbeit, nacht))

        val lines = Diagnostics.summarize(state, now)

        assertEquals("offen", lines["Sperre"])
    }

    @Test
    fun `laufende Sperre nennt Profil und Ende`() {
        val state = LockState(
            profiles = listOf(arbeit),
            chipLock = ChipLock("p1", LockMode.TIMER, now + 60_000),
        )

        val lines = Diagnostics.summarize(state, now)

        assertTrue(lines["Sperre"]!!.contains("Arbeit"))
        assertTrue(lines["Sperre"]!!.contains("TIMER"))
    }

    @Test
    fun `abgelaufene Sperre gilt als offen`() {
        val state = LockState(
            profiles = listOf(arbeit),
            chipLock = ChipLock("p1", LockMode.TIMER, now - 1),
        )

        assertEquals("offen", Diagnostics.summarize(state, now)["Sperre"])
    }

    @Test
    fun `Profile werden mit App-Anzahl und Modus aufgelistet`() {
        val state = LockState(profiles = listOf(arbeit, nacht))

        val profile = Diagnostics.summarize(state, now)["Profile"]!!

        assertTrue(profile.contains("Arbeit"))
        assertTrue(profile.contains("2 Apps"))
        assertTrue(profile.contains("TIMER"))
        assertTrue(profile.contains("Nacht"))
    }

    @Test
    fun `Chips werden mit Profil und Generalschluessel-Merkmal aufgelistet`() {
        val state = LockState(
            profiles = listOf(arbeit),
            tags = listOf(
                TagBinding("04AA", "Schreibtisch", "p1"),
                TagBinding("04BB", "Bund", "p1", isMaster = true),
            ),
        )

        val chips = Diagnostics.summarize(state, now)["Chips"]!!

        assertTrue(chips.contains("Schreibtisch"))
        assertTrue(chips.contains("Bund"))
        assertTrue(chips.contains("General"))
    }

    @Test
    fun `keine Chips wird ausdruecklich gemeldet`() {
        val state = LockState(profiles = listOf(arbeit))

        assertEquals("keine", Diagnostics.summarize(state, now)["Chips"])
    }

    @Test
    fun `Notfall-Code-Status steht drin`() {
        val ohne = LockState(profiles = listOf(arbeit))
        val mit = LockState(profiles = listOf(arbeit), codeHash = "abc")

        assertEquals("nein", Diagnostics.summarize(ohne, now)["Notfall-Code"])
        assertEquals("ja", Diagnostics.summarize(mit, now)["Notfall-Code"])
    }

    @Test
    fun `Bericht enthaelt keine UIDs und keine Hashes`() {
        val state = LockState(
            profiles = listOf(arbeit),
            tags = listOf(TagBinding("04AABBCC", "Schreibtisch", "p1")),
            codeHash = "geheimerhash",
        )

        val text = Diagnostics.summarize(state, now).values.joinToString(" ")

        assertTrue(!text.contains("04AABBCC"))
        assertTrue(!text.contains("geheimerhash"))
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
android/gradlew.bat -p android testDebugUnitTest --tests "*DiagnosticsTest*"
```

Erwartet: Kompilierfehler, `Unresolved reference: Diagnostics`.

- [ ] **Step 3: Diagnostics schreiben**

`android/app/src/main/kotlin/com/klaas/nfc_riegel/Diagnostics.kt`:

```kotlin
package com.klaas.nfc_riegel

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Fasst den Sperrzustand für einen Fehlerbericht zusammen.
 *
 * Bewusst ohne Tag-UIDs und ohne den Hash des Notfall-Codes: ein Bericht wandert
 * in eine Notion-Datenbank, und beides wäre dort ein Schlüssel zur Wohnung.
 * Paketnamen bleiben drin — ohne sie ist ein Blockier-Fehler nicht zu deuten.
 */
object Diagnostics {

    fun summarize(state: LockState, now: Long): Map<String, String> {
        val lock = state.chipLock?.takeIf { l ->
            val endsAt = l.endsAt
            endsAt == null || now < endsAt
        }

        val lockLine = if (lock == null) {
            "offen"
        } else {
            val name = state.profileById(lock.profileId)?.name ?: "unbekanntes Profil"
            val ende = lock.endsAt?.let {
                " bis " + SimpleDateFormat("dd.MM. HH:mm", Locale.GERMANY).format(Date(it))
            } ?: ""
            "gesperrt · $name · ${lock.mode.name}$ende"
        }

        val profiles = if (state.profiles.isEmpty()) "keine"
        else state.profiles.joinToString(" | ") { p ->
            val ende = p.untilAt?.let {
                " bis " + SimpleDateFormat("dd.MM. HH:mm", Locale.GERMANY).format(Date(it))
            } ?: ""
            "${p.name}: ${p.blockedPackages.size} Apps, ${p.defaultMode.name}, " +
                "${p.durationMinutes} min$ende"
        }

        val chips = if (state.tags.isEmpty()) "keine"
        else state.tags.joinToString(" | ") { t ->
            val profil = state.profileById(t.profileId)?.name ?: "?"
            "${t.label} → $profil${if (t.isMaster) " (General)" else ""}"
        }

        val packages = state.profiles
            .flatMap { it.blockedPackages }
            .distinct()
            .sorted()
            .joinToString(", ")
            .ifEmpty { "keine" }

        return linkedMapOf(
            "Sperre" to lockLine,
            "Profile" to profiles,
            "Chips" to chips,
            "Gesperrte Pakete" to packages,
            "Notfall-Code" to if (state.codeHash != null) "ja" else "nein",
        )
    }
}
```

- [ ] **Step 4: Test laufen lassen**

```bash
android/gradlew.bat -p android testDebugUnitTest
```

Erwartet: `BUILD SUCCESSFUL`, 8 neue Tests, insgesamt **75**.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Diagnose des Sperrzustands fuer Fehlerberichte"
```

---

### Task 3: Diagnose über den Kanal reichen

**Files:**
- Modify: `android/app/src/main/kotlin/com/klaas/nfc_riegel/RiegelChannel.kt`

- [ ] **Step 1: Kanal-Methode ergänzen**

In `RiegelChannel.kt` im `when`-Block vor dem `else`-Zweig einfügen:

```kotlin
                "getDiagnostics" -> {
                    val map = Diagnostics.summarize(
                        controller.engine.state(),
                        System.currentTimeMillis(),
                    ).toMutableMap()
                    map["Bedienungshilfe"] = if (isAccessibilityEnabled()) "an" else "AUS"
                    map["Geräteadministrator"] =
                        if (devicePolicyManager().isAdminActive(adminComponent())) "an" else "aus"
                    map["Benachrichtigungen"] = notificationPermissionState()
                    map["Android"] = "SDK ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE})"
                    result.success(map)
                }
```

Und am Ende der Klasse, vor dem `companion object`:

```kotlin
    /**
     * Seit Android 13 ist POST_NOTIFICATIONS eine Laufzeit-Berechtigung. Fehlt sie,
     * verschwindet die Sperr-Benachrichtigung lautlos — im Bericht muss das stehen.
     */
    private fun notificationPermissionState(): String =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            "nicht nötig"
        } else if (
            activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            "erlaubt"
        } else {
            "VERWEIGERT"
        }
```

Import ergänzen:

```kotlin
import android.os.Build
```

- [ ] **Step 2: Kompilieren**

```bash
android/gradlew.bat -p android compileDebugKotlin
```

Erwartet: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/android/app/src
git commit -m "feat: Diagnose ueber den MethodChannel"
```

---

### Task 4: Dart-Anbindung

**Files:**
- Modify: `lib/riegel_channel.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Kanal-Client ergänzen**

In `lib/riegel_channel.dart` vor der schließenden Klammer der Klasse:

```dart
  /// Zustand für Fehlerberichte. Enthält keine Tag-UIDs und keinen Code-Hash.
  Future<Map<String, String>> getDiagnostics() async {
    final map =
        await channel.invokeMethod<Map<dynamic, dynamic>>('getDiagnostics');
    return (map ?? const {})
        .map((key, value) => MapEntry(key.toString(), value.toString()));
  }
```

- [ ] **Step 2: main.dart erweitern**

`lib/main.dart` vollständig ersetzen durch:

```dart
import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'build_info.dart';
import 'home_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';
import 'secrets.dart';
import 'setup_wizard.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FeedbackService.configure(
    notionToken: Secrets.notionToken,
    notionDbId: Secrets.notionDatabaseId,
    appName: 'Riegel',
    supportEmail: Secrets.supportEmail,
    buildNumber: kBuildNumber,
  );
  FeedbackService.setNavigatorKey(navigatorKey);

  // Abstürze im Widget-Baum landen im Protokoll und öffnen den Melde-Dialog.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FeedbackService.setLastStackTrace(details.stack.toString());
    FeedbackService.log('Flutter-Fehler: ${details.exceptionAsString()}');
    FeedbackService.showAutoErrorDialog();
  };

  // Alles, was außerhalb des Widget-Baums fliegt.
  PlatformDispatcher.instance.onError = (error, stack) {
    FeedbackService.setLastStackTrace(stack.toString());
    FeedbackService.log('Fehler: $error');
    FeedbackService.showAutoErrorDialog();
    return true;
  };

  runApp(const RiegelApp());
}

class RiegelApp extends StatelessWidget {
  const RiegelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riegel',
      navigatorKey: navigatorKey,
      navigatorObservers: [FeedbackService.screenObserver],
      theme: buildRiegelTheme(),
      home: const _Entry(),
    );
  }
}

/// Entscheidet beim Start zwischen Einrichtung und Hauptscreen.
class _Entry extends StatefulWidget {
  const _Entry();

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  final _channel = const RiegelChannel();
  LockStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await _channel.getState();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Scaffold(
        backgroundColor: RiegelColors.bgBase,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return status.setupComplete
        ? const HomeScreen()
        : SetupWizard(onFinished: _load);
  }
}
```

- [ ] **Step 3: Prüfen**

```bash
flutter analyze
flutter test
```

Erwartet: `No issues found!`, 8 Tests grün.

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/lib
git commit -m "feat: Feedback-Dienst und globale Fehlerbehandlung"
```

---

### Task 5: Einstieg in der Oberfläche

**Files:**
- Modify: `lib/home_screen.dart`

- [ ] **Step 1: Melde-Knopf und Zustands-Zulieferung ergänzen**

In `lib/home_screen.dart` die Importe ergänzen:

```dart
import 'package:feedback/feedback.dart';
```

In `_HomeScreenState` eine Methode ergänzen:

```dart
  /// Vor dem Öffnen des Dialogs den aktuellen Sperrzustand anhängen — sonst
  /// steht im Bericht nur, dass etwas nicht ging, aber nicht bei welcher
  /// Einstellung.
  Future<void> _reportProblem() async {
    final diagnostics = await widget.channel.getDiagnostics();
    for (final entry in diagnostics.entries) {
      FeedbackService.setSnapshot(entry.key, entry.value);
    }
    if (!mounted) return;
    await FeedbackService.showReportDialog(context);
  }
```

Die `AppBar` im `build` ersetzen durch:

```dart
      appBar: AppBar(
        title: const Text('Riegel'),
        actions: [
          IconButton(
            tooltip: 'Fehler melden',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: _reportProblem,
          ),
        ],
      ),
```

- [ ] **Step 2: Prüfen**

```bash
flutter analyze
flutter test
```

Erwartet: `No issues found!`, 8 Tests grün. Der bestehende `home_screen_test` kennt `getDiagnostics` nicht — er ruft die Methode aber auch nicht auf, der gefälschte Kanal liefert für unbekannte Methoden `null`, und das wird nur beim Antippen des Knopfes gebraucht.

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/lib
git commit -m "feat: Fehler-melden-Knopf im Hauptscreen"
```

---

### Task 6: Bauen und ablegen

**Files:**
- Modify: `GERAETETEST.md`

- [ ] **Step 1: Checkliste ergänzen**

An `GERAETETEST.md` anhängen:

```markdown
## Fehlermeldesystem

- [ ] Käfer-Symbol oben rechts öffnet den Melde-Dialog
- [ ] Bericht mit Beschreibung abschicken → Erfolgsmeldung
- [ ] Eintrag erscheint in der Notion-Datenbank „🐛 Fehlerberichte Riegel"
- [ ] Im Eintrag stehen unter Protokoll: Sperre, Profile, Chips, Bedienungshilfe, Benachrichtigungen, Android-Version
- [ ] Im Eintrag stehen **keine** Tag-UIDs und kein Code-Hash
- [ ] Flugmodus an, Bericht abschicken → E-Mail-App öffnet sich als Rückfall
```

- [ ] **Step 2: Alles prüfen**

```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
flutter analyze
flutter test
android/gradlew.bat -p android testDebugUnitTest
```

Erwartet: `No issues found!`, 8 Dart-Tests, 75 Kotlin-Tests.

- [ ] **Step 3: Release bauen und ablegen**

```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk \
   "/c/Users/klaas/Desktop/Programmieren/APKs/Android/Riegel.apk"
```

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/klaas/Desktop/Programmieren"
git add nfc_riegel/GERAETETEST.md
git commit -m "docs: Geraetetest um Fehlermeldesystem ergaenzt"
```

---

## Abschluss

- `flutter analyze` sauber, 8 Dart-Tests, 75 Kotlin-Tests
- `Riegel.apk` neu in `APKs\Android`
- Ein Bericht aus der App landet in Notion, samt Sperrzustand
- Gerätetest offen

## Bewusst nicht enthalten

- Die fehlende Abfrage der Benachrichtigungs-Berechtigung. Sie wird im Bericht
  jetzt **angezeigt**, aber noch nicht **angefordert** — das gehört zur nächsten
  Ausbaustufe zusammen mit der zeitgesteuerten Sperre.
- Telegram- und Backend-Kanal des Pakets bleiben unkonfiguriert.
