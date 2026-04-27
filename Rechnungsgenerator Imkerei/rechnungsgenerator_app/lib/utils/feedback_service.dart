import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../build_info.dart';
import 'app_secrets.dart';

// ═══════════════════════════════════════════════════════════════
//  FEEDBACK & ERROR LOGGER — Rechnungsgenerator Imkerei
//
//  Primär: Notion-Datenbank → sendet direkt aus der App.
//  Fallback: öffnet E-Mail-App (nur wenn Notion fehlschlägt).
// ═══════════════════════════════════════════════════════════════

class FeedbackService {
  // ── Notion-Konfiguration ────────────────────────────────────
  // Token aus app_secrets.dart (gitignoriert, nie committen)
  static const String _notionToken = kNotionToken;
  static const String _notionDbId  = kNotionDbId;

  // E-Mail-Empfänger (Fallback)
  static const String _supportEmail = 'klaasotte99@gmail.com';
  static const String _appName = 'Rechnungsgenerator Imkerei';

  static bool get _notionConfigured => _notionToken.isNotEmpty;

  static final List<String> _log = [];

  // ── Screen-Tracking ─────────────────────────────────────────
  static String _currentScreen = '';
  static String _screenContent = '';
  static void setCurrentScreen(String name) => _currentScreen = name;
  static void setScreenContent(String content) => _screenContent = content;
  static NavigatorObserver get screenObserver => _ScreenObserver();

  // Key vom RepaintBoundary in main.dart (für Auto-Screenshot)
  static GlobalKey? _repaintKey;
  static void setRepaintKey(GlobalKey key) => _repaintKey = key;

  // Navigator-Key für automatische Dialog-Öffnung ohne BuildContext
  static GlobalKey<NavigatorState>? _navigatorKey;
  static void setNavigatorKey(GlobalKey<NavigatorState> key) =>
      _navigatorKey = key;

  // Verhindert dass mehrere Fehler gleichzeitig mehrere Dialoge öffnen
  static bool _dialogOpen = false;

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

  // ── Protokoll-Einträge ──────────────────────────────────────
  static void log(String message) {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final entry = '[$h:$m:$s] $message';
    _log.add(entry);
    if (_log.length > 200) _log.removeAt(0);
    debugPrint(entry);
  }

  static void logEvent(String eventName, {Map<String, String>? details}) {
    final detailStr = details != null && details.isNotEmpty
        ? ' | ${details.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    log('EVENT: $eventName$detailStr');
  }

  static void logScreenLoad(String screenName, {String? additionalInfo}) {
    setCurrentScreen(screenName);
    log('📄 SCREEN: $screenName'
        '${additionalInfo != null ? ' ($additionalInfo)' : ''}');
  }

  static void logUserAction(String action, {Map<String, String>? context}) {
    final ctx = context != null && context.isNotEmpty
        ? ' | ${context.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    log('👆 ACTION: $action$ctx');
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
    final opts =
        availableOptions != null ? ' [${availableOptions.join(', ')}]' : '';
    log('✓ AUSWAHL: $fieldName = "$selectedValue"$opts');
  }

  static void logInput(String fieldName, String value) {
    final display =
        value.length > 50 ? '${value.substring(0, 47)}...' : value;
    log('✏️ INPUT: $fieldName = "$display"');
  }

  static void logError(String error,
      {String? context, StackTrace? stackTrace}) {
    log('⚠️ ERROR: $error'
        '${context != null ? ' (Kontext: $context)' : ''}');
    if (stackTrace != null) {
      log('Stack: ${stackTrace.toString().split('\n').first}');
    }
  }

