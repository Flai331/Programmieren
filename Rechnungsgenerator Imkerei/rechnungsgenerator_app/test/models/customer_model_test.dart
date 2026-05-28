import 'package:flutter_test/flutter_test.dart';
import 'package:beebrain/models/models.dart';

void main() {
  group('CustomerModel Tests', () {
    test('CustomerModel creation with valid data', () {
      final now = DateTime.now();
      final customer = CustomerModel(
        id: 'cust-001',
        name: 'Müller GmbH',
        street: 'Hauptstraße 42',
        zipcode: '10115',
        city: 'Berlin',
        phone: '+49 30 123456',
        email: 'info@mueller.de',
        createdAt: now,
        updatedAt: now,
      );

      expect(customer.id, 'cust-001');
      expect(customer.name, 'Müller GmbH');
      expect(customer.street, 'Hauptstraße 42');
      expect(customer.zipcode, '10115');
      expect(customer.city, 'Berlin');
      expect(customer.phone, '+49 30 123456');
      expect(customer.email, 'info@mueller.de');
    });

    test('CustomerModel.toMap() returns correct Map', () {
      final now = DateTime.now();
      final customer = CustomerModel(
        id: 'cust-001',
        name: 'Müller GmbH',
        street: 'Hauptstraße 42',
        zipcode: '10115',
        city: 'Berlin',
        phone: '+49 30 123456',
        email: 'info@mueller.de',
        createdAt: now,
        updatedAt: now,
      );

      final map = customer.toMap();

      expect(map['id'], 'cust-001');
      expect(map['name'], 'Müller GmbH');
      expect(map['street'], 'Hauptstraße 42');
      expect(map['zipcode'], '10115');
      expect(map['city'], 'Berlin');
      expect(map['phone'], '+49 30 123456');
      expect(map['email'], 'info@mueller.de');
    });

    test('CustomerModel.fromMap() creates instance correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'cust-001',
        'name': 'Müller GmbH',
        'street': 'Hauptstraße 42',
        'zipcode': '10115',
        'city': 'Berlin',
        'phone': '+49 30 123456',
        'email': 'info@mueller.de',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final customer = CustomerModel.fromMap(map);

      expect(customer.id, 'cust-001');
      expect(customer.name, 'Müller GmbH');
      expect(customer.email, 'info@mueller.de');
    });

    test('CustomerModel copyWith() creates new instance', () {
      final now = DateTime.now();
      final original = CustomerModel(
        id: 'cust-001',
        name: 'Müller GmbH',
        street: 'Hauptstraße 42',
        zipcode: '10115',
        city: 'Berlin',
        phone: '+49 30 123456',
        email: 'info@mueller.de',
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        street: 'Neue Straße 10',
        city: 'München',
      );

      expect(updated.id, original.id); // Unchanged
      expect(updated.street, 'Neue Straße 10'); // Changed
      expect(updated.city, 'München'); // Changed
      expect(updated.name, original.name); // Unchanged
    });
  });
}
