import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/database.dart';
import '../data/document_repository.dart';

/// Lokale Benachrichtigungen für Wiedervorlagen/Kündigungsfristen.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'fristen',
    'Fristen & Wiedervorlagen',
    channelDescription:
        'Erinnerungen an Kündigungsfristen und Wiedervorlagen von Dokumenten',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  /// Stabile Notification-ID aus der Dokument-UUID.
  static int idFor(String documentId) => documentId.hashCode & 0x7fffffff;

  Future<void> scheduleFor(Document doc) async {
    final when = doc.reminderAt;
    if (when == null || when.isBefore(DateTime.now())) return;
    await init();
    await _plugin.zonedSchedule(
      idFor(doc.id),
      'Frist: ${doc.title.isEmpty ? doc.docNumber : doc.title}',
      doc.reminderNote?.isNotEmpty == true
          ? doc.reminderNote!
          : 'Wiedervorlage für Dokument ${doc.docNumber}',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelFor(String documentId) async {
    await init();
    await _plugin.cancel(idFor(documentId));
  }

  /// Nach App-Start alle anstehenden Erinnerungen neu planen (deckt auch
  /// Geräteneustarts ab, ohne BOOT_COMPLETED-Receiver zu benötigen).
  Future<void> rescheduleAll(DocumentRepository repository) async {
    await init();
    for (final doc in await repository.upcomingReminders()) {
      await scheduleFor(doc);
    }
  }
}
