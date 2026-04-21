import 'package:flutter/material.dart';
import 'dart:async';
import 'database_service.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import '../models/models.dart';

class SyncQueueItem {
  final String id;
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final String entityType; // 'INVOICE', 'CUSTOMER', 'COMPANY', etc.
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;

  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.entityType,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });
}

class SyncService with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final ApiService _api = APIService();
  final ConnectivityService _connectivity = ConnectivityService();

  List<SyncQueueItem> _syncQueue = [];
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastSyncError;

  static final SyncService _instance = SyncService._internal();

  SyncService._internal() {
    // Listen to connectivity changes
    _connectivity.addListener(_onConnectivityChanged);
  }

  factory SyncService() {
    return _instance;
  }

  // Getters
  List<SyncQueueItem> get syncQueue => _syncQueue;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncError => _lastSyncError;
  int get pendingSyncCount => _syncQueue.length;

  void _onConnectivityChanged() {
    if (_connectivity.isOnline && _syncQueue.isNotEmpty) {
      print('📡 Internet connection restored, attempting sync...');
      syncAll();
    }
  }

  // ============ SYNC OPERATIONS ============

  Future<void> syncAll() async {
    if (_isSyncing || _syncQueue.isEmpty || _connectivity.isOffline) {
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      await _processSyncQueue();
      _lastSyncTime = DateTime.now();
      _lastSyncError = null;
    } catch (e) {
      _lastSyncError = e.toString();
      print('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _processSyncQueue() async {
    final queue = List<SyncQueueItem>.from(_syncQueue);

    for (var item in queue) {
      final success = await _syncItem(item);
      if (success) {
        _syncQueue.removeWhere((i) => i.id == item.id);
        notifyListeners();
      } else {
        item.retryCount++;
        // Keep in queue for retry
        if (item.retryCount > 5) {
          // Remove after 5 retries
          _syncQueue.removeWhere((i) => i.id == item.id);
          print('⚠️ Sync item removed after max retries: ${item.id}');
        }
        notifyListeners();
      }
    }
  }

  Future<bool> _syncItem(SyncQueueItem item) async {
    try {
      switch (item.operation) {
        case 'CREATE':
          return await _syncCreate(item);
        case 'UPDATE':
          return await _syncUpdate(item);
        case 'DELETE':
          return await _syncDelete(item);
        default:
          return false;
      }
    } catch (e) {
      print('Error syncing item ${item.id}: $e');
      return false;
    }
  }

  Future<bool> _syncCreate(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'INVOICE':
        final invoice = InvoiceModel.fromMap(item.data);
        return await _api.createInvoice(invoice);
      case 'CUSTOMER':
        final customer = CustomerModel.fromMap(item.data);
        return await _api.createCustomer(customer);
      case 'COMPANY':
        final company = CompanyModel.fromMap(item.data);
        return await _api.createCompany(company);
      default:
        return false;
    }
  }

  Future<bool> _syncUpdate(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'INVOICE':
        final invoice = InvoiceModel.fromMap(item.data);
        return await _api.updateCompany(CompanyModel.fromMap(item.data));
      case 'CUSTOMER':
        // API would have updateCustomer endpoint
        return false;
      case 'COMPANY':
        final company = CompanyModel.fromMap(item.data);
        return await _api.updateCompany(company);
      default:
        return false;
    }
  }

  Future<bool> _syncDelete(SyncQueueItem item) async {
    // TODO: Implement DELETE endpoints in API
    return false;
  }

  // ============ QUEUE MANAGEMENT ============

  void addToQueue({
    required String operation,
    required String entityType,
    required Map<String, dynamic> data,
  }) {
    final item = SyncQueueItem(
      id: '${entityType}_${operation}_${DateTime.now().millisecondsSinceEpoch}',
      operation: operation,
      entityType: entityType,
      data: data,
      createdAt: DateTime.now(),
    );

    _syncQueue.add(item);
    notifyListeners();

    // Try sync if online
    if (_connectivity.isOnline) {
      syncAll();
    }
  }

  void clearQueue() {
    _syncQueue.clear();
    notifyListeners();
  }

  void removeQueueItem(String id) {
    _syncQueue.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // ============ INVOICE SYNC ============

  Future<void> markInvoiceSynced(String invoiceId) async {
    final invoice = await _db.getInvoice(invoiceId);
    if (invoice != null) {
      final syncedInvoice = invoice.copyWith(synced: true);
      await _db.updateInvoice(syncedInvoice);
    }
  }

  Future<List<InvoiceModel>> getUnsyncedInvoices() async {
    return await _db.getUnsyncedInvoices();
  }

  // ============ MANUAL SYNC OPERATIONS ============

  Future<void> syncInvoicesManual() async {
    if (_connectivity.isOffline) {
      _lastSyncError = 'No internet connection';
      notifyListeners();
      return;
    }

    try {
      _isSyncing = true;
      notifyListeners();

      final unsyncedInvoices = await getUnsyncedInvoices();
      if (unsyncedInvoices.isEmpty) {
        _lastSyncTime = DateTime.now();
        _lastSyncError = null;
        return;
      }

      final success = await _api.syncInvoices(unsyncedInvoices);
      if (success) {
        for (var invoice in unsyncedInvoices) {
          await markInvoiceSynced(invoice.id);
        }
        _lastSyncTime = DateTime.now();
        _lastSyncError = null;
        print('✅ Synced ${unsyncedInvoices.length} invoices');
      } else {
        _lastSyncError = 'Sync failed';
      }
    } catch (e) {
      _lastSyncError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
