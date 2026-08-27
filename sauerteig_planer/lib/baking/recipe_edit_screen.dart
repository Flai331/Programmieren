import 'package:flutter/material.dart';
import 'baking_models.dart';
import 'recipe_storage.dart';
import '../app_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  REZEPT BEARBEITEN / NEU ERSTELLEN
// ═══════════════════════════════════════════════════════════════

class RecipeEditScreen extends StatefulWidget {
  final BakingRecipe? recipe;
  const RecipeEditScreen({super.key, this.recipe});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  late TextEditingController _nameCtrl;
  late List<BakingStep> _steps;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.recipe?.name ?? '');
    _steps = widget.recipe?.steps.map((s) => s.copyWith()).toList() ?? [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Rezeptnamen eingeben')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final recipe = BakingRecipe(
        id: widget.recipe?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        steps: _steps,
        lastUsed: widget.recipe?.lastUsed ?? DateTime.now(),
      );
      await RecipeStorage.save(recipe);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler beim Speichern — bitte erneut versuchen.'),
          backgroundColor: Color(0xFF2A1010),
        ),
      );
    }
  }

  void _addStep() {
    _showStepDialog(null);
  }

  void _editStep(int index) {
    _showStepDialog(index);
  }

  void _deleteStep(int index) {
    setState(() => _steps.removeAt(index));
  }

  void _showStepDialog(int? editIndex) {
    final step = editIndex != null ? _steps[editIndex] : null;
    final emojiCtrl = TextEditingController(text: step?.emoji ?? '⏱️');
    final nameCtrl = TextEditingController(text: step?.name ?? '');
    final descCtrl = TextEditingController(text: step?.description ?? '');
    int hours = step?.duration.inHours ?? 0;
    int minutes = step?.duration.inMinutes.remainder(60) ?? 5;
    int repeatCount = step?.repeatCount ?? 1;
    int repeatHours = step?.repeatInterval.inHours ?? 0;
    int repeatMinutes = step?.repeatInterval.inMinutes.remainder(60) ?? 0;
    bool useNativeTimer = step?.useNativeTimer ?? false;
    StepTemplate? selectedTemplate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  editIndex != null ? 'Schritt bearbeiten' : 'Schritt hinzufügen',
                  style: const TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Vorlage
                _label('Vorlage (optional)'),
                DropdownButtonFormField<StepTemplate?>(
                  value: selectedTemplate,
                  dropdownColor: AppColors.surface2,
                  style: const TextStyle(color: AppColors.text),
                  decoration: _inputDeco('Beispielschritt wählen...'),
                  items: [
                    const DropdownMenuItem<StepTemplate?>(
                      value: null,
                      child: Text('✏️  Freitext', style: TextStyle(color: AppColors.text2)),
                    ),
                    ...kStepTemplates.map((t) => DropdownMenuItem<StepTemplate?>(
                          value: t,
                          child: Text('${t.emoji}  ${t.name}',
                              style: const TextStyle(color: AppColors.text)),
                        )),
                  ],
                  onChanged: (t) {
                    setModal(() {
                      selectedTemplate = t;
                      if (t != null) {
                        emojiCtrl.text = t.emoji;
                        nameCtrl.text = t.name;
                        descCtrl.text = t.description;
                        hours = t.duration.inHours;
                        minutes = t.duration.inMinutes.remainder(60);
                        repeatCount = t.repeatCount;
                        repeatHours = t.repeatInterval.inHours;
                        repeatMinutes = t.repeatInterval.inMinutes.remainder(60);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Emoji
                _label('Emoji'),
                TextField(
                  controller: emojiCtrl,
                  style: const TextStyle(color: AppColors.text, fontSize: 22),
                  maxLength: 2,
                  decoration: _inputDeco('z.B. 🤲'),
                ),
                const SizedBox(height: 12),

                // Name
                _label('Name'),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppColors.text),
                  decoration: _inputDeco('z.B. Dehnen & Falten'),
                ),
                const SizedBox(height: 12),

                // Beschreibung
                _label('Beschreibung (optional)'),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: AppColors.text),
                  maxLines: 2,
                  decoration: _inputDeco('Kurze Beschreibung...'),
                ),
                const SizedBox(height: 12),

                // Dauer pro Runde
                _label('Dauer pro Runde'),
                _durationRow(
                  hours: hours,
                  minutes: minutes,
                  onHoursDec: hours > 0 ? () => setModal(() => hours--) : null,
                  onHoursInc: () => setModal(() => hours++),
                  onMinsDec: minutes > 0 ? () => setModal(() => minutes--) : null,
                  onMinsInc: minutes < 59 ? () => setModal(() => minutes++) : null,
                ),
                const SizedBox(height: 16),

                // Wiederholungen
                _label('Wiederholungen'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.gold),
                      onPressed: repeatCount > 1 ? () => setModal(() => repeatCount--) : null,
                    ),
                    Text('$repeatCount ×',
                        style: const TextStyle(color: AppColors.text, fontSize: 20)),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.gold),
                      onPressed: () => setModal(() => repeatCount++),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      repeatCount == 1 ? '(einmalig)' : 'Wiederholungen',
                      style: const TextStyle(color: AppColors.text3, fontSize: 12),
                    ),
                  ],
                ),

                // Pause zwischen Runden (nur wenn > 1 Wiederholung)
                if (repeatCount > 1) ...[
                  const SizedBox(height: 12),
                  _label('Pause zwischen Runden'),
                  _durationRow(
                    hours: repeatHours,
                    minutes: repeatMinutes,
                    onHoursDec: repeatHours > 0 ? () => setModal(() => repeatHours--) : null,
                    onHoursInc: () => setModal(() => repeatHours++),
                    onMinsDec: repeatMinutes > 0 ? () => setModal(() => repeatMinutes--) : null,
                    onMinsInc: repeatMinutes < 59 ? () => setModal(() => repeatMinutes++) : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    repeatHours == 0 && repeatMinutes == 0
                        ? 'Keine Pause — Runden direkt nacheinander'
                        : '$repeatCount× alle ${repeatHours > 0 ? "${repeatHours}h " : ""}${repeatMinutes > 0 ? "${repeatMinutes}min" : ""}',
                    style: const TextStyle(color: AppColors.gold, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 16),

                // Nativer Timer-Toggle
                SwitchListTile(
                  value: useNativeTimer,
                  onChanged: (v) => setModal(() => useNativeTimer = v),
                  title: const Text('Handy-Timer öffnen',
                      style: TextStyle(color: AppColors.text, fontSize: 14)),
                  subtitle: const Text('Öffnet die Uhr-App mit diesem Timer',
                      style: TextStyle(color: AppColors.text3, fontSize: 12)),
                  activeColor: AppColors.gold,
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 12),

                // Speichern
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final newStep = BakingStep(
                        id: step?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        emoji: emojiCtrl.text.trim().isEmpty ? '⏱️' : emojiCtrl.text.trim(),
                        name: name,
                        description: descCtrl.text.trim(),
                        duration: Duration(hours: hours, minutes: minutes),
                        useNativeTimer: useNativeTimer,
                        repeatCount: repeatCount,
                        repeatInterval: Duration(hours: repeatHours, minutes: repeatMinutes),
                      );
                      setState(() {
                        if (editIndex != null) {
                          _steps[editIndex] = newStep;
                        } else {
                          _steps.add(newStep);
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                    ),
                    child: const Text('Speichern'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _durationRow({
    required int hours,
    required int minutes,
    required VoidCallback? onHoursDec,
    required VoidCallback? onHoursInc,
    required VoidCallback? onMinsDec,
    required VoidCallback? onMinsInc,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Stunden', style: TextStyle(color: AppColors.text3, fontSize: 12)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: AppColors.gold),
                    onPressed: onHoursDec,
                  ),
                  Text('$hours', style: const TextStyle(color: AppColors.text, fontSize: 20)),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.gold),
                    onPressed: onHoursInc,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Text(':', style: TextStyle(color: AppColors.text2, fontSize: 24)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Minuten', style: TextStyle(color: AppColors.text3, fontSize: 12)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: AppColors.gold),
                    onPressed: onMinsDec,
                  ),
                  Text('$minutes', style: const TextStyle(color: AppColors.text, fontSize: 20)),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.gold),
                    onPressed: onMinsInc,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.text3),
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        counterText: '',
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: AppColors.text2, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          widget.recipe == null ? 'Neues Rezept' : 'Rezept bearbeiten',
          style: const TextStyle(color: AppColors.gold),
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Speichern', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Rezept-Name
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.text, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Rezeptname',
                labelStyle: const TextStyle(color: AppColors.text2),
                hintText: 'z.B. Roggenbrot',
                hintStyle: const TextStyle(color: AppColors.text3),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ),

          // Schritte-Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Text('Schritte', style: TextStyle(color: AppColors.text2, fontSize: 13)),
                const Spacer(),
                Text('${_steps.length} Schritt(e)', style: const TextStyle(color: AppColors.text3, fontSize: 12)),
              ],
            ),
          ),

          // Reorderable Schritte-Liste
          Expanded(
            child: _steps.isEmpty
                ? _buildEmptySteps()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onReorder: (oldIdx, newIdx) {
                      setState(() {
                        if (newIdx > oldIdx) newIdx--;
                        final item = _steps.removeAt(oldIdx);
                        _steps.insert(newIdx, item);
                      });
                    },
                    itemCount: _steps.length,
                    itemBuilder: (_, i) {
                      final s = _steps[i];
                      return _StepTile(
                        key: ValueKey(s.id),
                        step: s,
                        index: i,
                        onEdit: () => _editStep(i),
                        onDelete: () => _deleteStep(i),
                      );
                    },
                  ),
          ),

          // Schritt hinzufügen
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add, color: AppColors.gold),
                label: const Text('Schritt hinzufügen', style: TextStyle(color: AppColors.gold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.gold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySteps() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📋', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('Noch keine Schritte', style: TextStyle(color: AppColors.text2)),
          SizedBox(height: 4),
          Text('Tippe auf „Schritt hinzufügen"', style: TextStyle(color: AppColors.text3, fontSize: 13)),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final BakingStep step;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StepTile({
    super.key,
    required this.step,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: Text('${index + 1}', style: const TextStyle(color: AppColors.text3, fontSize: 13)),
        title: Row(
          children: [
            Text(step.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(step.name, style: const TextStyle(color: AppColors.text)),
            ),
          ],
        ),
        subtitle: Text(
          step.repeatCount > 1
              ? '${step.repeatCount}× ${formatDuration(step.duration)}'
                  '${step.repeatInterval > Duration.zero ? " · alle ${formatDuration(step.repeatInterval)}" : ""}'
              : formatDuration(step.duration),
          style: const TextStyle(color: AppColors.gold, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.text3, size: 18),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 18),
              onPressed: onDelete,
            ),
            const Icon(Icons.drag_handle, color: AppColors.text3),
          ],
        ),
      ),
    );
  }
}
