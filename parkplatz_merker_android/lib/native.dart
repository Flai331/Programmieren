import 'package:flutter/services.dart';

class NativeBridge {
  static const _channel = MethodChannel('parkplatz_merker/native');

  /// Holt alle Rohereignisse ab und leert das Journal.
  static Future<List<String>> drainEvents() async {
    try {
      final result = await _channel.invokeMethod('drainEvents');
      if (result is List) {
        return List<String>.from(
          result.cast<Object?>().map((e) => e.toString()),
        );
      }
      return [];
    } on PlatformException catch (e) {
      print('drainEvents error: ${e.message}');
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  /// Holt die aktuelle Konfiguration ab.
  static Future<Map<String, dynamic>> getConfig() async {
    try {
      final result = await _channel.invokeMethod('getConfig');
      if (result is Map<Object?, Object?>) {
        return Map<String, dynamic>.from(result);
      }
      return {
        'activityEnabled': true,
        'chargerEnabled': true,
        'deviceMode': 'none',
        'deviceAddress': null,
        'deviceName': null,
      };
    } on PlatformException catch (e) {
      print('getConfig error: ${e.message}');
      return {
        'activityEnabled': true,
        'chargerEnabled': true,
        'deviceMode': 'none',
        'deviceAddress': null,
        'deviceName': null,
      };
    } on MissingPluginException {
      return {
        'activityEnabled': true,
        'chargerEnabled': true,
        'deviceMode': 'none',
        'deviceAddress': null,
        'deviceName': null,
      };
    }
  }

  /// Setzt die Konfiguration.
  static Future<void> setConfig({
    bool? activityEnabled,
    bool? chargerEnabled,
    String? deviceMode,
    String? deviceAddress,
    String? deviceName,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (activityEnabled != null) params['activityEnabled'] = activityEnabled;
      if (chargerEnabled != null) params['chargerEnabled'] = chargerEnabled;
      if (deviceMode != null) params['deviceMode'] = deviceMode;
      if (deviceAddress != null) params['deviceAddress'] = deviceAddress;
      if (deviceName != null) params['deviceName'] = deviceName;
      await _channel.invokeMethod('setConfig', params);
    } on PlatformException catch (e) {
      print('setConfig error: ${e.message}');
    } on MissingPluginException {
      print('setConfig: platform not available');
    }
  }

  /// Registriert Aktivitätsübergänge.
  static Future<Map<String, dynamic>> registerTransitions() async {
    try {
      final result = await _channel.invokeMethod('registerTransitions');
      if (result is Map<Object?, Object?>) {
        return Map<String, dynamic>.from(result);
      }
      return {'ok': false, 'error': 'Unerwartetes Format'};
    } on PlatformException catch (e) {
      return {'ok': false, 'error': e.message};
    } on MissingPluginException {
      return {'ok': false, 'error': 'Platform nicht verfügbar'};
    }
  }

  /// Holt den aktuellen Standort (hohe Genauigkeit, max. 30 s).
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      final result = await _channel.invokeMethod('getCurrentLocation');
      if (result is Map<Object?, Object?>) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('getCurrentLocation error: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Holt den letzten bekannten Standort (schnell).
  static Future<Map<String, dynamic>?> getLastLocation() async {
    try {
      final result = await _channel.invokeMethod('getLastLocation');
      if (result is Map<Object?, Object?>) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('getLastLocation error: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Macht eine Reverse-Geocoding-Anfrage.
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final result = await _channel.invokeMethod('reverseGeocode', {
        'lat': lat,
        'lng': lng,
      });
      return result is String ? result : null;
    } on PlatformException catch (e) {
      print('reverseGeocode error: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Öffnet die Navigationsziele (Google Maps).
  static Future<bool> openNavigation(double lat, double lng) async {
    try {
      final result = await _channel.invokeMethod('openNavigation', {
        'lat': lat,
        'lng': lng,
      });
      return result is bool ? result : false;
    } on PlatformException catch (e) {
      print('openNavigation error: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Startet die Gerätesuche.
  static Future<Map<String, dynamic>> startDeviceSearch() async {
    try {
      final result = await _channel.invokeMethod('startDeviceSearch');
      if (result is Map<Object?, Object?>) {
        return Map<String, dynamic>.from(result);
      }
      return {'ok': false, 'error': 'Unerwartetes Format'};
    } on PlatformException catch (e) {
      return {'ok': false, 'error': e.message};
    } on MissingPluginException {
      return {'ok': false, 'error': 'Platform nicht verfügbar'};
    }
  }

  /// Holt die Suchtergebnisse.
  static Future<Map<String, dynamic>> getSearchResults() async {
    try {
      final result = await _channel.invokeMethod('getSearchResults');
      if (result is Map<Object?, Object?>) {
        final map = Map<String, dynamic>.from(result);
        if (map['devices'] is List) {
          map['devices'] = List<Map<String, dynamic>>.from(
            (map['devices'] as List).map((d) {
              if (d is Map<Object?, Object?>) {
                return Map<String, dynamic>.from(d);
              }
              return d as Map<String, dynamic>;
            }),
          );
        }
        return map;
      }
      return {'running': false, 'devices': []};
    } on PlatformException catch (e) {
      print('getSearchResults error: ${e.message}');
      return {'running': false, 'devices': []};
    } on MissingPluginException {
      return {'running': false, 'devices': []};
    }
  }

  /// Stoppt die Gerätesuche.
  static Future<void> stopDeviceSearch() async {
    try {
      await _channel.invokeMethod('stopDeviceSearch');
    } on PlatformException catch (e) {
      print('stopDeviceSearch error: ${e.message}');
    } on MissingPluginException {
      print('stopDeviceSearch: platform not available');
    }
  }

  /// Plant einen Reminder.
  static Future<bool> scheduleReminder(int atMs, String text) async {
    try {
      final result = await _channel.invokeMethod('scheduleReminder', {
        'atMs': atMs,
        'text': text,
      });
      return result is bool ? result : false;
    } on PlatformException catch (e) {
      print('scheduleReminder error: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Bricht einen Reminder ab.
  static Future<void> cancelReminder() async {
    try {
      await _channel.invokeMethod('cancelReminder');
    } on PlatformException catch (e) {
      print('cancelReminder error: ${e.message}');
    } on MissingPluginException {
      print('cancelReminder: platform not available');
    }
  }

  /// Holt den nativen Status.
  static Future<Map<String, dynamic>> getNativeStatus() async {
    try {
      final result = await _channel.invokeMethod('getNativeStatus');
      if (result is Map<Object?, Object?>) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } on PlatformException catch (e) {
      print('getNativeStatus error: ${e.message}');
      return {};
    } on MissingPluginException {
      return {};
    }
  }

  /// Öffnet die App-Details in den Einstellungen.
  static Future<void> openAppDetails() async {
    try {
      await _channel.invokeMethod('openAppDetails');
    } on PlatformException catch (e) {
      print('openAppDetails error: ${e.message}');
    } on MissingPluginException {
      print('openAppDetails: platform not available');
    }
  }

  /// Öffnet die Batterie-Einstellungen.
  static Future<void> openBatterySettings() async {
    try {
      await _channel.invokeMethod('openBatterySettings');
    } on PlatformException catch (e) {
      print('openBatterySettings error: ${e.message}');
    } on MissingPluginException {
      print('openBatterySettings: platform not available');
    }
  }
}
