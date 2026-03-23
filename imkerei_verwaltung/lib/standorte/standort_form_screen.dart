// ═══════════════════════════════════════════════════════════════
//  Standort Formular
//  lib/standorte/standort_form_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/standort.dart';
import '../utils/storage_service.dart';

class StandortFormScreen extends StatefulWidget {
  final Standort? standort;
  const StandortFormScreen({super.key, this.standort});

  @override
  State<StandortFormScreen> createState() => _StandortFormScreenState();
}

class _StandortFormScreenState extends State<StandortFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _adresseCtrl;
  late TextEditingController _beschreibungCtrl;
  late TextEditingController _trachtCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.standort;
    _nameCtrl         = TextEditingController(text: s?.name ?? '');
    _adresseCtrl      = TextEditingController(text: s?.adresse ?? '');
    _beschreibungCtrl = TextEditingController(text: s?.beschreibung ?? '');
    _trachtCtrl       = TextEditingController(text: s?.trachtpflanzen ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _adresseCtrl.dispose();
    _beschreibungCtrl.dispose();
    _trachtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final istNeu = widget.standort == null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(istNeu ? 'Neuer Standort' : 'Standort bearbeiten'),
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
            _textFeld(_nameCtrl, 'Name des Standorts *', Icons.location_on,
                required: true),
            const SizedBox(height: 12),
            _textFeld(_adresseCtrl, 'Adresse / Ort', Icons.home),
            const SizedBox(height: 12),
            _textFeld(_trachtCtrl, 'Trachtpflanzen (z.B. Linde, Raps)',
                Icons.local_florist),
            const SizedBox(height: 12),
            _textFeld(_beschreibungCtrl, 'Beschreibung / Besonderheiten',
                Icons.description, maxLines: 3),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _speichern,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(istNeu ? 'Standort anlegen' : 'Änderungen speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textFeld(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
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
      ),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Pflichtfeld' : null
          : null,
    );
  }

  Future<void> _speichern() async {
    if (!_formKey.currentState!.validate()) return;

    final list = await StorageService.loadStandorte();

    if (widget.standort == null) {
      list.add(Standort(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        adresse: _adresseCtrl.text.trim(),
        beschreibung: _beschreibungCtrl.text.trim(),
        trachtpflanzen: _trachtCtrl.text.trim(),
        erstelltAm: DateTime.now(),
      ));
    } else {
      final idx = list.indexWhere((s) => s.id == widget.standort!.id);
      if (idx >= 0) {
        list[idx].name          = _nameCtrl.text.trim();
        list[idx].adresse       = _adresseCtrl.text.trim();
        list[idx].beschreibung  = _beschreibungCtrl.text.trim();
        list[idx].trachtpflanzen = _trachtCtrl.text.trim();
      }
    }

    await StorageService.saveStandorte(list);
    if (mounted) Navigator.pop(context);
  }
}
