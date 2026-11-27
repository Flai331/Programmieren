import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bilder für Rechnung und Vorschau beschaffen — von der Platte oder, wenn
/// es sein muss, einmal aus dem Netz.
///
/// Logo und Kopfbild stehen in der Datenbank als Zeichenkette
/// (`design_settings.logo_url`). Der Name führt in die Irre: was dort steht,
/// ist bei dieser App ein **Pfad auf dem Gerät** — `_uploadImage` im
/// Design-Bildschirm legt das gewählte Bild im App-Ordner ab und speichert
/// `file.path`. Benutzt wurde es trotzdem als Netzadresse,
/// `networkImage(...)` im PDF und `Image.network(...)` in der Vorschau, und
/// beide können nur http. Darum war auf jeder Rechnung dort eine Lücke und
/// in der Vorschau ein rotes Feld. [bytes] sieht deshalb zuerst nach, was es
/// vor sich hat, und liest einen Pfad einfach.
///
/// Für eine echte Netzadresse gilt: **erst der Zwischenspeicher, dann das
/// Netz.** Vorher wurde bei jedem PDF neu geladen, ohne Zeitgrenze und ohne
/// Vorrat, der einen App-Start übersteht; bei einem Balken Netz wartet die
/// App dann, bis Android aufgibt. Liegt die Datei schon da, wird gar nicht
/// gefunkt — das ist der Fall, der im Keller und am Bienenstand zählt. Erst
/// wenn sie fehlt, wird geladen, mit Zeitgrenze, und das Ergebnis bleibt als
/// Datei liegen.
///
/// Der Dateiname ist ein Streuwert der Adresse (FNV-1a, in Dart gerechnet,
/// damit er über App-Starts hinweg derselbe bleibt — `String.hashCode` ist
/// das ausdrücklich nicht). Eine neue Adresse ist damit ein neuer Eintrag.
/// Wird dagegen *hinter derselben Adresse* ein anderes Bild hinterlegt,
/// merkt die App das nicht; dafür gibt es [forget].
class ImageCacheService {
  ImageCacheService._internal();

  static final ImageCacheService _instance = ImageCacheService._internal();

  factory ImageCacheService() => _instance;

  /// Wie lange auf das Netz gewartet wird, bevor aufgegeben wird. Kurz
  /// genug, dass eine Rechnung nicht daran hängen bleibt.
  static const Duration defaultTimeout = Duration(seconds: 6);

  /// Nur für Tests: Ablageort unterschieben, statt path_provider zu rufen
  /// (das braucht eine Plattform und gibt es im Test nicht).
  @visibleForTesting
  Directory? directoryForTests;

  /// Nur für Tests: den Download ersetzen. Gibt zurück, was „aus dem Netz"
  /// kommt, oder wirft, um schlechten Empfang nachzustellen.
  @visibleForTesting
  Future<Uint8List> Function(Uri uri)? downloaderForTests;

  /// Nur für Tests: zählt, wie oft wirklich geladen wurde.
  @visibleForTesting
  int downloads = 0;

  /// Die Bytes zu [url] — von der Platte, aus dem Zwischenspeicher oder aus
  /// dem Netz, in dieser Reihenfolge.
  ///
  /// Gibt `null` zurück, wenn die Angabe leer ist oder nichts davon
  /// aufgeht. Wirft nie: ein fehlendes Logo darf keine Rechnung verhindern.
  Future<Uint8List?> bytes(
    String? url, {
    Duration timeout = defaultTimeout,
  }) async {
    if (url == null || url.trim().isEmpty) return null;
    final adresse = url.trim();
    final Uri? uri = Uri.tryParse(adresse);

    // Ein Pfad auf dem Gerät ist schon eine Datei: lesen, nicht kopieren.
    // Das ist bei dieser App der Normalfall (siehe oben).
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      final eigen = uri != null && uri.scheme == 'file'
          ? File.fromUri(uri)
          : File(adresse);
      return _lesen(eigen);
    }

    final datei = await _datei(adresse);
    if (datei != null) {
      final gemerkt = await _lesen(datei);
      if (gemerkt != null) return gemerkt;
    }

    Uint8List? geladen;
    try {
      downloads++;
      geladen = await (downloaderForTests ?? _laden)(uri).timeout(timeout);
    } catch (_) {
      return null;
    }
    if (geladen.isEmpty) return null;

