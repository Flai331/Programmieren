import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/personalization_service.dart';

const _muted = Color(0xFF8a8a94);
const _peach = Color(0xFFfda085);
const _red = Color(0xFFff6b7a);
const _card = Color(0xFF18181c);
const _line = Color(0x14ffffff);

/// Die Verzeichnisse: alles, was in der App zur Auswahl steht.
///
/// Ein Verzeichnis ist eine Liste von Einträgen mit einem unveränderlichen
/// Schlüssel und einer Beschriftung, die du ändern darfst. Warum der Schlüssel
/// bleibt, steht in [CatalogEntry]: er steht in den gespeicherten Daten und
/// bei den Honigsorten mit Permanentmarker auf den Eimern.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _dienst = PersonalizationService();

  Future<void> _open(String verzeichnis) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => CatalogEntriesScreen(catalog: verzeichnis)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verzeichnisse')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text(
            'Hier steht, was die App dir zur Auswahl stellt. Beschriftungen, '
            'Reihenfolge und Farben kannst du ändern, eigene Einträge '
            'dazunehmen und nicht mehr Gebrauchtes ausblenden.',
            style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final verzeichnis in Catalogs.all) ...[
            _verzeichnisKarte(verzeichnis),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          const Text(
            'Die Saison-Aufgaben stehen nicht hier: das sind Monatsfenster '
            'und Packlisten, also Fachwissen und keine Beschriftungen.',
            style: TextStyle(fontSize: 10, color: _muted, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _verzeichnisKarte(String verzeichnis) {
    final alle = _dienst.entries(verzeichnis);
    final sichtbar = alle.where((e) => !e.archived).length;
    final versteckt = alle.length - sichtbar;

    return InkWell(
      onTap: () => _open(verzeichnis),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Catalogs.labelOf(verzeichnis),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    versteckt == 0
                        ? '$sichtbar Einträge'
                        : '$sichtbar Einträge · $versteckt ausgeblendet',
                    style: const TextStyle(fontSize: 11, color: _peach),
                  ),
                  const SizedBox(height: 5),
                  Text(Catalogs.hintOf(verzeichnis),
                      style: const TextStyle(
                          fontSize: 10, color: _muted, height: 1.35)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _muted),
          ],
        ),
      ),
    );
  }
}

/// Ein Verzeichnis bearbeiten: umbenennen, umsortieren, erweitern,
/// ausblenden, löschen.
class CatalogEntriesScreen extends StatefulWidget {
  final String catalog;

  const CatalogEntriesScreen({super.key, required this.catalog});

  @override
  State<CatalogEntriesScreen> createState() => _CatalogEntriesScreenState();
}

class _CatalogEntriesScreenState extends State<CatalogEntriesScreen> {
  final _dienst = PersonalizationService();

  /// Farben zur Auswahl – die der App, damit nichts aus dem Rahmen fällt.
  static const List<int> _farben = [
    0xFF60a5fa,
    0xFF38bdf8,
    0xFF4ade80,
    0xFF22c55e,
    0xFFf59e0b,
    0xFFfda085,
    0xFFff6b7a,
    0xFFa78bfa,
    0xFF8a8a94,
  ];

  List<CatalogEntry> _eintraege = const [];
  Map<String, int> _benutzung = const {};
  bool _laedt = true;

