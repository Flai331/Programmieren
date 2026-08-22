import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../services/season_service.dart';
import '../models/models.dart';
import '../utils/feedback_service.dart';
import '../utils/utils.dart';
import 'invoice_edit_screen.dart';
import 'season_task_detail_screen.dart';

// ── Kachel-Definition ────────────────────────────────────────────
class _TileDef {
  final String id;
  final String title;
  final IconData icon;
  final _C style;
  const _TileDef(this.id, this.title, this.icon, this.style);
}

/// Ergebnis eines Dashboard-Ladevorgangs.
///
/// Kacheln UND Listen werden aus genau diesem Objekt gerendert. Früher hielten
/// die Kacheln ihren Wert in einem veränderlichen Feld, das ein parallel
/// laufender (älterer) Ladevorgang überschreiben konnte – dadurch zeigten die
/// Kacheln andere Zahlen als die Liste darunter.
class _DashboardStats {
  final String revenue;
  final int total;
  final int customers;
  final int paid;
  final int sent;
  final int draft;
  final List<InvoiceModel> openInvoices;
  final List<InvoiceModel> openQuotes;
  final List<InvoiceModel> doneQuotes;
  final Map<String, String> customerMap;

  /// Saison-Aufgaben, die diesen Monat anstehen und noch offene Völker haben.
  final List<SeasonTaskStatus> seasonOpen;

  const _DashboardStats({
    required this.revenue,
    required this.total,
    required this.customers,
    required this.paid,
    required this.sent,
    required this.draft,
    required this.openInvoices,
    required this.openQuotes,
    required this.doneQuotes,
    required this.customerMap,
    required this.seasonOpen,
  });

  String valueFor(String tileId) => switch (tileId) {
        'revenue' => revenue,
        'total' => '$total',
        'customers' => '$customers',
        'paid' => '$paid',
        'sent' => '$sent',
        'draft' => '$draft',
        _ => '–',
      };
}

class DashboardScreen extends StatefulWidget {
  /// Wechselt zu einem Tab in der Hauptnavigation
  /// (0=Start, 1=Völker, 2=Rechnungen, 3=Kunden, …).
  ///
  /// [invoiceStatusFilter] setzt beim Rechnungs-Tab direkt den Status-Filter,
  /// damit die Liste genau die Datensätze zeigt, die die Kachel gezählt hat.
  final void Function(int tabIndex, {String? invoiceStatusFilter})? onNavigate;
  const DashboardScreen({Key? key, this.onNavigate}) : super(key: key);
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dbService = DatabaseService();
  late Future<_DashboardStats> _statsFuture;

  /// Zuletzt fertig geladener Stand – überbrückt das Neuladen, damit die
  /// Kacheln beim Refresh nicht kurz auf „–" springen.
  _DashboardStats? _lastStats;