    if (datei != null) {
      try {
        await datei.parent.create(recursive: true);
        await datei.writeAsBytes(geladen, flush: true);
      } catch (_) {
        // Nicht ablegen zu können ist bitter, aber kein Fehler für diesen
        // Aufruf: das Bild ist ja da.
      }
    }
    return geladen;
  }

  /// Den Eintrag zu [url] wegwerfen, damit das Bild neu geholt wird.
  ///
  /// Betrifft nur den eigenen Ablageordner. Ein Bild, das der Nutzer selbst
  /// ausgewählt hat, liegt woanders und wird hier nie angefasst.
  Future<void> forget(String url) async {
    final datei = await _datei(url.trim());
    if (datei == null) return;
    try {
      if (await datei.exists()) await datei.delete();
    } catch (_) {
      // Dann bleibt es eben liegen.
    }
  }

  /// Den ganzen Zwischenspeicher wegwerfen.
  Future<void> clear() async {
    final ordner = await _ordner();
    if (ordner == null) return;
    try {
      if (await ordner.exists()) await ordner.delete(recursive: true);
    } catch (_) {
      // Dann bleibt es eben liegen.
    }
  }

  // ── Innereien ────────────────────────────────────────────────────

  Future<Directory?> _ordner() async {
    final vorgegeben = directoryForTests;
    if (vorgegeben != null) return vorgegeben;
    try {
      final basis = await getApplicationSupportDirectory();
      return Directory(p.join(basis.path, 'bildspeicher'));
    } catch (_) {
      // Ohne Ablageort geht es auch, nur ohne Gedächtnis.
      return null;
    }
  }

  /// Eine Datei lesen, oder `null`. Eine leere Datei gilt als nicht da —
  /// so wird ein abgebrochener Download beim nächsten Mal nachgeholt.
  Future<Uint8List?> _lesen(File datei) async {
    try {
      if (!await datei.exists()) return null;
      if (await datei.length() <= 0) return null;
      return await datei.readAsBytes();
    } catch (_) {
      // Unlesbar ist so gut wie nicht vorhanden.
      return null;
    }
  }

  Future<File?> _datei(String url) async {
    final ordner = await _ordner();
    if (ordner == null) return null;
    return File(p.join(ordner.path, dateinameFor(url)));
  }

  /// Der Dateiname zu einer Adresse. Öffentlich, weil der Test ihn braucht.
  @visibleForTesting
  static String dateinameFor(String url) {
    final endung = _endung(url);
    return '${_fnv1a(url)}$endung';
  }

  /// FNV-1a über 64 Bit, als Hexzahl. Selbst gerechnet, weil das Ergebnis
  /// über App-Starts hinweg gleich bleiben muss und weil dafür kein
  /// zusätzliches Paket in die App soll.
  static String _fnv1a(String text) {
    // Die Konstanten des Verfahrens. In Dart sind int 64 Bit, der Überlauf
    // beim Multiplizieren ist hier gewollt und harmlos.
    var streuwert = 0xcbf29ce484222325;
    for (final einheit in text.codeUnits) {
      streuwert ^= einheit;
      streuwert = streuwert * 0x100000001b3;
    }
    // Vorzeichenlos ausschreiben, und zwar in zwei Hälften. Dart kennt nur
    // vorzeichenbehaftete Zahlen: `toRadixString(16)` setzt bei jedem
    // zweiten Streuwert ein Minus vor den Dateinamen, und
    // `toUnsigned(64)` hilft dagegen nicht — bei voller Breite ist das ein
    // Leerlauf. `>>>` schiebt dagegen ohne Vorzeichen.
    final hoch = streuwert >>> 32;
    final tief = streuwert & 0xFFFFFFFF;
    return hoch.toRadixString(16).padLeft(8, '0') +
        tief.toRadixString(16).padLeft(8, '0');
  }

  /// Die Endung aus der Adresse, nur damit die Dateien im Ablageordner
  /// erkennbar bleiben. Ohne brauchbare Endung ohne.
  static String _endung(String url) {
    final pfad = Uri.tryParse(url)?.path ?? '';
    final endung = p.extension(pfad).toLowerCase();
    const erlaubt = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};
    return erlaubt.contains(endung) ? endung : '';
  }

  Future<Uint8List> _laden(Uri uri) async {
    final klient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..userAgent = 'BeeBrain';
    try {
      final anfrage = await klient.getUrl(uri);
      final antwort = await anfrage.close();
      if (antwort.statusCode != 200) {
        throw HttpException('Status ${antwort.statusCode}', uri: uri);
      }
      final stuecke = await antwort.toList();
      return Uint8List.fromList(
          stuecke.expand((stueck) => stueck).toList(growable: false));
    } finally {
      klient.close(force: true);
    }
  }
}
