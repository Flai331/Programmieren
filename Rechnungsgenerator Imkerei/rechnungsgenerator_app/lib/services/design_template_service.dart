import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/design_template_model.dart';

/// Speichert Design-Vorlagen lokal als JSON-Datei.
class DesignTemplateService {
  static const _fileName = 'design_templates.json';

  static DesignTemplateService? _instance;
  DesignTemplateService._();
  factory DesignTemplateService() => _instance ??= DesignTemplateService._();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<DesignTemplateModel>> loadAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      return DesignTemplateModel.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> save(DesignTemplateModel template) async {
    final list = await loadAll();
    // Ersetze wenn ID schon vorhanden
    final idx = list.indexWhere((t) => t.id == template.id);
    if (idx >= 0) {
      list[idx] = template;
    } else {
      list.insert(0, template);
    }
    await _write(list);
  }

  Future<void> delete(String id) async {
    final list = await loadAll();
    list.removeWhere((t) => t.id == id);
    await _write(list);
  }

  Future<void> _write(List<DesignTemplateModel> list) async {
    final f = await _file();
    await f.writeAsString(DesignTemplateModel.listToJson(list));
  }
}
