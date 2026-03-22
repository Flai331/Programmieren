import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../diary/diary_screen.dart';
import 'starter_models.dart';

// ═══════════════════════════════════════════════════════════════
//  STARTER DONE SCREEN — Celebration
// ═══════════════════════════════════════════════════════════════

class StarterDoneScreen extends StatelessWidget {
  final StarterJourney journey;

  const StarterDoneScreen({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    final completedDays = journey.days.where((d) => d.isComplete).length;
    final daysWithTemp =
        journey.days.where((d) => d.temperature != null).length;
    final floatPassed =
        journey.days.where((d) => d.floatTestDone && d.floatTestPassed).length;

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
              '${journey.starterName} ist bereit!',
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
                    value: _formatDate(journey.startedAt),
                  ),
                  _StatRow(
                    emoji: '⏱️',
                    label: 'Gesamtdauer',
                    value: '${journey.days.length} Tage',
                  ),
                  _StatRow(
                    emoji: '✅',
                    label: 'Erledigte Tage',
                    value: '$completedDays/${journey.days.length}',
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
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const DiaryScreen()),
                  (route) => route.isFirst,
                ),
                icon: const Icon(Icons.book_outlined),
                label: const Text('Ins Tagebuch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
