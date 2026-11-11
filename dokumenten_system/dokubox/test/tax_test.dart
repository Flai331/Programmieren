import 'dart:io';
import 'dart:typed_data';

import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/data/tax.dart';
import 'package:dokubox/reports/tax_bundle.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

void main() {
  test('Steuer-Kategorie vorschlagen', () {
    expect(suggestTaxCategory('Zuwendungsbestätigung über Geldzuwendungen', null), 'spenden');
    expect(suggestTaxCategory('Arbeitskosten gem. § 35a EStG: 320 €', 'Rechnung'), 'haushaltsnah');
    expect(suggestTaxCategory('Rechnung nach GOÄ', null), 'krankheit');
    expect(suggestTaxCategory('Ausdruck der elektronischen Lohnsteuerbescheinigung', null), 'lohnsteuer');
    expect(suggestTaxCategory('Stromrechnung', 'Rechnung'), isNull);
  });

  test('Steuer-Mappe: Inhaltsverzeichnis + Trennblätter + Originale verlustfrei',
      () async {
    final lib = '${Directory.current.path}/.dart_tool/hooks_runner/shared/pdfium_dart/build/chromium_7811/linux-x64/libpdfium.so';
    if (!File(lib).existsSync()) return; // pdfium nur nach einem Build vorhanden
    Pdfrx.pdfiumModulePath = lib;
    await pdfrxInitialize();
    final tmp = await Directory.systemTemp.createTemp('dokubox_tax');
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final repo = DocumentRepository(db);
    Future<void> add(String nr, String cat, int pages, int cents) async {
      final pdf = pw.Document();
      for (var i = 0; i < pages; i++) {
        pdf.addPage(pw.Page(build: (_) => pw.Text('Beleg $nr Seite ${i + 1}')));
      }
      File('${tmp.path}/$nr.pdf').writeAsBytesSync(await pdf.save());
      await repo.createDocument(
        docNumber: nr,
        draft: DocumentDraft(
            title: 'Beleg $nr', storageLocation: 'Box', docDate: DateTime(2025, 5, 1),
            amountCents: cents, taxCategory: cat),
        pdfPath: '$nr.pdf', pageCount: pages, ocrText: '');
    }
    await add('2026-0001', 'spenden', 1, 5000);
    await add('2026-0002', 'haushaltsnah', 2, 32000);
    await add('2026-0003', 'spenden', 1, 2500);
    final rows = await repo.taxDocuments(2025);
    expect(rows.length, 3);
    expect(groupTax(rows).keys, ['haushaltsnah', 'spenden']);
    final bytes = await buildTaxBundle(
      year: 2025,
      rows: rows,
      pdfPathOf: (d) async => '${tmp.path}/${d.pdfPath}',
      font: ByteData.sublistView(File('assets/fonts/DejaVuSans.ttf').readAsBytesSync()),
      tempDir: tmp,
    );
    final out = await PdfDocument.openData(bytes);
    // 1 Inhaltsverzeichnis + 2 Trennblätter + 4 Belegseiten
    expect(out.pages.length, 7);
    final text = (await out.pages[2].loadText())!.fullText;
    expect(text, contains('Beleg 2026-0002 Seite 1')); // Text bleibt erhalten
    await out.dispose();
    await db.close();
    await tmp.delete(recursive: true);
  });
}
