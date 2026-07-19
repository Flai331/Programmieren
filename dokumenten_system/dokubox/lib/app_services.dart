import 'backup/backup_service.dart';
import 'data/database.dart';
import 'data/document_repository.dart';
import 'extract/suggestion_service.dart';
import 'reminders/notification_service.dart';
import 'scan/scan_service.dart';

/// Einfacher Service-Container, in main() initialisiert.
class AppServices {
  final AppDatabase db;
  late final DocumentRepository repository = DocumentRepository(db);
  late final SuggestionService suggestions = SuggestionService(repository);
  late final ScanService scanner = ScanService();
  late final NotificationService notifications = NotificationService();
  late final BackupService backup = BackupService(db);

  AppServices(this.db);
}

late AppServices services;
