import 'package:dokubox/update/updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Build-Nummer aus Release-Text', () {
    expect(parseBuild('Build 42\nZIP entpacken'), 42);
    expect(parseBuild('ohne'), isNull);
    expect(kBuildNumber, 0);
  });
}
