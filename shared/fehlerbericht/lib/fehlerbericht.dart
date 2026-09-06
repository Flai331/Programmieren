// ═══════════════════════════════════════════════════════════════════════
//  FEHLERBERICHT — Drop-in Fehlermelde-Modul für Flutter-Apps
//
//  Eine einzige Datei, ohne relative Imports, direkt in jede neue App
//  kopierbar. Erlaubte Paket-Abhängigkeiten: flutter, http, url_launcher.
//
//  EINBAU (siehe auch README.md im gleichen Ordner):
//
//    void main() => Fehlerbericht.runApp(
//          appKey: 'meine_app',
//          appName: 'Meine App',
//          version: '1.0.0',
//          builder: () => const MyApp(),
//        );
//
//    MaterialApp(
//      navigatorKey: Fehlerbericht.navigatorKey,
//      navigatorObservers: [Fehlerbericht.observer],
//      builder: Fehlerbericht.wrap,
//      ...
//    )
//
//  Alle Fehlerberichte landen automatisch in Notion (ein Token für alle
//  Apps, siehe --dart-define=NOTION_TOKEN=... in der README). Jede App
//  richtet sich beim ersten Fehlerbericht selbst eine eigene Notion-
//  Datenbank ein — es ist keine manuelle Notion-Konfiguration nötig.
//
//  Ist kein Token gesetzt oder schlägt Notion endgültig fehl, wird
//  stattdessen die E-Mail-App mit einem vollständigen Berichtstext
//  geöffnet (mailto:).
// ═══════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' as widgets_lib;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ───────────────────────────────────────────────────────────────────────
//  ÖFFENTLICHE API
// ───────────────────────────────────────────────────────────────────────

/// Zentrale Schnittstelle des Fehlermelde-Moduls.
///
/// Wird ausschließlich statisch verwendet — es gibt bewusst keine Instanz.
class Fehlerbericht {
  Fehlerbericht._();

  // ── App-Konfiguration (gesetzt in runApp) ───────────────────────────
  static String _appKey = '';
  static String _appName = 'App';
  static String _version = '';
  static bool _buttonEnabled = true;

  /// Textbausteine, bei denen ein automatischer Fehler NICHT gemeldet
  /// wird — für bekannte, harmlose Platform-Meldungen. Gesetzt über
  /// [runApp]. Manuelle Meldungen sind davon nie betroffen.
  static List<String> _ignorieren = const [];

  /// Wird von der App an `MaterialApp(navigatorKey: ...)` übergeben.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Wird von der App an `MaterialApp(navigatorObservers: [...])`
  /// übergeben. Trackt den Namen des aktuell sichtbaren Screens.
  static final NavigatorObserver observer = _FehlerberichtObserver();

  static String _aktuelleSeite = '';

  /// Ausweich-Kontext für den Melde-Dialog, falls `navigatorKey` einmal
  /// nicht gesetzt wurde. Wird vom [observer] beim ersten Routenwechsel
  /// gefüllt.
  static BuildContext? _letzterRouteKontext;

  // ── Ring-Puffer für das Protokoll ────────────────────────────────────
  static const int _maxLogEintraege = 300;
  static final List<String> _log = [];

  /// Alle bisher gesammelten Protokoll-Einträge (schreibgeschützt).
  static List<String> get protokoll => List.unmodifiable(_log);

  /// Nur für Tests: liefert den Klartext-Hinweis zu einem Netzwerkfehler.
  @visibleForTesting
  static String? ursacheVermuten(Object fehler) =>
      _Notion._ursacheVermuten(fehler);

  // ── Screenshot-Infrastruktur ─────────────────────────────────────────
  static final GlobalKey _repaintKey = GlobalKey();
  static final ValueNotifier<bool> _buttonSichtbar = ValueNotifier<bool>(true);
  static Offset? _buttonPosition;

  // ── Reentrancy- & Dedup-Schutz für automatische Meldungen ───────────
  static bool _sendingReport = false;
  static String? _letzterFingerprint;
  static DateTime? _letzterFingerprintZeit;
  static bool _dialogOffen = false;

  // ═══════════════════════════════════════════════════════════════════
  //  EINRICHTUNG
  // ═══════════════════════════════════════════════════════════════════

