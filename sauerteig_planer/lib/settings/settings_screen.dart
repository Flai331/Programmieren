import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app_colors.dart';
import '../untils/feedback_service.dart';
import '../starter/starter_storage.dart';

// ═══════════════════════════════════════════════════════════════
//  EINSTELLUNGEN
// ═══════════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _tutorialEnabled = false;
  bool _starterNotifEnabled = false;

  final _notifPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final notifEnabled = await StarterStorage.isNotificationEnabled();
    setState(() {
      // onboarding_done == false → Tutorial ist aktiv
      _tutorialEnabled = !(prefs.getBool('onboarding_done') ?? false);
      _starterNotifEnabled = notifEnabled;
    });
  }

  Future<void> _toggleTutorial(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    // value true → Tutorial beim Start anzeigen → onboarding_done = false
    await prefs.setBool('onboarding_done', !value);
    setState(() => _tutorialEnabled = value);
  }

  Future<void> _toggleStarterNotif(bool value) async {
    await StarterStorage.setNotificationEnabled(value);
    setState(() => _starterNotifEnabled = value);

    if (kIsWeb) return;

    if (value) {
      await _scheduleStarterReminder();
    } else {
      await _notifPlugin.cancel(200);
    }
  }

  Future<void> _scheduleStarterReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'starter_reminder',
      'Starter Erinnerung',
      channelDescription: 'Tägliche Erinnerung deinen Starter zu füttern',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _notifPlugin.zonedSchedule(
      200,
      '🌱 Starter-Erinnerung',
      'Zeit deinen Sauerteig-Starter zu kontrollieren!',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Einstellungen',
            style: TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: ListView(
        children: [
          _sectionHeader('Allgemein'),
          SwitchListTile(
            value: _tutorialEnabled,
            onChanged: _toggleTutorial,
            title: const Text('Tutorial beim Start anzeigen',
                style: TextStyle(color: AppColors.text)),
            subtitle: const Text('Onboarding-Seiten beim nächsten App-Start zeigen',
                style: TextStyle(color: AppColors.text3, fontSize: 12)),
            activeColor: AppColors.gold,
          ),
          const Divider(color: AppColors.border, height: 1),
          _sectionHeader('Starter-Erinnerungen'),
          SwitchListTile(
            value: _starterNotifEnabled,
            onChanged: kIsWeb ? null : _toggleStarterNotif,
            title: const Text('Tägliche Erinnerung um 8:00 Uhr',
                style: TextStyle(color: AppColors.text)),
            subtitle: const Text(
              kIsWeb
                  ? 'Nicht verfügbar im Browser'
                  : 'Erinnert dich täglich deinen Starter zu kontrollieren',
              style: TextStyle(color: AppColors.text3, fontSize: 12),
            ),
            activeColor: AppColors.green,
          ),
          const Divider(color: AppColors.border, height: 1),
          _sectionHeader('Feedback'),
          ListTile(
            leading: const Icon(Icons.bug_report, color: AppColors.red),
            title: const Text('Fehler melden',
                style: TextStyle(color: AppColors.text)),
            subtitle: const Text('Direkt aus der App senden',
                style: TextStyle(color: AppColors.text3, fontSize: 12)),
            onTap: () => FeedbackService.showReportDialog(context),
          ),
          const Divider(color: AppColors.border, height: 1),
          ListTile(
            leading: const Icon(Icons.science_outlined, color: AppColors.orange),
            title: const Text('Testfehler auslösen',
                style: TextStyle(color: AppColors.text)),
            subtitle: const Text('Testet die automatische Fehlererkennung',
                style: TextStyle(color: AppColors.text3, fontSize: 12)),
            onTap: () => throw Exception('TEST: Automatische Fehlererkennung'),
          ),
          const Divider(color: AppColors.border, height: 1),
          const ListTile(
            leading: Icon(Icons.info_outline, color: AppColors.text3),
            title: Text('Version',
                style: TextStyle(color: AppColors.text)),
            subtitle: Text('1.0.0',
                style: TextStyle(color: AppColors.text3, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
