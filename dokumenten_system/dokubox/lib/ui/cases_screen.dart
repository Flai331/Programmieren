import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../data/cases.dart';
import '../data/database.dart';
import 'document_detail_screen.dart';

final _date = DateFormat('dd.MM.yyyy');

/// Alle Vorgänge (Mappen), offene zuerst.
class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vorgänge')),
      body: StreamBuilder<List<({Case c, int docs})>>(
        stream: services.repository.watchCases(),
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Noch keine Vorgänge.\nSie entstehen, wenn ein neues Dokument '
                  'zu einem alten passt (gleiches Aktenzeichen …), oder im '
                  'Dokument unter „Vorgang“.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(children: [
            for (final e in list)
              ListTile(
                leading: Icon(e.c.status == 'erledigt'
                    ? Icons.folder_off_outlined
                    : Icons.folder_open),
                title: Text(e.c.title),
                subtitle: Text('${kCaseStatus[e.c.status] ?? e.c.status} · '
                    '${e.docs} Dokument${e.docs == 1 ? '' : 'e'}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CaseDetailScreen(caseId: e.c.id))),
              ),
          ]);
        },
      ),
    );
  }
}

/// Ein Vorgang: Dokumente zeitlich mit Rolle, Status.
class CaseDetailScreen extends StatelessWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});

  Future<void> _rename(BuildContext context, Case c) async {
    final controller = TextEditingController(text: c.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vorgang umbenennen'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('OK')),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty) {
      await services.repository.renameCase(c.id, title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = services.repository;
    return StreamBuilder<Case?>(
      stream: repo.watchCase(caseId),
      builder: (context, snap) {
        final c = snap.data;
        if (c == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(c.title),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'rename') await _rename(context, c);
                  if (v == 'delete') {
                    await repo.deleteCase(c.id);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text('Vorgang auflösen (Dokumente bleiben)')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final e in kCaseStatus.entries)
                    ButtonSegment(value: e.key, label: Text(e.value)),
                ],
                selected: {c.status},
                onSelectionChanged: (v) => repo.setCaseStatus(c.id, v.first),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<({Document doc, String role})>>(
                stream: repo.watchCaseDocuments(c.id),
                builder: (context, s2) {
                  final docs = s2.data ?? const [];
                  return Column(children: [
                    for (final d in docs)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                                d.doc.docNumber.substring(
                                    d.doc.docNumber.length - 4),
                                style: const TextStyle(fontSize: 11)),
                          ),
                          title: Text(d.doc.title.isEmpty
                              ? d.doc.docNumber
                              : d.doc.title),
                          subtitle: Text([
                            kCaseRoles[d.role] ?? d.role,
                            if (d.doc.docDate != null) _date.format(d.doc.docDate!),
                            if (d.doc.objectionDeadline != null)
                              'Widerspruch bis ${_date.format(d.doc.objectionDeadline!)}',
                          ].join(' · ')),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => DocumentDetailScreen(
                                      documentId: d.doc.id))),
                          trailing: IconButton(
                            tooltip: 'Aus Vorgang entfernen',
                            icon: const Icon(Icons.link_off),
                            onPressed: () =>
                                repo.removeFromCase(c.id, d.doc.id),
                          ),
                        ),
                      ),
                  ]);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dokument einem Vorgang hinzufügen (bestehend oder neu).
Future<void> addDocumentToCase(BuildContext context, Document doc) async {
  final repo = services.repository;
  final cases = await repo.watchCases().first;
  if (!context.mounted) return;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        ListTile(
          leading: const Icon(Icons.create_new_folder_outlined),
          title: const Text('Neuer Vorgang'),
          onTap: () => Navigator.pop(ctx, ''),
        ),
        for (final e in cases.where((e) => e.c.status != 'erledigt'))
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(e.c.title),
            subtitle: Text('${e.docs} Dokumente'),
            onTap: () => Navigator.pop(ctx, e.c.id),
          ),
      ]),
    ),
  );
  if (choice == null) return;
  var caseId = choice;
  if (caseId.isEmpty) {
    final firm = doc.correspondentId == null
        ? null
        : await repo.getCorrespondent(doc.correspondentId!);
    caseId = (await repo.createCase(
            [firm?.name, doc.title].whereType<String>().where((s) => s.isNotEmpty).join(' – '),
            correspondentId: doc.correspondentId))
        .id;
  }
  await repo.addToCase(caseId, doc.id, role: guessCaseRole(doc.docType));
}
