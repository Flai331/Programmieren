import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../data/document_repository.dart';
import '../scan/scan_service.dart';
import 'confirm_screen.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  Document? _doc;
  List<String> _tags = [];
  String? _correspondentName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await services.repository.getDocument(widget.documentId);
    if (doc == null) return;
    final tags =
        await services.repository.tagNamesForDocument(widget.documentId);
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
        _correspondentName = correspondentName;
      });
    }
  }

  Future<void> _openPdf() async {
    final path = await ScanService.absolutePdfPath(_doc!.pdfPath);
    await OpenFilex.open(path);
  }

  Future<void> _sharePdf() async {
    final path = await ScanService.absolutePdfPath(_doc!.pdfPath);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(path)],
      subject: '${_doc!.docNumber} ${_doc!.title}',
    ));
  }

  Future<void> _edit() async {
    final doc = _doc!;
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
    );
    final result = await Navigator.of(context).push<DocumentDraft>(
      MaterialPageRoute(builder: (_) => ConfirmScreen(draft: draft)),
    );
    if (result == null) return;
    await services.repository.updateDocument(doc.id, result);
    final updated = await services.repository.getDocument(doc.id);
    if (updated != null) {
      await services.notifications.cancelFor(doc.id);
      await services.notifications.scheduleFor(updated);
    }
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
            icon: const Icon(Icons.edit),
            tooltip: 'Bearbeiten',
            onPressed: _edit,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _sharePdf();
                case 'destroyed':
                  _markDestroyed();
                case 'delete':
                  _delete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'share', child: Text('PDF teilen')),
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
