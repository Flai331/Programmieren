import 'package:shared_preferences/shared_preferences.dart';

/// Ersterfassung: alle vorhandenen Dokumente erst sammeln (vorläufige
/// Nummern V-0001 …), am Ende Nummern nach Datum vergeben.
class SetupMode {
  static const _key = 'setup_mode';

  static Future<bool> isOn() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  static Future<void> set(bool on) async =>
      (await SharedPreferences.getInstance()).setBool(_key, on);
}
