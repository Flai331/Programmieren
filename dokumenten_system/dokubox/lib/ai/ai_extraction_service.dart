import 'dart:convert';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/doc_types.dart';
import '../data/document_repository.dart';

/// Vom KI-Modell extrahierte Dokumentdaten.
class AiDocumentData {
  final String? absender;
  final DateTime? datum;
  final String? typ;
  final String? titel;

  /// Thematische Tags, z. B. "Rentenversicherung", "Auto", "Steuer".
  final List<String> tags;

  const AiDocumentData({
    this.absender,
    this.datum,
    this.typ,
    this.titel,
    this.tags = const [],
  });

  bool get isEmpty =>
      absender == null &&
      datum == null &&
      typ == null &&
      titel == null &&
      tags.isEmpty;
}

/// Zieht aus einer (möglicherweise geschwätzigen) Modellantwort das erste
/// JSON-Objekt und parst es fehlertolerant. `null` wenn nichts Brauchbares
/// drinsteht.
AiDocumentData? parseAiJson(String response) {
  // Denk-Blöcke (Qwen3) und Markdown-Zäune entfernen.
  var text = response
      .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
      .replaceAll(RegExp(r'```(?:json)?'), '');
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  text = text.substring(start, end + 1);

  final Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) return null;
    map = decoded;
  } on FormatException {
    return null;
  }

  String? str(String key) {
    final v = map[key];
    if (v is! String) return null;
    final t = v.trim();
    if (t.isEmpty || t.toLowerCase() == 'null' || t.toLowerCase() == 'unbekannt') {
      return null;
    }
    return t;
  }

  DateTime? datum;
  final rawDatum = str('datum');
  if (rawDatum != null) {
    datum = DateTime.tryParse(rawDatum);
    // Auch deutsches Format tolerieren, falls das Modell es liefert.
    if (datum == null) {
      final m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(rawDatum);
      if (m != null) {
        datum = DateTime(
            int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
      }
    }
    // Unplausible Jahre verwerfen.
    if (datum != null && (datum.year < 1990 || datum.year > 2100)) {
      datum = null;
    }
  }

  // Nur bekannte Typen übernehmen, sonst verwirft der Nutzer nur wieder.
  var typ = str('typ');
  if (typ != null) {
    typ = kDocTypes.firstWhere(
      (t) => t.toLowerCase() == typ!.toLowerCase(),
      orElse: () => '',
    );
    if (typ.isEmpty) typ = null;
  }

  var titel = str('titel');
  if (titel != null && titel.length > 80) {
    titel = '${titel.substring(0, 79)}…';
  }

  final result = AiDocumentData(
    absender: str('absender'),
    datum: datum,
    typ: typ,
    titel: titel,
    tags: _parseTags(map['tags']),
  );
  return result.isEmpty ? null : result;
}

/// Liest die Tags aus der Modellantwort: akzeptiert eine JSON-Liste oder
/// einen kommagetrennten String. Bereinigt, entdoppelt und begrenzt auf
/// max. 4 kurze Tags.
List<String> _parseTags(dynamic raw) {
  final List<String> candidates;
  if (raw is List) {
    candidates = raw.map((e) => e.toString()).toList();
  } else if (raw is String) {
    candidates = raw.split(RegExp(r'[,;]'));
  } else {
    return const [];
  }
  final result = <String>[];
  final seen = <String>{};
  for (final c in candidates) {
    final tag = c.trim();
    if (tag.isEmpty ||
        tag.length > 30 ||
        tag.toLowerCase() == 'null' ||
        tag.toLowerCase() == 'unbekannt') {
      continue;
    }
    if (seen.add(tag.toLowerCase())) result.add(tag);
    if (result.length >= 4) break;
  }
  return result;
}

/// Mischt das KI-Ergebnis in den regelbasierten Entwurf.
///
/// Die KI gewinnt bei Titel, Datum und Typ (sie liest den Kontext besser als
/// Regeln). Beim Absender gewinnt ein bereits BEKANNTER Korrespondent
/// ([preserveCorrespondent]), weil dessen gelernte Tags/Typen daran hängen.
void applyAiToDraft(
  DocumentDraft draft,
  AiDocumentData ai, {
  bool preserveCorrespondent = false,
}) {
  if (ai.titel != null) draft.title = ai.titel!;
  if (ai.datum != null) draft.docDate = ai.datum;
  if (ai.absender != null && !preserveCorrespondent) {
    draft.correspondentName = ai.absender;
  }
  if (ai.typ != null && ai.typ != draft.docType) {
    draft.docType = ai.typ;
    draft.retentionUntil = suggestedRetentionUntil(
        ai.typ, draft.docDate ?? DateTime.now());
  }
  // KI-Tags zu den (evtl. gelernten) Tags dazunehmen, ohne Dubletten.
  final existing = draft.tagNames.map((t) => t.toLowerCase()).toSet();
  for (final tag in ai.tags) {
    if (existing.add(tag.toLowerCase())) draft.tagNames.add(tag);
  }
}

