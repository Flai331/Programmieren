import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/honey_service.dart';
import '../services/warmer_alarms.dart';
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

  /// Gleich den Abfüll-Dialog öffnen. Kommt von der Kamera-Lesung: Wer
  /// „abgefüllt" antippt, während er den Eimer in der Hand hat, soll
  /// nicht erst durch den Bildschirm suchen müssen.
  final bool startBottling;

  const HoneyBucketScreen({
    Key? key,
    required this.bucketId,
    this.startBottling = false,
  }) : super(key: key);

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
  final _alarms = WarmerAlarms();

  /// Darf die App melden? Erst gefragt, wenn eine Uhr läuft – vorher gilt
  /// keine Nachricht als gute Nachricht.
  bool _canNotify = true;

  HoneyBucketModel? _bucket;
  double _bottledKg = 0;
  List<HoneyBucketEventModel> _events = [];
  bool _loading = true;

  /// Hat sich etwas geändert, das die Liste dahinter neu laden muss?
  bool _dirty = false;

  /// Wurde der Abfüll-Dialog aus [HoneyBucketScreen.startBottling] schon
  /// geöffnet? Nur beim ersten Laden – danach lädt der Bildschirm nach
  /// jeder Buchung neu, und ein zweiter Dialog wäre eine Falle.
  bool _bottlingOffered = false;

  /// Hält die Wärmeschrank-Uhr am Laufen, solange eine läuft.
  ///
  /// Einmal je Minute genügt: die Uhr zählt Stunden. Läuft keine, läuft auch
  /// kein Timer – ein Bildschirm, der ohne Not aufwacht, kostet nur Strom.
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

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
      final uhr = HoneyWarmer.fromEvents(events);
      _syncTicker(uhr != null);
      if (uhr != null) {
        final darf = await _alarms.canNotify();
        if (mounted && darf != _canNotify) setState(() => _canNotify = darf);
      }
      if (widget.startBottling && !_bottlingOffered && bucket != null) {
        _bottlingOffered = true;
        // Erst nach dem Aufbau: Der Dialog braucht einen fertigen
        // Bildschirm hinter sich, sonst steht er über dem Ladekreis.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _bottle();
        });
      }
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
    await _applyState(naechster);
  }

  /// Einen Haken setzen oder wieder wegnehmen.
  ///
  /// Die Kette kennt keine Lücken: Haken 3 heißt, dass 1 und 2 vorbei sind.
  /// Darum hakt ein Antippen alles bis dorthin mit an, und ein gesetzter
  /// Haken nimmt sich selbst und alles danach wieder weg. Haken 1 bleibt
  /// stehen – geschleudert ist der Honig, sonst gäbe es den Eimer nicht.
  Future<void> _toggleTick(int nummer) async {
    final bucket = _bucket;
    if (bucket == null) return;
    final gesetzt = HoneyStates.ticksOf(bucket.state);
    final ziel = HoneyStates.ticksAfterTap(current: gesetzt, tapped: nummer);
    if (ziel == null) {
      _snack('Geschleudert ist er auf jeden Fall – der Haken bleibt.');
      return;
    }

    // Mehr als einen Haken auf einmal zu verlieren ist selten Absicht.
    if (gesetzt - ziel > 1) {
      final zurueck = HoneyStates.labelOf(HoneyStates.stateForTicks(ziel));
      final ok = await _confirm(
        titel: 'Haken zurücknehmen',
        text: 'Das nimmt ${gesetzt - ziel} Haken weg. Der Eimer steht '
            'danach wieder auf „$zurueck".',
        knopf: 'Zurücknehmen',
      );
      if (ok != true) return;
    }

    await _applyState(HoneyStates.stateForTicks(ziel));
  }

  /// Den Zustand schreiben und sagen, was jetzt auf den Eimer gehört.
  Future<void> _applyState(String neuer) async {
    final bucket = _bucket;
    if (bucket == null || neuer == bucket.state) return;
    try {
      await _honey.setState(bucket, neuer);
      _dirty = true;
      await _load();
      if (!mounted) return;
      _snackState(neuer);
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  void _snackState(String zustand) {
    final striche = HoneyStates.strokeHint(zustand);
    _snack(striche.isEmpty
        ? '✓ ${HoneyStates.labelOf(zustand)}'
        : '✓ ${HoneyStates.labelOf(zustand)} – jetzt $striche auf den Eimer');
  }

  // ── Markierung ─────────────────────────────────────────────────

  /// Grob kristallin oder kandiert vermerken – nochmal tippen nimmt es weg.
  ///
  /// Das ist kein Haken: der Honig bleibt stehen, wo er stand. Die Markierung
  /// sagt nur, dass er so nicht abgefüllt werden kann.
  Future<void> _toggleCrystallization(String wert) async {
    final bucket = _bucket;
    if (bucket == null) return;
    final neu = bucket.crystallization == wert ? null : wert;
    try {
      await _honey.setCrystallization(bucket, neu);
      _dirty = true;
      await _load();
      if (!mounted) return;
      _snack(neu == null
          ? 'Markierung abgenommen'
          : '${HoneyCrystallization.labelOf(neu)} vermerkt');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  /// Durch das Melitherm – der Weg zurück aus grob und kandiert.
  Future<void> _throughMelitherm() async {
    final bucket = _bucket;
    if (bucket == null) return;
    final erster = HoneyStates.stateForTicks(1);
    final ok = await _confirm(
      titel: 'Durch das Melitherm',
      text: 'Danach ist der Honig wieder flüssig: die Markierung fällt weg '
          'und der Eimer steht wieder auf '
          '„${HoneyStates.labelOf(erster)}". Impfen und Rühren kommen '
          'also noch einmal.',
      knopf: 'Ist durchgelaufen',
    );
    if (ok != true) return;
    try {
      await _honey.throughMelitherm(bucket);
      _dirty = true;
      await _load();
      if (!mounted) return;
      _snackState(erster);
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  // ── Wärmeschrank ───────────────────────────────────────────────

  void _syncTicker(bool laeuft) {
    if (laeuft) {
      _ticker ??= Timer.periodic(
          const Duration(minutes: 1), (_) => mounted ? setState(() {}) : null);
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// Den Eimer in den Schrank stellen. Von Hand – ein Haken sagt nicht, wo
  /// der Eimer steht.
  Future<void> _startWarmer() async {
    final bucket = _bucket;
    if (bucket == null) return;
    try {
      final uhr = await _honey.startWarmer(bucket);
      _dirty = true;

      // Erst jetzt nach der Erlaubnis fragen: hier ist der Grund sichtbar.
      var darf = await _alarms.canNotify();
      if (!darf) darf = await _alarms.requestPermission();
      final gesetzt = darf &&
          await _alarms.schedule(bucket: bucket, warmer: uhr);

      await _load();
      if (!mounted) return;
      _snack(gesetzt
          ? 'Uhr läuft – ${uhr.requiredHours} h, ${_fertigText(uhr.dueAt)}. '
              'Ich melde mich.'
          : 'Uhr läuft – ${uhr.requiredHours} h, ${_fertigText(uhr.dueAt)}. '
              'Ohne Meldung: schau am Eimer nach.');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  Future<void> _stopWarmer() async {
    final bucket = _bucket;
    if (bucket == null) return;
    try {
      await _honey.stopWarmer(bucket);
      await _alarms.cancel(bucket.id);
      _dirty = true;
      await _load();
      if (!mounted) return;
      _snack('Herausgenommen – die Uhr ist aus');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  /// Rückfrage im Stil der übrigen – ja oder nein, nichts dazwischen.
  Future<bool?> _confirm({
    required String titel,
    required String text,
    required String knopf,
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
              child: Text(knopf, style: const TextStyle(color: _peach)),
            ),
          ],
        ),
      );

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
      await _alarms.cancel(bucket.id);
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

            _section('Wärmeschrank'),
            _warmerCard(),
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

  // ── Hakenliste ─────────────────────────────────────────────────

  /// Die Hakenliste: eine Zeile je Schritt, abgehakt bis zum erreichten.
  ///
  /// Gespeichert wird nur ein Zustand – der weiteste erreichte Schritt. Die
  /// Haken davor ergeben sich daraus, denn die Kette hat keine Lücken: wer
  /// rührt, hat vorher geimpft. Darum hakt ein Antippen alles bis dorthin
  /// mit an.
  Widget _stateCard(HoneyBucketModel bucket, String? naechster) {
    final schritte = HoneyStates.steps;
    final gesetzt = HoneyStates.ticksOf(bucket.state);
    final leer = bucket.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF18181c),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x14ffffff)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < schritte.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, thickness: 1, color: Color(0x0dffffff)),
                _tickRow(
                  nummer: i + 1,
                  schritt: schritte[i],
                  erledigt: i + 1 <= gesetzt,
                  aktuell: i + 1 == gesetzt && !leer,
                  tippbar: !leer,
                ),
              ],
            ],
          ),
        ),
        if (leer) ...[
          const SizedBox(height: 8),
          Text(
            '${bucket.stateLabel} – alles aus diesem Eimer ist abgefüllt. '
            'Die Haken sind damit erledigt.',
            style: const TextStyle(fontSize: 10, color: _muted, height: 1.35),
          ),
        ] else if (naechster != null) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _advance,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text('Weiter zu „${HoneyStates.labelOf(naechster)}"'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(HoneyStates.colorOf(naechster)),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'Alle Haken sitzen – weiter geht es beim Abfüllen.',
            style: TextStyle(fontSize: 10, color: _muted, height: 1.35),
          ),
        ],
        const SizedBox(height: 16),
        _markerCard(bucket),
      ],
    );
  }

  /// Eine Zeile der Hakenliste. Rechts steht, was dann auf den Eimer gehört.
  Widget _tickRow({
    required int nummer,
    required String schritt,
    required bool erledigt,
    required bool aktuell,
    required bool tippbar,
  }) {
    final farbe = Color(HoneyStates.colorOf(schritt));
    final striche = HoneyStates.strokeHint(schritt);
    final hakenFarbe = aktuell ? farbe : (erledigt ? _green : _muted);

    return InkWell(
      onTap: tippbar ? () => _toggleTick(nummer) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(
              erledigt ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: hakenFarbe,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                HoneyStates.labelOf(schritt),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: aktuell
                      ? farbe
                      : (erledigt ? Colors.white : _muted),
                  fontWeight: aktuell ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
            if (aktuell && HoneyStates.needsAttention(schritt))
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('wartet auf dich',
                    style: TextStyle(fontSize: 10, color: _muted)),
              ),
            if (striche.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                striche,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: hakenFarbe,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Die Wärmeschrank-Uhr. Gestartet wird hier und nur hier, von Hand.
  ///
  /// Sie hängt ausdrücklich nicht an der Hakenliste: ein Haken beschreibt den
  /// Honig und heißt nicht, dass der Eimer im Schrank steht.
  Widget _warmerCard() {
    final uhr = HoneyWarmer.fromEvents(_events);
    if (uhr == null) return _warmerStart();

    final jetzt = DateTime.now();
    final faellig = uhr.isDue(jetzt);
    final farbe = faellig ? _green : _peach;
    final anteil = (uhr.elapsed(jetzt).inMinutes / (uhr.requiredHours * 60))
        .clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: farbe.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: farbe.withAlpha(140)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.thermostat, size: 17, color: farbe),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      faellig ? 'Fertig – er kann heraus' : 'Im Wärmeschrank',
                      style: TextStyle(
                          fontSize: 14,
                          color: farbe,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('${uhr.requiredHours} h',
                      style: const TextStyle(fontSize: 11, color: _muted)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'seit ${_dauer(uhr.elapsed(jetzt))} · '
                '${uhr.readableRemaining(jetzt)}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${_fertigText(uhr.dueAt)} · hineingestellt '
                '${AppUtils.formatDateTime(uhr.startedAt)}',
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
              if (!_canNotify) ...[
                const SizedBox(height: 6),
                const Text(
                  'Meldungen sind für diese App aus – die Uhr läuft, sie '
                  'meldet sich nur nicht. Umschalten geht in den '
                  'Android-Einstellungen.',
                  style:
                      TextStyle(fontSize: 10, color: _muted, height: 1.35),
                ),
              ],
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: anteil,
                  minHeight: 6,
                  backgroundColor: const Color(0x14ffffff),
                  valueColor: AlwaysStoppedAnimation(farbe),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _stopWarmer,
          icon: const Icon(Icons.output, size: 16),
          label: const Text('Herausgenommen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: farbe,
            side: BorderSide(color: farbe),
            minimumSize: const Size.fromHeight(42),
          ),
        ),
      ],
    );
  }

  Widget _warmerStart() {
    final schonEinmal = HoneyWarmer.wasInBeforeFrom(_events);
    final stunden = HoneyWarmer.hoursFor(wasInBefore: schonEinmal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _startWarmer,
          icon: const Icon(Icons.thermostat, size: 16),
          label: Text('Timer starten · $stunden h'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _peach,
            side: const BorderSide(color: _peach),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          schonEinmal
              ? 'Der Eimer war schon einmal im Schrank, deshalb genügen '
                  '$stunden h. Die Uhr läuft erst, wenn du sie hier '
                  'startest.'
              : 'Beim ersten Mal $stunden h. Die Uhr läuft erst, wenn du sie '
                  'hier startest – ein Haken sagt nichts darüber, wo der '
                  'Eimer steht.',
          style: const TextStyle(fontSize: 10, color: _muted, height: 1.35),
        ),
      ],
    );
  }

  /// „14 h", und unter einer Stunde Minuten – am Schrank hilft nichts anderes.
  String _dauer(Duration d) =>
      d.inMinutes < 60 ? '${d.inMinutes} min' : '${d.inHours} h';

  /// „fertig Do 09:00". Der Wochentag genügt, weil nie mehr als zwei Tage
  /// dazwischenliegen.
  String _fertigText(DateTime wann) =>
      'fertig ${_wochentage[wann.weekday - 1]} '
      '${AppUtils.formatTime(wann)}';

  static const List<String> _wochentage = [
    'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So',
  ];

  /// Die eigene Markierung neben der Kette – grob kristallin, kandiert.
  Widget _markerCard(HoneyBucketModel bucket) {
    final gesetzt = bucket.crystallization;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Eigene Markierung',
            style: TextStyle(
                fontSize: 10,
                color: _muted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final wert in HoneyCrystallization.all)
              _markerChip(wert, wert == gesetzt),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          gesetzt == null
              ? 'Der Honig ist in Ordnung. Wird er grob oder kandiert, hier '
                  'antippen – die Haken bleiben dabei, wie sie sind.'
              : 'Nochmal antippen nimmt die Markierung weg. Der richtige Weg '
                  'zurück führt durch das Melitherm.',
          style: const TextStyle(fontSize: 10, color: _muted, height: 1.35),
        ),
        if (gesetzt != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _throughMelitherm,
            icon: const Icon(Icons.local_fire_department_outlined, size: 16),
            label: const Text('Durch das Melitherm'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _peach,
              side: const BorderSide(color: _peach),
              minimumSize: const Size.fromHeight(42),
            ),
          ),
        ],
      ],
    );
  }

  Widget _markerChip(String wert, bool aktiv) {
    final farbe = Color(HoneyCrystallization.colorOf(wert));

    return InkWell(
      onTap: () => _toggleCrystallization(wert),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: aktiv ? farbe.withAlpha(38) : const Color(0xFF18181c),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: aktiv ? farbe : const Color(0x22ffffff)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(aktiv ? Icons.warning_amber_rounded : Icons.add,
                size: 14, color: aktiv ? farbe : _muted),
            const SizedBox(width: 6),
            Text(
              HoneyCrystallization.labelOf(wert),
              style: TextStyle(
                fontSize: 12,
                color: aktiv ? farbe : _muted,
                fontWeight: aktiv ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
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
        // Ein Rädchen nur, solange wirklich gesucht wird. Vorher hing es an
        // `snap.data == null` — und das ist auch dann null, wenn das Suchen
        // mit einem Fehler endete. Dann drehte es sich für immer.
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()));
        }
        final pfad = snap.data;
        if (pfad == null) {
          return InkWell(
            onTap: _photoSourceChooser,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF18181c),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text('Foto nicht gefunden — antippen zum Ersetzen',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8a8a94))),
            ),
          );
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
