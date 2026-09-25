import 'package:flutter/material.dart';

import '../data/db.dart';
import '../logic/series.dart';
import '../model/catalog.dart';
import 'book_screens.dart';
import 'build_menu.dart';
import 'city3d.dart';
import 'city_painter.dart';
import 'common.dart';
import 'entry_screen.dart';

/// Was ein Tipp auf die Stadt gerade bewirkt.
sealed class _Modus {}

class _Ansehen extends _Modus {}

class _Bauen extends _Modus {
  _Bauen(this.typ);
  final BuildingType typ;
}

class _Verschieben extends _Modus {
  _Verschieben(this.building);
  final Building building;
}

class CityScreen extends StatefulWidget {
  const CityScreen({super.key});

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();
  final _viewer = TransformationController();
  _Modus _modus = _Ansehen();
  (int, int)? _highlight;
  bool _zentriert = false;

  @override
  void dispose() {
    _anim.dispose();
    _viewer.dispose();
    super.dispose();
  }

  void _zentrieren(CityScene scene, Size view) {
    final mitte = scene.toScreen(scene.size / 2, scene.size / 2);
    const scale = 0.9;
    _viewer.value = Matrix4.identity()
      ..translateByDouble(
        view.width / 2 - mitte.dx * scale,
        view.height / 2 - mitte.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Future<void> _tap(CityScene scene, Offset pos) {
    final (x, y) = scene.fromScreen(pos);
    return _tapFeld(scene, x, y);
  }

  Future<void> _tapFeld(CityScene scene, int x, int y) async {
    final store = StoreScope.read(context);
    switch (_modus) {
      case _Bauen(:final typ):
        if (!store.isFreeTile(x, y)) {
          showSnack(context, 'Tippe auf ein freies Feld der Stadt.');
          return;
        }
        final ok = await store.build(typ, x, y);
        if (!mounted) return;
        showSnack(
          context,
          ok ? '${typ.name} gebaut!' : 'Nicht genug Material.',
        );
        setState(() {
          _modus = _Ansehen();
          _highlight = null;
        });
      case _Verschieben(:final building):
        final ok = await store.move(building, x, y);
        if (!mounted) return;
        if (!ok) {
          showSnack(context, 'Tippe auf ein freies Feld der Stadt.');
          return;
        }
        setState(() {
          _modus = _Ansehen();
          _highlight = null;
        });
      case _Ansehen():
        final b = store.buildingAt(x, y);
        if (b != null) {
          setState(() => _highlight = (x, y));
          await _buildingSheet(b);
          if (mounted) setState(() => _highlight = null);
          return;
        }
        for (final d in scene.districts) {
          for (final p in d.plots) {
            if (p.x == x && p.y == y) {
              setState(() => _highlight = (x, y));
              await _plotSheet(d, p);
              if (mounted) setState(() => _highlight = null);
              return;
            }
          }
        }
    }
  }

  Future<void> _buildingSheet(Building b) async {
    final store = StoreScope.read(context);
    final type = typeById(b.typeId);
    final book = b.bookId == null ? null : store.booksById[b.bookId];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (book != null) ...[
                  Text(book.titel, style: theme.textTheme.titleLarge),
                  if (book.autor.isNotEmpty) Text(book.autor),
                  const SizedBox(height: 8),
                  Text(switch (book.status) {
                    BookStatus.wunsch => 'Bauplan: steht auf der Wunschliste.',
                    BookStatus.lesend =>
                      'Baustelle: Seite ${store.currentPage(book)} von ${book.seitenGesamt}.',
                    BookStatus.beendet =>
                      book.beendetAm == null
                          ? 'Beendet.'
                          : 'Beendet am ${datumFormat.format(book.beendetAm!)}.',
                  }),
                  if (book.notiz?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(
                      '„${book.notiz}“',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ] else if (b.typeId == typJahresprojekt) ...[
                  Text(
                    'Jahresbauwerk ${b.jahr}',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Text(
                    'Jedes beendete Buch des Jahres fügt einen Bauabschnitt hinzu.',
                  ),
                ] else ...[
                  Text(
                    type?.name ?? b.typeId,
                    style: theme.textTheme.titleLarge,
                  ),
                  Text('Gebaut am ${datumFormat.format(b.gebautAm)}'),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (book != null)
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.menu_book),
                        label: const Text('Zum Buch'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookDetailScreen(bookId: book.id),
                            ),
                          );
                        },
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_with),
                      label: const Text('Verschieben'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _modus = _Verschieben(b));
                      },
                    ),
                    if (type?.baubar ?? false)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Abreißen'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await store.demolish(b);
                          if (mounted) {
                            showSnack(
                              context,
                              '${type!.name} abgerissen, Material zurück.',
                            );
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _plotSheet(District d, SeriesPlot p) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final book = p.book;
        final text = switch (p.state) {
          PlotState.geist => 'Band ${p.band}: noch nicht gelesen.',
          PlotState.baustelle => 'Band ${p.band}: wird gerade gelesen.',
          PlotState.fertig =>
            'Band ${p.band}: beendet'
                '${book?.beendetAm == null ? '' : ' am ${datumFormat.format(book!.beendetAm!)}'}.',
          PlotState.geruest =>
            'Bauplatz für den nächsten Band. Die Reihe läuft noch.',
          PlotState.wahrzeichen =>
            'Wahrzeichen: Reihe komplett! Bonus: ${50 * d.baende} Holz'
                '${d.genre == null ? '' : ' und ${50 * d.baende} ${d.genre!.material.label}'}.',
        };
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d.series.name} · ${d.stilName}',
                  style: theme.textTheme.labelLarge,
                ),
                if (book != null)
                  Text(book.titel, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(text),
                Text('${d.fertigeBaende} von ${d.baende} Bänden gelesen.'),
                const SizedBox(height: 16),
                if (book != null)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Zum Buch'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookDetailScreen(bookId: book.id),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBuildMenu() async {
    final typ = await Navigator.push<BuildingType>(
      context,
      MaterialPageRoute(builder: (_) => const BuildMenuScreen()),
    );
    if (typ != null && mounted) setState(() => _modus = _Bauen(typ));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scene = buildScene(
      books: store.books,
      entries: store.entries,
      buildings: store.buildings,
      series: store.series,
      yearGoals: store.yearGoals,
      now: store.now,
    );
    final ziel = store.nahziel;
    final inv = store.inventar;
    final theme = Theme.of(context);
    final placing = _modus is! _Ansehen;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${store.stufe.label} · ${zahlFormat.format(store.seitenGesamt)} Seiten',
        ),
        actions: [
          IconButton(
            tooltip: 'Über die 3D-Stadt',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'Lese-Stadt',
              children: const [
                Text(
                  'Die 3D-Stadt nutzt three.js (MIT-Lizenz). Gebäude selbst in Blender gebaut.\n\n'
                  'Figuren: „Cesium Man“ aus den glTF-Beispielmodellen der Khronos Group, '
                  'Lizenz CC BY 4.0 (creativecommons.org/licenses/by/4.0), '
                  'neu eingefärbt und um Animationen ergänzt.\n\n'
                  'Laterne: „Lantern“ aus den glTF-Beispielmodellen der Khronos Group, CC0.',
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Baumenü',
            icon: const Icon(Icons.construction),
            onPressed: _openBuildMenu,
          ),
        ],
      ),
      floatingActionButton: placing
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              icon: const Icon(Icons.edit_note),
              label: const Text('Lesen eintragen'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EntryScreen()),
              ),
            ),
      body: Column(
        children: [
          if (placing)
            MaterialBanner(
              content: Text(switch (_modus) {
                _Bauen(:final typ) =>
                  'Tippe auf ein freies Feld für: ${typ.name}',
                _Verschieben() => 'Tippe auf das neue Feld.',
                _Ansehen() => '',
              }),
              leading: const Icon(Icons.touch_app),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _modus = _Ansehen()),
                  child: const Text('Abbrechen'),
                ),
              ],
            )
          else if (ziel != null)
            Material(
              color: theme.colorScheme.primaryContainer,
              child: InkWell(
                onTap: _openBuildMenu,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        ziel.gepinnt ? Icons.push_pin : Icons.flag,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ziel.text,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final m in inv.keys)
                  if (inv[m] != 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: MatChip(m, inv[m]!),
                    ),
                if (inv.values.every((v) => v == 0))
                  const Text('Noch kein Material – trag gelesene Seiten ein.'),
              ],
            ),
          ),
          if (store.ohnePlatz > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${store.ohnePlatz} Buch-Denkmäler finden keinen Platz. Reiß etwas ab oder lies weiter bis zur nächsten Stufe.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (City3D.enabled)
            Expanded(
              child: City3DView(
                daten: city3dJson(
                  scene,
                  now: store.now,
                  placing: placing,
                  highlight: _highlight,
                ),
                onTap: (x, y) => _tapFeld(scene, x, y),
              ),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (!_zentriert) {
                    _zentriert = true;
                    _zentrieren(scene, constraints.biggest);
                  }
                  return ClipRect(
                    child: InteractiveViewer(
                      transformationController: _viewer,
                      constrained: false,
                      minScale: 0.3,
                      maxScale: 3,
                      boundaryMargin: const EdgeInsets.all(400),
                      child: GestureDetector(
                        onTapUp: (d) => _tap(scene, d.localPosition),
                        child: CustomPaint(
                          size: scene.canvasSize,
                          painter: CityPainter(
                            scene,
                            animation: _anim,
                            highlight: _highlight,
                            placing: placing,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '${store.belebung.label} · ${store.aktivitaet} Seiten in 7 Tagen',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
