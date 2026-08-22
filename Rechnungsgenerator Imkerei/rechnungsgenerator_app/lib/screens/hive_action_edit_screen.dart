import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../utils/app_utils.dart';
import '../utils/feedback_service.dart';
import '../utils/photo_storage.dart';

/// Maßnahme an einem Volk erfassen oder bearbeiten.
class HiveActionEditScreen extends StatefulWidget {
  final String hiveId;
  final String hiveLabel;

  /// Null = neue Maßnahme.
  final String? actionId;

  /// Vorauswahl des Typs beim Anlegen (Schnellzugriff aus der Timeline).
  final String? initialType;

  const HiveActionEditScreen({
    Key? key,
    required this.hiveId,
    required this.hiveLabel,
    this.actionId,
    this.initialType,
  }) : super(key: key);

  @override
  State<HiveActionEditScreen> createState() => _HiveActionEditScreenState();
}

class _HiveActionEditScreenState extends State<HiveActionEditScreen> {
  final _db = DatabaseService();
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);

  final _note = TextEditingController();
  final _broodFrames = TextEditingController();
  final _beeFrames = TextEditingController();
  final _amount = TextEditingController();
  final _unit = TextEditingController();
  final _treatment = TextEditingController();

  String _type = HiveActionTypes.inspection;
  DateTime _date = DateTime.now();
  int? _temper;
  bool _queenSeen = false;
  bool _swarmCells = false;

  /// Dateinamen in der App-Ablage
  List<String> _photos = [];

  /// Beim Bearbeiten entfernte Fotos – erst beim Speichern wirklich löschen.
  final List<String> _removedPhotos = [];

  HiveActionModel? _current;
  bool _loading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Maßnahme');
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.actionId != null) {
        _current = await _db.getHiveAction(widget.actionId!);
        if (_current != null) _populate(_current!);
      } else {
        _type = widget.initialType ?? HiveActionTypes.inspection;
        _unit.text = HiveActionTypes.defaultUnitOf(_type);
      }
    } catch (e) {
      _snack('Fehler beim Laden: $e', err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populate(HiveActionModel a) {
    _type = a.type;
    _date = a.date;
    _note.text = a.note ?? '';
    _broodFrames.text = a.broodFrames?.toString() ?? '';
    _beeFrames.text = a.beeFrames?.toString() ?? '';
    _amount.text = a.amount == null
        ? ''
        : AppUtils.formatNumber(a.amount!);
    _unit.text = a.unit ?? HiveActionTypes.defaultUnitOf(a.type);
    _treatment.text = a.treatment ?? '';
    _temper = a.temper;
    _queenSeen = a.queenSeen ?? false;
    _swarmCells = a.swarmCells ?? false;
    _photos = List.of(a.photoPaths);
  }

  String? _nullable(String s) => s.trim().isEmpty ? null : s.trim();

  HiveActionModel _buildModel() {
    final metrics = HiveActionTypes.hasColonyMetrics(_type);
    final withAmount = HiveActionTypes.hasAmount(_type);
    final withTreatment = HiveActionTypes.hasTreatment(_type);
    return HiveActionModel(
      id: _current?.id ?? const Uuid().v4(),
      hiveId: widget.hiveId,
      date: _date,
      type: _type,
      note: _nullable(_note.text),
      // Nur Felder speichern, die zum gewählten Typ gehören – sonst bleiben
      // beim Typwechsel Werte des vorherigen Typs am Datensatz hängen.
      broodFrames: metrics ? int.tryParse(_broodFrames.text) : null,
      beeFrames: metrics ? int.tryParse(_beeFrames.text) : null,
      temper: metrics ? _temper : null,
      queenSeen: metrics ? _queenSeen : null,
      swarmCells: metrics ? _swarmCells : null,
      amount: withAmount ? AppUtils.parseNumber(_amount.text) : null,
      unit: withAmount ? _nullable(_unit.text) : null,
      treatment: withTreatment ? _nullable(_treatment.text) : null,
      photoPaths: _photos,
      createdAt: _current?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final action = _buildModel();
      if (_current == null) {
        await _db.insertHiveAction(action);
      } else {
        await _db.updateHiveAction(action);
      }
      // Erst nach erfolgreichem Speichern die entfernten Fotos löschen.
      for (final name in _removedPhotos) {
        await PhotoStorage.delete(name);
      }
      FeedbackService.logUserAction('Maßnahme gespeichert',
          context: {'typ': _type});
      if (mounted) {
        _snack('✓ Maßnahme gespeichert');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      FeedbackService.logError(e.toString(), context: 'HiveActionEdit._save');
      _snack('Fehler: $e', err: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (_current == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Maßnahme löschen'),
        content: Text(
            '„${_current!.typeLabel}" vom ${AppUtils.formatDate(_current!.date)} wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen',
                style: TextStyle(color: Color(0xFFff6b7a))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.deleteHiveAction(_current!.id);
      for (final name in _current!.photoPaths) {
        await PhotoStorage.delete(name);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Datum der Maßnahme',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final name = await PhotoStorage.save(picked.path);
      if (mounted) setState(() => _photos = [..._photos, name]);
    } catch (e) {
      _snack('Foto konnte nicht übernommen werden: $e', err: true);
    }
  }

  void _showPhotoSourceChooser() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _peach),
              title: const Text('Foto aufnehmen'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _peach),
              title: const Text('Aus Galerie wählen'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removePhoto(String name) {
    setState(() {
      _photos = _photos.where((p) => p != name).toList();
      _removedPhotos.add(name);
    });
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maßnahme')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final metrics = HiveActionTypes.hasColonyMetrics(_type);
    final withAmount = HiveActionTypes.hasAmount(_type);
    final withTreatment = HiveActionTypes.hasTreatment(_type);

    return Scaffold(
      appBar: AppBar(
        title: Text(_current == null ? 'Neue Maßnahme' : 'Maßnahme'),
        actions: [
          if (_current != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFff6b7a)),
              tooltip: 'Löschen',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.hiveLabel,
              style: const TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 16),

          _section('Art der Maßnahme'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in HiveActionTypes.all)
                ChoiceChip(
                  label: Text(HiveActionTypes.labelOf(t)),
                  selected: _type == t,
                  onSelected: (_) => setState(() {
                    _type = t;
                    // Einheit passend zum neuen Typ vorbelegen, sofern der
                    // Nutzer noch keine eigene eingetragen hat.
                    final vorschlag = HiveActionTypes.defaultUnitOf(t);
                    if (_unit.text.isEmpty ||
                        HiveActionTypes.all.any((andere) =>
                            HiveActionTypes.defaultUnitOf(andere) ==
                            _unit.text)) {
                      _unit.text = vorschlag;
                    }
                  }),
                  selectedColor: _peach,
                  labelStyle: TextStyle(
                    color: _type == t ? Colors.white : null,
                    fontWeight: _type == t ? FontWeight.w600 : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          _section('Datum'),
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
          const SizedBox(height: 16),

          // ── Kennzahlen (Durchsicht / Schwarmkontrolle) ──
          if (metrics) ...[
            _section('Zustand'),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _broodFrames,
                  keyboardType: TextInputType.number,
                  decoration: _deco('Brutwaben'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _beeFrames,
                  keyboardType: TextInputType.number,
                  decoration: _deco('Waben besetzt'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            const Text('Sanftmut',
                style: TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 4),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$i'),
                      selected: _temper == i,
                      onSelected: (sel) =>
                          setState(() => _temper = sel ? i : null),
                      selectedColor: _peach,
                      labelStyle: TextStyle(
                        color: _temper == i ? Colors.white : null,
                        fontWeight: _temper == i ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                const Expanded(
                  child: Text('1 = stechlustig · 5 = sanft',
                      style: TextStyle(fontSize: 10, color: _muted),
                      textAlign: TextAlign.end),
                ),
              ],
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _queenSeen,
              onChanged: (v) => setState(() => _queenSeen = v ?? false),
              title: const Text('Königin gesehen'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: _peach,
            ),
            CheckboxListTile(
              value: _swarmCells,
              onChanged: (v) => setState(() => _swarmCells = v ?? false),
              title: const Text('Schwarmzellen gefunden'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: _peach,
            ),
            const SizedBox(height: 16),
          ],

          // ── Mittel (Varroabehandlung) ──
          if (withTreatment) ...[
            _section('Mittel'),
            TextField(
              controller: _treatment,
              decoration:
                  _deco('Präparat', hint: 'z.B. Ameisensäure 60%'),
            ),
            const SizedBox(height: 16),
          ],

          // ── Menge (Fütterung / Ernte / Behandlung) ──
          if (withAmount) ...[
            _section('Menge'),
            Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _deco('Menge', hint: 'z.B. 12,5'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _unit,
                  decoration: _deco('Einheit'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
          ],

          _section('Notiz'),
          TextField(
            controller: _note,
            decoration: _deco('Beobachtungen', hint: 'Frei eintragen'),
            maxLines: 4,
            minLines: 2,
          ),
          const SizedBox(height: 16),

          _section('Fotos'),
          _buildPhotoStrip(),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Speichern'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _peach,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPhotoStrip() {
    return FutureBuilder<List<String>>(
      future: PhotoStorage.resolveAll(_photos),
      builder: (ctx, snap) {
        final paths = snap.data ?? const <String>[];
        return SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < paths.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(paths[i]),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 88,
                            height: 88,
                            color: const Color(0xFF18181c),
                            child: const Icon(Icons.broken_image_outlined,
                                color: _muted),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removePhoto(_photos[i]),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              GestureDetector(
                onTap: _showPhotoSourceChooser,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _peach),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: _peach),
                      SizedBox(height: 4),
                      Text('Foto',
                          style: TextStyle(fontSize: 10, color: _peach)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _note.dispose();
    _broodFrames.dispose();
    _beeFrames.dispose();
    _amount.dispose();
    _unit.dispose();
    _treatment.dispose();
    super.dispose();
  }
}
