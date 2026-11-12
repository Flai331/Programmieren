import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:intl/intl.dart';

import '../ai/ai_extraction_service.dart';
import '../backup/auto_backup.dart';
import '../app_services.dart';
import '../data/batch_numbering.dart';
import '../data/database.dart';
import '../data/deadline_settings.dart';
import '../data/tax.dart';
import '../extract/deadlines.dart';
import '../extract/ref_matching.dart';
import '../data/setup_mode.dart';
import '../sync/pairing.dart';
import '../sync/sync_runner.dart';
import '../sync/sync_service.dart';
import '../data/doc_types.dart';
import '../data/document_repository.dart';
import '../data/finance.dart';
import '../extract/extractors.dart';
import '../extract/suggestion_service.dart';
import '../lock/lock_gate.dart';
import '../scan/blank_pages.dart';
import '../scan/pdf_import_service.dart';
import '../scan/scan_service.dart';
import '../scan/share_receiver.dart';
import '../scan/wlan_receiver.dart';
import 'cases_screen.dart';
import 'cleanup_screen.dart';
import 'confirm_screen.dart';
import 'document_detail_screen.dart';
import 'finance_actions.dart';
import 'finance_screen.dart';
import 'network_scanner_screen.dart';
import 'number_list_screen.dart';
import 'settings_screen.dart';
import 'task_widgets.dart';
import 'tasks_screen.dart';
import 'wlan_scan_screen.dart';
import '../platform.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  DocumentFilter _filter = const DocumentFilter();
  bool _scanning = false;
  Timer? _backupTimer;

  /// Am PC: fällige Backups schreiben (alle 15 min prüfen → USB-Stick
  /// wird erkannt, sobald er steckt) und an alte Backups erinnern.
  Future<void> _autoBackup() async {
    try {
      await AutoBackup(services.backup.createBackupFile).runIfDue();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    // PDFs aus dem „Teilen"-Menü: beim Start und während die App läuft.
    WidgetsBinding.instance.addObserver(this);
    // Abgleich mit gekoppelten Geräten beim Start; am PC zusätzlich
    // bereitstellen, damit das Handy jederzeit abgleichen kann.
    if (isDesktop) {
      SyncService.localAddress().then((host) {
        if (host != null) services.sync.startServer(host: host).ignore();
      });
      _autoBackup().then((_) async {
        final hint = await AutoBackup.reminder();
        if (hint != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
        }
      });
      _backupTimer =
          Timer.periodic(const Duration(minutes: 15), (_) => _autoBackup());
    }
    autoSync().then((_) {
      if (mounted) setState(() {});
    });
    ShareReceiver.listen(_importShared);
    WidgetsBinding.instance.addPostFrameCallback((_) => _importShared());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_scanning) {
      autoSync().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backupTimer?.cancel();
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
        financeStatus: clearFinance
            ? null
            : (financeStatus ?? _filter.financeStatus),
        categoryId: clearCategory ? null : (categoryId ?? _filter.categoryId),
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
    var mode = await BlankPageSettings.mode();
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Leere Seiten: direkt vor dem Scan umschaltbar (wird gemerkt).
            StatefulBuilder(
              builder: (ctx, setSheet) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leere Seiten',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: BlankModeSelector(
                        value: mode,
                        onChanged: (m) async {
                          await BlankPageSettings.setMode(m);
                          setSheet(() => mode = m);
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.description,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            if (isMobile)
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
                'Epson, Canon, HP, Brother … – Einzug, doppelseitig',
              ),
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
        () => services.scanner.processImages(
          result.imagePaths,
          duplex: result.duplex,
        ),
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
        _snack(
          '${result.documents.length} Dokument(e) erkannt, '
          '${result.blankPages} Leerseite(n) entfernt',
        );
      }

      await _confirmOutcomes(result.documents);
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
                'PDFs und Unterschriften per QR-Code vom Scan-Trenner',
              ),
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
    final base = await Navigator.of(
      context,
    ).push<Uri>(MaterialPageRoute(builder: (_) => const WlanScanScreen()));
    if (base == null || !mounted) return;
    final receiver = WlanReceiver(base);
    try {
      final files = await _withProgress('Verbinde mit dem PC …', receiver.list);
      if (files.isEmpty) {
        _snack('Der PC bietet keine Dateien an.');
        return;
      }
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            '${files.length} Datei${files.length == 1 ? '' : 'en'} '
            'vom PC übernehmen?',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in files)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      f.isTemplate ? Icons.draw : Icons.picture_as_pdf,
                    ),
                    title: Text(f.name),
                    subtitle: Text(
                      f.isTemplate
                          ? 'Unterschrift/Vorlage · ${(f.size / 1024).ceil()} KB'
                          : '${(f.size / 1024).ceil()} KB',
                    ),
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
            RegExp(r'\.png$', caseSensitive: false),
            '',
          );
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
        _snack(
          '$templates Unterschrift${templates == 1 ? '' : 'en'}/'
          'Vorlage${templates == 1 ? '' : 'n'} gespeichert – beim '
          'Ausfüllen unter „Unterschrift“',
        );
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
  Future<void> _importPaths(
    List<String> paths, {
    bool deleteSources = false,
  }) async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      if (!await services.ai.isReady()) {
        _snack(
          'Tipp: Mit der lokalen KI (Einstellungen) werden Absender, '
          'Titel und Tags genauer erkannt.',
        );
      }
      var saved = 0;
      var failed = 0;
      final outcomes = <ScanOutcome>[];
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
            } catch (_) {
              /* Cache-Kopie, räumt das System notfalls auf */
            }
          }
        }
        outcomes.add(outcome);
      }
      saved = await _confirmOutcomes(outcomes);
      if (paths.length > 1 && mounted) {
        _snack(
          '$saved von ${paths.length} PDFs gespeichert'
          '${failed > 0 ? ', $failed nicht lesbar' : ''}',
        );
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
  /// Ein Dokument → sofort Nummer, bestätigen, speichern. Mehrere →
  /// [_confirmBatch] (Nummern am Ende nach Datum). Liefert die Anzahl
  /// gespeicherter Dokumente.
  Future<int> _confirmOutcomes(List<ScanOutcome> outcomes) async {
    if (outcomes.isEmpty) return 0;
    if (outcomes.length == 1 ||
        await SetupMode.isOn() ||
        !await SyncSettings.isMain()) {
      // Ersterfassung: jedes Dokument bekommt eine vorläufige Nummer, die
      // endgültigen kommen gesammelt bei „Nummern vergeben“.
      if (outcomes.length > 1) {
        var saved = 0;
        for (final o in outcomes) {
          if (await _confirmAndSave(o)) saved++;
        }
        return saved;
      }
      return await _confirmAndSave(outcomes.single) ? 1 : 0;
    }
    return _confirmBatch(outcomes);
  }

  /// Ersterfassung abschließen: alle vorläufigen Dokumente bekommen
  /// endgültige Nummern nach Datum; danach Nummernliste.
  Future<void> _finishSetup(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nummern vergeben?'),
        content: Text(
          '$count Dokumente bekommen jetzt ihre endgültigen Nummern – nach '
          'Dokumentdatum sortiert, ältestes zuerst (ohne Datum ans Ende). '
          'Danach ist die Ersterfassung beendet und neue Scans bekommen '
          'wieder sofort ihre Nummer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Noch nicht'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nummern vergeben'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await _withProgress('Vergebe Nummern …', () async {
      final r = await services.repository.assignFinalNumbers();
      for (final n in r) {
        for (final e in n.renames.entries) {
          final from = File(await ScanService.absolutePdfPath(e.key));
          if (await from.exists()) {
            await from.rename(await ScanService.absolutePdfPath(e.value));
          }
        }
        await services.notifications.syncDocument(n.doc.id);
      }
      await SetupMode.set(false);
      return r;
    });
    if (!mounted) return;
    setState(() {});
    if (result.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NumberListScreen(
          entries: [
            for (final n in result)
              (doc: n.doc, sender: n.sender, oldNumber: n.oldNumber),
          ],
        ),
      ),
    );
  }

  Widget _setupBanner() {
    return FutureBuilder<bool>(
      future: SetupMode.isOn(),
      builder: (context, on) {
        if (on.data != true) return const SizedBox.shrink();
        return StreamBuilder<int>(
          stream: services.repository.watchProvisionalCount(),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            final theme = Theme.of(context);
            return Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.playlist_add_check),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ersterfassung: $count Dokument'
                        '${count == 1 ? '' : 'e'} gesammelt (vorläufige '
                        'Nummern)',
                      ),
                    ),
                    FilledButton(
                      onPressed: count == 0 ? null : () => _finishSetup(count),
                      child: const Text('Nummern vergeben'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Prüft vor dem Bestätigen auf Dubletten und verwandte Dokumente.
  Future<
    ({
      List<({String docNumber, String title, String reason})> duplicates,
      List<
        ({
          String id,
          String docNumber,
          String title,
          String reasons,
          bool strong,
        })
      >
      related,
    })
  >
  _analyze(ScanOutcome outcome, DocumentDraft draft) async {
    final repo = services.repository;
    try {
      final bytes = await File(
        await ScanService.absolutePdfPath(outcome.relativePdfPath),
      ).readAsBytes();
      final hash = await Sha256().hash(bytes);
      draft.contentHash = hash.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
    } catch (_) {}
    final refs = extractRefs(outcome.ocrText);
    final dups = await repo.findDuplicates(
      contentHash: draft.contentHash,
      refs: refs,
      correspondentName: draft.correspondentName,
      ocrText: outcome.ocrText,
      docDate: draft.docDate,
    );
    final firmId = draft.correspondentName == null
        ? null
        : (await repo.allCorrespondents())
              .where(
                (c) =>
                    c.name.toLowerCase() ==
                    draft.correspondentName!.trim().toLowerCase(),
              )
              .firstOrNull
              ?.id;
    final dupIds = {for (final d in dups) d.doc.id};
    final matches = matchRefs(
      refs,
      firmId,
      await repo.refCandidates(refs),
    ).where((m) => !dupIds.contains(m.documentId)).take(5);
    final related =
        <
          ({
            String id,
            String docNumber,
            String title,
            String reasons,
            bool strong,
          })
        >[];
    for (final m in matches) {
      final d = await repo.getDocument(m.documentId);
      if (d == null) continue;
      related.add((
        id: d.id,
        docNumber: d.docNumber,
        title: d.title,
        reasons: m.reasons.join(', '),
        strong: m.score >= 10,
      ));
    }
    return (
      duplicates: [
        for (final d in dups)
          (docNumber: d.doc.docNumber, title: d.doc.title, reason: d.reason),
      ],
      related: related,
    );
  }

  /// Nach dem Verknüpfen: offene Nachhaken/Einreichen-Aufgaben der
  /// verknüpften Dokumente abhaken?
  Future<void> _afterLink(List<String> linked) async {
    for (final id in linked) {
      if (!mounted) return;
      await offerCompleteTasks(
        context,
        documentId: id,
        actions: {'nachhaken', 'einreichen'},
        question: 'Antwort ist da – Aufgabe beim verknüpften Dokument abhaken?',
      );
    }
  }

  /// Regeln + KI → vorausgefüllter Entwurf.
  Future<DocumentDraft> _prepareDraft(ScanOutcome outcome) async {
    final finance = await FinanceSettings.load();
    final draft = await services.suggestions.buildDraft(
      outcome.ocrText,
      finance: finance,
    );
    await _refineWithAi(draft, outcome.ocrText, outcome.firstPageOcr);
    // Die KI kann Datum/Typ korrigiert haben → Fälligkeit neu berechnen.
    applyPaymentSuggestions(draft, outcome.ocrText, finance: finance);
    // Fristen: Widerspruch (Bescheide) und Garantie.
    final deadlines = await DeadlineSettings.load();
    draft.objectionLeadDays = deadlines.objectionLeadDays;
    draft.objectionDeadline ??= extractObjectionDeadline(
      outcome.ocrText,
      draft.docDate,
      state: deadlines.state,
    );
    draft.taxCategory ??= suggestTaxCategory(outcome.ocrText, draft.docType);
    final warranty = extractWarranty(outcome.ocrText, draft.docDate);
    if (warranty != null && draft.warrantyUntil == null) {
      draft.warrantyUntil = warranty.until;
      draft.warrantyKind = warranty.kind;
    }
    return draft;
  }

  /// Stapel: erst alle auslesen und nach Datum sortiert bestätigen, dann
  /// Nummern lückenlos nach (bestätigtem) Datum vergeben – ältestes zuerst –
  /// und eine Nummernliste zum Beschriften zeigen.
  Future<int> _confirmBatch(List<ScanOutcome> outcomes) async {
    final n = outcomes.length;
    final prepared = <({ScanOutcome outcome, DocumentDraft draft})>[];
    for (var i = 0; i < n; i++) {
      if (!mounted) break;
      _snack('Lese Dokument ${i + 1} von $n …');
      prepared.add((
        outcome: outcomes[i],
        draft: await _prepareDraft(outcomes[i]),
      ));
    }
    final order = sortForNumbering(prepared, (e) => e.draft.docDate);

    final confirmed = <({ScanOutcome outcome, DocumentDraft draft})>[];
    for (var i = 0; i < order.length; i++) {
      final item = order[i];
      if (!mounted) {
        await services.scanner.deletePdf(item.outcome.relativePdfPath);
        continue;
      }
      final analysis = await _analyze(item.outcome, item.draft);
      if (!mounted) continue;
      final result = await Navigator.of(context).push<DocumentDraft>(
        MaterialPageRoute(
          builder: (_) => ConfirmScreen(
            draft: item.draft,
            pdfPath: item.outcome.relativePdfPath,
            duplicates: analysis.duplicates,
            related: analysis.related,
            batchInfo: '${i + 1} von ${order.length}',
            saveLabel: i == order.length - 1 ? 'Fertig' : 'Weiter',
          ),
        ),
      );
      if (result == null) {
        await services.scanner.deletePdf(item.outcome.relativePdfPath);
      } else {
        confirmed.add((outcome: item.outcome, draft: result));
      }
    }
    if (confirmed.isEmpty) return 0;

    // Nummern erst jetzt, nach dem bestätigten Datum.
    final entries = <({Document doc, String sender})>[];
    for (final item in sortForNumbering(confirmed, (e) => e.draft.docDate)) {
      final docNumber = await services.repository.nextDocNumber();
      final pdfPath = await services.scanner.renamePdf(
        item.outcome.relativePdfPath,
        docNumber,
      );
      final doc = await services.repository.createDocument(
        docNumber: docNumber,
        draft: item.draft,
        pdfPath: pdfPath,
        pageCount: item.outcome.pageCount,
        ocrText: item.outcome.ocrText,
        refs: extractRefs(item.outcome.ocrText),
      );
      await services.notifications.syncDocument(doc.id);
      await _afterLink(item.draft.linkDocumentIds);
      entries.add((doc: doc, sender: item.draft.correspondentName ?? ''));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NumberListScreen(
            entries: [
              for (final e in entries)
                (doc: e.doc, sender: e.sender, oldNumber: null),
            ],
          ),
        ),
      );
    }
    return entries.length;
  }

  Future<bool> _confirmAndSave(ScanOutcome outcome) async {
    // Ersterfassung oder weiteres Gerät (Laptop/Tablet): vorläufige Nummer,
    // die endgültige vergibt das Haupt-Handy beim Abgleich.
    final isMain = await SyncSettings.isMain();
    final docNumber = await SetupMode.isOn()
        ? await services.repository.nextProvisionalNumber()
        : !isMain
            ? await services.repository
                .nextProvisionalNumber(tag: await SyncSettings.deviceTag())
            : await services.repository.nextDocNumber();
    final pdfPath = await services.scanner.renamePdf(
      outcome.relativePdfPath,
      docNumber,
    );
    final draft = await _prepareDraft(outcome);

    if (!mounted) {
      // Sollte nach dem Overlay-Fix nicht mehr vorkommen; falls doch,
      // keine verwaiste PDF/Nummer hinterlassen.
      await services.scanner.deletePdf(pdfPath);
      await services.repository.releaseDocNumberIfUnused(docNumber);
      return false;
    }
    final analysis = await _analyze(
      ScanOutcome(
        relativePdfPath: pdfPath,
        pageCount: outcome.pageCount,
        ocrText: outcome.ocrText,
        firstPageOcr: outcome.firstPageOcr,
      ),
      draft,
    );
    if (!mounted) return false;
    final confirmed = await Navigator.of(context).push<DocumentDraft>(
      MaterialPageRoute(
        builder: (_) => ConfirmScreen(
          draft: draft,
          docNumber: docNumber,
          pdfPath: pdfPath,
          duplicates: analysis.duplicates,
          related: analysis.related,
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
    await _afterLink(confirmed.linkDocumentIds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DocumentRepository.isProvisional(docNumber)
                ? '$docNumber gespeichert (vorläufig) – Original auf den '
                      'Ersterfassungs-Stapel'
                : '$docNumber gespeichert – Original vorne in die Box legen',
          ),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Erinnerung',
            onPressed: () => showTaskEditor(context, doc: doc),
          ),
        ),
      );
    }
    return true;
  }

  /// Verfeinert den Regel-Entwurf mit dem lokalen KI-Modell (falls
  /// aktiviert). Zeigt solange einen Hinweis-Dialog; Fehler und Timeouts
  /// fallen still auf die Regel-Vorschläge zurück.
  Future<void> _refineWithAi(
    DocumentDraft draft,
    String fullOcr,
    String firstPageOcr,
  ) async {
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
      final known = await services.suggestions.knownCorrespondentName(fullOcr);
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
            await services.repository.categoryIdForCorrespondentName(
                  draft.correspondentName,
                ) ==
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
            stream: services.repository.watchOpenCaseCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.folder_copy_outlined),
                ),
                tooltip: 'Vorgänge',
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const CasesScreen())),
              );
            },
          ),
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
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const TasksScreen())),
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
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CleanupScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
                .then((_) => setState(() {})), // Ersterfassung an/aus
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
          _setupBanner(),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
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
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
                        doc.title.isEmpty ? doc.docNumber : doc.title,
                      ),
                      subtitle: Text(
                        [
                          doc.docNumber,
                          if (doc.docDate != null)
                            _dateFormat.format(doc.docDate!),
                          if (doc.docType != null) doc.docType!,
                          doc.storageLocation,
                        ].join(' · '),
                      ),
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
