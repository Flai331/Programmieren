import 'package:flutter_test/flutter_test.dart';
import 'package:rechnungsgenerator_app/models/models.dart';

void main() {
  group('InvoiceItemModel Tests', () {
    test('InvoiceItemModel creation with valid data', () {
      final item = InvoiceItemModel(
        id: 'item-001',
        invoiceId: 'inv-001',
        description: 'Honig 500ml',
        quantity: 5,
        unit: 'Stück',
        price: 10.0,
        taxRate: 19.0,
        createdAt: DateTime.now(),
      );

      expect(item.id, 'item-001');
      expect(item.invoiceId, 'inv-001');
      expect(item.description, 'Honig 500ml');
      expect(item.quantity, 5);
      expect(item.unit, 'Stück');
      expect(item.price, 10.0);
      expect(item.taxRate, 19.0);
    });

    test('InvoiceItemModel.total calculation', () {
      final item = InvoiceItemModel(
        id: 'item-001',
        invoiceId: 'inv-001',
        description: 'Honig 500ml',
        quantity: 5,
        unit: 'Stück',
        price: 10.0,
        taxRate: 19.0,
        createdAt: DateTime.now(),
      );

      // Total should be quantity * price
      expect(item.total, 50.0);
    });

    test('InvoiceItemModel.total with decimal values', () {
      final item = InvoiceItemModel(
        id: 'item-001',
        invoiceId: 'inv-001',
        description: 'Wachskerze',
        quantity: 2.5,
        unit: 'Stück',
        price: 8.99,
        taxRate: 19.0,
        createdAt: DateTime.now(),
      );

      expect(item.total, closeTo(22.475, 0.01)); // 2.5 * 8.99
    });

    test('InvoiceItemModel.toMap() returns correct Map', () {
      final now = DateTime.now();
      final item = InvoiceItemModel(
        id: 'item-001',
        invoiceId: 'inv-001',
        description: 'Honig 500ml',
        quantity: 5,
        unit: 'Stück',
        price: 10.0,
        taxRate: 19.0,
        createdAt: now,
      );

      final map = item.toMap();

      expect(map['id'], 'item-001');
      expect(map['invoice_id'], 'inv-001');
      expect(map['description'], 'Honig 500ml');
      expect(map['quantity'], 5);
      expect(map['unit'], 'Stück');
      expect(map['price'], 10.0);
      expect(map['tax_rate'], 19.0);
    });

    test('InvoiceItemModel.fromMap() creates instance correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'item-001',
        'invoice_id': 'inv-001',
        'description': 'Honig 500ml',
        'quantity': 5.0,
        'unit': 'Stück',
        'price': 10.0,
        'tax_rate': 19.0,
        'created_at': now.toIso8601String(),
      };

      final item = InvoiceItemModel.fromMap(map);

      expect(item.id, 'item-001');
      expect(item.description, 'Honig 500ml');
      expect(item.quantity, 5.0);
      expect(item.total, 50.0);
    });

    test('InvoiceItemModel copyWith() creates new instance', () {
      final now = DateTime.now();
      final original = InvoiceItemModel(
        id: 'item-001',
        invoiceId: 'inv-001',
        description: 'Honig 500ml',
        quantity: 5,
        unit: 'Stück',
        price: 10.0,
        taxRate: 19.0,
        createdAt: now,
      );

      final updated = original.copyWith(
        quantity: 10,
        price: 12.0,
      );

      expect(updated.id, original.id); // Unchanged
      expect(updated.quantity, 10); // Changed
      expect(updated.price, 12.0); // Changed
      expect(updated.total, 120.0); // Recalculated
      expect(updated.description, original.description); // Unchanged
    });
  });
}
