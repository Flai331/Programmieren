import 'dart:convert';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
//  INVOICE LAYOUT CANVAS
//  A4-Vorschau mit verschiebbaren / skalierbaren / spiegelbaren
//  Bausteinen (Logo, Header, Texte, Tabelle, etc.)
// ═══════════════════════════════════════════════════════════════

class ElementPos {
  final double x;
  final double y;
  final double w;
  final double h;
  final bool flipH;
  final bool flipV;

  const ElementPos({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.flipH = false,
    this.flipV = false,
  });

  Map<String, dynamic> toJson() =>
      {'x': x, 'y': y, 'w': w, 'h': h, 'fh': flipH, 'fv': flipV};

  factory ElementPos.fromJson(Map<String, dynamic> j) => ElementPos(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        flipH: j['fh'] as bool? ?? false,
        flipV: j['fv'] as bool? ?? false,
      );

  ElementPos copyWith({
    double? x,
    double? y,
    double? w,
    double? h,
    bool? flipH,
    bool? flipV,
  }) =>
      ElementPos(
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
        flipH: flipH ?? this.flipH,
        flipV: flipV ?? this.flipV,
      );
}

/// Definition eines Layout-Elements
class LayoutElement {
  final String id;
  final String label;
  final Widget Function(BuildContext) builder;
  final bool isImage;
  final VoidCallback? onDoubleTap;

  const LayoutElement({
    required this.id,
    required this.label,
    required this.builder,
    this.isImage = false,
    this.onDoubleTap,
  });
}

class InvoiceLayoutCanvas extends StatefulWidget {
  final List<LayoutElement> elements;
  final Map<String, ElementPos> initialLayout;
  final void Function(Map<String, ElementPos>) onLayoutChanged;

  const InvoiceLayoutCanvas({
    Key? key,
    required this.elements,
    required this.initialLayout,
    required this.onLayoutChanged,
  }) : super(key: key);

  /// Default-Layout für alle Elemente (Standard-Rechnung)
  /// Koordinaten in PIXEL bezogen auf A4-Canvas-Breite (wird relativ skaliert).
  /// Canvas-Breite Referenz = 595 (A4 in Punkten bei 72 DPI).
  static Map<String, ElementPos> defaultLayout() {
    return {
      'header_image': const ElementPos(x: 20, y: 20, w: 555, h: 60),
      'logo': const ElementPos(x: 470, y: 90, w: 90, h: 90),
      // Firmenname-Überschrift links oben (unter Header-Bild)
      'company_header':
          const ElementPos(x: 57, y: 100, w: 450, h: 35),
      // DIN 5008 Form B — Anschriftenfeld: x=20mm, y=45mm, w=85mm, h=45mm
      // Rücksendezone (oben 17.7mm = 50pt): Mini-Absender
      'company_address':
          const ElementPos(x: 57, y: 142, w: 241, h: 50),
      // Anschriftzone (unten 27.3mm = 78pt): Empfänger
      'customer_address':
          const ElementPos(x: 57, y: 178, w: 241, h: 110),
      'invoice_meta':
          const ElementPos(x: 320, y: 178, w: 250, h: 110),
      'items_table':
          const ElementPos(x: 55, y: 340, w: 520, h: 200),
      'additional_info': const ElementPos(x: 55, y: 292, w: 520, h: 44),
      'summary': const ElementPos(x: 320, y: 560, w: 255, h: 100),
      'bank_info': const ElementPos(x: 55, y: 700, w: 520, h: 80),
      'footer': const ElementPos(x: 55, y: 800, w: 520, h: 30),
    };
  }

  static String encodeLayout(Map<String, ElementPos> layout) {
    return jsonEncode(
        layout.map((k, v) => MapEntry(k, v.toJson())));
  }

  /// Encode layout + optional text overrides into one JSON string.
  static String encodeLayoutWithTexts(
    Map<String, ElementPos> layout,
    Map<String, String> texts,
  ) {
    final map = <String, dynamic>{};
    for (final e in layout.entries) {
      map[e.key] = e.value.toJson();
    }
    if (texts.isNotEmpty) map['_texts'] = texts;
    return jsonEncode(map);
  }

