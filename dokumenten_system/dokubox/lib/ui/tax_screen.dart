import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../app_services.dart';
import '../data/finance.dart';
import '../data/tax.dart';
import '../reports/tax_bundle.dart';
import '../scan/scan_service.dart';
import 'document_detail_screen.dart';
import 'report_share.dart';

/// Steuer-Mappe: Belege eines Jahres nach Kategorie, Summen, eine PDF.
class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key});
  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  int _year = DateTime.now().year - 1;
  bool _busy = false;

  Future<void> _build(List<TaxRow> rows) async {
    setState(() => _busy = true);
    try {
      final bytes = await buildTaxBundle(
        year: _year,
        rows: rows,
        pdfPathOf: (d) => ScanService.absolutePdfPath(d.filledPdfPath ?? d.pdfPath),
        font: await reportFont(),
        tempDir: await getTemporaryDirectory(),
      );
      await shareReport(bytes, 'Steuer-Mappe $_year');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<TaxRow>>(
      future: services.repository.taxDocuments(_year),
      builder: (context, snap) {
        final rows = snap.data ?? const <TaxRow>[];
        final groups = groupTax(rows);
        final total = rows.fold(0, (a, r) => a + taxAmount(r.doc));
        return Scaffold(
          appBar: AppBar(title: const Text('Steuer-Mappe')),
          floatingActionButton: rows.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _busy ? null : () => _build(rows),
                  icon: _busy
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf),
                  label: const Text('Mappe erstellen'),
                ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Row(children: [
                IconButton(
                    onPressed: () => setState(() => _year--),
                    icon: const Icon(Icons.chevron_left)),
                Text('$_year', style: theme.textTheme.titleLarge),
                IconButton(
                    onPressed: _year >= DateTime.now().year
                        ? null
                        : () => setState(() => _year++),
                    icon: const Icon(Icons.chevron_right)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text('${rows.length} Belege · ${formatEuro(total)}'),
                ),
              ]),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Noch keine Belege für dieses Jahr. Beim Bestätigen bzw. '
                    'Bearbeiten eines Dokuments „Steuer-Mappe“ wählen – oft '
                    'schlägt die App die Kategorie schon vor.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final e in groups.entries) ...[
                ListTile(
                  title: Text(kTaxCategories[e.key]!, style: theme.textTheme.titleSmall),
                  trailing: Text(formatEuro(e.value.fold(0, (a, r) => a + taxAmount(r.doc)))),
                ),
                for (final r in e.value)
                  ListTile(
                    dense: true,
                    title: Text(r.doc.title.isEmpty ? r.doc.docNumber : r.doc.title),
                    subtitle: Text('${r.doc.docNumber} · ${r.sender}'),
                    trailing: Text(taxAmount(r.doc) == 0 ? '–' : formatEuro(taxAmount(r.doc))),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => DocumentDetailScreen(documentId: r.doc.id)))
                        .then((_) => setState(() {})),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