  static void logWidgetState(String widgetName,
      {Map<String, String>? state}) {
    if (state != null && state.isNotEmpty) {
      log('🎨 WIDGET: $widgetName | '
          '${state.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    } else {
      log('🎨 WIDGET: $widgetName');
    }
  }

  static void logDbOperation(String operation, String table,
      {String? id, bool success = true}) {
    final status = success ? '✓' : '✗';
    log('🗄️ DB $status $operation [$table]${id != null ? ' id=$id' : ''}');
  }

  static void logPdfGeneration(String invoiceNumber, {bool success = true}) {
    if (success) {
      log('📄 PDF generiert: $invoiceNumber');
    } else {
      log('❌ PDF fehlgeschlagen: $invoiceNumber');
    }
  }

  // ── Öffentliche API ─────────────────────────────────────────
  static List<String> get logEntries => List.unmodifiable(_log);

  static String buildReportText(String? userNote) =>
      _buildPlain(userNote);

  // ── Screenshot erfassen ─────────────────────────────────────
  static Future<String?> _captureScreenshot() async {
    if (kIsWeb) {
      log('Screenshot: Web nicht unterstützt');
      return null;
    }
    // Kamera-Screenshot auf Windows nicht verfügbar
    if (!kIsWeb && Platform.isWindows) {
      log('Screenshot: Windows-Repaint wird versucht');
    }
    if (_repaintKey == null) {
      log('Screenshot: RepaintKey nicht gesetzt');
      return null;
    }
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final ctx = _repaintKey!.currentContext;
        if (ctx == null) {
          log('Screenshot: context ist null');
          return null;
        }
        final boundary =
            ctx.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          log('Screenshot: RenderRepaintBoundary nicht gefunden');
          return null;
        }

        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          log('Screenshot: byteData ist null');
          continue;
        }

        final dir = await getTemporaryDirectory();
        final file = File(
            '${dir.path}/feedback_${DateTime.now().millisecondsSinceEpoch}.png');
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

