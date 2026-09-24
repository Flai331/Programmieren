import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/chronicle.dart';
import 'city_painter.dart';
import 'common.dart';

class ChronicleScreen extends StatefulWidget {
  const ChronicleScreen({super.key});

  @override
  State<ChronicleScreen> createState() => _ChronicleScreenState();
}

class _ChronicleScreenState extends State<ChronicleScreen> {
  int? _jahr;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final jahre = {
      store.now.year,
      for (final e in store.entries) e.datum.year,
      for (final b in store.books)
        if (b.beendetAm != null) b.beendetAm!.year,
    }.toList()..sort((a, b) => b.compareTo(a));
    final jahr = _jahr ?? jahre.first;
    final r = yearReview(
      jahr: jahr,
      books: store.books,
      entries: store.entries,
      series: store.series,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Stadtchronik')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Jahresrückblick', style: theme.textTheme.titleLarge),
              const Spacer(),
              DropdownButton<int>(
                value: jahr,
                items: [
                  for (final j in jahre)
                    DropdownMenuItem(value: j, child: Text('$j')),
                ],
                onChanged: (j) => setState(() => _jahr = j),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat('Bücher', '${r.buecher.length}'),
              _Stat('Seiten', zahlFormat.format(r.seiten)),
              _Stat('Top-Genre', r.topGenre?.label ?? '–'),
              _Stat('Reihen komplett', '${r.reihen.length}'),
            ],
          ),
          if (r.laengstesBuch != null) ...[
            const SizedBox(height: 12),
            Text(
              'Längstes Buch: ${r.laengstesBuch!.titel} '
              '(${r.laengstesBuch!.seitenGesamt} Seiten)',
            ),
          ],
          if (r.reihen.isNotEmpty)
            Text(
              'Abgeschlossene Reihen: ${r.reihen.map((s) => s.name).join(', ')}',
            ),
          if (r.buecher.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Gelesen', style: theme.textTheme.titleSmall),
            for (final b in r.buecher)
              Text('• ${b.titel}${b.autor.isEmpty ? '' : ' – ${b.autor}'}'),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: Text(
              'Zeitraffer 1. Januar $jahr bis '
              '${jahr == store.now.year ? 'heute' : '31. Dezember'}',
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TimelapseScreen(jahr: jahr)),
            ),
          ),
          const SizedBox(height: 28),
          Text('Monatliche Schnappschüsse', style: theme.textTheme.titleLarge),
          const Text(
            'Einmal im Monat wird festgehalten, was in deiner Stadt steht.',
          ),
          if (store.snapshots.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Noch keiner – der erste entsteht, sobald etwas gebaut ist.',
              ),
            ),
          for (final s in store.snapshots.map(summarizeSnapshot))
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(monatFormat.format(s.datum)),
              subtitle: Text('${s.gesamt} Gebäude'),
              children: [
                for (final e
                    in (s.proName.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value))))
                  ListTile(
                    dense: true,
                    title: Text(e.key),
                    trailing: Text('${e.value}×'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.wert);
  final String label;
  final String wert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(wert, style: theme.textTheme.titleLarge),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Spielt die Stadt vom 1. Januar bis heute (bzw. Jahresende) ab.
class TimelapseScreen extends StatefulWidget {
  const TimelapseScreen({super.key, required this.jahr});
  final int jahr;

  @override
  State<TimelapseScreen> createState() => _TimelapseScreenState();
}

class _TimelapseScreenState extends State<TimelapseScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..forward();
  final _boundary = GlobalKey();
  bool _teilt = false;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _teilen() async {
    setState(() => _teilt = true);
    try {
      final obj =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await obj.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lese-stadt-${widget.jahr}.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Meine Lese-Stadt ${widget.jahr}',
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Teilen hat nicht geklappt: $e');
    } finally {
      if (mounted) setState(() => _teilt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final start = DateTime(widget.jahr);
    final ende = widget.jahr == store.now.year
        ? store.now
        : DateTime(widget.jahr, 12, 31, 23, 59);
    final spanne = ende.difference(start);

    return Scaffold(
      appBar: AppBar(
        title: Text('Zeitraffer ${widget.jahr}'),
        actions: [
          IconButton(
            tooltip: 'Nochmal',
            icon: const Icon(Icons.replay),
            onPressed: () => _anim.forward(from: 0),
          ),
          IconButton(
            tooltip: 'Als Bild teilen',
            icon: const Icon(Icons.share),
            onPressed: _teilt ? null : _teilen,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = start.add(spanne * _anim.value);
          final books = booksAt(store.books, store.entries, t);
          final reihen = {for (final b in books) b.seriesId};
          final scene = buildScene(
            books: books,
            entries: entriesAt(store.entries, t),
            buildings: buildingsAt(store.buildings, t),
            series: store.series.where((s) => reihen.contains(s.id)).toList(),
            yearGoals: store.yearGoals.where((g) => g.jahr <= t.year).toList(),
            now: DateTime(t.year, t.month, t.day, 12),
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  datumFormat.format(t),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Slider(
                value: _anim.value,
                onChanged: (v) {
                  _anim.stop();
                  _anim.value = v;
                },
              ),
              Expanded(
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _boundary,
                    child: CustomPaint(
                      size: scene.canvasSize,
                      painter: CityPainter(scene),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
