import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_colors.dart';
import '../diary/diary_storage.dart';
import '../untils/feedback_service.dart';
import '../untils/temp_utils.dart';
import 'starter_models.dart';
import 'starter_storage.dart';

// ═══════════════════════════════════════════════════════════════
//  STARTER DAY SCREEN — Tages-Checkliste
// ═══════════════════════════════════════════════════════════════

class StarterDayScreen extends StatefulWidget {
  final StarterJourney journey;
  final int dayIndex;

  const StarterDayScreen({
    super.key,
    required this.journey,
    required this.dayIndex,
  });

  @override
  State<StarterDayScreen> createState() => _StarterDayScreenState();
}

class _StarterDayScreenState extends State<StarterDayScreen> {
  late StarterDayLog _day;
  late StarterJourney _journey;
  final _noteController = TextEditingController();
  final _tempController = TextEditingController();
  String? _photoPath; // gespeicherter Pfad im App-Verzeichnis
  String? _selectedFlour;

  static const _quickChips = [
    'Bläschen sichtbar',
    'Säuerlicher Geruch',
    'Volumen verdoppelt',
    'Oberfläche gewölbt',
    'Graue Flüssigkeit oben (Hunger)',
    'Schöne Aktivität',
  ];

  @override
  void initState() {
    super.initState();
    _journey = widget.journey;
    _day = _journey.days[widget.dayIndex];
    _noteController.text = _day.notes;
    _photoPath = _day.photoPath;
    _selectedFlour = _day.flourType ?? _journey.flourType;
    if (_day.temperature != null) {
      _tempController.text = _day.temperature!.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tempText = _tempController.text.trim();
    final temp =
        tempText.isEmpty ? null : double.tryParse(tempText.replaceAll(',', '.'));

    final doneTasks = _day.checks.values.where((v) => v).length;
    FeedbackService.log(
      'Starter Tag ${_day.dayNumber} gespeichert: $doneTasks/${_day.checks.length} Aufgaben, '
      'Temp=${temp != null ? '$temp°C' : 'keine'}, '
      'Notiz=${_noteController.text.trim().isNotEmpty ? 'ja' : 'nein'}',
    );

    final updated = _day.copyWith(
      notes: _noteController.text.trim(),
      temperature: temp,
      photoPath: _photoPath,
      clearPhoto: _photoPath == null,
      flourType: _selectedFlour,
    );

    final newDays = List<StarterDayLog>.from(_journey.days);
    newDays[widget.dayIndex] = updated;
    final newJourney = _journey.copyWith(days: newDays);

    await StarterStorage.save(newJourney);
    setState(() {
      _day = updated;
      _journey = newJourney;
    });
  }

  Future<void> _toggleCheck(StarterDayActivity activity, bool value) async {
    final newChecks = Map<StarterDayActivity, bool>.from(_day.checks);
    newChecks[activity] = value;
    final updated = _day.copyWith(checks: newChecks);

    final newDays = List<StarterDayLog>.from(_journey.days);
    newDays[widget.dayIndex] = updated;
    final newJourney = _journey.copyWith(days: newDays);

    await StarterStorage.save(newJourney);
    setState(() {
      _day = updated;
      _journey = newJourney;
    });
  }

  Future<void> _setFloatTest(bool passed) async {
    FeedbackService.log('Starter Tag ${_day.dayNumber} Float-Test: ${passed ? 'geschwommen ✓' : 'gesunken ✗'}');
    final updated = _day.copyWith(
      floatTestDone: true,
      floatTestPassed: passed,
    );
    final newDays = List<StarterDayLog>.from(_journey.days);
    newDays[widget.dayIndex] = updated;
    final newJourney = _journey.copyWith(days: newDays);

    await StarterStorage.save(newJourney);
    setState(() {
      _day = updated;
      _journey = newJourney;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (kIsWeb) return;
    try {
      final xFile = await ImagePicker()
          .pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (xFile == null) return;
      final saved = await DiaryStorage.savePhoto(xFile.path);
      if (saved != null) setState(() => _photoPath = saved);
    } catch (_) {}
  }

  Future<void> _removePhoto() async {
    if (_photoPath != null) await DiaryStorage.deletePhoto(_photoPath!);
    setState(() => _photoPath = null);
  }

  void _addQuickChip(String text) {
    final current = _noteController.text.trim();
    _noteController.text =
        current.isEmpty ? text : '$current\n$text';
    _noteController.selection = TextSelection.fromPosition(
      TextPosition(offset: _noteController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFloatTest = _day.dayNumber >= 5;
    final description =
        kDayDescriptions[_day.dayNumber] ?? 'Kontrolliere deinen Starter heute.';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Tag ${_day.dayNumber}',
            style: const TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: AppColors.gold),
        actions: [
          TextButton(
            onPressed: () async {
              await _save();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Speichern',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Beschreibung
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(description,
                style: const TextStyle(
                    color: AppColors.text2, height: 1.5)),
          ),
          const SizedBox(height: 20),

          // Checkliste
          _sectionTitle('Aufgaben'),
          ...StarterDayActivity.values.expand((activity) {
            final tile = CheckboxListTile(
              value: _day.checks[activity] ?? false,
              onChanged: (v) => _toggleCheck(activity, v ?? false),
              title: Text(
                '${kActivityEmojis[activity]} ${kActivityLabelsForDay(_day.dayNumber)[activity]}',
                style: const TextStyle(color: AppColors.text),
              ),
              activeColor: AppColors.green,
              checkColor: AppColors.bg,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            );
            if (activity == StarterDayActivity.feeding &&
                (_day.checks[StarterDayActivity.feeding] == true)) {
              return [
                tile,
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4, bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: kFlourOptions
                        .map((flour) => ChoiceChip(
                              label: Text(flour,
                                  style: const TextStyle(fontSize: 12)),
                              selected: _selectedFlour == flour,
                              onSelected: (sel) => setState(
                                  () => _selectedFlour = sel ? flour : null),
                              selectedColor:
                                  AppColors.gold.withValues(alpha: 0.3),
                              labelStyle: TextStyle(
                                color: _selectedFlour == flour
                                    ? AppColors.gold
                                    : AppColors.text2,
                              ),
                              backgroundColor: AppColors.surface2,
                              side: BorderSide(
                                color: _selectedFlour == flour
                                    ? AppColors.gold
                                    : AppColors.border,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ];
            }
            return [tile];
          }),

          const SizedBox(height: 20),

          // Temperatur
          _sectionTitle('Temperatur'),
          TextField(
            controller: _tempController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.text),
            onChanged: (_) {
              final t = double.tryParse(
                  _tempController.text.replaceAll(',', '.'));
              if (t != null) setState(() {});
            },
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

          // Float-Test (ab Tag 5)
          if (showFloatTest) ...[
            const SizedBox(height: 20),
            _sectionTitle('Float-Test 🥄'),
            const Text(
              'Lege einen Teelöffel Starter in ein Glas Wasser. '
              'Schwimmt er, ist er backbereit!',
              style: TextStyle(color: AppColors.text3, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (_day.floatTestDone) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: _day.floatTestPassed
                      ? AppColors.green.withValues(alpha: 0.15)
                      : AppColors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _day.floatTestPassed
                        ? AppColors.green
                        : AppColors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _day.floatTestPassed
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: _day.floatTestPassed
                          ? AppColors.green
                          : AppColors.red,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _day.floatTestPassed
                            ? 'Geschwommen ✓ – Starter ist aktiv!'
                            : 'Gesunken ✗ – Noch etwas Geduld',
                        style: TextStyle(
                          color: _day.floatTestPassed
                              ? AppColors.green
                              : AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  _day = _day.copyWith(floatTestDone: false);
                }),
                child: const Text('Ergebnis ändern',
                    style: TextStyle(color: AppColors.text3)),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _setFloatTest(true),
                      icon: const Icon(Icons.water_drop),
                      label: const Text('Geschwommen ✓'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.bg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _setFloatTest(false),
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('Gesunken ✗'),
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

          const SizedBox(height: 20),

          // Notizen
          _sectionTitle('Notizen'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickChips
                .map((chip) => ActionChip(
                      label: Text(chip,
                          style: const TextStyle(
                              color: AppColors.text2, fontSize: 12)),
                      backgroundColor: AppColors.surface2,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () => _addQuickChip(chip),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 4,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Beobachtungen, Geruch, Farbe ...',
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
            ),
          ),
          const SizedBox(height: 20),

          // Foto
          _sectionTitle('Foto'),
          if (_photoPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(_photoPath!),
                  width: double.infinity, height: 180, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _removePhoto,
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.red, size: 18),
              label: const Text('Foto entfernen',
                  style: TextStyle(color: AppColors.red, fontSize: 13)),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Kamera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text2,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
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

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await _save();
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Speichern & Zurück',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.green,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
