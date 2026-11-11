import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:intl/intl.dart';

import '../ai/ai_extraction_service.dart';
import '../app_services.dart';
import '../data/database.dart';
import '../data/doc_types.dart';
import '../data/document_repository.dart';
import '../data/finance.dart';
import '../extract/extractors.dart';
import '../extract/suggestion_service.dart';
import '../lock/lock_gate.dart';
import '../scan/pdf_import_service.dart';
import '../scan/scan_service.dart';
import '../scan/share_receiver.dart';
import '../scan/wlan_receiver.dart';
import 'cleanup_screen.dart';
import 'confirm_screen.dart';
import 'document_detail_screen.dart';
import 'finance_actions.dart';
import 'finance_screen.dart';
import 'network_scanner_screen.dart';
import 'settings_screen.dart';
import 'task_widgets.dart';
import 'tasks_screen.dart';
import 'wlan_scan_screen.dart';

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
  void initState() {
    super.initState();
    // PDFs aus dem „Teilen"-Menü: beim Start und während die App läuft.
    ShareReceiver.listen(_importShared);
    WidgetsBinding.instance.addPostFrameCallback((_) => _importShared());
  }

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
    String? financeStatus,
    bool clearFinance = false,
    String? categoryId,
    bool clearCategory = false,
  }) {
    setState(() {
      _filter = DocumentFilter(
        query: query ?? _filter.query,
        docType: clearDocType ? null : (docType ?? _filter.docType),
        year: clearYear ? null : (year ?? _filter.year),
        financeStatus:
            clearFinance ? null : (financeStatus ?? _filter.financeStatus),
        categoryId:
            clearCategory ? null : (categoryId ?? _filter.categoryId),
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
      final result = await services.scanner.scan();
      if (result == null) return; // Nutzer hat abgebrochen.
      await _handleScanResult(result);
    } on DocScanException catch (e) {
      _snack('Scan fehlgeschlagen: ${e.message}');
    } finally {
      LockController.suppressAutoLock = false;
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Kamera oder Netzwerk-Scanner?
  Future<void> _scanMenu() async {
    if (_scanning) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Mit der Kamera'),
              subtitle: const Text('Randerkennung, mehrere Seiten'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Mit dem Scanner (WLAN)'),
              subtitle: const Text(
                  'Epson, Canon, HP, Brother … – Einzug, doppelseitig'),
              onTap: () => Navigator.pop(ctx, 'network'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'camera') await _startScan();
    if (choice == 'network') await _scanNetwork();
  }

  Future<void> _scanNetwork() async {
    if (_scanning) return;
    final result = await Navigator.of(context).push<NetworkScanResult>(
      MaterialPageRoute(builder: (_) => const NetworkScannerScreen()),
    );
    if (result == null || result.imagePaths.isEmpty || !mounted) return;
    setState(() => _scanning = true);
    try {
      final scan = await _withProgress(
        'Erkenne Leerseiten und lese ${result.imagePaths.length} '
        'Seite${result.imagePaths.length == 1 ? '' : 'n'} …',
        () => services.scanner
            .processImages(result.imagePaths, duplex: result.duplex),
      );
      await _handleScanResult(scan);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Gemeinsamer Ablauf nach Kamera- oder Netzwerk-Scan.
  Future<void> _handleScanResult(ScanResult result) async {
    {
      if (result.documents.isEmpty) {
        _snack('Nur leere Seiten erkannt – nichts gespeichert.');
        return;
      }
      if (result.documents.length > 1 || result.blankPages > 0) {
        _snack('${result.documents.length} Dokument(e) erkannt, '
            '${result.blankPages} Leerseite(n) entfernt');
      }

      // Jedes Dokument des Stapels einzeln bestätigen. „Zurück" verwirft nur
      // dieses eine Dokument, die übrigen bleiben im Ablauf.
      var saved = 0;
      for (final outcome in result.documents) {
        if (await _confirmAndSave(outcome)) saved++;
      }
      if (saved > 1 && mounted) _snack('$saved Dokumente gespeichert');
    }
  }

  Future<void> _importShared() async {
    if (_scanning) return;
    final paths = await ShareReceiver.takeSharedPdfs();
    if (paths.isEmpty) return;
    await _importPaths(paths, deleteSources: true);
  }

  Future<void> _importMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('PDF-Dateien auswählen'),
              subtitle: const Text('Vom Handy, aus Downloads oder Drive'),
              onTap: () => Navigator.pop(ctx, 'files'),
            ),
            ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text('Vom PC (WLAN)'),
              subtitle: const Text(
                  'PDFs und Unterschriften per QR-Code vom Scan-Trenner'),
              onTap: () => Navigator.pop(ctx, 'wlan'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'files') await _pickPdfs();
    if (choice == 'wlan') await _receiveWlan();
  }

  /// QR-Code vom Scan-Trenner scannen, PDFs übers WLAN laden, importieren.
  Future<void> _receiveWlan() async {
    if (_scanning) return;
    final base = await Navigator.of(context).push<Uri>(
      MaterialPageRoute(builder: (_) => const WlanScanScreen()),
    );
    if (base == null || !mounted) return;
    final receiver = WlanReceiver(base);
    try {
      final files =
          await _withProgress('Verbinde mit dem PC …', receiver.list);
      if (files.isEmpty) {
        _snack('Der PC bietet keine Dateien an.');
        return;
      }
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${files.length} Datei${files.length == 1 ? '' : 'en'} '
              'vom PC übernehmen?'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in files)
                  ListTile(
                    dense: true,
                    leading: Icon(f.isTemplate
                        ? Icons.draw
                        : Icons.picture_as_pdf),
                    title: Text(f.name),
                    subtitle: Text(f.isTemplate
                        ? 'Unterschrift/Vorlage · ${(f.size / 1024).ceil()} KB'
                        : '${(f.size / 1024).ceil()} KB'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final paths = await _withProgress(
        'Lade ${files.length} Datei${files.length == 1 ? '' : 'en'} vom PC …',
        () => receiver.download(files),
      );
      // Unterschriften/Vorlagen in die Sammlung, PDFs in den Import.
      final pdfs = <String>[];
      var templates = 0;
      for (var i = 0; i < files.length; i++) {
        if (!files[i].isTemplate) {
          pdfs.add(paths[i]);
          continue;
        }
        final file = File(paths[i]);
        try {
          final name = files[i].name.replaceAll(
              RegExp(r'\.png$', caseSensitive: false), '');
          await services.templates.addPng(name, await file.readAsBytes());
          templates++;
        } on FormatException {
          _snack('${files[i].name}: keine gültige PNG.');
        } finally {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
      if (templates > 0) {
        _snack('$templates Unterschrift${templates == 1 ? '' : 'en'}/'
            'Vorlage${templates == 1 ? '' : 'n'} gespeichert – beim '
            'Ausfüllen unter „Unterschrift“');
      }
      if (pdfs.isNotEmpty) await _importPaths(pdfs, deleteSources: true);
    } on WlanException catch (e) {
      _snack(e.message);
    } on FormatException {
      _snack('Antwort vom PC nicht lesbar.');
    }
  }

  /// PDFs aus dem Dateisystem auswählen (z. B. vom Scan-Trenner am PC).
  Future<void> _pickPdfs() async {
    if (_scanning) return;
    LockController.suppressAutoLock = true;
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: true,
      );
    } catch (e) {
      _snack('Dateiauswahl fehlgeschlagen: $e');
    } finally {
      LockController.suppressAutoLock = false;
    }
    final paths = [
      for (final f in picked?.files ?? const <PlatformFile>[])
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty) return;
    // file_picker legt Kopien im Cache an → danach aufräumen.
    await _importPaths(paths, deleteSources: true);
  }

  /// Liest jede PDF (Textebene oder OCR) und schickt sie durch denselben
  /// Ablauf wie einen Scan: Nummer → Regeln + KI → Bestätigen → Speichern.
  Future<void> _importPaths(List<String> paths,
      {bool deleteSources = false}) async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      if (!await services.ai.isReady()) {
        _snack('Tipp: Mit der lokalen KI (Einstellungen) werden Absender, '
            'Titel und Tags genauer erkannt.');
      }
      var saved = 0;
      var failed = 0;
      for (var i = 0; i < paths.length; i++) {
        if (!mounted) break;
        final ScanOutcome outcome;
        try {
          outcome = await _withProgress(
            paths.length > 1
                ? 'Lese PDF ${i + 1} von ${paths.length} …'
                : 'Lese PDF …',
            () => services.pdfImport.importPdf(paths[i], index: i),
          );
        } on PdfImportException catch (e) {
          failed++;
          _snack('${_fileName(paths[i])}: ${e.message}');
          continue;
        } finally {
          if (deleteSources) {
            try {
              await File(paths[i]).delete();
            } catch (_) {/* Cache-Kopie, räumt das System notfalls auf */}
          }
        }
        if (await _confirmAndSave(outcome)) saved++;
      }
      if (paths.length > 1 && mounted) {
        _snack('$saved von ${paths.length} PDFs gespeichert'
            '${failed > 0 ? ', $failed nicht lesbar' : ''}');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  static String _fileName(String path) =>
      path.split(Platform.pathSeparator).last;

  /// Zeigt einen nicht abbrechbaren Fortschritts-Dialog, solange [work] läuft.
  Future<T> _withProgress<T>(String text, Future<T> Function() work) async {
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    ).whenComplete(() => dialogOpen = false);
    try {
      return await work();
    } finally {
      if (mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Vergibt die Nummer, füllt vor, lässt bestätigen und speichert ein
  /// Dokument. Liefert `true`, wenn es gespeichert wurde.
  Future<bool> _confirmAndSave(ScanOutcome outcome) async {
    final docNumber = await services.repository.nextDocNumber();
    final pdfPath =
        await services.scanner.renamePdf(outcome.relativePdfPath, docNumber);
    final finance = await FinanceSettings.load();
    final draft = await services.suggestions
        .buildDraft(outcome.ocrText, finance: finance);
    await _refineWithAi(draft, outcome.ocrText, outcome.firstPageOcr);
    // Die KI kann Datum/Typ korrigiert haben → Fälligkeit neu berechnen.
    applyPaymentSuggestions(draft, outcome.ocrText, finance: finance);

    if (!mounted) {
      // Sollte nach dem Overlay-Fix nicht mehr vorkommen; falls doch,
      // keine verwaiste PDF/Nummer hinterlassen.
      await services.scanner.deletePdf(pdfPath);
      await services.repository.releaseDocNumberIfUnused(docNumber);
      return false;
    }
    final confirmed = await Navigator.of(context).push<DocumentDraft>(
      MaterialPageRoute(
        builder: (_) => ConfirmScreen(
          draft: draft,
          docNumber: docNumber,
          pdfPath: pdfPath,
        ),
      ),
    );

    if (confirmed == null) {
      // Verworfen: PDF löschen, Nummer wenn möglich wieder freigeben.
      await services.scanner.deletePdf(pdfPath);
      await services.repository.releaseDocNumberIfUnused(docNumber);
      return false;
    }

    final doc = await services.repository.createDocument(
      docNumber: docNumber,
      draft: confirmed,
      pdfPath: pdfPath,
      pageCount: outcome.pageCount,
      ocrText: outcome.ocrText,
      refs: extractRefs(outcome.ocrText),
    );
    await services.notifications.syncDocument(doc.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$docNumber gespeichert – Original vorne in die Box legen'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Erinnerung',
          onPressed: () => showTaskEditor(context, doc: doc),
        ),
      ));
    }
    return true;
  }

  /// Verfeinert den Regel-Entwurf mit dem lokalen KI-Modell (falls
  /// aktiviert). Zeigt solange einen Hinweis-Dialog; Fehler und Timeouts
  /// fallen still auf die Regel-Vorschläge zurück.
  Future<void> _refineWithAi(
      DocumentDraft draft, String fullOcr, String firstPageOcr) async {
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
      // Bekannten Absender aus dem Volltext, aber KI nur auf die erste
      // Seite ansetzen (schneller; Absender/Datum/Betreff stehen dort).
      final known =
          await services.suggestions.knownCorrespondentName(fullOcr);
      final knownTags = await services.repository.allTagNames();
      final categories = await services.repository.allCategories();
      final ai = await services.ai.extract(
        firstPageOcr,
        knownTags: knownTags,
        categories: [for (final c in categories) c.name],
      );
      if (ai != null) {
        applyAiToDraft(draft, ai, preserveCorrespondent: known != null);
        // Kategorie nur für Firmen vorschlagen, die noch keine haben — eine
        // selbst vergebene Kategorie hat immer Vorrang.
        if (ai.kategorie != null &&
            await services.repository
                    .categoryIdForCorrespondentName(draft.correspondentName) ==
                null) {
          for (final c in categories) {
            if (c.name == ai.kategorie) draft.categoryId = c.id;
          }
        }
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
          StreamBuilder<int>(
            stream: services.repository.watchDueTaskCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.task_alt),
                ),
                tooltip: 'Aufgaben (heute fällig oder überfällig: $count)',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TasksScreen()),
                ),
              );
            },
          ),
          StreamBuilder<int>(
            stream: services.repository.watchOpenFinanceCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.payments_outlined),
                ),
                tooltip: 'Offene Posten (Rechnungen & Erstattungen)',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FinanceScreen()),
                ),
              );
            },
          ),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            tooltip: 'PDF importieren',
            onPressed: _scanning ? null : _importMenu,
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: _scanMenu,
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner),
            label: const Text('Scannen'),
          ),
        ],
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
                StreamBuilder<List<Category>>(
                  stream: services.repository.watchCategories(),
                  builder: (context, snapshot) {
                    final cats = snapshot.data ?? const <Category>[];
                    final names = {for (final c in cats) c.id: c.name};
                    return _FilterChip<String>(
                      label: 'Kategorie',
                      value: _filter.categoryId,
                      options: [for (final c in cats) c.id],
                      labelOf: (id) => names[id] ?? 'Kategorie',
                      onSelected: (v) => _updateFilter(categoryId: v),
                      onCleared: () => _updateFilter(clearCategory: true),
                    );
                  },
                ),
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
                _FilterChip<String>(
                  label: 'Zahlung',
                  value: _filter.financeStatus,
                  options: const [
                    ...PaymentStatus.all,
                    ClaimStatus.toSubmit,
                    ClaimStatus.submitted,
                  ],
                  onSelected: (v) => _updateFilter(financeStatus: v),
                  onCleared: () => _updateFilter(clearFinance: true),
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
                      trailing: doc.paymentStatus == PaymentStatus.open
                          ? Icon(
                              isOverdue(doc)
                                  ? Icons.warning_amber
                                  : Icons.payments_outlined,
                              size: 20,
                              color: isOverdue(doc)
                                  ? theme.colorScheme.error
                                  : null,
                            )
                          : doc.reminderAt != null &&
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

  /// Anzeigetext einer Option (Standard: `toString()`).
  final String Function(T option)? labelOf;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    required this.onCleared,
    this.labelOf,
  });

  String _text(T option) => labelOf?.call(option) ?? '$option';

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(value: option, child: Text(_text(option))),
      ],
      child: Chip(
        label: Text(value == null ? label : _text(value as T)),
        deleteIcon: value == null
            ? const Icon(Icons.arrow_drop_down)
            : const Icon(Icons.clear, size: 18),
        onDeleted: value == null ? null : onCleared,
      ),
    );
  }
}
