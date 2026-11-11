import 'package:dokubox/data/database.dart';

/// Baut eine aktuelle Datenbank auf den Stand von Schema [version] zurück
/// (für Migrationstests). Beim nächsten Öffnen migriert Drift wieder hoch.
Future<void> downgradeTo(AppDatabase db, int version) async {
  Future<void> sql(String s) => db.customStatement(s);
  Future<void> dropCols(String table, List<String> cols) async {
    for (final c in cols) {
      await sql('ALTER TABLE $table DROP COLUMN $c');
    }
  }

  await sql('PRAGMA foreign_keys = OFF');
  if (version < 6) {
    for (final i in [
      'idx_refs_value',
      'idx_case_docs_case',
      'idx_case_docs_doc',
      'idx_docs_hash',
    ]) {
      await sql('DROP INDEX IF EXISTS $i');
    }
    for (final t in [
      'case_documents',
      'cases',
      'contracts',
      'attachments',
      'personal_data',
    ]) {
      await sql('DROP TABLE $t');
    }
    await dropCols('documents', [
      'content_hash',
      'warranty_until',
      'warranty_kind',
      'objection_deadline',
      'tax_category',
      'tax_year',
      'tax_amount_cents',
      'destroyed_at',
      'destroyed_from',
      'payment_reference',
    ]);
    await dropCols('correspondents', [
      'email',
      'fax',
      'postal_address',
      'mail_subject_template',
      'mail_body_template',
      'iban',
      'bic',
    ]);
    await dropCols('doc_tasks', ['origin']);
  }
  if (version < 5) await sql('DROP TABLE doc_tasks');
  if (version < 4) {
    await sql('DROP TABLE signature_templates');
    await dropCols('documents', ['filled_pdf_path', 'fill_data']);
  }
  if (version < 3) {
    await sql('UPDATE correspondents SET category_id = NULL');
    await dropCols('correspondents', ['category_id']);
    await sql('DROP TABLE categories');
  }
  if (version < 2) {
    await sql('DROP TABLE claims');
    await dropCols('documents', [
      'amount_cents',
      'due_date',
      'payment_status',
      'paid_at',
      'payment_reminder_at',
    ]);
  }
  await sql('PRAGMA user_version = $version');
}
