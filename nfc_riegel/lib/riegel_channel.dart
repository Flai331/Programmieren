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

  Future<String> addProfile(String name) async =>
      await channel.invokeMethod<String>('addProfile', {'name': name}) ?? '';

  Future<bool> updateProfile(ProfileInfo profile) async =>
      await channel.invokeMethod<bool>('updateProfile', {
        'id': profile.id,
        'name': profile.name,
        'blockedPackages': profile.blockedPackages,
        'defaultMode': modeToNative(profile.mode),
        'durationMinutes': profile.durationMinutes,
        'untilAt': profile.untilAt?.millisecondsSinceEpoch,
        'pinCalendarEnd': profile.pinCalendarEnd,
      }) ??
      false;

  Future<bool> deleteProfile(String id) async =>
      await channel.invokeMethod<bool>('deleteProfile', {'id': id}) ?? false;

  Future<bool> deleteTag(String uid) async =>
      await channel.invokeMethod<bool>('deleteTag', {'uid': uid}) ?? false;

  Future<String?> generateCode() async =>
      channel.invokeMethod<String>('generateCode');

  Future<void> startTagEnrollment({
    required String label,
    required String profileId,
    required bool isMaster,
  }) => channel.invokeMethod<void>('startTagEnrollment', {
    'label': label,
    'profileId': profileId,
    'isMaster': isMaster,
  });

  Future<bool> isAccessibilityEnabled() async =>
      await channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  Future<void> openAccessibilitySettings() =>
      channel.invokeMethod<void>('openAccessibilitySettings');

  Future<bool> isAdminActive() async =>
      await channel.invokeMethod<bool>('isAdminActive') ?? false;

  Future<void> requestAdmin() => channel.invokeMethod<void>('requestAdmin');
}
