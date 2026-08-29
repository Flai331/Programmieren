import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/import_service.dart';
import '../utils/feedback_service.dart';

/// Daten aus dem Rechnungsgenerator (WebApp) übernehmen.
///
/// Die Übergabe läuft über die Zwischenablage statt über eine Dateiauswahl.
/// Ein Dateiauswahl-Plugin wäre eine native Abhängigkeit allein für diesen
/// einen Dialog – und file_picker ließ sich mit der hier verwendeten
/// Android-Gradle-Fassung nicht übersetzen.
class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);
  static const _green = Color(0xFF22c55e);

  final _input = TextEditingController();

  List<String> _preview = [];
  String? _error;
  bool _running = false;
  ImportResult? _result;

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Daten übernehmen');
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final daten = await Clipboard.getData(Clipboard.kTextPlain);
      final text = daten?.text ?? '';
      if (text.trim().isEmpty) {
        setState(() => _error = 'In der Zwischenablage steht kein Text.');
        return;
      }
      _input.text = text;
      _check();
    } catch (e) {
      setState(() => _error = 'Zwischenablage nicht lesbar: $e');
    }
  }

  /// Eingabe prüfen und zeigen, was darin steckt.
  void _check() {
    setState(() {
      _error = null;
      _result = null;
      _preview = [];
    });
    try {
      final daten = ImportParser.decode(_input.text);
      setState(() => _preview = ImportParser.describe(daten));
    } on ImportFormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Konnte nicht gelesen werden: $e');
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final ergebnis = await ImportRunner().run(_input.text);
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
                      'Klick im ersten Reiter auf „🐝 Für BeeBrain kopieren". '
                      'Die Vorlage liegt dann in der Zwischenablage.'),
                  _Step(3,
                      'Schick sie dir aufs Handy – etwa per Nachricht an dich '
                      'selbst – und füge sie hier unten ein.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Übernommen werden Absenderdaten, Bankverbindung und die Farben '
            'der Kopfzeile. Logo und Briefkopf sind nicht dabei: Als Text '
            'wären sie zu umfangreich für die Zwischenablage – die lädst du '
            'in den Einstellungen unter Design direkt hoch.\n\n'
            'Rechnungen gibt es dort ohnehin nicht zu holen; der Generator '
            'legt keine an, er erzeugt nur PDFs.',
            style: TextStyle(fontSize: 12, color: _muted, height: 1.35),
          ),
          const SizedBox(height: 20),

          _section('Vorlage einfügen'),
          OutlinedButton.icon(
            onPressed: _running ? null : _pasteFromClipboard,
            icon: const Icon(Icons.content_paste, color: _peach),
            label: const Text('Aus Zwischenablage einfügen',
                style: TextStyle(color: _peach)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _peach),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _input,
            maxLines: 6,
            minLines: 3,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: 'oder von Hand einfügen',
              hintText: '{ "beebrain_import": 1, … }',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
            onChanged: (_) {
              if (_preview.isNotEmpty || _error != null) {
                setState(() {
                  _preview = [];
                  _error = null;
                  _result = null;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _running ? null : _check,
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Prüfen'),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
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
              'die die Vorlage nicht kennt, bleiben stehen.',
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
