import '../models/honey_bucket_model.dart';

/// Wie sicher ein gelesener Code zugeordnet werden konnte.
enum BucketCodeConfidence {
  /// Zeichen für Zeichen getroffen.
  exact,

  /// Erst nach Ausgleich typischer Verwechslungen getroffen – etwa `5O-O42`
  /// für `SO-042`. Dem Nutzer wird gezeigt, worauf die App gekommen ist.
  corrected,

  /// Mehrere Eimer kommen in Frage. Die App rät nicht, sie fragt.
  ambiguous,

  /// Nichts Passendes gefunden.
  none,
}

/// Ergebnis eines Abgleichs.
class BucketCodeMatch {
  /// Der eindeutig zugeordnete Code, null bei [BucketCodeConfidence.ambiguous]
  /// und [BucketCodeConfidence.none].
  final String? code;

  /// Bei Mehrdeutigkeit: die Codes, die in Frage kommen.
  final List<String> candidates;

  final BucketCodeConfidence confidence;

  const BucketCodeMatch({
    this.code,
    this.candidates = const [],
    required this.confidence,
  });

  bool get isResolved => code != null;

  /// Soll dem Nutzer der Treffer zur Bestätigung gezeigt werden?
  /// Bei einem Zeichen-für-Zeichen-Treffer ist das unnötig.
  bool get needsConfirmation => confidence == BucketCodeConfidence.corrected;

  const BucketCodeMatch.none()
      : code = null,
        candidates = const [],
        confidence = BucketCodeConfidence.none;
}

/// Vergibt und erkennt die Codes, die von Hand auf die Eimer geschrieben
/// werden – zum Beispiel `SO-042`.
///
/// Der entscheidende Gedanke: Die App vergibt die Codes selbst und kennt
/// daher die Liste aller gültigen. Eine Kamera-Lesung muss deshalb keinen
/// Freitext entziffern, sondern nur aus wenigen bekannten Möglichkeiten die
/// richtige treffen. Das macht aus unzuverlässiger Handschrift-Erkennung ein
/// brauchbares Werkzeug: Ein verwackeltes `5O-O42` findet trotzdem zu
/// `SO-042`, weil nichts anderes in der Nähe liegt.
///
/// Reine Funktionen ohne Abhängigkeiten – die Logik ist vollständig ohne
/// Kamera und ohne Datenbank prüfbar.
class BucketCode {
  /// Stellen der laufenden Nummer. Drei reichen für 999 Eimer und bleiben
  /// mit dickem Stift gut lesbar.
  static const int numberDigits = 3;

  /// Code zusammensetzen: `format('SO', 42)` → `'SO-042'`.
  static String format(String variety, int number) =>
      '$variety-${number.toString().padLeft(numberDigits, '0')}';

  /// Nächste freie Nummer. Global laufend, nicht je Sorte – dadurch genügen
  /// die Ziffern allein zur Identifikation.
  static int nextNumber(int highestSoFar) =>
      highestSoFar < 0 ? 1 : highestSoFar + 1;

  /// Vergleichsform: Großbuchstaben, ohne Trenner und Leerraum.
  /// `'so 42'` → `'SO42'`, `'SO-042'` → `'SO042'`.
  static String normalize(String raw) {
    final gross = raw.trim().toUpperCase();
    final buffer = StringBuffer();
    for (final zeichen in gross.split('')) {
      // Nur Buchstaben und Ziffern zählen. Bindestriche, Punkte,
      // Leerzeichen und Zeilenumbrüche fallen weg.
      final ist = RegExp(r'[A-Z0-9]').hasMatch(zeichen);
      if (ist) buffer.write(zeichen);
    }
    return buffer.toString();
  }

  /// Zeichen, die in Handschrift regelmäßig verwechselt werden, auf eine
  /// gemeinsame Form bringen.
  ///
  /// Das ist unbedenklich, weil es die echten Codes nicht zusammenfallen
  /// lässt: Die Sortenkürzel bleiben auch gefaltet verschieden
  /// (`SO`→`50`, `LI`→`11`, `FR`→`FR` …), und Ziffern fallen auf sich
  /// selbst. Zwei verschiedene gültige Codes können daher nie dieselbe
  /// Faltung haben – das sichert ein Test ab.
  static const Map<String, String> _verwechslungen = {
    'O': '0', 'Q': '0',
    'I': '1', 'L': '1',
    'S': '5',
    'Z': '2',
    'B': '8',
    'G': '6',
  };

  static String _falten(String normalisiert) {
    final buffer = StringBuffer();
    for (final zeichen in normalisiert.split('')) {
      buffer.write(_verwechslungen[zeichen] ?? zeichen);
    }
    return buffer.toString();
  }

  /// Die laufende Nummer aus einer Lesung ziehen – der letzte Ziffernblock.
  ///
  /// Hilft, wenn vom Kürzel nichts mehr zu erkennen war und nur die Ziffern
  /// ankamen. Null, wenn kein brauchbarer Block gefunden wurde.
  static int? extractNumber(String raw) {
    final treffer = RegExp(r'\d+').allMatches(normalize(raw)).toList();
    if (treffer.isEmpty) return null;
    final letzter = treffer.last.group(0)!;
    // Mehr als vier Ziffern ist keine Eimernummer, sondern Lesemüll.
    if (letzter.length > 4) return null;
    return int.tryParse(letzter);
  }

