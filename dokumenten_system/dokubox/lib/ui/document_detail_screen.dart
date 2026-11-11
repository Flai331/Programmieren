import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../data/deadline_settings.dart';
import '../data/document_repository.dart';
import '../data/finance.dart';
import '../scan/scan_service.dart';
import 'confirm_screen.dart';
import 'finance_actions.dart';
import 'fill_screen.dart';
import 'pdf_preview.dart';
import '../data/cases.dart';
import 'attachments_section.dart';
import 'cases_screen.dart';
import 'contracts_screen.dart';
import 'girocode_screen.dart';
import 'share_name.dart';
import 'task_widgets.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;

  /// Direkt nach dem Öffnen ausführen (aus der Aufgaben-Übersicht:
  /// „Jetzt ausfüllen/versenden“).
  final TaskQuickAction? initialAction;

  const DocumentDetailScreen(
      {super.key, required this.documentId, this.initialAction});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  Document? _doc;
  List<String> _tags = [];
  List<Claim> _claims = [];
  String? _correspondentName;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      final action = widget.initialAction;
      if (action != null && mounted && _doc != null) _runQuick(action);
    });
  }

  /// „Jetzt …“-Knopf einer Aufgabe.
  Future<void> _runQuick(TaskQuickAction action) async {
    final doc = _doc;
    if (doc == null) return;
    switch (action) {
      case TaskQuickAction.fill:
        await _fill();
      case TaskQuickAction.share:
        await _sharePdf(filled: doc.filledPdfPath != null);
      case TaskQuickAction.paid:
        await markPaid(context, doc);
        if (!mounted) return;
        await offerCompleteTasks(context,
            documentId: doc.id,
            actions: {'bezahlen'},
            question: 'Aufgabe „Bezahlen“ abhaken?');
        await _load();
    }
  }

  Future<void> _editContract() async {
    final doc = _doc!;
    final existing = await services.repository.contractForDocument(doc.id);
    if (!mounted) return;
    await editContract(context, contract: existing, doc: doc);
  }

  Future<void> _addTask({String? action}) async {
    final doc = _doc;
    if (doc == null) return;
    await showTaskEditor(context, doc: doc, presetAction: action);
  }

  Widget _casesSection(Document doc) {
    return StreamBuilder<List<Case>>(
      stream: services.repository.watchCasesForDocument(doc.id),
      builder: (context, snap) {
        final cases = snap.data ?? const <Case>[];
        return Card(
          child: Column(children: [
            for (final c in cases)
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: Text(c.title),
                subtitle: Text('Vorgang · ${kCaseStatus[c.status] ?? c.status}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CaseDetailScreen(caseId: c.id))),
              ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(cases.isEmpty
                  ? 'Zu Vorgang hinzufügen'
                  : 'Weiterem Vorgang hinzufügen'),
              onTap: () => addDocumentToCase(context, doc),
            ),
          ]),
        );
      },
    );
  }

  Widget _tasksSection(Document doc, ThemeData theme) {
    return StreamBuilder<List<DocTask>>(
      stream: services.repository.watchTasksForDocument(doc.id),
      builder: (context, snap) {
        final tasks = snap.data ?? const <DocTask>[];
        final open = tasks.where((t) => t.doneAt == null).toList();
        final done = tasks.where((t) => t.doneAt != null).toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.alarm, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Aufgaben & Erinnerungen',
                            style: theme.textTheme.titleSmall),
                      ),
                      TextButton.icon(
                        onPressed: _addTask,
                        icon: const Icon(Icons.alarm_add),
                        label: const Text('Neu'),
                      ),
                    ],
                  ),
                ),
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('Noch nichts geplant – z. B. „Versenden bis '
                        'Freitag“ oder „Jährlich Vertrag prüfen“.'),
                  ),
                for (final t in [...open, ...done.take(3)])
                  TaskTile(
                    task: t,
                    onQuickAction: _runQuick,
                    onEdit: () => showTaskEditor(context, doc: doc, task: t),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _load() async {
    final doc = await services.repository.getDocument(widget.documentId);
    if (doc == null) return;
    final tags =
        await services.repository.tagNamesForDocument(widget.documentId);
    final claims =
        await services.repository.claimsForDocument(widget.documentId);
    String? correspondentName;
    if (doc.correspondentId != null) {
      correspondentName = (await services.repository
              .getCorrespondent(doc.correspondentId!))
          ?.name;
    }
    if (mounted) {
      setState(() {
        _doc = doc;
        _tags = tags;
        _claims = claims;
        _correspondentName = correspondentName;
      });
    }
  }

  /// Original in der App zeigen (zoombar, alle Seiten) — klappt auch ohne
  /// installierte PDF-App. Extern öffnen geht weiter über „PDF teilen“.
  Future<void> _openPdf() async {
    final path = await ScanService.absolutePdfPath(_doc!.pdfPath);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfViewerScreen(path: path, title: _doc!.docNumber),
    ));
  }

  Future<void> _openExternal() async {
    final path = await ScanService.absolutePdfPath(_doc!.pdfPath);
    await OpenFilex.open(path);
  }

  /// Teilen mit frei wählbarem Dateinamen (wird pro Dokument gemerkt).
  /// Die Datei in der App behält ihren Namen.
  Future<void> _sharePdf({bool filled = false}) async {
    final doc = _doc!;
    final relative = filled ? doc.filledPdfPath! : doc.pdfPath;
    final path = await ScanService.absolutePdfPath(relative);
    if (!mounted) return;
    final copy = await askShareCopy(
      context,
      sourcePath: path,
      rememberKey: '${doc.id}_${filled ? 'filled' : 'original'}',
      suggestion: suggestedShareName(doc.docNumber, doc.title, filled: filled),
    );
    if (copy == null) return;
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile(copy, mimeType: 'application/pdf')],
      subject: copy.split(Platform.pathSeparator).last.replaceAll('.pdf', ''),
    ));
    if (result.status == ShareResultStatus.dismissed || !mounted) return;
    await offerCompleteTasks(context,
        documentId: doc.id,
        actions: {'versenden'},
        question: 'Versendet – Aufgabe abhaken?');
  }

  /// Formular ausfüllen (Text, Haken, Kreuz, Datum, Unterschrift). Das
  /// Original bleibt, gespeichert wird eine ausgefüllte Kopie.
  Future<void> _fill() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FillScreen(document: _doc!)),
    );
    await _load();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            const Text('Ausgefüllte Kopie gespeichert – Original unverändert'),
        action: SnackBarAction(
          label: 'Versenden-Erinnerung',
          onPressed: () => _addTask(action: 'versenden'),
        ),
      ));
      await offerCompleteTasks(context,
          documentId: _doc!.id,
          actions: {'ausfuellen', 'unterschreiben'},
          question: 'Ausgefüllt – Aufgabe abhaken?');
    }
  }

  Future<void> _discardFill() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ausgefüllte Kopie löschen?'),
        content: const Text(
            'Die Eintragungen gehen verloren. Das Original bleibt erhalten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await services.fill.discard(_doc!);
    await _load();
  }

  Widget _filledSection(Document doc, ThemeData theme) {
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_document),
                const SizedBox(width: 8),
                Text('Ausgefüllte Version', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            OriginalPreview(
              relativePdfPath: doc.filledPdfPath!,
              title: '${doc.docNumber} ausgefüllt',
              height: 200,
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _sharePdf(filled: true),
                  icon: const Icon(Icons.share),
                  label: const Text('Teilen'),
                ),
                OutlinedButton.icon(
                  onPressed: _fill,
                  icon: const Icon(Icons.edit),
                  label: const Text('Weiter ausfüllen'),
                ),
                TextButton.icon(
                  onPressed: _discardFill,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Löschen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit() async {
    final doc = _doc!;
    final leadDays = (await DeadlineSettings.load()).objectionLeadDays;
    final draft = DocumentDraft(
      title: doc.title,
      docDate: doc.docDate,
      correspondentName: _correspondentName,
      docType: doc.docType,
      tagNames: List.of(_tags),
      storageLocation: doc.storageLocation,
      retentionUntil: doc.retentionUntil,
      reminderAt: doc.reminderAt,
      reminderNote: doc.reminderNote,
      amountCents: doc.amountCents,
      dueDate: doc.dueDate,
      paymentStatus: doc.paymentStatus,
      paidAt: doc.paidAt,
      paymentReminderAt: doc.paymentReminderAt,
      claims: [for (final c in _claims) ClaimDraft.fromClaim(c)],
      objectionDeadline: doc.objectionDeadline,
      warrantyUntil: doc.warrantyUntil,
      warrantyKind: doc.warrantyKind,
      objectionLeadDays: leadDays,
    );
    if (!mounted) return;
    final result = await Navigator.of(context).push<DocumentDraft>(
      MaterialPageRoute(
        builder: (_) => ConfirmScreen(draft: draft, pdfPath: doc.pdfPath),
      ),
    );
    if (result == null) return;
    await services.repository.updateDocument(doc.id, result);
    await services.notifications.syncDocument(doc.id);
    await _load();
  }

  Future<void> _markDestroyed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Original vernichtet?'),
        content: const Text(
            'Der Scan bleibt erhalten, nur der Lagerort wird auf '
            '„vernichtet" gesetzt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ja, vernichtet'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await services.repository.markDestroyed(_doc!.id);
      await _load();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dokument löschen?'),
        content: const Text(
            'Der Eintrag wird aus der Liste entfernt. Die Nummer auf dem '
            'Original wird dadurch ungültig.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await services.notifications.cancelFor(_doc!.id);
      await services.repository.softDeleteDocument(_doc!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _financeCard(Document doc, ThemeData theme) {
    final open = doc.paymentStatus == PaymentStatus.open ||
        doc.paymentStatus == PaymentStatus.directDebit;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOverdue(doc) ? Icons.warning_amber : Icons.receipt_long,
                  color: isOverdue(doc)
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    [
                      doc.paymentStatus ?? 'Rechnung',
                      if (doc.amountCents != null)
                        formatEuro(doc.amountCents!),
                    ].join(' · '),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (open)
                  FilledButton.tonal(
                    onPressed: () async {
                      await markPaid(context, doc);
                      await _load();
                    },
                    child: const Text('Bezahlt'),
                  ),
              ],
            ),
            if (doc.dueDate != null && open)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 36),
                child: Text(
                  '${_dateFormat.format(doc.dueDate!)} · ${dueLabel(doc.dueDate!)}',
                  style: isOverdue(doc)
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
              ),
            if (doc.paymentReminderAt != null &&
                doc.paymentStatus == PaymentStatus.open)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 36),
                child: Text(
                    'Erinnerung am ${_dateFormat.format(doc.paymentReminderAt!)}',
                    style: theme.textTheme.bodySmall),
              ),
            if (doc.paidAt != null && doc.paymentStatus == PaymentStatus.paid)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 36),
                child: Text('bezahlt am ${_dateFormat.format(doc.paidAt!)}'),
              ),
            for (final claim in _claims) ...[
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.local_hospital_outlined, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(claim.target),
                        Text(
                          [
                            claim.status,
                            if (claim.submittedAt != null)
                              'eingereicht ${_dateFormat.format(claim.submittedAt!)}',
                            if (claim.reimbursedCents != null)
                              '${formatEuro(claim.reimbursedCents!)} erhalten',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (nextClaimStatus(claim.status) case final next?)
                    TextButton(
                      onPressed: () async {
                        await advanceClaim(context, claim, next);
                        await _load();
                      },
                      child: Text(claimActionLabel(claim.status)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    if (doc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(doc.docNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.draw),
            tooltip: 'Ausfüllen / unterschreiben',
            onPressed: _fill,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Bearbeiten',
            onPressed: _edit,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _sharePdf();
                case 'external':
                  _openExternal();
                case 'contract':
                  _editContract();
                case 'girocode':
                  openGiroCode(context, _doc!);
                case 'destroyed':
                  _markDestroyed();
                case 'delete':
                  _delete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'share', child: Text('PDF teilen')),
              const PopupMenuItem(
                  value: 'external', child: Text('In anderer App öffnen')),
              const PopupMenuItem(
                  value: 'contract', child: Text('Als Vertrag erfassen')),
              const PopupMenuItem(
                  value: 'girocode', child: Text('Überweisen (GiroCode)')),
              const PopupMenuItem(
                  value: 'destroyed',
                  child: Text('Original als vernichtet markieren')),
              const PopupMenuItem(value: 'delete', child: Text('Löschen')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPdf,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('PDF öffnen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(doc.title.isEmpty ? '(ohne Titel)' : doc.title,
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          OriginalPreview(
            relativePdfPath: doc.pdfPath,
            title: doc.docNumber,
            height: 200,
          ),
          const SizedBox(height: 8),
          if (doc.filledPdfPath == null)
            OutlinedButton.icon(
              onPressed: _fill,
              icon: const Icon(Icons.draw),
              label: const Text('Ausfüllen / unterschreiben'),
            )
          else
            _filledSection(doc, theme),
          const SizedBox(height: 8),
          _casesSection(doc),
          _tasksSection(doc, theme),
          AttachmentsSection(doc: doc),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Original liegt in',
                            style: theme.textTheme.bodySmall),
                        Text(doc.storageLocation,
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                  Text(doc.docNumber, style: theme.textTheme.titleLarge),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow('Datum',
              doc.docDate == null ? '—' : _dateFormat.format(doc.docDate!)),
          _InfoRow('Absender', _correspondentName ?? '—'),
          _InfoRow('Typ', doc.docType ?? '—'),
          _InfoRow('Seiten', '${doc.pageCount}'),
          _InfoRow('Gescannt am', _dateFormat.format(doc.scannedAt)),
          _InfoRow(
              'Aufbewahren bis',
              doc.retentionUntil == null
                  ? 'dauerhaft'
                  : _dateFormat.format(doc.retentionUntil!)),
          if (doc.reminderAt != null)
            _InfoRow('Erinnerung',
                '${_dateFormat.format(doc.reminderAt!)} ${doc.reminderNote ?? ''}'),
          if (doc.paymentStatus != null || _claims.isNotEmpty)
            _financeCard(doc, theme),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [for (final tag in _tags) Chip(label: Text(tag))],
            ),
          ],
          if (doc.ocrText.trim().isNotEmpty) ...[
            const Divider(height: 32),
            Text('Erkannter Text', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              doc.ocrText,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
