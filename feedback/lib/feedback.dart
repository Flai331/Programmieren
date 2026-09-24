import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/rendering.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════
//  FEEDBACK & ERROR LOGGER — Reusable Flutter Package
//
//  Einmalig beim App-Start aufrufen:
//    FeedbackService.configure(
//      notionToken:  '...',   // direkter Notion-API-Token
//      notionDbId:   '...',   // Notion-Datenbank-ID
//      // ODER:
//      backendUrl:   'https://mein-server.de',  // POST /api/feedback
//      appName:      'Meine App',
//      supportEmail: 'info@example.com',
//      buildNumber:  42,
//      telegramBotToken: '...',  // optional
//      telegramChatId:   '...',  // optional
//    );
//
//  Kanäle (Priorität): Notion → Backend → Telegram → E-Mail
// ═══════════════════════════════════════════════════════════════

class FeedbackService {
  // ── Konfiguration ───────────────────────────────────────────
  static String _notionToken   = '';
  static String _notionDbId    = '';
  static String _backendUrl    = '';
  static String _appName       = 'App';
  static String _supportEmail  = '';
  static int    _buildNumber   = 0;
  static String _tgBotToken    = '';
  static String _tgChatId      = '';

  static void configure({
    String notionToken   = '',
    String notionDbId    = '',
    String backendUrl    = '',
    required String appName,
    required String supportEmail,
    int buildNumber      = 0,
    String telegramBotToken = '',
    String telegramChatId   = '',
  }) {
    _notionToken  = notionToken;
    _notionDbId   = notionDbId;
    _backendUrl   = backendUrl;
    _appName      = appName;
    _supportEmail = supportEmail;
    _buildNumber  = buildNumber;
    _tgBotToken   = telegramBotToken;
    _tgChatId     = telegramChatId;
  }

  static bool get _notionConfigured  => _notionToken.isNotEmpty && _notionDbId.isNotEmpty;
  static bool get _backendConfigured => _backendUrl.isNotEmpty;
  static bool get _tgConfigured      => _tgBotToken.isNotEmpty && _tgChatId.isNotEmpty;

  // ── In-Memory-Log ───────────────────────────────────────────
  static final List<String> _log = [];
  static List<String> get logEntries => List.unmodifiable(_log);

  // ── Screen-Tracking ─────────────────────────────────────────
  static String _currentScreen  = '';
  static String _screenContent  = '';
  static void setCurrentScreen(String name)    => _currentScreen = name;
  static void setScreenContent(String content) => _screenContent = content;
  static NavigatorObserver get screenObserver  => _ScreenObserver();

  // ── Snapshot / Benutzerrolle ─────────────────────────────────
  static final Map<String, String> _snapshot = {};
  static String _userRole = '';
  static void setSnapshot(String key, String value) => _snapshot[key] = value;
  static void setUserRole(String role) => _userRole = role;

  // ── Navigator / RepaintBoundary Keys ───────────────────────
  static GlobalKey? _repaintKey;
  static void setRepaintKey(GlobalKey key) => _repaintKey = key;

  static GlobalKey<NavigatorState>? _navigatorKey;
  static void setNavigatorKey(GlobalKey<NavigatorState> key) => _navigatorKey = key;

  // ── Schutz gegen mehrfache gleichzeitige Dialoge ────────────
  static bool _dialogOpen = false;

  // ── Auto-Send Dedup (gleicher Fehler max. alle 30 s) ────────
  static String?   _lastErrorFingerprint;
  static DateTime? _lastErrorSentAt;

