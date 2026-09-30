import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app_colors.dart';
import '../untils/feedback_service.dart';
import '../untils/discard_recipes.dart';
import 'starter_models.dart';
import 'starter_storage.dart';
import 'starter_day_screen.dart';
import 'starter_tips_screen.dart';
import 'starter_done_screen.dart';
import 'my_starters_screen.dart';

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
  TimeOfDay _notifTime = const TimeOfDay(hour: 8, minute: 0);
  final _nameController = TextEditingController(text: 'Mein Sauerteig');
  final _notifPlugin = FlutterLocalNotificationsPlugin();

  // Überschuss-Rechner (Discard)
  double _discardAmount = 50;

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
    final time = await StarterStorage.getNotificationTime();
    setState(() {
      _journey = journey;
      _notifEnabled = notifEnabled;
      _notifTime = TimeOfDay(hour: time.hour, minute: time.minute);
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.green,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    await StarterStorage.setNotificationTime(picked.hour, picked.minute);
    setState(() => _notifTime = picked);
    if (_notifEnabled && !kIsWeb) await _scheduleReminder();
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
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, _notifTime.hour, _notifTime.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    try {
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
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        FeedbackService.log('Starter-Erinnerung: Exakte Benachrichtigungen nicht erlaubt, fallback auf inexactAllowWhileIdle');
        await _notifPlugin.zonedSchedule(
          200,
          '🌱 Starter-Erinnerung',
          'Zeit deinen Sauerteig-Starter zu kontrollieren!',
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        rethrow;
      }
    }
    FeedbackService.log('Starter-Erinnerung geplant für ${_notifTime.hour}:${_notifTime.minute.toString().padLeft(2, '0')} täglich');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('🌱 Starter-Guide',
              style: TextStyle(color: AppColors.gold)),
          iconTheme: const IconThemeData(color: AppColors.gold),
          actions: [
            IconButton(
              icon: const Icon(Icons.kitchen_outlined, color: AppColors.text2),
              tooltip: 'Meine Starter',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyStartersScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.lightbulb_outline, color: AppColors.text2),
              tooltip: 'Problemlöser',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StarterTipsScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bug_report_outlined, color: AppColors.text2),
              tooltip: 'Fehler melden',
              onPressed: () => FeedbackService.showReportDialog(context),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.green,
            labelColor: AppColors.green,
            unselectedLabelColor: AppColors.text2,
            tabs: [
              Tab(icon: Icon(Icons.grass, size: 18), text: 'Guide'),
              Tab(icon: Icon(Icons.handyman_outlined, size: 18), text: 'Pflege'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.green))
                : _journey == null
                    ? _buildStart()
                    : _journey!.isCompleted
                        ? _buildCompleted()
                        : _buildActive(),
            _buildPflegeTab(),
          ],
        ),
      ),
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
            'deines Starters – mit täglichen Checklisten, Schwimmtest (Float-Test) und Tipps.',
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
              title: const Text('Tägliche Erinnerung',
                  style: TextStyle(color: AppColors.text)),
              activeThumbColor: AppColors.green,
              contentPadding: EdgeInsets.zero,
            ),
            GestureDetector(
              onTap: _pickTime,
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: AppColors.text3, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_notifTime.hour.toString().padLeft(2, '0')}:${_notifTime.minute.toString().padLeft(2, '0')} Uhr – antippen zum Ändern',
                      style: const TextStyle(color: AppColors.green, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('💡', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Im Tab "Pflege" findest du den Auffrischungsrechner (Levain-Rechner) '
                  'und Rezeptideen für deinen Überschuss (Discard).',
                  style: TextStyle(color: AppColors.text2, fontSize: 12, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 32),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(journey.starterName,
                            style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        if (journey.flourType != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '🌾 ${journey.flourType}',
                              style: const TextStyle(
                                color: AppColors.text3,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💡', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Im Tab "Pflege" findest du den Auffrischungsrechner '
                    'und Ideen für deinen Überschuss (Discard).',
                    style: TextStyle(color: AppColors.text2, fontSize: 12, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pflege-Tab ──────────────────────────────────────────────
  Widget _buildPflegeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildMaintenanceContent(),
      ),
    );
  }

  List<Widget> _buildMaintenanceContent() {
    return [
      // ── Auffrischen-Hinweis ─────────────────────────────────
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
        ),
        child: const Row(children: [
          Text('🧮', style: TextStyle(fontSize: 22)),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Auffrischungsplan im Planer',
                  style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 4),
              Text('Im Planer kannst du einstellen wie oft du auffrischen möchtest — er rechnet automatisch den Zeitplan aus.',
                  style: TextStyle(color: AppColors.text2, fontSize: 12, height: 1.4)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      const SizedBox(height: 28),

      // ── Tests ───────────────────────────────────────────────
      _sectionHeader('🧪 Tests: Muss ich jetzt auffrischen?'),
      const SizedBox(height: 12),
      _testCard(
        emoji: '📏',
        title: 'Volumen-Test',
        ok: 'Hat sich seit letzter Fütterung verdoppelt oder mehr → noch aktiv',
        notOk: 'Kein oder kaum Volumenwachstum, ist schon wieder gesunken → auffrischen',
      ),
      const SizedBox(height: 8),
      _testCard(
        emoji: '👃',
        title: 'Geruchs-Test',
        ok: 'Angenehm säuerlich, leicht joghurtartig → fit',
        notOk: 'Beißend nach Essig, Aceton oder Nagellackentferner → dringend auffrischen',
      ),
      const SizedBox(height: 8),
      _testCard(
        emoji: '🫧',
        title: 'Bläschen-Test',
        ok: 'Viele Bläschen sichtbar, lockere Struktur → aktiv',
        notOk: 'Kaum Bläschen, flüssig-kompakt, Flüssigkeitsschicht (Hooch) oben → auffrischen',
      ),
      const SizedBox(height: 8),
      _testCard(
        emoji: '🌊',
        title: 'Schwimmtest (Float-Test) (vor dem Backen)',
        ok: 'Kleines Stück in Wasser geben: schwimmt → backfertig',
        notOk: 'Sinkt sofort → noch 1–2 Stunden warten oder nochmal auffrischen',
      ),
      const SizedBox(height: 8),
      _testCard(
        emoji: '🕐',
        title: 'Zeit-Test',
        ok: 'Kühlschrank: < 1 Woche seit letzter Fütterung → ok',
        notOk: 'Kühlschrank: > 2 Wochen; Raumtemperatur: > 24 h → auffrischen',
      ),

      const SizedBox(height: 16),
      _infoCard('🚨 Zeichen, dass dein Starter Hunger hat',
          '• Graue/schwarze Flüssigkeit (Hooch) oben drauf\n'
          '• Sehr starker Essig- oder Acetongeruch\n'
          '• Keine Bläschen mehr sichtbar\n'
          '• Kaum Volumenveränderung nach dem Füttern'),
      const SizedBox(height: 8),
      _infoCard('✅ Zeichen eines aktiven Starters',
          '• Bläschen sichtbar\n'
          '• Angenehm säuerlicher Geruch\n'
          '• Volumen verdoppelt sich 4–8h nach dem Füttern\n'
          '• Schwimmtest (Float-Test) bestanden (schwimmt im Wasser)'),

      const SizedBox(height: 28),

      // ── Überschuss-Ideen (Discard) ──────────────────────────
      _sectionHeader('♻️ Ideen für den Überschuss (Discard)'),
      const SizedBox(height: 4),
      const Text(
        'Den übrig gebliebenen Starter nicht wegwerfen — er steckt voller Aromen!',
        style: TextStyle(color: AppColors.text3, fontSize: 13, height: 1.4),
      ),
      const SizedBox(height: 16),

      // Einstellbare Restmenge
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Text('Meine Restmenge:',
              style: TextStyle(color: AppColors.text2, fontSize: 13)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _discardAmount = (_discardAmount - 10).clamp(10, 500)),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: const Text('−', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_discardAmount.round()} g',
              style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _discardAmount = (_discardAmount + 10).clamp(10, 500)),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: const Text('+', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Builder(builder: (ctx) {
        final amount = _discardAmount.round();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DiscardChip('🥞', 'Pfannkuchen', onTap: () => showDiscardRecipe(ctx, 'Pfannkuchen', amount)),
            _DiscardChip('🧇', 'Waffeln', onTap: () => showDiscardRecipe(ctx, 'Waffeln', amount)),
            _DiscardChip('🍕', 'Pizza-Teig', onTap: () => showDiscardRecipe(ctx, 'Pizza-Teig', amount)),
            _DiscardChip('🫓', 'Focaccia', onTap: () => showDiscardRecipe(ctx, 'Focaccia', amount)),
            _DiscardChip('🍌', 'Bananenbrot', onTap: () => showDiscardRecipe(ctx, 'Bananenbrot', amount)),
            _DiscardChip('🍪', 'Kekse & Cracker', onTap: () => showDiscardRecipe(ctx, 'Kekse & Cracker', amount)),
            _DiscardChip('🌮', 'Tortillas', onTap: () => showDiscardRecipe(ctx, 'Tortillas', amount)),
            _DiscardChip('🧁', 'Muffins', onTap: () => showDiscardRecipe(ctx, 'Muffins', amount)),
            _DiscardChip('🍲', 'Soße andicken', onTap: () => showDiscardRecipe(ctx, 'Soße andicken', amount)),
            _DiscardChip('🍜', 'Nudelteig', onTap: () => showDiscardRecipe(ctx, 'Nudelteig', amount)),
          ],
        );
      }),
      const SizedBox(height: 8),
      const Text(
        'Tipp: Der Überschuss (Discard) ist ungefüttert, hat weniger Triebkraft (Levain-Kraft) — '
        'ideal für Rezepte die kein Aufgehen brauchen.',
        style: TextStyle(color: AppColors.text3, fontSize: 11, height: 1.4),
      ),
      const SizedBox(height: 32),
    ];
  }


  Widget _sectionHeader(String text) => Text(
        text,
        style: const TextStyle(
            color: AppColors.gold,
            fontSize: 17,
            fontWeight: FontWeight.bold),
      );

  Widget _testCard({
    required String emoji,
    required String title,
    required String ok,
    required String notOk,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('✅ ', style: TextStyle(fontSize: 12)),
            Expanded(
                child: Text(ok,
                    style: const TextStyle(
                        color: AppColors.green, fontSize: 12, height: 1.4))),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚠️ ', style: TextStyle(fontSize: 12)),
            Expanded(
                child: Text(notOk,
                    style: const TextStyle(
                        color: AppColors.orange, fontSize: 12, height: 1.4))),
          ]),
        ]),
      );

  Widget _infoCard(String title, String body) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  color: AppColors.text2, fontSize: 12, height: 1.5)),
        ]),
      );

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

// ── Discard Chip ────────────────────────────────────────────────

class _DiscardChip extends StatelessWidget {
  final String emoji, label;
  final VoidCallback? onTap;
  const _DiscardChip(this.emoji, this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: AppColors.text2, fontSize: 12)),
        ]),
      ),
    );
  }
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kurze Tages-Überschrift aus kDayDescriptions (erste Zeile)
            Text(
              _dayHeadline(),
              style: TextStyle(
                color: isFuture ? AppColors.text3 : color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isFuture) ...[
              const SizedBox(height: 2),
              Text(
                _subtitle(),
                style: const TextStyle(color: AppColors.text3, fontSize: 11),
              ),
            ],
          ],
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

  String _dayHeadline() {
    final desc = kDayDescriptions[day.dayNumber] ?? '';
    // Erste Zeile = "🌱 Heute legst du den Grundstein!"
    return desc.split('\n').first.trim();
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
