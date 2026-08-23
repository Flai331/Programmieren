import 'dart:convert';

/// Ein Fehlerbericht, wie er in der App entsteht.
///
/// Bewusst ohne Abhängigkeit zu einem Dienst: Der Bericht wird zuerst lokal
/// abgelegt und danach über das Teilen-Menü des Systems weitergegeben. So
/// braucht die App keinen Zugangsschlüssel für einen fremden Dienst.
class FeedbackReport {
  final String id;
  final DateTime createdAt;
  final String title;

  /// Beschreibung durch den Nutzer.
  final String? note;

  /// Protokoll der letzten Aktionen.
  final String log;

  final String appVersion;
  final String os;
  final String screen;

  /// Dateinamen der angehängten Bilder in der Berichts-Ablage.
  final List<String> photoNames;

  /// Automatisch erkannter Fehler statt manueller Meldung.
  final bool isAutoError;

  /// Wurde der Bericht schon geteilt oder kopiert?
  final bool exported;

  const FeedbackReport({
    required this.id,
    required this.createdAt,
    required this.title,
    this.note,
    required this.log,
    required this.appVersion,
    required this.os,
    this.screen = '',
    this.photoNames = const [],
    this.isAutoError = false,
    this.exported = false,
  });

  bool get hasPhotos => photoNames.isNotEmpty;

  /// Der Bericht als Text – dieselbe Form, die auch geteilt und kopiert wird.
  String asPlainText() {
    final b = StringBuffer();
    if ((note ?? '').isNotEmpty) {
      b.writeln('🐛 FEHLERBESCHREIBUNG');
      b.writeln(note);
      b.writeln();
    }
    if (screen.isNotEmpty) {
      b.writeln('📱 AKTUELLE SEITE');
      b.writeln('Seite: $screen');
      b.writeln();
    }
    b.writeln('📋 PROTOKOLL');
    b.writeln(log.isEmpty ? '(keine Einträge)' : log);
    b.writeln();
    b.writeln('📱 SYSTEM');
    b.writeln('App: BeeBrain');
    b.writeln('Build: #$appVersion');
    b.writeln('Zeit: $createdAt');
    if (os.isNotEmpty) b.writeln('OS: $os');
    return b.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'title': title,
        'note': note,
        'log': log,
        'app_version': appVersion,
        'os': os,
        'screen': screen,
        'photo_names': photoNames,
        'is_auto_error': isAutoError,
        'exported': exported,
      };

  factory FeedbackReport.fromJson(Map<String, dynamic> m) => FeedbackReport(
        id: m['id'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        title: (m['title'] as String?) ?? 'Fehlerbericht',
        note: m['note'] as String?,
        log: (m['log'] as String?) ?? '',
        appVersion: (m['app_version'] as String?) ?? '?',
        os: (m['os'] as String?) ?? '',
        screen: (m['screen'] as String?) ?? '',
        photoNames: (m['photo_names'] as List?)?.whereType<String>().toList() ??
            const [],
        isAutoError: (m['is_auto_error'] as bool?) ?? false,
        exported: (m['exported'] as bool?) ?? false,
      );

  static FeedbackReport fromJsonString(String raw) =>
      FeedbackReport.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  FeedbackReport copyWith({
    String? id,
    DateTime? createdAt,
    String? title,
    String? note,
    String? log,
    String? appVersion,
    String? os,
    String? screen,
    List<String>? photoNames,
    bool? isAutoError,
    bool? exported,
  }) =>
      FeedbackReport(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        title: title ?? this.title,
        note: note ?? this.note,
        log: log ?? this.log,
        appVersion: appVersion ?? this.appVersion,
        os: os ?? this.os,
        screen: screen ?? this.screen,
        photoNames: photoNames ?? this.photoNames,
        isAutoError: isAutoError ?? this.isAutoError,
        exported: exported ?? this.exported,
      );
}
