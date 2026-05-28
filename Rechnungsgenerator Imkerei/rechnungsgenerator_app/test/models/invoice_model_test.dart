import 'package:flutter_test/flutter_test.dart';
import 'package:beebrain/models/models.dart';

void main() {
  group('InvoiceModel Tests', () {
    test('InvoiceModel creation with valid data', () {
      final now = DateTime.now();
      final invoice = InvoiceModel(
        id: 'inv-001',
        invoiceNumber: 'RG-2026-001',
        companyId: 'company-001',
        customerId: 'customer-001',
        date: now,
        paymentTerms: 14,
        additionalInfo: 'Test invoice',
        taxRate: 19.0,
        subtotal: 100.0,
        vat: 19.0,
        total: 119.0,
        createdAt: now,
        updatedAt: now,
        synced: false,
      );

      expect(invoice.id, 'inv-001');
      expect(invoice.invoiceNumber, 'RG-2026-001');
      expect(invoice.companyId, 'company-001');
      expect(invoice.customerId, 'customer-001');
      expect(invoice.date, now);
      expect(invoice.paymentTerms, 14);
      expect(invoice.additionalInfo, 'Test invoice');
      expect(invoice.taxRate, 19.0);
      expect(invoice.subtotal, 100.0);
      expect(invoice.vat, 19.0);
      expect(invoice.total, 119.0);
      expect(invoice.synced, false);
    });

    test('InvoiceModel.toMap() returns correct Map', () {
      final now = DateTime.now();
      final invoice = InvoiceModel(
        id: 'inv-001',
        invoiceNumber: 'RG-2026-001',
        companyId: 'company-001',
        customerId: 'customer-001',
        date: now,
        paymentTerms: 14,
        additionalInfo: null,
        taxRate: 19.0,
        subtotal: 100.0,
        vat: 19.0,
        total: 119.0,
        createdAt: now,
        updatedAt: now,
        synced: false,
      );

      final map = invoice.toMap();

      expect(map['id'], 'inv-001');
      expect(map['invoice_number'], 'RG-2026-001');
      expect(map['company_id'], 'company-001');
      expect(map['customer_id'], 'customer-001');
      expect(map['subtotal'], 100.0);
      expect(map['vat'], 19.0);
      expect(map['total'], 119.0);
      expect(map['synced'], 0); // false converts to 0
    });

    test('InvoiceModel.fromMap() creates instance correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'inv-001',
        'invoice_number': 'RG-2026-001',
        'company_id': 'company-001',
        'customer_id': 'customer-001',
        'date': now.toIso8601String(),
        'payment_terms': 14,
        'additional_info': 'Test',
        'tax_rate': 19.0,
        'subtotal': 100.0,
        'vat': 19.0,
        'total': 119.0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'synced': 1,
      };

      final invoice = InvoiceModel.fromMap(map);

      expect(invoice.id, 'inv-001');
      expect(invoice.invoiceNumber, 'RG-2026-001');
      expect(invoice.taxRate, 19.0);
      expect(invoice.subtotal, 100.0);
      expect(invoice.synced, true); // 1 converts to true
    });

    test('InvoiceModel copyWith() creates new instance with updated fields', () {
      final now = DateTime.now();
      final original = InvoiceModel(
        id: 'inv-001',
        invoiceNumber: 'RG-2026-001',
        companyId: 'company-001',
        customerId: 'customer-001',
        date: now,
        paymentTerms: 14,
        additionalInfo: null,
        taxRate: 19.0,
        subtotal: 100.0,
        vat: 19.0,
        total: 119.0,
        createdAt: now,
        updatedAt: now,
        synced: false,
      );

      final updated = original.copyWith(
        invoiceNumber: 'RG-2026-002',
        total: 150.0,
        synced: true,
      );

      expect(updated.id, original.id); // Unchanged
      expect(updated.invoiceNumber, 'RG-2026-002'); // Changed
      expect(updated.total, 150.0); // Changed
      expect(updated.synced, true); // Changed
      expect(updated.companyId, original.companyId); // Unchanged
    });

    test('InvoiceModel with null additionalInfo', () {
      final now = DateTime.now();
      final invoice = InvoiceModel(
        id: 'inv-001',
        invoiceNumber: 'RG-2026-001',
        companyId: 'company-001',
        customerId: 'customer-001',
        date: now,
        paymentTerms: 14,
        additionalInfo: null,
        taxRate: 19.0,
        subtotal: 100.0,
        vat: 19.0,
        total: 119.0,
        createdAt: now,
        updatedAt: now,
        synced: false,
      );

      expect(invoice.additionalInfo, isNull);
      final map = invoice.toMap();
      expect(map['additional_info'], isNull);
    });
  });
}