  /// Extract custom text overrides from layoutJson.
  static Map<String, String> decodeTexts(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final raw = jsonDecode(json) as Map<String, dynamic>;
      final texts = raw['_texts'];
      if (texts is Map) return texts.cast<String, String>();
    } catch (_) {}
    return {};
  }

  static Map<String, ElementPos> decodeLayout(String? json) {
    final defaults = defaultLayout();
    if (json == null || json.isEmpty) return defaults;
    try {
      final raw = jsonDecode(json) as Map<String, dynamic>;
      // Skip internal meta-keys (e.g. _texts)
      final posEntries = raw.entries.where((e) => !e.key.startsWith('_'));
      final saved = Map.fromEntries(posEntries).map((k, v) =>
          MapEntry(k, ElementPos.fromJson(v as Map<String, dynamic>)));

      // Migration: alte Layouts ohne company_header-Key wurden vor DIN-5008-
      // Refactor gespeichert und haben Absender/Empfänger an Kollisionsposition.
      // Adressblöcke auf neue DIN-Defaults zwingen, Header-Bild/Logo behalten.
      if (!raw.containsKey('company_header')) {
        const addressKeys = [
          'company_header',
          'company_address',
          'customer_address',
          'invoice_meta',
        ];
        for (final k in addressKeys) {
          saved[k] = defaults[k]!;
        }
      }

      // Migration: additional_info war früher bei y=542, jetzt y=292.
      // Alte gespeicherte Position zurücksetzen.
      if (saved['additional_info']?.y == 542) {
        saved['additional_info'] = defaults['additional_info']!;
      }

      // Defaults für Keys, die im gespeicherten Layout fehlen.
      final merged = <String, ElementPos>{...defaults, ...saved};
      return merged;
    } catch (_) {
      return defaults;
    }
  }

  @override
  State<InvoiceLayoutCanvas> createState() => _InvoiceLayoutCanvasState();
}

class _InvoiceLayoutCanvasState extends State<InvoiceLayoutCanvas> {
  late Map<String, ElementPos> _layout;
  String? _selectedId;

  // Referenz-Breite für Layout-Koordinaten (= A4 595pt bei 72 DPI)
  static const double refWidth = 595;
  static const double refHeight = 842;

  @override
  void initState() {
    super.initState();
    _layout = Map<String, ElementPos>.from(widget.initialLayout);
    // Defaults für fehlende Elemente
    final defaults = InvoiceLayoutCanvas.defaultLayout();
    for (final e in widget.elements) {
      _layout[e.id] ??= defaults[e.id] ??
          const ElementPos(x: 50, y: 50, w: 200, h: 50);
    }
  }

  void _commit() => widget.onLayoutChanged(_layout);

