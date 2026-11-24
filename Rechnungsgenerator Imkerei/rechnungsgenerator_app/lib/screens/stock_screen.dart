import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/stock_service.dart';
import '../utils/app_utils.dart';
import '../utils/feedback_service.dart';
import 'stock_item_screen.dart';

/// Lager: alle Posten mit ihrem Bestand.
class StockScreen extends StatefulWidget {
  const StockScreen({Key? key}) : super(key: key);

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);
  static const _green = Color(0xFF22c55e);
  static const _red = Color(0xFFff6b7a);

  final _stock = StockService();
  final _searchCtrl = TextEditingController();

  List<StockBalance> _all = [];
  bool _loading = true;

  /// Warengruppen-Filter, null = alle.
  String? _category;

  /// Nur Posten unter Mindestbestand zeigen.
  bool _onlyLow = false;

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Lager');
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _stock.loadBalances();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  /// Sichtbare Posten nach Suche und Filtern.
  List<StockBalance> get _visible {
    final suche = StockItemModel.normalizeName(_searchCtrl.text);
    return _all.where((b) {
      if (_category != null && b.item.category != _category) return false;
      if (_onlyLow && !b.isBelowMinimum) return false;
      if (suche.isEmpty) return true;
      return b.item.matchKey.contains(suche) ||
          StockItemModel.normalizeName(b.item.categoryLabel).contains(suche);
    }).toList(growable: false);
  }

  Future<void> _openItem({StockItemModel? item}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StockItemScreen(itemId: item?.id)),
    );
    // Immer neu laden, ohne auf eine Rückmeldung zu warten: Im Posten kann
    // gebucht worden sein, und über die Systemgeste verlassen meldet er
    // nichts zurück.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final sichtbar = _visible;
    final knapp = StockService.belowMinimum(_all);
    final wert = StockService.totalValue(_all);

    return Scaffold(
      appBar: AppBar(title: const Text('Lager')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (_all.isNotEmpty) _summary(knapp.length, wert),
                  if (_all.isNotEmpty) const SizedBox(height: 12),
                  if (_all.isNotEmpty) ...[
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Posten suchen…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchCtrl.clear(),
                              ),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _filterChips(knapp.length),
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
        onPressed: () => _openItem(),
        backgroundColor: _peach,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Posten'),
      ),
    );
  }

  // ── Kopfzeile mit Kennzahlen ───────────────────────────────────
  Widget _summary(int knappeAnzahl, double wert) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _metric('Posten', '${_all.length}', _muted),
            ),
            Expanded(
              child: _metric(
                'unter Mindestbestand',
                '$knappeAnzahl',
                knappeAnzahl > 0 ? _red : _green,
              ),
            ),
            if (wert > 0)
              Expanded(
                child: _metric(
                    'Lagerwert', AppUtils.formatCurrency(wert), _peach),
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

  // ── Filterleiste ───────────────────────────────────────────────
  Widget _filterChips(int knappeAnzahl) {
    // Nur Warengruppen zeigen, in denen tatsächlich etwas liegt – eine
    // leere Gruppe anzutippen hilft niemandem.
    final vorhanden = StockCategories.all
        .where((c) => _all.any((b) => b.item.category == c))
        .toList(growable: false);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (knappeAnzahl > 0) ...[
            FilterChip(
              label: Text('Knapp ($knappeAnzahl)'),
              selected: _onlyLow,
              onSelected: (v) => setState(() => _onlyLow = v),
              selectedColor: _red.withAlpha(51),
              checkmarkColor: _red,
            ),
            const SizedBox(width: 6),
            const SizedBox(
              height: 24,
              child: VerticalDivider(width: 12, color: Color(0x22ffffff)),
            ),
          ],
          ChoiceChip(
            label: const Text('Alle'),
            selected: _category == null,
            onSelected: (_) => setState(() => _category = null),
            selectedColor: _peach.withAlpha(51),
          ),
          for (final c in vorhanden) ...[
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(StockCategories.labelOf(c)),
              selected: _category == c,
              onSelected: (_) => setState(() => _category = c),
              selectedColor: _peach.withAlpha(51),
            ),
          ],
        ],
      ),
    );
  }

  // ── Eine Zeile ─────────────────────────────────────────────────
  Widget _row(StockBalance b) {
    final knapp = b.isBelowMinimum;
    final farbe = knapp ? _red : (b.isEmpty ? _muted : _green);

    return InkWell(
      onTap: () => _openItem(item: b.item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF18181c),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: knapp ? _red.withAlpha(120) : const Color(0x14ffffff)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.item.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    knapp
                        ? '${b.item.categoryLabel} · es fehlen '
                            '${StockBalance.formatQuantity(b.shortfall, b.unit)}'
                        : b.item.categoryLabel,
                    style: TextStyle(
                        fontSize: 10, color: knapp ? _red : _muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(b.quantityLabel,
                    style: TextStyle(
                        fontSize: 14,
                        color: farbe,
                        fontWeight: FontWeight.w700)),
                if (b.item.hasMinimum)
                  Text(
                      'min. '
                      '${StockBalance.formatQuantity(b.item.minQuantity!, b.unit)}',
                      style: const TextStyle(fontSize: 9, color: _muted)),
              ],
            ),
            if (knapp) ...[
              const SizedBox(width: 6),
              const Icon(Icons.warning_amber_rounded, size: 16, color: _red),
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
            _onlyLow
                ? 'Kein Posten unter Mindestbestand'
                : 'Keine Treffer',
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
      );

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56, color: _muted),
            const SizedBox(height: 16),
            const Text('Das Lager ist noch leer',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Lege an, was du vorrätig hast: Honig, Gläser, Futter, '
                'Mittelwände, Behandlungsmittel. Mit einem Mindestbestand '
                'meldet sich die App, sobald es knapp wird.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openItem(),
              icon: const Icon(Icons.add),
              label: const Text('Ersten Posten anlegen'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _peach, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
}
