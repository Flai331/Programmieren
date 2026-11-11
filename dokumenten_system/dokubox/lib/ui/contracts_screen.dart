import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../data/contracts.dart';
import '../data/database.dart';
import '../data/document_repository.dart';
import '../data/finance.dart';
import 'document_detail_screen.dart';

final _date = DateFormat('dd.MM.yyyy');

/// Verträge: Kosten pro Monat/Jahr nach Kategorie, nächste Kündigungsfrist.
class ContractsTab extends StatelessWidget {
  const ContractsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return StreamBuilder<List<Category>>(
      stream: services.repository.watchCategories(),
      builder: (context, catSnap) {
        final cats = {for (final c in catSnap.data ?? const <Category>[]) c.id: c.name};
        return StreamBuilder<List<({Contract c, String firm, String? categoryId})>>(
          stream: services.repository.watchContracts(),
          builder: (context, snap) {
            final list = snap.data;
            if (list == null) return const Center(child: CircularProgressIndicator());
            if (list.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Noch keine Verträge.\nIm Dokument (z. B. Police, Vertrag) '
                    '⋮ → „Als Vertrag erfassen“.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final active = list.where((e) => e.c.cancelledAt == null).toList();
            final byCat = <String, int>{};
            for (final e in active) {
              final k = cats[e.categoryId] ?? 'ohne Kategorie';
              byCat[k] = (byCat[k] ?? 0) + monthlyCents(e.c.amountCents, e.c.interval);
            }
            final total = byCat.values.fold(0, (a, b) => a + b);
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${formatEuro(total)} pro Monat · '
                            '${formatEuro(total * 12)} pro Jahr',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        for (final e in byCat.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                          Text('${e.key}: ${formatEuro(e.value)}/Monat'),
                      ],
                    ),
                  ),
                ),
                for (final e in list)
                  Builder(builder: (context) {
                    final c = e.c;
                    final end = nextTermEnd(
                        minTermUntil: c.minTermUntil,
                        renewMonths: c.autoRenewMonths,
                        now: now);
                    final last = c.cancelledAt != null
                        ? null
                        : lastCancelDay(
                            termEnd: end,
                            noticeValue: c.noticeValue,
                            noticeUnit: c.noticeUnit,
                            noticeToEndOf: c.noticeToEndOf,
                            now: now);
                    final soon = last != null &&
                        last.difference(now).inDays <= 30 &&
                        !last.isBefore(now);
                    return ListTile(
                      leading: Icon(c.cancelledAt != null
                          ? Icons.block
                          : Icons.description_outlined),
                      title: Text(c.title),
                      subtitle: Text([
                        if (e.firm.isNotEmpty) e.firm,
                        if (c.amountCents != null)
                          '${formatEuro(c.amountCents!)} ${kContractIntervals[c.interval]}',
                        if (c.cancelledAt != null)
                          'gekündigt'
                        else if (last != null)
                          (last.isBefore(now)
                              ? 'Kündigungsfrist verpasst (bis ${_date.format(last)})'
                              : 'kündbar bis ${_date.format(last)}'),
                      ].join(' · ')),
                      trailing: soon
                          ? Icon(Icons.warning_amber, color: theme.colorScheme.error)
                          : null,
                      onTap: () => c.documentId == null
                          ? editContract(context, contract: c)
                          : Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  DocumentDetailScreen(documentId: c.documentId!))),
                      onLongPress: () => editContract(context, contract: c),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }
}

/// Vertrag anlegen/bearbeiten.
Future<void> editContract(BuildContext context,
    {Contract? contract, Document? doc}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ContractEditor(contract: contract, doc: doc),
  );
}

class _ContractEditor extends StatefulWidget {
  final Contract? contract;
  final Document? doc;
  const _ContractEditor({this.contract, this.doc});
  @override
  State<_ContractEditor> createState() => _ContractEditorState();
}

class _ContractEditorState extends State<_ContractEditor> {
  late final _title = TextEditingController(
      text: widget.contract?.title ?? widget.doc?.title ?? '');
  late final _amount = TextEditingController(
      text: () {
        final c = widget.contract?.amountCents ?? widget.doc?.amountCents;
        return c == null ? '' : formatEuro(c).replaceAll(RegExp(r'\s?€'), '');
      }());
  late String _interval = widget.contract?.interval ?? 'monatlich';
  late DateTime? _minTerm = widget.contract?.minTermUntil;
  late int? _renew = widget.contract?.autoRenewMonths ?? 12;
  late int _noticeValue = widget.contract?.noticeValue ?? 3;
  late String _noticeUnit = widget.contract?.noticeUnit ?? 'monate';
  late String _toEnd = widget.contract?.noticeToEndOf ?? 'laufzeitende';
  late bool _cancelled = widget.contract?.cancelledAt != null;

