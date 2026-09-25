import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../logic/economy.dart';
import '../logic/progress.dart';
import '../logic/series.dart';
import '../model/catalog.dart';
import 'sprites.dart';

const tileW = 64.0;
const tileH = 32.0;
const _unit = 26.0; // Pixel je Höheneinheit
const _margin = 40.0;
const _top = 150.0;

/// Alles, was die Stadtansicht zeichnet, unabhängig davon, ob es der aktuelle
/// Stand oder ein Bild aus dem Zeitraffer ist.
class CityScene {
  CityScene({
    required this.size,
    required this.buildings,
    required this.booksById,
    required this.pagesPerBook,
    required this.districts,
    required this.roads,
    required this.years,
    required this.belebung,
    required this.nacht,
  }) {
    var maxX = size, maxY = size;
    for (final d in districts) {
      maxX = max(maxX, d.x0 + d.breite);
      maxY = max(maxY, d.y0 + d.hoehe);
    }
    for (final (x, y) in roads) {
      maxX = max(maxX, x + 1);
      maxY = max(maxY, y + 1);
    }
    worldX = maxX;
    worldY = maxY;
  }

  final int size;
  final List<Building> buildings;
  final Map<int, Book> booksById;
  final Map<int, int> pagesPerBook;
  final List<District> districts;
  final List<(int, int)> roads;
  final Map<int, YearProgress> years;
  final Belebung belebung;
  final bool nacht;
  late final int worldX, worldY;

  Offset get origin => Offset(worldY * tileW / 2 + _margin, _top);

  Size get canvasSize => Size(
    (worldX + worldY) * tileW / 2 + 2 * _margin,
    (worldX + worldY) * tileH / 2 + _top + _margin,
  );

  Offset toScreen(double x, double y) =>
      origin + Offset((x - y) * tileW / 2, (x + y) * tileH / 2);

  (int, int) fromScreen(Offset p) {
    final d = p - origin;
    final a = d.dx / (tileW / 2);
    final b = d.dy / (tileH / 2);
    return (((a + b) / 2).floor(), ((b - a) / 2).floor());
  }
}

CityScene buildScene({
  required List<Book> books,
  required List<ReadingEntry> entries,
  required List<Building> buildings,
  required List<Series> series,
  required List<YearGoal> yearGoals,
  required DateTime now,
}) {
  final size = Stufe.fuerSeiten(totalPages(entries)).groesse;
  final districts = layoutDistricts(
    series: series,
    books: books,
    citySize: size,
  );
  return CityScene(
    size: size,
    buildings: buildings,
    booksById: {for (final b in books) b.id: b},
    pagesPerBook: pagesPerBook(entries),
    districts: districts,
    roads: districtRoads(districts, size),
    years: {
      for (final g in yearGoals)
        g.jahr: yearProgress(g.jahr, g.zielBuecher, books),
    },
    belebung: belebungFuer(activityValue(entries, now)),
    nacht: istNacht(now),
  );
}

// ------------------------------------------------------------------ Zeichnen

Color _shade(Color c, double f) =>
    Color.from(alpha: c.a, red: c.r * f, green: c.g * f, blue: c.b * f);

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

class CityPainter extends CustomPainter {
  CityPainter(
    this.scene, {
    this.animation,
    this.highlight,
    this.placing = false,
    Sprites? sprites,
  }) : sprites = sprites ?? Sprites.instance,
       super(repaint: animation);

  final CityScene scene;

  /// Gerenderte Gebäudebilder; ohne sie wird die Stadt gezeichnet.
  final Sprites? sprites;

  /// Animationsphase 0…1 für die Leute auf den Straßen.
  final Animation<double>? animation;
  double get t => animation?.value ?? 0;
  final (int, int)? highlight;

  /// Im Baumodus werden freie Felder hervorgehoben.
  final bool placing;