  // ── Automatisch bei abgefangenem Fehler aufrufen ────────────
  static Future<void> showAutoErrorDialog() async {
    if (_dialogOpen) return;
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) return;
    _dialogOpen = true;
    try {
      await showReportDialog(ctx, isAutoError: true);
    } finally {
      _dialogOpen = false;
    }
  }

  // ── Protokoll-Methoden ──────────────────────────────────────
  static void log(String message) {
    final now = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    final entry = '[${p(now.hour)}:${p(now.minute)}:${p(now.second)}] $message';
    _log.add(entry);
    if (_log.length > 200) _log.removeAt(0);
    debugPrint(entry);
  }

  static void logEvent(String eventName, {Map<String, String>? details}) {
    final d = details != null && details.isNotEmpty
        ? ' | ${details.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    log('EVENT: $eventName$d');
  }

  static void logScreenLoad(String screenName, {String? additionalInfo}) {
    setCurrentScreen(screenName);
    log('📄 SCREEN: $screenName${additionalInfo != null ? ' ($additionalInfo)' : ''}');
  }

  static void logUserAction(String action, {Map<String, String>? context}) {
    final c = context != null && context.isNotEmpty
        ? ' | ${context.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    log('👆 ACTION: $action$c');
  }

  static void logApiCall(String endpoint, String method,
      {int? statusCode, String? error}) {
    if (error != null) {
      log('❌ API $method $endpoint → ERROR: $error');
    } else {
      log('🔗 API $method $endpoint → ${statusCode ?? '...'}');
    }
  }

  static void logSelection(String fieldName, String selectedValue,
      {List<String>? availableOptions}) {
    final opts = availableOptions != null
        ? ' [${availableOptions.join(', ')}]'
        : '';
    log('✓ AUSWAHL: $fieldName = "$selectedValue"$opts');
  }

  static void logInput(String fieldName, String value) {
    final display = value.length > 50 ? '${value.substring(0, 47)}...' : value;
    log('✏️ INPUT: $fieldName = "$display"');
  }

  static void logError(String error,
      {String? context, StackTrace? stackTrace}) {
    log('⚠️ ERROR: $error${context != null ? ' (Kontext: $context)' : ''}');
    if (stackTrace != null) {
      log('Stack: ${stackTrace.toString().split('\n').first}');
    }
    _autoSendError(error, context: context, stack: stackTrace);
  }

  static void logWidgetState(String widgetName, {Map<String, String>? state}) {
    if (state != null && state.isNotEmpty) {
      log('🎨 WIDGET: $widgetName | '
          '${state.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    } else {
      log('🎨 WIDGET: $widgetName');
    }
  }

  static void logDbOperation(String operation, String table,
      {String? id, bool success = true}) {
    final s = success ? '✓' : '✗';
    log('🗄️ DB $s $operation [$table]${id != null ? ' id=$id' : ''}');
  }

  // ── Auto-Send (fire-and-forget, mit Dedup) ──────────────────
  static void _autoSendError(String error,
      {String? context, StackTrace? stack}) {
    if (!_notionConfigured && !_backendConfigured) return;
    final fp  = '$error|$context';
    final now = DateTime.now();
    if (_lastErrorFingerprint == fp &&
        _lastErrorSentAt != null &&
        now.difference(_lastErrorSentAt!).inSeconds < 30) {
      return;
    }
    _lastErrorFingerprint = fp;
    _lastErrorSentAt      = now;
    _sendAutoError(error, context: context, stack: stack);
  }

  static Future<void> _sendAutoError(String error,
      {String? context, StackTrace? stack}) async {
    try {
      final now = DateTime.now();
      String pad(int n) => n.toString().padLeft(2, '0');
      final shortErr = error.length > 70 ? '${error.substring(0, 67)}...' : error;
      final titel = '⚠️ $shortErr — ${pad(now.day)}.${pad(now.month)} '
          '${pad(now.hour)}:${pad(now.minute)}';

      final logTail =
          _log.skip(_log.length > 50 ? _log.length - 50 : 0).join('\n');
      final body = [
        'FEHLER: $error',
        if (context != null) 'KONTEXT: $context',
        if (stack != null)
          'STACK:\n${stack.toString().split('\n').take(10).join('\n')}',
        if (_currentScreen.isNotEmpty) 'SEITE: $_currentScreen',
        '---',
        'PROTOKOLL:',
        logTail,
      ].join('\n');
      final truncated =
          body.length > 1990 ? '…${body.substring(body.length - 1989)}' : body;

      String os = _osString();

      if (_notionConfigured) {
        await http.post(
          Uri.parse('https://api.notion.com/v1/pages'),
          headers: {
            'Authorization': 'Bearer $_notionToken',
            'Notion-Version': '2022-06-28',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'parent': {'database_id': _notionDbId},
            'properties': await _notionFelder({
              'Titel':       {'title':     [{'text': {'content': titel}}]},
              'Status':      {'select':    {'name': 'Offen'}},
              'App-Version': {'rich_text': [{'text': {'content': 'Build $_buildNumber'}}]},
              'Protokoll':   {'rich_text': [{'text': {'content': truncated}}]},
              'OS':          {'rich_text': [{'text': {'content': os}}]},
              'Zeitstempel': {'date':      {'start': now.toIso8601String()}},
              'Beschreibung':{'rich_text': [{'text': {'content': error.length > 2000 ? error.substring(0, 2000) : error}}]},
            }),
          }),
        ).timeout(const Duration(seconds: 10));
      } else if (_backendConfigured) {
        await http.post(
          Uri.parse('$_backendUrl/api/feedback'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'titel':      titel,
            'protokoll':  truncated,
            'os':         os,
            'zeitstempel':now.toIso8601String(),
            'app_version':'Build $_buildNumber',
            'beschreibung': error,
          }),
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint('FeedbackService auto-send Fehler: $e');
    }
  }

  // ── Screenshot ──────────────────────────────────────────────
  static Future<String?> _captureScreenshot() async {
    if (kIsWeb) { log('Screenshot: Web nicht unterstützt'); return null; }
    if (!kIsWeb && Platform.isWindows) { log('Screenshot: Windows nicht unterstützt'); return null; }
    if (_repaintKey == null) { log('Screenshot: RepaintKey nicht gesetzt'); return null; }
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final ctx = _repaintKey!.currentContext;
        if (ctx == null) { log('Screenshot: context null'); return null; }
        final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) { log('Screenshot: RenderRepaintBoundary nicht gefunden'); return null; }
        final image    = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) { log('Screenshot: byteData null'); continue; }
        final dir  = await getTemporaryDirectory();
        final file = File('${dir.path}/feedback_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        log('Screenshot gespeichert '
            '(${(byteData.lengthInBytes / 1024).round()} KB, Versuch $attempt)');
        return file.path;
      } catch (e) {
        log('Screenshot Versuch $attempt fehlgeschlagen: $e');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    return null;
  }

  // ── Dialog öffnen ───────────────────────────────────────────
  static Future<void> showReportDialog(
    BuildContext context, {
    bool isAutoError = false,
  }) async {
    if (_dialogOpen) return;
    if (_currentScreen.isNotEmpty) {
      log('${isAutoError ? 'Auto-Fehler' : 'Fehlerbericht'} auf Screen: $_currentScreen');
    }
    if (!context.mounted) return;
    _dialogOpen = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: !isAutoError,
        builder: (_) => _FeedbackDialog(
          notionAvailable:    _notionConfigured || _backendConfigured,
          telegramAvailable:  _tgConfigured && !isAutoError,
          isAutoError:        isAutoError,
          supportEmail:       _supportEmail,
          appName:            _appName,
          initialPhotoPaths:  const [],
          onSend: (note, photoPaths) => sendReport(
            userNote:   note,
            photoPaths: photoPaths,
          ),
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  // ── Bericht senden ──────────────────────────────────────────
  static Future<bool> sendReport({
    String? userNote,
    List<String>? photoPaths,
  }) async {
    if (_notionConfigured) {
      final ok = await _notionSend(userNote);
      if (ok) {
        if (_tgConfigured && !kIsWeb && photoPaths != null) {
          for (final p in photoPaths) { await _tgSendPhoto(p); }
        }
        return true;
      }
      log('Notion fehlgeschlagen – E-Mail-Fallback');
    } else if (_backendConfigured) {
      final ok = await _backendSend(userNote);
      if (ok) return true;
      log('Backend fehlgeschlagen – E-Mail-Fallback');
    } else if (_tgConfigured) {
      final ok = await _tgSendMessage(_buildHtml(userNote));
      if (!kIsWeb && photoPaths != null) {
        for (final p in photoPaths) { await _tgSendPhoto(p); }
      }
      if (ok) return true;
    }
    return _sendEmail(_buildPlain(userNote), photoPaths ?? []);
  }

  // ── Notion ──────────────────────────────────────────────────

  /// Spaltenname → Typ der Notion-Datenbank. Beim ersten Senden geholt.
  static Map<String, String>? _notionSchema;

  static Future<Map<String, String>> _notionSchemaLaden() async {
    final bekannt = _notionSchema;
    if (bekannt != null) return bekannt;
    try {
      final res = await http.get(
        Uri.parse('https://api.notion.com/v1/databases/$_notionDbId'),
        headers: {
          'Authorization': 'Bearer $_notionToken',
          'Notion-Version': '2022-06-28',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        log('Notion-Schema: ${res.statusCode}');
        return const {};
      }
      final props = (jsonDecode(res.body) as Map)['properties'] as Map;
      final schema = <String, String>{
        for (final e in props.entries)
          e.key as String: ((e.value as Map)['type'] as String?) ?? '',
      };
      _notionSchema = schema;
      return schema;
    } catch (e) {
      log('Notion-Schema Fehler: $e');
      return const {};
    }
  }

  /// Passt die Felder an die Spalten der Datenbank an. Jede App hat ihre
  /// eigene Datenbank, und die Spalten heißen dort nicht überall gleich.
  /// Notion lehnt einen Bericht ganz ab, sobald ein Feld nicht existiert —
  /// darum wird umbenannt, was sich zuordnen lässt, und der Rest fällt weg.
  static Future<Map<String, dynamic>> _notionFelder(
      Map<String, dynamic> felder) async {
    final schema = await _notionSchemaLaden();
    if (schema.isEmpty) return felder;
    const andereNamen = <String, List<String>>{
      'App-Version':  ['Version', 'App Version', 'Build'],
      'Beschreibung': ['Description'],
      'Protokoll':    ['Log', 'Logs'],
      'Zeitstempel':  ['Datum', 'Date'],
      'OS':           ['System'],
      'Status':       ['Zustand'],
    };
    final passend = <String, dynamic>{};
    felder.forEach((name, wert) {
      if (schema.containsKey(name)) {
        passend[name] = wert;
        return;
      }
      // Die Titelspalte heißt je Datenbank anders, hat aber immer Typ „title".
      if (wert is Map && wert.containsKey('title')) {
        for (final e in schema.entries) {
          if (e.value == 'title') {
            passend[e.key] = wert;
            return;
          }
        }
      }
      for (final anderer in andereNamen[name] ?? const <String>[]) {
        if (schema.containsKey(anderer)) {
          passend[anderer] = wert;
          return;
        }
      }
      log('Notion: Spalte „$name" fehlt, Feld weggelassen');
    });
    return passend;
  }

  static Future<bool> _notionSend(String? userNote) async {
    try {
      final now   = DateTime.now();
      String pad(int n) => n.toString().padLeft(2, '0');
      final titel = 'Fehlerbericht ${pad(now.day)}.${pad(now.month)}.${now.year} '
          '${pad(now.hour)}:${pad(now.minute)}';

      final screenHeader = _currentScreen.isNotEmpty
          ? 'SEITE: $_currentScreen'
              '${_screenContent.isNotEmpty ? "\nINHALT: $_screenContent" : ""}'
              '\n---\n'
          : '';
      final protokoll = screenHeader + _log.join('\n');
      final protokollTrunc = protokoll.length > 1990
          ? '…${protokoll.substring(protokoll.length - 1989)}'
          : protokoll;

      final props = <String, dynamic>{
        'Titel':       {'title':     [{'text': {'content': titel}}]},
        'Status':      {'select':    {'name': 'Offen'}},
        'App-Version': {'rich_text': [{'text': {'content': 'Build $_buildNumber'}}]},
        'Protokoll':   {'rich_text': [{'text': {'content': protokollTrunc}}]},
        'OS':          {'rich_text': [{'text': {'content': _osString()}}]},
        'Zeitstempel': {'date':      {'start': now.toIso8601String()}},
      };
      if (userNote != null && userNote.isNotEmpty) {
        props['Beschreibung'] = {
          'rich_text': [{'text': {'content': userNote.length > 2000 ? userNote.substring(0, 2000) : userNote}}],
        };
      }

      final res = await http.post(
        Uri.parse('https://api.notion.com/v1/pages'),
        headers: {
          'Authorization':  'Bearer $_notionToken',
          'Notion-Version': '2022-06-28',
          'Content-Type':   'application/json',
        },
        body: jsonEncode({
          'parent': {'database_id': _notionDbId},
          'properties': await _notionFelder(props),
        }),
      ).timeout(const Duration(seconds: 15));

      log('Notion: ${res.statusCode}');
      if (res.statusCode != 200) {
        final t = res.body.length > 400 ? '${res.body.substring(0, 400)}…' : res.body;
        log('Notion Body: $t');
      }
      return res.statusCode == 200;
    } catch (e) {
      log('Notion Fehler: $e');
      return false;
    }
  }

  // ── Backend ─────────────────────────────────────────────────
  static Future<bool> _backendSend(String? userNote) async {
    try {
      final now = DateTime.now();
      String pad(int n) => n.toString().padLeft(2, '0');
      final titel = 'Fehlerbericht ${pad(now.day)}.${pad(now.month)}.${now.year} '
          '${pad(now.hour)}:${pad(now.minute)}';

      final screenHeader = _currentScreen.isNotEmpty
          ? 'SEITE: $_currentScreen'
              '${_screenContent.isNotEmpty ? "\nINHALT: $_screenContent" : ""}'
              '\n---\n'
          : '';
      final protokoll = screenHeader + _log.join('\n');
      final protokollTrunc = protokoll.length > 1990
          ? '…${protokoll.substring(protokoll.length - 1989)}'
          : protokoll;

      final payload = <String, dynamic>{
        'titel':       titel,
        'protokoll':   protokollTrunc,
        'os':          _osString(),
        'zeitstempel': now.toIso8601String(),
        'app_version': 'Build $_buildNumber',
        if (_userRole.isNotEmpty) 'benutzerrolle': _userRole,
        if (userNote != null && userNote.isNotEmpty) 'beschreibung': userNote,
        if (_snapshot.isNotEmpty)
          'snapshot': _snapshot.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
      };

      final res = await http.post(
        Uri.parse('$_backendUrl/api/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      log('Backend: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      log('Backend Fehler: $e');
      return false;
    }
  }

  // ── Telegram ────────────────────────────────────────────────
  static Future<bool> _tgSendMessage(String html) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.telegram.org/bot$_tgBotToken/sendMessage'),
        body: {'chat_id': _tgChatId, 'text': html, 'parse_mode': 'HTML'},
      ).timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _tgSendPhoto(String filePath) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.telegram.org/bot$_tgBotToken/sendPhoto'),
      );
      req.fields['chat_id'] = _tgChatId;
      req.fields['caption'] = '📸 Screenshot';
      req.files.add(await http.MultipartFile.fromPath('photo', filePath));
      await req.send().timeout(const Duration(seconds: 30));
    } catch (_) {}
  }

  // ── E-Mail ──────────────────────────────────────────────────
  static Future<bool> _sendEmail(String body, List<String> attachments) async {
    if (kIsWeb || (!kIsWeb && Platform.isWindows)) {
      return _mailtoFallback(body);
    }
    try {
      final email = Email(
        recipients:      [_supportEmail],
        subject:         '[$_appName] Fehlerbericht',
        body:            body,
        attachmentPaths: attachments,
      );
      await FlutterEmailSender.send(email);
      log('E-Mail geöffnet (${attachments.length} Anhang/Anhänge)');
      return true;
    } catch (e) {
      log('E-Mail öffnen fehlgeschlagen: $e – versuche mailto Fallback');
      return _mailtoFallback(body);
    }
  }

  static Future<bool> _mailtoFallback(String body) async {
    final uri = Uri(
      scheme: 'mailto',
      path:   _supportEmail,
      queryParameters: {
        'subject': '[$_appName] Fehlerbericht',
        'body':    body,
      },
    );
    try {
      await launchUrl(uri);
      return true;
    } catch (e) {
      log('mailto Fallback fehlgeschlagen: $e');
      return false;
    }
  }

  // ── Report-Text ─────────────────────────────────────────────
  static String buildReportText(String? userNote) => _buildPlain(userNote);

  static String _buildHtml(String? userNote) {
    final b = StringBuffer();
    if (userNote != null && userNote.isNotEmpty) {
      b.writeln('<b>🐛 FEHLERBESCHREIBUNG</b>');
      b.writeln(_esc(userNote));
      b.writeln();
    }
    if (_currentScreen.isNotEmpty) {
      b.writeln('<b>📱 AKTUELLE SEITE</b>');
      b.writeln('Seite: $_currentScreen');
      if (_screenContent.isNotEmpty) b.writeln('Inhalt: $_screenContent');
      b.writeln();
    }
    b.writeln('<b>📋 PROTOKOLL</b>');
    if (_log.isEmpty) {
      b.writeln('(keine Einträge)');
    } else {
      for (final e in _log) { b.writeln(_esc(e)); }
    }
    b.writeln();
    if (_snapshot.isNotEmpty || _userRole.isNotEmpty) {
      b.writeln('<b>📊 ZUSTAND</b>');
      if (_userRole.isNotEmpty) b.writeln('Benutzerrolle: $_userRole');
      for (final e in _snapshot.entries) { b.writeln('${e.key}: ${e.value}'); }
      b.writeln();
    }
    b.writeln('<b>📱 SYSTEM</b>');
    b.writeln('App: $_appName');
    b.writeln('Build: #$_buildNumber');
    b.writeln('Zeit: ${DateTime.now()}');
    if (!kIsWeb) {
      try {
        b.writeln('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      } catch (_) {}
    }
    return b.toString();
  }

  static String _buildPlain(String? userNote) => _buildHtml(userNote)
      .replaceAll('<b>', '').replaceAll('</b>', '')
      .replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>');

  static String _esc(String s) => s
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static String _osString() {
    if (kIsWeb) return 'Web';
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'unbekannt';
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  FEEDBACK DIALOG
// ═══════════════════════════════════════════════════════════════

class _FeedbackDialog extends StatefulWidget {
  final bool notionAvailable;
  final bool telegramAvailable;
  final bool isAutoError;
  final String supportEmail;
  final String appName;
  final List<String> initialPhotoPaths;
  final Future<bool> Function(String? note, List<String>? photoPaths) onSend;

  const _FeedbackDialog({
    required this.notionAvailable,
    required this.telegramAvailable,
    required this.onSend,
    required this.supportEmail,
    required this.appName,
    this.isAutoError        = false,
    this.initialPhotoPaths  = const [],
  });

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _controller = TextEditingController();
  late List<String> _photoPaths;
  bool _sending     = false;
  bool _logExpanded = false;
  bool _copied      = false;

  @override
  void initState() {
    super.initState();
    _photoPaths = List.from(widget.initialPhotoPaths);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadScreenshot());
  }

  Future<void> _loadScreenshot() async {
    final path = await FeedbackService._captureScreenshot();
    if (path != null && mounted) {
      setState(() => _photoPaths.insert(0, path));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canPickImages =>
      !kIsWeb && !(Platform.isWindows) && !widget.isAutoError;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (picked != null) setState(() => _photoPaths.add(picked.path));
    } catch (_) {}
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final note      = _controller.text.trim();
    final paths     = (!kIsWeb && _photoPaths.isNotEmpty) ? _photoPaths : null;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok        = await widget.onSend(note.isEmpty ? null : note, paths);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? (widget.notionAvailable || widget.telegramAvailable
              ? '✓ Fehlerbericht gesendet.'
              : '✓ E-Mail-App geöffnet.')
          : '✗ Senden fehlgeschlagen – Verbindung prüfen.'),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final titleColor =
        widget.isAutoError ? Colors.orange : Colors.deepOrange;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(children: [
        Icon(
          widget.isAutoError ? Icons.warning_amber_rounded : Icons.bug_report,
          color: titleColor, size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          widget.isAutoError ? 'Fehler erkannt' : 'Fehler melden',
          style: TextStyle(color: titleColor),
        ),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 300),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBanner(
                notion:       widget.notionAvailable,
                telegram:     widget.telegramAvailable,
                hasPhotos:    _photoPaths.isNotEmpty,
                isAutoError:  widget.isAutoError,
                supportEmail: widget.supportEmail,
              ),
              const SizedBox(height: 12),

              // Screenshots
              Row(children: [
                const Text('Screenshots',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const Spacer(),
                if (_canPickImages) ...[
                  _SmallIconBtn(
                    icon: Icons.camera_alt,
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  const SizedBox(width: 4),
                  _SmallIconBtn(
                    icon: Icons.photo_library,
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              if (!kIsWeb && _photoPaths.isNotEmpty)
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_photoPaths[i]),
                          width: 90, height: 90, fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _photoPaths.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 13),
                          ),
                        ),
                      ),
                    ]),
                  ),
                )
              else if (!kIsWeb && !Platform.isWindows)
                Text(
                  'Kamera- oder Galerie-Symbol antippen zum Hinzufügen.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              const SizedBox(height: 12),

              // Fehlerbeschreibung
              const Text('Was ist passiert?',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              TextField(
                controller: _controller,
                maxLines:   3,
                decoration: InputDecoration(
                  hintText:  'z.B. "Daten lassen sich nicht speichern"',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Protokoll (aufklappbar)
              GestureDetector(
                onTap: () => setState(() => _logExpanded = !_logExpanded),
                child: Row(children: [
                  const Text('📋 Protokoll',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const Spacer(),
                  Icon(
                    _logExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey, size: 18,
                  ),
                ]),
              ),
              if (_logExpanded) ...[
                const SizedBox(height: 6),
                Container(
                  height: 150,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.builder(
                    itemCount: FeedbackService.logEntries.length,
                    itemBuilder: (_, i) => Text(
                      FeedbackService.logEntries[i],
                      style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Text(
                    '${FeedbackService.logEntries.length} Einträge · '
                    'wird automatisch angehängt',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final note = _controller.text.trim();
                    final text = FeedbackService.buildReportText(
                        note.isEmpty ? null : note);
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!mounted) return;
                    setState(() => _copied = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? const Row(
                            key: ValueKey('ok'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Colors.green, size: 14),
                              SizedBox(width: 4),
                              Text('Kopiert!',
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 11)),
                            ])
                        : Row(
                            key: const ValueKey('copy'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy,
                                  color: Colors.grey.shade400, size: 14),
                              const SizedBox(width: 4),
                              Text('Kopieren',
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11)),
                            ]),
                  ),
                ),
              ]),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(
                  widget.notionAvailable || widget.telegramAvailable
                      ? Icons.send
                      : Icons.email,
                  size: 16),
          label: Text(_sending
              ? 'Sende...'
              : widget.notionAvailable || widget.telegramAvailable
                  ? 'Senden'
                  : 'Per E-Mail'),
        ),
      ],
    );
  }
}

