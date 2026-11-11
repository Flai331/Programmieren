import 'package:drift/drift.dart';

import '../data/database.dart';

/// Tabellen, die abgeglichen werden – in Abhängigkeitsreihenfolge.
/// Alle haben `id` (UUID) und `updated_at`; Konflikte: letzte Änderung
/// gewinnt.
const kSyncTables = [
  'categories',
  'correspondents',
  'tags',
  'documents',
  'claims',
  'signature_templates',
  'doc_tasks',
  'cases',
  'case_documents',
  'contracts',
  'attachments',
  'personal_data',
];

/// Tabellen mit eindeutigem Namen: gleiche Namen werden zusammengeführt.
const _uniqueName = {'categories', 'correspondents', 'tags'};

/// Fremdschlüssel, die nach dem Zusammenführen umgeschrieben werden.
const _foreignKeys = {
  'correspondents': {'category_id': 'categories'},
  'documents': {'correspondent_id': 'correspondents'},
  'cases': {'correspondent_id': 'correspondents'},
  'contracts': {'correspondent_id': 'correspondents'},
};

/// Dateien, die zu einer Zeile gehören (relativ zum App-Verzeichnis).
const _fileColumns = {
  'documents': ['pdf_path', 'filled_pdf_path'],
  'attachments': ['rel_path'],
  'signature_templates': ['image_path'],
};

/// Ein Änderungspaket.
class SyncChanges {
  /// Tabelle → Zeilen (Spaltenname → SQLite-Wert).
  final Map<String, List<Map<String, Object?>>> tables;

  /// Dokument-ID → Tag-Namen bzw. Referenzen (Art → Werte).
  final Map<String, List<String>> documentTags;
  final Map<String, Map<String, List<String>>> documentRefs;

  const SyncChanges(
      {this.tables = const {},
      this.documentTags = const {},
      this.documentRefs = const {}});

  bool get isEmpty => tables.values.every((r) => r.isEmpty);
  int get rowCount => tables.values.fold(0, (a, r) => a + r.length);

  Map<String, Object?> toJson() => {
        'v': 1,
        'tables': tables,
        'documentTags': documentTags,
        'documentRefs': documentRefs,
      };

  static SyncChanges fromJson(Map<String, dynamic> j) => SyncChanges(
        tables: {
          for (final e in (j['tables'] as Map).entries)
            e.key as String: [
              for (final r in e.value as List) Map<String, Object?>.from(r as Map),
            ],
        },
        documentTags: {
          for (final e in ((j['documentTags'] ?? {}) as Map).entries)
            e.key as String: [for (final t in e.value as List) t as String],
        },
        documentRefs: {
          for (final e in ((j['documentRefs'] ?? {}) as Map).entries)
            e.key as String: {
              for (final r in (e.value as Map).entries)
                r.key as String: [for (final v in r.value as List) v as String],
            },
        },
      );
}

/// Ergebnis eines Imports.
class SyncImport {
  int inserted = 0, updated = 0, skipped = 0;

  /// Geänderte/neue Dokumente (für Suchindex und Erinnerungen).
  final changedDocuments = <String>{};

  /// Dateien, die angefordert werden müssen (relativ).
  final neededFiles = <String>{};

  /// Lokal umzubenennende Dateien (alt → neu), z. B. nach Nummernvergabe.
  final renames = <String, String>{};
}

/// Sekunden seit 1970 (so speichert drift DateTime).
int _ts(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);

class SyncEngine {
  final AppDatabase db;
  SyncEngine(this.db);

