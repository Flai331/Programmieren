// ═══════════════════════════════════════════════════════════════
//  Behandlung Formular
//  lib/behandlungen/behandlung_form_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/behandlung.dart';
import '../models/volk.dart';
import '../models/standort.dart';
import '../utils/storage_service.dart';

class BehandlungFormScreen extends StatefulWidget {
  const BehandlungFormScreen({super.key});

  @override
  State<BehandlungFormScreen> createState() => _BehandlungFormScreenState();
}

class _BehandlungFormScreenState extends State<BehandlungFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Standort> _standorte = [];
  List<Volk>     _voelker   = [];

  String?         _standortId;
  String?         _volkId;    // null = alle Völker am Standort
  DateTime        _datum     = DateTime.now();
  DateTime?       _bisDate;
  BehandlungsTyp  _typ       = BehandlungsTyp.varroaOxalsaeure;

  final _mittelCtrl   = TextEditingController();
  final _dosisCtrl    = TextEditingController();
  final _ergebnisCtrl = TextEditingController();
  final _notizenCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final s = await StorageService.loadStandorte();
    final v = await StorageService.loadVoelker();
    if (!mounted) return;
    setState(() {
      _standorte  = s;
      _voelker    = v;
      _standortId = s.isNotEmpty ? s.first.id : null;
    });
  }

  @override
  void dispose() {
    _mittelCtrl.dispose();
    _dosisCtrl.dispose();
    _ergebnisCtrl.dispose();
    _notizenCtrl.dispose();
    super.dispose();
  }

  List<Volk> get _voelkerAmStandort =>
      _standortId == null
          ? []
          : _voelker.where((v) => v.standortId == _standortId).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Behandlung eintragen'),
        actions: [
          TextButton(
            onPressed: _speichern,
            child: const Text('Speichern',
                style: TextStyle(
                    color: AppColors.honey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _standortDropdown(),
            const SizedBox(height: 12),
            _volkDropdown(),
            const SizedBox(height: 12),
            _datumFeld(),
            const SizedBox(height: 12),
            _bisDateFeld(),
            const SizedBox(height: 12),
            _typDropdown(),
            const SizedBox(height: 12),
            _textFeld(_mittelCtrl, 'Mittel / Produkt', Icons.medication),
            const SizedBox(height: 12),
            _textFeld(_dosisCtrl, 'Dosis (z.B. 35 ml)', Icons.science),
            const SizedBox(height: 12),
            _textFeld(_ergebnisCtrl, 'Ergebnis / Erfolg', Icons.check_circle,
                maxLines: 2),
            const SizedBox(height: 12),
            _textFeld(_notizenCtrl, 'Notizen', Icons.note, maxLines: 3),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _speichern,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Behandlung speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _standortDropdown() {
    if (_standorte.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.orange.withOpacity(0.5)),
        ),
        child: const Text(
          'Bitte zuerst einen Standort anlegen.',
          style: TextStyle(color: AppColors.orange),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      value: _standortId,
      decoration: _deco('Standort *', Icons.location_on),
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      items: _standorte
          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
          .toList(),
      onChanged: (v) => setState(() {
        _standortId = v;
        _volkId = null;
      }),
      validator: (v) => v == null ? 'Pflichtfeld' : null,
    );
  }

  Widget _volkDropdown() {
    final list = _voelkerAmStandort;
    return DropdownButtonFormField<String?>(
      value: _volkId,
      decoration: _deco('Volk (leer = alle)', Icons.hive),
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      items: [
        const DropdownMenuItem<String?>(
            value: null, child: Text('Alle Völker am Standort')),
        ...list.map((v) => DropdownMenuItem<String?>(
            value: v.id, child: Text(v.name))),
      ],
      onChanged: (v) => setState(() => _volkId = v),
    );
  }

  Widget _datumFeld() {
    return ListTile(
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: const Icon(Icons.calendar_today, color: AppColors.honey),
      title: const Text('Startdatum',
          style: TextStyle(color: AppColors.textSecondary)),
      subtitle: Text(
        '${_datum.day}.${_datum.month}.${_datum.year}',
        style: const TextStyle(color: AppColors.honey),
      ),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _datum,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppColors.honey),
            ),
            child: child!,
          ),
        );
        if (d != null) setState(() => _datum = d);
      },
    );
  }

  Widget _bisDateFeld() {
    return ListTile(
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: const Icon(Icons.calendar_month, color: AppColors.honey),
      title: const Text('Enddatum (optional)',
          style: TextStyle(color: AppColors.textSecondary)),
      subtitle: Text(
        _bisDate == null
            ? 'Einmalig / nicht festgelegt'
            : '${_bisDate!.day}.${_bisDate!.month}.${_bisDate!.year}',
        style: TextStyle(
            color: _bisDate == null ? AppColors.textHint : AppColors.honey),
      ),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _bisDate ?? _datum.add(const Duration(days: 7)),
          firstDate: _datum,
          lastDate: _datum.add(const Duration(days: 180)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppColors.honey),
            ),
            child: child!,
          ),
        );
        if (d != null) setState(() => _bisDate = d);
      },
      trailing: _bisDate != null
          ? IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
              onPressed: () => setState(() => _bisDate = null),
            )
          : null,
    );
  }

  Widget _typDropdown() {
    return DropdownButtonFormField<BehandlungsTyp>(
      value: _typ,
      decoration: _deco('Behandlungstyp', Icons.medical_services),
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      items: BehandlungsTyp.values
          .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
          .toList(),
      onChanged: (v) => setState(() => _typ = v!),
    );
  }

  Widget _textFeld(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: _deco(label, icon),
    );
  }

  InputDecoration _deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: Icon(icon, color: AppColors.honey),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.honey)),
    );
  }

  Future<void> _speichern() async {
    if (!_formKey.currentState!.validate()) return;
    if (_standortId == null) return;

    final list = await StorageService.loadBehandlungen();
    list.add(Behandlung(
      id: const Uuid().v4(),
      volkId: _volkId ?? '',
      standortId: _standortId!,
      datum: _datum,
      bisDate: _bisDate,
      typ: _typ,
      mittel: _mittelCtrl.text.trim(),
      dosis: _dosisCtrl.text.trim(),
      ergebnis: _ergebnisCtrl.text.trim(),
      notizen: _notizenCtrl.text.trim(),
    ));
    await StorageService.saveBehandlungen(list);
    if (mounted) Navigator.pop(context);
  }
}