// ── Info-Banner ──────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final bool notion;
  final bool telegram;
  final bool hasPhotos;
  final bool isAutoError;
  final String supportEmail;

  const _InfoBanner({
    required this.notion,
    required this.telegram,
    required this.hasPhotos,
    required this.isAutoError,
    required this.supportEmail,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String text;

    if (notion) {
      color = Colors.green.shade700;
      icon  = Icons.send;
      text  = 'Wird direkt aus der App gesendet – kein Login nötig';
    } else if (telegram) {
      color = Colors.blue.shade700;
      icon  = Icons.send;
      text  = 'Wird direkt aus der App gesendet (inkl. Screenshots)';
    } else if (isAutoError) {
      color = Colors.orange;
      icon  = Icons.email_outlined;
      text  = 'Öffnet E-Mail-App an: $supportEmail';
    } else if (hasPhotos) {
      color = Colors.blue;
      icon  = Icons.email_outlined;
      text  = 'Öffnet E-Mail-App mit Screenshot als Anhang';
    } else {
      color = Colors.blue;
      icon  = Icons.email_outlined;
      text  = 'Öffnet deine E-Mail-App – Adresse & Text sind eingetragen';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 11)),
        ),
      ]),
    );
  }
}

// ── Icon-Button ──────────────────────────────────────────────────
class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SmallIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(5),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }
}

// ── Screen-Observer ──────────────────────────────────────────────
class _ScreenObserver extends NavigatorObserver {
  static String? _routeName(Route route) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    final name = _routeName(route);
    if (name != null) FeedbackService.setCurrentScreen(name);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    final name = previousRoute != null ? _routeName(previousRoute) : null;
    if (name != null) FeedbackService.setCurrentScreen(name);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final name = newRoute != null ? _routeName(newRoute) : null;
    if (name != null) FeedbackService.setCurrentScreen(name);
  }
}
