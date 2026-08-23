import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import 'feedback_report.dart';
import 'report_store.dart';

import '../build_info.dart';

// ═══════════════════════════════════════════════════════════════
//  FEEDBACK & ERROR LOGGER — BeeBrain
//
//  Ein Bericht wird zuerst lokal abgelegt und danach über das
//  Teilen-Menü des Systems weitergegeben (Notion-App, Mail,
//  Messenger …) oder in die Zwischenablage kopiert.
//
//  Kein Direktversand an einen Dienst: Dafür müsste ein
//  Zugangsschlüssel in der App liegen, und der lässt sich aus dem
//  fertigen Paket auslesen. Nichts geht mehr verloren, wenn das
//  Teilen abgebrochen wird – der Bericht bleibt in der Ablage.
// ═══════════════════════════════════════════════════════════════

/// Auf welchem Weg ein Bericht die App verlässt.
enum FeedbackDelivery {
  /// Direkt an die Support-Adresse.
  mail,

  /// Teilen-Menü des Systems – Notion-App, Messenger, Mail, …
  share,
}

class FeedbackService {
  /// Zieladresse für Fehlerberichte.
  static const String _supportEmail = 'error.404.found@outlook.de';

  /// Öffentlich, damit Screens die Adresse anzeigen können.
  static String get supportEmail => _supportEmail;
  static const String _appName = 'BeeBrain';

  /// Höchstzahl aufbewahrter Berichte.
  static const int _maxStoredReports = 50;

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

