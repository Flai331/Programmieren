// ═══════════════════════════════════════════════════════════════
//  MEINE STARTER — Screen
//  lib/starter/my_starters_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../untils/feedback_service.dart';
import 'my_starter_models.dart';
import 'my_starter_storage.dart';
import 'starter_models.dart' show kFlourOptions;

class MyStartersScreen extends StatefulWidget {
  const MyStartersScreen({super.key});

  @override
  State<MyStartersScreen> createState() => _MyStartersScreenState();
}

class _MyStartersScreenState extends State<MyStartersScreen> {
  List<MyStarter> _starters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await MyStarterStorage.loadAll();
    if (mounted) setState(() { _starters = list; _loading = false; });
  }

  Future<void> _addStarter() async {
    final result = await showModalBottomSheet<MyStarter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _AddStarterSheet(),
    );
    if (result == null) return;
    await MyStarterStorage.save(result);
    FeedbackService.log('MyStarter: "${result.name}" hinzugefügt (${result.gramAmount}g)');
    _load();
  }

  Future<void> _feedStarter(MyStarter starter) async {
    final result = await showModalBottomSheet<StarterFeedingLog>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _FeedSheet(starter: starter),
    );
    if (result == null) return;
    final updated = starter.copyWith(
      gramAmount: result.totalAfter,
      feedings: [...starter.feedings, result],
    );
    await MyStarterStorage.save(updated);
    FeedbackService.log('MyStarter: "${starter.name}" gefüttert → ${result.totalAfter}g');
    _load();
  }

  Future<void> _deleteStarter(MyStarter starter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('„${starter.name}" löschen?',
            style: const TextStyle(color: AppColors.text, fontSize: 16)),
        content: const Text('Der Starter und sein Protokoll werden entfernt.',
            style: TextStyle(color: AppColors.text2, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.text3))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await MyStarterStorage.delete(starter.id);
    FeedbackService.log('MyStarter: "${starter.name}" gelöscht');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: const BackButton(color: AppColors.text2),
        title: const Text('🫙 Meine Starter',
            style: TextStyle(color: AppColors.gold, fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStarter,
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.add),
        label: const Text('Starter hinzufügen',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _starters.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🫙', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('Noch keine Starter',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Füge deinen fertigen Sauerteig-Starter hinzu, '
              'um ihn zu pflegen und im Planer zu verwenden.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text2, fontSize: 13, height: 1.5),
            ),
          ]),
        ),
      );

  Widget _buildList() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _starters.length,
        itemBuilder: (_, i) => _StarterCard(
          starter: _starters[i],
          onFeed: () => _feedStarter(_starters[i]),
          onDelete: () => _deleteStarter(_starters[i]),
        ),
      );
}

// ── Starter-Karte ────────────────────────────────────────────────

class _StarterCard extends StatelessWidget {
  final MyStarter starter;
  final VoidCallback onFeed;
  final VoidCallback onDelete;

  const _StarterCard({
    required this.starter,
    required this.onFeed,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final days = starter.daysSinceLastFed;
    final needsFeeding = starter.needsFeeding;
    final lastFed = starter.lastFed;

    String lastFedLabel;
    if (lastFed == null) {
      lastFedLabel = 'Noch nie gefüttert';
    } else if (days == 0) {
      lastFedLabel = 'Heute gefüttert';
    } else if (days == 1) {
      lastFedLabel = 'Gestern gefüttert';
    } else {
      lastFedLabel = 'Vor $days Tagen gefüttert';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: needsFeeding
              ? AppColors.orange.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(starter.name,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                if (starter.flourType != null || starter.origin != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (starter.flourType != null) starter.flourType!,
                      if (starter.origin != null) starter.origin!,
                    ].join(' · '),
                    style: const TextStyle(color: AppColors.text3, fontSize: 12),
                  ),
                ],
              ]),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, color: AppColors.text3, size: 20),
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // Stats
          Row(children: [
            _Stat(
              emoji: '⚖️',
              label: 'Im Kühlschrank',
              value: '${starter.gramAmount} g',
              color: AppColors.blue,
            ),
            const SizedBox(width: 12),
            _Stat(
              emoji: needsFeeding ? '⚠️' : '✅',
              label: 'Letzte Fütterung',
              value: lastFedLabel,
              color: needsFeeding ? AppColors.orange : AppColors.green,
            ),
          ]),

          if (needsFeeding) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.orange, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    lastFed == null
                        ? 'Starter wurde noch nie gefüttert'
                        : 'Fütterung fällig! Starter braucht wöchentliche Pflege.',
                    style: const TextStyle(
                        color: AppColors.orange, fontSize: 11),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 12),

          // Füttern-Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onFeed,
              icon: const Icon(Icons.restaurant, size: 16),
              label: const Text('Füttern (1:1:1)'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    needsFeeding ? AppColors.orange : AppColors.green,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          // Letzten Einträge
          if (starter.feedings.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 8),
            Text('Letzte ${starter.feedings.length > 3 ? 3 : starter.feedings.length} Fütterungen:',
                style: const TextStyle(color: AppColors.text3, fontSize: 11)),
            const SizedBox(height: 4),
            ...starter.feedings.reversed.take(3).map((f) {
              final d = f.date;
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  Text(
                    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
                    style: const TextStyle(color: AppColors.text3, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${f.kept}g behalten + ${f.flour}g Mehl + ${f.water}g Wasser → ${f.totalAfter}g',
                      style: const TextStyle(color: AppColors.text2, fontSize: 11),
                    ),
                  ),
                ]),
              );
            }),
          ],
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;

  const _Stat(
      {required this.emoji,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: AppColors.text3, fontSize: 10)),
          const SizedBox(height: 2),
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      );
}

