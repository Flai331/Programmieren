import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/screen_time.dart';

void main() {
  test('unter einer Stunde nur Minuten', () {
    expect(formatUsage(const Duration(minutes: 47)), '47 min');
    expect(formatUsage(const Duration(minutes: 59, seconds: 59)), '59 min');
  });

  test('ab einer Stunde mit Stundenfeld', () {
    expect(formatUsage(const Duration(hours: 1, minutes: 23)), '1 h 23 min');
    expect(formatUsage(const Duration(hours: 2)), '2 h 0 min');
  });

  test('Nutzung wird aus der Karte gelesen', () {
    final nutzung = AppUsage.fromMap({
      'name': 'Chrome',
      'packageName': 'com.android.chrome',
      'millis': 90000,
    });

    expect(nutzung.name, 'Chrome');
    expect(nutzung.packageName, 'com.android.chrome');
    expect(nutzung.duration, const Duration(seconds: 90));
  });
}
