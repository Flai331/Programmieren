/// Die Namen der Einträge in `app_settings`.
///
/// Eine eigene Datei ohne Abhängigkeiten, damit sowohl der
/// `PersonalizationService` als auch die Datenbank-Migrationen sie benutzen
/// können, ohne sich gegenseitig zu importieren.
///
/// Als Konstanten, weil sie in der Datenbank stehen: ein Tippfehler im Namen
/// wäre eine stille Rückkehr zur Vorgabe.
library;

/// Die Namen der einstellbaren Zahlen.
class AppNumbers {
  /// Stunden im Wärmeschrank beim ersten Mal.
  static const String warmerFirstHours = 'waermeschrank_erst_h';

  /// Stunden, wenn der Eimer schon einmal drin war.
  static const String warmerRepeatHours = 'waermeschrank_wieder_h';
}

/// Die Namen der einstellbaren Texte. Siehe [AppNumbers].
class AppTexts {
  /// Die Format-Vorlage für Rechnungsnummern.
  ///
  /// Lag bis v8 als Spalte an der Firma. Das war der falsche Ort: ohne
  /// angelegte Firmendaten war das Format nicht einzustellen – die Karte in
  /// den Einstellungen zeigte dann ein Rädchen, das sich nie wieder
  /// beruhigte –, und jedes Speichern der Firmendaten setzte es still
  /// zurück, weil der Firmen-Bildschirm die Firma ohne das Format neu
  /// aufbaute. Eine App-Einstellung gehört in die App-Einstellungen.
  static const String invoiceNumberPattern = 'rechnungsnummer_format';
}
