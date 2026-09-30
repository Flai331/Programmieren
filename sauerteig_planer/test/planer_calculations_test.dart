import 'package:flutter_test/flutter_test.dart';
import 'package:sauerteig_planer/planer/planer_calculations.dart';

void main() {
  group('planer_calculations', () {
    // Test 1: Regression 12h/22°C
    test('Regression: waehleFaktor(12, 22) must return 2.0, not 3.0', () {
      final factor = waehleFaktor(12, 22);
      expect(factor, equals(2.0),
          reason: 'At 22°C with 12h window, should select factor 2.0');
    });

    // Test 2: Invariante "Verhältnis passt ins Fenster"
    test('Invariante: timeFromFactor(waehleFaktor(w, t), t) <= w', () {
      final temperatures = [16.0, 18.0, 20.0, 22.0, 25.0, 28.0];
      final windows = List<int>.generate(26, (i) => i + 5); // 5 to 30

      for (final temp in temperatures) {
        for (final window in windows) {
          final w = window.toDouble();
          final f = waehleFaktor(w, temp);

          if (f != 1.0) {
            final timeNeeded = timeFromFactor(f, temp);
            expect(timeNeeded <= w, true,
                reason:
                    'Temp: ${temp}°C, Window: ${w}h, Factor: $f, TimeNeeded: ${timeNeeded.toStringAsFixed(2)}h');
          }
        }
      }
    });

    // Test 3: Monotonie
    test('Monotonie: waehleFaktor(w+1, 22) >= waehleFaktor(w, 22)', () {
      for (int w = 5; w < 30; w++) {
        final f1 = waehleFaktor(w.toDouble(), 22);
        final f2 = waehleFaktor((w + 1).toDouble(), 22);
        expect(f2 >= f1, true,
            reason:
                'Window $w: f=$f1, Window ${w + 1}: f=$f2. Should be monotonic non-decreasing.');
      }
    });
  });
}
