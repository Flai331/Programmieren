import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  late ConnectivityResult _lastResult;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  static final ConnectivityService _instance = ConnectivityService._internal();

  ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _lastResult = result;
    _updateConnectionStatus(result);

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _lastResult = result;
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    // Notify listeners if connection status changed
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  Future<bool> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    _lastResult = result;
    _updateConnectionStatus(result);
    return _isOnline;
  }
}
