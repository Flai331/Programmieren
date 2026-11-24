import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/honey_service.dart';
import '../utils/app_utils.dart';
import '../utils/feedback_service.dart';
import '../utils/photo_storage.dart';

/// Ein Eimer Honig: was drin ist, in welchem Zustand, wo er steht.
///
/// Der Code steht groß oben – er ist die Verbindung zwischen dem, was mit
/// Stift auf dem Eimer steht, und dem Datensatz hier. Darunter der Hinweis,
/// was genau aufzumalen ist.
class HoneyBucketScreen extends StatefulWidget {
  final String bucketId;

  const HoneyBucketScreen({Key? key, required this.bucketId})
      : super(key: key);

  @override
  State<HoneyBucketScreen> createState() => _HoneyBucketScreenState();
}

class _HoneyBucketScreenState extends State<HoneyBucketScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);
  static const _green = Color(0xFF22c55e);
  static const _red = Color(0xFFff6b7a);

  final _db = DatabaseService();
  final _honey = HoneyService();

  HoneyBucketModel? _bucket;
  double _bottledKg = 0;
  List<HoneyBucketEventModel> _events = [];
  bool _loading = true;

  /// Hat sich etwas geändert, das die Liste dahinter neu laden muss?
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Eimer');
    _load();
  }

  Future<void> _load() async {
    try {
      final bucket = await _db.getHoneyBucket(widget.bucketId);
      final bottled = await _db.getBottledKgPerBucket();
      final events = await _db.getHoneyEvents(widget.bucketId);
      if (!mounted) return;
      setState(() {
        _bucket = bucket;
        _bottledKg = bottled[widget.bucketId] ?? 0;
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Fehler beim Laden: $e', err: true);
    }
  }

  HoneyBucketStatus get _status =>
      HoneyBucketStatus(bucket: _bucket!, bottledKg: _bottledKg);

  // ── Zustand ────────────────────────────────────────────────────

  /// Einen Schritt weiter in der Kette – der häufigste Griff.
  Future<void> _advance() async {
    final bucket = _bucket;
    if (bucket == null) return;
    final naechster = HoneyStates.next(bucket.state);
    if (naechster == null) return;
    try {
      await _honey.advanceState(bucket);
      _dirty = true;
      await _load();
      if (!mounted) return;
      final striche = HoneyStates.strokeHint(naechster);
      _snack(striche.isEmpty
          ? '✓ ${HoneyStates.labelOf(naechster)}'
          : '✓ ${HoneyStates.labelOf(naechster)} – '
              'jetzt $striche auf den Eimer');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  /// Einen anderen Zustand wählen – auch die Abzweige grob und fest.
  Future<void> _chooseState() async {
    final bucket = _bucket;
    if (bucket == null) return;

    final gewaehlt = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Zustand setzen',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final z in HoneyStates.all)
              ListTile(
                dense: true,
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(HoneyStates.colorOf(z)),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(HoneyStates.labelOf(z),
                    style: TextStyle(
                        fontWeight: z == bucket.state
                            ? FontWeight.w700
                            : FontWeight.normal)),
                subtitle: Text(
                  HoneyStates.strokeHint(z).isEmpty
                      ? 'kein Strich am Eimer'
                      : '${HoneyStates.strokeHint(z)} am Eimer',
                  style: const TextStyle(fontSize: 10, color: _muted),
                ),
                trailing: z == bucket.state
                    ? const Icon(Icons.check, size: 16, color: _peach)
                    : null,
                onTap: () => Navigator.pop(ctx, z),
              ),
          ],
        ),
      ),
    );
    if (gewaehlt == null || gewaehlt == bucket.state) return;

    try {
      await _honey.setState(bucket, gewaehlt);
      _dirty = true;
      await _load();
      if (!mounted) return;
      final striche = HoneyStates.strokeHint(gewaehlt);
      _snack(striche.isEmpty
          ? '✓ ${HoneyStates.labelOf(gewaehlt)}'
          : '✓ ${HoneyStates.labelOf(gewaehlt)} – '
              'jetzt $striche auf den Eimer');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  // ── Lagerplatz ─────────────────────────────────────────────────

  Future<void> _setLocation() async {
    final bucket = _bucket;
    if (bucket == null) return;

    final ctrl = TextEditingController(text: bucket.location ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lagerplatz'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Wo steht der Eimer?',
            hintText: 'z.B. Keller Regal B3',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _peach, foregroundColor: Colors.white),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final platz = ctrl.text.trim();
    if (platz.isEmpty) return;
    try {
      await _honey.setLocation(bucket, platz);
      _dirty = true;
      await _load();
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  // ── Abfüllen ───────────────────────────────────────────────────

  Future<void> _bottle() async {
    final bucket = _bucket;
    if (bucket == null) return;
    final rest = _status.currentKg;
    if (rest <= 0) {
      _snack('Der Eimer ist leer');
      return;
    }

    // Nur Posten, die als abgefüllter Honig taugen: Warengruppe Honig mit
    // Füllgewicht. Ohne solchen Posten gibt es nichts zu buchen.
    final alle = await _db.getAllStockItems();
    final glaeser =
        alle.where((i) => i.isFilledJar).toList(growable: false);
    if (!mounted) return;
    if (glaeser.isEmpty) {
      await _noJarItemHint();
      return;
    }

    // Vorauswahl: ein Posten derselben Sorte, sonst der erste.
    var ziel = glaeser.firstWhere((i) => i.variety == bucket.variety,
        orElse: () => glaeser.first);
    final kgCtrl =
        TextEditingController(text: AppUtils.formatNumber(rest));
    final glaeserCtrl = TextEditingController();
    var datum = DateTime.now();
    // Welche Seite hat der Nutzer zuletzt angefasst? Die andere wird
    // gerechnet, damit keine Eingabe unter den Händen wegspringt.
    var letzteEingabe = 'kg';

    BottlingPlan planen() {
      final kg = AppUtils.parseNumber(kgCtrl.text);
      final anzahl = int.tryParse(glaeserCtrl.text.trim());
      if (letzteEingabe == 'glaeser' && anzahl != null) {
        return HoneyService.planBottling(
            jarSizeG: ziel.jarSizeG!, jars: anzahl);
      }
      return HoneyService.planBottling(jarSizeG: ziel.jarSizeG!, kg: kg);
    }

    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final plan = planen();
          // Die gerechnete Seite nachziehen, ohne die getippte zu
          // überschreiben.
          if (letzteEingabe == 'kg') {
            glaeserCtrl.text = plan.jars == 0 ? '' : plan.jars.toString();
          } else {
            kgCtrl.text = AppUtils.formatNumber(plan.kg);
          }
          final zuViel = plan.kg > rest + 0.0001;

          return AlertDialog(
            title: const Text('Abfüllen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Im Eimer ${bucket.code}: '
                    '${AppUtils.formatNumber(rest)} kg',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  const SizedBox(height: 14),
                  if (glaeser.length > 1) ...[
                    const Text('In welche Gläser?',
                        style: TextStyle(fontSize: 11, color: _muted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final g in glaeser)
                          ChoiceChip(
                            label: Text(g.name,
                                style: const TextStyle(fontSize: 11)),
                            selected: ziel.id == g.id,
                            onSelected: (_) => setLocal(() => ziel = g),
                            selectedColor: _peach.withAlpha(51),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: kgCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: _dialogDeco('kg'),
                          onChanged: (_) =>
                              setLocal(() => letzteEingabe = 'kg'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('=',
                            style: TextStyle(color: _muted, fontSize: 16)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: glaeserCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _dialogDeco('Gläser'),
                          onChanged: (_) =>
                              setLocal(() => letzteEingabe = 'glaeser'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ziel.jarSizeG == null
                        ? ''
                        : 'Ein Glas wiegt '
                            '${AppUtils.formatNumber(ziel.jarSizeG! / 1000)} kg',
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                  if (zuViel) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Das ist mehr, als im Eimer ist. Gebucht wird es '
                      'trotzdem – dann steht der Eimer rechnerisch im '
                      'Minus und du siehst, dass etwas nicht stimmt.',
                      style: const TextStyle(
                          fontSize: 10, color: _red, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: datum,
                        firstDate: bucket.harvestDate,
                        lastDate:
                            DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setLocal(() => datum = picked);
                    },
                    icon: const Icon(Icons.calendar_today_outlined,
                        size: 15, color: _peach),
                    label: Text(AppUtils.formatDate(datum),
                        style:
                            const TextStyle(color: _peach, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _peach),
                        minimumSize: const Size.fromHeight(40)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen')),
              ElevatedButton(
                onPressed: plan.jars <= 0 && plan.kg <= 0
                    ? null
                    : () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _peach, foregroundColor: Colors.white),
                child: Text(plan.jars > 0
                    ? '${plan.jars} Gläser'
                    : 'Abfüllen'),
              ),
            ],
          );
        },
      ),
    );

    if (bestaetigt != true) return;
    final plan = planen();
    if (plan.jars <= 0 && plan.kg <= 0) return;

    try {
      await _honey.bottle(
          bucket: bucket, jarItem: ziel, plan: plan, date: datum);
      _dirty = true;
      await _load();
      if (!mounted) return;
      final leere = await _honey.findEmptyJarItem(ziel.jarSizeG);
      if (!mounted) return;
      _snack(leere == null
          ? '✓ ${plan.jars} Gläser im Lager'
          : '✓ ${plan.jars} Gläser im Lager, Leergut abgebucht');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  /// Hinweis, wenn kein Glas-Posten geführt wird. Ein Dialog, der nur
  /// „geht nicht" sagt, wäre im Weg – dieser erklärt, was fehlt.
  Future<void> _noJarItemHint() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Noch kein Glas im Lager'),
        content: const Text(
          'Zum Abfüllen braucht die App einen Lagerposten für das Glas: '
          'Warengruppe „Honig", mit Sorte und Füllgewicht. Leg ihn im '
          'Lager an – danach landen die abgefüllten Gläser dort.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Verstanden')),
        ],
      ),
    );
  }

  // ── Etikett-Foto ───────────────────────────────────────────────

  Future<void> _addLabelPhoto(ImageSource source) async {
    final bucket = _bucket;
    if (bucket == null) return;
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (picked == null) return;
      final name = await PhotoStorage.save(picked.path);
      final alt = bucket.labelPhoto;
      await _db.updateHoneyBucket(
          bucket.copyWith(labelPhoto: name, updatedAt: DateTime.now()));
      // Erst nach erfolgreichem Speichern das alte Bild löschen.
      if (alt != null && alt != name) await PhotoStorage.delete(alt);
      _dirty = true;
      await _load();
    } catch (e) {
      _snack('Foto konnte nicht übernommen werden: $e', err: true);
    }
  }

  void _photoSourceChooser() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _peach),
              title: const Text('Etikett fotografieren'),
              subtitle: const Text(
                  'Das handgeschriebene Etikett am Eimer',
                  style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _addLabelPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _peach),
              title: const Text('Aus Galerie wählen'),
              onTap: () {
                Navigator.pop(ctx);
                _addLabelPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Löschen ────────────────────────────────────────────────────

  Future<void> _delete() async {
    final bucket = _bucket;
    if (bucket == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eimer löschen'),
        content: Text(
          'Eimer ${bucket.code} wirklich löschen? '
          'Der Verlauf mit ${_events.length} Einträgen verschwindet mit. '
          'Die Gläser, die daraus abgefüllt wurden, bleiben im Lager.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final foto = bucket.labelPhoto;
      await _db.deleteHoneyBucket(bucket.id);
      if (foto != null) await PhotoStorage.delete(foto);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: err ? Colors.red : null),
    );
  }

  InputDecoration _dialogDeco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: const TextStyle(
                color: _peach, fontSize: 14, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Eimer')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final bucket = _bucket;
    if (bucket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Eimer')),
        body: const Center(
          child: Text('Dieser Eimer ist nicht mehr da',
              style: TextStyle(color: _muted)),
        ),
      );
    }

    final stand = _status;
    final naechster = HoneyStates.next(bucket.state);

    return Scaffold(
      appBar: AppBar(
        title: Text(bucket.code),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_dirty),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _red),
            tooltip: 'Löschen',
            onPressed: _delete,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _labelCard(bucket),
            const SizedBox(height: 14),
            _contentCard(bucket, stand),
            const SizedBox(height: 18),

            _section('Zustand'),
            _stateCard(bucket, naechster),
            const SizedBox(height: 18),

            _section('Lagerplatz'),
            InkWell(
              onTap: _setLocation,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181c),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x14ffffff)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 17, color: _peach),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bucket.location ?? 'Noch kein Platz vermerkt',
                        style: TextStyle(
                          fontSize: 13,
                          color: bucket.location == null ? _muted : null,
                        ),
                      ),
                    ),
                    const Icon(Icons.edit_outlined, size: 15, color: _muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            _section('Honig'),
            _facts(bucket),
            const SizedBox(height: 18),

            _section('Foto vom Etikett'),
            _labelPhoto(bucket),
            const SizedBox(height: 18),

            _section('Verlauf'),
            if (_events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Noch nichts passiert',
                    style: TextStyle(fontSize: 12, color: _muted)),
              )
            else
              ..._events.map(_eventRow),
          ],
        ),
      ),
      floatingActionButton: stand.currentKg <= 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _bottle,
              backgroundColor: _peach,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.local_drink_outlined),
              label: const Text('Abfüllen'),
            ),
    );
  }

  // ── Was auf den Eimer zu malen ist ─────────────────────────────
  Widget _labelCard(HoneyBucketModel bucket) {
    final striche = HoneyStates.strokeHint(bucket.state);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Das steht auf dem Eimer',
                style: TextStyle(
                    fontSize: 10,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  bucket.code,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    height: 1.1,
                  ),
                ),
                if (striche.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Color(HoneyStates.colorOf(bucket.state)),
                          width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      striche,
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Color(HoneyStates.colorOf(bucket.state)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              striche.isEmpty
                  ? 'Nur den Code aufschreiben – dieser Zustand braucht '
                      'noch kein Kästchen.'
                  : 'Code aufschreiben, Kästchen dazumalen und $striche '
                      'eintragen. Am Eimer siehst du damit ohne App, '
                      'woran du bist.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 11, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: bucket.labelHint));
                _snack('„${bucket.labelHint}" kopiert');
              },
              icon: const Icon(Icons.copy, size: 14, color: _muted),
              label: Text(bucket.labelHint,
                  style: const TextStyle(fontSize: 11, color: _muted)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0x22ffffff))),
            ),
          ],
        ),
      ),
    );
  }

  // ── Inhalt ─────────────────────────────────────────────────────
  Widget _contentCard(HoneyBucketModel bucket, HoneyBucketStatus stand) {
    final anteil = stand.remainingShare.clamp(0.0, 1.0);
    final farbe = stand.currentKg <= 0
        ? _muted
        : (stand.currentKg < 0 ? _red : _green);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Noch drin',
                          style: TextStyle(
                              fontSize: 10,
                              color: _muted,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(stand.currentLabel,
                          style: TextStyle(
                              fontSize: 26,
                              color: farbe,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _bottledKg <= 0
                        ? 'eingewogen '
                            '${AppUtils.formatNumber(bucket.filledKg)} kg'
                        : 'abgefüllt '
                            '${AppUtils.formatNumber(_bottledKg)} kg '
                            'von ${AppUtils.formatNumber(bucket.filledKg)}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: anteil,
                minHeight: 7,
                backgroundColor: const Color(0x14ffffff),
                valueColor: AlwaysStoppedAnimation(farbe),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Die Menge wird aus Einwaage minus Abfüllungen gerechnet – '
              'sie steht nirgends als Zahl, die veralten könnte.',
              style: TextStyle(fontSize: 10, color: _muted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  // ── Zustand ────────────────────────────────────────────────────
  Widget _stateCard(HoneyBucketModel bucket, String? naechster) {
    final farbe = Color(HoneyStates.colorOf(bucket.state));

    return Column(
      children: [
        InkWell(
          onTap: _chooseState,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: farbe.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: farbe.withAlpha(140)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: farbe, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(bucket.stateLabel,
                      style: TextStyle(
                          fontSize: 14,
                          color: farbe,
                          fontWeight: FontWeight.w700)),
                ),
                if (bucket.needsAttention)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('wartet auf dich',
                        style: TextStyle(fontSize: 10, color: _muted)),
                  ),
                const Icon(Icons.unfold_more, size: 16, color: _muted),
              ],
            ),
          ),
        ),
        if (naechster != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _advance,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text('Weiter zu „${HoneyStates.labelOf(naechster)}"'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(HoneyStates.colorOf(naechster)),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Stammdaten ─────────────────────────────────────────────────
  Widget _facts(HoneyBucketModel bucket) {
    final zeilen = <List<String>>[
      ['Sorte', bucket.varietyLabel],
      ['Geschleudert', AppUtils.formatDate(bucket.harvestDate)],
      ['Einwaage', '${AppUtils.formatNumber(bucket.filledKg)} kg'],
      if (bucket.bucketSizeKg != null)
        ['Gebinde', '${AppUtils.formatNumber(bucket.bucketSizeKg!)} kg'],
      if (bucket.waterContent != null)
        ['Wassergehalt', '${AppUtils.formatNumber(bucket.waterContent!)} %'],
      if (bucket.note != null) ['Notiz', bucket.note!],
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF18181c),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14ffffff)),
      ),
      child: Column(
        children: [
          for (final z in zeilen)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(z[0],
                        style:
                            const TextStyle(fontSize: 11, color: _muted)),
                  ),
                  Expanded(
                    child: Text(z[1],
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Etikett-Foto ───────────────────────────────────────────────
  Widget _labelPhoto(HoneyBucketModel bucket) {
    final name = bucket.labelPhoto;
    if (name == null) {
      return OutlinedButton.icon(
        onPressed: _photoSourceChooser,
        icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: _peach),
        label: const Text('Etikett fotografieren',
            style: TextStyle(color: _peach, fontSize: 12)),
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _peach),
            minimumSize: const Size.fromHeight(44)),
      );
    }

    return FutureBuilder<String>(
      future: PhotoStorage.resolve(name),
      builder: (ctx, snap) {
        final pfad = snap.data;
        if (pfad == null) {
          return const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()));
        }
        return InkWell(
          onTap: _photoSourceChooser,
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(pfad),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                height: 160,
                color: const Color(0xFF18181c),
                alignment: Alignment.center,
                child: const Text('Foto nicht gefunden',
                    style: TextStyle(fontSize: 11, color: _muted)),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Eine Zeile im Verlauf ──────────────────────────────────────
  Widget _eventRow(HoneyBucketEventModel e) {
    final icon = switch (e.kind) {
      HoneyEventKinds.bottling => Icons.local_drink_outlined,
      HoneyEventKinds.location => Icons.place_outlined,
      HoneyEventKinds.state => Icons.change_circle_outlined,
      _ => Icons.sticky_note_2_outlined,
    };
    final farbe = e.kind == HoneyEventKinds.state && e.state != null
        ? Color(HoneyStates.colorOf(e.state!))
        : _peach;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF18181c),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14ffffff)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: farbe),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.summary,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(
                  [
                    AppUtils.formatDate(e.date),
                    HoneyEventKinds.labelOf(e.kind),
                    if (e.note != null && e.kind != HoneyEventKinds.note)
                      e.note!,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 10, color: _muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
