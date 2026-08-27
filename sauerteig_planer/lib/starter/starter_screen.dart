import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/timezone.dart' as tz;
import '../app_colors.dart';
import '../untils/feedback_service.dart';
import 'starter_models.dart';
import 'starter_storage.dart';
import 'starter_day_screen.dart';
import 'starter_tips_screen.dart';
import 'starter_done_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  STARTER SCREEN — Übersicht
// ═══════════════════════════════════════════════════════════════

class StarterScreen extends StatefulWidget {
  const StarterScreen({super.key});

  @override
  State<StarterScreen> createState() => _StarterScreenState();
}

class _StarterScreenState extends State<StarterScreen> {
  StarterJourney? _journey;
  bool _loading = true;
  bool _notifEnabled = false;
  final _nameController = TextEditingController(text: 'Mein Sauerteig');
  final _notifPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final journey = await StarterStorage.load();
    final notifEnabled = await StarterStorage.isNotificationEnabled();
    setState(() {
      _journey = journey;
      _notifEnabled = notifEnabled;
      _loading = false;
    });
  }

  Future<void> _startJourney() async {
    final name = _nameController.text.trim();
    FeedbackService.log('Starter-Journey gestartet: "$name", Erinnerung=$_notifEnabled');
    final journey = StarterJourney.create(name);
    await StarterStorage.save(journey);
    if (_notifEnabled && !kIsWeb) {
      await _scheduleReminder();
    }
    setState(() => _journey = journey);
  }

  Future<void> _complete() async {
    if (_journey == null) return;
    FeedbackService.log('Starter-Journey abgeschlossen: "${_journey!.starterName}", ${_journey!.days.length} Tage');
    final updated = _journey!.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    await StarterStorage.save(updated);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StarterDoneScreen(journey: updated)),
    );
    _load();
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Neuen Starter beginnen?',
            style: TextStyle(color: AppColors.text)),
        content: const Text(
          'Der aktuelle Journey wird gelöscht. Dies kann nicht rückgängig gemacht werden.',
          style: TextStyle(color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Löschen', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      FeedbackService.log('Starter-Journey gelöscht: "${_journey?.starterName}"');
      await StarterStorage.delete();
      _load();
    }
  }

  Future<void> _addDay() async {
    if (_journey == null) return;
    FeedbackService.log('Starter: Erweiterungstag hinzugefügt → jetzt ${_journey!.days.length + 1} Tage');
    final updated = _journey!.addExtensionDay();
    await StarterStorage.save(updated);
    setState(() => _journey = updated);
  }

  Future<void> _scheduleReminder() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'starter_reminder',
        'Starter Erinnerung',
        channelDescription: 'Tägliche Erinnerung deinen Starter zu füttern',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
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
    FeedbackService.log('Starter-Erinnerung geplant für ${scheduled.hour}:${scheduled.minute.toString().padLeft(2, '0')} täglich');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('🌱 Starter-Guide',
            style: TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: AppColors.gold),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: AppColors.text2),
            tooltip: 'Problemlöser',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StarterTipsScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green))
          : _journey == null
              ? _buildStart()
              : _journey!.isCompleted
                  ? _buildCompleted()
                  : _buildActive(),
    );
  }

  // ── Kein Journey vorhanden ──────────────────────────────────
  Widget _buildStart() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'Deinen ersten Sauerteig-Starter ansetzen',
            style: TextStyle(
                color: AppColors.gold,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Der 7-Tage-Begleiter führt dich Schritt für Schritt durch das Ansetzen '
            'deines Starters – mit täglichen Checklisten, Float-Test und Tipps.',
            style: TextStyle(color: AppColors.text2, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              labelText: 'Name deines Starters',
              labelStyle: const TextStyle(color: AppColors.text2),
              hintText: 'Mein Sauerteig',
              hintStyle: const TextStyle(color: AppColors.text3),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.green),
              ),
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              value: _notifEnabled,
              onChanged: (v) async {
                await StarterStorage.setNotificationEnabled(v);
                setState(() => _notifEnabled = v);
              },
              title: const Text('Tägliche Erinnerung um 8:00',
                  style: TextStyle(color: AppColors.text)),
              activeColor: AppColors.green,
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startJourney,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Starter-Reise beginnen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Aktiver Journey ─────────────────────────────────────────
  Widget _buildActive() {
    final journey = _journey!;
    final completedDays =
        journey.days.where((d) => d.isComplete).length;
    final progress = completedDays / journey.days.length;

    return Column(
      children: [
        // Fortschrittsbalken
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(journey.starterName,
                      style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('Tag ${journey.currentDayNumber}/${journey.days.length}',
                      style: const TextStyle(
                          color: AppColors.green, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surface2,
                  color: AppColors.green,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text('$completedDays von ${journey.days.length} Tagen erledigt',
                  style: const TextStyle(
                      color: AppColors.text3, fontSize: 12)),
            ],
          ),
        ),
        // Tagesliste
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: journey.days.length,
            itemBuilder: (_, i) {
              final day = journey.days[i];
              final isToday = day.dayNumber == journey.currentDayNumber;
              final isFuture =
                  day.dayNumber > journey.currentDayNumber;

              return _DayCard(
                day: day,
                isToday: isToday,
                isFuture: isFuture,
                onTap: isFuture
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StarterDayScreen(
                              journey: journey,
                              dayIndex: i,
                            ),
                          ),
                        );
                        _load();
                      },
              );
            },
          ),
        ),
        // Aktionsbuttons
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addDay,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tag hinzufügen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text2,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _complete,
                  icon: const Icon(Icons.celebration, size: 16),
                  label: const Text('Fertig! 🎉'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.bg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Abgeschlossener Journey ─────────────────────────────────
  Widget _buildCompleted() {
    final journey = _journey!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              '${journey.starterName} ist fertig!',
              style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Gestartet am ${_formatDate(journey.startedAt)} · '
              '${journey.days.length} Tage',
              style: const TextStyle(color: AppColors.text2),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Neuen Starter ansetzen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.bg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

// ── Tageskarte ──────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final StarterDayLog day;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  const _DayCard({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFuture
        ? AppColors.text3
        : day.isComplete
            ? AppColors.green
            : isToday
                ? AppColors.gold
                : AppColors.text2;

    return Card(
      color: isToday ? AppColors.surface2 : AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isToday ? AppColors.green : AppColors.border,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              day.isComplete ? AppColors.green : AppColors.surface2,
          child: day.isComplete
              ? const Icon(Icons.check, color: AppColors.bg, size: 18)
              : Text('${day.dayNumber}',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold)),
        ),
        title: Text('Tag ${day.dayNumber}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600)),
        subtitle: Text(
          isFuture ? 'Noch nicht verfügbar' : _subtitle(),
          style: const TextStyle(color: AppColors.text3, fontSize: 12),
        ),
        trailing: isToday
            ? const Chip(
                label: Text('Heute',
                    style: TextStyle(color: AppColors.bg, fontSize: 11)),
                backgroundColor: AppColors.green,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            : isFuture
                ? const Icon(Icons.lock_outline,
                    color: AppColors.text3, size: 18)
                : null,
      ),
    );
  }

  String _subtitle() {
    final done = day.checks.values.where((v) => v).length;
    final total = day.checks.length;
    if (day.notes.isNotEmpty) {
      return '$done/$total Aufgaben · ${day.notes.substring(0, day.notes.length.clamp(0, 40))}';
    }
    return '$done/$total Aufgaben erledigt';
  }
}
