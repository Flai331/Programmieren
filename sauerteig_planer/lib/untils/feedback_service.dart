import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/rendering.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  FEEDBACK & ERROR LOGGER
//
//  Primär: Telegram Bot → sendet Text + Screenshot direkt aus der App.
//  Fallback: öffnet E-Mail-App (ohne Bildanhang).
//
//  SETUP Telegram (einmalig, ~5 Minuten):
//  1. Öffne Telegram → schreibe @BotFather: /newbot
//  2. Folge den Anweisungen → du erhältst einen Bot-Token
//  3. Schreibe deinem neuen Bot eine beliebige Nachricht
//  4. Öffne im Browser:
//     https://api.telegram.org/bot<TOKEN>/getUpdates
//     → kopiere den Wert "id" aus "chat" → das ist deine Chat-ID
//  5. Trage beide Werte unten ein
// ═══════════════════════════════════════════════════════════════

class FeedbackService {
  // ── Telegram-Konfiguration ──────────────────────────────────
  static const String _botToken = 'DEIN_BOT_TOKEN';
  static const String _chatId   = 'DEINE_CHAT_ID';

  // E-Mail-Fallback
  static const String _supportEmail = 'trail.kauri7760@eagereverest.com';

  static bool get _telegramConfigured =>
      _botToken != 'DEIN_BOT_TOKEN' && _chatId != 'DEINE_CHAT_ID';

