import 'package:flutter/material.dart';

import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

/// Auswahl der Rufnummern für die Ruhe. Gibt die normalisierten Nummern zurück.
///
/// Gespeichert wird allein die Nummer, nicht der Name: entschieden wird beim
/// Anruf, und dafür ist der Name unnötig. Wer die Kontaktberechtigung später
/// entzieht, behält damit eine wirksame Auswahl — nur die Namen fehlen dann.
class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({
    super.key,
    required this.selected,
    this.channel = const RiegelChannel(),
  });

  final List<String> selected;
  final RiegelChannel channel;

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen>
    with WidgetsBindingObserver {
  List<ContactInfo>? _kontakte;
  bool _berechtigt = true;
  late final Set<String> _gewaehlt = widget.selected.toSet();
  final TextEditingController _suche = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lade();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _suche.dispose();
    super.dispose();
  }

  /// Die Berechtigung wird in einem Systemdialog erteilt. Zurück in der App
  /// muss die Liste deshalb von selbst erscheinen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _lade();
  }

  Future<void> _lade() async {
    final berechtigt = await widget.channel.contactsGranted();
    final kontakte = berechtigt
        ? await widget.channel.contacts()
        : <ContactInfo>[];
    if (!mounted) return;
    setState(() {
      _berechtigt = berechtigt;
      _kontakte = kontakte;
    });
  }

  Future<void> _frageBerechtigung() async {
    final erteilt = await widget.channel.requestContacts();
    if (erteilt) await _lade();
  }

  List<ContactInfo> _gefiltert(List<ContactInfo> alle) {
    final suche = _suche.text.trim().toLowerCase();
    if (suche.isEmpty) return alle;
    return alle
        .where(
          (k) =>
              k.name.toLowerCase().contains(suche) || k.number.contains(suche),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final kontakte = _kontakte;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontakte wählen'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _gewaehlt.toList()),
            child: const Text('Fertig'),
          ),
        ],
      ),
      body: !_berechtigt
          ? _hinweis()
          : kontakte == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(RiegelSpacing.s4),
                  child: TextField(
                    controller: _suche,
                    decoration: const InputDecoration(
                      labelText: 'Suchen',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(child: _liste(_gefiltert(kontakte))),
              ],
            ),
    );
  }

  Widget _hinweis() => Padding(
    padding: const EdgeInsets.all(RiegelSpacing.s4),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ohne Zugriff auf die Kontakte kann Anker keine Namen anzeigen. '
          'Gespeichert wird nur die Rufnummer.',
          style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
        ),
        const SizedBox(height: RiegelSpacing.s3),
        OutlinedButton(
          onPressed: _frageBerechtigung,
          child: const Text('Zugriff erlauben'),
        ),
      ],
    ),
  );

  Widget _liste(List<ContactInfo> kontakte) {
    if (kontakte.isEmpty) {
      return const Center(
        child: Text(
          'Keine Kontakte gefunden',
          style: TextStyle(fontSize: 13, color: RiegelColors.fg3),
        ),
      );
    }
    return ListView.builder(
      itemCount: kontakte.length,
      itemBuilder: (context, index) {
        final kontakt = kontakte[index];
        final gewaehlt = _gewaehlt.contains(kontakt.number);
        return Container(
          // Wie in der App-Auswahl: die getönte Zeile zeigt die Auswahl auch
          // dann, wenn das Häkchen aus dem Blick gescrollt ist.
          color: gewaehlt ? RiegelColors.accentTint : null,
          child: CheckboxListTile(
            title: Text(
              kontakt.name,
              style: const TextStyle(fontSize: 14, color: RiegelColors.fg1),
            ),
            subtitle: Text(
              kontakt.number,
              style: const TextStyle(
                fontFamily: kMonoFamily,
                fontSize: 12,
                color: RiegelColors.fg3,
              ),
            ),
            value: gewaehlt,
            onChanged: (an) => setState(() {
              if (an ?? false) {
                _gewaehlt.add(kontakt.number);
              } else {
                _gewaehlt.remove(kontakt.number);
              }
            }),
          ),
        );
      },
    );
  }
}
