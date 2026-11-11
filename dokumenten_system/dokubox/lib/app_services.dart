import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ai/ai_extraction_service.dart';
import 'platform.dart';
import 'sync/mirror.dart';
import 'sync/sync_service.dart';
import 'attachments/attachment_service.dart';
import 'backup/backup_service.dart';
import 'data/database.dart';
import 'data/document_repository.dart';
import 'extract/suggestion_service.dart';
import 'fill/fill_service.dart';
import 'fill/template_service.dart';
import 'reminders/notification_service.dart';
import 'scan/pdf_import_service.dart';
import 'scan/scan_service.dart';

/// Einfacher Service-Container, in main() initialisiert.
class AppServices {
  final AppDatabase db;
  late final DocumentRepository repository = DocumentRepository(db);
  late final SuggestionService suggestions = SuggestionService(repository);
  late final ScanService scanner = ScanService();
  late final PdfImportService pdfImport = PdfImportService(scanner);
  late final NotificationService notifications = NotificationService(
    repository,
  );
  late final BackupService backup = BackupService(db);
  late final AiExtractionService ai = AiExtractionService();
  late final SyncService sync = SyncService(
    db,
    repository,
    docsDir: getApplicationDocumentsDirectory,
    onChanged: (ids) async {
      for (final id in ids) {
        await notifications.syncDocument(id);
      }
      // Am PC: lesbarer Ablage-Ordner (Dokumente/DokuBox-Ablage).
      if (isDesktop) {
        final docs = await getApplicationDocumentsDirectory();
        await AblageMirror(
          repository,
          Directory(p.join(docs.path, 'DokuBox-Ablage')),
          ScanService.absolutePdfPath,
        ).update(ids);
      }
    },
  );
  late final AttachmentService attachments = AttachmentService(repository);
  late final TemplateService templates = TemplateService(repository);
  late final FillService fill = FillService(repository, templates);

  AppServices(this.db);
}

late AppServices services;
