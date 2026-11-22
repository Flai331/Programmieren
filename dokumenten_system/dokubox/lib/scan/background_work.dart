import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Lässt längere Arbeit (Scan, Leerseiten, Texterkennung) weiterlaufen,
/// wenn die App in den Hintergrund geht oder das Handy gesperrt wird:
/// Android-Vordergrunddienst mit Benachrichtigung. Verschachtelt nutzbar.
class BackgroundWork {
  static const _ch = MethodChannel('dokubox/background');
  static int _depth = 0;

  /// Läuft gerade ein Scan/eine Verarbeitung?
  static bool get active => _depth > 0;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<T> run<T>(String text, Future<T> Function() work,
      {String? done}) async {
    if (!_supported) return work();
    _depth++;
    await _call('start', {'text': text});
    var ok = false;
    try {
      final r = await work();
      ok = true;
      return r;
    } finally {
      _depth--;
      if (_depth == 0) {
        // Fertig-Meldung nur, wenn man gerade nicht in der App ist.
        final away = WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
        await _call('stop', {'done': away ? (ok ? done : 'Scan abgebrochen') : null});
      } else {
        await _call('update', {'text': text});
      }
    }
  }

  /// Text der laufenden Benachrichtigung ändern (z. B. „Seite 3“).
  static Future<void> update(String text) async {
    if (_supported && _depth > 0) await _call('update', {'text': text});
  }

  static Future<void> _call(String m, Map<String, Object?> args) async {
    try {
      await _ch.invokeMethod(m, args);
    } catch (_) {
      // Ohne Dienst läuft es trotzdem – nur nicht abgesichert.
    }
  }
}
