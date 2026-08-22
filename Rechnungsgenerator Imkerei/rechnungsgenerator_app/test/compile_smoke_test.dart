import 'package:flutter_test/flutter_test.dart';

// Importiert den kompletten App-Graphen. Dadurch übersetzt `flutter test`
// jede Bibliothek der App – ein Übersetzungsfehler in einem Screen fällt
// damit schon hier auf und nicht erst beim APK-Build.
import 'package:beebrain/main.dart';
import 'package:beebrain/models/models.dart';
import 'package:beebrain/screens/screens.dart';
import 'package:beebrain/services/services.dart';
import 'package:beebrain/utils/utils.dart';
import 'package:beebrain/utils/feedback_service.dart';
import 'package:beebrain/widgets/gradient_button.dart';
import 'package:beebrain/widgets/invoice_item_widget.dart';
import 'package:beebrain/widgets/invoice_layout_canvas.dart';
import 'package:beebrain/widgets/feedback_actions.dart';

void main() {
  test('App-Bibliotheken übersetzen und laden', () {
    // Je ein Symbol pro Ebene – hält die Imports „benutzt" und prüft,
    // dass die Bibliotheken tatsächlich initialisiert werden können.
    expect(const MyApp(), isNotNull);
    expect(const MainNavigationScreen(), isNotNull);
    expect(DatabaseService(), same(DatabaseService()));
    expect(InvoiceModel.invoiceStatuses, isNotEmpty);
    expect(AppUtils.formatDate(DateTime(2026, 8, 22)), '22.08.2026');
    expect(FeedbackService.screenObserver, isNotNull);
    expect(const FeedbackActions(), isNotNull);
    expect(const GradientButton(label: 'x'), isNotNull);
  });
}
