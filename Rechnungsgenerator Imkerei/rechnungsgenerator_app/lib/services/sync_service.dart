import 'package:flutter/material.dart';

/// No-Op-Stub seit BeeBrain offline-only ist.
/// Behält das Interface, damit existierende Aufrufer (`addToQueue`, ...) weiter funktionieren.
/// Bei späterem Cloud-Sync hier wieder echte Logik einsetzen.
class SyncQueueItem {
  final String id;
  final String operation;
  final String entityType;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.entityType,
    required this.data,
    required this.createdAt,
  });
}

class SyncService with ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  SyncService._internal();
  factory SyncService() => _instance;

  final List<SyncQueueItem> _syncQueue = const [];
  final bool _isSyncing = false;
  final DateTime? _lastSyncTime = null;
  final String? _lastSyncError = null;

  List<SyncQueueItem> get syncQueue => _syncQueue;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncError => _lastSyncError;
  int get pendingSyncCount => 0;

  void addToQueue({
    required String operation,
    required String entityType,
    required Map<String, dynamic> data,
  }) {
    // No-Op (offline-only)
  }

  Future<void> syncAll() async {}

  Future<void> syncInvoicesManual() async {}

  void clearQueue() {}

  void removeQueueItem(String id) {}
}
