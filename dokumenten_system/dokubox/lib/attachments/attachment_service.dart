import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../backup/backup_service.dart';
import '../data/database.dart';
import '../data/document_repository.dart';

/// Fotos/Dateien an Dokumenten, gespeichert unter `anhaenge/`.
class AttachmentService {
  final DocumentRepository repository;
  final Future<Directory> Function() _docsDir;

  AttachmentService(this.repository, {Future<Directory> Function()? docsDir})
      : _docsDir = docsDir ?? getApplicationDocumentsDirectory;

  /// Lange Kante, auf die Fotos verkleinert werden.
  static const maxPhotoEdge = 2000;

  Future<String> absolutePath(Attachment a) async =>
      p.join((await _docsDir()).path, a.relPath);

  /// Datei übernehmen (Kopie). Fotos werden verkleinert (JPEG 85).
  Future<Attachment> add(String documentId, String sourcePath,
      {String caption = ''}) async {
    final ext = p.extension(sourcePath).toLowerCase();
    final isPhoto = const {'.jpg', '.jpeg', '.png', '.heic', '.webp'}.contains(ext);
    var bytes = await File(sourcePath).readAsBytes();
    var outExt = ext.isEmpty ? '.bin' : ext;
    var mime = _mime(ext);
    if (isPhoto && ext != '.heic') {
      final shrunk = await Isolate.run(() => shrinkPhoto(bytes));
      if (shrunk != null) {
        bytes = shrunk;
        outExt = '.jpg';
        mime = 'image/jpeg';
      }
    }
    final dir = Directory(p.join((await _docsDir()).path, attachmentsDirName));
    await dir.create(recursive: true);
    final name = '${const Uuid().v4()}$outExt';
    await File(p.join(dir.path, name)).writeAsBytes(bytes, flush: true);
    final hash = await Sha256().hash(bytes);
    return repository.addAttachment(
      documentId: documentId,
      kind: isPhoto ? 'foto' : 'datei',
      relPath: p.join(attachmentsDirName, name),
      mime: mime,
      caption: caption.isEmpty ? p.basenameWithoutExtension(sourcePath) : caption,
      sizeBytes: bytes.length,
      sha256: hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
  }

  static String _mime(String ext) => switch (ext) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.heic' => 'image/heic',
        '.pdf' => 'application/pdf',
        '.txt' => 'text/plain',
        _ => 'application/octet-stream',
      };
}

/// Foto auf [AttachmentService.maxPhotoEdge] verkleinern; null, wenn nicht
/// lesbar oder schon klein genug (dann Original behalten).
Uint8List? shrinkPhoto(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  final edge = image.width > image.height ? image.width : image.height;
  if (edge <= AttachmentService.maxPhotoEdge && bytes.length < 1500000) {
    return null;
  }
  final scaled = image.width >= image.height
      ? img.copyResize(image, width: AttachmentService.maxPhotoEdge)
      : img.copyResize(image, height: AttachmentService.maxPhotoEdge);
  return img.encodeJpg(scaled, quality: 85);
}
