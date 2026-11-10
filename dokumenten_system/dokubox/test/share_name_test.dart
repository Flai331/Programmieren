import 'package:dokubox/ui/share_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dateiname zum Versenden wird bereinigt', () {
    expect(safePdfFileName('Antrag Beihilfe – Müller'),
        'Antrag Beihilfe – Müller.pdf');
    expect(safePdfFileName('Antrag.pdf'), 'Antrag.pdf');
    expect(safePdfFileName('Antrag.PDF'), 'Antrag.pdf');
    expect(safePdfFileName('a/b:c*d?"e"<f>|g'), 'a b c d e f g.pdf');
    expect(safePdfFileName('   '), 'Dokument.pdf');
    expect(safePdfFileName('...', fallback: '2026-0001'), '2026-0001.pdf');
    expect(safePdfFileName('x' * 300).length, 104);
  });

  test('Vorschlag aus Nummer, Titel, „ausgefüllt“', () {
    expect(suggestedShareName('2026-0042', 'Antrag', filled: true),
        '2026-0042 Antrag ausgefüllt');
    expect(suggestedShareName('2026-0042', ''), '2026-0042');
  });
}
