import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/honey_service.dart';
import '../utils/app_utils.dart';
import '../utils/bucket_code.dart';
import '../utils/feedback_service.dart';
import 'honey_bucket_new_screen.dart';
import 'honey_bucket_screen.dart';

/// Honiglager: alle Eimer mit Sorte, Menge und Zustand.
///
/// Die wichtigste Frage beantwortet die Liste oben: Was wartet auf mich?
/// „Zeig mir alles, was gerührt werden muss" ist ein Tipp auf einen Chip.
class HoneyStockScreen extends StatefulWidget {
  const HoneyStockScreen({Key? key}) : super(key: key);

  @override
  State<HoneyStockScreen> createState() => _HoneyStockScreenState();
}

class _HoneyStockScreenState extends State<HoneyStockScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);
  static const _red = Color(0xFFff6b7a);

  final _honey = HoneyService();

  List<HoneyBucketStatus> _all = [];
  bool _loading = true;

  /// Zustands-Filter, null = alle.
  String? _state;

  /// Nur Eimer, an denen etwas zu tun ist.
  bool _onlyOpen = false;

  /// Leere Eimer ausblenden – sie sind erledigt, aber als Nachweis da.
  bool _hideEmpty = true;

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Honiglager');
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _honey.loadBuckets();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  List<HoneyBucketStatus> get _visible => _all.where((s) {
        if (_hideEmpty && s.bucket.isEmpty) return false;
        if (_onlyOpen && !s.needsAttention) return false;
        if (_state != null && s.bucket.state != _state) return false;
        return true;
      }).toList(growable: false);

  Future<void> _openBucket(String id) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => HoneyBucketScreen(bucketId: id)),
    );
    // Immer neu laden: Im Eimer kann abgefüllt oder gelöscht worden sein,
    // und über die Systemgeste verlassen meldet er nichts zurück.
    if (mounted) await _load();
  }

  Future<void> _newBucket() async {
    final angelegt = await Navigator.of(context).push<HoneyBucketModel>(
      MaterialPageRoute(builder: (_) => const HoneyBucketNewScreen()),
    );
    if (!mounted) return;
    await _load();
    if (angelegt != null && mounted) await _openBucket(angelegt.id);
  }

  // ── Code eingeben ──────────────────────────────────────────────

  /// Code von Hand eintippen – der Weg, der immer geht.
  ///
  /// Drei Ziffern genügen: Die Nummer läuft global, also identifiziert sie
  /// den Eimer auch ohne Sortenkürzel.
  Future<void> _enterCode() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code eingeben'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Was steht auf dem Eimer? Die drei Ziffern genügen – das '
              'Sortenkürzel darf fehlen oder verwischt sein.',
              style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Code',
                hintText: 'z.B. 042 oder SO-042',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _peach, foregroundColor: Colors.white),
            child: const Text('Suchen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final eingabe = ctrl.text.trim();
    if (eingabe.isEmpty) return;
    await _resolveCode(eingabe);
  }

  /// Eine Lesung einem Eimer zuordnen – oder fragen, statt zu raten.
  Future<void> _resolveCode(String read) async {
    final treffer = await _honey.lookupCode(read);
    if (!mounted) return;

    // Eindeutig und Zeichen für Zeichen getroffen: direkt öffnen.
    if (treffer.isResolved && !treffer.needsConfirmation) {
      await _openBucket(treffer.bucket!.id);
      return;
    }

    // Erst nach Ausgleich typischer Verwechslungen getroffen: zeigen,
    // worauf die App gekommen ist.
    if (treffer.isResolved) {
      final bucket = treffer.bucket!;
      final ja = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Meinst du diesen?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(bucket.code,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
              const SizedBox(height: 8),
              Text(
                '${bucket.varietyLabel} · '
                '${AppUtils.formatDate(bucket.harvestDate)}'
                '${bucket.location == null ? '' : ' · ${bucket.location}'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 10),
              Text('Gelesen: „$read"',
                  style: const TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Nein')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _peach, foregroundColor: Colors.white),
              child: const Text('Ja, der'),
            ),
          ],
        ),
      );
      if (ja == true && mounted) await _openBucket(bucket.id);
      return;
    }

    // Mehrere kommen in Frage: auswählen lassen.
    if (treffer.isAmbiguous && treffer.match.candidates.isNotEmpty) {
      final gewaehlt = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('Mehrere kommen in Frage',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'Die App rät nicht. Welcher ist es?',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
              ),
              for (final code in treffer.match.candidates)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.inventory_2_outlined,
                      size: 18, color: _peach),
                  title: Text(code,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, letterSpacing: 1)),
                  subtitle: Text(_describeCode(code),
                      style: const TextStyle(fontSize: 10, color: _muted)),
                  onTap: () => Navigator.pop(ctx, code),
                ),
            ],
          ),
        ),
      );
      if (gewaehlt == null || !mounted) return;
      String? id;
      for (final s in _all) {
        if (s.bucket.code == gewaehlt) id = s.bucket.id;
      }
      if (id != null) {
        await _openBucket(id);
      } else {
        // Der Code kommt frisch aus der Datenbank, die geladene Liste ist
        // also veraltet. Ein zweiter Durchgang trifft ihn genau.
        await _resolveCode(gewaehlt);
      }
      return;
    }

    // Nichts gefunden.
    _snack(BucketCode.isWellFormed(read)
        ? 'Keinen Eimer mit „$read" gefunden'
        : '„$read" sieht nach keinem Eimer-Code aus');
  }

  /// Kurzbeschreibung zu einem Code aus der geladenen Liste.
  String _describeCode(String code) {
    for (final s in _all) {
      if (s.bucket.code == code) {
        return '${s.bucket.varietyLabel} · ${s.currentLabel} · '
            '${s.bucket.stateLabel}';
      }
    }
    return '';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final sichtbar = _visible;
    final offen = HoneyService.needingAttention(_all);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Honiglager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_alt_outlined),
            tooltip: 'Code eingeben',
            onPressed: _enterCode,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (_all.isNotEmpty) ...[
                    _summary(offen.length),
                    const SizedBox(height: 12),
                    _varietyBreakdown(),
                    const SizedBox(height: 12),
                    _filterChips(offen.length),
                    const SizedBox(height: 12),
                  ],
                  if (_all.isEmpty)
                    _emptyState()
                  else if (sichtbar.isEmpty)
                    _noMatches()
                  else
                    ...sichtbar.map(_row),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newBucket,
        backgroundColor: _peach,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Eimer'),
      ),
    );
  }

  // ── Kennzahlen ─────────────────────────────────────────────────
  Widget _summary(int offeneAnzahl) {
    final kg = HoneyService.totalKg(_all);
    final voll = _all.where((s) => s.currentKg > 0).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
                child: _metric(
                    'Honig', '${AppUtils.formatNumber(kg)} kg', _peach)),
            Expanded(child: _metric('Eimer', '$voll', _muted)),
            Expanded(
              child: _metric('wartet auf dich', '$offeneAnzahl',
                  offeneAnzahl > 0 ? _red : const Color(0xFF22c55e)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: _muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 16, color: color, fontWeight: FontWeight.w700)),
        ],
      );

  // ── kg je Sorte ────────────────────────────────────────────────
  Widget _varietyBreakdown() {
    final jeSorte = HoneyService.kgPerVariety(_all);
    if (jeSorte.isEmpty) return const SizedBox.shrink();

    // Die größte Menge zuerst – so steht oben, was den Keller füllt.
    final sortiert = jeSorte.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in sortiert)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF18181c),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x14ffffff)),
              ),
              child: Row(
                children: [
                  Text(HoneyVarieties.labelOf(e.key),
                      style: const TextStyle(fontSize: 11, color: _muted)),
                  const SizedBox(width: 6),
                  Text('${AppUtils.formatNumber(e.value)} kg',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Filterleiste ───────────────────────────────────────────────
  Widget _filterChips(int offeneAnzahl) {
    // Nur Zustände zeigen, in denen tatsächlich ein Eimer steht.
    final vorhanden = HoneyStates.all
        .where((z) => _all.any((s) => s.bucket.state == z))
        .toList(growable: false);
    final hatLeere = _all.any((s) => s.bucket.isEmpty);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (offeneAnzahl > 0) ...[
            FilterChip(
              label: Text('Zu tun ($offeneAnzahl)'),
              selected: _onlyOpen,
              onSelected: (v) => setState(() {
                _onlyOpen = v;
                if (v) _state = null;
              }),
              selectedColor: _red.withAlpha(51),
              checkmarkColor: _red,
            ),
            const SizedBox(width: 6),
          ],
          if (hatLeere) ...[
            FilterChip(
              label: const Text('Leere zeigen'),
              selected: !_hideEmpty,
              onSelected: (v) => setState(() => _hideEmpty = !v),
              selectedColor: _muted.withAlpha(51),
              checkmarkColor: _muted,
            ),
            const SizedBox(width: 6),
          ],
          ChoiceChip(
            label: const Text('Alle'),
            selected: _state == null,
            onSelected: (_) => setState(() => _state = null),
            selectedColor: _peach.withAlpha(51),
          ),
          for (final z in vorhanden) ...[
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(HoneyStates.labelOf(z),
                  style: const TextStyle(fontSize: 11)),
              selected: _state == z,
              onSelected: (_) => setState(() {
                _state = z;
                _onlyOpen = false;
                // Wer nach „leer" filtert, will die leeren auch sehen.
                if (z == HoneyStates.empty) _hideEmpty = false;
              }),
              selectedColor: Color(HoneyStates.colorOf(z)).withAlpha(51),
            ),
          ],
        ],
      ),
    );
  }

  // ── Eine Zeile ─────────────────────────────────────────────────
  Widget _row(HoneyBucketStatus s) {
    final bucket = s.bucket;
    final farbe = Color(HoneyStates.colorOf(bucket.state));
    final striche = HoneyStates.strokeHint(bucket.state);

    return InkWell(
      onTap: () => _openBucket(bucket.id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF18181c),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: s.needsAttention && !bucket.isEmpty
                ? farbe.withAlpha(140)
                : const Color(0x14ffffff),
          ),
        ),
        child: Row(
          children: [
            // Der Code, wie er auf dem Eimer steht – samt Strichkästchen.
            SizedBox(
              width: 74,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bucket.code,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: bucket.isEmpty ? _muted : null,
                      )),
                  if (striche.isNotEmpty)
                    Text(striche,
                        style: TextStyle(
                            fontSize: 11,
                            color: farbe,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bucket.varietyLabel,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    [
                      bucket.stateLabel,
                      if (bucket.location != null) bucket.location!,
                    ].join(' · '),
                    style: TextStyle(fontSize: 10, color: farbe),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(s.currentLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: bucket.isEmpty ? _muted : null,
                    )),
                Text(AppUtils.formatDate(bucket.harvestDate),
                    style: const TextStyle(fontSize: 9, color: _muted)),
              ],
            ),
            if (s.needsAttention && !bucket.isEmpty) ...[
              const SizedBox(width: 6),
              Icon(Icons.priority_high, size: 15, color: farbe),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noMatches() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            _onlyOpen
                ? 'Nichts zu tun – alle Eimer ruhen'
                : 'Kein Eimer in diesem Zustand',
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
      );

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.hive_outlined, size: 56, color: _muted),
            const SizedBox(height: 16),
            const Text('Noch kein Eimer im Lager',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Leg einen Eimer an – die App vergibt einen Code wie '
                '„SO-042", den du mit Stift auf den Deckel schreibst. '
                'Dazu ein Kästchen mit Strichen für den Zustand. Später '
                'genügen die drei Ziffern, um den Eimer wiederzufinden.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _newBucket,
              icon: const Icon(Icons.add),
              label: const Text('Ersten Eimer anlegen'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _peach, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
}
