import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/bucket_code.dart';
import '../utils/feedback_service.dart';

/// Was eine Kamera-Lesung ergeben hat.
class BucketScanReading {
  /// Der ganze erkannte Text, Zeile für Zeile verbunden. Nur zum Anzeigen,
  /// wenn nichts getroffen wurde – damit der Imker sieht, was die Kamera
  /// gelesen hat, statt nur „nicht erkannt" zu lesen.
  final String rawText;

  /// Die Bruchstücke, geordnet von der aussichtsreichsten Zusammensetzung
  /// zur dürftigsten. Siehe [BucketCode.fragments].
  final List<String> fragments;

  /// Hat die Erkennung überhaupt etwas gefunden?
  bool get isEmpty => fragments.isEmpty;

  const BucketScanReading({required this.rawText, required this.fragments});

  const BucketScanReading.empty()
      : rawText = '',
        fragments = const [];
}

/// Handschrift vom Eimer lesen.
///
/// Die einzige Stelle der App, die die Texterkennung anfasst. Das ist
/// Absicht: Die native Abhängigkeit (ML Kit) steckt in diesem einen
/// Dienst, und der Abgleich dahinter ([BucketCode.matchAny]) ist reines
/// Dart. Bricht die Erkennung weg, bleibt das Lager vollständig
/// benutzbar – der Code lässt sich immer eintippen.
///
/// Erkannt wird mit dem lateinischen Modell, das im Paket steckt. Es
/// braucht kein Netz, und das ist hier der Punkt: Im Honigraum oder im
/// Keller gibt es keins.
class BucketScanService {
  /// Nur das lateinische Modell liegt dem Paket bei; die anderen Schriften
  /// sind `compileOnly` und wären zur Laufzeit nicht da.
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Ein Foto lesen und in Bruchstücke zerlegen.
  ///
  /// Wirft nicht: Eine fehlgeschlagene Erkennung ist kein Fehler, den der
  /// Imker ausbaden soll – sie führt zur Tastatur.
  Future<BucketScanReading> read(String imagePath) async {
    try {
      final erkannt =
          await _recognizer.processImage(InputImage.fromFilePath(imagePath));

      // Von der Baumstruktur der Erkennung bleibt nur, was der Abgleich
      // braucht: je Zeile die einzelnen Stücke. Ein handgeschriebenes
      // `SO-042` kommt je nach Schrift als ein Stück, als zwei oder als
      // drei an – darum zählt die Gliederung, nicht der Fließtext.
      final zeilen = <List<String>>[];
      for (final block in erkannt.blocks) {
        for (final zeile in block.lines) {
          final stuecke = <String>[];
          for (final element in zeile.elements) {
            final text = element.text.trim();
            if (text.isNotEmpty) stuecke.add(text);
          }
          // Rückfall auf die ganze Zeile: Kommt die Erkennung ohne
          // Gliederung zurück, ist der Zeilentext alles, was es gibt.
          if (stuecke.isEmpty && zeile.text.trim().isNotEmpty) {
            stuecke.add(zeile.text.trim());
          }
          if (stuecke.isNotEmpty) zeilen.add(stuecke);
        }
      }

      final bruchstuecke = BucketCode.fragments(zeilen);
      FeedbackService.logEvent('Eimer-Code gelesen', details: {
        'Zeilen': zeilen.length.toString(),
        'Bruchstücke': bruchstuecke.length.toString(),
      });
      return BucketScanReading(
        rawText: erkannt.text.trim(),
        fragments: bruchstuecke,
      );
    } catch (e, s) {
      FeedbackService.logError('Texterkennung fehlgeschlagen: $e',
          context: 'BucketScanService.read', stackTrace: s);
      return const BucketScanReading.empty();
    }
  }

  /// Die Erkennung freigeben. Sie hält natives Gerät – ein offener
  /// Erkenner nach dem Verlassen des Bildschirms wäre ein Leck.
  Future<void> dispose() async {
    try {
      await _recognizer.close();
    } catch (_) {
      // Beim Aufräumen ist ein Fehlschlag ohne Folgen.
    }
  }
}
