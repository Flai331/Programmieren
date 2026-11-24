import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/stock_service.dart';
import '../utils/app_utils.dart';
import '../utils/feedback_service.dart';

/// Ein Lagerposten: Stammdaten, Bestand und seine Bewegungen.
///
/// Der Bestand ist kein Feld, das man hier setzt – er ist die Summe der
/// Bewegungen darunter. Wer ihn ändern will, bucht einen Zugang, einen
/// Abgang oder macht Inventur. So hat jede Zahl im Lager eine Herkunft.
class StockItemScreen extends StatefulWidget {
  /// Null = neuer Posten.
  final String? itemId;

  /// Vorbelegung beim Anlegen – etwa aus einem Buchungsvorschlag heraus.
  final String? initialCategory;

  const StockItemScreen({Key? key, this.itemId, this.initialCategory})
      : super(key: key);

  @override
  State<StockItemScreen> createState() => _StockItemScreenState();
}

class _StockItemScreenState extends State<StockItemScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);
  static const _green = Color(0xFF22c55e);
  static const _red = Color(0xFFff6b7a);

  final _db = DatabaseService();
  final _stock = StockService();

  final _name = TextEditingController();
  final _unit = TextEditingController();
  final _min = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();

  String _category = StockCategories.other;

  /// Nur bei Gläsern: Sorte und Füllgewicht machen aus dem Posten ein
  /// bestimmtes Glas – „500-g-Glas Sommerblüte".
  String? _variety;
  int? _jarSizeG;

  StockItemModel? _current;
  double _balance = 0;
  List<StockMovementModel> _movements = [];

  bool _loading = true;
  bool _isSaving = false;

  /// Hat sich etwas geändert, das die Liste dahinter neu laden muss?
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Lagerposten');
    _init();
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _min.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      if (widget.itemId != null) {
        _current = await _db.getStockItem(widget.itemId!);
        if (_current != null) {
          _populate(_current!);
          await _loadMovements();
        }
      } else {
        _category = widget.initialCategory ?? StockCategories.other;
        _unit.text = StockCategories.defaultUnitOf(_category);
      }
    } catch (e) {
      _snack('Fehler beim Laden: $e', err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populate(StockItemModel i) {
    _name.text = i.name;
    _category = i.category;
    _unit.text = i.unit;
    _min.text = i.minQuantity == null
        ? ''
        : AppUtils.formatNumber(i.minQuantity!);
    _price.text =
        i.pricePerUnit == null ? '' : AppUtils.formatNumber(i.pricePerUnit!);
    _note.text = i.note ?? '';
    _variety = i.variety;
    _jarSizeG = i.jarSizeG;
  }

  Future<void> _loadMovements() async {
    final id = _current?.id;
    if (id == null) return;
    final bewegungen = await _db.getStockMovements(id, limit: 50);
    final bestaende = await _db.getStockBalances();
    if (!mounted) return;
    setState(() {
      _movements = bewegungen;
      _balance = bestaende[id] ?? 0;
    });
  }

  String? _nullable(String s) => s.trim().isEmpty ? null : s.trim();

  /// Warengruppen, bei denen ein Füllgewicht Sinn hat: abgefüllter Honig
  /// (Ware) und Leergut (Verpackung).
  bool get _hasJarFields =>
      _category == StockCategories.honey || _category == StockCategories.jars;

  /// Die Sorte gehört nur zum abgefüllten Honig. Leere Gläser sind
  /// untereinander gleich, egal welcher Honig später hineinkommt.
  bool get _hasVarietyField => _category == StockCategories.honey;

  StockItemModel _buildModel() => StockItemModel(
        id: _current?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        category: _category,
        unit: _nullable(_unit.text) ?? StockCategories.defaultUnitOf(_category),
        minQuantity: AppUtils.parseNumber(_min.text),
        pricePerUnit: AppUtils.parseNumber(_price.text),
        // Nach einem Wechsel der Warengruppe dürfen Sorte und Füllgewicht
        // nicht am Posten hängen bleiben: Futter hat keine Glasgröße.
        variety: _hasVarietyField ? _variety : null,
        jarSizeG: _hasJarFields ? _jarSizeG : null,
        note: _nullable(_note.text),
        createdAt: _current?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _snack('Der Posten braucht einen Namen', err: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final item = _buildModel();
      if (_current == null) {
        await _db.insertStockItem(item);
      } else {
        await _db.updateStockItem(item);
      }
      FeedbackService.logUserAction('Lagerposten gespeichert',
          context: {'warengruppe': _category});
      if (mounted) {
        _snack('✓ Posten gespeichert');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      FeedbackService.logError(e.toString(), context: 'StockItem._save');
      _snack('Fehler: $e', err: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final item = _current;
    if (item == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Posten löschen'),
        content: Text(_movements.isEmpty
            ? '„${item.name}" wirklich löschen?'
            : '„${item.name}" wirklich löschen? '
                'Die ${_movements.length} Buchungen dazu verschwinden mit.'),
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
      await _db.deleteStockItem(item.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  // ── Buchen ─────────────────────────────────────────────────────

  /// Zugang oder Abgang buchen. [inbound] entscheidet über das Vorzeichen.
  Future<void> _book({required bool inbound}) async {
    final item = _current;
    if (item == null) return;

    final mengeCtrl = TextEditingController();
    final notizCtrl = TextEditingController();
    var grund = inbound ? StockReasons.purchase : StockReasons.consumption;
    var datum = DateTime.now();

    final gebucht = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(inbound ? 'Zugang buchen' : 'Abgang buchen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: mengeCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: false),
                  decoration: _deco('Menge', hint: item.unit),
                ),
                const SizedBox(height: 12),
                const Text('Grund',
                    style: TextStyle(fontSize: 11, color: _muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in inbound
                        ? StockReasons.inbound
                        : StockReasons.outbound)
                      ChoiceChip(
                        label: Text(StockReasons.labelOf(g),
                            style: const TextStyle(fontSize: 11)),
                        selected: grund == g,
                        onSelected: (_) => setLocal(() => grund = g),
                        selectedColor: _peach.withAlpha(51),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: datum,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (picked != null) setLocal(() => datum = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined,
                      size: 15, color: _peach),
                  label: Text(AppUtils.formatDate(datum),
                      style: const TextStyle(color: _peach, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _peach),
                      minimumSize: const Size.fromHeight(40)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notizCtrl,
                  decoration: _deco('Notiz', hint: 'optional'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () {
                final menge = AppUtils.parseNumber(mengeCtrl.text);
                if (menge == null || menge <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Bitte eine Menge größer 0 eingeben')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: inbound ? _green : _peach,
                  foregroundColor: Colors.white),
              child: Text(inbound ? 'Zugang' : 'Abgang'),
            ),
          ],
        ),
      ),
    );

    if (gebucht != true) return;
    final menge = AppUtils.parseNumber(mengeCtrl.text);
    if (menge == null || menge <= 0) return;

    try {
      await _stock.book(
        itemId: item.id,
        // Das Vorzeichen trägt die Richtung, der Grund die Bedeutung.
        quantity: inbound ? menge : -menge,
        reason: grund,
        date: datum,
        note: _nullable(notizCtrl.text),
      );
      _dirty = true;
      await _loadMovements();
      if (mounted) _snack('✓ Gebucht');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  /// Inventur: gezählten Bestand eintragen, die App bucht die Differenz.
  Future<void> _inventory() async {
    final item = _current;
    if (item == null) return;

    final ctrl = TextEditingController(text: AppUtils.formatNumber(_balance));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inventur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wie viel ist tatsächlich da? Gebucht wird die Differenz zu '
              '${StockBalance.formatQuantity(_balance, item.unit)} – '
              'der alte Bestand bleibt damit nachvollziehbar.',
              style: const TextStyle(fontSize: 11, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _deco('Gezählt', hint: item.unit),
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
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final gezaehlt = AppUtils.parseNumber(ctrl.text);
    if (gezaehlt == null) return;
    try {
      final bewegung = await _stock.takeInventory(
          itemId: item.id, countedQuantity: gezaehlt);
      _dirty = true;
      await _loadMovements();
      if (!mounted) return;
      _snack(bewegung == null
          ? 'Bestand stimmte – nichts zu buchen'
          : '✓ Inventur gebucht');
    } catch (e) {
      _snack('Fehler: $e', err: true);
    }
  }

  Future<void> _deleteMovement(StockMovementModel m) async {
    if (m.isLinked) {
      // Buchungen aus Maßnahmen und Rechnungen gehören zu ihrem Ursprung.
      // Sie dort zu ändern hält Lager und Stockkarte beieinander.
      _snack('Diese Buchung stammt aus einer Maßnahme oder Rechnung – '
          'dort ändern');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buchung löschen'),
        content: Text('${m.reasonLabel} '
            '${StockBalance.formatQuantity(m.quantity, _current!.unit)} '
            'vom ${AppUtils.formatDate(m.date)} wirklich löschen?'),
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
      await _db.deleteStockMovement(m.id);
      _dirty = true;
      await _loadMovements();
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

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
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
        appBar: AppBar(title: const Text('Posten')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final neu = _current == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(neu ? 'Neuer Posten' : 'Posten'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Gebuchte Bewegungen sind bereits gespeichert – die Liste
          // dahinter muss davon erfahren, auch wenn nicht gespeichert wird.
          onPressed: () => Navigator.of(context).pop(_dirty),
        ),
        actions: [
          if (!neu)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: _red),
              tooltip: 'Löschen',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (!neu) _balanceCard(),
          if (!neu) const SizedBox(height: 18),

          _section('Posten'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: _deco('Name', hint: 'z.B. Mittelwände Deutsch Normal'),
          ),
          const SizedBox(height: 14),

          _section('Warengruppe'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in StockCategories.all)
                ChoiceChip(
                  label: Text(StockCategories.labelOf(c)),
                  selected: _category == c,
                  onSelected: (_) => setState(() {
                    _category = c;
                    // Einheit nachziehen, solange der Nutzer keine eigene
                    // eingetragen hat.
                    final vorschlag = StockCategories.defaultUnitOf(c);
                    final istVorschlag = StockCategories.all.any((andere) =>
                        StockCategories.defaultUnitOf(andere) == _unit.text);
                    if (_unit.text.isEmpty || istVorschlag) {
                      _unit.text = vorschlag;
                    }
                  }),
                  selectedColor: _peach,
                  labelStyle: TextStyle(
                    color: _category == c ? Colors.white : null,
                    fontWeight: _category == c ? FontWeight.w600 : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Honig und Leergut: Füllgewicht, Honig auch mit Sorte ──
          if (_hasJarFields) ...[
            _section(_hasVarietyField ? 'Welcher Honig?' : 'Welches Glas?'),
            Text(
              _hasVarietyField
                  ? 'Füllgewicht und Sorte machen aus dem Posten ein '
                      'bestimmtes Glas Honig. Nur so kann die App beim '
                      'Abfüllen eines Eimers die richtigen Gläser hochbuchen.'
                  : 'Mit dem Füllgewicht erkennt die App dieses Leergut beim '
                      'Abfüllen und bucht es ab. Ohne Angabe bleibt der '
                      'Posten davon unberührt.',
              style: const TextStyle(fontSize: 11, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in const [250, 500, 1000])
                  ChoiceChip(
                    label: Text(g >= 1000 ? '1 kg' : '$g g'),
                    selected: _jarSizeG == g,
                    onSelected: (v) => setState(() => _jarSizeG = v ? g : null),
                    selectedColor: _peach.withAlpha(51),
                  ),
                ChoiceChip(
                  label: Text(_hasVarietyField
                      ? 'kein Glas (Eimer, Hobbock)'
                      : 'ohne Füllgewicht'),
                  selected: _jarSizeG == null,
                  onSelected: (_) => setState(() => _jarSizeG = null),
                  selectedColor: _peach.withAlpha(51),
                ),
              ],
            ),
            if (_hasVarietyField && _jarSizeG != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final sorte in HoneyVarieties.all)
                    ChoiceChip(
                      label: Text(HoneyVarieties.labelOf(sorte),
                          style: const TextStyle(fontSize: 11)),
                      selected: _variety == sorte,
                      onSelected: (v) =>
                          setState(() => _variety = v ? sorte : null),
                      selectedColor: _peach.withAlpha(51),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
          ],

          _section('Mengen'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _unit,
                  decoration: _deco('Einheit', hint: 'Stk, kg, ml'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _min,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _deco('Mindestbestand', hint: 'optional'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Mit einem Mindestbestand meldet sich die App im Dashboard, '
            'sobald es knapp wird.',
            style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _deco('Preis je Einheit', hint: 'optional, in €'),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _note,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: _deco('Notiz', hint: 'Lieferant, Lagerplatz, …'),
          ),
          const SizedBox(height: 20),

          if (!neu) ...[
            _section('Buchungen'),
            if (_movements.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Noch nichts gebucht. Der Bestand ist die Summe der '
                  'Buchungen – fang mit einem Zugang an.',
                  style:
                      TextStyle(fontSize: 12, color: _muted, height: 1.4),
                ),
              )
            else
              ..._movements.map(_movementRow),
          ],
        ],
      ),
      floatingActionButton: _isSaving
          ? null
          : FloatingActionButton.extended(
              onPressed: _save,
              backgroundColor: _peach,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.check),
              label: const Text('Speichern'),
            ),
    );
  }

  // ── Bestand und Buchungsknöpfe ─────────────────────────────────
  Widget _balanceCard() {
    final item = _current!;
    final stand = StockBalance(item: item, quantity: _balance);
    final farbe = stand.isBelowMinimum
        ? _red
        : (stand.isEmpty ? _muted : _green);

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
                      const Text('Bestand',
                          style: TextStyle(
                              fontSize: 10,
                              color: _muted,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(stand.quantityLabel,
                          style: TextStyle(
                              fontSize: 26,
                              color: farbe,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                if (stand.isBelowMinimum)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'es fehlen '
                      '${StockBalance.formatQuantity(stand.shortfall, item.unit)}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: _red,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                else if (stand.value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(AppUtils.formatCurrency(stand.value!),
                        style:
                            const TextStyle(fontSize: 12, color: _muted)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _book(inbound: true),
                    icon: const Icon(Icons.add, size: 16, color: _green),
                    label: const Text('Zugang',
                        style: TextStyle(color: _green, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _green)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _book(inbound: false),
                    icon: const Icon(Icons.remove, size: 16, color: _peach),
                    label: const Text('Abgang',
                        style: TextStyle(color: _peach, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _peach)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _inventory,
                  icon: const Icon(Icons.fact_check_outlined,
                      size: 20, color: _muted),
                  tooltip: 'Inventur',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Eine Buchung ───────────────────────────────────────────────
  Widget _movementRow(StockMovementModel m) {
    final zugang = m.isInbound;
    final farbe = zugang ? _green : _peach;
    final einheit = _current?.unit ?? '';

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
          Icon(zugang ? Icons.north_east : Icons.south_west,
              size: 15, color: farbe),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.reasonLabel,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(
                  [
                    AppUtils.formatDate(m.date),
                    if (m.isLinked) 'aus Maßnahme',
                    if (m.note != null) m.note!,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 10, color: _muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${zugang ? '+' : ''}'
            '${StockBalance.formatQuantity(m.quantity, einheit)}',
            style: TextStyle(
                fontSize: 13, color: farbe, fontWeight: FontWeight.w700),
          ),
          IconButton(
            onPressed: () => _deleteMovement(m),
            icon: Icon(
              m.isLinked ? Icons.link : Icons.close,
              size: 15,
              color: _muted,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: m.isLinked ? 'Stammt aus einer Maßnahme' : 'Löschen',
          ),
        ],
      ),
    );
  }
}