  @override
  void didUpdateWidget(InvoiceLayoutCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final defaults = InvoiceLayoutCanvas.defaultLayout();
    for (final e in widget.elements) {
      _layout[e.id] ??= defaults[e.id] ??
          const ElementPos(x: 50, y: 50, w: 200, h: 50);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasW = constraints.maxWidth;
        final scale = canvasW / refWidth;
        final canvasH = refHeight * scale;

        return GestureDetector(
          onTap: () => setState(() => _selectedId = null),
          child: Container(
            width: canvasW,
            height: canvasH,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (final el in widget.elements)
                  _buildElement(el, scale, canvasW, canvasH),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildElement(
    LayoutElement el,
    double scale,
    double canvasW,
    double canvasH,
  ) {
    final pos = _layout[el.id] ??
        InvoiceLayoutCanvas.defaultLayout()[el.id] ??
        const ElementPos(x: 50, y: 50, w: 200, h: 50);
    final isSelected = _selectedId == el.id;

    return Positioned(
      left: pos.x * scale,
      top: pos.y * scale,
      width: pos.w * scale,
      height: pos.h * scale,
      child: GestureDetector(
        onTap: () => setState(() => _selectedId = el.id),
        onDoubleTap: el.onDoubleTap,
        onPanUpdate: (d) {
          setState(() {
            final newX = (pos.x + d.delta.dx / scale)
                .clamp(0.0, refWidth - pos.w);
            final newY = (pos.y + d.delta.dy / scale)
                .clamp(0.0, refHeight - pos.h);
            _layout[el.id] = pos.copyWith(x: newX, y: newY);
          });
        },
        onPanEnd: (_) => _commit(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Inhalt mit Flip
            Positioned.fill(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(
                    pos.flipH ? -1.0 : 1.0,
                    pos.flipV ? -1.0 : 1.0, 1.0),
                child: Container(
                  decoration: isSelected
                      ? null
                      : BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 0.5,
                          ),
                        ),
                  child: el.builder(context),
                ),
              ),
            ),
            if (isSelected)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFfda085), width: 2),
                    ),
                  ),
                ),
              ),
            // Label oben links
            if (isSelected)
              Positioned(
                top: -18,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  color: const Color(0xFFfda085),
                  child: Text(
                    el.label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            // Flip-Buttons (nur bei Bildern + selected)
            if (isSelected && el.isImage)
              Positioned(
                top: 2,
                left: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniBtn(
                      icon: Icons.swap_horiz,
                      active: pos.flipH,
                      onTap: () {
                        setState(() {
                          _layout[el.id] =
                              pos.copyWith(flipH: !pos.flipH);
                        });
                        _commit();
                      },
                    ),
                    const SizedBox(width: 4),
                    _MiniBtn(
                      icon: Icons.swap_vert,
                      active: pos.flipV,
                      onTap: () {
                        setState(() {
                          _layout[el.id] =
                              pos.copyWith(flipV: !pos.flipV);
                        });
                        _commit();
                      },
                    ),
                  ],
                ),
              ),
            // Edge resize handles (top, bottom, left, right)
            if (isSelected) ...[
              // Top edge
              Positioned(
                top: -4,
                left: 16,
                right: 16,
                height: 8,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeRow,
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        final cur = _layout[el.id]!;
                        final dy = d.delta.dy / scale;
                        final newY = (cur.y + dy).clamp(0.0, cur.y + cur.h - 20);
                        final newH = cur.h - (newY - cur.y);
                        _layout[el.id] = cur.copyWith(y: newY, h: newH);
                      });
                    },
                    onPanEnd: (_) => _commit(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              // Bottom edge
              Positioned(
                bottom: -4,
                left: 16,
                right: 16,
                height: 8,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeRow,
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        final cur = _layout[el.id]!;
                        final dy = d.delta.dy / scale;
                        final newH = (cur.h + dy).clamp(20.0, refHeight - cur.y);
                        _layout[el.id] = cur.copyWith(h: newH);
                      });
                    },
                    onPanEnd: (_) => _commit(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              // Left edge
              Positioned(
                left: -4,
                top: 16,
                bottom: 16,
                width: 8,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        final cur = _layout[el.id]!;
                        final dx = d.delta.dx / scale;
                        final newX = (cur.x + dx).clamp(0.0, cur.x + cur.w - 20);
                        final newW = cur.w - (newX - cur.x);
                        _layout[el.id] = cur.copyWith(x: newX, w: newW);
                      });
                    },
                    onPanEnd: (_) => _commit(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              // Right edge
              Positioned(
                right: -4,
                top: 16,
                bottom: 16,
                width: 8,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        final cur = _layout[el.id]!;
                        final dx = d.delta.dx / scale;
                        final newW = (cur.w + dx).clamp(20.0, refWidth - cur.x);
                        _layout[el.id] = cur.copyWith(w: newW);
                      });
                    },
                    onPanEnd: (_) => _commit(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ],
            // Corner resize handle (bottom-right)
            if (isSelected)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    setState(() {
                      final cur = _layout[el.id]!;
                      final dx = d.delta.dx / scale;
                      final dy = d.delta.dy / scale;
                      final newW = (cur.w + dx)
                          .clamp(20.0, refWidth - cur.x);
                      final newH = (cur.h + dy)
                          .clamp(20.0, refHeight - cur.y);
                      _layout[el.id] =
                          cur.copyWith(w: newW, h: newH);
                    });
                  },
                  onPanEnd: (_) => _commit(),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFfda085),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Icon(Icons.open_in_full,
                        color: Colors.white, size: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _MiniBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFfda085)
              : Colors.black54,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Icon(icon, color: Colors.white, size: 12),
      ),
    );
  }
}
