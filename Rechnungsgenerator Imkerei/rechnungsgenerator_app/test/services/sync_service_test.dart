import 'package:flutter_test/flutter_test.dart';
import 'package:rechnungsgenerator_app/services/services.dart';

void main() {
  group('SyncService Tests', () {
    late SyncService syncService;

    setUp(() {
      syncService = SyncService();
    });

    test('SyncService is singleton', () {
      final instance1 = SyncService();
      final instance2 = SyncService();

      expect(identical(instance1, instance2), true);
    });

    test('addToQueue adds operation to sync queue', () {
      final beforeCount = syncService.pendingSyncCount;

      syncService.addToQueue(
        operation: 'CREATE',
        entityType: 'INVOICE',
        data: {'id': 'inv-001', 'number': 'RG-2026-001'},
      );

      final afterCount = syncService.pendingSyncCount;
      expect(afterCount, greaterThan(beforeCount));
    });

    test('addToQueue with multiple operations', () {
      final beforeCount = syncService.pendingSyncCount;

      syncService.addToQueue(
        operation: 'CREATE',
        entityType: 'INVOICE',
        data: {'id': 'inv-001'},
      );

      syncService.addToQueue(
        operation: 'CREATE',
        entityType: 'CUSTOMER',
        data: {'id': 'cust-001'},
      );

      final afterCount = syncService.pendingSyncCount;
      expect(afterCount, greaterThanOrEqualTo(beforeCount + 2));
    });

    test('pendingSyncCount returns queue size', () {
      final beforeCount = syncService.pendingSyncCount;

      syncService.addToQueue(
        operation: 'UPDATE',
        entityType: 'INVOICE',
        data: {'id': 'inv-001'},
      );

      final afterCount = syncService.pendingSyncCount;
      expect(afterCount, greaterThanOrEqualTo(beforeCount + 1));
    });

    test('isSyncing getter returns boolean', () {
      final isSyncing = syncService.isSyncing;

      expect(isSyncing, isA<bool>());
    });

    test('lastSyncTime getter returns nullable DateTime', () {
      final lastSyncTime = syncService.lastSyncTime;

      expect(lastSyncTime, anyOf(isNull, isA<DateTime>()));
    });

    test('addToQueue with different entity types', () {
      final beforeCount = syncService.pendingSyncCount;
      final entityTypes = ['INVOICE', 'CUSTOMER', 'COMPANY', 'DESIGN_SETTINGS'];

      for (final entityType in entityTypes) {
        syncService.addToQueue(
          operation: 'CREATE',
          entityType: entityType,
          data: {'id': 'test-id'},
        );
      }

      final afterCount = syncService.pendingSyncCount;
      expect(afterCount, greaterThanOrEqualTo(beforeCount + entityTypes.length));
    });

    test('addToQueue with different operations', () {
      final beforeCount = syncService.pendingSyncCount;
      final operations = ['CREATE', 'UPDATE', 'DELETE'];

      for (final operation in operations) {
        syncService.addToQueue(
          operation: operation,
          entityType: 'INVOICE',
          data: {'id': 'test-id'},
        );
      }

      final afterCount = syncService.pendingSyncCount;
      expect(afterCount, greaterThanOrEqualTo(beforeCount + operations.length));
    });
  });
}
