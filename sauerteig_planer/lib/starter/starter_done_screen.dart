import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../diary/diary_models.dart';
import '../diary/diary_screen.dart';
import '../diary/diary_storage.dart';
import '../untils/feedback_service.dart';
import 'starter_models.dart';

// ═══════════════════════════════════════════════════════════════
//  STARTER DONE SCREEN — Celebration
// ═══════════════════════════════════════════════════════════════

class StarterDoneScreen extends StatefulWidget {
  final StarterJourney journey;

  const StarterDoneScreen({super.key, required this.journey});

  @override
  State<StarterDoneScreen> createState() => _StarterDoneScreenState();
}

class _StarterDoneScreenState extends State<StarterDoneScreen> {
  bool _exporting = false;

  Future<void> _exportToDiary() async {
    setState(() => _exporting = true);
    int count = 0;
    for (final day in widget.journey.days) {
      if (!day.isComplete && day.notes.isEmpty && day.photoPath == null) {
        continue; // Leere Tage überspringen
      }
      // Typ bestimmen
      final hasFed = day.checks[StarterDayActivity.feeding] == true;
      final type = hasFed ? DiaryEntryType.feeding : DiaryEntryType.observation;

      // Text zusammenstellen
      final parts = <String>[];
      parts.add('Starter-Tag ${day.dayNumber} – ${widget.journey.starterName}');
      if (day.notes.isNotEmpty) parts.add(day.notes);
      if (day.floatTestDone) {
        parts.add(day.floatTestPassed
            ? '🥄 Float-Test: geschwommen ✓'
            : '🥄 Float-Test: gesunken ✗');
      }

      final entry = DiaryEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}_starter_${day.dayNumber}',
        timestamp: day.date,
        type: type,
        text: parts.join('\n'),
        temperature: day.temperature,
        photoPath: day.photoPath,
      );
      await DiaryStorage.save(entry);
      count++;
    }
    FeedbackService.log(
        'Starter "${widget.journey.starterName}" → $count Tagebuch-Einträge exportiert');
    if (!mounted) return;
    setState(() => _exporting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$count Tage ins Tagebuch übertragen ✓'),
      backgroundColor: AppColors.green,
    ));
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DiaryScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedDays = widget.journey.days.where((d) => d.isComplete).length;
    final daysWithTemp =
        widget.journey.days.where((d) => d.temperature != null).length;
    final floatPassed = widget.journey.days
        .where((d) => d.floatTestDone && d.floatTestPassed)
        .length;
    final daysWithPhoto =
        widget.journey.days.where((d) => d.photoPath != null).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Starter fertig! 🎉',
            style: TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text('🎉', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text(
              '${widget.journey.starterName} ist bereit!',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Herzlichen Glückwunsch! Du hast deinen ersten Sauerteig-Starter erfolgreich gezüchtet.',
              style: TextStyle(color: AppColors.text2, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _StatRow(
                    emoji: '📅',
                    label: 'Gestartet am',
                    value: _formatDate(widget.journey.startedAt),
                  ),
                  _StatRow(
                    emoji: '⏱️',
                    label: 'Gesamtdauer',
                    value: '${widget.journey.days.length} Tage',
                  ),
                  _StatRow(
                    emoji: '✅',
                    label: 'Erledigte Tage',
                    value: '$completedDays/${widget.journey.days.length}',
                  ),
                  if (daysWithTemp > 0)
                    _StatRow(
                      emoji: '🌡️',
                      label: 'Temperaturen gemessen',
                      value: '$daysWithTemp Tage',
                    ),
                  if (floatPassed > 0)
                    _StatRow(
                      emoji: '🥄',
                      label: 'Float-Test bestanden',
                      value: '$floatPassed ×',
                    ),
                  if (daysWithPhoto > 0)
                    _StatRow(
                      emoji: '📷',
                      label: 'Fotos aufgenommen',
                      value: '$daysWithPhoto Tage',
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Nächste Schritte:',
              style: TextStyle(
                  color: AppColors.text2,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const _TipChip('Starter im Kühlschrank lagern (1× pro Woche füttern)'),
            const _TipChip('Für dein erstes Brot: Float-Test vor jedem Backen'),
            const _TipChip('Im Tagebuch Backergebnisse festhalten'),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _exportToDiary,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.bg))
                    : const Icon(Icons.upload_outlined),
                label: Text(_exporting
                    ? 'Wird übertragen ...'
                    : 'Mit allen Daten ins Tagebuch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const DiaryScreen()),
                  (route) => route.isFirst,
                ),
                icon: const Icon(Icons.book_outlined, size: 18),
                label: const Text('Tagebuch öffnen (ohne Export)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text2,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text2,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Zurück zum Starter-Guide'),
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

class _StatRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatRow(
      {required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.text2))),
          Text(value,
              style: const TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final String text;
  const _TipChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.green)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: AppColors.text2, height: 1.4))),
        ],
      ),
    );
  }
}
