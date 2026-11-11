import 'package:shared_preferences/shared_preferences.dart';

/// Einstellungen für Fristen: Bundesland (Feiertage) und Vorlauf der
/// Erinnerung an die Widerspruchsfrist.
class DeadlineSettings {
  final String? state;
  final int objectionLeadDays;
  const DeadlineSettings({this.state, this.objectionLeadDays = 7});

  static const _stateKey = 'deadline_state';
  static const _leadKey = 'deadline_objection_lead';

  static Future<DeadlineSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return DeadlineSettings(
      state: p.getString(_stateKey),
      objectionLeadDays: p.getInt(_leadKey) ?? 7,
    );
  }

  static Future<void> setState(String? state) async {
    final p = await SharedPreferences.getInstance();
    state == null ? await p.remove(_stateKey) : await p.setString(_stateKey, state);
  }

  static Future<void> setObjectionLeadDays(int days) async =>
      (await SharedPreferences.getInstance()).setInt(_leadKey, days);
}
