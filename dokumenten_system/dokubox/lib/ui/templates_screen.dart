import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/database.dart';

/// Unterschriften und handschriftliche Vorlagen verwalten. Sie werden am PC
/// im Scan-Trenner gezeichnet und per WLAN übertragen.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unterschriften & Vorlagen')),
      body: StreamBuilder<List<SignatureTemplate>>(
        stream: services.repository.watchTemplates(),
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'So kommt eine Unterschrift aufs Handy:\n'
                    '1. Am PC im Scan-Trenner „✍ Unterschrift zeichnen…“ – mit '
                    'Maus, Stift oder Grafiktablett unterschreiben und speichern.\n'
                    '2. Dort „Per WLAN ans Handy“ – QR-Code erscheint.\n'
                    '3. Hier: PDF importieren → Vom PC (WLAN) → Code scannen.\n\n'
                    'Beim Ausfüllen eines Dokuments: Werkzeug „Unterschrift“, '
                    'auf die Stelle tippen, mit dem Griff in der Größe anpassen.',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Noch keine Vorlagen.',
                      textAlign: TextAlign.center),
                ),
              for (final t in list) _TemplateTile(template: t),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final SignatureTemplate template;
  const _TemplateTile({required this.template});

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: template.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Umbenennen'),
        content: TextField(controller: controller, autofocus: true),
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
    if (name != null && name.trim().isNotEmpty) {
      await services.repository.renameTemplate(template.id, name);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${template.name}“ löschen?'),
        content: const Text(
            'Bereits ausgefüllte Dokumente behalten die Unterschrift.'),
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
    if (ok == true) await services.repository.deleteTemplate(template.id);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: Container(
          width: 120,
          color: Colors.white,
          padding: const EdgeInsets.all(4),
          child: FutureBuilder<Uint8List?>(
            future: services.templates.bytes(template.id),
            builder: (context, snap) => snap.data == null
                ? const SizedBox.shrink()
                : Image.memory(snap.data!, fit: BoxFit.contain),
          ),
        ),
        title: Text(template.name),
        trailing: PopupMenuButton<String>(
          onSelected: (v) =>
              v == 'rename' ? _rename(context) : _delete(context),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
            PopupMenuItem(value: 'delete', child: Text('Löschen')),
          ],
        ),
      ),
    );
  }
}
