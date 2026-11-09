import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'fill_model.dart';

/// Schrift für Formulareinträge (App-Anzeige und PDF).
const kFillFontAsset = 'assets/fonts/DejaVuSans.ttf';
const kFillFontFamily = 'DejaVuSans';

/// Eine gerenderte Seite des Originals als Hintergrund.
class PageBackground {
  /// PNG oder JPEG der Seite.
  final Uint8List image;

  /// Seitengröße in PDF-Punkten (1/72 Zoll), wie im Original.
  final double widthPt;
  final double heightPt;

  const PageBackground(this.image, this.widthPt, this.heightPt);
}

/// Baut die ausgefüllte PDF: jede Seite des Originals als Bild, darauf Texte,
/// Haken/Kreuze (als Vektorlinien) und Unterschriften.
///
/// [templateImages]: PNG-Bytes je Vorlagen-ID. Fehlt eine Vorlage, wird das
/// Element ausgelassen.
///
/// [font]: TTF-Bytes der Schrift (DejaVu Sans, siehe `kFillFontAsset`) —
/// die eingebaute PDF-Schrift kennt weder „€“ noch viele Sonderzeichen.
Future<Uint8List> buildFilledPdf({
  required List<PageBackground> pages,
  required FillDocument fill,
  Map<String, Uint8List> templateImages = const {},
  ByteData? font,
}) async {
  final doc = pw.Document(
    title: 'Ausgefüllt',
    creator: 'DokuBox',
    theme: font == null ? null : pw.ThemeData.withFont(base: pw.Font.ttf(font)),
  );
  final images = {
    for (final e in templateImages.entries) e.key: pw.MemoryImage(e.value),
  };

  for (var index = 0; index < pages.length; index++) {
    final page = pages[index];
    final w = page.widthPt;
    final h = page.heightPt;
    final background = pw.MemoryImage(page.image);
    final items = fill.onPage(index);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(w, h, marginAll: 0),
        build: (_) => pw.Stack(
          children: [
            pw.Positioned.fill(child: pw.Image(background, fit: pw.BoxFit.fill)),
            for (final item in items) ?_positioned(item, w, h, images),
          ],
        ),
      ),
    );
  }
  return doc.save();
}

pw.Widget? _positioned(
    FillItem item, double w, double h, Map<String, pw.MemoryImage> images) {
  final left = item.x * w;
  final top = item.y * h;
  final color = PdfColor.fromInt(item.color);
  switch (item.kind) {
    case FillKind.text:
      if (item.text.trim().isEmpty) return null;
      return pw.Positioned(
        left: left,
        top: top,
        child: pw.Text(
          item.text,
          style: pw.TextStyle(
            fontSize: item.size * w,
            color: color,
            lineSpacing: item.size * w * 0.15,
          ),
        ),
      );
    case FillKind.check:
    case FillKind.cross:
      final side = item.size * w;
      final paths = item.kind == FillKind.check ? [kCheckPath] : kCrossPaths;
      return pw.Positioned(
        left: left,
        top: top,
        child: pw.SizedBox(
          width: side,
          height: side,
          child: pw.CustomPaint(
            size: PdfPoint(side, side),
            painter: (canvas, size) {
              canvas
                ..setStrokeColor(color)
                ..setLineWidth(side * kMarkStroke)
                ..setLineCap(PdfLineCap.round)
                ..setLineJoin(PdfLineJoin.round);
              for (final path in paths) {
                // PDF zählt y von unten → umrechnen.
                canvas.moveTo(path.first[0] * side, side - path.first[1] * side);
                for (final pt in path.skip(1)) {
                  canvas.lineTo(pt[0] * side, side - pt[1] * side);
                }
                canvas.strokePath();
              }
            },
          ),
        ),
      );
    case FillKind.image:
      final image = images[item.templateId];
      if (image == null) return null;
      final width = item.size * w;
      return pw.Positioned(
        left: left,
        top: top,
        child: pw.Image(
          image,
          width: width,
          height: width * item.aspect,
          fit: pw.BoxFit.fill,
        ),
      );
  }
}
