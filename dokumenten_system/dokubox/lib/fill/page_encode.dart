import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Rohpixel (BGRA, wie pdfrx sie liefert) → JPEG. Rein und isolatfähig.
/// JPEG hält die ausgefüllte PDF klein (Scans komprimieren als PNG schlecht).
Uint8List encodeBgraToJpg(int width, int height, Uint8List bgra,
    {int quality = 85}) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bgra.buffer,
    bytesOffset: bgra.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
  );
  return img.encodeJpg(image, quality: quality);
}
