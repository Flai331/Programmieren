import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../app_colors.dart';
import '../untils/feedback_service.dart';
import '../untils/temp_utils.dart';
import 'diary_models.dart';
import 'diary_storage.dart';

// ═══════════════════════════════════════════════════════════════
//  DIARY ENTRY EDIT SCREEN — Erstellen / Bearbeiten
// ═══════════════════════════════════════════════════════════════

class DiaryEntryEditScreen extends StatefulWidget {
  final DiaryEntry? entry;

  const DiaryEntryEditScreen({super.key, this.entry});

  @override
  State<DiaryEntryEditScreen> createState() => _DiaryEntryEditScreenState();
}

class _DiaryEntryEditScreenState extends State<DiaryEntryEditScreen> {
  late DiaryEntryType _type;
  late DateTime _timestamp;
  late TextEditingController _textController;
  late TextEditingController _tempController;
  int? _rating;
  String? _photoPath;
  String? _oldPhotoPath;
  bool _photoChanged = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _type = e?.type ?? DiaryEntryType.feeding;
    _timestamp = e?.timestamp ?? DateTime.now();
    _textController = TextEditingController(text: e?.text ?? '');
    _tempController = TextEditingController(
        text: e?.temperature?.toStringAsFixed(1) ?? '');
    _rating = e?.activityRating;
    _photoPath = e?.photoPath;
    _oldPhotoPath = e?.photoPath;
  }

  @override
  void dispose() {
    _textController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    FeedbackService.log('Tagebuch: Foto aufnehmen via ${source == ImageSource.camera ? 'Kamera' : 'Galerie'}');
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
          source: source, imageQuality: 80, maxWidth: 1200);
      if (xFile == null) {
        FeedbackService.log('Tagebuch: Foto-Auswahl abgebrochen');
        return;
      }

      // Speichere in App-Verzeichnis
      final savedPath = await DiaryStorage.savePhoto(xFile.path);
      if (savedPath != null) {
        FeedbackService.log('Tagebuch: Foto gespeichert → $savedPath');
        setState(() {
          _photoPath = savedPath;
          _photoChanged = true;
        });
      } else {
        FeedbackService.log('Tagebuch: Foto-Speichern fehlgeschlagen (savedPath null)');
      }
    } catch (e, stack) {
      FeedbackService.log('Tagebuch: Fehler beim Foto-Aufnehmen: $e\n$stack');
    }
  }

  Future<void> _removePhoto() async {
    setState(() {
      _photoPath = null;
      _photoChanged = true;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.orange,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.orange,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    setState(() {
      _timestamp = DateTime(
        picked.year,
        picked.month,
        picked.day,
        pickedTime?.hour ?? _timestamp.hour,
        pickedTime?.minute ?? _timestamp.minute,
      );
    });
  }

  Future<void> _save() async {
    final tempText = _tempController.text.trim();
    final temp =
        tempText.isEmpty ? null : double.tryParse(tempText.replaceAll(',', '.'));

    final isNew = widget.entry == null;
    FeedbackService.log(
      'Tagebuch-Eintrag ${isNew ? 'erstellt' : 'bearbeitet'}: '
      'Typ=${kEntryTypeLabel[_type]}, '
      'Temp=${temp != null ? '$temp°C' : 'keine'}, '
      'Rating=$_rating, '
      'Foto=${_photoPath != null ? 'ja' : 'nein'}, '
      'Text=${_textController.text.trim().length} Zeichen',
    );

    // Altes Foto löschen wenn geändert
    if (_photoChanged && _oldPhotoPath != null && _oldPhotoPath != _photoPath) {
      await DiaryStorage.deletePhoto(_oldPhotoPath!);
    }

    final entry = (widget.entry ?? DiaryEntry.create(_type)).copyWith(
      timestamp: _timestamp,
      type: _type,
      text: _textController.text.trim(),
      temperature: temp,
      clearTemp: temp == null,
      activityRating: _rating,
      clearRating: _rating == null,
      photoPath: _photoPath,
      clearPhoto: _photoPath == null,
    );

    await DiaryStorage.save(entry);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.entry == null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(isNew ? 'Neuer Eintrag' : 'Eintrag bearbeiten',
            style: const TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: AppColors.gold),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Speichern',
                style: TextStyle(
                    color: AppColors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Typ-Auswahl
          _sectionLabel('Art des Eintrags'),
          Wrap(
            spacing: 8,
            children: DiaryEntryType.values.map((t) {
              final selected = _type == t;
              final color = kEntryTypeColor[t] ?? AppColors.text2;
              return ChoiceChip(
                label: Text(
                  '${kEntryTypeEmoji[t]} ${kEntryTypeLabel[t]}',
                  style: TextStyle(
                    color: selected ? AppColors.bg : color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: selected,
                selectedColor: color,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                    color: selected ? color : AppColors.border),
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Datum / Uhrzeit
          _sectionLabel('Zeitpunkt'),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      color: AppColors.text3, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    _formatDateTime(_timestamp),
                    style: const TextStyle(color: AppColors.text),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit, color: AppColors.text3, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Text
          _sectionLabel('Notiz'),
          // Quick-Chips
          if ((kQuickEntries[_type] ?? []).isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (kQuickEntries[_type] ?? [])
                  .map((chip) => ActionChip(
                        label: Text(chip,
                            style: const TextStyle(
                                color: AppColors.text2, fontSize: 12)),
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                        onPressed: () {
                          final current =
                              _textController.text.trim();
                          _textController.text = current.isEmpty
                              ? chip
                              : '$current\n$chip';
                          _textController.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                                offset: _textController.text.length),
                          );
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _textController,
            maxLines: 5,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Was hast du beobachtet?',
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
                borderSide: const BorderSide(color: AppColors.orange),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Temperatur
          _sectionLabel('Temperatur (optional)'),
          TextField(
            controller: _tempController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.text),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'z.B. 22.5',
              hintStyle: const TextStyle(color: AppColors.text3),
              suffixText: '°C',
              suffixStyle: TextStyle(
                color: () {
                  final t = double.tryParse(
                      _tempController.text.replaceAll(',', '.'));
                  return t != null ? tempColor(t) : AppColors.text3;
                }(),
              ),
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
            ),
          ),

          const SizedBox(height: 20),

          // Aktivitäts-Rating
          _sectionLabel('Aktivität des Starters'),
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                onPressed: () =>
                    setState(() => _rating = _rating == star ? null : star),
                icon: Icon(
                  _rating != null && star <= _rating!
                      ? Icons.star
                      : Icons.star_border,
                  color: AppColors.gold,
                ),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }),
          ),

          // Foto (nur auf Nicht-Web)
          if (!kIsWeb) ...[
            const SizedBox(height: 20),
            _sectionLabel('Foto (optional)'),
            if (_photoPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_photoPath!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _removePhoto,
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                label: const Text('Foto entfernen',
                    style: TextStyle(color: AppColors.red)),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Kamera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text2,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Galerie'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text2,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Speichern',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.orange,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$day.$month.${d.year}, $h:$m Uhr';
  }
}
