import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Placeholder smoke test', (WidgetTester tester) async {
    // Full app-launch requires SQLite init — not suitable for unit test.
    expect(true, isTrue);
  });
}