// ── Sheet: Starter hinzufügen ────────────────────────────────────

class _AddStarterSheet extends StatefulWidget {
  const _AddStarterSheet();

  @override
  State<_AddStarterSheet> createState() => _AddStarterSheetState();
}

class _AddStarterSheetState extends State<_AddStarterSheet> {
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController(text: '100');
  final _originCtrl = TextEditingController();
  String? _flourType;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _originCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text) ?? 0;
    if (name.isEmpty || amount <= 0) return;

    final starter = MyStarter.create(
      name: name,
      flourType: _flourType,
      origin: _originCtrl.text.trim().isEmpty ? null : _originCtrl.text.trim(),
      gramAmount: amount,
    );
    Navigator.pop(context, starter);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Starter hinzufügen',
            style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 20),

        _SheetField(
          label: 'Name',
          hint: 'z.B. Roggen-Starter, Max',
          ctrl: _nameCtrl,
        ),
        const SizedBox(height: 12),

        // Mehltyp
        DropdownButtonFormField<String>(
          value: _flourType,
          hint: const Text('Mehltyp (optional)',
              style: TextStyle(color: AppColors.text3, fontSize: 13)),
          dropdownColor: AppColors.surface2,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: _inputDecoration(),
          items: kFlourOptions
              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
              .toList(),
          onChanged: (v) => setState(() => _flourType = v),
        ),
        const SizedBox(height: 12),

        _SheetField(
          label: 'Herkunft (optional)',
          hint: 'z.B. Selbst gezüchtet, Von Oma',
          ctrl: _originCtrl,
        ),
        const SizedBox(height: 12),

        Row(children: [
          const Expanded(
            child: Text('Aktuelle Menge',
                style: TextStyle(color: AppColors.text2, fontSize: 13)),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: _inputDecoration(suffix: 'g'),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Speichern',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ── Sheet: Füttern ───────────────────────────────────────────────

class _FeedSheet extends StatefulWidget {
  final MyStarter starter;
  const _FeedSheet({required this.starter});

  @override
  State<_FeedSheet> createState() => _FeedSheetState();
}

class _FeedSheetState extends State<_FeedSheet> {
  late final TextEditingController _keptCtrl;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Standard: 20g behalten (typische Kühlschrankpflege)
    _keptCtrl = TextEditingController(text: '20');
  }

  @override
  void dispose() {
    _keptCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _kept   => int.tryParse(_keptCtrl.text) ?? 0;
  int get _flour  => _kept;
  int get _water  => _kept;
  int get _total  => _kept * 3;

  void _submit() {
    if (_kept <= 0) return;
    final log = StarterFeedingLog(
      date: DateTime.now(),
      kept: _kept,
      flour: _flour,
      water: _water,
      totalAfter: _total,
      notes: _notesCtrl.text.trim(),
    );
    Navigator.pop(context, log);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🫙 ${widget.starter.name} füttern',
            style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 4),
        Text('Aktuell im Kühlschrank: ${widget.starter.gramAmount} g',
            style: const TextStyle(color: AppColors.text3, fontSize: 12)),
        const SizedBox(height: 20),

        // Behalten-Eingabe
        Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Behalten (Anstellgut)',
                  style: TextStyle(color: AppColors.text2, fontSize: 13)),
              Text('Rest wegwerfen oder verschenken',
                  style: TextStyle(color: AppColors.text3, fontSize: 11)),
            ]),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _keptCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: _inputDecoration(suffix: 'g'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        // Ergebnis
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
          ),
          child: Column(children: [
            const Text('Zugeben (1:1:1)',
                style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 10),
            _FeedRow('🍞 Mehl', '$_flour g'),
            const SizedBox(height: 4),
            _FeedRow('💧 Wasser', '$_water g'),
            const Divider(color: AppColors.border, height: 16),
            _FeedRow('⚖️ Gesamt danach', '$_total g', bold: true),
          ]),
        ),

        const SizedBox(height: 12),

        _SheetField(
          label: 'Notiz (optional)',
          hint: 'z.B. Rieht gut, sehr aktiv',
          ctrl: _notesCtrl,
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Fütterung speichern',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class _FeedRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _FeedRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: bold ? AppColors.text : AppColors.text2,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ),
        Text(value,
            style: TextStyle(
                color: bold ? AppColors.gold : AppColors.text,
                fontWeight: FontWeight.bold,
                fontSize: bold ? 15 : 13)),
      ]);
}

// ── Gemeinsame Hilfswidgets ──────────────────────────────────────

class _SheetField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;
  const _SheetField({required this.label, required this.hint, required this.ctrl});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        decoration: _inputDecoration(hint: hint, label: label),
      );
}

InputDecoration _inputDecoration({String? hint, String? label, String? suffix}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.text3, fontSize: 13),
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.text3, fontSize: 13),
      suffixText: suffix,
      suffixStyle: const TextStyle(color: AppColors.text3, fontSize: 13),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gold),
      ),
    );
