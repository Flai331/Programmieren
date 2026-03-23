// ═══════════════════════════════════════════════════════════════
//  Inspektion Formular (Stockkarte)
//  lib/inspektionen/inspektion_form_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/inspektion.dart';
import '../models/volk.dart';
import '../utils/storage_service.dart';

class InspektionFormScreen extends StatefulWidget {
  final String? volkId; // vorausgewählt wenn von Volk-Detail geöffnet
  const InspektionFormScreen({super.key, this.volkId});

  @override
  State<InspektionFormScreen> createState() => _InspektionFormScreenState();
}

class _InspektionFormScreenState extends State<InspektionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Volk> _voelker = [];

  String?      _volkId;
  DateTime     _datum          = DateTime.now();
  int          _staerke        = 5;
  BrutStatus   _brutStatus     = BrutStatus.gut;
  bool         _koeninginGesehen = false;
  int          _varroa         = 0;
  bool         _honigvorrat    = true;
  bool         _pollenvorrat   = true;
  bool         _schwarmstimmung = false;
  int          _futterMenge    = 0;

  final _beobachtungenCtrl = TextEditingController();
  final _massnahmenCtrl    = TextEditingController();
  final _wetterCtrl        = TextEditingController();

  @override
  void initState() {
    super.initState();
    _volkId = widget.volkId;
    _laden();
  }

  Future<void> _laden() async {
    final v = await StorageService.loadVoelker();
    if (!mounted) return;
    setState(() {
      _voelker = v.where((volk) => volk.status == Volksstatus.aktiv).toList();
      if (_volkId == null && _voelker.isNotEmpty) {
        _volkId = _voelker.first.id;
      }
    });
  }

  @override
  void dispose() {
    _beobachtungenCtrl.dispose();
    _massnahmenCtrl.dispose();
    _wetterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Inspektion eintragen'),
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
            _volkDropdown(),
            const SizedBox(height: 12),
            _datumFeld(),
            const SizedBox(height: 12),
            _staerkeSlider(),
            const SizedBox(height: 12),
            _brutStatusDropdown(),
            const SizedBox(height: 12),
            _varroaSlider(),
            const SizedBox(height: 12),
            _checkboxAbschnitt(),
            const SizedBox(height: 12),
            _futterFeld(),
            const SizedBox(height: 12),
            _textFeld(_wetterCtrl, 'Wetter', Icons.cloud),
            const SizedBox(height: 12),
            _textFeld(_beobachtungenCtrl, 'Beobachtungen', Icons.visibility,
                maxLines: 4),
            const SizedBox(height: 12),
            _textFeld(_massnahmenCtrl, 'Durchgeführte Maßnahmen',
                Icons.build, maxLines: 3),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _speichern,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Inspektion speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _volkDropdown() {
    if (_voelker.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.orange.withOpacity(0.5)),
        ),
        child: const Text(
          'Bitte zuerst ein aktives Volk anlegen.',
          style: TextStyle(color: AppColors.orange),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      value: _volkId,
      decoration: _inputDeco('Volk *', Icons.hive),
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      items: _voelker
          .map((v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
          .toList(),
      onChanged: (v) => setState(() => _volkId = v),
      validator: (v) => v == null ? 'Pflichtfeld' : null,
    );
  }

  Widget _datumFeld() {
    return ListTile(
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: const Icon(Icons.calendar_today, color: AppColors.honey),
      title: const Text('Datum',
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

  Widget _staerkeSlider() {
    return _sliderKarte(
      'Volksstärke',
      Icons.people,
      _staerke.toDouble(),
      1,
      10,
      9,
      (v) => setState(() => _staerke = v.round()),
      '$_staerke / 10',
    );
  }

  Widget _varroaSlider() {
    return _sliderKarte(
      'Varroa-Schätzung',
      Icons.pest_control,
      _varroa.toDouble(),
      0,
      10,
      10,
      (v) => setState(() => _varroa = v.round()),
      '$_varroa %',
      activeColor: _varroa >= 3 ? AppColors.red : AppColors.honey,
    );
  }

  Widget _sliderKarte(
    String label,
    IconData icon,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
    String display, {
    Color activeColor = AppColors.honey,
  }) {
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
              Icon(icon, color: AppColors.honey, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              Text(display,
                  style: TextStyle(
                      color: activeColor, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: activeColor,
            inactiveColor: AppColors.textHint,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _brutStatusDropdown() {
    return DropdownButtonFormField<BrutStatus>(
      value: _brutStatus,
      decoration: _inputDeco('Brutstatus', Icons.egg),
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      items: BrutStatus.values
          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
          .toList(),
      onChanged: (v) => setState(() => _brutStatus = v!),
    );
  }

  Widget _checkboxAbschnitt() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _switchTile('Königin gesehen', _koeninginGesehen, Icons.star,
              (v) => setState(() => _koeninginGesehen = v)),
          _switchTile('Honigvorrat ausreichend', _honigvorrat,
              Icons.water_drop,
              (v) => setState(() => _honigvorrat = v)),
          _switchTile('Pollenvorrat ausreichend', _pollenvorrat,
              Icons.local_florist,
              (v) => setState(() => _pollenvorrat = v)),
          _switchTile('Schwarmstimmung', _schwarmstimmung, Icons.warning,
              (v) => setState(() => _schwarmstimmung = v),
              activeColor: AppColors.red),
        ],
      ),
    );
  }

  Widget _switchTile(
    String label,
    bool value,
    IconData icon,
    ValueChanged<bool> onChanged, {
    Color activeColor = AppColors.honey,
  }) {
    return SwitchListTile(
      value: value,
      activeColor: activeColor,
      secondary: Icon(icon, color: AppColors.honey, size: 20),
      title: Text(label,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      onChanged: onChanged,
    );
  }

  Widget _futterFeld() {
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
              const Icon(Icons.local_drink, color: AppColors.honey, size: 20),
              const SizedBox(width: 8),
              const Text('Futtermenge',
                  style: TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              Text(
                _futterMenge == 0 ? 'Kein Futter' : '$_futterMenge Liter',
                style: TextStyle(
                    color: _futterMenge > 0 ? AppColors.green : AppColors.textHint,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _futterMenge.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: AppColors.green,
            inactiveColor: AppColors.textHint,
            onChanged: (v) => setState(() => _futterMenge = v.round()),
          ),
        ],
      ),
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
      decoration: _inputDeco(label, icon),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
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
    if (_volkId == null) return;

    final list = await StorageService.loadInspektionen();
    list.add(Inspektion(
      id: const Uuid().v4(),
      volkId: _volkId!,
      datum: _datum,
      staerke: _staerke,
      brutStatus: _brutStatus,
      koeninginGesehen: _koeninginGesehen,
      varroaSchaetzung: _varroa,
      honigvorrat: _honigvorrat,
      pollenvorrat: _pollenvorrat,
      schwarmstimmung: _schwarmstimmung,
      beobachtungen: _beobachtungenCtrl.text.trim(),
      massnahmen: _massnahmenCtrl.text.trim(),
      futterMenge: _futterMenge,
      wetter: _wetterCtrl.text.trim(),
    ));
    await StorageService.saveInspektionen(list);
    if (mounted) Navigator.pop(context);
  }
}
