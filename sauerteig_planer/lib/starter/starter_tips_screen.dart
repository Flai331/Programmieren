import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'starter_models.dart';

// ═══════════════════════════════════════════════════════════════
//  STARTER TIPS SCREEN — Problemlöser
// ═══════════════════════════════════════════════════════════════

class StarterTipsScreen extends StatelessWidget {
  const StarterTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('💡 Problemlöser',
            style: TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
            child: Text(
              'Etwas stimmt nicht mit deinem Starter? '
              'Hier findest du Lösungen für die häufigsten Probleme.',
              style: TextStyle(color: AppColors.text2, height: 1.5),
            ),
          ),
          ...kStarterTips.map((tip) => _TipTile(tip: tip)),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  final StarterTip tip;

  const _TipTile({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        leading: Text(tip.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(tip.title,
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w600)),
        subtitle: Text(tip.symptom,
            style: const TextStyle(color: AppColors.text3, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        iconColor: AppColors.gold,
        collapsedIconColor: AppColors.text3,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: AppColors.border),
                const Text('Problem:',
                    style: TextStyle(
                        color: AppColors.text3,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(tip.symptom,
                    style: const TextStyle(
                        color: AppColors.text2, height: 1.4)),
                const SizedBox(height: 12),
                const Text('Lösung:',
                    style: TextStyle(
                        color: AppColors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(tip.solution,
                    style: const TextStyle(
                        color: AppColors.text, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
