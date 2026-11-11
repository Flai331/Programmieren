import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../lock/lock_gate.dart';

/// Fotos/Dateien an einem Dokument (z. B. Schadensfoto, Kassenbon-Foto).
class AttachmentsSection extends StatelessWidget {
  final Document doc;
  const AttachmentsSection({super.key, required this.doc});

  Future<void> _add(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Aus der Galerie'),
              onTap: () => Navigator.pop(ctx, 'gallery')),
          ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Datei'),
              onTap: () => Navigator.pop(ctx, 'file')),
        ]),
      ),
    );
    if (choice == null) return;
    LockController.suppressAutoLock = true;
    final paths = <String>[];
    try {
      if (choice == 'file') {
        final r = await FilePicker.platform.pickFiles(allowMultiple: true);
        paths.addAll([for (final f in r?.files ?? const <PlatformFile>[]) if (f.path != null) f.path!]);
      } else if (choice == 'gallery') {
        paths.addAll((await ImagePicker().pickMultiImage()).map((x) => x.path));
      } else {
        final x = await ImagePicker().pickImage(source: ImageSource.camera);
        if (x != null) paths.add(x.path);
      }
    } finally {
      LockController.suppressAutoLock = false;
    }
    for (final path in paths) {
      await services.attachments.add(doc.id, path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Attachment>>(
      stream: services.repository.watchAttachments(doc.id),
      builder: (context, snap) {
        final list = snap.data ?? const <Attachment>[];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.attach_file, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Anhänge (${list.length})',
                          style: theme.textTheme.titleSmall)),
                  TextButton.icon(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Hinzufügen'),
                  ),
                ]),
                if (list.isNotEmpty)
                  SizedBox(
                    height: 92,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      for (final a in list) _Thumb(attachment: a),
                    ]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  final Attachment attachment;
  const _Thumb({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: services.attachments.absolutePath(attachment),
      builder: (context, snap) {
        final path = snap.data;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: path == null ? null : () => OpenFilex.open(path),
            onLongPress: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Anhang entfernen?'),
                  content: Text(attachment.caption),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Entfernen')),
                  ],
                ),
              );
              if (ok == true) await services.repository.deleteAttachment(attachment.id);
            },
            child: SizedBox(
              width: 80,
              child: Column(children: [
                Expanded(
                  child: path != null && attachment.kind == 'foto'
                      ? Image.file(File(path), fit: BoxFit.cover, width: 80)
                      : const Icon(Icons.insert_drive_file, size: 40),
                ),
                Text(attachment.caption,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        );
      },
    );
  }
}
