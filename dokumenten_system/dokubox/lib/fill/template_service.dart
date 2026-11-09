import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../data/document_repository.dart';
import 'fill_model.dart';

/// Unterschriften/Vorlagen (PNG) im App-Verzeichnis `vorlagen/`.
class TemplateService {
  static const dirName = 'vorlagen';
  final DocumentRepository repository;
  final _cache = <String, Uint8List>{};

  TemplateService(this.repository);

  static Future<Directory> directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, dirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Speichert eine PNG als neue Vorlage. Wirft [FormatException], wenn es
  /// keine PNG ist.
  Future<SignatureTemplate> addPng(String name, Uint8List bytes) async {
    final size = pngSize(bytes);
    if (size == null) {
      throw const FormatException('Keine gültige PNG-Datei.');
    }
    final file = '${const Uuid().v4()}.png';
    final dir = await directory();
    await File(p.join(dir.path, file)).writeAsBytes(bytes, flush: true);
    return repository.addTemplate(
      name: name,
      imagePath: p.join(dirName, file),
      aspect: size.height / size.width,
    );
  }

  /// PNG-Bytes einer Vorlage (auch gelöschter, damit ältere Eintragungen
  /// weiter funktionieren). `null`, wenn die Datei fehlt.
  Future<Uint8List?> bytes(String templateId) async {
    final cached = _cache[templateId];
    if (cached != null) return cached;
    final t = await repository.getTemplate(templateId);
    if (t == null) return null;
    final base = await getApplicationDocumentsDirectory();
    final file = File(p.join(base.path, t.imagePath));
    if (!await file.exists()) return null;
    return _cache[templateId] = await file.readAsBytes();
  }
}
