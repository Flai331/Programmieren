// Dubletten-Erkennung über Textähnlichkeit (Wort-Trigramme, Jaccard).

Set<String> _trigrams(String text) {
  final words = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zäöüß0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1)
      .toList();
  return {
    for (var i = 0; i + 2 < words.length; i++)
      '${words[i]} ${words[i + 1]} ${words[i + 2]}',
  };
}

/// Ähnlichkeit zweier OCR-Texte zwischen 0 und 1.
double textSimilarity(String a, String b) {
  final ta = _trigrams(a), tb = _trigrams(b);
  if (ta.length < 5 || tb.length < 5) return 0;
  final inter = ta.intersection(tb).length;
  return inter / (ta.length + tb.length - inter);
}

/// Ab hier gilt ein Text als (fast) gleich – OCR-Abweichungen inklusive.
const kDuplicateSimilarity = 0.85;