  /// Nur bei den Zuständen bedeuten Striche, Farbe und „wartet auf Arbeit"
  /// etwas; nur bei den Gründen die Richtung. Darum nur dort zeigen.
  bool get _istZustand => widget.catalog == Catalogs.honeyState;
  bool get _istGrund => widget.catalog == Catalogs.stockReason;
  bool get _istSorte => widget.catalog == Catalogs.honeyVariety;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final benutzung = await _dienst.usageCounts(widget.catalog);
    if (!mounted) return;
    setState(() {
      _eintraege = _dienst.entries(widget.catalog);
      _benutzung = benutzung;
      _laedt = false;
    });
  }

  void _snack(String text, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: err ? _red : null),
    );
  }

  // ── Ändern ─────────────────────────────────────────────────────

  /// [neu] ist schon der Platz NACH dem Herausnehmen – darum kein Abzug.
  Future<void> _reorder(int alt, int neu) async {
    final liste = [..._eintraege];
    final genommen = liste.removeAt(alt);
    liste.insert(neu, genommen);
    setState(() => _eintraege = liste);
    try {
      await _dienst
          .reorder(widget.catalog, liste.map((e) => e.key).toList());
      await _laden();
      if (_istZustand) _snack('Neue Reihenfolge der Kette gespeichert');
    } catch (e) {
      _snack('Fehler: $e', err: true);
      await _laden();
    }
  }

  Future<void> _toggleArchived(CatalogEntry eintrag) async {
    final benutzt = _benutzung[eintrag.key] ?? 0;
    if (!eintrag.archived && benutzt > 0) {
      final ok = await _confirm(
        titel: 'Ausblenden',
        text: '„${eintrag.label}" steht in $benutzt '
            '${benutzt == 1 ? 'Datensatz' : 'Datensätzen'}. Ausblenden nimmt '
            'den Eintrag nur aus der Auswahl – gespeichert bleibt er, und '
            'einblenden geht jederzeit.'
            '${_istZustand ? ' Eimer, die auf diesem Schritt stehen, zeigen '
                'bis dahin den ersten Haken.' : ''}',
        knopf: 'Ausblenden',
      );
      if (ok != true) return;
    }
    try {
      await _dienst.save(eintrag.copyWith(archived: !eintrag.archived));
      await _laden();
      _snack(eintrag.archived
          ? '„${eintrag.label}" ist wieder in der Auswahl'
          : '„${eintrag.label}" ausgeblendet');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  Future<void> _delete(CatalogEntry eintrag) async {
    final ok = await _confirm(
      titel: 'Löschen',
      text: '„${eintrag.label}" ganz entfernen? Niemand benutzt den Eintrag, '
          'also bleibt nichts zurück.',
      knopf: 'Löschen',
      rot: true,
    );
    if (ok != true) return;
    final weg = await _dienst.remove(widget.catalog, eintrag.key);
    if (!weg) {
      _snack('Das geht nicht – inzwischen benutzt jemand den Eintrag',
          err: true);
    }
    await _laden();
  }

  Future<void> _resetCatalog() async {
    final ok = await _confirm(
      titel: 'Auf Werk zurücksetzen',
      text: 'Alle Beschriftungen, Farben und Reihenfolgen in '
          '„${Catalogs.labelOf(widget.catalog)}" gehen auf die Vorgabe '
          'zurück, und eigene Einträge verschwinden. Gespeicherte Daten, '
          'die auf einen eigenen Eintrag zeigen, zeigen danach nur noch '
          'dessen Schlüssel.',
      knopf: 'Zurücksetzen',
      rot: true,
    );
    if (ok != true) return;
    try {
      await _dienst.resetToDefaults(widget.catalog);
      await _laden();
      _snack('Werkseinstellung gilt wieder');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  // ── Anlegen und bearbeiten ─────────────────────────────────────

  Future<void> _add() async {
    final label = TextEditingController();
    final kuerzel = TextEditingController();
    var richtung = CatalogDirections.outbound;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, neu) => AlertDialog(
          title: const Text('Eintrag anlegen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: label,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _deco('Beschriftung'),
                ),
                if (_istSorte) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: kuerzel,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(2),
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                    ],
                    decoration: _deco('Kürzel'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Genau zwei Buchstaben, wie SO oder RA. Das Kürzel steht '
                    'auf dem Eimer und bleibt, wie es ist – die Kamera sucht '
                    'danach.',
                    style:
                        TextStyle(fontSize: 10, color: _muted, height: 1.35),
                  ),
                ],
                if (_istGrund) ...[
                  const SizedBox(height: 14),
                  const Text('Zählt als',
                      style: TextStyle(fontSize: 11, color: _muted)),
                  const SizedBox(height: 6),
                  _richtungsWahl(richtung, (r) => neu(() => richtung = r)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anlegen',
                  style: TextStyle(color: _peach)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final text = label.text.trim();
    if (text.isEmpty) {
      _snack('Ohne Beschriftung geht es nicht', err: true);
      return;
    }
    final kuerzelText = kuerzel.text.trim().toUpperCase();
    if (_istSorte) {
      if (kuerzelText.length != 2) {
        _snack('Das Kürzel sind genau zwei Buchstaben', err: true);
        return;
      }
      // Ein zweites Mal dasselbe Kürzel darf es nicht geben: es steht auf
      // den Eimern, und zwei Sorten mit demselben Kürzel wären dort nicht
      // zu unterscheiden.
      final schon = _dienst.entry(widget.catalog, kuerzelText);
      if (schon != null) {
        _snack('„$kuerzelText" ist schon „${schon.label}"', err: true);
        return;
      }
    }
    try {
      final eintrag = await _dienst.add(
        widget.catalog,
        label: text,
        key: _istSorte ? kuerzelText : null,
        direction: _istGrund ? richtung : null,
      );
      await _laden();
      _snack('„${eintrag.label}" angelegt');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  Future<void> _edit(CatalogEntry eintrag) async {
    final label = TextEditingController(text: eintrag.label);
    final striche = TextEditingController(text: eintrag.marks ?? '');
    var farbe = eintrag.color;
    var wartet = eintrag.needsAttention ?? false;
    var richtung = eintrag.direction ?? CatalogDirections.both;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, neu) => AlertDialog(
          title: const Text('Eintrag ändern'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: label,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _deco('Beschriftung'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Schlüssel: ${eintrag.key} – der bleibt, damit '
                  'gespeicherte Daten weiter darauf zeigen.',
                  style:
                      const TextStyle(fontSize: 10, color: _muted, height: 1.35),
                ),
                if (_istZustand) ...[
                  const SizedBox(height: 14),
                  const Text('Farbe',
                      style: TextStyle(fontSize: 11, color: _muted)),
                  const SizedBox(height: 6),
                  _farbWahl(farbe, (f) => neu(() => farbe = f)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: striche,
                    inputFormatters: [LengthLimitingTextInputFormatter(6)],
                    decoration: _deco('Striche am Eimer'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Leer lassen heißt: so viele Striche, wie der Schritt '
                    'Haken hat, minus einen – wie bisher.',
                    style:
                        TextStyle(fontSize: 10, color: _muted, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: wartet,
                    onChanged: (v) => neu(() => wartet = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wartet auf eine Arbeit',
                        style: TextStyle(fontSize: 13)),
                    subtitle: const Text(
                        'Dann steht der Eimer auf der Übersicht unter '
                        '„zu tun".',
                        style: TextStyle(fontSize: 10, color: _muted)),
                  ),
                ],
                if (_istGrund) ...[
                  const SizedBox(height: 14),
                  const Text('Zählt als',
                      style: TextStyle(fontSize: 11, color: _muted)),
                  const SizedBox(height: 6),
                  _richtungsWahl(richtung, (r) => neu(() => richtung = r)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Speichern', style: TextStyle(color: _peach)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final text = label.text.trim();
    if (text.isEmpty) {
      _snack('Ohne Beschriftung geht es nicht', err: true);
      return;
    }
    try {
      await _dienst.save(eintrag.copyWith(
        label: text,
        color: _istZustand ? farbe : null,
        clearColor: _istZustand && farbe == null,
        marks: _istZustand ? striche.text : null,
        clearMarks: _istZustand && striche.text.isEmpty,
        needsAttention: _istZustand ? wartet : null,
        direction: _istGrund ? richtung : null,
      ));
      await _laden();
      _snack('Gespeichert');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  // ── Bausteine ──────────────────────────────────────────────────

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  Widget _farbWahl(int? gewaehlt, ValueChanged<int?> onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _farbPunkt(null, gewaehlt == null, () => onPick(null)),
          for (final f in _farben)
            _farbPunkt(f, gewaehlt == f, () => onPick(f)),
        ],
      );

  Widget _farbPunkt(int? farbe, bool aktiv, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: farbe == null ? _card : Color(farbe),
            shape: BoxShape.circle,
            border: Border.all(
                color: aktiv ? Colors.white : _line, width: aktiv ? 2 : 1),
          ),
          // Der leere Punkt heißt „Vorgabe nehmen".
          child: farbe == null
              ? const Icon(Icons.auto_awesome, size: 14, color: _muted)
              : null,
        ),
      );

  Widget _richtungsWahl(String gewaehlt, ValueChanged<String> onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final r in CatalogDirections.all)
            ChoiceChip(
              label: Text(CatalogDirections.labelOf(r),
                  style: const TextStyle(fontSize: 12)),
              selected: r == gewaehlt,
              onSelected: (_) => onPick(r),
            ),
        ],
      );

  Future<bool?> _confirm({
    required String titel,
    required String text,
    required String knopf,
    bool rot = false,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(titel),
          content:
              Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(knopf,
                  style: TextStyle(color: rot ? _red : _peach)),
            ),
          ],
        ),
      );

  // ── Aufbau ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Catalogs.labelOf(widget.catalog)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_backup_restore),
            tooltip: 'Auf Werk zurücksetzen',
            onPressed: _laedt ? null : _resetCatalog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _laedt ? null : _add,
        tooltip: 'Eintrag anlegen',
        child: const Icon(Icons.add),
      ),
      body: _laedt
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    Catalogs.hintOf(widget.catalog),
                    style: const TextStyle(
                        fontSize: 11, color: _muted, height: 1.4),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                    itemCount: _eintraege.length,
                    onReorderItem: _reorder,
                    itemBuilder: (ctx, i) => _zeile(i, _eintraege[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _zeile(int index, CatalogEntry eintrag) {
    final benutzt = _benutzung[eintrag.key] ?? 0;
    final farbe = eintrag.color != null ? Color(eintrag.color!) : _muted;
    final loeschbar = !eintrag.builtIn && benutzt == 0;

    final hinweise = <String>[
      eintrag.key,
      benutzt == 0 ? 'unbenutzt' : '$benutzt×',
      if (eintrag.direction != null)
        CatalogDirections.labelOf(eintrag.direction!),
      if (eintrag.marks != null && eintrag.marks!.isNotEmpty)
        '„${eintrag.marks}" am Eimer',
      if (eintrag.needsAttention == true) 'wartet auf Arbeit',
      if (eintrag.builtIn) 'Werkseintrag',
    ];

    return Container(
      key: ValueKey(eintrag.key),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Opacity(
        opacity: eintrag.archived ? 0.45 : 1,
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(10, 14, 4, 14),
                child: Icon(Icons.drag_handle, size: 18, color: _muted),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _edit(eintrag),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_istZustand) ...[
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                  color: farbe, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              eintrag.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: eintrag.archived
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(hinweise.join(' · '),
                          style:
                              const TextStyle(fontSize: 10, color: _muted),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                  eintrag.archived
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: _muted),
              tooltip: eintrag.archived ? 'Wieder zeigen' : 'Ausblenden',
              onPressed: () => _toggleArchived(eintrag),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: loeschbar ? _red : const Color(0x33ffffff)),
              tooltip: loeschbar
                  ? 'Löschen'
                  : (eintrag.builtIn
                      ? 'Werkseinträge bleiben – blende sie aus'
                      : 'Wird $benutzt× benutzt – blende ihn aus'),
              onPressed: loeschbar
                  ? () => _delete(eintrag)
                  : () => _snack(eintrag.builtIn
                      ? 'Werkseinträge lassen sich nicht löschen, nur '
                          'ausblenden'
                      : '„${eintrag.label}" steht in $benutzt Datensätzen – '
                          'ausblenden geht, löschen nicht'),
            ),
          ],
        ),
      ),
    );
  }
}