  Future<void> _save() async {
    final data = ContractsCompanion(
      title: Value(_title.text.trim().isEmpty ? 'Vertrag' : _title.text.trim()),
      documentId: Value(widget.contract?.documentId ?? widget.doc?.id),
      correspondentId:
          Value(widget.contract?.correspondentId ?? widget.doc?.correspondentId),
      amountCents: Value(parseEuro(_amount.text)),
      interval: Value(_interval),
      minTermUntil: Value(_minTerm),
      autoRenewMonths: Value(_renew),
      noticeValue: Value(_noticeValue),
      noticeUnit: Value(_noticeUnit),
      noticeToEndOf: Value(_toEnd),
      cancelledAt: Value(_cancelled
          ? (widget.contract?.cancelledAt ?? DateTime.now())
          : null),
    );
    final c = await services.repository.saveContract(data, id: widget.contract?.id);
    if (c.documentId != null) {
      await services.notifications.syncDocument(c.documentId!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vertrag', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Bezeichnung')),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Beitrag (€)')),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _interval,
                onChanged: (v) => setState(() => _interval = v!),
                items: [
                  for (final e in kContractIntervals.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
              ),
            ]),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mindestlaufzeit bis'),
              subtitle: Text(_minTerm == null ? 'keine' : _date.format(_minTerm!)),
              onTap: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _minTerm ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100));
                if (d != null) setState(() => _minTerm = d);
              },
            ),
            Row(children: [
              const Text('Verlängert sich um '),
              DropdownButton<int>(
                value: _renew ?? 0,
                onChanged: (v) => setState(() => _renew = v),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('1 Monat (monatl. kündbar)')),
                  DropdownMenuItem(value: 12, child: Text('12 Monate')),
                  DropdownMenuItem(value: 24, child: Text('24 Monate')),
                ],
              ),
            ]),
            Row(children: [
              const Text('Kündigungsfrist '),
              DropdownButton<int>(
                value: _noticeValue,
                onChanged: (v) => setState(() => _noticeValue = v!),
                items: [
                  for (final n in const [1, 2, 3, 4, 6, 12])
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
              ),
              const SizedBox(width: 6),
              DropdownButton<String>(
                value: _noticeUnit,
                onChanged: (v) => setState(() => _noticeUnit = v!),
                items: const [
                  DropdownMenuItem(value: 'tage', child: Text('Tage')),
                  DropdownMenuItem(value: 'wochen', child: Text('Wochen')),
                  DropdownMenuItem(value: 'monate', child: Text('Monate')),
                ],
              ),
            ]),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'laufzeitende', label: Text('zum Laufzeitende')),
                ButtonSegment(value: 'monatsende', label: Text('zum Monatsende')),
              ],
              selected: {_toEnd},
              onSelectionChanged: (v) => setState(() => _toEnd = v.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gekündigt'),
              value: _cancelled,
              onChanged: (v) => setState(() => _cancelled = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              if (widget.contract != null)
                TextButton(
                  onPressed: () async {
                    await services.repository.deleteContract(widget.contract!.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Löschen'),
                ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('Speichern')),
            ]),
            Text('Erinnerung kommt 14 Tage vor dem letzten Kündigungstag.',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Erstattungs-Statistik pro Jahr.
class ClaimStatsTab extends StatefulWidget {
  const ClaimStatsTab({super.key});
  @override
  State<ClaimStatsTab> createState() => _ClaimStatsTabState();
}

class _ClaimStatsTabState extends State<ClaimStatsTab> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
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
        ]),
        FutureBuilder<List<ClaimStats>>(
          future: services.repository.claimStats(_year),
          builder: (context, snap) {
            final list = snap.data;
            if (list == null) return const LinearProgressIndicator();
            if (list.isEmpty) return const Text('Keine Einreichungen in diesem Jahr.');
            return Column(children: [
              for (final s in list)
                Card(
                  child: ListTile(
                    title: Text(s.target),
                    subtitle: Text(
                        '${s.count} eingereicht · ${formatEuro(s.amountCents)}\n'
                        'erstattet ${formatEuro(s.reimbursedCents)}'
                        '${s.amountCents - s.openCents > 0 ? ' (${(s.quota * 100).round()} %)' : ''}'
                        ' · offen ${s.open} (${formatEuro(s.openCents)})'
                        '${s.rejected > 0 ? ' · abgelehnt ${s.rejected}' : ''}'),
                    isThreeLine: true,
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }
}