  // ── Melde-Dialog öffnen ─────────────────────────────────────
  static Future<void> showReportDialog(
    BuildContext context, {
    bool isAutoError = false,
  }) async {
    if (_currentScreen.isNotEmpty) {
      log('${isAutoError ? 'Auto-Fehler' : 'Fehlerbericht'} auf Screen: $_currentScreen');
    }
    await Future.delayed(Duration.zero);
    final screenshotPath = await _captureScreenshot();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: !isAutoError,
      builder: (_) => _FeedbackDialog(
        notionAvailable: _notionConfigured,
        isAutoError: isAutoError,
        supportEmail: _supportEmail,
        appName: _appName,
        initialPhotoPaths:
            screenshotPath != null ? [screenshotPath] : [],
        onSend: (note, photoPaths) =>
            sendReport(userNote: note, photoPaths: photoPaths),
      ),
    );
  }

  // ── Fehlerbericht senden ────────────────────────────────────
  static Future<bool> sendReport({
    String? userNote,
    List<String>? photoPaths,
  }) async {
    if (_notionConfigured) {
      final ok = await _notionSend(userNote);
      if (ok) return true;
      log('Notion fehlgeschlagen – öffne E-Mail-Fallback');
    }
    return _sendEmail(_buildPlain(userNote), photoPaths ?? []);
  }

  // ── Notion: Fehlerbericht anlegen ───────────────────────────
  static Future<bool> _notionSend(String? userNote) async {
    try {
      final now = DateTime.now();
      String pad(int n) => n.toString().padLeft(2, '0');
      final titel =
          'Fehlerbericht ${pad(now.day)}.${pad(now.month)}.${now.year} '
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

      String os = 'Web';
      if (!kIsWeb) {
        try {
          os =
              '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
        } catch (_) {}
      }

      final props = <String, dynamic>{
        'Titel': {
          'title': [
            {
              'text': {'content': titel}
            }
          ]
        },
        'Status': {
          'select': {'name': 'Offen'}
        },
        'App-Version': {
          'rich_text': [
            {
              'text': {'content': 'Build $kBuildNumber'}
            }
          ]
        },
        'Protokoll': {
          'rich_text': [
            {
              'text': {'content': protokollTrunc}
            }
          ]
        },
        'OS': {
          'rich_text': [
            {
              'text': {'content': os}
            }
          ]
        },
        'Zeitstempel': {'date': {'start': now.toIso8601String()}},
        'App': {
          'rich_text': [
            {
              'text': {'content': _appName}
            }
          ]
        },
      };

      if (userNote != null && userNote.isNotEmpty) {
        final desc =
            userNote.length > 2000 ? userNote.substring(0, 2000) : userNote;
        props['Beschreibung'] = {
          'rich_text': [
            {
              'text': {'content': desc}
            }
          ]
        };
      }

      final res = await http
          .post(
            Uri.parse('https://api.notion.com/v1/pages'),
            headers: {
              'Authorization': 'Bearer $_notionToken',
              'Notion-Version': '2022-06-28',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
                {'parent': {'database_id': _notionDbId}, 'properties': props}),
          )
          .timeout(const Duration(seconds: 15));

      log('Notion: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      log('Notion Fehler: $e');
      return false;
    }
  }

  // ── E-Mail senden ───────────────────────────────────────────
  static Future<bool> _sendEmail(
      String body, List<String> photoPaths) async {
    // Auf Windows / Web: nur URL-Launcher (mailto:)
    if (kIsWeb || (!kIsWeb && Platform.isWindows)) {
      return _launchMailto(body);
    }

    // Mobile: flutter_email_sender mit Anhängen versuchen
    try {
      // Dynamischer Import über Reflection nicht möglich —
      // wir nutzen url_launcher als zuverlässige Fallback-Lösung
      return _launchMailto(body);
    } catch (e) {
      log('E-Mail öffnen fehlgeschlagen: $e');
      return false;
    }
  }

  static Future<bool> _launchMailto(String body) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': '[$_appName] Fehlerbericht',
        'body': body,
      },
    );
    try {
      await launchUrl(uri);
      return true;
    } catch (e) {
      log('E-Mail Fallback fehlgeschlagen: $e');
      return false;
    }
  }

  // ── Report-Text ─────────────────────────────────────────────
  static String buildPlainPublic(String? userNote) =>
      _buildPlain(userNote);

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
      if (_screenContent.isNotEmpty) {
        b.writeln('Inhalt: $_screenContent');
      }
      b.writeln();
    }
    b.writeln('<b>📋 PROTOKOLL</b>');
    if (_log.isEmpty) {
      b.writeln('(keine Einträge)');
    } else {
      for (final e in _log) {
        b.writeln(_esc(e));
      }
    }
    b.writeln();
    b.writeln('<b>📱 SYSTEM</b>');
    b.writeln('App: $_appName');
    b.writeln('Build: #$kBuildNumber');
    b.writeln('Zeit: ${DateTime.now()}');
    if (!kIsWeb) {
      try {
        b.writeln(
            'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      } catch (_) {}
    }
    return b.toString();
  }

  static String _buildPlain(String? userNote) => _buildHtml(userNote)
      .replaceAll('<b>', '')
      .replaceAll('</b>', '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

// ═══════════════════════════════════════════════════════════════
//  FEEDBACK DIALOG
// ═══════════════════════════════════════════════════════════════

class _FeedbackDialog extends StatefulWidget {
  final bool notionAvailable;
  final bool isAutoError;
  final String supportEmail;
  final String appName;
  final List<String> initialPhotoPaths;
  final Future<bool> Function(String? note, List<String>? photoPaths) onSend;

  const _FeedbackDialog({
    required this.notionAvailable,
    required this.onSend,
    required this.supportEmail,
    required this.appName,
    this.isAutoError = false,
    this.initialPhotoPaths = const [],
  });

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _controller = TextEditingController();
  late List<String> _photoPaths;
  bool _sending = false;
  bool _logExpanded = false;
  bool _copied = false;

  static const Color _peach = Color(0xFFfda085);

  @override
  void initState() {
    super.initState();
    _photoPaths = List.from(widget.initialPhotoPaths);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (picked != null) setState(() => _photoPaths.add(picked.path));
    } catch (_) {}
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final note = _controller.text.trim();
    final paths =
        (!kIsWeb && _photoPaths.isNotEmpty) ? _photoPaths : null;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok =
        await widget.onSend(note.isEmpty ? null : note, paths);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? (widget.notionAvailable
              ? '✓ Fehlerbericht gesendet.'
              : '✓ E-Mail-App geöffnet.')
          : '✗ Senden fehlgeschlagen – Verbindung prüfen.'),
      backgroundColor:
          ok ? Colors.green.shade700 : Colors.red.shade700,
    ));
  }

  // Ob Bildauswahl auf dieser Plattform verfügbar ist
  bool get _canPickImages =>
      !kIsWeb &&
      !(_isWindows) &&
      !widget.isAutoError;

  bool get _isWindows =>
      !kIsWeb && Platform.isWindows;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        widget.isAutoError ? Colors.orange : _peach;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(
            widget.isAutoError
                ? Icons.warning_amber_rounded
                : Icons.bug_report,
            color: titleColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            widget.isAutoError ? 'Fehler erkannt' : 'Fehler melden',
            style: TextStyle(color: titleColor),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 300),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBanner(
                notion: widget.notionAvailable,
                isAutoError: widget.isAutoError,
                supportEmail: widget.supportEmail,
              ),
              const SizedBox(height: 12),

              // Screenshots
              Row(
                children: [
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
                ],
              ),
              const SizedBox(height: 6),
              if (!kIsWeb && _photoPaths.isNotEmpty)
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoPaths.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 6),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_photoPaths[i]),
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _photoPaths.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(3),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!kIsWeb && !_isWindows)
                Text(
                  'Kamera- oder Galerie-Symbol antippen zum Hinzufügen.',
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 11),
                ),
              const SizedBox(height: 12),

              // Fehlerbeschreibung
              const Text('Was ist passiert?',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              TextField(
                controller: _controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'z.B. "PDF lässt sich nicht generieren"',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: _peach, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Protokoll (aufklappbar)
              GestureDetector(
                onTap: () =>
                    setState(() => _logExpanded = !_logExpanded),
                child: Row(
                  children: [
                    const Text('📋 Protokoll',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey)),
                    const Spacer(),
                    Icon(
                      _logExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.grey,
                      size: 18,
                    ),
                  ],
                ),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${FeedbackService.logEntries.length} Einträge · '
                      'wird automatisch angehängt',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final text = FeedbackService.buildReportText(
                          _controller.text.trim().isEmpty
                              ? null
                              : _controller.text.trim());
                      await Clipboard.setData(
                          ClipboardData(text: text));
                      if (!mounted) return;
                      setState(() => _copied = true);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          setState(() => _copied = false);
                        }
                      });
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _copied
                          ? const Row(
                              key: ValueKey('ok'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check,
                                    color: Colors.green, size: 14),
                                SizedBox(width: 4),
                                Text('Kopiert!',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 11)),
                              ],
                            )
                          : Row(
                              key: const ValueKey('copy'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy,
                                    color: Colors.grey.shade400,
                                    size: 14),
                                const SizedBox(width: 4),
                                Text('Kopieren',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 11)),
                              ],
                            ),
                    ),
                  ),
                ],
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
          style: ElevatedButton.styleFrom(
            backgroundColor: _peach,
            foregroundColor: Colors.white,
          ),
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(
                  widget.notionAvailable ? Icons.send : Icons.email,
                  size: 16),
          label: Text(_sending
              ? 'Sende...'
              : widget.notionAvailable ? 'Senden' : 'Per E-Mail'),
        ),
      ],
    );
  }
}

