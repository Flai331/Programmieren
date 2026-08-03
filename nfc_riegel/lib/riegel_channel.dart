import 'package:flutter/services.dart';

import 'lock_status.dart';

/// Einzige Stelle, an der Dart mit der nativen Seite spricht.
class RiegelChannel {
  const RiegelChannel([this.channel = const MethodChannel(_name)]);

  static const _name = 'com.klaas.nfc_riegel/riegel';

  final MethodChannel channel;

  Future<LockStatus> getState() async {
    final map = await channel.invokeMethod<Map<dynamic, dynamic>>('getState');
    return LockStatus.fromMap(map ?? const {});
  }

  Future<bool> setBlockedPackages(List<String> packages) async =>
      await channel.invokeMethod<bool>(
        'setBlockedPackages',
        {'packages': packages},
      ) ??
      false;

  Future<bool> setMode(LockMode mode, int durationMinutes) async =>
      await channel.invokeMethod<bool>('setMode', {
        'mode': mode == LockMode.open ? 'OPEN' : 'TIMER',
        'durationMinutes': durationMinutes,
      }) ??
      false;

  Future<String> generateCode() async =>
      await channel.invokeMethod<String>('generateCode') ?? '';

  Future<void> startTagEnrollment() =>
      channel.invokeMethod<void>('startTagEnrollment');

  Future<bool> isAccessibilityEnabled() async =>
      await channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  Future<void> openAccessibilitySettings() =>
      channel.invokeMethod<void>('openAccessibilitySettings');

  Future<bool> isAdminActive() async =>
      await channel.invokeMethod<bool>('isAdminActive') ?? false;

  Future<void> requestAdmin() => channel.invokeMethod<void>('requestAdmin');
}
