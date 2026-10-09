import 'dart:typed_data';

/// Apps, die standardmäßig als „wichtig“ gelten (werden nie automatisch beendet),
/// solange du selbst noch nichts markiert hast. Wer hier beendet wird,
/// bekommt keine Nachrichten/Wecker mehr, bis er wieder geöffnet wird.
const defaultImportant = <String>{
  'com.whatsapp',
  'com.whatsapp.w4b',
  'org.thoughtcrime.securesms', // Signal
  'org.telegram.messenger',
  'ch.threema.app',
  'com.google.android.deskclock',
  'com.sec.android.app.clockpackage',
  'com.android.deskclock',
  'com.google.android.dialer',
  'com.samsung.android.dialer',
  'com.google.android.apps.messaging',
  'com.samsung.android.messaging',
  'com.google.android.gm', // Gmail
  'com.google.android.calendar',
  'com.spotify.music',
};

class AppEntry {
  final String pkg;
  final String label;
  final bool system;
  final bool stopped;
  final bool protected;
  final DateTime? lastUsed;
  final Duration foreground;
  final Duration fgService;
  final Uint8List? icon;

  const AppEntry({
    required this.pkg,
    required this.label,
    this.system = false,
    this.stopped = false,
    this.protected = false,
    this.lastUsed,
    this.foreground = Duration.zero,
    this.fgService = Duration.zero,
    this.icon,
  });

  factory AppEntry.fromMap(Map<dynamic, dynamic> m) {
    final last = (m['lastUsed'] as num?)?.toInt() ?? 0;
    return AppEntry(
      pkg: m['pkg'] as String,
      label: (m['label'] as String?) ?? m['pkg'] as String,
      system: m['system'] == true,
      stopped: m['stopped'] == true,
      protected: m['protected'] == true,
      lastUsed: last > 0 ? DateTime.fromMillisecondsSinceEpoch(last) : null,
      foreground: Duration(milliseconds: (m['foregroundMs'] as num?)?.toInt() ?? 0),
      fgService: Duration(milliseconds: (m['fgServiceMs'] as num?)?.toInt() ?? 0),
      icon: m['icon'] as Uint8List?,
    );
  }

  AppEntry copyWith({bool? stopped}) => AppEntry(
        pkg: pkg,
        label: label,
        system: system,
        stopped: stopped ?? this.stopped,
        protected: protected,
        lastUsed: lastUsed,
        foreground: foreground,
        fgService: fgService,
        icon: icon,
      );

  /// Darf überhaupt beendet werden (Startbildschirm, Tastatur nie).
  bool get stoppable => !protected && !stopped;
}

/// Apps, die „Unwichtige beenden“ erfasst: laufend, keine System-App,
/// nicht geschützt und nicht als wichtig markiert.
List<AppEntry> stopCandidates(List<AppEntry> apps, Set<String> important) => apps
    .where((a) => a.stoppable && !a.system && !important.contains(a.pkg))
    .toList();

