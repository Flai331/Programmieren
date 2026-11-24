import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/season_service.dart';
import '../services/stock_service.dart';
import '../utils/app_utils.dart';
import '../utils/feedback_service.dart';
import 'hive_action_edit_screen.dart';
import 'stock_item_screen.dart';

/// Eine Saison-Aufgabe im Detail: Packliste zum Abhaken und die Völker,
/// bei denen sie noch offen ist.
class SeasonTaskDetailScreen extends StatefulWidget {
  final SeasonTaskStatus status;

  const SeasonTaskDetailScreen({Key? key, required this.status})
      : super(key: key);

  @override
  State<SeasonTaskDetailScreen> createState() =>
      _SeasonTaskDetailScreenState();
}

class _SeasonTaskDetailScreenState extends State<SeasonTaskDetailScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);
  static const _green = Color(0xFF22c55e);
  static const _red = Color(0xFFff6b7a);

  final _db = DatabaseService();

  late SeasonTaskStatus _status;

  /// Abgehakte Packlisten-Posten. Nur für den laufenden Arbeitsgang gedacht
  /// und deshalb bewusst nicht gespeichert – beim nächsten Öffnen richtet
  /// sich die Liste ohnehin neu nach den dann offenen Völkern.
  final Set<String> _packed = {};

  /// Hat sich etwas geändert? Steuert das Neuladen der Saison-Übersicht.
  bool _changed = false;

  /// Lagerbestände, um die Packliste dagegen zu halten. Leer, solange noch
  /// nicht geladen – die Packliste steht dann ohne Bestandsangabe, was
  /// besser ist als ein Platzhalter, der nach Fehlmenge aussieht.
  List<StockBalance> _balances = [];

  SeasonTask get _task => _status.task;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    FeedbackService.logScreenLoad('Saison-Aufgabe',
        additionalInfo: _task.id);
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    final bestaende = await StockService().loadBalances();
    if (!mounted) return;
    setState(() => _balances = bestaende);
  }

  /// Stand dieser Aufgabe neu berechnen, nachdem eine Maßnahme erfasst wurde.
  Future<void> _refresh() async {
    final hives = await _db.getAllHives();
    final actions = await _db.getAllHiveActions();
    final alle = SeasonService.buildStatuses(
      hives: hives,
      actions: actions,
      reference: DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _status = alle.firstWhere(
        (s) => s.task.id == _task.id,
        orElse: () => _status,
      );
    });
    // Beim Erfassen kann Material gebucht worden sein – die Packliste muss
    // den neuen Bestand zeigen.
    await _loadBalances();
  }

  Future<void> _recordFor(HiveModel hive) async {
    final gespeichert = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HiveActionEditScreen(
          hiveId: hive.id,
          hiveLabel: hive.displayLabel,
          initialType: _task.actionType,
          seasonTask: _task.id,
        ),
      ),
    );
    if (gespeichert == true) {
      _changed = true;
      await _refresh();
    }
  }

  Future<void> _openExisting(HiveActionModel action, HiveModel hive) async {
    final gespeichert = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HiveActionEditScreen(
          hiveId: hive.id,
          hiveLabel: hive.displayLabel,
          actionId: action.id,
        ),
      ),
    );
    if (gespeichert == true) {
      _changed = true;
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final offen = _status.openHives;
    final erledigt = _status.doneHives;
    final packliste = _status.packList;
    // Was auf der Liste steht, gegen das gehalten, was im Lager liegt.
    final abgleich = StockService.coverage(packliste, _balances);
    final fehlt = abgleich.where((c) => c.isShort).toList(growable: false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_task.title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_task.description,
                style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),

            // ── Fortschritt ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_status.doneCount} von ${_status.total} Völkern',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        if (_status.isComplete)
                          const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 16, color: _green),
                              SizedBox(width: 4),
                              Text('abgeschlossen',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _green,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _status.progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF26262c),
                        valueColor: AlwaysStoppedAnimation(
                            _status.isComplete ? _green : _peach),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Packliste, gegen das Lager gehalten ──
            if (packliste.isNotEmpty) ...[
              _section('Packliste'),
              Text(
                _status.openCount == 0
                    ? 'Nichts mehr offen – alle Völker sind versorgt.'
                    : 'Mengen für ${_status.openCount} offene '
                        '${_status.openCount == 1 ? "Volk" : "Völker"}',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final c in abgleich) _packRow(c),
                  ],
                ),
              ),
              if (fehlt.isNotEmpty) ...[
                const SizedBox(height: 8),
                _shortfallHint(fehlt),
              ],
              const SizedBox(height: 20),
            ],

            // ── Offene Völker ──
            _section('Offen (${offen.length})'),
            if (offen.isEmpty)
              _hint('Alle Völker erledigt')
            else
              for (final h in offen) _openHiveRow(h.hive),

            const SizedBox(height: 20),

            // ── Erledigte Völker ──
            _section('Erledigt (${erledigt.length})'),
            if (erledigt.isEmpty)
              _hint('Noch nichts erfasst')
            else
              for (final h in erledigt) _doneHiveRow(h),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: const TextStyle(
                color: _peach, fontSize: 14, fontWeight: FontWeight.bold)),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: _muted)),
      );

  Widget _packRow(StockCoverage c) {
    final e = c.entry;
    final abgehakt = _packed.contains(e.item.name);

    // Die Unterzeile sagt, wie der Posten zum Lager steht. Ein Posten, den
    // das Lager nicht führt, bekommt gar keine – „unbekannt" ist keine
    // Fehlmenge, und die App soll nicht so tun als wüsste sie mehr.
    final String? unterzeile;
    if (c.isShort) {
      unterzeile = '${c.stockLabel} · '
          '${StockBalance.formatQuantity(c.missing, c.balance!.unit)} fehlen';
    } else if (!c.isUnknown) {
      unterzeile = c.stockLabel;
    } else {
      unterzeile = null;
    }

    return CheckboxListTile(
      value: abgehakt,
      onChanged: (v) => setState(() {
        if (v == true) {
          _packed.add(e.item.name);
        } else {
          _packed.remove(e.item.name);
        }
      }),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      activeColor: _peach,
      title: Text(
        e.label,
        style: TextStyle(
          fontSize: 13,
          decoration: abgehakt ? TextDecoration.lineThrough : null,
          color: abgehakt ? _muted : null,
        ),
      ),
      subtitle: unterzeile == null
          ? null
          : Text(unterzeile,
              style: TextStyle(
                  fontSize: 10, color: c.isShort ? _red : _muted)),
      secondary: e.quantityLabel.isEmpty
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(e.quantityLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: c.isShort ? _red : _peach,
                        fontWeight: FontWeight.w600)),
                if (c.isShort)
                  const Icon(Icons.warning_amber_rounded,
                      size: 13, color: _red),
              ],
            ),
    );
  }

  /// Zusammenfassung der Fehlmengen – der Einkaufszettel zu dieser Arbeit.
  Widget _shortfallHint(List<StockCoverage> fehlt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _red.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _red.withAlpha(110)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shopping_basket_outlined, size: 16, color: _red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Das fehlt im Lager',
                    style: TextStyle(
                        fontSize: 11,
                        color: _red,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                // Jede Zeile führt zum Posten: Von hier aus ist der
                // Zugang gebucht, sobald das Fehlende eingekauft ist.
                for (final c in fehlt)
                  InkWell(
                    onTap: () => _openStockItem(c.balance!.item.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${c.label}: '
                              '${StockBalance.formatQuantity(c.missing, c.balance!.unit)}',
                              style: const TextStyle(
                                  fontSize: 11, height: 1.4),
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 14, color: _muted),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStockItem(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StockItemScreen(itemId: id)),
    );
    await _loadBalances();
  }

  Widget _openHiveRow(HiveModel hive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.radio_button_unchecked,
            size: 20, color: _peach),
        title: Text(hive.displayLabel,
            style: const TextStyle(fontSize: 13)),
        subtitle: (hive.location ?? '').isEmpty
            ? null
            : Text(hive.location!,
                style: const TextStyle(fontSize: 11, color: _muted)),
        trailing: TextButton(
          onPressed: () => _recordFor(hive),
          child: const Text('Erfassen',
              style: TextStyle(color: _peach, fontSize: 12)),
        ),
        onTap: () => _recordFor(hive),
      ),
    );
  }

  Widget _doneHiveRow(SeasonHiveStatus h) {
    final action = h.fulfilledBy!;
    final summary = action.summary;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.check_circle, size: 20, color: _green),
        title: Text(h.hive.displayLabel,
            style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          summary.isEmpty
              ? AppUtils.formatDate(action.date)
              : '${AppUtils.formatDate(action.date)} · $summary',
          style: const TextStyle(fontSize: 11, color: _muted),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _openExisting(action, h.hive),
      ),
    );
  }
}
