import 'package:flutter_test/flutter_test.dart';
import 'package:beebrain/services/services.dart';

void main() {
  group('SyncService Tests (no-op stub)', () {
    late SyncService syncService;

    setUp(() {
      syncService = SyncService();
    });

    test('SyncService is singleton', () {
      final instance1 = SyncService();
      final instance2 = SyncService();
      expect(identical(instance1, instance2), true);
    });

    test('pendingSyncCount is always 0 (offline-only)', () {
      syncService.addToQueue(
        operation: 'CREATE',
        entityType: 'INVOICE',
        data: {'id': 'inv-001'},
      );
      expect(syncService.pendingSyncCount, 0);
    });

    test('isSyncing is always false', () {
      expect(syncService.isSyncing, false);
    });

    test('lastSyncTime is always null', () {
      expect(syncService.lastSyncTime, isNull);
    });

    test('addToQueue does not throw', () {
      expect(
        () => syncService.addToQueue(
          operation: 'CREATE',
          entityType: 'INVOICE',
          data: {'id': 'inv-001'},
        ),
        returnsNormally,
      );
    });

    test('syncAll completes without error', () async {
      await expectLater(syncService.syncAll(), completes);
    });

    test('clearQueue does not throw', () {
      expect(() => syncService.clearQueue(), returnsNormally);
    });
  });
}
