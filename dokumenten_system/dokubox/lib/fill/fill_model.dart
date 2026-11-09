import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Was auf ein Formular gesetzt wird.
enum FillKind {
  /// Freier Text (auch Datum-Stempel).
  text,

  /// Haken ✓
  check,

  /// Kreuz ✗
  cross,

  /// Unterschrift/Vorlage (Bild).
  image,
}

/// Feste Farben zum schnellen Antippen.
const kFillColors = <int>[
  0xFF000000, // Schwarz
  0xFF0D47A1, // Blau (Kugelschreiber)
  0xFFC62828, // Rot
  0xFF2E7D32, // Grün
];

/// Standard- und Grenzwerte für [FillItem.size] je Art (Anteil der
/// Seitenbreite). Text: Schriftgröße; Haken/Kreuz: Kantenlänge; Bild: Breite.
const _defaultSize = {
  FillKind.text: 0.025,
  FillKind.check: 0.03,
  FillKind.cross: 0.03,
  FillKind.image: 0.3,
};
const _minSize = {
  FillKind.text: 0.008,
  FillKind.check: 0.01,
  FillKind.cross: 0.01,
  FillKind.image: 0.04,
};
const _maxSize = {
  FillKind.text: 0.15,
  FillKind.check: 0.2,
  FillKind.cross: 0.2,
  FillKind.image: 0.95,
};

double clampSize(FillKind kind, double size) =>
    size.clamp(_minSize[kind]!, _maxSize[kind]!).toDouble();

/// Ein Element auf einer Seite. Position und Größe sind relativ zur Seite
/// (0…1), damit sie auf jedem Bildschirm und im PDF gleich liegen.
class FillItem {
  final String id;
  final FillKind kind;

  /// Seite, 0-basiert.
  final int page;

  /// Linke obere Ecke, Anteil von Seitenbreite bzw. -höhe.
  double x;
  double y;

  /// Siehe [_defaultSize].
  double size;
  int color;
  String text;

  /// Bei [FillKind.image]: Vorlage und Seitenverhältnis (Höhe/Breite).
  String? templateId;
  double aspect;

  FillItem({
    String? id,
    required this.kind,
    required this.page,
    required this.x,
    required this.y,
    double? size,
    this.color = 0xFF000000,
    this.text = '',
    this.templateId,
    this.aspect = 0.35,
  })  : id = id ?? _uuid.v4(),
        size = clampSize(kind, size ?? _defaultSize[kind]!);

  /// Breite des Elements als Anteil der Seitenbreite (für Haken/Kreuz/Bild;
  /// Text hängt von der Schrift ab).
  double get boxWidth => size;

  /// Höhe als Anteil der Seitenbreite (nicht -höhe!).
  double get boxHeightOfWidth => switch (kind) {
        FillKind.image => size * aspect,
        FillKind.check || FillKind.cross => size,
        FillKind.text => size * 1.25 * (text.split('\n').length),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'page': page,
        'x': x,
        'y': y,
        'size': size,
        'color': color,
        if (text.isNotEmpty) 'text': text,
        if (templateId != null) 'templateId': templateId,
        if (kind == FillKind.image) 'aspect': aspect,
      };

  static FillItem? fromJson(Map<String, dynamic> json) {
    final kind = FillKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    if (kind == null) return null;
    double d(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    return FillItem(
      id: json['id'] as String?,
      kind: kind,
      page: (json['page'] as num?)?.toInt() ?? 0,
      x: d('x', 0).clamp(0, 1).toDouble(),
      y: d('y', 0).clamp(0, 1).toDouble(),
      size: d('size', _defaultSize[kind]!),
      color: (json['color'] as num?)?.toInt() ?? 0xFF000000,
      text: json['text'] as String? ?? '',
      templateId: json['templateId'] as String?,
      aspect: d('aspect', 0.35),
    );
  }

  FillItem copy() => FillItem.fromJson(toJson())!;
}

/// Alle Eintragungen eines Dokuments.
class FillDocument {
  final List<FillItem> items;
  FillDocument([List<FillItem>? items]) : items = items ?? [];

  String encode() => jsonEncode({
        'version': 1,
        'items': [for (final i in items) i.toJson()],
      });

  static FillDocument decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return FillDocument();
    try {
      final json = jsonDecode(raw);
      final list = json is Map ? json['items'] : null;
      if (list is! List) return FillDocument();
      return FillDocument([
        for (final e in list)
          if (e is Map<String, dynamic>) ?FillItem.fromJson(e),
      ]);
    } on FormatException {
      return FillDocument();
    }
  }

  List<FillItem> onPage(int page) =>
      [for (final i in items) if (i.page == page) i];

  FillDocument copy() => FillDocument([for (final i in items) i.copy()]);
}

/// Rückgängig machen: merkt sich Zustände vor jeder Änderung.
class FillHistory {
  static const maxSteps = 100;
  final _stack = <String>[];

  bool get canUndo => _stack.isNotEmpty;

  /// Vor einer Änderung aufrufen.
  void remember(FillDocument doc) {
    final state = doc.encode();
    if (_stack.isNotEmpty && _stack.last == state) return;
    _stack.add(state);
    if (_stack.length > maxSteps) _stack.removeAt(0);
  }

  FillDocument? undo() =>
      _stack.isEmpty ? null : FillDocument.decode(_stack.removeLast());
}

/// Breite/Höhe einer PNG aus dem Dateikopf (ohne Bild zu dekodieren).
({int width, int height})? pngSize(Uint8List bytes) {
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) return null;
  for (var i = 0; i < sig.length; i++) {
    if (bytes[i] != sig[i]) return null;
  }
  final data = ByteData.sublistView(bytes);
  final w = data.getUint32(16);
  final h = data.getUint32(20);
  if (w == 0 || h == 0) return null;
  return (width: w, height: h);
}

/// Linienzüge für Haken und Kreuz in einem Quadrat 0…1 (y nach unten).
const kCheckPath = [
  [0.12, 0.55],
  [0.40, 0.82],
  [0.90, 0.18],
];
const kCrossPaths = [
  [
    [0.15, 0.15],
    [0.85, 0.85],
  ],
  [
    [0.85, 0.15],
    [0.15, 0.85],
  ],
];

/// Strichstärke relativ zur Kantenlänge.
const kMarkStroke = 0.13;
