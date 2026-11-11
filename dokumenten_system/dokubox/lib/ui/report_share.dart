import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../fill/fill_export.dart';
import 'share_name.dart';

/// Schrift für Ausdrucke.
Future<ByteData> reportFont() => rootBundle.load(kFillFontAsset);

/// Erzeugte PDF teilen/drucken (Drucken geht über „Teilen“ → Drucker).
Future<void> shareReport(Uint8List bytes, String name) async {
  final file = File(p.join(
      (await getTemporaryDirectory()).path, safePdfFileName(name)));
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'application/pdf')],
    subject: name,
  ));
}
