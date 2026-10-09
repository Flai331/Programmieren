import 'dart:typed_data';

/// Stufen (Entscheidung im Kotlin-Teil, `Policy.kt`):
/// keep = nie anfassen, soft = nur aus dem Speicher werfen (Push-Nachrichten und
/// Kopfhörer-Play funktionieren weiter), full = „Beenden erzwingen“.
enum Level { keep, soft, full }

Level parseLevel(Object? s) => switch (s) {
      'soft' => Level.soft,
      'full' => Level.full,
      _ => Level.keep,
    };

String levelName(Level l) => switch (l) {
      Level.keep => 'Wichtig',
      Level.soft => 'Sanft',
      Level.full => 'Komplett',
    };

String levelHint(Level l) => switch (l) {
      Level.keep => 'Wird nie beendet.',
      Level.soft =>
        'Nur aus dem Speicher werfen. Nachrichten, Wecker und Play am Kopfhörer funktionieren weiter.',
      Level.full =>
        '„Beenden erzwingen“ – läuft gar nicht mehr, bis du die App selbst öffnest. Keine Benachrichtigungen.',
    };

class AppEntry {
  final String pkg;
  final String label;
  final bool system;
  final bool stopped;
  final bool protected;
  final bool audio;

  /// Tage mit Nutzung in den letzten 7 Tagen, null = unbekannt (kein Nutzungszugriff).
  final int? days7;
  final Level autoLevel;
  final Level level;
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
    this.audio = false,
    this.days7,
    this.autoLevel = Level.soft,
    Level? level,
    this.lastUsed,
    this.foreground = Duration.zero,
    this.fgService = Duration.zero,
    this.icon,
  }) : level = level ?? autoLevel;

  factory AppEntry.fromMap(Map<dynamic, dynamic> m) {
    final last = (m['lastUsed'] as num?)?.toInt() ?? 0;
    return AppEntry(
      pkg: m['pkg'] as String,
      label: (m['label'] as String?) ?? m['pkg'] as String,
      system: m['system'] == true,
      stopped: m['stopped'] == true,
      protected: m['protected'] == true,
      audio: m['audio'] == true,
      days7: (m['days7'] as num?)?.toInt(),
      autoLevel: parseLevel(m['autoLevel']),
      level: parseLevel(m['level']),
      lastUsed: last > 0 ? DateTime.fromMillisecondsSinceEpoch(last) : null,
      foreground: Duration(milliseconds: (m['foregroundMs'] as num?)?.toInt() ?? 0),
      fgService: Duration(milliseconds: (m['fgServiceMs'] as num?)?.toInt() ?? 0),
      icon: m['icon'] as Uint8List?,
    );
  }

  AppEntry copyWith({Level? level}) => AppEntry(
        pkg: pkg,
        label: label,
        system: system,
        stopped: stopped,
        protected: protected,
        audio: audio,
        days7: days7,
        autoLevel: autoLevel,
        level: level ?? this.level,
        lastUsed: lastUsed,
        foreground: foreground,
        fgService: fgService,
        icon: icon,
      );

  bool get manual => level != autoLevel;

  /// Läuft und darf angefasst werden.
  bool get running => !stopped && !protected;
}

/// Was „Aufräumen“ tut: sanft = Stufen soft + full, komplett = nur full.
class Cleanup {
  final List<AppEntry> soft;
  final List<AppEntry> full;
  const Cleanup(this.soft, this.full);
  bool get isEmpty => soft.isEmpty && full.isEmpty;
  int get count => soft.length + full.length;
}

Cleanup planCleanup(List<AppEntry> apps) => Cleanup(
      apps.where((a) => a.running && a.level == Level.soft).toList(),
      apps.where((a) => a.running && a.level == Level.full).toList(),
    );

/// Warum die Automatik diese Stufe gewählt hat (spiegelt `Policy.autoLevel` in Kotlin).
String autoReason(AppEntry a) {
  final d = a.days7;
  if (a.protected) return 'Startbildschirm/Tastatur';
  if (a.system) return 'vorinstalliert';
  if (d != null && d >= 4) return 'oft benutzt ($d von 7 Tagen)';
  if (a.audio) return 'Musik/Audio – Kopfhörer-Play soll gehen';
  if (a.autoLevel == Level.soft && d == 0) return 'Messenger/Wecker/Musik/Navigation';
  if (d == null) return 'ohne Nutzungszugriff vorsichtig';
  if (d >= 1) return 'ab und zu benutzt ($d von 7 Tagen)';
  return '7 Tage nicht benutzt';
}

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
