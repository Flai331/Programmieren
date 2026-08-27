import 'package:flutter_test/flutter_test.dart';
import 'package:imkerei_verwaltung/main.dart';

void main() {
  testWidgets('App startet ohne Fehler', (WidgetTester tester) async {
    await tester.pumpWidget(const ImkereiApp());
    expect(find.text('Imkerei Verwaltung'), findsWidgets);
  });
}
