import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/import_service.dart';
import '../utils/feedback_service.dart';

/// Daten aus dem Rechnungsgenerator (WebApp) übernehmen.
class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);
  static const _green = Color(0xFF22c55e);

  String? _fileName;
  String? _raw;
  List<String> _preview = [];
  String? _error;
  bool _running = false;
  ImportResult? _result;

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Daten übernehmen');
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _result = null;
    });
    try {
      final auswahl = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (auswahl == null || auswahl.files.isEmpty) return;
      final datei = auswahl.files.first;

      // withData liefert die Bytes direkt; auf manchen Plattformen kommt
      // stattdessen nur ein Pfad zurück.
      final inhalt = datei.bytes != null
          ? utf8.decode(datei.bytes!, allowMalformed: true)
          : (datei.path != null
              ? await File(datei.path!).readAsString()
              : null);
      if (inhalt == null) {
        setState(() => _error = 'Die Datei ließ sich nicht lesen.');
        return;
      }

      final daten = ImportParser.decode(inhalt);
      setState(() {
        _fileName = datei.name;
        _raw = inhalt;
        _preview = ImportParser.describe(daten);
      });
    } on ImportFormatException catch (e) {
      setState(() {
        _error = e.message;
        _raw = null;
        _preview = [];
      });
    } catch (e) {
      setState(() {
        _error = 'Datei konnte nicht gelesen werden: $e';
        _raw = null;
        _preview = [];
      });
    }
  }

  Future<void> _run() async {
    final raw = _raw;
    if (raw == null) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final ergebnis = await ImportRunner().run(raw);
      if (mounted) setState(() => _result = ergebnis);
    } on ImportFormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      FeedbackService.logError(e.toString(), context: 'Import');
      if (mounted) setState(() => _error = 'Import fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daten übernehmen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('So geht es'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Step(1,
                      'Öffne den Rechnungsgenerator im Browser '
                      '(RECHNUNGSGENERATOR.html).'),
                  _Step(2,
                      'Klick im ersten Reiter auf „🐝 Für BeeBrain '
                      'exportieren". Es wird eine JSON-Datei gespeichert.'),
                  _Step(3, 'Wähl diese Datei hier unten aus.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Übernommen wird die Vorlage: Absenderdaten, Logo, Briefkopf und '
            'Farben. Rechnungen sind nicht dabei – der Generator legt keine '
            'an, er erzeugt nur PDFs.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 20),

          _section('Datei'),
          OutlinedButton.icon(
            onPressed: _running ? null : _pickFile,
            icon: const Icon(Icons.folder_open, color: _peach),
            label: Text(_fileName ?? 'Datei auswählen',
                style: const TextStyle(color: _peach)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _peach),
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            _banner(Icons.error_outline, Colors.red, _error!),
          ],

          if (_preview.isNotEmpty && _result == null) ...[
            const SizedBox(height: 20),
            _section('Das steckt drin'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final zeile in _preview)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 15, color: _green),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(zeile,
                                    style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vorhandene Firmendaten werden ergänzt, nicht gelöscht: Felder, '
              'die die Datei nicht kennt, bleiben stehen.',
              style: TextStyle(fontSize: 11, color: _muted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_outlined),
              label: Text(_running ? 'Übernehme...' : 'Jetzt übernehmen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _peach,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],

          if (_result != null) ...[
            const SizedBox(height: 20),
            _section('Übernommen'),
            _resultCard(_result!),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _resultCard(ImportResult r) {
    final zeilen = <String>[
      if (r.companyImported) 'Absenderdaten',
      if (r.designImported) 'Design und Farben',
      if (r.logoImported) 'Logo',
      if (r.headerImported) 'Briefkopf',
      if (r.customers > 0) '${r.customers} Kunden',
      if (r.articles > 0) '${r.articles} Artikel',
      if (r.invoices > 0) '${r.invoices} Rechnungen',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (zeilen.isEmpty)
                  const Text('Es gab nichts zu übernehmen.',
                      style: TextStyle(fontSize: 13))
                else
                  for (final z in zeilen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              size: 16, color: _green),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(z,
                                  style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        for (final hinweis in r.notes) ...[
          const SizedBox(height: 8),
          _banner(Icons.info_outline, Colors.blue, hinweis),
        ],
      ],
    );
  }

  Widget _banner(IconData icon, Color color, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontSize: 12, height: 1.35)),
            ),
          ],
        ),
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: const TextStyle(
                color: _peach, fontSize: 14, fontWeight: FontWeight.bold)),
      );
}

class _Step extends StatelessWidget {
  final int number;
  final String text;
  const _Step(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFfda085).withAlpha(38),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFfda085)),
            ),
            child: Text('$number',
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFfda085),
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