  /// Ersetzt den Aufruf von `runApp(...)` in main(). Initialisiert das
  /// Flutter-Binding, verdrahtet alle globalen Fehlerkanäle
  /// (FlutterError.onError, PlatformDispatcher.onError, runZonedGuarded)
  /// und startet danach die eigentliche App.
  ///
  /// [appKey] ist ein stabiler, klein geschriebener Schlüssel (z. B.
  /// "sauerteig") — er identifiziert die App in der Notion-Registry und
  /// darf sich später nicht mehr ändern. [appName] ist der Anzeigename
  /// in Notion. [version] ist optional und taucht in jedem Bericht auf.
  /// Mit `button: false` wird der schwebende Fehler-Button deaktiviert;
  /// dann kann [FehlerButton] manuell z. B. in eine AppBar eingebaut
  /// werden.
  static void runApp({
    required String appKey,
    required String appName,
    String version = '',
    required Widget Function() builder,
    bool button = true,
    List<String> ignorieren = const [],
  }) {
    _appKey = appKey;
    _appName = appName;
    _version = version;
    _buttonEnabled = button;
    _ignorieren = ignorieren;

    // WidgetsFlutterBinding.ensureInitialized() und der eigentliche
    // runApp()-Aufruf müssen in derselben Zone laufen (Flutter-Empfehlung
    // für runZonedGuarded), sonst kann es zu "Zone mismatch"-Warnungen
    // kommen.
    runZonedGuarded(
      () {
        WidgetsFlutterBinding.ensureInitialized();

        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          _meldeAutomatisch(
            details.exceptionAsString(),
            kontext: 'FlutterError',
            stack: details.stack,
            art: _artAbsturz,
          );
        };

        PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
          _meldeAutomatisch(
            error.toString(),
            kontext: 'PlatformDispatcher',
            stack: stack,
            art: _artAbsturz,
          );
          return true;
        };

        // widgets_lib.runApp statt des unqualifizierten Namens: sonst
        // würde der Aufruf innerhalb dieser statischen Methode auf sich
        // selbst (Fehlerbericht.runApp) verweisen.
        widgets_lib.runApp(builder());
      },
      (Object error, StackTrace stack) {
        _meldeAutomatisch(
          error.toString(),
          kontext: 'Zone',
          stack: stack,
          art: _artAbsturz,
        );
      },
    );
  }

  /// `TransitionBuilder` für `MaterialApp(builder: Fehlerbericht.wrap)`.
  /// Packt die App in ein `RepaintBoundary` (für Auto-Screenshots) und
  /// blendet — sofern aktiviert — den verschiebbaren Fehler-Button ein.
  static Widget wrap(BuildContext context, Widget? child) {
    return _FehlerberichtOverlay(child: child ?? const SizedBox.shrink());
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PROTOKOLL
  // ═══════════════════════════════════════════════════════════════════

  /// Schreibt eine Zeile ins Protokoll (Ring-Puffer, max. 300 Einträge).
  /// Wird von allen anderen log*-Methoden intern verwendet und kann auch
  /// direkt für beliebige Debug-Meldungen genutzt werden.
  static void log(String message) {
    final now = DateTime.now();
    String p2(int n) => n.toString().padLeft(2, '0');
    final entry =
        '[${p2(now.hour)}:${p2(now.minute)}:${p2(now.second)}] $message';
    _log.add(entry);
    if (_log.length > _maxLogEintraege) _log.removeAt(0);
    debugPrint('[Fehlerbericht] $entry');
  }

  /// Protokolliert eine Nutzeraktion, z. B. `logAktion('Rechnung gespeichert')`.
  static void logAktion(String aktion, {Map<String, String>? kontext}) {
    final zusatz = (kontext != null && kontext.isNotEmpty)
        ? ' | ${kontext.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    log('AKTION: $aktion$zusatz');
  }

  /// Protokolliert das Laden eines Screens und merkt sich den Namen für
  /// nachfolgende Fehlerberichte (Feld "Seite").
  static void logSeite(String name, {String? info}) {
    _aktuelleSeite = name;
    log('SEITE: $name${info != null && info.isNotEmpty ? ' ($info)' : ''}');
  }

  /// Protokolliert einen API-/Netzwerk-Aufruf.
  static void logApi(String endpoint, String methode,
      {int? statusCode, String? fehler}) {
    if (fehler != null) {
      log('API $methode $endpoint -> FEHLER: $fehler');
    } else {
      log('API $methode $endpoint -> ${statusCode ?? '...'}');
    }
  }

  /// Protokolliert eine Datenbank-Operation (z. B. INSERT/UPDATE/DELETE).
  /// Zusätzliche Hilfsmethode, damit beim Umbiegen bestehender Aufrufe
  /// (z. B. eine bisherige logDbOperation-Methode) keine Log-Aufrufe verloren
  /// gehen.
  static void logDb(String operation, String tabelle,
      {String? id, bool erfolgreich = true}) {
    final status = erfolgreich ? 'OK' : 'FEHLER';
    log('DB $status $operation [$tabelle]${id != null ? ' id=$id' : ''}');
  }

  /// Protokolliert eine Auswahl des Nutzers (z. B. in einem Dropdown).
  /// Zusätzliche Hilfsmethode, siehe [logDb].
  static void logAuswahl(String feld, String wert, {List<String>? optionen}) {
    final opts = (optionen != null && optionen.isNotEmpty)
        ? ' [${optionen.join(', ')}]'
        : '';
    log('AUSWAHL: $feld = "$wert"$opts');
  }

  /// Protokolliert einen (nicht zwangsläufig fatalen) Fehler und löst —
  /// gedrosselt per Fingerprint-Dedup — eine automatische, stille
  /// Meldung an Notion (bzw. den E-Mail-Fallback) aus. Für echte
  /// Abstürze (globale Fehlerkanäle) übernimmt [runApp] das automatisch;
  /// diese Methode ist für App-Code gedacht, der Fehler selbst abfängt
  /// (`try { ... } catch (e) { Fehlerbericht.logFehler(...); }`).
  static void logFehler(String fehler, {String? kontext, StackTrace? stack}) {
    _meldeAutomatisch(fehler,
        kontext: kontext, stack: stack, art: _artAutoFehler);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  AUTOMATISCHE MELDUNG (Abstürze & explizite logFehler-Aufrufe)
  // ═══════════════════════════════════════════════════════════════════

  static const String _artAbsturz = 'Absturz';
  static const String _artAutoFehler = 'Auto-Fehler';
  static const String _artManuell = 'Manuelle Meldung';

  static void _meldeAutomatisch(
    String fehler, {
    String? kontext,
    StackTrace? stack,
    required String art,
  }) {
    final anzeige = (kontext != null && kontext.isNotEmpty)
        ? '$fehler (Kontext: $kontext)'
        : fehler;
    // Bekannte Störmeldungen gar nicht erst melden — sie würden die
    // Notion-Datenbank zumüllen. Im Protokoll bleiben sie sichtbar.
    for (final muster in _ignorieren) {
      if (muster.isNotEmpty && anzeige.contains(muster)) {
        log('Ignoriert (Muster "$muster"): $anzeige');
        return;
      }
    }

    log('FEHLER [$art]: $anzeige');
    if (stack != null) log('Stack: ${_kurzerStack(stack)}');

    // Kein Endlos-Loop: Fehler innerhalb des Fehlerberichts selbst lösen
    // keinen neuen Fehlerbericht aus.
    if (_sendingReport) {
      log('Fehlerbericht: Versand läuft bereits — überspringe (Reentrancy-Schutz).');
      return;
    }

    // Dedup: identischer Fingerprint innerhalb von 60s wird nicht erneut
    // gesendet (z. B. bei Fehlern, die in einer Schleife auftreten).
    final fingerprint = _fingerprintBerechnen(anzeige, _aktuelleSeite);
    final jetzt = DateTime.now();
    if (_letzterFingerprint == fingerprint &&
        _letzterFingerprintZeit != null &&
        jetzt.difference(_letzterFingerprintZeit!).inSeconds < 60) {
      log('Fehlerbericht: identischer Fehler innerhalb 60s bereits gemeldet — überspringe.');
      return;
    }
    _letzterFingerprint = fingerprint;
    _letzterFingerprintZeit = jetzt;

    // Fire-and-forget: App darf durch die Meldung nie blockiert werden.
    unawaited(_automatischSenden(anzeige, art: art, fingerprint: fingerprint));
  }

  static Future<void> _automatischSenden(
    String fehlerText, {
    required String art,
    required String fingerprint,
  }) async {
    _sendingReport = true;
    var erfolg = false;
    try {
      erfolg = await _versandDurchfuehren(
        art: art,
        fehlerText: fehlerText,
        beschreibung: null,
        screenshot: null, // Auto-Fehler: kein Screenshot, um die App
        // nicht durch die (potenziell langsame) Bildaufnahme zu
        // verzögern oder zu stören — passend zu "still gesendet".
        fingerprintOverride: fingerprint,
      );
    } catch (e) {
      // Darf niemals eine weitere Meldung auslösen — daher log(), nicht
      // logFehler().
      log('Automatischer Versand unerwartet fehlgeschlagen: $e');
    } finally {
      _sendingReport = false;
    }
    _autoHinweisAnzeigen(erfolg);
  }

  /// Dezenter Hinweis per SnackBar — kein aufdringlicher Dialog.
  static void _autoHinweisAnzeigen(bool erfolg) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    try {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            erfolg
                ? 'Ein Fehler ist aufgetreten und wurde automatisch gemeldet.'
                : 'Ein Fehler ist aufgetreten. Die Meldung konnte nicht gesendet werden.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      log('Hinweis-SnackBar konnte nicht angezeigt werden: $e');
    }
  }

  static String _kurzerStack(StackTrace stack) {
    return stack.toString().split('\n').take(3).join(' | ');
  }

  static String _fingerprintBerechnen(String basisText, String? seite) {
    final input = '$basisText|${seite ?? ''}';
    return input.hashCode.toRadixString(16);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MANUELLE MELDUNG (Dialog)
  // ═══════════════════════════════════════════════════════════════════

  /// Öffnet den Melde-Dialog (Beschreibungsfeld, Screenshot-Vorschau,
  /// aufklappbares Protokoll, Senden/Abbrechen). Wird sowohl vom
  /// schwebenden Fehler-Button als auch von [FehlerButton] aufgerufen.
  static Future<void> melden(BuildContext context) async {
    if (_dialogOffen) return;
    _dialogOffen = true;
    Uint8List? screenshot;
    try {
      // Harte Obergrenze: der Dialog geht auch dann auf, wenn die
      // Screenshot-Erfassung klemmt — lieber ein Bericht ohne Bild als
      // ein Button, der scheinbar nichts tut.
      screenshot = await _screenshotErfassen()
          .timeout(const Duration(seconds: 2), onTimeout: () {
        log('Screenshot: Zeitüberschreitung — Dialog wird ohne Bild geöffnet.');
        _buttonSichtbar.value = true;
        return null;
      });
    } catch (e) {
      log('Screenshot vor Melde-Dialog fehlgeschlagen: $e');
      _buttonSichtbar.value = true;
    }
    if (!context.mounted) {
      _dialogOffen = false;
      return;
    }
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => _FehlerberichtDialog(screenshot: screenshot),
      );
    } finally {
      _dialogOffen = false;
    }
  }

  static Future<bool> _sendeManuell(
      {String? beschreibung, Uint8List? screenshot}) {
    return _versandDurchfuehren(
      art: _artManuell,
      beschreibung: beschreibung,
      fehlerText: null,
      screenshot: screenshot,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ZENTRALER VERSAND (Notion, mit E-Mail-Fallback)
  // ═══════════════════════════════════════════════════════════════════

  static Future<bool> _versandDurchfuehren({
    required String art,
    String? beschreibung,
    String? fehlerText,
    Uint8List? screenshot,
    String? fingerprintOverride,
  }) async {
    final protokollSnapshot = protokoll;
    final seite = _aktuelleSeite;
    final fingerprint = fingerprintOverride ??
        _fingerprintBerechnen(fehlerText ?? beschreibung ?? art, seite);

    var notionErfolg = false;
    if (_Notion.konfiguriert) {
      try {
        notionErfolg = await _Notion.sendeBericht(
          appKey: _appKey,
          appName: _appName,
          version: _version,
          art: art,
          beschreibung: beschreibung,
          fehlerText: fehlerText,
          seite: seite,
          screenshot: screenshot,
          protokoll: protokollSnapshot,
          fingerprint: fingerprint,
        );
      } catch (e) {
        log('Notion-Versand unerwartet fehlgeschlagen: $e');
        notionErfolg = false;
      }
    } else {
      log('Kein NOTION_TOKEN gesetzt (--dart-define=NOTION_TOKEN=...) — nutze E-Mail-Fallback.');
    }

    if (notionErfolg) return true;

    final text = _berichtAlsText(
      art: art,
      beschreibung: beschreibung,
      fehlerText: fehlerText,
      seite: seite,
      protokoll: protokollSnapshot,
    );
    return _emailFallback(text);
  }

  static Future<bool> _emailFallback(String text) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'klaasotte99@gmail.com',
      queryParameters: {
        'subject': '[$_appName] Fehlerbericht',
        'body': text,
      },
    );
    try {
      final ok = await launchUrl(uri);
      log(ok
          ? 'E-Mail-App geöffnet (Fallback).'
          : 'E-Mail-App konnte nicht geöffnet werden.');
      return ok;
    } catch (e) {
      log('E-Mail-Fallback fehlgeschlagen: $e');
      return false;
    }
  }

  static String _berichtAlsText({
    required String art,
    String? beschreibung,
    String? fehlerText,
    String? seite,
    required List<String> protokoll,
  }) {
    final b = StringBuffer();
    b.writeln('FEHLERBERICHT ($art)');
    b.writeln('App: $_appName ($_appKey)');
    b.writeln('Version: ${_version.isEmpty ? 'unbekannt' : _version}');
    b.writeln('Zeit: ${DateTime.now()}');
    b.writeln('Plattform: ${_plattformName()} — OS: ${_osInfoText()}');
    if (seite != null && seite.isNotEmpty) b.writeln('Seite: $seite');
    if (beschreibung != null && beschreibung.isNotEmpty) {
      b.writeln();
      b.writeln('BESCHREIBUNG:');
      b.writeln(beschreibung);
    }
    if (fehlerText != null && fehlerText.isNotEmpty) {
      b.writeln();
      b.writeln('FEHLER:');
      b.writeln(fehlerText);
    }
    b.writeln();
    final tail = protokoll.length > 100
        ? protokoll.sublist(protokoll.length - 100)
        : protokoll;
    b.writeln(
        'PROTOKOLL (letzte ${tail.length} von ${protokoll.length} Einträgen):');
    b.writeln(tail.isEmpty ? '(keine Einträge)' : tail.join('\n'));
    return b.toString();
  }
}

