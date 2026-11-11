import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../fill/fill_export.dart';
import '../fill/page_encode.dart';
import '../reports/number_list_pdf.dart';
import '../scan/scan_service.dart';
import 'document_detail_screen.dart';

final _date = DateFormat('dd.MM.yyyy');

/// Nach einem Stapel: welche Nummer gehört auf welches Original? Sortiert
/// nach Nummer (= nach Datum), mit Vorschau der ersten Seite zum
/// Wiedererkennen, Abhaken beim Beschriften und PDF zum Ausdrucken.
class NumberListScreen extends StatefulWidget {
  final List<({Document doc, String sender, String? oldNumber})> entries;
  const NumberListScreen({super.key, required this.entries});

  @override
  State<NumberListScreen> createState() => _NumberListScreenState();
}

class _NumberListScreenState extends State<NumberListScreen> {
  final _done = <String>{};

  /// Reihenfolge der Liste: wie der Haufen liegt oder nach neuer Nummer.
  late _Order _order =
      _hasPile ? _Order.firstOnTop : _Order.byNumber;

  bool get _hasPile => widget.entries.any((e) => e.oldNumber != null);

  /// Einträge in der gewählten Reihenfolge, mit Position im Haufen
  /// (1 = oberstes Blatt).
  List<({Document doc, String sender, String? oldNumber})> get _ordered {
    final byScan = [...widget.entries]
      ..sort((a, b) => (a.oldNumber ?? a.doc.docNumber)
          .compareTo(b.oldNumber ?? b.doc.docNumber));
    return switch (_order) {
      _Order.firstOnTop => byScan,
      _Order.lastOnTop => byScan.reversed.toList(),
      _Order.byNumber => [...widget.entries]
        ..sort((a, b) => a.doc.docNumber.compareTo(b.doc.docNumber)),
    };
  }
  bool _exporting = false;

  Future<Uint8List?> _thumbnail(Document doc) async {
    try {
      final pdf =
          await PdfDocument.openFile(await ScanService.absolutePdfPath(doc.pdfPath));
      try {
        final page = pdf.pages.first;
        const width = 240.0;
        final img = await page.render(
          fullWidth: width,
          fullHeight: width * page.height / page.width,
          backgroundColor: 0xffffffff,
        );
        if (img == null) return null;
        final jpg = encodeBgraToJpg(img.width, img.height,
            Uint8List.fromList(img.pixels), quality: 70);
        img.dispose();
        return jpg;
      } finally {
        await pdf.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final rows = <NumberListRow>[];
      final ordered = _ordered;
      for (var i = 0; i < ordered.length; i++) {
        final e = ordered[i];
        rows.add(NumberListRow(
          position: _order == _Order.byNumber ? null : i + 1,
          docNumber: e.doc.docNumber,
          oldNumber: e.oldNumber,
          docDate: e.doc.docDate,
          sender: e.sender,
          title: e.doc.title,
          thumbnail: await _thumbnail(e.doc),
        ));
      }
      final bytes = await buildNumberListPdf(rows,
          font: await rootBundle.load(kFillFontAsset));
      final first = widget.entries.first.doc.docNumber;
      final last = widget.entries.last.doc.docNumber;
      final file = File(p.join((await getTemporaryDirectory()).path,
          'Nummernliste $first bis $last.pdf'));
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Nummernliste $first bis $last',
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = widget.entries.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nummern aufs Original'),
        actions: [
          IconButton(
            tooltip: 'Als PDF drucken/teilen',
            onPressed: _exporting ? null : _exportPdf,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _order == _Order.byNumber
                  ? '$n Dokumente, Nummern nach Datum vergeben. Nummer auf das '
                      'passende Original schreiben und abhaken.'
                  : 'Haufen von oben nach unten abarbeiten: auf jedes '
                      'Dokument die angezeigte Nummer schreiben, abhaken, '
                      'danach von Hand nach Nummer sortieren. Verworfene '
                      'Dokumente vorher herausnehmen.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (_hasPile)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<_Order>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: _Order.firstOnTop,
                      label: Text('Zuerst gescannt oben')),
                  ButtonSegment(
                      value: _Order.lastOnTop,
                      label: Text('Zuletzt gescannt oben')),
                  ButtonSegment(
                      value: _Order.byNumber, label: Text('Nach Nummer')),
                ],
                selected: {_order},
                onSelectionChanged: (v) => setState(() => _order = v.first),
              ),
            ),
          for (final (i, e) in _ordered.indexed)
            CheckboxListTile(
              value: _done.contains(e.doc.id),
              onChanged: (v) => setState(() =>
                  v == true ? _done.add(e.doc.id) : _done.remove(e.doc.id)),
              controlAffinity: ListTileControlAffinity.leading,
              secondary: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DocumentDetailScreen(documentId: e.doc.id),
                )),
                child: _Thumb(path: e.doc.pdfPath),
              ),
              title: Text.rich(TextSpan(children: [
                if (_order != _Order.byNumber)
                  TextSpan(
                      text: '${i + 1}. im Haufen → ',
                      style: theme.textTheme.bodyMedium),
                TextSpan(
                    text: e.doc.docNumber,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (e.oldNumber != null)
                  TextSpan(
                      text: '   (war ${e.oldNumber})',
                      style: theme.textTheme.bodySmall),
              ])),
              subtitle: Text([
                e.doc.docDate == null ? 'ohne Datum' : _date.format(e.doc.docDate!),
                if (e.doc.pageCount > 1) '${e.doc.pageCount} Seiten',
                if (e.sender.isNotEmpty) e.sender,
                if (e.doc.title.isNotEmpty) e.doc.title,
              ].join(' · ')),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(_done.length == n ? Icons.check : Icons.done_all),
        label: Text(_done.length == n
            ? 'Alle beschriftet – fertig'
            : 'Fertig (${_done.length}/$n)'),
      ),
    );
  }
}

/// Kleine Vorschau der ersten Seite.
class _Thumb extends StatelessWidget {
  final String path;
  const _Thumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 64,
      child: FutureBuilder<String>(
        future: ScanService.absolutePdfPath(path),
        builder: (context, snap) => snap.data == null
            ? const SizedBox.shrink()
            : PdfDocumentViewBuilder.file(
                snap.data!,
                builder: (context, doc) => doc == null
                    ? const SizedBox.shrink()
                    : PdfPageView(
                        document: doc,
                        pageNumber: 1,
                        maximumDpi: 60,
                        backgroundColor: Colors.white,
                      ),
              ),
      ),
    );
  }
}

enum _Order { firstOnTop, lastOnTop, byNumber }
