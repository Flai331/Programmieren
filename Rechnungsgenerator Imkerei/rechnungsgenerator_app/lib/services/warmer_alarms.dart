import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../utils/feedback_service.dart';
import 'honey_service.dart';

/// Meldet, wenn ein Eimer im Wärmeschrank fertig ist.
///
/// Die Weckzeit setzt Android, die Meldung baut eigenes Kotlin
/// (`WarmerAlarms.kt`). Warum nicht `flutter_local_notifications`: das Paket
/// verlangt *core library desugaring*, und dieses Projekt steht auf AGP 9.1.0,
/// wo `file_picker` ganz verloren ging.
///
/// Zwei Dinge, die dieser Dienst bewusst nicht tut: Er hält keine eigene
/// Liste offener Uhren – die steht im Eimer-Verlauf, und [reregister] liest
/// sie dort. Und er fragt nicht beim Start nach der Erlaubnis, sondern erst
/// beim Starten einer Uhr: dann ist der Grund sichtbar.
class WarmerAlarms {
  static final WarmerAlarms _instance = WarmerAlarms._internal();
  WarmerAlarms._internal();
  factory WarmerAlarms() => _instance;

  static const MethodChannel channel = MethodChannel('beebrain/warmer');

  /// Nur Android trägt die Kotlin-Seite. Auf allem anderen – und im Test –
  /// tut dieser Dienst nichts und sagt das auch.
  @visibleForTesting
  bool available = Platform.isAndroid;

  /// Darf die App melden? Falsch heißt: die Uhr läuft, sie meldet sich nur
  /// nicht.
  Future<bool> canNotify() async {
    if (!available) return false;
    try {
      return await channel.invokeMethod<bool>('canNotify') ?? false;
    } catch (e) {
      FeedbackService.log('⚠️ Meldungen nicht abfragbar: $e');
      return false;
    }
  }

  /// Nach der Erlaubnis fragen. Ab Android 13 erscheint der Systemdialog;
  /// vorher zählt allein, ob die Meldungen der App abgeschaltet sind.
  Future<bool> requestPermission() async {
    if (!available) return false;
    try {
      return await channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (e) {
      FeedbackService.log('⚠️ Erlaubnis nicht erfragbar: $e');
      return false;
    }
  }

  /// Die Weckzeit für einen Eimer setzen. Eine zweite ersetzt die erste.
  ///
  /// Eine Fälligkeit in der Vergangenheit wird nicht gesetzt: eine Meldung,
  /// die sofort kommt, sagt nichts, was nicht schon am Eimer steht.
  Future<bool> schedule({
    required HoneyBucketModel bucket,
    required HoneyWarmer warmer,
    DateTime? now,
  }) async {
    if (!available) return false;
    final jetzt = now ?? DateTime.now();
    if (!warmer.dueAt.isAfter(jetzt)) return false;

    try {
      return await channel.invokeMethod<bool>('schedule', {
            'bucketId': bucket.id,
            'dueAtMillis': warmer.dueAt.millisecondsSinceEpoch,
            'title': titleFor(bucket),
            'text': textFor(bucket, warmer),
          }) ??
          false;
    } catch (e) {
      FeedbackService.log('⚠️ Weckzeit nicht gesetzt: $e');
      return false;
    }
  }

  Future<void> cancel(String bucketId) async {
    if (!available) return;
    try {
      await channel.invokeMethod<bool>('cancel', {'bucketId': bucketId});
    } catch (e) {
      FeedbackService.log('⚠️ Weckzeit nicht abgenommen: $e');
    }
  }

  /// Die offenen Uhren neu anmelden – beim Start der App.
  ///
  /// Ein Neustart des Handys löscht alle Weckzeiten. Die Uhren selbst stehen
  /// im Eimer-Verlauf, also lassen sie sich von dort wiederherstellen. Gibt
  /// zurück, wie viele angemeldet wurden.
  Future<int> reregister({HoneyService? honey, DateTime? now}) async {
    if (!available) return 0;
    try {
      final offen = await (honey ?? HoneyService()).runningWarmers();
      var gesetzt = 0;
      for (final uhr in offen) {
        if (await schedule(bucket: uhr.bucket, warmer: uhr.warmer, now: now)) {
          gesetzt++;
        }
      }
      if (offen.isNotEmpty) {
        FeedbackService.log(
            '⏱️ Wärmeschrank: $gesetzt von ${offen.length} Uhren angemeldet');
      }
      return gesetzt;
    } catch (e) {
      FeedbackService.log('⚠️ Uhren nicht wieder angemeldet: $e');
      return 0;
    }
  }

  /// Der Titel der Meldung. Der Code steht vorn: er ist das, was auf dem
  /// Eimer steht.
  @visibleForTesting
  static String titleFor(HoneyBucketModel bucket) =>
      'Eimer ${bucket.code} ist durchgewärmt';

  @visibleForTesting
  static String textFor(HoneyBucketModel bucket, HoneyWarmer warmer) =>
      '${bucket.varietyLabel} stand ${warmer.requiredHours} h im '
      'Wärmeschrank und kann heraus.';
}