// ───────────────────────────────────────────────────────────────────────
//  SCREENSHOT (in-memory, kein path_provider / image_picker nötig)
// ───────────────────────────────────────────────────────────────────────

/// Erfasst einen Screenshot des aktuellen Frames als PNG-Bytes. Blendet
/// dafür kurz den schwebenden Fehler-Button aus, damit er den
/// Screenshot nicht verfälscht.
Future<Uint8List?> _screenshotErfassen() async {
  if (kIsWeb) {
    Fehlerbericht.log('Screenshot: auf Web nicht unterstützt.');
    return null;
  }
  Fehlerbericht._buttonSichtbar.value = false;
  try {
    for (var versuch = 1; versuch <= 3; versuch++) {
      try {
        // Einen Frame ohne Button abwarten, bevor erfasst wird.
        // ensureVisualUpdate() ist wichtig: ohne einen angeforderten
        // Frame würde endOfFrame auf einem statischen Bildschirm nie
        // zurückkehren und der Melde-Dialog nie aufgehen.
        WidgetsBinding.instance.ensureVisualUpdate();
        await WidgetsBinding.instance.endOfFrame;
        final ctx = Fehlerbericht._repaintKey.currentContext;
        if (ctx == null || !ctx.mounted) {
          Fehlerbericht.log(
              'Screenshot: RepaintBoundary-Kontext ist null oder nicht mehr aktiv.');
          return null;
        }
        final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          Fehlerbericht.log(
              'Screenshot: RenderRepaintBoundary nicht gefunden.');
          return null;
        }
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ImageByteFormat.png);
        if (byteData == null) continue;
        final bytes = byteData.buffer.asUint8List();
        Fehlerbericht.log(
            'Screenshot erfasst (${(bytes.lengthInBytes / 1024).round()} KB).');
        return bytes;
      } catch (e) {
        Fehlerbericht.log('Screenshot Versuch $versuch fehlgeschlagen: $e');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    return null;
  } finally {
    Fehlerbericht._buttonSichtbar.value = true;
  }
}