  /// Alle Zeilen, die nach [since] (Sekunden) geändert wurden. Ohne
  /// [since]: alles.
  Future<SyncChanges> exportChanges({int? since}) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final t in kSyncTables) {
      final rows = await db.customSelect(
        since == null
            ? 'SELECT * FROM $t'
            : 'SELECT * FROM $t WHERE updated_at > ?',
        variables: [if (since != null) Variable.withInt(since)],
      ).get();
      tables[t] = [for (final r in rows) Map<String, Object?>.from(r.data)];
    }
    final docIds = [for (final r in tables['documents']!) r['id'] as String];
    final tags = <String, List<String>>{};
    final refs = <String, Map<String, List<String>>>{};
    for (final id in docIds) {
      final t = await db.customSelect(
        'SELECT t.name FROM document_tags dt JOIN tags t ON t.id = dt.tag_id '
        'WHERE dt.document_id = ?',
        variables: [Variable.withString(id)],
      ).get();
      tags[id] = [for (final r in t) r.read<String>('name')];
      final rr = await db.customSelect(
        'SELECT kind, value FROM extracted_refs WHERE document_id = ?',
        variables: [Variable.withString(id)],
      ).get();
      final m = <String, List<String>>{};
      for (final r in rr) {
        m.putIfAbsent(r.read<String>('kind'), () => []).add(r.read<String>('value'));
      }
      refs[id] = m;
    }
    return SyncChanges(tables: tables, documentTags: tags, documentRefs: refs);
  }

  Future<Map<String, Object?>?> _local(String table, String id) async {
    final r = await db.customSelect('SELECT * FROM $table WHERE id = ?',
        variables: [Variable.withString(id)]).getSingleOrNull();
    return r?.data;
  }

  Future<void> _upsert(String table, Map<String, Object?> row) async {
    final cols = row.keys.toList();
    final updates = [for (final c in cols) if (c != 'id') '$c = excluded.$c'];
    await db.customStatement(
      'INSERT INTO $table (${cols.join(', ')}) VALUES '
      '(${List.filled(cols.length, '?').join(', ')}) '
      'ON CONFLICT(id) DO UPDATE SET ${updates.join(', ')}',
      [for (final c in cols) row[c]],
    );
  }

  /// Änderungen übernehmen (letzte Änderung gewinnt). Gleichnamige Firmen,
  /// Kategorien und Tags werden zusammengeführt.
  Future<SyncImport> importChanges(SyncChanges changes) async {
    final result = SyncImport();
    final idMap = <String, Map<String, String>>{}; // Tabelle → fremd → lokal
    await db.transaction(() async {
      await db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in kSyncTables) {
        for (final incoming in changes.tables[table] ?? const []) {
          final row = Map<String, Object?>.from(incoming);
          // Fremdschlüssel auf zusammengeführte IDs umbiegen.
          for (final fk in (_foreignKeys[table] ?? const {}).entries) {
            final v = row[fk.key];
            if (v is String) row[fk.key] = idMap[fk.value]?[v] ?? v;
          }
          final id = row['id'] as String;
          var local = await _local(table, id);
          if (local == null && _uniqueName.contains(table)) {
            final same = await db.customSelect(
              'SELECT * FROM $table WHERE lower(name) = lower(?) AND id != ?',
              variables: [
                Variable.withString(row['name'] as String),
                Variable.withString(id),
              ],
            ).getSingleOrNull();
            if (same != null) {
              // Gleicher Name, andere ID → lokale ID behalten.
              idMap.putIfAbsent(table, () => {})[id] = same.data['id'] as String;
              if (_ts(row['updated_at']) > _ts(same.data['updated_at'])) {
                row['id'] = same.data['id'];
                await _upsert(table, row);
                result.updated++;
              } else {
                result.skipped++;
              }
              continue;
            }
          }
          if (local != null &&
              _ts(row['updated_at']) <= _ts(local['updated_at'])) {
            result.skipped++;
            continue;
          }
          if (table == 'documents') {
            // Dokumentnummer schon für ein anderes Dokument vergeben?
            final clash = await db.customSelect(
              'SELECT id FROM documents WHERE doc_number = ? AND id != ?',
              variables: [
                Variable.withString(row['doc_number'] as String),
                Variable.withString(id),
              ],
            ).getSingleOrNull();
            if (clash != null) row['doc_number'] = '${row['doc_number']}-K';
            if (local != null && local['pdf_path'] != row['pdf_path']) {
              result.renames[local['pdf_path'] as String] = row['pdf_path'] as String;
            }
            if (local != null &&
                local['filled_pdf_path'] != null &&
                row['filled_pdf_path'] != null &&
                local['filled_pdf_path'] != row['filled_pdf_path']) {
              result.renames[local['filled_pdf_path'] as String] =
                  row['filled_pdf_path'] as String;
            }
          }
          await _upsert(table, row);
          local == null ? result.inserted++ : result.updated++;
          for (final col in _fileColumns[table] ?? const <String>[]) {
            final f = row[col];
            if (f is String && f.isNotEmpty) result.neededFiles.add(f);
          }
          if (table == 'documents') {
            result.changedDocuments.add(id);
            await _replaceTagsAndRefs(id, changes);
          }
        }
      }
    });
    // Umbenannte Dateien werden lokal verschoben, nicht neu geholt.
    result.neededFiles.removeAll(result.renames.values);
    return result;
  }

  Future<void> _replaceTagsAndRefs(String docId, SyncChanges changes) async {
    final tags = changes.documentTags[docId];
    if (tags != null) {
      await db.customStatement(
          'DELETE FROM document_tags WHERE document_id = ?', [docId]);
      for (final name in tags) {
        final t = await db.customSelect(
          'SELECT id FROM tags WHERE lower(name) = lower(?)',
          variables: [Variable.withString(name)],
        ).getSingleOrNull();
        String tagId;
        if (t == null) {
          tagId = (await db.into(db.tags)
                  .insertReturning(TagsCompanion.insert(name: name)))
              .id;
        } else {
          tagId = t.read<String>('id');
        }
        await db.customStatement(
            'INSERT OR IGNORE INTO document_tags (document_id, tag_id) VALUES (?, ?)',
            [docId, tagId]);
      }
    }
    final refs = changes.documentRefs[docId];
    if (refs != null) {
      await db.customStatement(
          'DELETE FROM extracted_refs WHERE document_id = ?', [docId]);
      for (final e in refs.entries) {
        for (final v in e.value) {
          await db.customStatement(
              'INSERT OR IGNORE INTO extracted_refs (document_id, kind, value) '
              'VALUES (?, ?, ?)',
              [docId, e.key, v]);
        }
      }
    }
  }
}
