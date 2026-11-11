import 'dart:io';

import '../app_services.dart';
import '../data/setup_mode.dart';
import '../scan/scan_service.dart';
import 'pairing.dart';
import 'sync_service.dart';

/// Abgleich mit einem Gerät inkl. Nummernvergabe durch das Haupt-Handy:
/// vorläufige Nummern anderer Geräte (V-L0001 …) bekommen nach dem Holen
/// sofort endgültige Nummern, die gleich zurückgeschickt werden.
Future<SyncReport> runSync(PairedDevice device) async {
  final sync = services.sync;
  final report = await sync.syncWith(device);
  if (await SyncSettings.isMain() && !await SetupMode.isOn()) {
    final assigned = await services.repository.assignFinalNumbers();
    if (assigned.isNotEmpty) {
      for (final n in assigned) {
        for (final e in n.renames.entries) {
          final from = File(await ScanService.absolutePdfPath(e.key));
          if (await from.exists()) {
            await from.rename(await ScanService.absolutePdfPath(e.value));
          }
        }
        await services.notifications.syncDocument(n.doc.id);
      }
      final again = await sync.syncWith(
          (await SyncSettings.devices()).firstWhere((d) => d.id == device.id));
      report.sent += again.sent;
    }
  }
  return report;
}

/// Still mit allen gekoppelten Geräten abgleichen (z. B. beim Öffnen der
/// App). Fehler (Gerät nicht da) werden ignoriert.
Future<void> autoSync() async {
  for (final d in await SyncSettings.devices()) {
    try {
      await runSync(d);
    } catch (_) {}
  }
}
