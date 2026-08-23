import 'package:flutter_test/flutter_test.dart';
import 'package:beebrain/utils/feedback_service.dart';

/// Die Zieladresse für Fehlerberichte ist eine bewusste Festlegung und
/// soll nicht versehentlich durch eine private Adresse ersetzt werden.
void main() {
  test('Fehlerberichte gehen an die Support-Adresse', () {
    expect(FeedbackService.supportEmail, 'error.404.found@outlook.de');
  });

  test('Zustellwege sind Mail und Teilen', () {
    expect(FeedbackDelivery.values,
        containsAll([FeedbackDelivery.mail, FeedbackDelivery.share]));
  });
}