  // Kachel-Reihenfolge (drag-and-drop veränderbar)
  late List<_TileDef> _tiles;

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Dashboard');
    _tiles = [
      const _TileDef('revenue',   'Umsatz',      Icons.euro_outlined,         _C.accent),
      const _TileDef('total',     'Rechnungen',  Icons.receipt_outlined,      _C.info),
      const _TileDef('customers', 'Kunden',      Icons.people_outline,        _C.neutral),
      const _TileDef('paid',      'Bezahlt',     Icons.check_circle_outline,  _C.success),
      const _TileDef('sent',      'Gestellt',    Icons.send_outlined,         _C.warning),
      const _TileDef('draft',     'Entwurf',     Icons.edit_outlined,         _C.neutral),
    ];
    _statsFuture = _load();
  }

  /// Neu laden. Eigene Methode statt `setState(() => _statsFuture = _load())`:
  /// eine Arrow-Funktion liefert die zugewiesene Future zurück, und `setState`
  /// bricht bei einem Future-Rückgabewert mit einer Assertion ab.
  void _reload() {
    if (!mounted) return;
    setState(() {
      _statsFuture = _load();
    });
  }

  Future<_DashboardStats> _load() async {
    final all       = await _dbService.getAllInvoices();
    // Angebote zählen NICHT als Umsatz/Rechnung
    final invoices  = all.where((i) => i.documentType == 'invoice').toList();
    final quotes    = all.where((i) => i.documentType == 'quote').toList();
    final customers = await _dbService.getAllCustomers();
    final customerMap = {for (final c in customers) c.id: c.name};

    // Saison: nur was jetzt ansteht und noch nicht überall erledigt ist.
    final saison = SeasonService.due(await SeasonService().loadAll())
        .where((s) => s.openCount > 0)
        .toList(growable: false);
    double revenue = 0;
    int paid = 0, sent = 0, draft = 0;
    for (final inv in invoices) {
      revenue += inv.total;
      // normalizedStatus: identische Zählung wie in der Rechnungsliste
      switch (inv.normalizedStatus) {
        case 'paid': paid++;
        case 'sent': sent++;
        default:     draft++;
      }
    }

    // Dashboard-Listen: nur offene + abgearbeitete Angebote
    int byDate(InvoiceModel a, InvoiceModel b) => b.date.compareTo(a.date);
    final openInvoices =
        invoices.where((i) => i.normalizedStatus != 'paid').toList()
          ..sort(byDate);
    final openQuotes = quotes
        .where((q) =>
            q.normalizedStatus == 'draft' || q.normalizedStatus == 'sent')
        .toList()
      ..sort(byDate);
    final doneQuotes = quotes
        .where((q) =>
            q.normalizedStatus == 'accepted' || q.normalizedStatus == 'rejected')
        .toList()
      ..sort(byDate);

    final stats = _DashboardStats(
      revenue:      AppUtils.formatCurrency(revenue),
      total:        invoices.length,
      customers:    customers.length,
      paid:         paid,
      sent:         sent,
      draft:        draft,
      openInvoices: openInvoices,
      openQuotes:   openQuotes,
      doneQuotes:   doneQuotes,
      customerMap:  customerMap,
      seasonOpen:   saison,
    );
    return stats;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
      case 'accepted': return const Color(0xFF22c55e);
      case 'sent':     return const Color(0xFFf59e0b);
      case 'rejected': return const Color(0xFFff6b7a);
      default:         return const Color(0xFF8a8a94);
    }
  }

  String _statusLabel(String status, bool isQuote) {
    switch (status) {
      case 'paid':     return 'Bezahlt';
      case 'accepted': return 'Angenommen';
      case 'sent':     return isQuote ? 'Versandt' : 'Gestellt';
      case 'rejected': return 'Abgelehnt';
      default:         return 'Entwurf';
    }
  }

  // Angebot → Rechnung umwandeln (direkt vom Dashboard)
  Future<void> _convertToInvoice(InvoiceModel quote) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('In Rechnung umwandeln'),
        content: Text('Angebot ${quote.invoiceNumber} als neue Rechnung übernehmen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Umwandeln'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final companies = await _dbService.getAllCompanies();
      final pattern = companies.isNotEmpty
          ? companies.first.invoiceNumberPattern
          : InvoiceNumberGenerator.defaultPattern;
      final existing = await _dbService.getAllInvoiceNumbers();
      final customer = await _dbService.getCustomer(quote.customerId);
      final newNumber = InvoiceNumberGenerator.generate(
        pattern: pattern,
        existingNumbers: existing,
        customerName: customer?.name,
        customerNumber: customer?.customerNumber,
      );
      final newId = const Uuid().v4();
      final invoice = quote.copyWith(
        id: newId,
        invoiceNumber: newNumber,
        documentType: 'invoice',
        status: 'draft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _dbService.insertInvoice(invoice);
      final items = await _dbService.getInvoiceItems(quote.id);
      for (final item in items) {
        await _dbService.insertInvoiceItem(
          item.copyWith(id: const Uuid().v4(), invoiceId: newId),
        );
      }
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Rechnung $newNumber erstellt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onReorder(int from, int to) {
    setState(() {
      if (to > from) to--;
      final tile = _tiles.removeAt(from);
      _tiles.insert(to, tile);
    });
  }

  // Kachel-Tap → passenden Tab öffnen (Index nach Nav-Layout in main_navigation_screen)
  //
  // Status-Kacheln öffnen die Rechnungsliste direkt mit dem passenden Filter,
  // damit dort exakt die Datensätze stehen, die die Kachel gezählt hat.
  void _onTileTap(String id) {
    if (id == 'customers') {
      widget.onNavigate?.call(3); // Kunden
      return;
    }
    final filter = switch (id) {
      'paid'  => 'paid',
      'sent'  => 'sent',
      'draft' => 'draft',
      _       => 'all', // Umsatz + Rechnungen → alle Rechnungen
    };
    widget.onNavigate?.call(2, invoiceStatusFilter: filter);
  }

  // Dokument öffnen/bearbeiten
  Future<void> _openInvoice(InvoiceModel doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceEditScreen(invoiceId: doc.id),
      ),
    );
    _reload();
  }

  // Status zyklisch ändern – je Dokumenttyp
  Future<void> _cycleStatus(InvoiceModel doc) async {
    final order = doc.statusOrder;
    final idx = order.indexOf(doc.normalizedStatus);
    final next = order[(idx + 1) % order.length];
    await _dbService.updateInvoiceStatus(doc.id, next);
    _reload();
  }

  // Saison-Aufgabe öffnen, ohne den Tab zu wechseln.
  Future<void> _openSeasonTask(SeasonTaskStatus status) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SeasonTaskDetailScreen(status: status),
      ),
    );
    if (changed == true) _reload();
  }

  Widget _seasonRow(SeasonTaskStatus s) {
    return InkWell(
      onTap: () => _openSeasonTask(s),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF18181c),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x14ffffff)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_note_outlined,
                size: 16, color: Color(0xFFfda085)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.task.title,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text('${s.doneCount} von ${s.total} Völkern erledigt',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF8a8a94))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFfda085).withAlpha(38),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFfda085), width: 1),
              ),
              child: Text('${s.openCount} offen',
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFfda085),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$title ($count)',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: const Color(0xFF8a8a94))),
    );
  }

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(text,
              style: const TextStyle(color: Color(0xFF8a8a94), fontSize: 12)),
        ),
      );

  Widget _docRow(InvoiceModel doc, Map<String, String> customerMap,
      {bool showConvert = false}) {
    final color = _statusColor(doc.normalizedStatus);
    final label = _statusLabel(doc.normalizedStatus, doc.isQuote);
    final custName = customerMap[doc.customerId] ?? '–';
    final dateStr = AppUtils.formatDate(doc.date);
    return InkWell(
      onTap: () => _openInvoice(doc),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF18181c),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x14ffffff)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${doc.invoiceNumber}  ·  $custName',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF8a8a94))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(AppUtils.formatCurrency(doc.total),
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFfda085),
                    fontWeight: FontWeight.w600)),
            if (showConvert) ...[
              const SizedBox(width: 2),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: 'In Rechnung umwandeln',
                icon: const Icon(Icons.receipt_long_outlined,
                    size: 18, color: Color(0xFFfda085)),
                onPressed: () => _convertToInvoice(doc),
              ),
            ],
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _cycleStatus(doc),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 2),
                    Icon(Icons.swap_horiz, size: 11, color: color),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<_DashboardStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            // Fertige Daten merken, damit ein Refresh nicht auf „–" zurückfällt.
            if (snapshot.hasData) _lastStats = snapshot.data;
            final stats = snapshot.data ?? _lastStats;

            if (stats == null) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 40, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('${snapshot.error}'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _reload,
                        child: const Text('Neu laden'),
                      ),
                    ],
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }

            // Kacheln und Listen stammen aus demselben Ladevorgang – sie
            // können deshalb nicht mehr unterschiedliche Zahlen zeigen.
            final openInvoices = stats.openInvoices;
            final openQuotes   = stats.openQuotes;
            final doneQuotes   = stats.doneQuotes;
            final customerMap  = stats.customerMap;

            return LayoutBuilder(builder: (ctx, box) {
              final wide = box.maxWidth >= 600;
              final cols = wide ? 3 : 2;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Drag-and-Drop Kacheln ──
                    _DraggableGrid(
                      tiles: _tiles,
                      stats: stats,
                      cols: cols,
                      onReorder: _onReorder,
                      onTileTap: _onTileTap,
                    ),

                    if (stats.seasonOpen.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionHeader(
                          'Jetzt im Bienenjahr', stats.seasonOpen.length),
                      ...stats.seasonOpen.map(_seasonRow),
                    ],

                    const SizedBox(height: 16),

                    // ── Offene Rechnungen ──
                    _sectionHeader('Offene Rechnungen', openInvoices.length),
                    if (openInvoices.isEmpty)
                      _emptyHint('Keine offenen Rechnungen')
                    else
                      ...openInvoices.map((d) => _docRow(d, customerMap)),

                    const SizedBox(height: 16),

                    // ── Offene Angebote ──
                    _sectionHeader('Offene Angebote', openQuotes.length),
                    if (openQuotes.isEmpty)
                      _emptyHint('Keine offenen Angebote')
                    else
                      ...openQuotes.map(
                          (d) => _docRow(d, customerMap, showConvert: true)),

                    const SizedBox(height: 16),

                    // ── Abgearbeitete Angebote ──
                    _sectionHeader('Angebote abgearbeitet', doneQuotes.length),
                    if (doneQuotes.isEmpty)
                      _emptyHint('Keine abgearbeiteten Angebote')
                    else
                      ...doneQuotes.map(
                          (d) => _docRow(d, customerMap, showConvert: true)),
                  ],
                ),
              );
            });
          },
        ),
      ),
    );
  }
}

