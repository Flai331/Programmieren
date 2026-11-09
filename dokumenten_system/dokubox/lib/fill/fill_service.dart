import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../data/database.dart';
import '../data/document_repository.dart';
import '../scan/scan_service.dart';
import 'fill_export.dart';
import 'fill_model.dart';
import 'page_encode.dart';
import 'template_service.dart';

/// Erzeugt und speichert die ausgefüllte Kopie eines Dokuments.
class FillService {
  /// Auflösung der Original-Seiten in der ausgefüllten PDF.
  static const dpi = 200.0;

  final DocumentRepository repository;
  final TemplateService templates;

  FillService(this.repository, this.templates);

  static String filledPathFor(Document doc) =>
      p.join(ScanService.pdfDirName, '${doc.docNumber}_ausgefuellt.pdf');

  /// Rendert alle Seiten des Originals als JPEG-Hintergrund.
  Future<List<PageBackground>> renderBackgrounds(String absolutePdf) async {
    final doc = await PdfDocument.openFile(absolutePdf);
    final pages = <PageBackground>[];
    try {
      for (final page in doc.pages) {
        final scale = dpi / 72;
        final image = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
          backgroundColor: 0xffffffff,
        );
        if (image == null) {
          throw StateError('Seite ${page.pageNumber} ließ sich nicht lesen.');
        }
        final w = image.width;
        final h = image.height;
        final pixels = Uint8List.fromList(image.pixels);
        image.dispose();
        final jpg = await Isolate.run(() => encodeBgraToJpg(w, h, pixels));
        pages.add(PageBackground(jpg, page.width, page.height));
      }
    } finally {
      await doc.dispose();
    }
    return pages;
  }

  /// Baut die ausgefüllte PDF, speichert sie neben dem Original und merkt
  /// sich die Eintragungen. Liefert den relativen Pfad.
  Future<String> save(Document doc, FillDocument fill) async {
    final original = await ScanService.absolutePdfPath(doc.pdfPath);
    final pages = await renderBackgrounds(original);
    final images = <String, Uint8List>{};
    for (final item in fill.items) {
      final id = item.templateId;
      if (item.kind != FillKind.image || id == null) continue;
      final bytes = await templates.bytes(id);
      if (bytes != null) images[id] = bytes;
    }
    final font = await rootBundle.load(kFillFontAsset);
    final pdf = await Isolate.run(() => buildFilledPdf(
          pages: pages,
          fill: fill,
          templateImages: images,
          font: font,
        ));
    final relative = filledPathFor(doc);
    await File(await ScanService.absolutePdfPath(relative))
        .writeAsBytes(pdf, flush: true);
    await repository.saveFill(doc.id,
        fillData: fill.encode(), filledPdfPath: relative);
    return relative;
  }

  /// Ausgefüllte Kopie verwerfen (Original bleibt).
  Future<void> discard(Document doc) async {
    final path = doc.filledPdfPath;
    if (path != null) {
      final file = File(await ScanService.absolutePdfPath(path));
      if (await file.exists()) await file.delete();
    }
    await repository.clearFill(doc.id);
  }
}
