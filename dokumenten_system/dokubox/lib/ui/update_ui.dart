import 'package:flutter/material.dart';

import '../lock/lock_gate.dart';
import '../update/updater.dart';

/// Sucht nach einer neuen Version und installiert sie nach Rückfrage.
/// [silent]: keine Meldung, wenn alles aktuell ist oder offline.
Future<void> checkForUpdate(BuildContext context, {bool silent = false}) async {
  final messenger = ScaffoldMessenger.of(context);
  UpdateInfo? info;
  try {
    info = await Updater.check();
  } catch (e) {
    if (!silent) messenger.showSnackBar(SnackBar(content: Text('Update-Prüfung fehlgeschlagen: $e')));
    return;
  }
  if (info == null) {
    if (!silent) {
      messenger.showSnackBar(const SnackBar(content: Text('DokuBox ist aktuell.')));
    }
    return;
  }
  if (!context.mounted) return;
  if (silent) {
    final found = info;
    messenger.showSnackBar(SnackBar(
      content: Text('Neue Version (Build ${found.build}) verfügbar'),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
          label: 'Aktualisieren', onPressed: () => _install(context, found)),
    ));
    return;
  }
  await _install(context, info);
}

Future<void> _install(BuildContext context, UpdateInfo info) async {
  final progress = ValueNotifier<double>(0);
  final mb = (info.size / 1e6).round();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Aktualisieren'),
      content: Text('Neue Version Build ${info.build} ($mb MB) herunterladen '
          'und installieren? Deine Daten bleiben erhalten.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Später')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Aktualisieren')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final nav = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Lade Update …'),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, v, _) => LinearProgressIndicator(value: v == 0 ? null : v),
      ),
    ),
  );
  // Installer ist eine eigene Activity → App-Sperre kurz aussetzen.
  LockController.suppressAutoLock = true;
  String? error;
  try {
    await Updater.install(info, (v) => progress.value = v);
  } catch (e) {
    error = '$e';
  } finally {
    LockController.suppressAutoLock = false;
  }
  nav.pop();
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}
