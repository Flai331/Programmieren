import '../data/database.dart';
import '../data/doc_types.dart';
import '../data/document_repository.dart';
import 'extractors.dart';

/// Baut aus dem OCR-Text den vorausgefüllten Entwurf für den
/// Bestätigen-Screen: Regeln + lernende Absender-Zuordnungen.
class SuggestionService {
  final DocumentRepository repository;

  SuggestionService(this.repository);

  Future<DocumentDraft> buildDraft(String ocrText, {DateTime? now}) async {
    final reference = now ?? DateTime.now();

    // Bekannte Absender über Namen + Aliasse wiedererkennen.
    final correspondents = await repository.allCorrespondents();
    final aliasToId = <String, String>{};
    for (final c in correspondents) {
      aliasToId[c.name] = c.id;
      for (final alias in c.aliases.split('\n')) {
        if (alias.trim().isNotEmpty) aliasToId[alias.trim()] = c.id;
      }
    }
    final matchedId = matchKnownCorrespondent(ocrText, aliasToId);
    Correspondent? matched;
    if (matchedId != null) {
      matched = await repository.getCorrespondent(matchedId);
    }

    var docType = guessDocType(ocrText);
    var tagNames = <String>[];
    if (matched != null) {
      // Lernende Zuordnung: zuletzt bestätigte Werte dieses Absenders.
      docType ??= matched.defaultDocType;
      final tagIds = matched.defaultTagIds
          .split(',')
          .where((t) => t.isNotEmpty)
          .toList();
      tagNames = (await repository.tagsByIds(tagIds))
          .map((t) => t.name)
          .toList();
    }

    final docDate = guessDocDate(ocrText, now: reference);

    return DocumentDraft(
      title: suggestTitle(
        docType: docType,
        correspondentName: matched?.name,
        ocrText: ocrText,
      ),
      docDate: docDate,
      correspondentName: matched?.name,
      docType: docType,
      tagNames: tagNames,
      storageLocation: StorageLocations.boxForYear(reference.year),
      retentionUntil:
          suggestedRetentionUntil(docType, docDate ?? reference),
    );
  }
}
