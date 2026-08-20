/// Tagesnutzung einer App, wie sie die native Seite liefert.
class AppUsage {
  const AppUsage({
    required this.name,
    required this.packageName,
    required this.duration,
  });

  final String name;
  final String packageName;
  final Duration duration;

  factory AppUsage.fromMap(Map<dynamic, dynamic> map) => AppUsage(
    name: map['name'] as String? ?? '',
    packageName: map['packageName'] as String? ?? '',
    duration: Duration(milliseconds: (map['millis'] as num?)?.toInt() ?? 0),
  );
}

/// Ab einer Stunde mit Stundenfeld. Sekunden nirgends — sie ändern sich beim
/// Hinsehen und tragen nichts zur Aussage bei.
String formatUsage(Duration d) {
  final minuten = d.inMinutes;
  if (minuten < 60) return '$minuten min';
  return '${minuten ~/ 60} h ${minuten % 60} min';
}

/// Apps darunter fallen aus der Liste — sonst besteht sie aus
/// Zufallsberührungen. In die Tagessumme zählen sie trotzdem hinein.
const kUsageThreshold = Duration(minutes: 1);
