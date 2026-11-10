import 'dart:io';
import 'dart:ui' as ui;

import 'package:dokubox/fill/fill_model.dart';
import 'package:dokubox/ui/fill_item_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gleicher Aufbau wie im Ausfüll-Bildschirm: InteractiveViewer → Seite →
/// Tipp-Fläche → Element.
class _Harness extends StatefulWidget {
  final FillItem item;
  final GlobalKey boundary;
  const _Harness(this.item, this.boundary);
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool selected = true;
  bool dragging = false;
  int pageTaps = 0;
  static const page = Size(360, 509);

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: widget.boundary,
            child: InteractiveViewer(
              maxScale: 6,
              panEnabled: !dragging,
              scaleEnabled: !dragging,
              child: SizedBox(
                width: page.width,
                height: page.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(child: ColoredBox(color: Colors.white)),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (_) => pageTaps++,
                      ),
                    ),
                    Positioned(
                      left: item.x * page.width,
                      top: item.y * page.height,
                      child: FillItemView(
                        item: item,
                        pageSize: page,
                        selected: selected,
                        onTap: () => setState(() => selected = true),
                        onDragStart: () => setState(() => dragging = true),
                        onDragEnd: () => setState(() => dragging = false),
                        onMove: (d) => setState(() {
                          item.x += d.dx / page.width;
                          item.y += d.dy / page.height;
                        }),
                        onResize: (v) => setState(() => item.size = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _snapshot(WidgetTester tester, GlobalKey key, String? path) async {
  if (path == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('auch ein kurzer Zug am Griff kommt sofort an', (tester) async {
    final item = FillItem(kind: FillKind.text, page: 0, x: 0.1, y: 0.2, text: 'Kurz');
    await tester.pumpWidget(_Harness(item, GlobalKey()));
    final before = item.size;
    final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('resize-handle'))));
    await g.moveBy(const Offset(12, 6));
    await tester.pump();
    await g.up();
    expect(item.size, greaterThan(before));
  });

  // Optional: Bilder für die Anleitung (SNAP_DIR=… flutter test …).
  final snapDir = Platform.environment['SNAP_DIR'];

  setUpAll(() async {
    final font = FontLoader('DejaVuSans')
      ..addFont(Future.value(ByteData.sublistView(
          File('assets/fonts/DejaVuSans.ttf').readAsBytesSync())));
    await font.load();
  });

  testWidgets('Ziehen am Griff macht den Text größer, nicht verschoben',
      (tester) async {
    final item = FillItem(
        kind: FillKind.text, page: 0, x: 0.1, y: 0.2, text: 'Max Müller',
        color: kFillColors[1]);
    final key = GlobalKey();
    await tester.pumpWidget(_Harness(item, key));
    await _snapshot(tester, key, snapDir == null ? null : '$snapDir/1_vorher.png');
    final before = item.size;
    final x = item.x, y = item.y;

    final handle = find.byKey(const ValueKey('resize-handle'));
    expect(handle, findsOneWidget);
    // Langsam wie ein Finger nach rechts unten ziehen.
    final gesture = await tester.startGesture(tester.getCenter(handle));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(8, 4));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await _snapshot(tester, key, snapDir == null ? null : '$snapDir/2_nachher.png');

    expect(item.size, greaterThan(before * 1.5),
        reason: 'Text muss deutlich größer werden');
    expect([item.x, item.y], [x, y], reason: 'Position bleibt');
  });

  testWidgets('nach links oben ziehen macht kleiner', (tester) async {
    final item = FillItem(
        kind: FillKind.text, page: 0, x: 0.1, y: 0.2, text: 'Text', size: 0.06);
    await tester.pumpWidget(_Harness(item, GlobalKey()));
    await tester.drag(
        find.byKey(const ValueKey('resize-handle')), const Offset(-60, -30));
    await tester.pump();
    expect(item.size, lessThan(0.06));
  });

  testWidgets('am Text selbst ziehen verschiebt nur', (tester) async {
    final item = FillItem(
        kind: FillKind.text, page: 0, x: 0.1, y: 0.2, text: 'Verschieb mich');
    await tester.pumpWidget(_Harness(item, GlobalKey()));
    final size = item.size;
    await tester.drag(find.text('Verschieb mich'), const Offset(50, 40));
    await tester.pump();
    expect(item.size, size);
    expect(item.x, greaterThan(0.1));
    expect(item.y, greaterThan(0.2));
  });

  testWidgets('Unterschrift über den Griff vergrößern', (tester) async {
    final item = FillItem(
        kind: FillKind.image, page: 0, x: 0.1, y: 0.5, templateId: 'x');
    await tester.pumpWidget(_Harness(item, GlobalKey()));
    final size = item.size;
    await tester.drag(
        find.byKey(const ValueKey('resize-handle')), const Offset(60, 20));
    await tester.pump();
    expect(item.size, greaterThan(size));
  });
}