/// Sortierung: laufende zuerst, dann wer am meisten im Hintergrund lief,
/// dann zuletzt benutzt, dann Name.
List<AppEntry> sortApps(List<AppEntry> apps) {
  final list = [...apps];
  list.sort((a, b) {
    if (a.stopped != b.stopped) return a.stopped ? 1 : -1;
    final bg = b.fgService.compareTo(a.fgService);
    if (bg != 0) return bg;
    final la = a.lastUsed?.millisecondsSinceEpoch ?? 0;
    final lb = b.lastUsed?.millisecondsSinceEpoch ?? 0;
    if (la != lb) return lb.compareTo(la);
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return list;
}

String formatDuration(Duration d) {
  if (d.inMinutes < 1) return '< 1 min';
  if (d.inHours < 1) return '${d.inMinutes} min';
  final m = d.inMinutes % 60;
  return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
}

String formatAgo(DateTime? t, DateTime now) {
  if (t == null) return 'nicht in den letzten 24 h';
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'gerade eben';
  if (d.inMinutes < 60) return 'vor ${d.inMinutes} min';
  if (d.inHours < 24) return 'vor ${d.inHours} h';
  return 'vor ${d.inDays} Tagen';
}

class BatteryState {
  final int level;
  final bool charging;
  final String plug;
  final double temp;
  final int voltageMv;
  final String health;
  final String technology;
  final int? currentMa;
  final int? cycles;
  final bool powerSave;

  const BatteryState({
    required this.level,
    this.charging = false,
    this.plug = '',
    this.temp = 0,
    this.voltageMv = 0,
    this.health = 'unknown',
    this.technology = '',
    this.currentMa,
    this.cycles,
    this.powerSave = false,
  });

  factory BatteryState.fromMap(Map<dynamic, dynamic> m) => BatteryState(
        level: (m['level'] as num?)?.toInt() ?? -1,
        charging: m['charging'] == true,
        plug: (m['plug'] as String?) ?? '',
        temp: (m['temp'] as num?)?.toDouble() ?? 0,
        voltageMv: (m['voltage'] as num?)?.toInt() ?? 0,
        health: (m['health'] as String?) ?? 'unknown',
        technology: (m['technology'] as String?) ?? '',
        currentMa: currentToMa((m['currentNow'] as num?)?.toInt()),
        cycles: (m['cycles'] as num?)?.toInt(),
        powerSave: m['powerSave'] == true,
      );
}

/// Android liefert Mikroampere, manche Hersteller aber Milliampere.
/// Werte über 20 000 sind sicher µA (kein Handy zieht 20 A).
int? currentToMa(int? raw) {
  if (raw == null || raw == 0) return null;
  return raw.abs() > 20000 ? raw ~/ 1000 : raw;
}

String healthText(String h) => switch (h) {
      'good' => 'Gut',
      'overheat' => 'Überhitzt',
      'dead' => 'Defekt',
      'overvoltage' => 'Überspannung',
      'failure' => 'Fehler',
      'cold' => 'Zu kalt',
      _ => 'Unbekannt',
    };

enum Severity { info, warn, danger }

class Advice {
  final Severity severity;
  final String text;
  const Advice(this.severity, this.text);
}

/// Hinweise passend zum aktuellen Akku-Zustand.
List<Advice> batteryAdvice(BatteryState b, {int upper = 80, int lower = 20, int maxTemp = 40}) {
  final out = <Advice>[];
  if (b.health != 'good' && b.health != 'unknown') {
    out.add(Advice(Severity.danger,
        'Android meldet den Akku als „${healthText(b.health)}“. Bläht er sich auf oder wird das Handy sehr heiß: nicht mehr laden, Akku tauschen lassen.'));
  }
  if (b.temp >= maxTemp) {
    out.add(Advice(Severity.danger,
        'Akku ist ${b.temp.toStringAsFixed(1)} °C warm. ${b.charging ? 'Laden unterbrechen, ' : ''}Hülle ab, aus der Sonne, Spiele/Kamera/Navigation beenden.'));
  } else if (b.temp >= maxTemp - 4) {
    out.add(Advice(Severity.warn,
        'Akku wird warm (${b.temp.toStringAsFixed(1)} °C). Wärme altert einen Akku am schnellsten.'));
  }
  if (b.charging && b.level >= upper) {
    out.add(Advice(Severity.warn, 'Über $upper % – jetzt abstecken schont den Akku.'));
  }
  if (!b.charging && b.level >= 0 && b.level <= lower) {
    out.add(Advice(Severity.warn, 'Nur noch ${b.level} % – bald laden, tiefe Entladung schadet.'));
  }
  if (!b.charging && !b.powerSave && b.level >= 0 && b.level <= 50) {
    out.add(const Advice(Severity.info, 'Tipp: Energiesparmodus einschalten (Reiter „Sparen“).'));
  }
  if (out.isEmpty) {
    out.add(const Advice(Severity.info, 'Alles im grünen Bereich.'));
  }
  return out;
}
