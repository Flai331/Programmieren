import 'package:flutter_test/flutter_test.dart';
import 'package:beebrain/models/models.dart';

/// Regression zum Fehlerbericht vom 21.08.2026:
/// „bei bezahlt und Rechnungen werden 4 und 5 angezeigt, beim Draufklicken
/// sind es nur jeweils 3."
///
/// Ursache war u.a., dass Dashboard und Rechnungsliste Status unterschiedlich
/// zählten. Beide nutzen jetzt [InvoiceModel.normalizedStatus] – diese Tests
/// halten den gemeinsamen Vertrag fest.
InvoiceModel _doc({
  required String status,
  String documentType = 'invoice',
  double total = 119.0,
}) {
  final now = DateTime.now();
  return InvoiceModel(
    id: 'doc-1',
    invoiceNumber: 'RE-2026-001',
    companyId: 'company-1',
    customerId: 'customer-1',
    date: now,
    paymentTerms: 14,
    taxRate: 19.0,
    subtotal: 100.0,
    vat: 19.0,
    total: total,
    createdAt: now,
    status: status,
    documentType: documentType,
  );
}

void main() {
  group('InvoiceModel Status-Normalisierung', () {
    test('gültige Rechnungs-Status bleiben unverändert', () {
      for (final s in InvoiceModel.invoiceStatuses) {
        expect(_doc(status: s).normalizedStatus, s);
      }
    });

    test('gültige Angebots-Status bleiben unverändert', () {
      for (final s in InvoiceModel.quoteStatuses) {
        expect(
          _doc(status: s, documentType: 'quote').normalizedStatus,
          s,
        );
      }
    });

    test('typfremder Status einer Rechnung fällt auf Entwurf zurück', () {
      // Kann entstehen, wenn ein Angebot mit 'accepted' zur Rechnung wird.
      expect(_doc(status: 'accepted').normalizedStatus, 'draft');
      expect(_doc(status: 'rejected').normalizedStatus, 'draft');
    });

    test('unbekannter Status fällt auf Entwurf zurück', () {
      expect(_doc(status: 'irgendwas').normalizedStatus, 'draft');
      expect(_doc(status: '').normalizedStatus, 'draft');
    });

    test('statusOrder passt zum Dokumenttyp', () {
      expect(_doc(status: 'draft').statusOrder, InvoiceModel.invoiceStatuses);
      expect(
        _doc(status: 'draft', documentType: 'quote').statusOrder,
        InvoiceModel.quoteStatuses,
      );
    });

    test('normalizedStatus liegt immer in statusOrder', () {
      for (final type in ['invoice', 'quote']) {
        for (final s in ['draft', 'sent', 'paid', 'accepted', 'rejected', 'x']) {
          final d = _doc(status: s, documentType: type);
          expect(d.statusOrder, contains(d.normalizedStatus),
              reason: 'Typ $type, Status $s');
        }
      }
    });
  });

  group('Dashboard-Kacheln und Rechnungsliste zählen gleich', () {
    // Bildet die Zählung beider Screens nach: Das Dashboard summiert je
    // Status, die Liste filtert je Status-Chip. Beide müssen übereinstimmen.
    late List<InvoiceModel> docs;

    setUp(() {
      docs = [
        _doc(status: 'paid'),
        _doc(status: 'paid'),
        _doc(status: 'sent'),
        _doc(status: 'draft'),
        // Datensatz mit typfremdem Status – der eigentliche Auslöser
        _doc(status: 'accepted'),
        // Angebote dürfen bei den Rechnungen nicht mitzählen
        _doc(status: 'sent', documentType: 'quote'),
        _doc(status: 'accepted', documentType: 'quote'),
      ];
    });

    test('Summe der Status-Kacheln entspricht der Kachel „Rechnungen"', () {
      final invoices =
          docs.where((d) => d.documentType == 'invoice').toList();

      var paid = 0, sent = 0, draft = 0;
      for (final inv in invoices) {
        switch (inv.normalizedStatus) {
          case 'paid':
            paid++;
          case 'sent':
            sent++;
          default:
            draft++;
        }
      }

      expect(invoices.length, 5);
      expect(paid + sent + draft, invoices.length);
      expect(paid, 2);
      expect(sent, 1);
      expect(draft, 2); // 'draft' + der typfremde 'accepted'
    });

    test('Kachelwert entspricht der gefilterten Liste', () {
      final invoices =
          docs.where((d) => d.documentType == 'invoice').toList();

      // Dashboard-Weg: ein Durchlauf, Zähler je Status (wie in _load()).
      final ausKachel = {for (final s in InvoiceModel.invoiceStatuses) s: 0};
      for (final inv in invoices) {
        switch (inv.normalizedStatus) {
          case 'paid':
            ausKachel['paid'] = ausKachel['paid']! + 1;
          case 'sent':
            ausKachel['sent'] = ausKachel['sent']! + 1;
          default:
            ausKachel['draft'] = ausKachel['draft']! + 1;
        }
      }

      // Listen-Weg: je Status-Chip einmal filtern (wie im Rechnungs-Screen).
      for (final status in InvoiceModel.invoiceStatuses) {
        final ausListe =
            invoices.where((i) => i.normalizedStatus == status).length;
        expect(ausKachel[status], ausListe, reason: 'Status $status');
      }
    });

    test('Filter „alle" zeigt genauso viele wie die Kachel „Rechnungen"', () {
      final invoices =
          docs.where((d) => d.documentType == 'invoice').toList();
      final proStatus = InvoiceModel.invoiceStatuses
          .map((s) => invoices.where((i) => i.normalizedStatus == s).length)
          .fold<int>(0, (a, b) => a + b);
      expect(proStatus, invoices.length);
    });
  });
}