// ── Info-Banner ──────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final bool notion;
  final bool isAutoError;
  final String supportEmail;

  const _InfoBanner({
    required this.notion,
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
      icon = Icons.send;
      text = 'Wird direkt aus der App gesendet – kein Login nötig';
    } else if (isAutoError) {
      color = Colors.orange;
      icon = Icons.email_outlined;
      text = 'Öffnet E-Mail-App an: $supportEmail';
    } else {
      color = Colors.blue;
      icon = Icons.email_outlined;
      text = 'Öffnet deine E-Mail-App – Adresse & Text sind eingetragen';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child:
                Text(text, style: TextStyle(color: color, fontSize: 11)),
          ),
        ],
      ),
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
          color: Colors.black38,
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
    // Klassen-Namen für Push-Routen ohne Namen extrahieren
    final type = route.runtimeType.toString();
    if (type.contains('MaterialPageRoute')) {
      return route.settings.arguments?.toString();
    }
    return null;
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    final name = _routeName(route);
    if (name != null) FeedbackService.setCurrentScreen(name);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    final name =
        previousRoute != null ? _routeName(previousRoute) : null;
    if (name != null) FeedbackService.setCurrentScreen(name);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final name = newRoute != null ? _routeName(newRoute) : null;
    if (name != null) FeedbackService.setCurrentScreen(name);
  }
}
