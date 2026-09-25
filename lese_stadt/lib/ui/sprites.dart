import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Die mit Blender gerenderten Gebäudebilder (`tools/sprites`).
///
/// Jedes Bild ist 320×480 px groß, die Feldmitte liegt bei (160, 384) und
/// ein Feld ist 256 px breit. Zu Gebäuden mit Fenstern gibt es zusätzlich
/// `<name>_nacht` mit erleuchteten Fenstern.
class Sprites {
  Sprites(this._bilder);

  final Map<String, ui.Image> _bilder;

  static const anker = Offset(160, 384);
  static const feldBreite = 256.0;
  static const groesse = Size(320, 480);

  /// Welt-Höhe 1 in Bildpixeln (isometrisch verkürzt, siehe render_sprites.py).
  static const pxProHoehe = 0.866 * 320 / (1.25 * 1.41421356);

  /// Nach dem Laden gesetzt; in Tests bleibt es null und die Stadt wird
  /// gezeichnet statt aus Bildern zusammengesetzt.
  static Sprites? instance;

  ui.Image? operator [](String name) => _bilder[name];

  static Future<Sprites> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(b);
    final bilder = <String, ui.Image>{};
    for (final pfad in manifest.listAssets()) {
      if (!pfad.startsWith('assets/sprites/')) continue;
      final name = pfad.split('/').last.split('.').first;
      final data = await b.load(pfad);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      bilder[name] = (await codec.getNextFrame()).image;
    }
    return Sprites(bilder);
  }
}
