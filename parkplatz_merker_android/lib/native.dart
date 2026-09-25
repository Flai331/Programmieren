import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

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
        final map = Map<String, dynamic>.from(result);
        if (map['launchApps'] is List) {
          map['launchApps'] = List<Map<String, dynamic>>.from(
            (map['launchApps'] as List).map((a) {
              if (a is Map<Object?, Object?>) {
                return Map<String, dynamic>.from(a);
              }
              return a as Map<String, dynamic>;
            }),
          );
        }
        return map;
      }
      return _defaultConfig();
    } on PlatformException catch (e) {
      debugPrint('getConfig error: ${e.message}');
      return _defaultConfig();
    } on MissingPluginException {
      return _defaultConfig();
    }
  }

  static Map<String, dynamic> _defaultConfig() {
    return {
      'activityEnabled': true,
      'chargerEnabled': true,
      'deviceMode': 'none',
      'deviceAddress': null,
      'deviceName': null,
      'launchPackage': '',
      'launchLabel': '',
      'launchApps': <Map<String, dynamic>>[],
      'closeOnGone': true,
      'closeActionTitle': '',
      'closeActionIndex': -1,
      'forceStopFallback': false,
      'volumeEnabled': false,
      'volMusic': -1,
      'volRing': -1,
      'volNotification': -1,
      'ringerMode': 'keep',
      'volumeRestore': true,
    };
  }

  /// Setzt die Konfiguration.
  static Future<void> setConfig({
    bool? activityEnabled,
    bool? chargerEnabled,
    String? deviceMode,
    String? deviceAddress,
    String? deviceName,
    String? launchPackage,
    String? launchLabel,
    bool? closeOnGone,
    String? closeActionTitle,
    int? closeActionIndex,
    bool? forceStopFallback,
    List<Map<String, dynamic>>? launchApps,
    bool? volumeEnabled,
    int? volMusic,
    int? volRing,
    int? volNotification,
    String? ringerMode,
    bool? volumeRestore,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (activityEnabled != null) params['activityEnabled'] = activityEnabled;
      if (chargerEnabled != null) params['chargerEnabled'] = chargerEnabled;
      if (deviceMode != null) params['deviceMode'] = deviceMode;
      if (deviceAddress != null) params['deviceAddress'] = deviceAddress;
      if (deviceName != null) params['deviceName'] = deviceName;
      if (launchPackage != null) params['launchPackage'] = launchPackage;
      if (launchLabel != null) params['launchLabel'] = launchLabel;
      if (closeOnGone != null) params['closeOnGone'] = closeOnGone;
      if (closeActionTitle != null) params['closeActionTitle'] = closeActionTitle;
      if (closeActionIndex != null) params['closeActionIndex'] = closeActionIndex;
      if (forceStopFallback != null) params['forceStopFallback'] = forceStopFallback;
      if (launchApps != null) params['launchApps'] = launchApps;
      if (volumeEnabled != null) params['volumeEnabled'] = volumeEnabled;
      if (volMusic != null) params['volMusic'] = volMusic;
      if (volRing != null) params['volRing'] = volRing;
      if (volNotification != null) params['volNotification'] = volNotification;
      if (ringerMode != null) params['ringerMode'] = ringerMode;
      if (volumeRestore != null) params['volumeRestore'] = volumeRestore;
      await _channel.invokeMethod('setConfig', params);
    } on PlatformException catch (e) {
      debugPrint('setConfig error: ${e.message}');
    } on MissingPluginException {
      debugPrint('setConfig: platform not available');
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

  /// Listet alle installierten Launcher-Apps auf.
  static Future<List<Map<String, String>>> listApps() async {
    try {
      final result = await _channel.invokeMethod('listApps');
      if (result is List) {
        return List<Map<String, String>>.from(
          result.cast<Object?>().map((e) {
            if (e is Map<Object?, Object?>) {
              return Map<String, String>.from(e.cast<String, String>());
            }
            return <String, String>{};
          }),
        );
      }
      return [];
    } on PlatformException catch (e) {
      debugPrint('listApps error: ${e.message}');
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  /// Öffnet die Einstellungen für Overlay-Berechtigung.
  static Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } on PlatformException catch (e) {
      debugPrint('openOverlaySettings error: ${e.message}');
    } on MissingPluginException {
      debugPrint('openOverlaySettings: platform not available');
    }
  }

  /// Testet den App-Start.
  static Future<void> testLaunch() async {
    try {
      await _channel.invokeMethod('testLaunch');
    } on PlatformException catch (e) {
      debugPrint('testLaunch error: ${e.message}');
    } on MissingPluginException {
      debugPrint('testLaunch: platform not available');
    }
  }

  /// Listet Ausschaltknopf-Optionen auf.
  static Future<Map<String, dynamic>> listCloseActions(String? package) async {
    try {
      final result = await _channel.invokeMethod('listCloseActions', {'package': package});
      if (result is Map<Object?, Object?>) {
        final map = Map<String, dynamic>.from(result);
        // Einträge von Android kommen als Map<Object?, Object?> an.
        map['actions'] = ((map['actions'] as List?) ?? const [])
            .whereType<Map<Object?, Object?>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return map;
      }
      return {'actions': [], 'actionless': false, 'hasNotification': false};
    } on PlatformException catch (e) {
      debugPrint('listCloseActions error: ${e.message}');
      return {'actions': [], 'actionless': false, 'hasNotification': false};
    } on MissingPluginException {
      return {'actions': [], 'actionless': false, 'hasNotification': false};
    }
  }

  /// Testet das App-Beenden.
  static Future<void> testClose() async {
    try {
      await _channel.invokeMethod('testClose');
    } on PlatformException catch (e) {
      debugPrint('testClose error: ${e.message}');
    } on MissingPluginException {
      debugPrint('testClose: platform not available');
    }
  }

  /// Oeffnet die Benachrichtigungszugriff-Einstellungen.
  static Future<void> openNotificationListenerSettings() async {
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } on PlatformException catch (e) {
      debugPrint('openNotificationListenerSettings error: ${e.message}');
    } on MissingPluginException {
      debugPrint('openNotificationListenerSettings: platform not available');
    }
  }

  /// Oeffnet die Bedienungshilfen-Einstellungen.
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint('openAccessibilitySettings error: ${e.message}');
    } on MissingPluginException {
      debugPrint('openAccessibilitySettings: platform not available');
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

  /// Aktualisiert das Car-Widget mit den neuesten Parkplatz-Daten.
  static Future<void> updateWidget(Map<String, dynamic>? spot) async {
    try {
      await _channel.invokeMethod('updateWidget', spot);
    } on PlatformException catch (e) {
      debugPrint('updateWidget error: ${e.message}');
    } on MissingPluginException {
      debugPrint('updateWidget: platform not available');
    }
  }

  /// Signalisiert dem Hintergrund-Lauf, dass er beendet ist.
  static Future<void> backgroundDone() async {
    try {
      await _channel.invokeMethod('backgroundDone');
    } on PlatformException catch (e) {
      debugPrint('backgroundDone error: ${e.message}');
    } on MissingPluginException {
      debugPrint('backgroundDone: platform not available');
    }
  }

  /// Holt Lautstärke-Info.
  static Future<Map<String, dynamic>> getVolumeInfo() async {
    try {
      final result = await _channel.invokeMethod('getVolumeInfo');
      if (result is Map<Object?, Object?>) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } on PlatformException catch (e) {
      debugPrint('getVolumeInfo error: ${e.message}');
      return {};
    } on MissingPluginException {
      return {};
    }
  }

  /// Wendet Lautstärke-Profil an.
  static Future<void> applyVolumeNow() async {
    try {
      await _channel.invokeMethod('applyVolumeNow');
    } on PlatformException catch (e) {
      debugPrint('applyVolumeNow error: ${e.message}');
    } on MissingPluginException {
      debugPrint('applyVolumeNow: platform not available');
    }
  }

  /// Stellt Lautstärke zurück.
  static Future<void> restoreVolumeNow() async {
    try {
      await _channel.invokeMethod('restoreVolumeNow');
    } on PlatformException catch (e) {
      debugPrint('restoreVolumeNow error: ${e.message}');
    } on MissingPluginException {
      debugPrint('restoreVolumeNow: platform not available');
    }
  }

  /// Öffnet Nicht-stören-Zugriff-Einstellungen.
  static Future<void> openDndSettings() async {
    try {
      await _channel.invokeMethod('openDndSettings');
    } on PlatformException catch (e) {
      debugPrint('openDndSettings error: ${e.message}');
    } on MissingPluginException {
      debugPrint('openDndSettings: platform not available');
    }
  }
}