  static final List<String> _log = [];

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
      // showReportDialog awaitet jetzt das Schließen des Dialogs
    } finally {
      _dialogOpen = false;
    }
  }

  // ── Protokoll-Eintrag ───────────────────────────────────────
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

  // ── Automatischen Screenshot erfassen ──────────────────────
  // Wird VOR dem Dialog aufgerufen, damit der Dialog selbst
  // nicht im Screenshot erscheint.
  static Future<String?> _captureScreenshot() async {
    if (kIsWeb) { log('Screenshot: Web nicht unterstützt'); return null; }
    if (_repaintKey == null) { log('Screenshot: RepaintKey nicht gesetzt'); return null; }
    // Bis zu 3 Versuche – boundary.toImage() braucht einen abgeschlossenen Frame
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final ctx = _repaintKey!.currentContext;
        if (ctx == null) { log('Screenshot: context ist null'); return null; }
        final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) { log('Screenshot: RenderRepaintBoundary nicht gefunden'); return null; }

        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) { log('Screenshot: byteData ist null'); continue; }

        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/feedback_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        log('Screenshot gespeichert (${(byteData.lengthInBytes / 1024).round()} KB, Versuch $attempt)');
        return file.path;
      } catch (e) {
        log('Screenshot Versuch $attempt fehlgeschlagen: $e');
        // Einen Frame warten und nochmal versuchen
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    return null;
  }

  // ── Melde-Dialog öffnen ────────────────────────────────────
  // Screenshot wird vor dem Dialog aufgenommen (Dialog-UI bleibt sauber).
  static Future<void> showReportDialog(
    BuildContext context, {
    bool isAutoError = false,
  }) async {
    // Einen Frame warten damit alle Animationen/Rebuilds abgeschlossen sind
    await Future.delayed(Duration.zero);
    final screenshotPath = await _captureScreenshot();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: !isAutoError,
      builder: (_) => _FeedbackDialog(
        telegramAvailable: _telegramConfigured && !isAutoError,
        isAutoError: isAutoError,
        supportEmail: _supportEmail,
        initialPhotoPaths: screenshotPath != null ? [screenshotPath] : [],
        onSend: (note, photoPaths) => sendReport(
          userNote: note,
          photoPaths: photoPaths,
          forceEmail: isAutoError,
        ),
      ),
    );
  }

  // ── Fehlerbericht senden ───────────────────────────────────
  static Future<bool> sendReport({
    String? userNote,
    List<String>? photoPaths,
    bool forceEmail = false,
  }) async {
    final htmlText = _buildHtml(userNote);
    final plainText = _buildPlain(userNote);

    // Bei automatischem Fehler: direkt E-Mail-App öffnen (mit Anhang wenn möglich)
    if (forceEmail) {
      return _sendEmailWithAttachments(plainText, photoPaths ?? []);
    }

    if (_telegramConfigured) {
      final ok = await _tgSendMessage(htmlText);
      if (!kIsWeb && photoPaths != null) {
        for (final path in photoPaths) {
          await _tgSendPhoto(path);
        }
      }
      return ok;
    }

    // E-Mail-Fallback
    return _sendEmailWithAttachments(plainText, photoPaths ?? []);
  }

  // ── Telegram: Text ──────────────────────────────────────────
  static Future<bool> _tgSendMessage(String html) async {
    try {
      final res = await http
          .post(
            Uri.parse(
                'https://api.telegram.org/bot$_botToken/sendMessage'),
            body: {
              'chat_id': _chatId,
              'text': html,
              'parse_mode': 'HTML',
            },
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Telegram: Foto (multipart) ──────────────────────────────
  static Future<void> _tgSendPhoto(String filePath) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://api.telegram.org/bot$_botToken/sendPhoto'),
      );
      req.fields['chat_id'] = _chatId;
      req.fields['caption'] = '📸 Screenshot';
      req.files
          .add(await http.MultipartFile.fromPath('photo', filePath));
      await req.send().timeout(const Duration(seconds: 30));
    } catch (_) {}
  }

  // ── E-Mail mit Anhängen öffnen (Android + iOS) ─────────────
  static Future<bool> _sendEmailWithAttachments(
      String body, List<String> attachments) async {
    if (kIsWeb) return _sendEmailFallback(body);
    try {
      final email = Email(
        recipients: [_supportEmail],
        subject: 'Fehlerbericht – Sauerteig Planer',
        body: body,
        attachmentPaths: attachments,
      );
      await FlutterEmailSender.send(email);
      log('E-Mail geöffnet (${attachments.length} Anhang/Anhänge)');
      return true;
    } catch (e) {
      log('E-Mail öffnen fehlgeschlagen: $e – versuche Fallback');
      return _sendEmailFallback(body);
    }
  }

  // ── E-Mail-Fallback ohne Anhang (Web / Fehlerfall) ──────────
  static Future<bool> _sendEmailFallback(String body) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Fehlerbericht – Sauerteig Planer',
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

  static String _buildHtml(String? userNote) {
    final b = StringBuffer();
    if (userNote != null && userNote.isNotEmpty) {
      b.writeln('<b>🐛 FEHLERBESCHREIBUNG</b>');
      b.writeln(_esc(userNote));
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
  final bool telegramAvailable;
  final bool isAutoError;
  final String supportEmail;
  final List<String> initialPhotoPaths;
  final Future<bool> Function(String? note, List<String>? photoPaths) onSend;

  const _FeedbackDialog({
    required this.telegramAvailable,
    required this.onSend,
    required this.supportEmail,
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
    final paths = (!kIsWeb && _photoPaths.isNotEmpty) ? _photoPaths : null;
    // Referenzen VOR dem await sichern – nach async gap nicht mehr sicher
    final navigator  = Navigator.of(context);
    final messenger  = ScaffoldMessenger.of(context);
    final ok = await widget.onSend(note.isEmpty ? null : note, paths);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok
            ? (widget.telegramAvailable
                ? '✓ Fehlerbericht gesendet.'
                : '✓ E-Mail-App geöffnet.')
            : '✗ Senden fehlgeschlagen – Verbindung prüfen.'),
        backgroundColor: ok ? AppColors.green : AppColors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(
            widget.isAutoError ? Icons.warning_amber_rounded : Icons.bug_report,
            color: widget.isAutoError ? AppColors.orange : AppColors.gold,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            widget.isAutoError ? 'Fehler erkannt' : 'Fehler melden',
            style: TextStyle(
              color: widget.isAutoError ? AppColors.orange : AppColors.gold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoBanner(
              telegram: widget.telegramAvailable,
              hasPhotos: _photoPaths.isNotEmpty,
              isAutoError: widget.isAutoError,
              supportEmail: widget.supportEmail,
            ),
            const SizedBox(height: 12),

            // Screenshots (Picker nur im manuellen Modus)
            Row(
              children: [
                const Text('Screenshots',
                    style: TextStyle(color: AppColors.text2, fontSize: 13)),
                const Spacer(),
                if (!kIsWeb && !widget.isAutoError) ...[
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
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
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
            else if (!kIsWeb)
              Text(
                'Kamera- oder Galerie-Symbol antippen zum Hinzufügen.',
                style: TextStyle(
                    color: AppColors.text3.withValues(alpha: 0.7),
                    fontSize: 11),
              ),
            const SizedBox(height: 12),

            // Fehlerbeschreibung
            const Text('Was ist passiert?',
                style: TextStyle(color: AppColors.text2, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              maxLines: 3,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'z.B. "Timer startet nicht wenn ich tippe"',
                hintStyle: const TextStyle(
                    color: AppColors.text3, fontSize: 12),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sitzungs-Protokoll wird automatisch angehängt.',
              style: TextStyle(color: AppColors.text3, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen',
              style: TextStyle(color: AppColors.text2)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.bg,
          ),
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.bg),
                )
              : Icon(
                  widget.telegramAvailable ? Icons.send : Icons.email,
                  size: 16,
                ),
          label: Text(_sending
              ? 'Sende...'
              : widget.telegramAvailable
                  ? 'Senden'
                  : 'Per E-Mail senden'),
        ),
      ],
    );
  }
}

// ── Hilfsmittel ─────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final bool telegram;
  final bool hasPhotos;
  final bool isAutoError;
  final String supportEmail;
  const _InfoBanner({
    required this.telegram,
    required this.hasPhotos,
    required this.isAutoError,
    required this.supportEmail,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String text;
    final Color color;
    if (isAutoError) {
      color = AppColors.orange;
      icon = Icons.email_outlined;
      text = 'Wird per E-Mail gesendet an: $supportEmail';
    } else if (telegram) {
      color = AppColors.green;
      icon = Icons.send;
      text = 'Wird direkt aus der App gesendet (inkl. Screenshots)';
    } else if (hasPhotos) {
      color = AppColors.blue;
      icon = Icons.email_outlined;
      text = 'Öffnet E-Mail-App mit Screenshot als Anhang';
    } else {
      color = AppColors.blue;
      icon = Icons.email_outlined;
      text = 'Öffnet deine E-Mail-App – Adresse & Text sind bereits eingetragen';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

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