  double get _light => scene.nacht ? 0.55 : 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    _paintGround(canvas);
    _paintObjects(canvas);
    _paintLife(canvas);
    _paintLabels(canvas);
  }

  void _paintSky(Canvas canvas, Size size) {
    final colors = scene.nacht
        ? [const Color(0xFF0E1630), const Color(0xFF26335A)]
        : [const Color(0xFFBFE3F5), const Color(0xFFEAF6E4)];
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(Offset.zero & size),
    );
    if (scene.nacht) {
      final rnd = Random(7);
      final p = Paint()..color = Colors.white70;
      for (var i = 0; i < 60; i++) {
        canvas.drawCircle(
          Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * _top),
          rnd.nextDouble() * 1.2 + 0.3,
          p,
        );
      }
    }
  }

  Path _diamond(double x, double y, [double inset = 0]) {
    final a = scene.toScreen(x + inset, y + inset);
    final b = scene.toScreen(x + 1 - inset, y + inset);
    final c = scene.toScreen(x + 1 - inset, y + 1 - inset);
    final d = scene.toScreen(x + inset, y + 1 - inset);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
  }

  void _tile(Canvas canvas, int x, int y, Color color) {
    final path = _diamond(x.toDouble(), y.toDouble());
    canvas.drawPath(path, Paint()..color = _shade(color, _light));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = _shade(color, _light * 0.85),
    );
  }

  // ------------------------------------------------------------ Bilder

  bool get _lichter =>
      scene.nacht && scene.belebung.index >= Belebung.licht.index;

  static const _nachtFilter = ColorFilter.mode(
    Color(0xFF5A6690),
    BlendMode.modulate,
  );

  // Blass und halb durchsichtig: Bauplan eines Buchs auf der Wunschliste.
  static const _geistFilter = ColorFilter.matrix(<double>[
    0.25, 0.25, 0.25, 0, 150, //
    0.25, 0.25, 0.25, 0, 160,
    0.25, 0.25, 0.25, 0, 185,
    0, 0, 0, 0.45, 0,
  ]);

  static const _geistNachtFilter = ColorFilter.matrix(<double>[
    0.2, 0.2, 0.2, 0, 60, //
    0.2, 0.2, 0.2, 0, 70,
    0.2, 0.2, 0.2, 0, 100,
    0, 0, 0, 0.4, 0,
  ]);

  double get _bildSkala => tileW / Sprites.feldBreite;

  /// Zeichnet das Bild [name] auf Feld (x, y). False, wenn es fehlt.
  bool _sprite(Canvas canvas, String name, int x, int y, {bool geist = false}) {
    final s = sprites;
    if (s == null) return false;
    ui.Image? bild = !geist && _lichter ? s['${name}_nacht'] : null;
    ColorFilter? filter = geist
        ? (scene.nacht ? _geistNachtFilter : _geistFilter)
        : null;
    if (bild == null) {
      bild = s[name];
      if (bild == null) return false;
      if (scene.nacht && !geist) filter = _nachtFilter;
    }
    final k = _bildSkala;
    final c = scene.toScreen(x + 0.5, y + 0.5);
    canvas.drawImageRect(
      bild,
      Rect.fromLTWH(0, 0, bild.width.toDouble(), bild.height.toDouble()),
      Rect.fromLTWH(
        c.dx - Sprites.anker.dx * k,
        c.dy - Sprites.anker.dy * k,
        Sprites.groesse.width * k,
        Sprites.groesse.height * k,
      ),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = filter,
    );
    return true;
  }

  String _gras(int x, int y) =>
      (x * 7 + y * 13) % 3 == 0 ? 'boden_gras2' : 'boden_gras1';

  void _overlay(Canvas canvas, int x, int y, Color color) => canvas.drawPath(
    _diamond(x.toDouble(), y.toDouble()),
    Paint()..color = color,
  );

  bool _paintGroundSprites(Canvas canvas, Set<(int, int)> belegt) {
    if (sprites?['boden_gras1'] == null) return false;
    for (var x = 0; x < scene.size; x++) {
      for (var y = 0; y < scene.size; y++) {
        _sprite(canvas, _gras(x, y), x, y);
        if (placing && !belegt.contains((x, y))) {
          _overlay(canvas, x, y, Colors.yellow.withValues(alpha: 0.28));
        }
      }
    }
    for (final (x, y) in scene.roads) {
      _sprite(canvas, 'boden_strasse', x, y);
    }
    for (final d in scene.districts) {
      final tint = (d.genre?.material.color ?? Colors.grey).withValues(
        alpha: 0.16,
      );
      for (var i = 0; i < d.breite * d.hoehe; i++) {
        final x = d.x0 + i % d.breite, y = d.y0 + i ~/ d.breite;
        _sprite(canvas, _gras(x, y), x, y);
        _overlay(canvas, x, y, tint);
      }
    }
    return true;
  }

  bool _paintBuildingSprite(Canvas canvas, Building b, BuildingType type) {
    switch (type.id) {
      case 'strasse':
        return _sprite(canvas, 'boden_strasse', b.x, b.y);
      case 'baum':
        return _sprite(
          canvas,
          (b.x * 31 + b.y * 17).isEven ? 'baum' : 'baum2',
          b.x,
          b.y,
        );
      case typBuchDenkmal:
        final book = scene.booksById[b.bookId];
        if (book == null) return true;
        switch (book.status) {
          case BookStatus.wunsch:
            return _sprite(canvas, 'haus', b.x, b.y, geist: true);
          case BookStatus.lesend:
            final gelesen = scene.pagesPerBook[book.id] ?? 0;
            final p = book.seitenGesamt <= 0
                ? 0.0
                : gelesen / book.seitenGesamt;
            // Gemalte Baustellen: erst Rohbau mit offenem Dach, ab der
            // Hälfte mit Dachstuhl. Sonst die gerenderten in drei Stufen.
            if (_sprite(
              canvas,
              p < 0.5 ? 'baustelle_baeckerei' : 'baustelle_muehle',
              b.x,
              b.y,
            )) {
              return true;
            }
            final stufe = p < 1 / 3 ? 1 : (p < 2 / 3 ? 2 : 3);
            return _sprite(canvas, 'baustelle$stufe', b.x, b.y);
          case BookStatus.beendet:
            final genre = book.genres.isEmpty
                ? 'neutral'
                : book.genres.first.name;
            return _sprite(canvas, 'buch_$genre', b.x, b.y);
        }
      case typJahresprojekt:
        final prog = b.jahr == null ? null : scene.years[b.jahr];
        if (prog == null || prog.ziel <= 0) return true;
        final teile = prog.fertig
            ? 4
            : (prog.abschnitte * 4 / prog.ziel).floor().clamp(0, 4);
        final name = prog.fertig ? 'jahr_fertig' : 'jahr$teile';
        if (!_sprite(canvas, name, b.x, b.y)) return false;
        final hoehe = 0.06 + teile * 0.23 + (prog.fertig ? 0.46 : 0.12);
        final top =
            scene.toScreen(b.x + 0.5, b.y + 0.5) -
            Offset(0, hoehe * Sprites.pxProHoehe * _bildSkala);
        _yearDecor(canvas, prog, b, top);
        return true;
      default:
        return _sprite(canvas, type.id, b.x, b.y);
    }
  }

  bool _paintPlotSprite(Canvas canvas, SeriesPlot p, District d) {
    final genre = d.genre?.name ?? 'neutral';
    return switch (p.state) {
      PlotState.geist => _sprite(
        canvas,
        'reihe_neutral',
        p.x,
        p.y,
        geist: true,
      ),
      PlotState.geruest => _sprite(canvas, 'geruest', p.x, p.y),
      PlotState.baustelle =>
        _sprite(canvas, 'baustelle_muehle', p.x, p.y) ||
            _sprite(canvas, 'baustelle2', p.x, p.y),
      PlotState.fertig => _sprite(canvas, 'reihe_$genre', p.x, p.y),
      PlotState.wahrzeichen => _sprite(canvas, 'wahrzeichen', p.x, p.y),
    };
  }

  // ------------------------------------------------------------ Zeichnung

  void _paintGround(Canvas canvas) {
    final belegt = {for (final b in scene.buildings) (b.x, b.y)};
    if (_paintGroundSprites(canvas, belegt)) {
      _paintHighlight(canvas);
      return;
    }
    for (var x = 0; x < scene.size; x++) {
      for (var y = 0; y < scene.size; y++) {
        var c = (x + y).isEven
            ? const Color(0xFF8DC47A)
            : const Color(0xFF86BD73);
        if (placing && !belegt.contains((x, y))) {
          c = _mix(c, Colors.yellow, 0.25);
        }
        _tile(canvas, x, y, c);
      }
    }
    for (final (x, y) in scene.roads) {
      _tile(canvas, x, y, const Color(0xFF9E9A92));
    }
    for (final d in scene.districts) {
      final base = _mix(
        const Color(0xFFA9CF8F),
        d.genre?.material.color ?? Colors.grey,
        0.18,
      );
      for (var i = 0; i < d.breite * d.hoehe; i++) {
        _tile(canvas, d.x0 + i % d.breite, d.y0 + i ~/ d.breite, base);
      }
    }
    _paintHighlight(canvas);
  }

  void _paintHighlight(Canvas canvas) {
    if (highlight != null) {
      canvas.drawPath(
        _diamond(highlight!.$1.toDouble(), highlight!.$2.toDouble()),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.orangeAccent,
      );
    }
  }

  void _paintObjects(Canvas canvas) {
    final items = <(int, int, void Function())>[];
    for (final b in scene.buildings) {
      items.add((b.x, b.y, () => _paintBuilding(canvas, b)));
    }
    for (final d in scene.districts) {
      for (final p in d.plots) {
        items.add((p.x, p.y, () => _paintPlot(canvas, p, d)));
      }
    }
    if (sprites?['person_a_vorn'] != null) {
      for (final m in _menschen()) {
        items.add((m.x, m.y, () => _paintMensch(canvas, m)));
      }
    }
    items.sort((a, b) {
      final c = (a.$1 + a.$2).compareTo(b.$1 + b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    for (final item in items) {
      item.$3();
    }
  }

  // Quader mit Grundfläche auf Feld (x, y), eingerückt um [inset].
  void _box(
    Canvas canvas,
    int x,
    int y,
    double h,
    Color color, {
    double inset = 0.14,
    double base = 0,
    bool fenster = true,
  }) {
    final l = _light;
    final fx = x.toDouble(), fy = y.toDouble();
    final left = scene.toScreen(fx + inset, fy + 1 - inset) - Offset(0, base);
    final bottom =
        scene.toScreen(fx + 1 - inset, fy + 1 - inset) - Offset(0, base);
    final right = scene.toScreen(fx + 1 - inset, fy + inset) - Offset(0, base);
    final top = scene.toScreen(fx + inset, fy + inset) - Offset(0, base);
    final up = Offset(0, h);

    Path quad(Offset a, Offset b, Offset c, Offset d) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();

    canvas.drawPath(
      quad(left, bottom, bottom - up, left - up),
      Paint()..color = _shade(color, 0.82 * l),
    );
    canvas.drawPath(
      quad(bottom, right, right - up, bottom - up),
      Paint()..color = _shade(color, 0.66 * l),
    );
    canvas.drawPath(
      quad(top - up, right - up, bottom - up, left - up),
      Paint()..color = _shade(color, min(1.0, 1.08 * l)),
    );

    if (fenster && h >= 16) {
      final lit = scene.nacht && scene.belebung.index >= Belebung.licht.index;
      final paint = Paint()
        ..color = lit
            ? const Color(0xFFFFD66B)
            : _shade(const Color(0xFF3B4A5C), scene.nacht ? 0.6 : 1.0);
      final rows = (h / 14).floor();
      for (var r = 0; r < rows; r++) {
        final dy = 8.0 + r * 14;
        for (final f in [0.3, 0.7]) {
          final p = Offset.lerp(left, bottom, f)! - Offset(0, dy);
          canvas.drawRect(
            Rect.fromCenter(center: p, width: 3.5, height: 5),
            paint,
          );
          final q = Offset.lerp(bottom, right, f)! - Offset(0, dy);
          canvas.drawRect(
            Rect.fromCenter(center: q, width: 3.5, height: 5),
            paint,
          );
        }
      }
    }
  }

  void _pyramid(
    Canvas canvas,
    int x,
    int y,
    double base,
    double h,
    Color color, {
    double inset = 0.1,
  }) {
    final fx = x.toDouble(), fy = y.toDouble();
    final left = scene.toScreen(fx + inset, fy + 1 - inset) - Offset(0, base);
    final bottom =
        scene.toScreen(fx + 1 - inset, fy + 1 - inset) - Offset(0, base);
    final right = scene.toScreen(fx + 1 - inset, fy + inset) - Offset(0, base);
    final apex = scene.toScreen(fx + 0.5, fy + 0.5) - Offset(0, base + h);
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..lineTo(apex.dx, apex.dy)
        ..close(),
      Paint()..color = _shade(color, 0.85 * _light),
    );
    canvas.drawPath(
      Path()
        ..moveTo(bottom.dx, bottom.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(apex.dx, apex.dy)
        ..close(),
      Paint()..color = _shade(color, 0.65 * _light),
    );
  }

  void _ghost(Canvas canvas, int x, int y, double h) {
    final fx = x.toDouble(), fy = y.toDouble();
    const i = 0.16;
    final pts = [
      scene.toScreen(fx + i, fy + 1 - i),
      scene.toScreen(fx + 1 - i, fy + 1 - i),
      scene.toScreen(fx + 1 - i, fy + i),
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.75);
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.18);
    final up = Offset(0, h);
    final body = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo((pts[2] - up).dx, (pts[2] - up).dy)
      ..lineTo((pts[1] - up).dx, (pts[1] - up).dy - 6)
      ..lineTo((pts[0] - up).dx, (pts[0] - up).dy)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, paint);
    canvas.drawLine(pts[1], pts[1] - up - const Offset(0, 6), paint);
  }

  void _scaffold(Canvas canvas, int x, int y, double h) {
    final fx = x.toDouble(), fy = y.toDouble();
    final paint = Paint()
      ..color = const Color(0xFF8A5A2B)
      ..strokeWidth = 1.4;
    final corners = [
      scene.toScreen(fx + 0.1, fy + 1 - 0.1),
      scene.toScreen(fx + 0.9, fy + 0.9),
      scene.toScreen(fx + 0.9, fy + 0.1),
    ];
    for (final c in corners) {
      canvas.drawLine(c, c - Offset(0, h), paint);
    }
    for (var level = 10.0; level <= h; level += 10) {
      canvas.drawLine(
        corners[0] - Offset(0, level),
        corners[1] - Offset(0, level),
        paint,
      );
      canvas.drawLine(
        corners[1] - Offset(0, level),
        corners[2] - Offset(0, level),
        paint,
      );
    }
  }

  void _paintBuilding(Canvas canvas, Building b) {
    final type = typeById(b.typeId);
    if (type == null) return;
    if (_paintBuildingSprite(canvas, b, type)) return;
    switch (type.id) {
      case 'strasse':
        _tile(canvas, b.x, b.y, const Color(0xFF9E9A92));
        final c = scene.toScreen(b.x + 0.5, b.y + 0.5);
        canvas.drawLine(
          c - const Offset(8, 4),
          c + const Offset(8, 4),
          Paint()
            ..color = Colors.white70
            ..strokeWidth = 1.2,
        );
      case 'baum':
        final c = scene.toScreen(b.x + 0.5, b.y + 0.5);
        canvas.drawRect(
          Rect.fromLTWH(c.dx - 2, c.dy - 12, 4, 12),
          Paint()..color = _shade(const Color(0xFF6D4C2F), _light),
        );
        canvas.drawCircle(
          c - const Offset(0, 20),
          11,
          Paint()..color = _shade(const Color(0xFF3F8F46), _light),
        );
        canvas.drawCircle(
          c - const Offset(4, 24),
          6,
          Paint()..color = _shade(const Color(0xFF58A95C), _light),
        );
      case 'haus':
        _box(canvas, b.x, b.y, 18, const Color(0xFFEAD9C0), inset: 0.2);
        _pyramid(
          canvas,
          b.x,
          b.y,
          18,
          14,
          const Color(0xFFC0533A),
          inset: 0.16,
        );
      case typBuchDenkmal:
        _paintBookMonument(canvas, b);
      case typJahresprojekt:
        _paintYear(canvas, b);
      default:
        _paintGenreBuilding(canvas, b, type);
    }
  }

  void _paintGenreBuilding(Canvas canvas, Building b, BuildingType type) {
    final color = type.genre?.material.color ?? const Color(0xFFC9A36B);
    final h = type.hoehe * _unit;
    if (type.kategorie == Kategorie.kombi) {
      if (type.id == 'marktplatz') {
        _tile(canvas, b.x, b.y, const Color(0xFFD8C7A8));
        for (final (dx, dy, c) in [
          (0.25, 0.25, Colors.redAccent),
          (0.6, 0.3, Colors.blueAccent),
          (0.35, 0.65, Colors.amber),
        ]) {
          final p = scene.toScreen(b.x + dx + 0.1, b.y + dy + 0.1);
          canvas.drawRect(
            Rect.fromLTWH(p.dx - 6, p.dy - 10, 12, 8),
            Paint()..color = _shade(c, _light),
          );
        }
        return;
      }
      _box(canvas, b.x, b.y, h, const Color(0xFFB7A48A), inset: 0.08);
      _pyramid(canvas, b.x, b.y, h, 10, const Color(0xFF6B7F8E), inset: 0.06);
      return;
    }
    final tier = type.abStufe.index;
    _box(canvas, b.x, b.y, h, color, inset: tier == 2 ? 0.1 : 0.18);
    switch (tier) {
      case 0:
        _pyramid(canvas, b.x, b.y, h, 16, _shade(color, 0.7));
      case 1:
        _box(
          canvas,
          b.x,
          b.y,
          8,
          _shade(color, 0.8),
          inset: 0.3,
          base: h,
          fenster: false,
        );
      default:
        _box(canvas, b.x, b.y, 16, color, inset: 0.3, base: h);
        _pyramid(canvas, b.x, b.y, h + 16, 18, _shade(color, 0.6), inset: 0.28);
    }
  }

  void _paintBookMonument(Canvas canvas, Building b) {
    final book = scene.booksById[b.bookId];
    if (book == null) return;
    final color = book.genres.isEmpty
        ? const Color(0xFFC9A36B)
        : book.genres.first.material.color;
    const h = 30.0;
    switch (book.status) {
      case BookStatus.wunsch:
        _ghost(canvas, b.x, b.y, h);
      case BookStatus.lesend:
        final gelesen = scene.pagesPerBook[book.id] ?? 0;
        final p = book.seitenGesamt <= 0
            ? 0.0
            : (gelesen / book.seitenGesamt).clamp(0.0, 1.0);
        _box(canvas, b.x, b.y, max(3, h * p), color, inset: 0.22);
        _scaffold(canvas, b.x, b.y, h);
      case BookStatus.beendet:
        _paintFinishedBook(canvas, b.x, b.y, color, h);
    }
  }

  // Sockel mit aufgeschlagenem Buch obendrauf.
  void _paintFinishedBook(Canvas canvas, int x, int y, Color color, double h) {
    _box(canvas, x, y, 8, const Color(0xFFD9D2C3), inset: 0.12, fenster: false);
    _box(canvas, x, y, h - 8, color, inset: 0.24, base: 8);
    final c = scene.toScreen(x + 0.5, y + 0.5) - Offset(0, h + 4);
    final page = Paint()..color = _shade(const Color(0xFFFFFBF0), _light);
    final edge = Paint()
      ..color = _shade(const Color(0xFF7A5A3A), _light)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final l = Path()
      ..moveTo(c.dx, c.dy + 3)
      ..lineTo(c.dx - 11, c.dy - 1)
      ..lineTo(c.dx - 11, c.dy - 9)
      ..lineTo(c.dx, c.dy - 5)
      ..close();
    final r = Path()
      ..moveTo(c.dx, c.dy + 3)
      ..lineTo(c.dx + 11, c.dy - 1)
      ..lineTo(c.dx + 11, c.dy - 9)
      ..lineTo(c.dx, c.dy - 5)
      ..close();
    for (final p in [l, r]) {
      canvas.drawPath(p, page);
      canvas.drawPath(p, edge);
    }
  }

  void _paintYear(Canvas canvas, Building b) {
    final jahr = b.jahr;
    final prog = jahr == null ? null : scene.years[jahr];
    if (prog == null || prog.ziel <= 0) return;
    const color = Color(0xFFD7B56D);
    final total = min(prog.ziel, 24);
    final seg = min(8.0, 70.0 / total);
    final done = (prog.abschnitte * total / prog.ziel).floor();
    _box(
      canvas,
      b.x,
      b.y,
      6,
      const Color(0xFFBDB6A8),
      inset: 0.08,
      fenster: false,
    );
    var base = 6.0;
    for (var i = 0; i < total; i++) {
      if (i < done) {
        _box(
          canvas,
          b.x,
          b.y,
          seg - 1,
          _shade(color, i.isEven ? 1 : 0.9),
          inset: 0.22,
          base: base,
          fenster: false,
        );
      } else {
        _ghost(canvas, b.x, b.y, 0);
      }
      base += seg;
    }
    if (prog.fertig) {
      _pyramid(canvas, b.x, b.y, base, 14, const Color(0xFFB8860B), inset: 0.2);
    } else {
      _scaffold(canvas, b.x, b.y, base);
    }
    final top = scene.toScreen(b.x + 0.5, b.y + 0.5) - Offset(0, base + 14);
    _yearDecor(canvas, prog, b, top);
  }

  /// Extras bei Übererfüllung und die Jahreszahl am Jahresbauwerk.
  void _yearDecor(Canvas canvas, YearProgress prog, Building b, Offset top) {
    for (final e in prog.extras) {
      switch (e) {
        case Extra.fahnen:
          final p = Paint()
            ..color = Colors.brown
            ..strokeWidth = 1;
          canvas.drawLine(top, top - const Offset(0, 14), p);
          canvas.drawPath(
            Path()
              ..moveTo(top.dx, top.dy - 14)
              ..lineTo(top.dx + 10, top.dy - 11)
              ..lineTo(top.dx, top.dy - 8)
              ..close(),
            Paint()..color = Colors.redAccent,
          );
        case Extra.glocken:
          canvas.drawCircle(
            top + const Offset(-6, 10),
            3.5,
            Paint()..color = const Color(0xFFE0B23A),
          );
        case Extra.beleuchtung:
          final glow = Paint()
            ..color = const Color(0xFFFFE08A).withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawCircle(top + const Offset(0, 16), 22, glow);
      }
    }
    _label(
      canvas,
      '${prog.jahr}',
      scene.toScreen(b.x + 0.5, b.y + 1.0) + const Offset(0, 2),
      size: 9,
      color: Colors.white,
      background: const Color(0xAA5A4520),
    );
  }

  void _paintPlot(Canvas canvas, SeriesPlot p, District d) {
    if (_paintPlotSprite(canvas, p, d)) return;
    final color = d.genre?.material.color ?? const Color(0xFFC9A36B);
    switch (p.state) {
      case PlotState.geist:
        _ghost(canvas, p.x, p.y, 20);
      case PlotState.geruest:
        _tile(canvas, p.x, p.y, const Color(0xFFB8A58A));
        _scaffold(canvas, p.x, p.y, 20);
      case PlotState.baustelle:
        _box(canvas, p.x, p.y, 8, color, inset: 0.2);
        _scaffold(canvas, p.x, p.y, 22);
      case PlotState.fertig:
        _box(canvas, p.x, p.y, 20, color, inset: 0.18);
        _pyramid(canvas, p.x, p.y, 20, 13, _shade(color, 0.65), inset: 0.14);
      case PlotState.wahrzeichen:
        _box(
          canvas,
          p.x,
          p.y,
          10,
          const Color(0xFFD9D2C3),
          inset: 0.1,
          fenster: false,
        );
        _box(
          canvas,
          p.x,
          p.y,
          44,
          const Color(0xFFE0B23A),
          inset: 0.3,
          base: 10,
        );
        _pyramid(canvas, p.x, p.y, 54, 20, color, inset: 0.28);
    }
  }

  /// Leute auf den Wegen der Stadt, je nach Aktivität mehr oder weniger.
  List<_Mensch> _menschen() {
    final bel = scene.belebung;
    if (bel == Belebung.still || scene.size == 0) return const [];
    final anzahl = switch (bel) {
      Belebung.wenige => 4,
      Belebung.licht => 10,
      _ => 18,
    };
    // In Gebäuden (nicht auf Straßen oder im Park) sind sie unsichtbar.
    final drin = {
      for (final b in scene.buildings)
        if (b.typeId != 'strasse' && b.typeId != 'park') (b.x, b.y),
    };
    final rnd = Random(42);
    final s = scene.size.toDouble();
    final result = <_Mensch>[];
    for (var i = 0; i < anzahl; i++) {
      final entlangX = rnd.nextBool();
      final vor = rnd.nextBool();
      final spur = rnd.nextInt(scene.size) + 0.5;
      final tempo = 0.5 + rnd.nextDouble();
      final phase = rnd.nextDouble();
      var pos = ((t * tempo + phase) % 1.0) * s;
      if (!vor) pos = s - pos;
      final (fx, fy) = entlangX ? (pos, spur) : (spur, pos);
      final tile = (fx.floor(), fy.floor());
      if (drin.contains(tile)) continue;
      final frau = i.isOdd;
      // Nach vorn (zum Betrachter) laufen sie mit Gesicht, sonst von hinten.
      final bild = vor
          ? (frau ? 'person_b_vorn' : 'person_a_vorn')
          : (frau
                ? 'person_b_hinten'
                : (i % 4 == 0 ? 'person_a_seite' : 'person_a_hinten'));
      // Entlang y geht es im Bild nach links: gespiegelt.
      result.add(
        _Mensch(tile.$1, tile.$2, scene.toScreen(fx, fy), bild, !entlangX),
      );
    }
    return result;
  }

  void _paintMensch(Canvas canvas, _Mensch m) {
    final bild = sprites?[m.bild];
    if (bild == null) return;
    final h = 0.32 * Sprites.pxProHoehe * _bildSkala;
    final w = h * bild.width / bild.height;
    canvas.save();
    canvas.translate(m.fuss.dx, m.fuss.dy);
    if (m.gespiegelt) canvas.scale(-1, 1);
    canvas.drawImageRect(
      bild,
      Rect.fromLTWH(0, 0, bild.width.toDouble(), bild.height.toDouble()),
      Rect.fromLTWH(-w / 2, -h, w, h),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = scene.nacht ? _nachtFilter : null,
    );
    canvas.restore();
  }

  void _paintLife(Canvas canvas) {
    final bel = scene.belebung;
    if (bel == Belebung.still || scene.size == 0) return;
    if (sprites?['person_a_vorn'] != null) {
      _paintFest(canvas);
      return;
    }
    final anzahl = switch (bel) {
      Belebung.wenige => 4,
      Belebung.licht => 10,
      _ => 18,
    };
    final rnd = Random(42);
    final s = scene.size.toDouble();
    for (var i = 0; i < anzahl; i++) {
      final horizontal = rnd.nextBool();
      final lane = rnd.nextDouble() * s;
      final speed = 0.5 + rnd.nextDouble();
      final phase = rnd.nextDouble();
      final pos = ((t * speed + phase) % 1.0) * s;
      final p = horizontal
          ? scene.toScreen(pos, lane)
          : scene.toScreen(lane, pos);
      final c = Colors.primaries[rnd.nextInt(Colors.primaries.length)];
      canvas.drawCircle(
        p - const Offset(0, 6),
        2.6,
        Paint()..color = _shade(c, _light),
      );
      canvas.drawCircle(
        p - const Offset(0, 10),
        2,
        Paint()..color = _shade(const Color(0xFFF1C9A5), _light),
      );
    }
    _paintFest(canvas);
  }

  void _paintFest(Canvas canvas) {
    final s = scene.size.toDouble();
    if (scene.belebung == Belebung.fest) {
      // Lichterkette zwischen zwei Masten quer über die Stadt.
      final a = scene.toScreen(0, s / 2);
      final b = scene.toScreen(s, s / 2);
      final mast = Paint()
        ..color = _shade(const Color(0xFF6D4C2F), _light)
        ..strokeWidth = 2;
      canvas.drawLine(a, a - const Offset(0, 50), mast);
      canvas.drawLine(b, b - const Offset(0, 50), mast);
      Offset punkt(double f) =>
          Offset.lerp(a, b, f)! - Offset(0, 50 - 16 * sin(pi * f));
      final kette = Path()..moveTo(punkt(0).dx, punkt(0).dy);
      for (var i = 1; i <= 48; i++) {
        kette.lineTo(punkt(i / 48).dx, punkt(i / 48).dy);
      }
      canvas.drawPath(
        kette,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.black45,
      );
      final colors = [Colors.red, Colors.yellow, Colors.blue, Colors.green];
      for (var i = 1; i < 24; i++) {
        final glow = scene.nacht && ((t * 8 + i) % 2 < 1);
        canvas.drawCircle(
          punkt(i / 24) + const Offset(0, 2),
          glow ? 3 : 2.2,
          Paint()
            ..color = colors[i % colors.length].withValues(
              alpha: glow ? 1 : 0.85,
            ),
        );
      }
    }
  }

  void _paintLabels(Canvas canvas) {
    for (final d in scene.districts) {
      final name = '${d.series.name} · ${d.stilName}';
      _label(
        canvas,
        name,
        scene.toScreen(d.x0.toDouble(), d.y0.toDouble()) - const Offset(0, 34),
        size: 10,
        color: Colors.white,
        background: const Color(0xAA2E3A48),
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center, {
    double size = 10,
    Color color = Colors.black,
    Color? background,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 180);
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + 8,
      height: tp.height + 4,
    );
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = background,
      );
    }
    tp.paint(canvas, rect.topLeft + const Offset(4, 2));
  }

  @override
  bool shouldRepaint(CityPainter old) =>
      old.scene != scene ||
      old.animation != animation ||
      old.highlight != highlight ||
      old.placing != placing ||
      old.sprites != sprites;
}

class _Mensch {
  _Mensch(this.x, this.y, this.fuss, this.bild, this.gespiegelt);
  final int x, y;
  final Offset fuss;
  final String bild;
  final bool gespiegelt;
}
