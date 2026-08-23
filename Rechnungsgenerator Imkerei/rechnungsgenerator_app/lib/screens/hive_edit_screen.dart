import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/pdf_hive_service.dart';
import '../utils/app_utils.dart';
import 'hive_action_edit_screen.dart';

class HiveEditScreen extends StatefulWidget {
  final String? hiveId;
  const HiveEditScreen({Key? key, this.hiveId}) : super(key: key);

  @override
  State<HiveEditScreen> createState() => _HiveEditScreenState();
}

class _HiveEditScreenState extends State<HiveEditScreen> {
  final _db = DatabaseService();
  static const _peach = Color(0xFFfda085);

  final _number = TextEditingController();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _position = TextEditingController();
  final _queenYear = TextEditingController();
  final _queenOrigin = TextEditingController();
  final _notes = TextEditingController();
  String _status = 'aktiv';
  String _qrId = '';
  HiveModel? _current;
  bool _loading = true;
  bool _isSaving = false;

  /// Maßnahmen-Verlauf des Volkes (leer bei einem neuen Volk).
  List<HiveActionModel> _actions = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.hiveId != null) {
        _current = await _db.getHive(widget.hiveId!);
        if (_current != null) _populate(_current!);
        _actions = await _db.getHiveActions(widget.hiveId!);
      } else {
        // Neu: Default-Werte vorbelegen
        final next = await _db.getNextHiveNumber();
        _number.text = next.toString();
        _qrId = 'hive-${const Uuid().v4().substring(0, 8)}';
        _queenYear.text = DateTime.now().year.toString();
      }
    } catch (e) {
      _snack('Fehler beim Laden: $e', err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populate(HiveModel h) {
    _number.text = h.number?.toString() ?? '';
    _name.text = h.name ?? '';
    _location.text = h.location ?? '';
    _position.text = h.position ?? '';
    _queenYear.text = h.queenYear?.toString() ?? '';
    _queenOrigin.text = h.queenOrigin ?? '';
    _notes.text = h.notes ?? '';
    _status = h.status;
    _qrId = h.qrId;
  }

  HiveModel _buildModel() => HiveModel(
        id: _current?.id ?? const Uuid().v4(),
        number: int.tryParse(_number.text),
        name: _nullable(_name.text),
        qrId: _qrId,
        queenYear: int.tryParse(_queenYear.text),
        queenOrigin: _nullable(_queenOrigin.text),
        location: _nullable(_location.text),
        position: _nullable(_position.text),
        status: _status,
        notes: _nullable(_notes.text),
        createdAt: _current?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

  String? _nullable(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      if (!await _saveSilently()) return;
      if (mounted) {
        _snack('✓ Volk gespeichert');
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reloadActions() async {
    if (_current == null) return;
    final actions = await _db.getHiveActions(_current!.id);
    if (mounted) setState(() => _actions = actions);
  }

  /// Maßnahme erfassen. Ein neues Volk muss dafür erst gespeichert sein –
  /// sonst hinge die Maßnahme an einer ID, die es nicht gibt.
  Future<void> _addAction({String? type}) async {
    if (_current == null) {
      final gespeichert = await _saveSilently();
      if (!gespeichert) return;
    }
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HiveActionEditScreen(
          hiveId: _current!.id,
          hiveLabel: _current!.displayLabel,
          initialType: type,
        ),
      ),
    );
    if (changed == true) await _reloadActions();
  }

  Future<void> _openAction(HiveActionModel action) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HiveActionEditScreen(
          hiveId: action.hiveId,
          hiveLabel: _current?.displayLabel ?? 'Volk',
          actionId: action.id,
        ),
      ),
    );
    if (changed == true) await _reloadActions();
  }

  /// Volk speichern, ohne den Screen zu verlassen.
  Future<bool> _saveSilently() async {
    try {
      final h = _buildModel();
      if (_current == null) {
        await _db.insertHive(h);
      } else {
        await _db.updateHive(h);
      }
      if (mounted) setState(() => _current = h);
      return true;
    } catch (e) {
      _snack('Volk konnte nicht gespeichert werden: $e', err: true);
      return false;
    }
  }

  Future<void> _printStockkarte() async {
    try {
      final h = _buildModel();
      final pdf = await PdfHiveService()
          .generateStockkartePdf(hive: h, actions: _actions);
      final bytes = await pdf.save();
      final tmp = await getTemporaryDirectory();
      final num = h.number ?? 0;
      final file =
          File('${tmp.path}/Stockkarte_${num.toString().padLeft(3, '0')}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Stockkarte ${h.displayLabel}',
      );
    } catch (e) {
      _snack('PDF-Fehler: $e', err: true);
    }
  }

  Future<void> _delete() async {
    if (_current == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Volk löschen'),
        content: Text(
            '„${_current!.displayLabel}" wirklich löschen? Alle zugehörigen Maßnahmen werden ebenfalls entfernt.'),
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
      await _db.deleteHive(_current!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg), backgroundColor: err ? Colors.red : null),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Volk')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final h = _buildModel();
    return Scaffold(
      appBar: AppBar(
        title: Text(_current == null ? 'Neues Volk' : 'Volk bearbeiten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'QR + Stockkarte',
            onPressed: _printStockkarte,
          ),
          if (_current != null)
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Color(0xFFff6b7a)),
              tooltip: 'Löschen',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // QR + Kerndaten oben
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: h.qrId,
                      version: QrVersions.auto,
                      size: 100,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.displayLabel,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('QR: ${h.qrId}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF8a8a94))),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _printStockkarte,
                          icon: const Icon(Icons.picture_as_pdf_outlined,
                              size: 16, color: _peach),
                          label: const Text('Stockkarte',
                              style: TextStyle(color: _peach)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _peach),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _section('Stammdaten'),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: _deco('Nr.'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          _section('Ort'),
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _location,
                decoration:
                    _deco('Standort', hint: 'z.B. Hausstand'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _position,
                decoration:
                    _deco('Aufstellungsort', hint: 'z.B. Reihe 2'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // Name entsteht aus Standort + Aufstellungsort und zieht bei einem
          // Ortswechsel mit. Ein eigener Name übersteuert das dauerhaft.
          TextField(
            controller: _name,
            decoration: _deco(
              'Name',
              hint: h.derivedName.isEmpty
                  ? 'wird aus Standort + Aufstellungsort gebildet'
                  : h.derivedName,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                h.usesDerivedName
                    ? Icons.autorenew
                    : Icons.push_pin_outlined,
                size: 13,
                color: const Color(0xFF8a8a94),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  h.usesDerivedName
                      ? 'Heißt „${h.effectiveName}" und ändert sich mit dem Ort'
                      : (_name.text.trim().isEmpty
                          ? 'Trag Standort und Aufstellungsort ein – daraus '
                              'entsteht der Name'
                          : 'Eigener Name – bleibt bei einem Ortswechsel '
                              'stehen. Feld leeren, um ihn wieder aus dem Ort '
                              'zu bilden.'),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF8a8a94)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _section('Königin'),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _queenYear,
                keyboardType: TextInputType.number,
                decoration: _deco('Jahrgang'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _queenOrigin,
                decoration: _deco('Herkunft', hint: 'z.B. Eigenzucht'),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          _section('Status'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'aktiv', label: Text('Aktiv')),
              ButtonSegment(value: 'abgegeben', label: Text('Abgegeben')),
              ButtonSegment(
                  value: 'eingegangen', label: Text('Eingegangen')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          const SizedBox(height: 16),

          _section('Notizen'),
          TextField(
            controller: _notes,
            decoration: _deco('Notizen / Auffälligkeiten'),
            maxLines: 4,
            minLines: 2,
          ),
          const SizedBox(height: 8),

          const SizedBox(height: 8),
          _buildActionTimeline(),

          if (_current != null) ...[
            const SizedBox(height: 8),
            Text(
              'Erstellt: ${AppUtils.formatDate(_current!.createdAt)}',
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF8a8a94)),
            ),
          ],
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

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: const TextStyle(
                color: _peach, fontSize: 14, fontWeight: FontWeight.bold)),
      );

  // ── Maßnahmen-Verlauf ───────────────────────────────────────
  static const _muted = Color(0xFF8a8a94);

  IconData _actionIcon(String type) => switch (type) {
        HiveActionTypes.inspection => Icons.search,
        HiveActionTypes.feeding => Icons.water_drop_outlined,
        HiveActionTypes.varroa => Icons.medical_services_outlined,
        HiveActionTypes.harvest => Icons.inventory_2_outlined,
        HiveActionTypes.swarm => Icons.groups_outlined,
        HiveActionTypes.queen => Icons.star_outline,
        HiveActionTypes.combs => Icons.grid_on_outlined,
        _ => Icons.edit_note_outlined,
      };

  Widget _buildActionTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _section('Maßnahmen (${_actions.length})'),
            TextButton.icon(
              onPressed: () => _addAction(),
              icon: const Icon(Icons.add, size: 16, color: _peach),
              label: const Text('Erfassen',
                  style: TextStyle(color: _peach)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),

        // Schnellzugriff auf die häufigsten Arbeiten
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in const [
                HiveActionTypes.inspection,
                HiveActionTypes.feeding,
                HiveActionTypes.varroa,
                HiveActionTypes.harvest,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(_actionIcon(t), size: 15, color: _peach),
                    label: Text(HiveActionTypes.labelOf(t),
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () => _addAction(type: t),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (_actions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                _current == null
                    ? 'Nach dem Speichern lassen sich hier Maßnahmen erfassen'
                    : 'Noch keine Maßnahmen erfasst',
                style: const TextStyle(fontSize: 12, color: _muted),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final a in _actions) _buildActionRow(a),
      ],
    );
  }

  Widget _buildActionRow(HiveActionModel a) {
    final summary = a.summary;
    return InkWell(
      onTap: () => _openAction(a),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF18181c),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x14ffffff)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_actionIcon(a.type), size: 18, color: _peach),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(a.typeLabel,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Text(AppUtils.formatDate(a.date),
                          style: const TextStyle(
                              fontSize: 11, color: _muted)),
                    ],
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(summary,
                        style: const TextStyle(fontSize: 11, color: _muted)),
                  ],
                  if (summary != (a.note ?? '') &&
                      (a.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(a.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                  ],
                  if (a.hasPhotos) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.photo_outlined,
                            size: 12, color: _muted),
                        const SizedBox(width: 3),
                        Text('${a.photoPaths.length}',
                            style: const TextStyle(
                                fontSize: 10, color: _muted)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _location.dispose();
    _position.dispose();
    _queenYear.dispose();
    _queenOrigin.dispose();
    _notes.dispose();
    super.dispose();
  }
}
