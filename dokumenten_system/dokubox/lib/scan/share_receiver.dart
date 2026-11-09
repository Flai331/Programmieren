import 'dart:io';

import 'package:flutter/services.dart';

/// Holt PDFs ab, die über das Android-„Teilen"-Menü an DokuBox geschickt
/// wurden (siehe MainActivity.kt). Auf anderen Plattformen passiert nichts.
class ShareReceiver {
  static const _channel = MethodChannel('dokubox/share');

  /// [onAvailable] wird aufgerufen, wenn bei laufender App neue PDFs
  /// geteilt wurden; danach [takeSharedPdfs] aufrufen.
  static void listen(void Function() onAvailable) {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedPdfsAvailable') onAvailable();
    });
  }

  /// Liefert die Pfade der geteilten PDFs (Kopien im Cache) und leert die
  /// Warteschlange.
  static Future<List<String>> takeSharedPdfs() async {
    if (!Platform.isAndroid) return const [];
    try {
      final list = await _channel.invokeListMethod<String>('takeSharedPdfs');
      return list ?? const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}
