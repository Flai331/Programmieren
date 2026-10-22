import 'dart:io';

import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import 'blank_pages.dart';

/// Ergebnis eines abgeschlossenen Scan-Durchlaufs.
class ScanOutcome {
  /// Pfad der erzeugten PDF, relativ zum App-Dokumentenverzeichnis.
  final String relativePdfPath;
  final int pageCount;

  /// OCR-Text aller Seiten (für Volltextsuche und Regel-Extraktion).
  final String ocrText;

  /// OCR-Text nur der ERSTEN Seite (für das KI-Auslesen — dort stehen
  /// Absender/Datum/Betreff, und weniger Text = schneller).
  final String firstPageOcr;

  const ScanOutcome({
    required this.relativePdfPath,
    required this.pageCount,
    required this.ocrText,
    required this.firstPageOcr,
  });
}

/// Ergebnis eines Scanner-Durchlaufs: ein oder mehrere Dokumente (der Stapel
/// wird an Leerseiten getrennt) plus Anzahl der entfernten Leerseiten.
class ScanResult {
  final List<ScanOutcome> documents;
  final int blankPages;

  const ScanResult({required this.documents, required this.blankPages});
}

/// Kapselt Scanner (ML Kit / VisionKit), PDF-Erzeugung und On-Device-OCR.
class ScanService {
  final _scanner = FlutterDocScanner();

  /// Unterverzeichnis für Dokument-PDFs im App-Dokumentenverzeichnis.
  static const pdfDirName = 'pdfs';

  static Future<Directory> pdfDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, pdfDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> absolutePdfPath(String relativePath) async {
    final base = await getApplicationDocumentsDirectory();
    return p.join(base.path, relativePath);
  }

  /// Startet den Scanner. Liefert `null`, wenn der Nutzer abbricht.
  ///
  /// Leere Seiten werden erkannt und entfernt; an ihnen wird der Stapel in
  /// einzelne Dokumente getrennt (abschaltbar in den Einstellungen).
  ///
  /// Jede PDF bekommt zunächst einen temporären Namen; erst wenn die Nummer
  /// vergeben ist, wird sie per [renamePdf] umbenannt. So verbrennt ein
  /// abgebrochener Scan keine Dokumentnummer.
  Future<ScanResult?> scan() async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    // Großzügiges Limit: ein Stapel mit Trenn-Blättern hat schnell viele Seiten.
    final result = await _scanner.getScannedDocumentAsImages(page: 40);
    if (result == null || result.images.isEmpty) return null;

    // Android liefert file://-URIs, iOS Dateipfade — beides normalisieren.
    final imagePaths = [
      for (final raw in result.images)
        raw.startsWith('file://') ? Uri.parse(raw).toFilePath() : raw,
    ];

    try {
      final blank = List<bool>.filled(imagePaths.length, false);
      final detect = await BlankPageSettings.isEnabled();
      if (detect) {
        final threshold = (await BlankPageSettings.sensitivity()).inkThreshold;
        for (var i = 0; i < imagePaths.length; i++) {
          blank[i] = await isBlankImageFile(imagePaths[i],
              inkThreshold: threshold);
        }
      }

      final groups = groupPagesAtBlanks(blank, split: detect);
      final documents = <ScanOutcome>[];
      for (var n = 0; n < groups.length; n++) {
        final paths = [for (final i in groups[n]) imagePaths[i]];
        final pages = await _runOcr(paths);
        final relativePdfPath = await _buildPdf(paths, 'scan_${stamp}_${n + 1}');
        documents.add(ScanOutcome(
          relativePdfPath: relativePdfPath,
          pageCount: paths.length,
          ocrText: pages.join('\n\n'),
          firstPageOcr: pages.isNotEmpty ? pages.first : '',
        ));
      }
      return ScanResult(
        documents: documents,
        blankPages: blank.where((b) => b).length,
      );
    } finally {
      // Scanner-Zwischendateien aufräumen (liegen im Cache).
      for (final path in imagePaths) {
        try {
          await File(path).delete();
        } catch (_) {/* Cache räumt das System notfalls selbst auf */}
      }
    }
  }

  /// Benennt die temporäre Scan-PDF auf die endgültige Nummer um.
  Future<String> renamePdf(String relativePath, String docNumber) async {
    final absolute = await absolutePdfPath(relativePath);
    final dir = await pdfDirectory();
    final target = p.join(dir.path, '$docNumber.pdf');
    await File(absolute).rename(target);
    return p.join(pdfDirName, '$docNumber.pdf');
  }

  /// Löscht eine (z. B. verworfene) Scan-PDF.
  Future<void> deletePdf(String relativePath) async {
    final absolute = await absolutePdfPath(relativePath);
    final file = File(absolute);
    if (await file.exists()) await file.delete();
  }

  /// OCR pro Seite; liefert eine Liste mit einem Eintrag je Seite (in
  /// Lesereihenfolge sortiert).
  Future<List<String>> _runOcr(List<String> imagePaths) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final pages = <String>[];
    try {
      for (final path in imagePaths) {
        final recognized =
            await recognizer.processImage(InputImage.fromFilePath(path));
        pages.add(_textInReadingOrder(recognized));
      }
    } finally {
      await recognizer.close();
    }
    return pages;
  }

  /// ML Kit liefert Textblöcke in Erkennungs-, nicht in Lesereihenfolge.
  /// Für die Extraktion (Briefkopf oben, Datum zuerst) werden die Blöcke
  /// nach Position sortiert: oben → unten, bei gleicher Höhe links → rechts.
  static String _textInReadingOrder(RecognizedText recognized) {
    final blocks = [...recognized.blocks];
    blocks.sort((a, b) {
      final at = a.boundingBox.top;
      final bt = b.boundingBox.top;
      // Blöcke auf ähnlicher Höhe (halbe Blockhöhe Toleranz) als eine
      // "Zeile" behandeln und links vor rechts lesen.
      final tolerance =
          ((a.boundingBox.height + b.boundingBox.height) / 4).clamp(8.0, 60.0);
      if ((at - bt).abs() < tolerance) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return at.compareTo(bt);
    });
    return blocks
        .map((block) => block.lines.map((l) => l.text).join('\n'))
        .join('\n');
  }

  Future<String> _buildPdf(List<String> imagePaths, String docNumber) async {
    final pdf = pw.Document();
    for (final path in imagePaths) {
      final image = pw.MemoryImage(await File(path).readAsBytes());
      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    final dir = await pdfDirectory();
    final file = File(p.join(dir.path, '$docNumber.pdf'));
    await file.writeAsBytes(await pdf.save());
    return p.join(pdfDirName, '$docNumber.pdf');
  }
}
