import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'scan_service.dart';

/// Mindestens so viele Buchstaben/Ziffern muss die Textebene einer Seite
/// haben, damit sie ohne OCR übernommen wird. Darunter ist es meist nur ein
/// Scanner-Stempel, eine Seitenzahl oder gar nichts (reiner Bild-Scan).
const minTextLayerChars = 40;

/// Reicht die Textebene einer PDF-Seite aus, oder muss die Seite per OCR
/// gelesen werden?
bool textLayerUsable(String text) =>
    RegExp(r'[\p{L}\p{N}]', unicode: true).allMatches(text).length >=
    minTextLayerChars;

/// Breite, mit der Seiten ohne Text für die OCR gerendert werden (≈ 200 dpi
/// bei A4) — genug für ML Kit, ohne das Handy zu überlasten.
const _ocrRenderWidth = 1654.0;

/// Importiert fertige PDFs (z. B. vom Scan-Trenner am PC) in denselben
/// Ablauf wie ein Kamera-Scan: Text lesen → Regeln + KI → Bestätigen.
class PdfImportService {
  final ScanService _scanner;
  bool _initialized = false;

  PdfImportService(this._scanner);

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await pdfrxFlutterInitialize();
    _initialized = true;
  }

  /// Kopiert [sourcePath] ins App-Verzeichnis (temporärer Name, wird nach
  /// der Nummernvergabe per [ScanService.renamePdf] umbenannt) und liest den
  /// Text jeder Seite: aus der Textebene, wenn vorhanden, sonst per OCR.
  ///
  /// Wirft [PdfImportException], wenn die Datei nicht lesbar ist.
  Future<ScanOutcome> importPdf(String sourcePath, {int index = 0}) async {
    await _ensureInitialized();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final dir = await ScanService.pdfDirectory();
    final name = 'import_${stamp}_$index.pdf';
    final target = p.join(dir.path, name);
    await File(sourcePath).copy(target);

    try {
      final pages = await _readPages(target);
      if (pages.isEmpty) {
        throw const PdfImportException('Die PDF hat keine Seiten.');
      }
      return ScanOutcome(
        relativePdfPath: p.join(ScanService.pdfDirName, name),
        pageCount: pages.length,
        ocrText: pages.join('\n\n'),
        firstPageOcr: pages.first,
      );
    } catch (e) {
      try {
        await File(target).delete();
      } catch (_) {}
      if (e is PdfImportException) rethrow;
      throw PdfImportException('Datei konnte nicht gelesen werden ($e).');
    }
  }

  Future<List<String>> _readPages(String path) async {
    final PdfDocument doc;
    try {
      doc = await PdfDocument.openFile(path);
    } on PdfPasswordException {
      throw const PdfImportException('Die PDF ist passwortgeschützt.');
    }
    final tempDir = await getTemporaryDirectory();
    final texts = <String>[];
    try {
      for (final page in doc.pages) {
        final layer = (await page.loadStructuredText()).fullText.trim();
        if (textLayerUsable(layer)) {
          texts.add(layer);
          continue;
        }
        final image = await _renderPage(page, tempDir.path);
        if (image == null) {
          texts.add(layer);
          continue;
        }
        try {
          final ocr = await _scanner.runOcr([image]);
          final text = ocr.isEmpty ? '' : ocr.first;
          // Das Längere gewinnt (OCR kann bei Bild-PDFs auch leer bleiben).
          texts.add(text.length >= layer.length ? text : layer);
        } finally {
          try {
            await File(image).delete();
          } catch (_) {}
        }
      }
    } finally {
      await doc.dispose();
    }
    return texts;
  }

  /// Rendert eine Seite als PNG für die OCR; `null`, wenn das nicht geht.
  Future<String?> _renderPage(PdfPage page, String tempDir) async {
    final scale = _ocrRenderWidth / page.width;
    final rendered = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: 0xffffffff,
    );
    if (rendered == null) return null;
    try {
      final image = await rendered.createImage();
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) return null;
        final file = File(
          p.join(
            tempDir,
            'ocr_${DateTime.now().microsecondsSinceEpoch}_${page.pageNumber}.png',
          ),
        );
        await file.writeAsBytes(png.buffer.asUint8List(), flush: true);
        return file.path;
      } finally {
        image.dispose();
      }
    } finally {
      rendered.dispose();
    }
  }
}

class PdfImportException implements Exception {
  final String message;
  const PdfImportException(this.message);

  @override
  String toString() => message;
}
