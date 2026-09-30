import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/doc_types.dart';
import '../data/document_repository.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// Bestätigen-Screen: zeigt die vergebene Nummer groß an („aufs Original
/// schreiben") und die automatisch vorausgefüllten Metadaten zur Kontrolle.
/// Wird auch zum Bearbeiten bestehender Dokumente genutzt ([docNumber] ist
/// dann null und der Nummern-Banner entfällt).
class ConfirmScreen extends StatefulWidget {
  final DocumentDraft draft;

  /// Nur beim Neuanlegen gesetzt.
  final String? docNumber;
  final String saveLabel;

  const ConfirmScreen({
    super.key,
    required this.draft,
    this.docNumber,
    this.saveLabel = 'Speichern',
  });

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late final TextEditingController _title;
  late final TextEditingController _correspondent;
  late final TextEditingController _tagInput;
  late final TextEditingController _reminderNote;
  late DocumentDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _title = TextEditingController(text: _draft.title);
    _correspondent =
        TextEditingController(text: _draft.correspondentName ?? '');
    _tagInput = TextEditingController();
    _reminderNote = TextEditingController(text: _draft.reminderNote ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _correspondent.dispose();
    _tagInput.dispose();
    _reminderNote.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(1990),
        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      );

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    if (!_draft.tagNames.any((t) => t.toLowerCase() == tag.toLowerCase())) {
      setState(() => _draft.tagNames.add(tag));
    }
    _tagInput.clear();
  }

  void _save() {
    _draft
      ..title = _title.text
      ..correspondentName =
          _correspondent.text.trim().isEmpty ? null : _correspondent.text
      ..reminderNote =
          _reminderNote.text.trim().isEmpty ? null : _reminderNote.text;
    Navigator.of(context).pop(_draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = DateTime.now().year;
    final locations = {
      ..._locationChoices(year),
      _draft.storageLocation,
    }.where((l) => l.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docNumber == null
            ? 'Dokument bearbeiten'
            : 'Kontrollieren & speichern'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.docNumber != null) ...[
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Diese Nummer aufs Original schreiben:',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(
                      widget.docNumber!,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('… und vorne in die Box legen. Nicht sortieren!',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Titel',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _DateRow(
            label: 'Dokumentdatum',
            value: _draft.docDate,
            onTap: () async {
              final picked = await _pickDate(_draft.docDate);
              if (picked != null) setState(() => _draft.docDate = picked);
            },
            onClear: () => setState(() => _draft.docDate = null),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _correspondent,
            decoration: const InputDecoration(
              labelText: 'Absender (z. B. HUK-COBURG)',
              helperText: 'Wird beim nächsten Scan automatisch wiedererkannt',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue:
                kDocTypes.contains(_draft.docType) ? _draft.docType : null,
            decoration: const InputDecoration(
              labelText: 'Dokumenttyp',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final type in kDocTypes)
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: (value) => setState(() {
              _draft.docType = value;
              _draft.retentionUntil = suggestedRetentionUntil(
                  value, _draft.docDate ?? DateTime.now());
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _draft.storageLocation.isEmpty
                ? null
                : _draft.storageLocation,
            decoration: const InputDecoration(
              labelText: 'Lagerort des Originals',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final location in locations)
                DropdownMenuItem(value: location, child: Text(location)),
            ],
            onChanged: (value) =>
                setState(() => _draft.storageLocation = value ?? ''),
          ),
          const SizedBox(height: 16),
          Text('Tags', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in _draft.tagNames)
                InputChip(
                  label: Text(tag),
                  onDeleted: () =>
                      setState(() => _draft.tagNames.remove(tag)),
                ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _tagInput,
                  decoration: const InputDecoration(
                    hintText: 'Tag hinzufügen…',
                    isDense: true,
                  ),
                  onSubmitted: _addTag,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _DateRow(
            label: 'Aufbewahren bis (Ausmistliste)',
            value: _draft.retentionUntil,
            onTap: () async {
              final picked = await _pickDate(_draft.retentionUntil);
              if (picked != null) {
                setState(() => _draft.retentionUntil = picked);
              }
            },
            onClear: () => setState(() => _draft.retentionUntil = null),
            emptyLabel: 'dauerhaft aufbewahren',
          ),
          const SizedBox(height: 12),
          _DateRow(
            label: 'Erinnerung (z. B. Kündigungsfrist)',
            value: _draft.reminderAt,
            onTap: () async {
              final picked = await _pickDate(_draft.reminderAt);
              if (picked != null) {
                setState(() =>
                    _draft.reminderAt = DateTime(picked.year, picked.month,
                        picked.day, 9));
              }
            },
            onClear: () => setState(() => _draft.reminderAt = null),
            emptyLabel: 'keine',
          ),
          if (_draft.reminderAt != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _reminderNote,
              decoration: const InputDecoration(
                labelText: 'Erinnerungs-Notiz',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(widget.saveLabel),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  List<String> _locationChoices(int year) => [
        StorageLocations.boxForYear(year),
        StorageLocations.boxForYear(year - 1),
        StorageLocations.mappe,
        StorageLocations.digital,
      ];
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String emptyLabel;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
    this.emptyLabel = 'nicht gesetzt',
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(value == null
                  ? emptyLabel
                  : _dateFormat.format(value!)),
            ),
          ),
          if (value != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: onClear,
              tooltip: 'Entfernen',
            ),
          IconButton(
            icon: const Icon(Icons.edit_calendar, size: 18),
            onPressed: onTap,
            tooltip: 'Datum wählen',
          ),
        ],
      ),
    );
  }
}
