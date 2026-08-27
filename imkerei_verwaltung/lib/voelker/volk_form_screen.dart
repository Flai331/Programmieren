// ═══════════════════════════════════════════════════════════════
//  Volk Formular (Anlegen / Bearbeiten)
//  lib/voelker/volk_form_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/volk.dart';
import '../models/standort.dart';
import '../utils/storage_service.dart';

class VolkFormScreen extends StatefulWidget {
  final Volk? volk;
  final List<Standort> standorte;

  const VolkFormScreen({super.key, this.volk, required this.standorte});

  @override
  State<VolkFormScreen> createState() => _VolkFormScreenState();
}

class _VolkFormScreenState extends State<VolkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _notizenCtrl;
  late TextEditingController _koeniginJahrCtrl;

  String?       _standortId;
  Bienenrasse   _rasse    = Bienenrasse.carnica;
  Volksstatus   _status   = Volksstatus.aktiv;
  int           _staerke  = 5;
  bool          _koeniginMarkiert = false;
  DateTime?     _naechsteInspektion;

  @override
  void initState() {
    super.initState();
    final v = widget.volk;
    _nameCtrl         = TextEditingController(text: v?.name ?? '');
    _notizenCtrl      = TextEditingController(text: v?.notizen ?? '');
    _koeniginJahrCtrl = TextEditingController(text: v?.koeninginJahr ?? '');
    _standortId       = v?.standortId.isNotEmpty == true ? v?.standortId : null;
    _rasse            = v?.rasse   ?? Bienenrasse.carnica;
    _status           = v?.status  ?? Volksstatus.aktiv;
    _staerke          = v?.staerke ?? 5;
    _koeniginMarkiert = v?.koeninginMarkiert ?? false;
    _naechsteInspektion = v?.naechsteInspektion;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notizenCtrl.dispose();
    _koeniginJahrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final istNeu = widget.volk == null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(istNeu ? 'Neues Volk' : 'Volk bearbeiten'),
        actions: [
          TextButton(
            onPressed: _speichern,
            child: const Text('Speichern',
                style: TextStyle(color: AppColors.honey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _textFeld(_nameCtrl, 'Name des Volks *', Icons.hive),
            const SizedBox(height: 12),
            _standortDropdown(),
            const SizedBox(height: 12),
            _rasseDropdown(),
            const SizedBox(height: 12),
            _statusDropdown(),
            const SizedBox(height: 12),
            _staerkeSlider(),
            const SizedBox(height: 12),
            _koeniginAbschnitt(),
            const SizedBox(height: 12),
            _naechsteInspektionFeld(),
            const SizedBox(height: 12),
            _textFeld(_notizenCtrl, 'Notizen', Icons.note, maxLines: 3),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _speichern,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(istNeu ? 'Volk anlegen' : 'Änderungen speichern'),
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
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.honey),
        ),
      ),
      validator: label.contains('*')
          ? (v) => v == null || v.trim().isEmpty ? 'Pflichtfeld' : null
          : null,
    );
  }

  Widget _standortDropdown() {
    if (widget.standorte.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.orange.withOpacity(0.5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.orange, size: 20),
            SizedBox(width: 8),
            Text('Bitte zuerst einen Standort anlegen.',
                style: TextStyle(color: AppColors.orange)),
          ],
        ),
      );
    }
    return DropdownButtonFormField<String>(
      value: _standortId,
      decoration: InputDecoration(
        labelText: 'Standort *',
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.location_on, color: AppColors.honey),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.honey)),
      ),
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      items: widget.standorte
          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
          .toList(),
      onChanged: (v) => setState(() => _standortId = v),
      validator: (v) => v == null ? 'Bitte Standort wählen' : null,
    );
  }

  Widget _rasseDropdown() {
    return DropdownButtonFormField<Bienenrasse>(
      value: _rasse,
      decoration: InputDecoration(
        labelText: 'Bienenrasse',
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.bug_report, color: AppColors.honey),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.honey)),
      ),
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      items: Bienenrasse.values
          .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
          .toList(),
      onChanged: (v) => setState(() => _rasse = v!),
    );
  }

  Widget _statusDropdown() {
    return DropdownButtonFormField<Volksstatus>(
      value: _status,
      decoration: InputDecoration(
        labelText: 'Status',
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.info, color: AppColors.honey),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.honey)),
      ),
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      items: Volksstatus.values
          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
          .toList(),
      onChanged: (v) => setState(() => _status = v!),
    );
  }

  Widget _staerkeSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: AppColors.honey, size: 20),
              const SizedBox(width: 8),
              const Text('Volksstärke',
                  style: TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              Text(
                '$_staerke / 10',
                style: const TextStyle(
                    color: AppColors.honey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _staerke.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppColors.honey,
            inactiveColor: AppColors.textHint,
            onChanged: (v) => setState(() => _staerke = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _koeniginAbschnitt() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: AppColors.honey, size: 20),
              SizedBox(width: 8),
              Text('Königin',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _koeniginJahrCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Schlupfjahr (z.B. 2023)',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              border: InputBorder.none,
            ),
          ),
          SwitchListTile(
            value: _koeniginMarkiert,
            activeColor: AppColors.honey,
            contentPadding: EdgeInsets.zero,
            title: const Text('Markiert',
                style: TextStyle(color: AppColors.textPrimary)),
            subtitle: _koeniginJahrCtrl.text.isNotEmpty
                ? Text(
                    'Farbe: ${Volk.markierungFarbeNachJahr(int.tryParse(_koeniginJahrCtrl.text) ?? 0)}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  )
                : null,
            onChanged: (v) => setState(() => _koeniginMarkiert = v),
          ),
        ],
      ),
    );
  }

  Widget _naechsteInspektionFeld() {
    return ListTile(
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: const Icon(Icons.calendar_today, color: AppColors.honey),
      title: const Text('Nächste Inspektion',
          style: TextStyle(color: AppColors.textSecondary)),
      subtitle: Text(
        _naechsteInspektion == null
            ? 'Nicht festgelegt'
            : '${_naechsteInspektion!.day}.${_naechsteInspektion!.month}.${_naechsteInspektion!.year}',
        style: TextStyle(
          color: _naechsteInspektion == null
              ? AppColors.textHint
              : AppColors.honey,
        ),
      ),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _naechsteInspektion ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppColors.honey),
            ),
            child: child!,
          ),
        );
        if (d != null) setState(() => _naechsteInspektion = d);
      },
      trailing: _naechsteInspektion != null
          ? IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
              onPressed: () => setState(() => _naechsteInspektion = null),
            )
          : null,
    );
  }

  Future<void> _speichern() async {
    if (!_formKey.currentState!.validate()) return;

    final voelker = await StorageService.loadVoelker();

    if (widget.volk == null) {
      // Neu
      voelker.add(Volk(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        standortId: _standortId ?? '',
        rasse: _rasse,
        status: _status,
        staerke: _staerke,
        koeninginJahr: _koeniginJahrCtrl.text.trim(),
        koeninginMarkiert: _koeniginMarkiert,
        koeninginFarbe: _koeniginJahrCtrl.text.isNotEmpty
            ? Volk.markierungFarbeNachJahr(
                int.tryParse(_koeniginJahrCtrl.text) ?? 0)
            : '',
        notizen: _notizenCtrl.text.trim(),
        erstelltAm: DateTime.now(),
        naechsteInspektion: _naechsteInspektion,
      ));
    } else {
      // Bearbeiten
      final idx = voelker.indexWhere((v) => v.id == widget.volk!.id);
      if (idx >= 0) {
        final alt = voelker[idx];
        alt.name                = _nameCtrl.text.trim();
        alt.standortId          = _standortId ?? '';
        alt.rasse               = _rasse;
        alt.status              = _status;
        alt.staerke             = _staerke;
        alt.koeninginJahr       = _koeniginJahrCtrl.text.trim();
        alt.koeninginMarkiert   = _koeniginMarkiert;
        alt.koeninginFarbe      = _koeniginJahrCtrl.text.isNotEmpty
            ? Volk.markierungFarbeNachJahr(
                int.tryParse(_koeniginJahrCtrl.text) ?? 0)
            : '';
        alt.notizen             = _notizenCtrl.text.trim();
        alt.naechsteInspektion  = _naechsteInspektion;
      }
    }

    await StorageService.saveVoelker(voelker);
    if (mounted) Navigator.pop(context);
  }
}
