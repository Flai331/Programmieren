import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/personal.dart';

/// „Meine Daten“ für mehrere Personen – zum Einsetzen beim Ausfüllen.
class PersonalDataScreen extends StatelessWidget {
  const PersonalDataScreen({super.key});

  Future<String?> _askName(BuildContext context, String title, [String initial = '']) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'z. B. Ich, Anna, Max')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = services.repository;
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Daten')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await _askName(context, 'Neue Person');
          if (name != null && name.trim().isNotEmpty) await repo.addPerson(name.trim());
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Person'),
      ),
      body: StreamBuilder<List<String>>(
        stream: repo.watchPersons(),
        builder: (context, snap) {
          final persons = snap.data ?? const <String>[];
          if (persons.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Name, Anschrift, Geburtsdatum, IBAN, Versicherungsnummern … '
                  'einmal eintragen und beim Ausfüllen mit einem Tipp einsetzen '
                  '(Werkzeug „Meine Daten“). Mehrere Personen möglich.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(children: [
            for (final p in persons)
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(p),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final n = await _askName(context, 'Umbenennen', p);
                      if (n != null && n.trim().isNotEmpty) await repo.renamePerson(p, n);
                    } else {
                      await repo.deletePerson(p);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
                    PopupMenuItem(value: 'delete', child: Text('Löschen')),
                  ],
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _PersonEditor(person: p))),
              ),
          ]);
        },
      ),
    );
  }
}

class _PersonEditor extends StatefulWidget {
  final String person;
  const _PersonEditor({required this.person});
  @override
  State<_PersonEditor> createState() => _PersonEditorState();
}

class _PersonEditorState extends State<_PersonEditor> {
  final _controllers = <String, TextEditingController>{};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    services.repository.personalValues(widget.person).then((v) {
      for (final k in kPersonalFields.keys) {
        _controllers[k] = TextEditingController(text: v[k] ?? '');
      }
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    for (final e in _controllers.entries) {
      await services.repository.setPersonalValue(widget.person, e.key, e.value.text);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.save))],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final e in kPersonalFields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _controllers[e.key],
                      decoration: InputDecoration(
                          labelText: e.value, border: const OutlineInputBorder()),
                    ),
                  ),
                FilledButton(onPressed: _save, child: const Text('Speichern')),
              ],
            ),
    );
  }
}

/// Auswahl beim Ausfüllen: Person → Feld/Kombination. Liefert den Text.
Future<String?> pickPersonalText(BuildContext context) async {
  final repo = services.repository;
  final persons = await repo.watchPersons().first;
  if (!context.mounted) return null;
  if (persons.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Noch keine Daten'),
        content: const Text('Unter Einstellungen → „Meine Daten“ einmal '
            'eintragen, dann hier mit einem Tipp einsetzen.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    return null;
  }
  var person = persons.first;
  if (persons.length > 1) {
    final p = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final p in persons)
            ListTile(
                leading: const Icon(Icons.person),
                title: Text(p),
                onTap: () => Navigator.pop(ctx, p)),
        ]),
      ),
    );
    if (p == null) return null;
    person = p;
  }
  final combos = personalCombos(await repo.personalValues(person));
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        for (final c in combos)
          ListTile(
            title: Text(c.label),
            subtitle: Text(c.text, maxLines: 3),
            onTap: () => Navigator.pop(ctx, c.text),
          ),
      ]),
    ),
  );
}
