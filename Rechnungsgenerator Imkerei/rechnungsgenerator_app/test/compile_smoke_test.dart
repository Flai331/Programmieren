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
    expect(InvoiceItemWidget, isNotNull);
    expect(const ElementPos(x: 0, y: 0, w: 1, h: 1).x, 0);
    expect(HiveActionTypes.all, isNotEmpty);
    expect(const BeeYearScreen(), isNotNull);
    expect(const SeasonScreen(), isNotNull);
    expect(SeasonCatalog.tasks, isNotEmpty);
    expect(SeasonService(), isNotNull);
    expect(const ReportListScreen(), isNotNull);
    expect(const ImportScreen(), isNotNull);
    expect(ImportRunner(), isNotNull);
    // Lager – prüft zugleich, dass die Screens aus dem Barrel kommen.
    expect(const HoneyStockScreen(), isNotNull);
    expect(const HoneyBucketNewScreen(), isNotNull);
    expect(const StockScreen(), isNotNull);
    expect(const StockItemScreen(), isNotNull);
    expect(HoneyService(), isNotNull);
    expect(StockService(), isNotNull);
    expect(HoneyStates.all, isNotEmpty);
    // Texterkennung: nur anlegen, nicht benutzen – das native Modell gibt
    // es im Test nicht. Geprüft ist damit, dass die Bibliothek übersetzt
    // und über das Barrel erreichbar ist.
    expect(BucketScanService(), isNotNull);
    expect(const BucketScanReading.empty().isEmpty, isTrue);
    expect(StockCategories.all, isNotEmpty);
    // Anpassbare Verzeichnisse: Bildschirm und Dienst kommen aus dem Barrel.
    expect(const CatalogScreen(), isNotNull);
    expect(
        const CatalogEntriesScreen(catalog: Catalogs.honeyState), isNotNull);
    expect(PersonalizationService(), same(PersonalizationService()));
    // Wärmeschrank-Meldung: Dienst erreichbar, Kanalname wie im Kotlin.
    expect(WarmerAlarms(), same(WarmerAlarms()));
    expect(WarmerAlarms.channel.name, 'beebrain/warmer');
    expect(Catalogs.all, isNotEmpty);
    // Aktualisierung: Der Dienst lässt sich anlegen, ohne das Netz
    // anzufassen – geprüft wird nur, dass er über das Barrel erreichbar ist
    // und übersetzt. Das Nachsehen selbst prüft update_service_test.dart.
    expect(UpdateService(), isNotNull);
    expect(UpdateService.releaseUrl, startsWith('https://api.github.com/'));
  });
}
