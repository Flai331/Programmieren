import 'package:flutter/material.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:intl/intl.dart';

import '../ai/ai_extraction_service.dart';
import '../app_services.dart';
import '../data/database.dart';
import '../data/doc_types.dart';
import '../data/document_repository.dart';
import '../extract/extractors.dart';
import '../lock/lock_gate.dart';
import 'cleanup_screen.dart';
import 'confirm_screen.dart';
import 'document_detail_screen.dart';
import 'settings_screen.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  DocumentFilter _filter = const DocumentFilter();
  bool _scanning = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilter({
    String? query,
    String? docType,
    bool clearDocType = false,
    int? year,
    bool clearYear = false,
  }) {
    setState(() {
      _filter = DocumentFilter(
        query: query ?? _filter.query,
        docType: clearDocType ? null : (docType ?? _filter.docType),
        year: clearYear ? null : (year ?? _filter.year),
      );
    });
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    // Der Scanner ist eine eigene Android-Activity → die App pausiert. Ohne
    // diese Unterdrückung würde die App-Sperre zuschnappen und den Scan
    // verwerfen.
    LockController.suppressAutoLock = true;
    try {
      final outcome = await services.scanner.scan();
      if (outcome == null) return; // Nutzer hat abgebrochen.

      final docNumber = await services.repository.nextDocNumber();
      final pdfPath = await services.scanner
          .renamePdf(outcome.relativePdfPath, docNumber);
      final draft = await services.suggestions.buildDraft(outcome.ocrText);
      await _refineWithAi(draft, outcome.ocrText);

      if (!mounted) {
        // Sollte nach dem Overlay-Fix nicht mehr vorkommen; falls doch,
        // keine verwaiste PDF/Nummer hinterlassen.
        await services.scanner.deletePdf(pdfPath);
        await services.repository.releaseDocNumberIfUnused(docNumber);
        return;
      }
      final confirmed = await Navigator.of(context).push<DocumentDraft>(
        MaterialPageRoute(
          builder: (_) => ConfirmScreen(draft: draft, docNumber: docNumber),
        ),
      );

      if (confirmed == null) {
        // Verworfen: PDF löschen, Nummer wenn möglich wieder freigeben.
        await services.scanner.deletePdf(pdfPath);
        await services.repository.releaseDocNumberIfUnused(docNumber);
        return;
      }

      final doc = await services.repository.createDocument(
        docNumber: docNumber,
        draft: confirmed,
        pdfPath: pdfPath,
        pageCount: outcome.pageCount,
        ocrText: outcome.ocrText,
        refs: extractRefs(outcome.ocrText),
      );
      await services.notifications.scheduleFor(doc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$docNumber gespeichert – Original vorne in die Box legen'),
          ),
        );
      }
    } on DocScanException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan fehlgeschlagen: ${e.message}')),
        );
      }
    } finally {
      LockController.suppressAutoLock = false;
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Verfeinert den Regel-Entwurf mit dem lokalen KI-Modell (falls
  /// aktiviert). Zeigt solange einen Hinweis-Dialog; Fehler und Timeouts
  /// fallen still auf die Regel-Vorschläge zurück.
  Future<void> _refineWithAi(DocumentDraft draft, String ocrText) async {
    if (!await services.ai.isReady()) return;
    if (!mounted) return;

    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('KI liest das Dokument …')),
          ],
        ),
      ),
    ).whenComplete(() => dialogOpen = false);

    try {
      final known =
          await services.suggestions.knownCorrespondentName(ocrText);
      final ai = await services.ai.extract(ocrText);
      if (ai != null) {
        applyAiToDraft(draft, ai, preserveCorrespondent: known != null);
      }
    } finally {
      if (mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentYear = DateTime.now().year;
    final years = [for (var y = currentYear; y >= currentYear - 10; y--) y];

    return Scaffold(
      appBar: AppBar(
        title: const Text('DokuBox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Ausmistliste',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CleanupScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startScan,
        icon: _scanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.document_scanner),
        label: const Text('Scannen'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Suchen (Volltext, Nummer, Absender …)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filter.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _updateFilter(query: '');
                        },
                      ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                isDense: true,
              ),
              onChanged: (value) => _updateFilter(query: value),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterChip<String>(
                  label: 'Typ',
                  value: _filter.docType,
                  options: kDocTypes,
                  onSelected: (v) => _updateFilter(docType: v),
                  onCleared: () => _updateFilter(clearDocType: true),
                ),
                const SizedBox(width: 8),
                _FilterChip<int>(
                  label: 'Jahr',
                  value: _filter.year,
                  options: years,
                  onSelected: (v) => _updateFilter(year: v),
                  onCleared: () => _updateFilter(clearYear: true),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Document>>(
              stream: services.repository.watchDocuments(_filter),
              builder: (context, snapshot) {
                final docs = snapshot.data;
                if (docs == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(
                            _filter.isEmpty
                                ? 'Noch keine Dokumente.\nTippe auf „Scannen", '
                                    'nummeriere das Original und leg es vorne '
                                    'in die Box.'
                                : 'Nichts gefunden.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          doc.docNumber.substring(doc.docNumber.length - 4),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(
                          doc.title.isEmpty ? doc.docNumber : doc.title),
                      subtitle: Text([
                        doc.docNumber,
                        if (doc.docDate != null)
                          _dateFormat.format(doc.docDate!),
                        if (doc.docType != null) doc.docType!,
                        doc.storageLocation,
                      ].join(' · ')),
                      trailing: doc.reminderAt != null &&
                              doc.reminderAt!.isAfter(DateTime.now())
                          ? const Icon(Icons.alarm, size: 20)
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DocumentDetailScreen(documentId: doc.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> options;
  final ValueChanged<T> onSelected;
  final VoidCallback onCleared;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(value: option, child: Text('$option')),
      ],
      child: Chip(
        label: Text(value == null ? label : '$value'),
        deleteIcon: value == null
            ? const Icon(Icons.arrow_drop_down)
            : const Icon(Icons.clear, size: 18),
        onDeleted: value == null ? null : onCleared,
      ),
    );
  }
}