// ───────────────────────────────────────────────────────────────────────
//  GERÄTE-/PLATTFORM-INFOS (nur mit dart:io — kein device_info_plus)
// ───────────────────────────────────────────────────────────────────────

String _plattformName() {
  if (kIsWeb) return 'Web';
  try {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
  } catch (_) {
    // Plattform nicht ermittelbar — Notion legt bei einem unbekannten
    // Select-Wert automatisch eine neue Option an.
  }
  return 'Unbekannt';
}

String _osInfoText() {
  if (kIsWeb) return 'Browser';
  try {
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  } catch (_) {
    return 'unbekannt';
  }
}

String _geraetInfoText() {
  // Ohne zusätzliches Paket (device_info_plus ist laut Vorgabe bewusst
  // nicht erlaubt) lässt sich nur der Hostname als grobe Geräte-Info
  // ermitteln — für Details siehe README, Abschnitt "Fehlersuche".
  if (kIsWeb) return 'Browser';
  try {
    return Platform.localHostname;
  } catch (_) {
    return '';
  }
}

// ───────────────────────────────────────────────────────────────────────
//  NAVIGATOR-OBSERVER (Screen-Tracking)
// ───────────────────────────────────────────────────────────────────────

class _FehlerberichtObserver extends NavigatorObserver {
  static String? _name(Route<dynamic> route) {
    final name = route.settings.name;
    return (name != null && name.isNotEmpty) ? name : null;
  }

  static void _merkeKontext(Route<dynamic>? route) {
    final ctx = route?.navigator?.context;
    if (ctx != null) Fehlerbericht._letzterRouteKontext = ctx;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _merkeKontext(route);
    final name = _name(route);
    if (name != null) Fehlerbericht._aktuelleSeite = name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _merkeKontext(previousRoute ?? route);
    final name = previousRoute != null ? _name(previousRoute) : null;
    if (name != null) Fehlerbericht._aktuelleSeite = name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final name = newRoute != null ? _name(newRoute) : null;
    if (name != null) Fehlerbericht._aktuelleSeite = name;
  }
}

// ───────────────────────────────────────────────────────────────────────
//  OVERLAY: RepaintBoundary + verschiebbarer Fehler-Button
// ───────────────────────────────────────────────────────────────────────