/// Lokales KI-Auslesen mit Qwen3 0.6B über flutter_gemma (LiteRT-LM).
/// Modell läuft komplett auf dem Gerät; einmaliger Download ~600 MB,
/// kein Konto und kein Token nötig (Apache-2.0-Modell).
class AiExtractionService {
  static const modelFilename = 'Qwen3-0.6B.litertlm';
  static const modelUrl =
      'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm';
  static const modelSizeLabel = 'ca. 600 MB';
  static const _enabledKey = 'ai_extraction_enabled';

  InferenceModel? _model;
  bool _registered = false;

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_enabledKey, value);

  Future<bool> isInstalled() => FlutterGemma.isModelInstalled(modelFilename);

  /// Aktiv = eingeschaltet UND Modell vorhanden.
  Future<bool> isReady() async => await isEnabled() && await isInstalled();

  /// Lädt das Modell herunter (bzw. registriert es, wenn die Datei schon
  /// da ist). [onProgress] bekommt 0–100.
  Future<void> download({void Function(int percent)? onProgress}) async {
    await FlutterGemma.installModel(
      modelType: ModelType.qwen3,
      fileType: ModelFileType.litertlm,
    )
        .fromNetwork(modelUrl)
        .withProgress((p) => onProgress?.call(p))
        .install();
    _registered = true;
    await setEnabled(true);
  }

  Future<void> delete() async {
    await _model?.close();
    _model = null;
    _registered = false;
    await setEnabled(false);
    await FlutterGemma.uninstallModel(modelFilename);
  }

  Future<InferenceModel> _loadModel() async {
    if (_model != null) return _model!;
    if (!_registered) {
      // Registriert das vorhandene Modell als aktiv (Datei existiert schon,
      // es wird nichts erneut heruntergeladen).
      await FlutterGemma.installModel(
        modelType: ModelType.qwen3,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(modelUrl).install();
      _registered = true;
    }
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.cpu,
    );
    return _model!;
  }

  /// Nur der obere Teil des Dokuments wird an die KI gegeben. Absender,
  /// Datum und Betreff stehen bei Briefen fast immer im Kopf; weniger Text
  /// = deutlich kürzere Rechenzeit auf dem Handy (der Flaschenhals ist das
  /// Einlesen des Prompts).
  static const maxOcrCharsForAi = 1200;

  static String buildPrompt(String ocrText, {List<String> knownTags = const []}) {
    final text = ocrText.length > maxOcrCharsForAi
        ? ocrText.substring(0, maxOcrCharsForAi)
        : ocrText;
    // Vorhandene Tags anbieten, damit das Modell sie wiederverwendet statt
    // Dubletten zu erzeugen ("Rente" vs. "Rentenversicherung").
    final tagHint = knownTags.isEmpty
        ? ''
        : '\n  Verwende bevorzugt vorhandene Tags, falls passend: '
            '${knownTags.take(30).join(', ')}.';
    return '''
Du extrahierst Metadaten aus dem OCR-Text eines eingescannten deutschen Dokuments.
Antworte AUSSCHLIESSLICH mit einem JSON-Objekt in genau dieser Form, ohne Erklärungen:
{"absender": "...", "datum": "JJJJ-MM-TT", "typ": "...", "titel": "...", "tags": ["...", "..."]}

Regeln:
- "absender": die Firma/Behörde, die das Dokument VERSCHICKT hat (nie der private Empfänger). Unbekannt: null
- "datum": das Datum des Dokuments im Format JJJJ-MM-TT. Unbekannt: null
- "typ": genau einer dieser Werte: ${kDocTypes.join(', ')}. Unbekannt: null
- "titel": kurzer aussagekräftiger Titel (max. 60 Zeichen), am besten der Betreff. Unbekannt: null
- "tags": 1 bis 3 kurze Themen/Bereiche, zu denen das Dokument gehört (z. B. "Rentenversicherung", "Krankenversicherung", "Auto", "Wohnung", "Steuer", "Bank"). Leere Liste, wenn unklar.$tagHint

OCR-TEXT:
"""
$text
"""''';
  }

  /// Liest die Dokumentdaten per lokalem Modell aus. Wirft nicht — bei
  /// Fehlern oder Timeout kommt `null` zurück und die Regel-Vorschläge
  /// bleiben stehen.
  Future<AiDocumentData?> extract(String ocrText,
      {List<String> knownTags = const [],
      Duration timeout = const Duration(seconds: 60)}) async {
    if (ocrText.trim().isEmpty) return null;
    try {
      final model = await _loadModel();
      final chat = await model.createChat(
        temperature: 0.1,
        topK: 1,
        isThinking: false,
        // Das JSON ist kurz — kurze Ausgabe spart Rechenzeit.
        maxOutputTokens: 128,
      );
      await chat.addQueryChunk(Message.text(
          text: buildPrompt(ocrText, knownTags: knownTags), isUser: true));
      final response = await chat.generateChatResponse().timeout(timeout);
      final text = switch (response) {
        TextResponse(:final token) => token,
        ThinkingResponse(:final content) => content,
        _ => '',
      };
      return parseAiJson(text);
    } catch (_) {
      return null;
    }
  }
}
