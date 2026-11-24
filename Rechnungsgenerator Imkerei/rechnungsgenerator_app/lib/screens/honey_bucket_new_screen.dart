import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/honey_service.dart';
import '../utils/app_utils.dart';
import '../utils/bucket_code.dart';
import '../utils/feedback_service.dart';

/// Einen Eimer anlegen. Die App vergibt den Code – er wird hier schon
/// angezeigt, damit er gleich auf den Eimer geschrieben werden kann.
///
/// Die Vorbelegungen kommen aus einer Ernte-Maßnahme, wenn der Weg dort
/// beginnt: Sorte, Menge und Datum stehen dann schon fest.
class HoneyBucketNewScreen extends StatefulWidget {
  final String? initialVariety;
  final double? initialKg;
  final DateTime? initialDate;

  const HoneyBucketNewScreen({
    Key? key,
    this.initialVariety,
    this.initialKg,
    this.initialDate,
  }) : super(key: key);

  @override
  State<HoneyBucketNewScreen> createState() => _HoneyBucketNewScreenState();
}

class _HoneyBucketNewScreenState extends State<HoneyBucketNewScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);

  final _db = DatabaseService();
  final _honey = HoneyService();

  final _kg = TextEditingController();
  final _size = TextEditingController(text: '25');
  final _water = TextEditingController();
  final _varietyName = TextEditingController();
  final _location = TextEditingController();
  final _note = TextEditingController();

  String _variety = HoneyVarieties.summer;
  DateTime _date = DateTime.now();
  String _state = HoneyStates.fresh;

  /// Der Code, den dieser Eimer bekommen wird – aus der höchsten bisher
  /// vergebenen Nummer. Nur eine Vorschau: Vergeben wird er beim Speichern.
  int? _nextNumber;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Eimer anlegen');
    _variety = widget.initialVariety ?? HoneyVarieties.summer;
    _date = widget.initialDate ?? DateTime.now();
    if (widget.initialKg != null) {
      _kg.text = AppUtils.formatNumber(widget.initialKg!);
    }
    _loadNextNumber();
  }

  @override
  void dispose() {
    _kg.dispose();
    _size.dispose();
    _water.dispose();
    _varietyName.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadNextNumber() async {
    final hoechste = await _db.getHighestBucketNumber();
    if (!mounted) return;
    setState(() => _nextNumber = BucketCode.nextNumber(hoechste));
  }

  String get _codePreview => _nextNumber == null
      ? '…'
      : BucketCode.format(_variety, _nextNumber!);

  String? _nullable(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    final kg = AppUtils.parseNumber(_kg.text);
    if (kg == null || kg <= 0) {
      _snack('Wie viel Honig ist im Eimer?', err: true);
      return;
    }
    if (_variety == HoneyVarieties.other &&
        _nullable(_varietyName.text) == null) {
      _snack('Bei „Sonstige" bitte den Sortennamen eintragen', err: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final bucket = await _honey.createBucket(
        variety: _variety,
        varietyName: _variety == HoneyVarieties.other
            ? _nullable(_varietyName.text)
            : null,
        harvestDate: _date,
        filledKg: kg,
        bucketSizeKg: AppUtils.parseNumber(_size.text),
        waterContent: AppUtils.parseNumber(_water.text),
        state: _state,
        location: _nullable(_location.text),
        note: _nullable(_note.text),
      );
      if (!mounted) return;
      await _showCodeDialog(bucket);
      if (mounted) Navigator.of(context).pop(bucket);
    } catch (e) {
      FeedbackService.logError(e.toString(), context: 'HoneyBucketNew._save');
      _snack('Fehler: $e', err: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Nach dem Anlegen zeigen, was auf den Eimer zu schreiben ist. Dieser
  /// Schritt ist der ganze Zweck des Codes – er darf nicht untergehen.
  Future<void> _showCodeDialog(HoneyBucketModel bucket) async {
    final striche = HoneyStates.strokeHint(bucket.state);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jetzt auf den Eimer schreiben'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              bucket.code,
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2),
            ),
            const SizedBox(height: 10),
            Text(
              striche.isEmpty
                  ? 'Nur den Code – ein Kästchen kommt dazu, sobald der '
                      'Honig geimpft ist.'
                  : 'Dazu ein Kästchen mit $striche.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'Schrift oder Striche – die App erkennt beides wieder, '
              'solange die Ziffern lesbar bleiben.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: _peach, foregroundColor: Colors.white),
            child: const Text('Aufgeschrieben'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Wann geschleudert?',
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: err ? Colors.red : null),
    );
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: const TextStyle(
                color: _peach, fontSize: 14, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eimer anlegen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // Der Code steht oben, nicht am Ende: Er ist das, was gleich mit
          // dem Stift auf den Eimer kommt.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Text('Dieser Eimer bekommt den Code',
                      style: TextStyle(
                          fontSize: 10,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text(_codePreview,
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                  const SizedBox(height: 6),
                  const Text(
                    'Die Nummer läuft durch alle Sorten. Sind die '
                    'Buchstaben später verwischt, genügen die drei Ziffern.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 10, color: _muted, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          _section('Sorte'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in HoneyVarieties.all)
                ChoiceChip(
                  label: Text('$s · ${HoneyVarieties.labelOf(s)}',
                      style: const TextStyle(fontSize: 11)),
                  selected: _variety == s,
                  onSelected: (_) => setState(() => _variety = s),
                  selectedColor: _peach,
                  labelStyle: TextStyle(
                    color: _variety == s ? Colors.white : null,
                    fontWeight: _variety == s ? FontWeight.w600 : null,
                  ),
                ),
            ],
          ),
          if (_variety == HoneyVarieties.other) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _varietyName,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('Sortenname', hint: 'z.B. Phacelia'),
            ),
          ],
          const SizedBox(height: 18),

          _section('Geschleudert'),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined,
                size: 16, color: _peach),
            label: Text(AppUtils.formatDate(_date),
                style: const TextStyle(color: _peach)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _peach),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          const SizedBox(height: 18),

          _section('Menge'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kg,
                  autofocus: widget.initialKg == null,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _deco('Einwaage', hint: 'kg'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _size,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _deco('Gebinde', hint: 'kg'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _water,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _deco('Wassergehalt', hint: 'optional, in %'),
          ),
          const SizedBox(height: 18),

          _section('Zustand'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Beim Anlegen kommen nur die Zustände in Frage, in denen ein
              // frisch geschleuderter Eimer tatsächlich stehen kann.
              for (final z in const [
                HoneyStates.fresh,
                HoneyStates.toSeed,
                HoneyStates.seeded,
                HoneyStates.toStir,
                HoneyStates.readyToBottle,
              ])
                ChoiceChip(
                  label: Text(HoneyStates.labelOf(z),
                      style: const TextStyle(fontSize: 11)),
                  selected: _state == z,
                  onSelected: (_) => setState(() => _state = z),
                  selectedColor: _peach.withAlpha(51),
                ),
            ],
          ),
          const SizedBox(height: 18),

          _section('Sonstiges'),
          TextField(
            controller: _location,
            textCapitalization: TextCapitalization.sentences,
            decoration: _deco('Lagerplatz', hint: 'z.B. Keller Regal B3'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: _deco('Notiz', hint: 'optional'),
          ),
        ],
      ),
      floatingActionButton: _saving
          ? null
          : FloatingActionButton.extended(
              onPressed: _save,
              backgroundColor: _peach,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.check),
              label: const Text('Anlegen'),
            ),
    );
  }
}
