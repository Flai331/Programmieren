import 'package:flutter/material.dart';
import 'dart:async';
import 'database_service.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import '../models/models.dart';
import '../utils/feedback_service.dart';

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
  final APIService _api = APIService();
  final ConnectivityService _connectivity = ConnectivityService();

  List<SyncQueueItem> _syncQueue = [];
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastSyncError;

  static final SyncService _instance = SyncService._internal();

  SyncService._internal() {
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
      FeedbackService.log('📡 Verbindung wiederhergestellt – Sync startet');
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
    FeedbackService.logEvent('SYNC_START',
        details: {'pending': _syncQueue.length.toString()});

    try {
      await _processSyncQueue();
      _lastSyncTime = DateTime.now();
      _lastSyncError = null;
      FeedbackService.logEvent('SYNC_SUCCESS');
    } catch (e) {
      _lastSyncError = e.toString();
      FeedbackService.logError(e.toString(), context: 'SyncAll');
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
        if (item.retryCount > 5) {
          _syncQueue.removeWhere((i) => i.id == item.id);
          FeedbackService.log(
              '⚠️ Sync-Item nach max. Versuchen entfernt: ${item.id}');
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
          FeedbackService.log('Unbekannte Sync-Operation: ${item.operation}');
          return false;
      }
    } catch (e) {
      FeedbackService.logError(e.toString(),
          context: 'SyncItem ${item.id}');
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
        FeedbackService.log('Unbekannter Entity-Typ: ${item.entityType}');
        return false;
    }
  }

  Future<bool> _syncUpdate(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'INVOICE':
        // TODO: API-Endpoint für Invoice-Update implementieren
        FeedbackService.log(
            '⚠️ Invoice-Update noch nicht implementiert (API fehlt)');
        return false;
      case 'CUSTOMER':
        // TODO: API-Endpoint für Customer-Update implementieren
        FeedbackService.log(
            '⚠️ Customer-Update noch nicht implementiert (API fehlt)');
        return false;
      case 'COMPANY':
        final company = CompanyModel.fromMap(item.data);
        return await _api.updateCompany(company);
      default:
        FeedbackService.log('Unbekannter Entity-Typ: ${item.entityType}');
        return false;
    }
  }

  Future<bool> _syncDelete(SyncQueueItem item) async {
    // TODO: DELETE-Endpoints im Backend implementieren
    FeedbackService.log('⚠️ DELETE-Sync noch nicht implementiert');
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
    FeedbackService.logEvent('SYNC_QUEUE_ADD',
        details: {'type': entityType, 'op': operation});

    if (_connectivity.isOnline) {
      syncAll();
    }
  }

  void clearQueue() {
    _syncQueue.clear();
    notifyListeners();
    FeedbackService.log('Sync-Queue geleert');
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
      FeedbackService.logDbOperation('UPDATE', 'invoices',
          id: invoiceId);
    }
  }

  Future<List<InvoiceModel>> getUnsyncedInvoices() async {
    return await _db.getUnsyncedInvoices();
  }

  // ============ MANUAL SYNC ============

  Future<void> syncInvoicesManual() async {
    if (_connectivity.isOffline) {
      _lastSyncError = 'Keine Internetverbindung';
      notifyListeners();
      FeedbackService.log('Sync abgebrochen: Offline');
      return;
    }

    try {
      _isSyncing = true;
      notifyListeners();

      final unsyncedInvoices = await getUnsyncedInvoices();
      if (unsyncedInvoices.isEmpty) {
        _lastSyncTime = DateTime.now();
        _lastSyncError = null;
        FeedbackService.log('Sync: Alle Rechnungen bereits synchronisiert');
        return;
      }

      final success = await _api.syncInvoices(unsyncedInvoices);
      if (success) {
        for (var invoice in unsyncedInvoices) {
          await markInvoiceSynced(invoice.id);
        }
        _lastSyncTime = DateTime.now();
        _lastSyncError = null;
        FeedbackService.logEvent('SYNC_INVOICES_SUCCESS',
            details: {'count': unsyncedInvoices.length.toString()});
      } else {
        _lastSyncError = 'Sync fehlgeschlagen';
        FeedbackService.logError('Sync fehlgeschlagen',
            context: 'syncInvoicesManual');
      }
    } catch (e) {
      _lastSyncError = e.toString();
      FeedbackService.logError(e.toString(), context: 'syncInvoicesManual');
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
