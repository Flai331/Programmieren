import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/db.dart';
import '../logic/progress.dart';
import '../logic/series.dart';
import '../model/catalog.dart';
import 'city_painter.dart';

/// Die 3D-Stadt (three.js, `web3d/`) läuft in einer WebView. Die Dateien
/// liegen unter `assets/city3d/` und werden über einen kleinen Server auf
/// 127.0.0.1 ausgeliefert: Von file:// aus dürfte die Seite die Modelle
/// nicht nachladen.
class City3D {
  /// In Tests aus, dort wird die Stadt gezeichnet.
  static bool enabled = false;

  static HttpServer? _server;

  static Future<Uri> start() async {
    final server = _server ??= await _serve();
    return Uri.parse('http://127.0.0.1:${server.port}/index.html');
  }

  static Future<HttpServer> _serve() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final pfad = req.uri.path == '/' ? '/index.html' : req.uri.path;
      try {
        if (pfad.contains('..')) throw const FormatException();
        final data = await rootBundle.load('assets/city3d$pfad');
        req.response.headers.contentType = _typ(pfad);
        req.response.add(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } catch (_) {
        req.response.statusCode = HttpStatus.notFound;
      }
      await req.response.close();
    });
    return server;
  }

  static ContentType _typ(String pfad) {
    if (pfad.endsWith('.html')) return ContentType.html;
    if (pfad.endsWith('.js')) {
      return ContentType('application', 'javascript', charset: 'utf-8');
    }
    if (pfad.endsWith('.glb')) return ContentType('model', 'gltf-binary');
    return ContentType.binary;
  }
}

/// Gebäude, vor denen tagsüber jemand arbeitet.
const _arbeitsplaetze = {
  'baeckerei',
  'wassermuehle',
  'marktplatz',
  'polizeiwache',
  'detektivbuero',
  'bibliothek',
  'schule',
  'universitaet',
  'rathaus',
  'cafe',
  'labor',
  'museum',
  'theater',
  'oper',
  'bahnhof',
  'hafen',
  'observatorium',
  'raumhafen',
};

/// Plätze, über die man laufen kann.
const _begehbar = {'park', 'marktplatz', 'brunnen', 'denkmal'};

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Der Stadtzustand für die 3D-Szene.
Map<String, Object?> city3dJson(
  CityScene scene, {
  required DateTime now,
  bool placing = false,
  (int, int)? highlight,
}) {
  final gebaeude = <Map<String, Object?>>[];
  final strassen = <List<int>>[
    for (final (x, y) in scene.roads) [x, y],
  ];
  final baustellen = <List<int>>[];
  final arbeit = <List<int>>[];

  for (final b in scene.buildings) {
    final typ = typeById(b.typeId);
    if (typ == null) continue;
    if (typ.id == 'strasse') {
      strassen.add([b.x, b.y]);
      continue;
    }
    String? modell;
    var geist = false;
    switch (typ.id) {
      case 'baum':
        modell = (b.x * 31 + b.y * 17).isEven ? 'baum' : 'baum2';
      case 'baeckerei' || 'wassermuehle':
        modell = '${typ.id}3d';
      case typBuchDenkmal:
        final book = scene.booksById[b.bookId];
        if (book == null) continue;
        switch (book.status) {
          case BookStatus.wunsch:
            modell = 'haus';
            geist = true;
          case BookStatus.lesend:
            final p = book.seitenGesamt <= 0
                ? 0.0
                : (scene.pagesPerBook[book.id] ?? 0) / book.seitenGesamt;
            modell = 'baustelle${p < 1 / 3 ? 1 : (p < 2 / 3 ? 2 : 3)}';
            baustellen.add([b.x, b.y]);
          case BookStatus.beendet:
            modell =
                'buch_${book.genres.isEmpty ? 'neutral' : book.genres.first.name}';
        }
      case typJahresprojekt:
        final prog = b.jahr == null ? null : scene.years[b.jahr];
        if (prog == null || prog.ziel <= 0) continue;
        modell = prog.fertig
            ? 'jahr_fertig'
            : 'jahr${(prog.abschnitte * 4 / prog.ziel).floor().clamp(0, 4)}';
        if (!prog.fertig) baustellen.add([b.x, b.y]);
      default:
        modell = typ.id;
    }
    if (_arbeitsplaetze.contains(typ.id)) arbeit.add([b.x, b.y]);
    gebaeude.add({
      'x': b.x,
      'y': b.y,
      'modell': modell,
      'geist': geist,
      'begehbar': _begehbar.contains(typ.id),
    });
  }

  final viertel = <Map<String, Object?>>[];
  for (final d in scene.districts) {
    viertel.add({
      'x0': d.x0,
      'y0': d.y0,
      'breite': d.breite,
      'hoehe': d.hoehe,
      'farbe': _hex(d.genre?.material.color ?? Colors.grey),
      'name': '${d.series.name} · ${d.stilName}',
    });
    final genre = d.genre?.name ?? 'neutral';
    for (final p in d.plots) {
      final (modell, geist) = switch (p.state) {
        PlotState.geist => ('reihe_neutral', true),
        PlotState.geruest => ('geruest', false),
        PlotState.baustelle => ('baustelle2', false),
        PlotState.fertig => ('reihe_$genre', false),
        PlotState.wahrzeichen => ('wahrzeichen', false),
      };
      if (p.state == PlotState.baustelle) baustellen.add([p.x, p.y]);
      gebaeude.add({'x': p.x, 'y': p.y, 'modell': modell, 'geist': geist});
    }
  }

  return {
    'size': scene.size,
    'stunde': now.hour + now.minute / 60,
    'belebung': scene.belebung.index,
    'lichter': scene.belebung.index >= Belebung.licht.index,
    'gebaeude': gebaeude,
    'strassen': strassen,
    'viertel': viertel,
    'baustellen': baustellen,
    'arbeitsplaetze': arbeit,
    'placing': placing,
    'highlight': highlight == null ? null : [highlight.$1, highlight.$2],
  };
}

/// Zeigt die 3D-Stadt und meldet angetippte Felder.
class City3DView extends StatefulWidget {
  const City3DView({super.key, required this.daten, required this.onTap});

  final Map<String, Object?> daten;
  final void Function(int x, int y) onTap;

  @override
  State<City3DView> createState() => _City3DViewState();
}

class _City3DViewState extends State<City3DView> {
  late final WebViewController _web;
  bool _geladen = false;
  String? _gesendet;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFBFD9EF))
      ..addJavaScriptChannel('Flutter', onMessageReceived: _nachricht)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _geladen = true;
            _senden();
          },
        ),
      );
    City3D.start().then((uri) {
      if (mounted) _web.loadRequest(uri);
    });
  }

  void _nachricht(JavaScriptMessage m) {
    try {
      final n = jsonDecode(m.message) as Map<String, dynamic>;
      if (n['typ'] == 'tap') {
        widget.onTap((n['x'] as num).toInt(), (n['y'] as num).toInt());
      }
    } catch (_) {}
  }

  void _senden() {
    if (!_geladen) return;
    final json = jsonEncode(widget.daten);
    if (json == _gesendet) return;
    _gesendet = json;
    unawaited(_web.runJavaScript('LeseStadt.update($json)'));
  }

  @override
  void didUpdateWidget(City3DView old) {
    super.didUpdateWidget(old);
    _senden();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}