class _FehlerberichtOverlay extends StatelessWidget {
  final Widget child;
  const _FehlerberichtOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: Fehlerbericht._repaintKey,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          if (Fehlerbericht._buttonEnabled)
            ValueListenableBuilder<bool>(
              valueListenable: Fehlerbericht._buttonSichtbar,
              builder: (_, sichtbar, __) => sichtbar
                  ? const _DraggableBugButton()
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _DraggableBugButton extends StatefulWidget {
  const _DraggableBugButton();

  @override
  State<_DraggableBugButton> createState() => _DraggableBugButtonState();
}

class _DraggableBugButtonState extends State<_DraggableBugButton> {
  static const double _groesse = 48;
  Offset? _pos;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _pos ??= Fehlerbericht._buttonPosition ??
        Offset(size.width - _groesse - 16, size.height - _groesse - 96);
    final maxX = (size.width - _groesse).clamp(0.0, double.infinity);
    final maxY = (size.height - _groesse).clamp(0.0, double.infinity);
    final left = _pos!.dx.clamp(0.0, maxX);
    final top = _pos!.dy.clamp(0.0, maxY);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() => _pos = _pos! + details.delta);
          Fehlerbericht._buttonPosition = _pos;
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              // Der Overlay-Button sitzt oberhalb des Navigators, deshalb
              // wird der Navigator-Kontext genutzt (der eigene Kontext
              // hätte keinen Navigator über sich).
              final ctx = Fehlerbericht.navigatorKey.currentContext ??
                  Fehlerbericht._letzterRouteKontext;
              if (ctx == null) {
                Fehlerbericht.log(
                    'Fehler-Button: kein Navigator-Kontext verfügbar — '
                    'navigatorKey in MaterialApp gesetzt?');
                return;
              }
              Fehlerbericht.melden(ctx);
            },
            child: Container(
              width: _groesse,
              height: _groesse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child:
                  const Icon(Icons.bug_report, color: Colors.white70, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// AppBar-Icon-Button zum manuellen Einbau — nützlich, wenn der
/// schwebende Overlay-Button per `Fehlerbericht.runApp(button: false)`
/// deaktiviert wurde.
class FehlerButton extends StatelessWidget {
  const FehlerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.bug_report_outlined),
      tooltip: 'Fehler melden',
      onPressed: () => Fehlerbericht.melden(context),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
//  MELDE-DIALOG
// ───────────────────────────────────────────────────────────────────────

class _FehlerberichtDialog extends StatefulWidget {
  final Uint8List? screenshot;
  const _FehlerberichtDialog({this.screenshot});

  @override
  State<_FehlerberichtDialog> createState() => _FehlerberichtDialogState();
}

class _FehlerberichtDialogState extends State<_FehlerberichtDialog> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _logOffen = false;

  @override
  void dispose() {
    // Die Sperre hier zurücksetzen und nicht nur nach showDialog():
    // wird der Dialog samt Route verworfen, ohne geschlossen zu werden
    // (Routen-Wechsel, Neustart), liefe showDialog() nie zu Ende und der
    // Fehler-Button bliebe dauerhaft wirkungslos.
    Fehlerbericht._dialogOffen = false;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _senden() async {
    setState(() => _sending = true);
    final note = _controller.text.trim();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final erfolg = await Fehlerbericht._sendeManuell(
      beschreibung: note.isEmpty ? null : note,
      screenshot: widget.screenshot,
    );
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(erfolg
            ? '✓ Fehlerbericht gesendet. Danke!'
            : '✗ Senden fehlgeschlagen — E-Mail-App geöffnet.'),
        backgroundColor:
            erfolg ? Colors.green.shade700 : Colors.orange.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = Fehlerbericht.protokoll;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.bug_report, size: 20),
          SizedBox(width: 8),
          Text('Fehler melden'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 280),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.screenshot != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    widget.screenshot!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Was ist passiert?',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              TextField(
                controller: _controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'z. B. "Speichern funktioniert nicht"',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _logOffen = !_logOffen),
                child: Row(
                  children: [
                    const Text('Protokoll',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const Spacer(),
                    Text('${log.length} Einträge',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    Icon(
                      _logOffen ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
              if (_logOffen)
                Container(
                  height: 140,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: ListView.builder(
                    itemCount: log.length,
                    itemBuilder: (_, i) => Text(
                      log[i],
                      style: const TextStyle(
                          fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton.icon(
          onPressed: _sending ? null : _senden,
          icon: _sending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 16),
          label: Text(_sending ? 'Sende...' : 'Senden'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  NOTION-ANBINDUNG
//
//  Ein einziges Integrations-Token für alle Apps, per
//  --dart-define=NOTION_TOKEN=ntn_... zur Build-Zeit gesetzt. Jede App
//  richtet sich beim ersten Fehlerbericht selbst eine eigene, unter der
//  Fehlerzentrale liegende Datenbank ein (siehe README).
// ═══════════════════════════════════════════════════════════════════════

class _Notion {
  _Notion._();

  static const String _token =
      String.fromEnvironment('NOTION_TOKEN', defaultValue: '');

  // Fest verdrahtete Notion-IDs — bitte nicht verändern, die Struktur
  // ist in Notion bereits angelegt.
  static const String _wurzelSeiteId =
      '3d185584-dd12-81bb-9516-e34e03839fbc'; // 🐞 Fehlerzentrale
  static const String _registryDbId =
      '0f07715e-7f9b-4804-adb5-3d0f704febae'; // 📊 Apps

  static const String _base = 'https://api.notion.com/v1';
  static const Duration _timeout = Duration(seconds: 15);

  static bool get konfiguriert => _token.isNotEmpty;

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Notion-Version': '2022-06-28',
        'Content-Type': 'application/json',
      };

  /// Übersetzt typische Netzwerkfehler in einen konkreten Hinweis.
  /// Ohne das steht im Protokoll nur eine rohe SocketException, und die
  /// eigentliche Ursache (meist eine fehlende Berechtigung) bleibt
  /// unerkannt — genau daran ist schon einmal eine Fehlersuche
  /// vorbeigelaufen.
  static String? _ursacheVermuten(Object fehler) {
    final t = fehler.toString();
    // errno 7 / EAI_NONAME beim Auflösen von api.notion.com ist auf
    // Android praktisch immer die fehlende INTERNET-Berechtigung: ohne
    // sie schlägt schon die Namensauflösung fehl, nicht erst die
    // Verbindung. Debug-Builds bekommen sie von Flutter geschenkt,
    // Release-Builds nicht.
    if (t.contains('Failed host lookup')) {
      if (t.contains('errno = 7') || t.contains('No address associated')) {
        return 'Vermutlich fehlt <uses-permission '
            'android:name="android.permission.INTERNET"/> in '
            'android/app/src/main/AndroidManifest.xml. Steht sie nur '
            'unter src/debug/, funktioniert der Debug-Build und der '
            'Release-Build nicht.';
      }
      return 'Kein DNS — Gerät vermutlich offline.';
    }
    if (t.contains('SocketException') || t.contains('ClientException')) {
      return 'Netzwerk nicht erreichbar — Gerät offline oder Zugriff '
          'blockiert.';
    }
    if (t.contains('TimeoutException')) {
      return 'Notion hat nicht rechtzeitig geantwortet — Verbindung sehr '
          'langsam oder gestört.';
    }
    return null;
  }

  // In-Memory-Cache: pro App-Prozess wird die Registry nur einmal
  // abgefragt bzw. eingerichtet.
  static String? _dbIdCache;
  static String? _registryPageIdCache;

  // Web: Merkt sich, ob ein Versuch bereits an CORS gescheitert ist (s.u.).
  static bool _webVorherigFehlgeschlagen = false;

  /// Legt — falls nötig — die App-Infrastruktur in Notion an und
  /// speichert anschließend den Fehlerbericht. Gibt `true` nur bei
  /// vollem Erfolg zurück; jeder Fehlschlag führt zum E-Mail-Fallback
  /// in [Fehlerbericht._versandDurchfuehren].
  static Future<bool> sendeBericht({
    required String appKey,
    required String appName,
    required String version,
    required String art,
    String? beschreibung,
    String? fehlerText,
    String? seite,
    Uint8List? screenshot,
    required List<String> protokoll,
    required String fingerprint,
  }) async {
    if (!konfiguriert) return false;

    // Web: Die Notion-API sendet keinen Access-Control-Allow-Origin-
    // Header, ein direkter Aufruf aus dem Browser wird also von der
    // Same-Origin-Policy blockiert (CORS) und schlägt immer mit einem
    // Netzwerkfehler fehl. Statt bei jedem Fehler erneut sinnlos zu
    // versuchen, merken wir uns das für die laufende Session und gehen
    // danach direkt auf den E-Mail-Fallback.
    if (kIsWeb && _webVorherigFehlgeschlagen) {
      Fehlerbericht.log(
        'Notion: Web-Versand war zuvor an CORS gescheitert — überspringe erneuten Versuch.',
      );
      return false;
    }

    try {
      final dbId = await _datenbankIdErmitteln(
          appKey: appKey, appName: appName, version: version);
      if (dbId == null) return false;

      final ok = await _berichtAnlegen(
        dbId: dbId,
        art: art,
        beschreibung: beschreibung,
        fehlerText: fehlerText,
        seite: seite,
        version: version,
        protokoll: protokoll,
        screenshot: screenshot,
        fingerprint: fingerprint,
      );

      if (ok) {
        // Fire-and-forget, Fehler werden ignoriert (Registry-Update ist
        // nicht kritisch für den Erfolg des Berichts).
        unawaited(_registryAktualisieren(appKey: appKey, version: version));
      }
      return ok;
    } catch (e) {
      if (kIsWeb) {
        _webVorherigFehlgeschlagen = true;
        Fehlerbericht.log(
            'Notion im Web nicht erreichbar (vermutlich CORS-Blockade): $e');
      } else {
        Fehlerbericht.log('Notion-Versand fehlgeschlagen: $e');
        final rat = _ursacheVermuten(e);
        if (rat != null) Fehlerbericht.log('→ $rat');
      }
      return false;
    }
  }

  // ── Schritt 1+2: Cache / Registry-Abfrage ───────────────────────────
  static Future<String?> _datenbankIdErmitteln({
    required String appKey,
    required String appName,
    required String version,
  }) async {
    if (_dbIdCache != null) return _dbIdCache;

    final gefunden = await _registryEintragSuchen(appKey);
    if (gefunden.dbId != null && gefunden.dbId!.isNotEmpty) {
      _dbIdCache = gefunden.dbId;
      _registryPageIdCache = gefunden.pageId;
      return _dbIdCache;
    }

    // ── Schritt 3: kein Treffer -> App richtet sich selbst ein ────────
    return _appSelbstEinrichten(
        appKey: appKey, appName: appName, version: version);
  }

  static Future<({String? dbId, String? pageId})> _registryEintragSuchen(
      String appKey) async {
    final res = await http
        .post(
          Uri.parse('$_base/databases/$_registryDbId/query'),
          headers: _headers,
          body: jsonEncode({
            'filter': {
              'property': 'App-Key',
              'rich_text': {'equals': appKey},
            },
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      Fehlerbericht.log('Notion: Registry-Abfrage HTTP ${res.statusCode}');
      return (dbId: null, pageId: null);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>;
    if (results.isEmpty) return (dbId: null, pageId: null);

    final row = results.first as Map<String, dynamic>;
    final props = row['properties'] as Map<String, dynamic>;
    return (
      dbId: _richTextPlain(props['Datenbank-ID']),
      pageId: row['id'] as String?
    );
  }

  static Future<String?> _appSelbstEinrichten({
    required String appKey,
    required String appName,
    required String version,
  }) async {
    Fehlerbericht.log(
        'Notion: App "$appKey" unbekannt — richte Fehlerdatenbank ein…');

    // a) Seite unter der Fehlerzentrale anlegen
    final pageRes = await http
        .post(
          Uri.parse('$_base/pages'),
          headers: _headers,
          body: jsonEncode({
            'parent': {'page_id': _wurzelSeiteId},
            'icon': {'type': 'emoji', 'emoji': '🐛'},
            'properties': {
              'title': {
                'title': [
                  {
                    'text': {'content': appName},
                  },
                ],
              },
            },
            'children': [
              {
                'object': 'block',
                'type': 'paragraph',
                'paragraph': {
                  'rich_text': [
                    {
                      'text': {
                        'content':
                            'Automatisch angelegte Fehlerzentrale für $appName. '
                                'Neue Berichte erscheinen in der Datenbank unten.',
                      },
                    },
                  ],
                },
              },
            ],
          }),
        )
        .timeout(_timeout);

    if (pageRes.statusCode != 200) {
      Fehlerbericht.log(
          'Notion: Seite anlegen fehlgeschlagen (HTTP ${pageRes.statusCode})');
      return null;
    }
    final pageId =
        (jsonDecode(pageRes.body) as Map<String, dynamic>)['id'] as String;

    // b) Datenbank mit dem festen Schema anlegen
    final dbRes = await http
        .post(
          Uri.parse('$_base/databases'),
          headers: _headers,
          body: jsonEncode({
            'parent': {'page_id': pageId},
            'is_inline': true,
            'title': [
              {
                'text': {'content': '🐛 $appName'},
              },
            ],
            'properties': {
              'Titel': {'title': {}},
              'Status': {
                'select': {
                  'options': [
                    {'name': 'Neu', 'color': 'red'},
                    {'name': 'In Arbeit', 'color': 'yellow'},
                    {'name': 'Behoben', 'color': 'green'},
                    {'name': 'Ignoriert', 'color': 'gray'},
                  ],
                },
              },
              'Art': {
                'select': {
                  'options': [
                    {'name': 'Absturz', 'color': 'red'},
                    {'name': 'Auto-Fehler', 'color': 'orange'},
                    {'name': 'Manuelle Meldung', 'color': 'blue'},
                  ],
                },
              },
              'Beschreibung': {'rich_text': {}},
              'Fehler': {'rich_text': {}},
              'Seite': {'rich_text': {}},
              'Version': {'rich_text': {}},
              'Plattform': {
                'select': {
                  'options': [
                    {'name': 'Android'},
                    {'name': 'iOS'},
                    {'name': 'Web'},
                    {'name': 'Windows'},
                    {'name': 'macOS'},
                    {'name': 'Linux'},
                  ],
                },
              },
              'OS': {'rich_text': {}},
              'Gerät': {'rich_text': {}},
              'Zeitstempel': {'date': {}},
              'Fingerprint': {'rich_text': {}},
            },
          }),
        )
        .timeout(_timeout);

    if (dbRes.statusCode != 200) {
      Fehlerbericht.log(
          'Notion: Datenbank anlegen fehlgeschlagen (HTTP ${dbRes.statusCode})');
      return null;
    }
    final dbId =
        (jsonDecode(dbRes.body) as Map<String, dynamic>)['id'] as String;

    // c) Registry-Zeile anlegen
    final now = DateTime.now().toIso8601String();
    final regRes = await http
        .post(
          Uri.parse('$_base/pages'),
          headers: _headers,
          body: jsonEncode({
            'parent': {'database_id': _registryDbId},
            'properties': {
              'App': _titleProp(appName),
              'App-Key': _textProp(appKey),
              'Datenbank-ID': _textProp(dbId),
              'Seiten-ID': _textProp(pageId),
              'Plattform': _selectProp(_plattformName()),
              'Version': _textProp(version.isEmpty ? 'unbekannt' : version),
              'Erste Meldung': {
                'date': {'start': now},
              },
              'Letzte Meldung': {
                'date': {'start': now},
              },
              'Berichte': {'number': 1},
              'Status': _selectProp('Aktiv'),
            },
          }),
        )
        .timeout(_timeout);

    if (regRes.statusCode != 200) {
      Fehlerbericht.log(
        'Notion: Registry-Eintrag anlegen fehlgeschlagen (HTTP ${regRes.statusCode}) '
        '— Datenbank wurde aber angelegt und wird trotzdem verwendet.',
      );
    } else {
      _registryPageIdCache =
          (jsonDecode(regRes.body) as Map<String, dynamic>)['id'] as String?;
    }

    _dbIdCache = dbId;
    Fehlerbericht.log(
        'Notion: Fehlerdatenbank für "$appName" erfolgreich eingerichtet.');
    return dbId;
  }

  // ── Schritt 4: Bericht anlegen ───────────────────────────────────────
  static Future<bool> _berichtAnlegen({
    required String dbId,
    required String art,
    String? beschreibung,
    String? fehlerText,
    String? seite,
    required String version,
    required List<String> protokoll,
    Uint8List? screenshot,
    required String fingerprint,
  }) async {
    final now = DateTime.now();
    final props = <String, dynamic>{
      'Titel': _titleProp(_titelFuer(art, beschreibung, fehlerText, now)),
      'Status': _selectProp('Neu'),
      'Art': _selectProp(art),
      if (beschreibung != null && beschreibung.isNotEmpty)
        'Beschreibung': _textProp(beschreibung),
      if (fehlerText != null && fehlerText.isNotEmpty)
        'Fehler': _textProp(fehlerText),
      if (seite != null && seite.isNotEmpty) 'Seite': _textProp(seite),
      'Version': _textProp(version.isEmpty ? 'unbekannt' : version),
      'Plattform': _selectProp(_plattformName()),
      'OS': _textProp(_osInfoText()),
      'Gerät': _textProp(_geraetInfoText()),
      'Zeitstempel': {
        'date': {'start': now.toIso8601String()},
      },
      'Fingerprint': _textProp(fingerprint),
    };

    final children = <Map<String, dynamic>>[];
    if (fehlerText != null && fehlerText.isNotEmpty) {
      children.add(_headingBlock('Fehler'));
      children.add(_codeBlock(fehlerText));
    }
    if (protokoll.isNotEmpty) {
      final tail = protokoll.length > 100
          ? protokoll.sublist(protokoll.length - 100)
          : protokoll;
      children.add(_headingBlock(
          'Protokoll (${tail.length} von ${protokoll.length} Einträgen)'));
      children.add(_codeBlock(tail.join('\n')));
    }

    final body = <String, dynamic>{
      'parent': {'database_id': dbId},
      'properties': props,
      if (children.isNotEmpty) 'children': children,
    };

    final res = await http
        .post(Uri.parse('$_base/pages'),
            headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);

    if (res.statusCode != 200) {
      Fehlerbericht.log(
          'Notion: Bericht anlegen fehlgeschlagen (HTTP ${res.statusCode})');
      return false;
    }

    final pageId =
        (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String;

    // ── Screenshot: strikt best-effort ──────────────────────────────
    if (screenshot != null && !kIsWeb) {
      try {
        await _screenshotAnhaengen(pageId, screenshot);
      } catch (e) {
        Fehlerbericht.log(
            'Notion: Screenshot-Anhang fehlgeschlagen (ignoriert): $e');
      }
    }

    return true;
  }

  static String _titelFuer(
      String art, String? beschreibung, String? fehlerText, DateTime now) {
    String p2(int n) => n.toString().padLeft(2, '0');
    final zeit =
        '${p2(now.day)}.${p2(now.month)}. ${p2(now.hour)}:${p2(now.minute)}';
    final kern = (beschreibung != null && beschreibung.isNotEmpty)
        ? beschreibung
        : (fehlerText != null && fehlerText.isNotEmpty ? fehlerText : art);
    final kurz = kern.length > 60 ? '${kern.substring(0, 57)}...' : kern;
    return '$art – $kurz ($zeit)';
  }

  // ── Schritt 5: Registry aktualisieren (fire-and-forget) ─────────────
  static Future<void> _registryAktualisieren(
      {required String appKey, required String version}) async {
    try {
      var pageId = _registryPageIdCache;
      pageId ??= (await _registryEintragSuchen(appKey)).pageId;
      if (pageId == null) return;

      var berichte = 1;
      try {
        final getRes = await http
            .get(Uri.parse('$_base/pages/$pageId'), headers: _headers)
            .timeout(_timeout);
        if (getRes.statusCode == 200) {
          final data = jsonDecode(getRes.body) as Map<String, dynamic>;
          final props = data['properties'] as Map<String, dynamic>;
          final n = (props['Berichte'] as Map<String, dynamic>?)?['number'];
          if (n is num) berichte = n.toInt() + 1;
        }
      } catch (_) {
        // Zähler konnte nicht gelesen werden — wir schreiben trotzdem
        // mit einem plausiblen Startwert weiter.
      }

      final now = DateTime.now().toIso8601String();
      await http
          .patch(
            Uri.parse('$_base/pages/$pageId'),
            headers: _headers,
            body: jsonEncode({
              'properties': {
                'Letzte Meldung': {
                  'date': {'start': now},
                },
                'Version': _textProp(version.isEmpty ? 'unbekannt' : version),
                'Plattform': _selectProp(_plattformName()),
                'Berichte': {'number': berichte},
              },
            }),
          )
          .timeout(_timeout);
    } catch (e) {
      Fehlerbericht.log(
          'Notion: Registry-Update fehlgeschlagen (ignoriert): $e');
    }
  }

  // ── Screenshot-Upload (File-Upload-API) ─────────────────────────────
  static Future<void> _screenshotAnhaengen(
      String pageId, Uint8List bytes) async {
    // 1) Upload-Objekt anlegen
    final createRes = await http
        .post(
          Uri.parse('$_base/file_uploads'),
          headers: _headers,
          body: jsonEncode(
              {'filename': 'screenshot.png', 'content_type': 'image/png'}),
        )
        .timeout(_timeout);
    if (createRes.statusCode != 200) {
      Fehlerbericht.log(
          'Notion: file_uploads anlegen fehlgeschlagen (HTTP ${createRes.statusCode})');
      return;
    }
    final uploadId =
        (jsonDecode(createRes.body) as Map<String, dynamic>)['id'] as String;

    // 2) Datei per multipart hochladen
    final req = http.MultipartRequest(
        'POST', Uri.parse('$_base/file_uploads/$uploadId/send'))
      ..headers['Authorization'] = 'Bearer $_token'
      ..headers['Notion-Version'] = '2022-06-28'
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: 'screenshot.png'));
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    if (streamed.statusCode != 200) {
      Fehlerbericht.log(
          'Notion: Screenshot-Upload fehlgeschlagen (HTTP ${streamed.statusCode})');
      return;
    }

    // 3) Bild-Block an die Berichtsseite anhängen
    final attachRes = await http
        .patch(
          Uri.parse('$_base/blocks/$pageId/children'),
          headers: _headers,
          body: jsonEncode({
            'children': [
              {
                'object': 'block',
                'type': 'image',
                'image': {
                  'type': 'file_upload',
                  'file_upload': {'id': uploadId},
                },
              },
            ],
          }),
        )
        .timeout(_timeout);
    if (attachRes.statusCode != 200) {
      Fehlerbericht.log(
        'Notion: Screenshot-Block anhängen fehlgeschlagen (HTTP ${attachRes.statusCode})',
      );
    }
  }

  // ── Kleine JSON-Hilfsmittel ──────────────────────────────────────────
  static Map<String, dynamic> _titleProp(String text) => {
        'title': [
          {
            'text': {'content': _clip(text, 1900)},
          },
        ],
      };

  static Map<String, dynamic> _textProp(String text) => {
        'rich_text': [
          {
            'text': {'content': _clip(text, 1900)},
          },
        ],
      };

  static Map<String, dynamic> _selectProp(String name) => {
        'select': {'name': name},
      };

  static String _clip(String s, int max) =>
      s.length > max ? s.substring(0, max) : s;

  static String? _richTextPlain(dynamic prop) {
    if (prop is! Map<String, dynamic>) return null;
    final arr = prop['rich_text'] as List<dynamic>?;
    if (arr == null || arr.isEmpty) return null;
    final buf = StringBuffer();
    for (final t in arr) {
      final m = t as Map<String, dynamic>;
      buf.write(m['plain_text'] ??
          (m['text'] as Map<String, dynamic>?)?['content'] ??
          '');
    }
    return buf.toString();
  }

  /// Teilt Text in `rich_text`-Objekte à max. 1900 Zeichen (Notion-Limit:
  /// 2000 Zeichen pro Text-Objekt) — der Text wird dabei nie
  /// abgeschnitten, sondern auf mehrere Objekte verteilt.
  static List<Map<String, dynamic>> _richTextChunks(String text) {
    const maxLen = 1900;
    if (text.isEmpty) {
      return [
        {
          'type': 'text',
          'text': {'content': ''},
        },
      ];
    }
    final chunks = <Map<String, dynamic>>[];
    for (var i = 0; i < text.length; i += maxLen) {
      final end = min(i + maxLen, text.length);
      chunks.add({
        'type': 'text',
        'text': {'content': text.substring(i, end)},
      });
    }
    return chunks;
  }

  static Map<String, dynamic> _codeBlock(String text) => {
        'object': 'block',
        'type': 'code',
        'code': {
          'rich_text': _richTextChunks(text),
          'language': 'plain text',
        },
      };

  static Map<String, dynamic> _headingBlock(String text) => {
        'object': 'block',
        'type': 'heading_3',
        'heading_3': {
          'rich_text': [
            {
              'type': 'text',
              'text': {'content': text},
            },
          ],
        },
      };
}
