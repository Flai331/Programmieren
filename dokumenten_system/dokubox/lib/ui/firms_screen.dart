import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/database.dart';

/// Firmen (Absender) und ihre Kategorien verwalten. Über die Kategorie lässt
/// sich die Dokumentenliste filtern (Chip „Kategorie“ auf dem Startbildschirm).
class FirmsScreen extends StatelessWidget {
  const FirmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Firmen & Kategorien'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Firmen'), Tab(text: 'Kategorien')],
          ),
        ),
        body: const TabBarView(children: [_FirmsTab(), _CategoriesTab()]),
      ),
    );
  }
}

// ------------------------------------------------------------------ Firmen

class _FirmsTab extends StatelessWidget {
  const _FirmsTab();

  @override
  Widget build(BuildContext context) {
    final repo = services.repository;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-firm',
        onPressed: () => _editFirm(context, null),
        icon: const Icon(Icons.add_business),
        label: const Text('Firma'),
      ),
      body: StreamBuilder<List<Category>>(
        stream: repo.watchCategories(),
        builder: (context, catSnap) {
          final categories = catSnap.data ?? const <Category>[];
          final catNames = {for (final c in categories) c.id: c.name};
          return StreamBuilder<Map<String, int>>(
            stream: repo.watchDocumentCountsByCorrespondent(),
            builder: (context, countSnap) {
              final counts = countSnap.data ?? const <String, int>{};
              return StreamBuilder<List<Correspondent>>(
                stream: repo.watchCorrespondents(),
                builder: (context, snap) {
                  final firms = snap.data;
                  if (firms == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (firms.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Noch keine Firmen. Sie entstehen automatisch beim '
                          'Speichern eines Dokuments – oder lege sie hier an.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: firms.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final f = firms[i];
                      final n = counts[f.id] ?? 0;
                      return ListTile(
                        leading: const Icon(Icons.business),
                        title: Text(f.name),
                        subtitle: Text([
                          catNames[f.categoryId] ?? 'ohne Kategorie',
                          '$n Dokument${n == 1 ? '' : 'e'}',
                        ].join(' · ')),
                        onTap: () => _editFirm(context, f),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editFirm(BuildContext context, Correspondent? firm) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _FirmDialog(firm: firm),
    );
  }
}

class _FirmDialog extends StatefulWidget {
  final Correspondent? firm;
  const _FirmDialog({this.firm});

  @override
  State<_FirmDialog> createState() => _FirmDialogState();
}

class _FirmDialogState extends State<_FirmDialog> {
  late final TextEditingController _name;
  late final TextEditingController _aliases;
  String? _categoryId;
  List<Category> _categories = const [];

  @override
  void initState() {
    super.initState();
    final f = widget.firm;
    _name = TextEditingController(text: f?.name ?? '');
    // Der Name selbst zählt immer als Stichwort → nicht doppelt zeigen.
    _aliases = TextEditingController(
      text: f == null
          ? ''
          : f.aliases
                .split('\n')
                .where(
                  (a) =>
                      a.trim().isNotEmpty &&
                      a.trim().toLowerCase() != f.name.toLowerCase(),
                )
                .join('\n'),
    );
    _categoryId = f?.categoryId;
    services.repository.allCategories().then((value) {
      if (mounted) setState(() => _categories = value);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _aliases.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    try {
      await services.repository.saveCorrespondent(
        id: widget.firm?.id,
        name: _name.text,
        aliases: _aliases.text,
        categoryId: _categoryId,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eine Firma „${_name.text.trim()}“ gibt es schon.'),
          ),
        );
      }
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Firma entfernen?'),
        content: const Text(
          'Die Dokumente bleiben erhalten und behalten den Absender. Wird die '
          'Firma erneut erkannt, wird sie wieder angelegt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await services.repository.deleteCorrespondent(widget.firm!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.firm == null;
    return AlertDialog(
      title: Text(isNew ? 'Neue Firma' : 'Firma bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: isNew,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name (z. B. Union Investment)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('firm-cat-${_categories.length}'),
              initialValue: _categories.any((c) => c.id == _categoryId)
                  ? _categoryId
                  : null,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('– keine –'),
                ),
                for (final c in _categories)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliases,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Weitere Erkennungs-Stichwörter',
                helperText:
                    'Eins pro Zeile, z. B. „UnionDepot“. Steht eins davon '
                    'im Dokument, wird diese Firma vorgeschlagen.',
                helperMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!isNew)
          TextButton(onPressed: _delete, child: const Text('Entfernen')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}

// -------------------------------------------------------------- Kategorien

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    final repo = services.repository;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-category',
        onPressed: () async {
          final name = await _askName(context, 'Neue Kategorie', '');
          if (name != null) await repo.createCategory(name);
        },
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Kategorie'),
      ),
      body: StreamBuilder<List<Correspondent>>(
        stream: repo.watchCorrespondents(),
        builder: (context, firmSnap) {
          final firms = firmSnap.data ?? const <Correspondent>[];
          return StreamBuilder<List<Category>>(
            stream: repo.watchCategories(),
            builder: (context, snap) {
              final cats = snap.data;
              if (cats == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: cats.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = cats[i];
                  final members = firms
                      .where((f) => f.categoryId == c.id)
                      .map((f) => f.name)
                      .toList();
                  return ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(c.name),
                    subtitle: Text(
                      members.isEmpty ? 'keine Firmen' : members.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'rename') {
                          final name = await _askName(
                            context,
                            'Kategorie umbenennen',
                            c.name,
                          );
                          if (name != null) {
                            try {
                              await repo.renameCategory(c.id, name);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('„$name“ gibt es schon.'),
                                  ),
                                );
                              }
                            }
                          }
                        } else if (action == 'delete') {
                          if (await _confirmDelete(context, c.name)) {
                            await repo.deleteCategory(c.id);
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
                        PopupMenuItem(value: 'delete', child: Text('Löschen')),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static Future<String?> _askName(
    BuildContext context,
    String title,
    String initial,
  ) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    // Controller nicht sofort entsorgen: der Dialog animiert noch heraus.
    final name = result?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  static Future<bool> _confirmDelete(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„$name“ löschen?'),
        content: const Text(
          'Die Firmen dieser Kategorie bleiben erhalten, nur ohne Kategorie.',
        ),
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
    return ok == true;
  }
}
