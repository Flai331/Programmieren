/// Vorlage für `secrets.dart`. Diese Datei liegt im Repo, `secrets.dart` nicht.
///
/// Einrichten:
///   1. Datei neben dieser als `secrets.dart` kopieren
///   2. Token eintragen
///
/// Der Token gehört zur internen Notion-Integration „Riegel Fehlerberichte".
/// Die Datenbank muss für diese Integration freigegeben sein:
/// Datenbank öffnen → ••• → Verbindungen → Integration hinzufügen.
///
/// Ohne gültigen Token fällt die Fehlermeldung automatisch auf E-Mail zurück.
class Secrets {
  const Secrets._();

  /// Internal Integration Secret, beginnt mit `ntn_`.
  static const String notionToken = '';

  /// Datenbank „🐛 Fehlerberichte Riegel".
  static const String notionDatabaseId = 'd1dc9af960734132b96d3a08c3d3ce9b';

  /// Fallback, wenn Notion nicht erreichbar ist.
  static const String supportEmail = 'error.404.found@outlook.de';
}