// ── Drag-and-Drop Grid ───────────────────────────────────────────
class _DraggableGrid extends StatefulWidget {
  final List<_TileDef> tiles;
  final _DashboardStats stats;
  final int cols;
  final void Function(int from, int to) onReorder;
  final void Function(String id) onTileTap;

  const _DraggableGrid({
    required this.tiles,
    required this.stats,
    required this.cols,
    required this.onReorder,
    required this.onTileTap,
  });

  @override
  State<_DraggableGrid> createState() => _DraggableGridState();
}

class _DraggableGridState extends State<_DraggableGrid> {
  int? _dragging;
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final tileH = 64.0;
    final rows  = (widget.tiles.length / widget.cols).ceil();

    return SizedBox(
      height: rows * tileH + (rows - 1) * 8,
      child: Stack(
        children: [
          // Grid-Layout via positioned Slots
          LayoutBuilder(builder: (ctx, box) {
            final w = (box.maxWidth - (widget.cols - 1) * 8) / widget.cols;
            return Stack(
              children: [
                for (int i = 0; i < widget.tiles.length; i++)
                  _buildSlot(i, w, tileH),
              ],
            );
          }),
        ],
      ),
    );
  }

  double _left(int i, double w) =>
      (i % widget.cols) * (w + 8);

  double _top(int i, double tileH) =>
      (i ~/ widget.cols) * (tileH + 8);

  Widget _buildSlot(int i, double w, double tileH) {
    final tile = widget.tiles[i];
    final isHover = _hover == i && _dragging != null && _dragging != i;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      left: _left(i, w),
      top: _top(i, tileH),
      width: w,
      height: tileH,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          setState(() => _hover = i);
          return true;
        },
        onLeave: (_) => setState(() => _hover = null),
        onAcceptWithDetails: (details) {
          setState(() => _hover = null);
          widget.onReorder(details.data, i);
        },
        builder: (ctx, candidates, _) {
          return LongPressDraggable<int>(
            data: i,
            delay: const Duration(milliseconds: 200),
            onDragStarted: () => setState(() => _dragging = i),
            onDragEnd: (_)   => setState(() {
              _dragging = null;
              _hover    = null;
            }),
            feedback: SizedBox(
              width: w,
              height: tileH,
              child: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.85,
                  child: _Tile(tile, widget.stats.valueFor(tile.id),
                      highlight: true),
                ),
              ),
            ),
            childWhenDragging: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111114),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0x22ffffff),
                    style: BorderStyle.solid),
              ),
            ),
            child: GestureDetector(
              onTap: () => widget.onTileTap(tile.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: isHover
                      ? Border.all(
                          color: const Color(0xFFfda085), width: 2)
                      : null,
                ),
                child: _Tile(tile, widget.stats.valueFor(tile.id)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Farb-Enum ────────────────────────────────────────────────────
enum _C { accent, success, info, neutral, warning, danger }

// ── Kachel-Widget ────────────────────────────────────────────────
class _Tile extends StatelessWidget {
  final _TileDef tile;
  final String value;
  final bool highlight;
  const _Tile(this.tile, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final Color vc = switch (tile.style) {
      _C.accent   => const Color(0xFFffb89e),
      _C.success  => const Color(0xFF4ade80),
      _C.info     => const Color(0xFF60a5fa),
      _C.warning  => const Color(0xFFf59e0b),
      _C.danger   => const Color(0xFFff6b7a),
      _C.neutral  => const Color(0xFFc4c4cc),
    };

    return Container(
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF222228)
            : const Color(0xFF18181c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x20ffffff)),
        boxShadow: highlight
            ? [BoxShadow(color: vc.withAlpha(60), blurRadius: 12)]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(tile.icon, color: vc, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tile.title,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8a8a94),
                        fontWeight: FontWeight.w600)),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        color: vc,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
              ],
            ),
          ),
          // Drag-Handle
          const Icon(Icons.drag_indicator,
              size: 14, color: Color(0x44ffffff)),
        ],
      ),
    );
  }
}