  /// Nummer aus einem gültigen Code lesen: `'SO-042'` → 42.
  static int? numberOf(String code) => extractNumber(code);

  /// Eine Lesung den vergebenen Codes zuordnen.
  ///
  /// Vier Stufen, von sicher nach großzügig. Sobald eine Stufe **genau
  /// einen** Kandidaten liefert, ist Schluss. Liefert eine Stufe mehrere,
  /// wird gefragt statt geraten.
  static BucketCodeMatch match(String read, List<String> candidates) {
    final gesucht = normalize(read);
    if (gesucht.isEmpty || candidates.isEmpty) {
      return const BucketCodeMatch.none();
    }

    // Stufe 1: Zeichen für Zeichen.
    for (final kandidat in candidates) {
      if (normalize(kandidat) == gesucht) {
        return BucketCodeMatch(
            code: kandidat, confidence: BucketCodeConfidence.exact);
      }
    }

    // Stufe 2: nach Ausgleich der typischen Verwechslungen.
    final gefaltet = _falten(gesucht);
    final gefalteteTreffer = candidates
        .where((k) => _falten(normalize(k)) == gefaltet)
        .toList(growable: false);
    if (gefalteteTreffer.length == 1) {
      return BucketCodeMatch(
          code: gefalteteTreffer.first,
          confidence: BucketCodeConfidence.corrected);
    }
    if (gefalteteTreffer.length > 1) {
      return BucketCodeMatch(
          candidates: gefalteteTreffer,
          confidence: BucketCodeConfidence.ambiguous);
    }

    // Stufe 3: nur die Ziffern. Greift, wenn das Kürzel unleserlich war.
    final nummer = extractNumber(read);
    if (nummer != null) {
      final nummerTreffer = candidates
          .where((k) => numberOf(k) == nummer)
          .toList(growable: false);
      if (nummerTreffer.length == 1) {
        return BucketCodeMatch(
            code: nummerTreffer.first,
            confidence: BucketCodeConfidence.corrected);
      }
      if (nummerTreffer.length > 1) {
        return BucketCodeMatch(
            candidates: nummerTreffer,
            confidence: BucketCodeConfidence.ambiguous);
      }
    }

    // Stufe 4: ein Zeichen Abstand auf der gefalteten Form.
    final nah = candidates
        .where((k) => _abstand(_falten(normalize(k)), gefaltet) <= 1)
        .toList(growable: false);
    if (nah.length == 1) {
      return BucketCodeMatch(
          code: nah.first, confidence: BucketCodeConfidence.corrected);
    }
    if (nah.length > 1) {
      return BucketCodeMatch(
          candidates: nah, confidence: BucketCodeConfidence.ambiguous);
    }

    return const BucketCodeMatch.none();
  }

