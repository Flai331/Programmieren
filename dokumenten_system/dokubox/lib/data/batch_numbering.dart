/// Reihenfolge für die Nummernvergabe eines Stapels: nach Dokumentdatum,
/// ältestes zuerst; ohne Datum ans Ende. Bei gleichem (oder fehlendem)
/// Datum bleibt die Reihenfolge im Stapel erhalten (stabil).
List<T> sortForNumbering<T>(List<T> items, DateTime? Function(T) dateOf) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final da = dateOf(a.$2);
    final db = dateOf(b.$2);
    if (da == null && db == null) return a.$1.compareTo(b.$1);
    if (da == null) return 1;
    if (db == null) return -1;
    // Nur der Tag zählt (Uhrzeit aus OCR ist Zufall).
    final c = DateTime(da.year, da.month, da.day)
        .compareTo(DateTime(db.year, db.month, db.day));
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
