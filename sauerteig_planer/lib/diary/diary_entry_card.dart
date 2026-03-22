import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../app_colors.dart';
import '../untils/feedback_service.dart';
import '../untils/temp_utils.dart';
import 'diary_models.dart';
import 'diary_storage.dart';
import 'diary_entry_edit_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  DIARY ENTRY CARD
// ═══════════════════════════════════════════════════════════════

class DiaryEntryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onChanged;

  const DiaryEntryCard({
    super.key,
    required this.entry,
    required this.onChanged,
  });

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: AppColors.gold),
            title: const Text('Bearbeiten',
                style: TextStyle(color: AppColors.text)),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DiaryEntryEditScreen(entry: entry),
                ),
              );
              onChanged();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.red),
            title:
                const Text('Löschen', style: TextStyle(color: AppColors.red)),
            onTap: () async {
              Navigator.pop(context);
              FeedbackService.log('Tagebuch-Eintrag gelöscht: Typ=${kEntryTypeLabel[entry.type]}, ${entry.timestamp}');
              await DiaryStorage.delete(entry);
              onChanged();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = kEntryTypeColor[entry.type] ?? AppColors.text2;
    final emoji = kEntryTypeEmoji[entry.type] ?? '📝';
    final label = kEntryTypeLabel[entry.type] ?? '';

    final h = entry.timestamp.hour.toString().padLeft(2, '0');
    final m = entry.timestamp.minute.toString().padLeft(2, '0');

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Card(
        color: AppColors.surface,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Farbiger Akzentbalken links
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
              // Inhalt
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(emoji,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(label,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('$h:$m',
                              style: const TextStyle(
                                  color: AppColors.text3, fontSize: 12)),
                        ],
                      ),
                      if (entry.text.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          entry.text,
                          style: const TextStyle(
                              color: AppColors.text2, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // Chips: Temperatur + Rating
                      if (entry.temperature != null ||
                          entry.activityRating != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (entry.temperature != null)
                              _chip(
                                '${entry.temperature!.toStringAsFixed(1)}°C',
                                tempColor(entry.temperature!),
                              ),
                            if (entry.activityRating != null)
                              _chip(
                                '⭐' * entry.activityRating!,
                                AppColors.gold,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Foto-Thumbnail
              if (entry.photoPath != null && !kIsWeb)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  child: Image.file(
                    File(entry.photoPath!),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 72),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
