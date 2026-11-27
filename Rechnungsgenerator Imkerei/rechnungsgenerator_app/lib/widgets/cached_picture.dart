import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/image_cache_service.dart';

/// Ein Bild aus dem Netz, das nur einmal geholt wird.
///
/// Ersatz für `Image.network` an den Stellen, wo Logo und Kopfbild in der
/// Vorschau stehen. `Image.network` legt das Bild nur im Arbeitsspeicher ab:
/// nach jedem App-Start wird neu geladen, ohne Zeitgrenze. Hier liegt es als
/// Datei — siehe [ImageCacheService].
///
/// Dazu merkt sich diese Klasse den Ladevorgang je Adresse. Die Vorschau
/// wird beim Ziehen sehr oft neu gebaut; ohne das Merken läse jeder
/// Neuaufbau die Datei erneut. Gemerkt wird die [Future], nicht das
/// Ergebnis — so lädt auch der zweite Aufruf während des ersten nicht
/// doppelt. Und weil dabei dieselben Bytes zurückkommen, trifft auch
/// Flutters eigener Bildspeicher und entschlüsselt das Bild nicht neu.
class CachedPicture extends StatefulWidget {
  const CachedPicture(
    this.url, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.error,
  });

  /// Die Adresse des Bildes.
  final String url;

  final BoxFit? fit;
  final double? width;
  final double? height;

  /// Was statt des Bildes steht, wenn es nicht zu holen ist. Ohne Angabe
  /// bleibt die Fläche leer.
  final Widget? error;

  /// Die gemerkten Ladevorgänge. Mehr als eine Handvoll Bilder hat diese
  /// App nicht (Logo und Kopfbild), die Grenze ist nur ein Riegel.
  static final Map<String, Future<Uint8List?>> _gemerkt = {};
  static const int _grenze = 8;

  /// Die Adresse neu holen lassen — wenn hinter derselben Adresse ein
  /// anderes Bild liegt.
  static Future<void> forget(String url) async {
    _gemerkt.remove(url.trim());
    await ImageCacheService().forget(url);
  }

  @visibleForTesting
  static void forgetAllForTests() => _gemerkt.clear();

  /// Nur für Tests: der laufende Ladevorgang zu [url], oder null.
  ///
  /// Ein Widget-Test kann darauf warten, statt auf die Uhr zu schauen.
  /// Echte Ein-/Ausgabe läuft im Test nur in `runAsync` weiter, und wie
  /// viele Runden sie braucht, hängt an der Maschine — ein Test mit festen
  /// Wartezeiten flattert.
  @visibleForTesting
  static Future<Uint8List?>? pendingForTests(String url) =>
      _gemerkt[url.trim()];

  static Future<Uint8List?> _holen(String url) {
    final adresse = url.trim();
    final schon = _gemerkt[adresse];
    if (schon != null) return schon;
    if (_gemerkt.length >= _grenze) _gemerkt.remove(_gemerkt.keys.first);
    final lauf = ImageCacheService().bytes(adresse);
    _gemerkt[adresse] = lauf;
    return lauf;
  }

  @override
  State<CachedPicture> createState() => _CachedPictureState();
}

class _CachedPictureState extends State<CachedPicture> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = CachedPicture._holen(widget.url);
  }

  @override
  void didUpdateWidget(CachedPicture alt) {
    super.didUpdateWidget(alt);
    if (alt.url != widget.url) {
      _bytes = CachedPicture._holen(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, stand) {
        final daten = stand.data;
        if (daten != null) {
          return Image.memory(
            daten,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            // Kaputte Bytes sehen aus wie ein fehlendes Bild, nicht wie ein
            // Absturz.
            errorBuilder: (_, _, _) => _leer(),
          );
        }
        // Fertig und nichts bekommen: das ist der Fehlerfall. Noch nicht
        // fertig: eine leere Fläche in derselben Größe, damit das Gerüst
        // nicht springt.
        if (stand.connectionState == ConnectionState.done) {
          return _leer();
        }
        return SizedBox(width: widget.width, height: widget.height);
      },
    );
  }

  Widget _leer() =>
      widget.error ??
      SizedBox(width: widget.width, height: widget.height);
}
