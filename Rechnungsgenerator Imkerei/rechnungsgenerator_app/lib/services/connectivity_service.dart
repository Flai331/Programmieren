import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  static final ConnectivityService _instance = ConnectivityService._internal();

  ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  Future<void> initialize() async {
    try {
      _updateConnectionStatus(await _connectivity.checkConnectivity());

      // Listen to connectivity changes
      _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (_) {
          // Windows NetworkManager-Bug ignorieren — Default: online
          _isOnline = true;
        },
      );
    } catch (_) {
      // Windows NetworkManager::StartListen wirft → online annehmen
      _isOnline = true;
    }
  }

  /// Ab connectivity_plus 7 liefert die Abfrage eine Liste: Ein Gerät kann
  /// über mehrere Wege gleichzeitig verbunden sein (z.B. WLAN und Mobilfunk).
  /// Online ist es, sobald mindestens ein Weg taugt.
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    // Notify listeners if connection status changed
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  Future<bool> checkConnection() async {
    try {
      _updateConnectionStatus(await _connectivity.checkConnectivity());
    } catch (_) {
      _isOnline = true;
    }
    return _isOnline;
  }
}