  /// Levenshtein-Abstand: wie viele Einfügungen, Löschungen oder
  /// Ersetzungen zwei Zeichenketten trennen.
  ///
  /// Bricht früh ab, sobald klar ist, dass der Abstand größer als 1 ist –
  /// mehr braucht der Abgleich nicht zu wissen.
  static int _abstand(String a, String b) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > 1) return 2;

    var vorige = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final aktuelle = List<int>.filled(b.length + 1, 0);
      aktuelle[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final kosten = a[i - 1] == b[j - 1] ? 0 : 1;
        aktuelle[j] = [
          aktuelle[j - 1] + 1, // Einfügung
          vorige[j] + 1, // Löschung
          vorige[j - 1] + kosten, // Ersetzung
        ].reduce((x, y) => x < y ? x : y);
      }
      // Ist die ganze Zeile schon über 1, kann das Ergebnis es nicht mehr
      // unterschreiten.
      if (aktuelle.reduce((x, y) => x < y ? x : y) > 1) return 2;
      vorige = aktuelle;
    }
    return vorige[b.length];
  }

  // ── Kamera-Lesung ──────────────────────────────────────────────

  /// Länge der längsten Zeichengruppe, die aus Nachbar-Stücken gebildet
  /// wird. Drei genügt: `SO`, `-`, `042` ist der schlimmste Fall, in dem
  /// ein Code in Einzelteilen ankommt.
  static const int _maxFenster = 3;

  /// Aus einer Kamera-Lesung alle Bruchstücke bilden, die einen Code
  /// enthalten könnten.
  ///
  /// [lines] ist die Lesung, wie die Texterkennung sie liefert: je Zeile
  /// die einzelnen erkannten Stücke. Das ist nötig, weil `SO-042` je nach
  /// Handschrift als ein Stück ankommt, als `SO` und `042`, oder als `SO`,
  /// `-`, `042`. Nur die Zeile als Ganzes zu prüfen reicht nicht, denn auf
  /// dem Eimer steht neben dem Code noch anderes.
  ///
  /// Zurück kommt eine geordnete Liste, von der aussichtsreichsten
  /// Zusammensetzung zur dürftigsten: erst ganze Zeilen, dann Nachbarn,
  /// dann einzelne Stücke. Doppelte fallen weg.
  ///
  /// Reine Funktion – damit ist der Weg von der Lesung zum Eimer ohne
  /// Kamera prüfbar.
  static List<String> fragments(List<List<String>> lines) {
    final heraus = <String>[];
    final gesehen = <String>{};

    void nimm(String rohling) {
      final vergleich = normalize(rohling);
      // Was nach dem Normalisieren leer ist, trägt kein Zeichen bei.
      if (vergleich.isEmpty) return;
      if (!gesehen.add(vergleich)) return;
      heraus.add(rohling);
    }

    // Erst jede Zeile als Ganzes: Steht nur der Code darauf, trifft das
    // zeichengenau.
    for (final zeile in lines) {
      if (zeile.length > 1) nimm(zeile.join());
    }

    // Dann Nachbarn innerhalb einer Zeile, von lang nach kurz.
    for (var breite = _maxFenster; breite >= 2; breite--) {
      for (final zeile in lines) {
        for (var i = 0; i + breite <= zeile.length; i++) {
          nimm(zeile.sublist(i, i + breite).join());
        }
      }
    }

    // Zuletzt die einzelnen Stücke. Sie tragen den Fall, in dem der Code
    // vollständig in einem Stück ankam – und den, in dem nur die Ziffern
    // übrig sind.
    for (final zeile in lines) {
      for (final stueck in zeile) {
        nimm(stueck);
      }
    }

    return heraus;
  }

  /// Aus vielen Bruchstücken einer Lesung den einen Eimer finden.
  ///
  /// Ein Foto liefert immer mehr Text als den Code – Sorte, Datum,
  /// Gewicht, was der Imker sonst notiert hat. Deshalb wird jedes
  /// Bruchstück geprüft und erst am Ende entschieden:
  ///
  /// 1. Genau ein zeichengenauer Treffer → der ist es.
  /// 2. Mehrere zeichengenaue → zwei Eimer im Bild, also fragen.
  /// 3. Kein zeichengenauer, genau ein korrigierter → zur Bestätigung
  ///    zeigen.
  /// 4. Mehrere korrigierte oder mehrdeutige → zur Auswahl zeigen.
  ///
  /// Zeichengenau schlägt korrigiert, und das ist der Grund, warum eine
  /// mitfotografierte Zahl wie „17,2" (Wassergehalt) keinen Schaden
  /// anrichtet: Sie kann über die Ziffern-Stufe zwar auf Eimer 172 passen,
  /// verliert aber gegen den richtig gelesenen Code. Wird auch der Code
  /// nur ungenau gelesen, stehen beide gleichauf – dann wird gefragt,
  /// nicht geraten.
  static BucketCodeMatch matchAny(
      List<String> fragments, List<String> candidates) {
    if (candidates.isEmpty) return const BucketCodeMatch.none();

    final exakt = <String>[];
    final korrigiert = <String>[];
    final unklar = <String>[];

    void merke(List<String> liste, String code) {
      if (!liste.contains(code)) liste.add(code);
    }

    for (final bruchstueck in fragments) {
      final treffer = match(bruchstueck, candidates);
      if (treffer.confidence == BucketCodeConfidence.exact) {
        merke(exakt, treffer.code!);
      } else if (treffer.confidence == BucketCodeConfidence.corrected) {
        merke(korrigiert, treffer.code!);
      } else if (treffer.confidence == BucketCodeConfidence.ambiguous) {
        for (final kandidat in treffer.candidates) {
          merke(unklar, kandidat);
        }
      }
    }

    if (exakt.length == 1) {
      return BucketCodeMatch(
          code: exakt.first, confidence: BucketCodeConfidence.exact);
    }
    if (exakt.length > 1) {
      return BucketCodeMatch(
          candidates: exakt, confidence: BucketCodeConfidence.ambiguous);
    }
    if (korrigiert.length == 1) {
      return BucketCodeMatch(
          code: korrigiert.first, confidence: BucketCodeConfidence.corrected);
    }
    if (korrigiert.length > 1) {
      return BucketCodeMatch(
          candidates: korrigiert, confidence: BucketCodeConfidence.ambiguous);
    }
    if (unklar.isNotEmpty) {
      return BucketCodeMatch(
          candidates: unklar, confidence: BucketCodeConfidence.ambiguous);
    }
    return const BucketCodeMatch.none();
  }

  /// Taugt der Code als Eingabe von Hand? Prüft nur die Gestalt, nicht ob
  /// es den Eimer gibt.
  static bool isWellFormed(String raw) {
    final n = normalize(raw);
    final treffer = RegExp(r'^([A-Z]{2})(\d{1,4})$').firstMatch(n);
    if (treffer == null) return false;
    return HoneyVarieties.isKnown(treffer.group(1)!);
  }
}
