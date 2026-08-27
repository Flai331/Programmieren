// ═══════════════════════════════════════════════════════════════
//  Ernte Formular
//  lib/ernte/ernte_form_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/ernte.dart';
import '../models/standort.dart';
import '../utils/storage_service.dart';

class ErnteFormScreen extends StatefulWidget {
  const ErnteFormScreen({super.key});

  @override
  State<ErnteFormScreen> createState() => _ErnteFormScreenState();
}

class _ErnteFormScreenState extends State<ErnteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Standort> _standorte = [];

  String?    _standortId;
  DateTime   _datum         = DateTime.now();
  Honigsorte _sorte         = Honigsorte.blütenhonig;

  final _mengeCtrl      = TextEditingController();
  final _wasserCtrl     = TextEditingController();
  final _qualitaetCtrl  = TextEditingController();
  final _notizenCtrl    = TextEditingController();

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final s = await StorageService.loadStandorte();
    if (!mounted) return;
    setState(() {
      _standorte  = s;
      _standortId = s.isNotEmpty ? s.first.id : null;
    });
  }

  @override
  void dispose() {
    _mengeCtrl.dispose();
    _wasserCtrl.dispose();
    _qualitaetCtrl.dispose();
    _notizenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Ernte eintragen'),
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
            _datumFeld(),
            const SizedBox(height: 12),
            _sorteDropdown(),
            const SizedBox(height: 12),
            _mengeTextField(),
            const SizedBox(height: 12),
            _wassergehaltField(),
            const SizedBox(height: 12),
            _textFeld(_qualitaetCtrl, 'Qualität (Farbe, Geschmack)',
                Icons.star, maxLines: 2),
            const SizedBox(height: 12),
            _textFeld(_notizenCtrl, 'Notizen', Icons.note, maxLines: 3),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _speichern,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Ernte speichern'),
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
      onChanged: (v) => setState(() => _standortId = v),
      validator: (v) => v == null ? 'Pflichtfeld' : null,
    );
  }

  Widget _datumFeld() {
    return ListTile(
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: const Icon(Icons.calendar_today, color: AppColors.honey),
      title: const Text('Erntedatum',
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
          lastDate: DateTime.now(),
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

  Widget _sorteDropdown() {
    return DropdownButtonFormField<Honigsorte>(
      value: _sorte,
      decoration: _deco('Honigsorte', Icons.water_drop),
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      items: Honigsorte.values
          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
          .toList(),
      onChanged: (v) => setState(() => _sorte = v!),
    );
  }

  Widget _mengeTextField() {
    return TextFormField(
      controller: _mengeCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: _deco('Menge in kg *', Icons.scale),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
        final n = double.tryParse(v.trim().replaceAll(',', '.'));
        if (n == null || n <= 0) return 'Ungültige Menge';
        return null;
      },
    );
  }

  Widget _wassergehaltField() {
    return TextFormField(
      controller: _wasserCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: _deco('Wassergehalt in % (optimal < 18%)', Icons.opacity),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final n = double.tryParse(v.trim().replaceAll(',', '.'));
        if (n == null || n < 0 || n > 100) return 'Ungültiger Wert';
        return null;
      },
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

    final menge = double.parse(_mengeCtrl.text.trim().replaceAll(',', '.'));
    final wasser = _wasserCtrl.text.trim().isEmpty
        ? 0.0
        : double.parse(_wasserCtrl.text.trim().replaceAll(',', '.'));

    final list = await StorageService.loadErnten();
    list.add(Ernte(
      id: const Uuid().v4(),
      standortId: _standortId!,
      datum: _datum,
      mengeKg: menge,
      sorte: _sorte,
      wassergehalt: wasser,
      qualitaet: _qualitaetCtrl.text.trim(),
      notizen: _notizenCtrl.text.trim(),
    ));
    await StorageService.saveErnten(list);
    if (mounted) Navigator.pop(context);
  }
}
