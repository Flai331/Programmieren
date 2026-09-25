import 'models.dart';
import 'detection.dart';
import 'format.dart';

/// Dünnt periodische Standorte aus und gibt nur die letzten `limit` Ereignisse.
List<RawEvent> diagnosticEvents(List<RawEvent> all, {int limit = 100}) {
  // Nach Zeit sortieren
  final sorted = List<RawEvent>.from(all)..sort((a, b) => a.t.compareTo(b.t));

  // Ausdünnen: höchstens eins pro 5 Minuten für loc mit reason=periodic
  int lastPeriodicLocTime = 0;
  final filtered = <RawEvent>[];

  for (final event in sorted) {
    if (event.type == 'loc' && event.str('reason') == 'periodic') {
      if (event.t - lastPeriodicLocTime >= 5 * 60 * 1000) {
        filtered.add(event);
        lastPeriodicLocTime = event.t;
      }
    } else {
      filtered.add(event);
    }
  }

  // Letzte `limit` Ereignisse
  if (filtered.length > limit) {
    return filtered.sublist(filtered.length - limit);
  }

  return filtered;
}

/// Beschreibt ein einzelnes Ereignis als Text.
String describeEvent(RawEvent e) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(e.t);
  // „25.09. 17:42:08“ – mit Sekunden, damit die Reihenfolge nachvollziehbar ist.
  final dateStr =
      '${formatDateTime(dateTime)}:${dateTime.second.toString().padLeft(2, '0')}';
  final timeStr = dateStr;
  String coord(double? v) => v == null ? '?' : v.toStringAsFixed(5);
  String meters(double? v) => v == null ? '?' : v.round().toString();

  return switch (e.type) {
    'activity' =>
      '$dateStr Aktivität ${e.str('activity')} ${e.str('transition')}',
    'loc' =>
      '$dateStr Standort ${coord(e.dbl('lat'))}, ${coord(e.dbl('lng'))} ± ${meters(e.dbl('acc'))} m (${e.str('reason')})',
    'service' =>
      '$dateStr Service ${e.str('state')} (${e.str('mode')} ${e.str('target') ?? 'keins'})',
    'scan' => _describeScan(dateStr, timeStr, e),
    'beacon_bg' =>
      '$dateStr Beacon-Hintergrund ${e.str('target')} (RSSI ${e.integer('rssi')})',
    'power' =>
      '$dateStr Laden: ${e.boolean('plugged') == true ? 'eingesteckt' : 'abgesteckt'} (${e.str('reason')})',
    'manual' => '$dateStr Manuell (${e.str('source')})',
    'info' => '$dateStr Info: ${e.str('msg')}',
    _ => '$dateStr ${e.toJson()}',
  };
}

String _describeScan(String dateStr, String timeStr, RawEvent e) {
  final mode = e.str('mode') ?? 'unknown';
  final target = e.str('target') ?? 'unknown';
  final ok = e.boolean('ok');
  final found = e.boolean('found');
  final rssi = e.integer('rssi');
  final error = e.str('error');

  if (ok == false) {
    return '$dateStr Suche $mode: Fehler: $error';
  }

  if (found == true) {
    return '$dateStr Suche $mode $target: gefunden (RSSI $rssi)';
  } else {
    return '$dateStr Suche $mode $target: nicht gefunden';
  }
}

class DeviceStats {
  final int scans;
  final int hits;
  final int? lastSeen;
  final int? lastRssi;

  DeviceStats({
    required this.scans,
    required this.hits,
    required this.lastSeen,
    required this.lastRssi,
  });
}

/// Sammelt Geräteverwendungsstatistiken.
DeviceStats deviceStats(List<RawEvent> all, String? address) {
  int scans = 0;
  int hits = 0;
  int? lastSeenTime;
  int? lastRssiValue;

  for (final event in all) {
    if (event.type == 'scan') {
      if (event.boolean('ok') == true) {
        scans++;
      }
      if (event.boolean('found') == true) {
        hits++;
        lastSeenTime = event.t;
        lastRssiValue = event.integer('rssi');
      }
    }
  }

  return DeviceStats(
    scans: scans,
    hits: hits,
    lastSeen: lastSeenTime,
    lastRssi: lastRssiValue,
  );
}

/// Erstellt einen kompletten Diagnose-Text.
String buildDiagnosticText({
  required List<RawEvent> events,
  required Map<String, String> permissions,
  required Map<String, dynamic> nativeStatus,
  required Map<String, dynamic> config,
  required List<TripResult> tripResults,
}) {
  final buffer = StringBuffer();

  // Kopf
  buffer.writeln('Parkplatz-Merker Diagnose');
  buffer.writeln(formatDateTime(DateTime.now()));
  final version = nativeStatus['appVersion'];
  if (version != null) buffer.writeln('Version: $version');
  buffer.writeln();

  // Berechtigungen
  buffer.writeln('--- Berechtigungen ---');
  for (final entry in permissions.entries) {
    buffer.writeln('${entry.key}: ${entry.value}');
  }
  buffer.writeln();

  // Native Status
  buffer.writeln('--- Native Status ---');
  for (final entry in nativeStatus.entries) {
    buffer.writeln('${entry.key}: ${entry.value}');
  }
  buffer.writeln();

  // Einstellungen
  buffer.writeln('--- Einstellungen ---');
  for (final entry in config.entries) {
    buffer.writeln('${entry.key}: ${entry.value}');
  }
  buffer.writeln();

  // Gerät-Statistik
  final deviceAddress = config['deviceAddress'] as String?;
  final stats = deviceStats(events, deviceAddress);
  buffer.writeln('--- Gerät ---');
  buffer.writeln('Adresse: $deviceAddress');
  buffer.writeln('Scans (ok): ${stats.scans}');
  buffer.writeln('Treffer: ${stats.hits}');
  if (stats.lastSeen != null) {
    final lastSeenDt = DateTime.fromMillisecondsSinceEpoch(stats.lastSeen!);
    buffer.writeln(
      'Zuletzt gesehen: ${formatDateTime(lastSeenDt)} (RSSI ${stats.lastRssi})',
    );
  } else {
    buffer.writeln('Zuletzt gesehen: noch nie');
  }
  buffer.writeln();

  // Letzte 10 Fahrten
  buffer.writeln('--- Fahrten (letzte 10) ---');
  final recentTrips = tripResults.length > 10
      ? tripResults.sublist(tripResults.length - 10)
      : tripResults;
  for (final result in recentTrips.reversed) {
    buffer.writeln(
      'Start: ${formatDateTime(DateTime.fromMillisecondsSinceEpoch(result.trip.start))}',
    );
    if (result.trip.exit != null) {
      buffer.writeln(
        '  Exit: ${formatDateTime(DateTime.fromMillisecondsSinceEpoch(result.trip.exit!))}',
      );
    }
    buffer.writeln('  Status: ${result.status}');
  }
  buffer.writeln();

  // Ereignisse
  buffer.writeln('--- Ereignisse ---');
  final diag = diagnosticEvents(events);
  for (final event in diag) {
    buffer.writeln(describeEvent(event));
  }

  return buffer.toString();
}
