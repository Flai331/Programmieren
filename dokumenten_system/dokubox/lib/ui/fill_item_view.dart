import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../fill/fill_export.dart';
import '../fill/fill_model.dart';

/// Größe des runden Griffs zum Vergrößern/Verkleinern.
const kResizeHandleSize = 32.0;

/// Ein Element (Text, Haken, Kreuz, Unterschrift) auf der Seite.
///
/// Ausgewählt zeigt es einen Rahmen und unten rechts einen runden Griff:
/// am Element ziehen verschiebt, am Griff ziehen ändert die Größe.
///
/// Ziehen wird über rohe Zeiger-Ereignisse ([Listener]) ausgewertet, nicht
/// über Gesten-Erkenner: Sonst konkurriert der Zoom (InteractiveViewer) um
/// jede Bewegung und schluckt die ersten ~40 px – kurze Züge am Griff kämen
/// gar nicht an. [onDragStart]/[onDragEnd] sagen dem Bildschirm, dass er den
/// Zoom so lange pausieren soll.
class FillItemView extends StatefulWidget {
  final FillItem item;

  /// Angezeigte Seitengröße in Pixeln.
  final Size pageSize;
  final bool selected;
  final Uint8List? imageBytes;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final VoidCallback? onDragEnd;

  /// Verschieben um [delta] Pixel.
  final ValueChanged<Offset> onMove;

  /// Neue Größe (siehe [FillItem.size]).
  final ValueChanged<double> onResize;

  const FillItemView({
    super.key,
    required this.item,
    required this.pageSize,
    required this.selected,
    required this.onTap,
    required this.onDragStart,
    required this.onMove,
    required this.onResize,
    this.onDragEnd,
    this.imageBytes,
  });

  /// Neue Größe, wenn der Griff um [delta] Pixel gezogen wird: Das Element
  /// wird proportional so skaliert, dass seine rechte untere Ecke dem Finger
  /// folgt ([contentSize] = aktuelle Größe in Pixeln).
  static double resizedSize(FillItem item, Offset delta, Size contentSize) {
    final w = contentSize.width;
    final h = contentSize.height;
    final len2 = w * w + h * h;
    if (len2 <= 0) return item.size;
    // Bewegung auf die Diagonale projizieren.
    final factor = 1 + (delta.dx * w + delta.dy * h) / len2;
    return clampSize(item.kind, item.size * factor.clamp(0.5, 2.0));
  }

  @override
  State<FillItemView> createState() => _FillItemViewState();
}

enum _DragMode { none, move, resize }

class _FillItemViewState extends State<FillItemView> {
  _DragMode _mode = _DragMode.none;
  int? _pointer;
  final _contentKey = GlobalKey();

  void _down(PointerDownEvent e, _DragMode mode) {
    // Der Griff liegt im Element: er bekommt das Ereignis zuerst und gewinnt.
    if (_pointer != null) return;
    _pointer = e.pointer;
    _mode = mode;
    widget.onDragStart();
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    switch (_mode) {
      case _DragMode.move:
        widget.onMove(e.localDelta);
      case _DragMode.resize:
        final box =
            _contentKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        widget.onResize(
          FillItemView.resizedSize(widget.item, e.localDelta, box.size),
        );
      case _DragMode.none:
        break;
    }
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _mode = _DragMode.none;
    widget.onDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final selected = widget.selected;
    final imageBytes = widget.imageBytes;
    final w = widget.pageSize.width;

    Widget content;
    switch (item.kind) {
      case FillKind.text:
        content = Text(
          item.text,
          style: TextStyle(
            fontFamily: kFillFontFamily,
            fontSize: item.size * w,
            color: Color(item.color),
            height: 1.3,
          ),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
          ),
        );
      case FillKind.check:
      case FillKind.cross:
        final side = item.size * w;
        content = CustomPaint(
          size: Size.square(side),
          painter: FillMarkPainter(item.kind, Color(item.color)),
        );
      case FillKind.image:
        final width = item.size * w;
        content = SizedBox(
          width: width,
          height: width * item.aspect,
          child: imageBytes == null
              ? const Icon(Icons.broken_image)
              : Image.memory(
                  imageBytes,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
        );
    }

    const overhang = kResizeHandleSize * 0.6;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _down(e, _DragMode.move),
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // Der Griff muss INNERHALB der Stack-Fläche liegen – Flutter nimmt
        // Berührungen außerhalb der eigenen Größe nicht an. Deshalb Platz per
        // Padding schaffen und den Griff bündig unten rechts setzen.
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: selected ? overhang : 0,
                bottom: selected ? overhang : 0,
              ),
              child: Container(
                key: _contentKey,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                alignment: Alignment.topLeft,
                foregroundDecoration: selected
                    ? BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      )
                    : null,
                child: content,
              ),
            ),
            if (selected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Listener(
                  key: const ValueKey('resize-handle'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _down(e, _DragMode.resize),
                  child: Container(
                    width: kResizeHandleSize,
                    height: kResizeHandleSize,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(blurRadius: 3, color: Colors.black26),
                      ],
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Zeichnet Haken/Kreuz genauso wie in der PDF (fill_export.dart).
class FillMarkPainter extends CustomPainter {
  final FillKind kind;
  final Color color;
  FillMarkPainter(this.kind, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width;
    final paint = Paint()
      ..color = color
      ..strokeWidth = side * kMarkStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final paths = kind == FillKind.check ? [kCheckPath] : kCrossPaths;
    for (final pts in paths) {
      final path = Path()..moveTo(pts.first[0] * side, pts.first[1] * side);
      for (final pt in pts.skip(1)) {
        path.lineTo(pt[0] * side, pt[1] * side);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(FillMarkPainter old) =>
      old.kind != kind || old.color != color;
}
