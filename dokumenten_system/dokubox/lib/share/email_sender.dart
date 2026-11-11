import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// E-Mail mit Empfänger und Anhängen. Auf Android über einen eigenen Kanal
/// (Empfänger wird gesetzt), sonst Rückfall auf das normale Teilen.
Future<void> sendEmail({
  required List<String> to,
  required String subject,
  required String body,
  required List<String> files,
}) async {
  if (Platform.isAndroid) {
    try {
      await const MethodChannel('dokubox/email').invokeMethod('send', {
        'to': to,
        'subject': subject,
        'body': body,
        'files': files,
      });
      return;
    } on PlatformException {
      // weiter mit Teilen
    } on MissingPluginException {
      // weiter mit Teilen
    }
  }
  await SharePlus.instance.share(ShareParams(
    files: [for (final f in files) XFile(f, mimeType: 'application/pdf')],
    subject: subject,
    text: '${to.isEmpty ? '' : 'An: ${to.join(', ')}\n\n'}$body',
  ));
}
