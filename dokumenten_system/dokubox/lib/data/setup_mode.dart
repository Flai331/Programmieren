import 'package:shared_preferences/shared_preferences.dart';

/// Ersterfassung: alle vorhandenen Dokumente erst sammeln (vorläufige
/// Nummern V-0001 …), am Ende Nummern nach Datum vergeben.
class SetupMode {
  static const _key = 'setup_mode';

  static Future<bool> isOn() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  static Future<void> set(bool on) async =>
      (await SharedPreferences.getInstance()).setBool(_key, on);

  /// Frische Einrichtung (noch kein Dokument mit endgültiger Nummer und nie
  /// bewusst umgeschaltet) → Ersterfassung automatisch an.
  static Future<bool> autoEnable(Future<int> Function() finalNumbered) async {
    final sp = await SharedPreferences.getInstance();
    if (sp.containsKey(_key)) return sp.getBool(_key)!;
    final fresh = await finalNumbered() == 0;
    await sp.setBool(_key, fresh);
    return fresh;
  }
}

/// Vor dem Scan wählbar: sofort auslesen (Regeln + KI, kontrollieren) oder
/// erst nur sammeln und später gesammelt auslesen.
class ScanFlow {
  static const _key = 'scan_collect';

  static Future<bool> collect() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  static Future<void> setCollect(bool on) async =>
      (await SharedPreferences.getInstance()).setBool(_key, on);
}
