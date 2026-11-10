import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dateiname, der für Windows, Android und Mail-Programme taugt: ohne
/// verbotene Zeichen, nicht zu lang, endet auf `.pdf`.
String safePdfFileName(String raw, {String fallback = 'Dokument'}) {
  var name = raw
      .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^\.+|\.+$'), '');
  if (name.isEmpty) name = fallback;
  if (name.length > 100) name = name.substring(0, 100).trim();
  return '$name.pdf';
}

/// Vorschlag für den Dateinamen beim Versenden.
String suggestedShareName(String docNumber, String title, {bool filled = false}) {
  final parts = [
    docNumber,
    if (title.trim().isNotEmpty) title.trim(),
    if (filled) 'ausgefüllt',
  ];
  return parts.join(' ');
}

/// Fragt nach dem Dateinamen (vorbelegt mit dem zuletzt gewählten bzw.
/// [suggestion]) und legt eine Kopie unter diesem Namen zum Teilen an.
/// Die gespeicherte Datei in der App bleibt unverändert.
/// Liefert den Pfad der Kopie oder `null` bei Abbruch.
Future<String?> askShareCopy(
  BuildContext context, {
  required String sourcePath,
  required String rememberKey,
  required String suggestion,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'share_name_$rememberKey';
  final initial = prefs.getString(key) ?? suggestion;
  if (!context.mounted) return null;
  final controller = TextEditingController(text: initial);
  controller.selection =
      TextSelection(baseOffset: 0, extentOffset: initial.length);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Dateiname zum Versenden'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          suffixText: '.pdf',
          helperText: 'So heißt die Datei beim Empfänger',
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, controller.text),
          icon: const Icon(Icons.share),
          label: const Text('Teilen'),
        ),
      ],
    ),
  );
  if (name == null) return null;
  final fileName = safePdfFileName(name, fallback: suggestion);
  await prefs.setString(key, fileName.replaceAll(RegExp(r'\.pdf$'), ''));
  final dir = Directory(p.join((await getTemporaryDirectory()).path, 'teilen',
      DateTime.now().millisecondsSinceEpoch.toString()));
  await dir.create(recursive: true);
  final copy = p.join(dir.path, fileName);
  await File(sourcePath).copy(copy);
  return copy;
}
