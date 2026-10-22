import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/database.dart';
import '../data/document_repository.dart';
import '../data/finance.dart';

/// Lokale Benachrichtigungen für Wiedervorlagen/Kündigungsfristen,
/// fällige Rechnungen und ausstehende Erstattungen.
class NotificationService {
  final DocumentRepository repository;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationService(this.repository);

  static const _channel = AndroidNotificationDetails(
    'fristen',
    'Fristen & Wiedervorlagen',
    channelDescription:
        'Erinnerungen an Kündigungsfristen und Wiedervorlagen von Dokumenten',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _paymentChannel = AndroidNotificationDetails(
    'zahlungen',
    'Rechnungen & Erstattungen',
    channelDescription:
        'Erinnerungen an fällige Rechnungen und ausstehende Erstattungen',
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
  static int paymentIdFor(String documentId) =>
      'zahlung:$documentId'.hashCode & 0x7fffffff;
  static int claimIdFor(String claimId) =>
      'erstattung:$claimId'.hashCode & 0x7fffffff;

  static String _label(Document doc) =>
      doc.title.isEmpty ? doc.docNumber : doc.title;

  Future<void> _schedule(int id, String title, String body, DateTime when,
      AndroidNotificationDetails channel) async {
    if (when.isBefore(DateTime.now())) return;
    await init();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      NotificationDetails(android: channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Wiedervorlage und (bei offener Rechnung) Zahlungserinnerung planen.
  Future<void> scheduleFor(Document doc) async {
    final when = doc.reminderAt;
    if (when != null) {
      await _schedule(
        idFor(doc.id),
        'Frist: ${_label(doc)}',
        doc.reminderNote?.isNotEmpty == true
            ? doc.reminderNote!
            : 'Wiedervorlage für Dokument ${doc.docNumber}',
        when,
        _channel,
      );
    }
    final payAt = doc.paymentReminderAt;
    if (payAt != null && doc.paymentStatus == PaymentStatus.open) {
      final amount =
          doc.amountCents == null ? '' : ' ${formatEuro(doc.amountCents!)}';
      final due = doc.dueDate == null
          ? ''
          : ' – fällig am ${_date(doc.dueDate!)}';
      await _schedule(
        paymentIdFor(doc.id),
        'Rechnung bezahlen:$amount',
        '${_label(doc)} (${doc.docNumber})$due',
        payAt,
        _paymentChannel,
      );
    }
  }

  Future<void> scheduleClaim(Claim claim, Document doc) async {
    final when = claim.followUpAt;
    if (when == null || claim.status != ClaimStatus.submitted) return;
    await _schedule(
      claimIdFor(claim.id),
      'Erstattung noch offen: ${claim.target}',
      '${_label(doc)} (${doc.docNumber}) wurde am '
          '${_date(claim.submittedAt ?? when)} eingereicht – schon erstattet?',
      when,
      _paymentChannel,
    );
  }

  Future<void> cancelFor(String documentId) async {
    await init();
    await _plugin.cancel(idFor(documentId));
    await _plugin.cancel(paymentIdFor(documentId));
    for (final claim in await repository.claimsForDocument(documentId,
        includeDeleted: true)) {
      await _plugin.cancel(claimIdFor(claim.id));
    }
  }

  /// Alle Erinnerungen eines Dokuments nach einer Änderung neu aufsetzen.
  Future<void> syncDocument(String documentId) async {
    await cancelFor(documentId);
    final doc = await repository.getDocument(documentId);
    if (doc == null || doc.deletedAt != null) return;
    await scheduleFor(doc);
    for (final claim in await repository.claimsForDocument(documentId)) {
      await scheduleClaim(claim, doc);
    }
  }

  /// Nach App-Start alle anstehenden Erinnerungen neu planen (deckt auch
  /// Geräteneustarts ab, ohne BOOT_COMPLETED-Receiver zu benötigen).
  Future<void> rescheduleAll() async {
    await init();
    final ids = <String>{
      for (final doc in await repository.upcomingReminders()) doc.id,
      for (final doc in await repository.upcomingPaymentReminders()) doc.id,
      for (final claim in await repository.upcomingClaimFollowUps())
        claim.documentId,
    };
    for (final id in ids) {
      await syncDocument(id);
    }
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
