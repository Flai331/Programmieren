// Erkennt, ob ein neues Dokument zu einem vorhandenen gehört (Bescheid zu
// Antrag, Mahnung zu Rechnung …), über gemeinsame Referenzen.
// Rein und ohne Datenbank – testbar.

/// Vereinheitlicht Nummern für den Vergleich (Leerzeichen, Bindestriche,
/// Schrägstriche, Punkte raus; Großschreibung).
String normalizeRef(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[\s\-/.]'), '');

/// Gewicht je Referenzart. `null` = zählt nicht (IBAN: jede Rechnung
/// derselben Firma hat sie).
int? refWeight(String kind, {required bool sameCorrespondent}) =>
    switch (kind) {
      'AZ' => 10, // Aktenzeichen/Vorgang: sehr spezifisch
      'RGNR' => 10, // Rechnungsnummer: Mahnung, Gutschrift zur Rechnung
      'STNR' => sameCorrespondent ? 6 : null,
      'VSNR' || 'KDNR' => sameCorrespondent ? 4 : null, // betrifft alle Briefe
      'REF' => sameCorrespondent ? 3 : null,
      _ => null, // IBAN u. a.
    };

/// Ab dieser Punktzahl wird eine Verknüpfung vorgeschlagen.
const kRefMatchThreshold = 6;

class RefCandidate {
  final String documentId;
  final String? correspondentId;

  /// Art → Werte (wie `extractRefs`).
  final Map<String, Set<String>> refs;
  const RefCandidate(this.documentId, this.correspondentId, this.refs);
}

class RefMatch {
  final String documentId;
  final int score;

  /// Die gemeinsamen Referenzen, z. B. `AZ 12/345`.
  final List<String> reasons;
  const RefMatch(this.documentId, this.score, this.reasons);
}

/// Bewertet [candidates] gegen die Referenzen des neuen Dokuments; liefert
/// die Treffer ab [kRefMatchThreshold], bester zuerst.
List<RefMatch> matchRefs(
  Map<String, Set<String>> refs,
  String? correspondentId,
  Iterable<RefCandidate> candidates,
) {
  final mine = {
    for (final e in refs.entries)
      e.key: {for (final v in e.value) normalizeRef(v): v},
  };
  final result = <RefMatch>[];
  for (final c in candidates) {
    final same = correspondentId != null && correspondentId == c.correspondentId;
    var score = 0;
    final reasons = <String>[];
    for (final e in c.refs.entries) {
      final weight = refWeight(e.key, sameCorrespondent: same);
      final values = mine[e.key];
      if (weight == null || values == null) continue;
      for (final v in e.value) {
        final original = values[normalizeRef(v)];
        if (original != null && normalizeRef(v).length >= 4) {
          score += weight;
          reasons.add('${e.key} $original');
        }
      }
    }
    if (same && score > 0) score += 1; // gleiche Firma als kleiner Bonus
    if (score >= kRefMatchThreshold) {
      result.add(RefMatch(c.documentId, score, reasons));
    }
  }
  result.sort((a, b) => b.score.compareTo(a.score));
  return result;
}
