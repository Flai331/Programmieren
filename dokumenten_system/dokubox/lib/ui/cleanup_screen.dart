import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../reports/print_lists.dart';
import 'document_detail_screen.dart';
import 'report_share.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// Ausmistliste: Dokumente mit abgelaufener Aufbewahrungsfrist, deren
/// Original noch existiert. Auswählen, schreddern, als vernichtet markieren –
/// mit Vernichtungs-Protokoll.
class CleanupScreen extends StatefulWidget {
  const CleanupScreen({super.key});

  @override
  State<CleanupScreen> createState() => _CleanupScreenState();
}

class _CleanupScreenState extends State<CleanupScreen> {
  final _selected = <String>{};

  Future<void> _destroySelected(List<Document> docs) async {
    final chosen = docs.where((d) => _selected.contains(d.id)).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${chosen.length} Originale vernichtet?'),
        content: const Text('Die Scans bleiben erhalten. Danach wird ein '
            'Vernichtungs-Protokoll (PDF) erstellt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vernichtet + Protokoll')),
        ],
      ),
    );
    if (ok != true) return;
    final now = DateTime.now();
    for (final d in chosen) {
      await services.repository.markDestroyed(d.id, at: now);
    }
    setState(_selected.clear);
    final rows = await services.repository.destroyedBetween(
        now.subtract(const Duration(seconds: 1)),
        now.add(const Duration(seconds: 1)));
    await _protocol(rows, 'am ${_dateFormat.format(now)}');
  }

  Future<void> _protocol(List<DocRow> rows, String period) async {
    if (rows.isEmpty) return;
    final templates = await services.repository.allTemplates();
    final signature = templates.isEmpty
        ? null
        : await services.templates.bytes(templates.first.id);
    final bytes = await buildDestructionLogPdf(rows,
        font: await reportFont(), signature: signature, period: period);
    await shareReport(bytes, 'Vernichtungs-Protokoll $period');
  }

  Future<void> _protocolForPeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange:
          DateTimeRange(start: DateTime(now.year, 1, 1), end: now),
    );
    if (range == null) return;
    final rows = await services.repository.destroyedBetween(
        range.start, range.end.add(const Duration(days: 1)),
        includeUndated: true);
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Keine vernichteten Originale im Zeitraum.')));
      }
      return;
    }
    await _protocol(rows,
        '${_dateFormat.format(range.start)}–${_dateFormat.format(range.end)}');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Document>>(
      stream: services.repository.watchCleanupCandidates(),
      builder: (context, snapshot) {
        final docs = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ausmistliste'),
            actions: [
              IconButton(
                tooltip: 'Vernichtungs-Protokoll für Zeitraum',
                icon: const Icon(Icons.receipt_long),
                onPressed: _protocolForPeriod,
              ),
              if (docs != null && docs.isNotEmpty)
                IconButton(
                  tooltip: 'Alle auswählen',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(() => _selected.length == docs.length
                      ? _selected.clear()
                      : _selected.addAll(docs.map((d) => d.id))),
                ),
            ],
          ),
          floatingActionButton: _selected.isEmpty || docs == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _destroySelected(docs),
                  icon: const Icon(Icons.delete_forever),
                  label: Text('${_selected.length} vernichtet'),
                ),
          body: docs == null
              ? const Center(child: CircularProgressIndicator())
              : docs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Nichts auszumisten. 🎉\n\nDokumente erscheinen hier, '
                          'sobald ihre Aufbewahrungsfrist abgelaufen ist '
                          '(nicht, solange Garantie läuft).',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        for (final doc in docs)
                          CheckboxListTile(
                            value: _selected.contains(doc.id),
                            onChanged: (v) => setState(() => v == true
                                ? _selected.add(doc.id)
                                : _selected.remove(doc.id)),
                            title: Text(
                                doc.title.isEmpty ? doc.docNumber : doc.title),
                            subtitle: Text(
                              '${doc.docNumber} · ${doc.storageLocation} · '
                              'Frist: ${_dateFormat.format(doc.retentionUntil!)}',
                            ),
                            secondary: IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DocumentDetailScreen(documentId: doc.id),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
        );
      },
    );
  }
}
