import 'package:flutter/services.dart';

import 'logic.dart';

class Native {
  static const _ch = MethodChannel('akku_schoner/native');

  static Future<BatteryState> battery() async =>
      BatteryState.fromMap(await _ch.invokeMethod<Map>('getBattery') ?? {});

  static Future<Map<dynamic, dynamic>> status() async =>
      await _ch.invokeMethod<Map>('getStatus') ?? {};

  static Future<List<AppEntry>> apps() async {
    final list = await _ch.invokeMethod<List>('listApps') ?? [];
    return list.map((e) => AppEntry.fromMap(e as Map)).toList();
  }

  /// level == null → wieder automatisch.
  static Future<void> setLevel(String pkg, Level? level) =>
      _ch.invokeMethod('setLevel', {'pkg': pkg, 'level': level?.name});

  static Future<int> killBackground(List<String> pkgs) async =>
      await _ch.invokeMethod<int>('killBackground', {'pkgs': pkgs}) ?? 0;

  /// false = Bedienungshilfe nicht aktiv.
  static Future<bool> forceStop(List<String> pkgs) async =>
      await _ch.invokeMethod<bool>('forceStop', {'pkgs': pkgs}) ?? false;

  static Future<void> cancelForceStop() => _ch.invokeMethod('cancelForceStop');

  static Future<Map<dynamic, dynamic>> forceStopState() async =>
      await _ch.invokeMethod<Map>('forceStopState') ?? {};

  static Future<Map<dynamic, dynamic>> watcher() async =>
      await _ch.invokeMethod<Map>('getWatcher') ?? {};

  static Future<void> setWatcher(Map<String, Object> values) =>
      _ch.invokeMethod('setWatcher', values);

  static Future<void> openAppDetails(String pkg) =>
      _ch.invokeMethod('openAppDetails', {'pkg': pkg});

  static Future<void> openSettings(String name) =>
      _ch.invokeMethod('openSettings', {'name': name});
}
