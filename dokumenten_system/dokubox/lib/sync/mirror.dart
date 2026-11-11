import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/database.dart';
import '../data/document_repository.dart';
import '../ui/share_name.dart';

/// Lesbarer Ablage-Ordner am PC:
/// `Ablage/Jahr/Kategorie/Nummer Firma Titel.pdf` (+ „(ausgefüllt)“).
/// Wird nach jedem Abgleich aktualisiert;
/// gelöschte Dokumente wandern in `_Papierkorb`.
class AblageMirror {
  final DocumentRepository repo;
  final Directory root;
  final Future<String> Function(String relative) absolutePdf;
  AblageMirror(this.repo, this.root, this.absolutePdf);

  File get _indexFile => File(p.join(root.path, '.dokubox-index.json'));

  Future<Map<String, List<String>>> _index() async {
    if (!await _indexFile.exists()) return {};
    final j = jsonDecode(await _indexFile.readAsString()) as Map<String, dynamic>;
    return {for (final e in j.entries) e.key: [for (final v in e.value as List) v as String]};
  }

  /// Zielpfade (relativ) für ein Dokument.
  static List<String> targetsFor(Document d, {String firm = '', String category = ''}) {
    final year = (d.docDate ?? d.scannedAt).year.toString();
    final folder = category.isEmpty ? 'Ohne Kategorie' : category;
    final base = [d.docNumber, firm, d.title].where((s) => s.trim().isNotEmpty).join(' ');
    String clean(String s) => safePdfFileName(s).replaceAll('.pdf', '');
    return [
      p.join(year, clean(folder), safePdfFileName(base)),
      if (d.filledPdfPath != null)
        p.join(year, clean(folder), safePdfFileName('$base (ausgefüllt)')),
    ];
  }

  Future<void> update(Iterable<String> documentIds) async {
    await root.create(recursive: true);
    final index = await _index();
    final cats = {for (final c in await repo.allCategories()) c.id: c.name};
    for (final id in documentIds) {
      final d = await repo.getDocument(id);
      final old = index[id] ?? const [];
      if (d == null || d.deletedAt != null) {
        for (final o in old) {
          final f = File(p.join(root.path, o));
          if (await f.exists()) {
            final bin = File(p.join(root.path, '_Papierkorb', p.basename(o)));
            await bin.parent.create(recursive: true);
            await f.rename(bin.path);
          }
        }
        index.remove(id);
        continue;
      }
      final firm = d.correspondentId == null
          ? null
          : await repo.getCorrespondent(d.correspondentId!);
      final targets = targetsFor(d,
          firm: firm?.name ?? '', category: cats[firm?.categoryId] ?? '');
      final sources = [d.pdfPath, if (d.filledPdfPath != null) d.filledPdfPath!];
      for (final o in old) {
        if (!targets.contains(o)) {
          final f = File(p.join(root.path, o));
          if (await f.exists()) await f.delete();
        }
      }
      for (var i = 0; i < targets.length; i++) {
        final src = File(await absolutePdf(sources[i]));
        if (!await src.exists()) continue;
        final dst = File(p.join(root.path, targets[i]));
        await dst.parent.create(recursive: true);
        if (!await dst.exists() || await dst.length() != await src.length()) {
          await src.copy(dst.path);
        }
      }
      index[id] = targets;
    }
    await _indexFile.writeAsString(jsonEncode(index));
  }
}
