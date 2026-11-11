import 'package:intl/intl.dart';

/// Platzhalter in Betreff/Text ersetzen: {nummer} {titel} {datum} {firma}
/// {kdnr} {az} {rgnr} {vsnr} {name}. Unbekannte bleiben leer; doppelte
/// Leerzeichen/Trenner werden aufgeräumt.
String fillTemplate(String template, Map<String, String?> values) {
  var out = template.replaceAllMapped(RegExp(r'\{(\w+)\}'),
      (m) => (values[m[1]!.toLowerCase()] ?? '').trim());
  out = out
      .split('\n')
      .map((l) => l
          .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
          .replaceAll(RegExp(r'(\s[–\-·,]\s*)+$'), '')
          .replaceAll(RegExp(r'^\s*[–\-·,]\s'), '')
          .trimRight())
      .join('\n');
  return out.trim();
}

Map<String, String?> templateValues({
  required String docNumber,
  required String title,
  DateTime? docDate,
  String firm = '',
  Map<String, Set<String>> refs = const {},
  String name = '',
}) =>
    {
      'nummer': docNumber,
      'titel': title,
      'datum': docDate == null ? '' : DateFormat('dd.MM.yyyy').format(docDate),
      'firma': firm,
      'kdnr': refs['KDNR']?.firstOrNull,
      'az': refs['AZ']?.firstOrNull,
      'rgnr': refs['RGNR']?.firstOrNull,
      'vsnr': refs['VSNR']?.firstOrNull,
      'name': name,
    };

const kDefaultMailBody = 'Sehr geehrte Damen und Herren,\n\n'
    'anbei erhalten Sie {titel}{kdnr_hint}.\n\n'
    'Mit freundlichen Grüßen\n{name}';

/// Standardtext, wenn die Firma keine Vorlage hat.
String defaultMailBody(Map<String, String?> v) => fillTemplate(
    kDefaultMailBody.replaceAll(
        '{kdnr_hint}',
        (v['kdnr'] ?? '').isEmpty
            ? ''
            : ' (Kundennummer {kdnr})'),
    v);