  // Auto-Send Dedup: gleicher Fehler max alle 30s
  static String? _lastErrorFingerprint;
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
    // Auto-Send zu Notion (fire-and-forget, mit Dedup)
    _autoSendError(error, context: context, stack: stackTrace);
  }

  /// Automatisch erkannte Fehler landen in der lokalen Ablage.
  /// Gleiche Fehler innerhalb von 30 Sekunden nur einmal.
  static void _autoSendError(String error,
      {String? context, StackTrace? stack}) {
    final fp = '$error|$context';
    final now = DateTime.now();
    if (_lastErrorFingerprint == fp &&
        _lastErrorSentAt != null &&
        now.difference(_lastErrorSentAt!).inSeconds < 30) {
      return;
    }
    _lastErrorFingerprint = fp;
    _lastErrorSentAt = now;
    // Kein await: Das Protokollieren darf den Programmablauf nicht bremsen.
    _storeAutoError(error, context: context, stack: stack);
  }

  static Future<void> _storeAutoError(String error,
      {String? context, StackTrace? stack}) async {
    try {
      final now = DateTime.now();
      String pad(int n) => n.toString().padLeft(2, '0');
      final shortErr =
          error.length > 70 ? '${error.substring(0, 67)}...' : error;
      final titel = '⚠️ $shortErr — ${pad(now.day)}.${pad(now.month)} '
          '${pad(now.hour)}:${pad(now.minute)}';

      final beschreibung = [
        'FEHLER: $error',
        if (context != null) 'KONTEXT: $context',
        if (stack != null)
          'STACK:\n${stack.toString().split('\n').take(10).join('\n')}',
      ].join('\n');

      await _storeReport(
        title: titel,
        note: beschreibung,
        isAutoError: true,
        photoPaths: const [],
      );
    } catch (e) {
      log('Bericht ablegen fehlgeschlagen: $e');
    }
  }

  /// Bericht in der lokalen Ablage speichern und zurückgeben.
  static Future<FeedbackReport> _storeReport({
    required String title,
    String? note,
    required bool isAutoError,
    required List<String> photoPaths,
  }) async {
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}-'
        '${now.microsecond.toString().padLeft(6, '0')}';

    // Screenshots liegen im temporären Verzeichnis, das das System jederzeit
    // leeren darf – deshalb in die Berichts-Ablage übernehmen.
    final namen = <String>[];
    for (var i = 0; i < photoPaths.length; i++) {
      final name = await ReportStore.adoptPhoto(photoPaths[i], id, i);
      if (name != null) namen.add(name);
    }

    final report = FeedbackReport(
      id: id,
      createdAt: now,
      title: title,
      note: note,
      log: _log.join('\n'),
      appVersion: '$kBuildNumber',
      os: _osLabel(),
      screen: _currentScreen,
      photoNames: namen,
      isAutoError: isAutoError,
    );

    await ReportStore.save(report);
    await ReportStore.pruneTo(_maxStoredReports);
    log('📝 Fehlerbericht abgelegt: $title');
    return report;
  }

  static String _osLabel() {
    if (kIsWeb) return 'Web';
    try {
      return '${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion}';
    } catch (_) {
      return '';
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
    if (!kIsWeb && Platform.isWindows) {
      log('Screenshot: Windows nicht unterstützt');
      return null;
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
    if (_dialogOpen) return;
    if (_currentScreen.isNotEmpty) {
      log('${isAutoError ? 'Auto-Fehler' : 'Fehlerbericht'} auf Screen: $_currentScreen');
    }
    // Dialog sofort zeigen — nicht auf Screenshot warten
    if (!context.mounted) return;
    _dialogOpen = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: !isAutoError,
        builder: (_) => _FeedbackDialog(
          isAutoError: isAutoError,
          supportEmail: _supportEmail,
          appName: _appName,
          // Screenshot wird im Dialog selbst im Hintergrund geladen
          initialPhotoPaths: const [],
          onSend: (note, photoPaths, delivery) => sendReport(
              userNote: note,
              photoPaths: photoPaths,
              delivery: delivery),
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  // ── Fehlerbericht ablegen und weitergeben ───────────────────

  /// Ergebnis eines Melde-Vorgangs.
  ///
  /// [stored] ist der entscheidende Teil: Der Bericht ist gespeichert, auch
  /// wenn das Teilen danach abgebrochen wird.
  /// [shared] sagt, ob das Teilen-Menü tatsächlich etwas übernommen hat.

  /// Bericht ablegen und auf dem gewählten Weg weitergeben.
  ///
  /// Rückgabe: true, wenn der Bericht abgelegt werden konnte. Was der Nutzer
  /// danach im Mail- oder Teilen-Menü tut, liegt außerhalb der App.
  static Future<bool> sendReport({
    String? userNote,
    List<String>? photoPaths,
    FeedbackDelivery delivery = FeedbackDelivery.mail,
  }) async {
    try {
      final now = DateTime.now();
      String pad(int n) => n.toString().padLeft(2, '0');
      final titel =
          'Fehlerbericht ${pad(now.day)}.${pad(now.month)}.${now.year} '
          '${pad(now.hour)}:${pad(now.minute)}';

      final report = await _storeReport(
        title: titel,
        note: userNote,
        isAutoError: false,
        photoPaths: photoPaths ?? const [],
      );
      switch (delivery) {
        case FeedbackDelivery.mail:
          // Ohne Mail-App nicht den Bericht verlieren, sondern das
          // Teilen-Menü anbieten.
          final perMail = await mailReport(report);
          if (!perMail) await shareReport(report);
        case FeedbackDelivery.share:
          await shareReport(report);
      }
      return true;
    } catch (e) {
      log('Fehlerbericht fehlgeschlagen: $e');
      return false;
    }
  }

  /// Bericht über das Teilen-Menü des Systems weitergeben.
  ///
  /// Damit landet er dort, wo der Nutzer ihn haben will – Notion-App, Mail,
  /// Messenger –, ohne dass die App einen Zugangsschlüssel kennen muss.
  static Future<bool> shareReport(FeedbackReport report) async {
    final text = report.asPlainText();
    try {
      final bilder = await ReportStore.photoPaths(report);
      if (bilder.isNotEmpty && !kIsWeb) {
        await Share.shareXFiles(
          [for (final pfad in bilder) XFile(pfad, mimeType: 'image/png')],
          subject: '[$_appName] ${report.title}',
          text: text,
        );
      } else {
        await Share.share(text, subject: '[$_appName] ${report.title}');
      }
      await ReportStore.save(report.copyWith(exported: true));
      return true;
    } catch (e) {
      log('Teilen fehlgeschlagen: $e');
      return false;
    }
  }

  /// Bericht in die Zwischenablage legen – zum Einfügen in Notion o.ä.
  static Future<bool> copyReport(FeedbackReport report) async {
    try {
      await Clipboard.setData(ClipboardData(text: report.asPlainText()));
      await ReportStore.save(report.copyWith(exported: true));
      log('📋 Fehlerbericht kopiert');
      return true;
    } catch (e) {
      log('Kopieren fehlgeschlagen: $e');
      return false;
    }
  }

  /// Bericht per E-Mail an den Support – nur noch als ausdrückliche Wahl,
  /// nicht mehr als stiller Notnagel.
  static Future<bool> mailReport(FeedbackReport report) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': '[$_appName] ${report.title}',
        'body': report.asPlainText(),
      },
    );
    try {
      // Rückgabewert auswerten: Ohne Mail-App meldet launchUrl false, und
      // vorher galt der Bericht trotzdem als versendet.
      final ok = await launchUrl(uri);
      if (ok) await ReportStore.save(report.copyWith(exported: true));
      if (!ok) log('Keine E-Mail-App gefunden');
      return ok;
    } catch (e) {
      log('E-Mail öffnen fehlgeschlagen: $e');
      return false;
    }
  }

  /// Abgelegte Berichte, neueste zuerst.
  static Future<List<FeedbackReport>> storedReports() => ReportStore.list();

  static Future<void> deleteReport(String id) => ReportStore.delete(id);

  static Future<void> deleteAllReports() => ReportStore.deleteAll();

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
  final bool isAutoError;
  final String supportEmail;
  final String appName;
  final List<String> initialPhotoPaths;
  final Future<bool> Function(
      String? note, List<String>? photoPaths, FeedbackDelivery delivery) onSend;

  const _FeedbackDialog({
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
    // Screenshot nach Dialog-Öffnung im Hintergrund laden
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAutoScreenshot();
    });
  }

  Future<void> _loadAutoScreenshot() async {
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (picked != null) setState(() => _photoPaths.add(picked.path));
    } catch (_) {}
  }

  Future<void> _send(FeedbackDelivery delivery) async {
    setState(() => _sending = true);
    final note = _controller.text.trim();
    final paths =
        (!kIsWeb && _photoPaths.isNotEmpty) ? _photoPaths : null;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok =
        await widget.onSend(note.isEmpty ? null : note, paths, delivery);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? (delivery == FeedbackDelivery.mail
              ? '✓ Gespeichert – E-Mail an ${widget.supportEmail} vorbereitet.'
              : '✓ Gespeichert – wähle aus, wohin er soll.')
          : '✗ Bericht konnte nicht gespeichert werden.'),
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
        TextButton.icon(
          onPressed:
              _sending ? null : () => _send(FeedbackDelivery.share),
          icon: const Icon(Icons.ios_share, size: 16),
          label: const Text('Teilen'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _peach,
            foregroundColor: Colors.white,
          ),
          onPressed:
              _sending ? null : () => _send(FeedbackDelivery.mail),
          icon: _sending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.mail_outline, size: 16),
          label: Text(_sending ? 'Speichere...' : 'Per Mail'),
        ),
      ],
    );
  }
}

// ── Info-Banner ──────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final bool isAutoError;
  final String supportEmail;

  const _InfoBanner({
    required this.isAutoError,
    required this.supportEmail,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String text;

    if (isAutoError) {
      color = Colors.orange;
      icon = Icons.save_outlined;
      text = 'Wird gespeichert – danach wählst du, wohin er soll';
    } else {
      color = Colors.blue;
      icon = Icons.mail_outline;
      text = 'Wird gespeichert und geht an $supportEmail. '
          'Über „Teilen" auch an jede andere App. Alle Berichte findest '
          'du unter Einstellungen.';
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
