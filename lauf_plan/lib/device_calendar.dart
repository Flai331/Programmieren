import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar.dart';

// Direkt in den Handykalender (Android, MainActivity.kt):
// - einzelner Termin: Kalender-App öffnet sich mit vorausgefülltem Termin
// - mehrere Termine: werden in einen gewählten Kalender geschrieben; die
//   Termin-IDs werden gemerkt, damit ein erneuter Export sie aktualisiert.

const _channel = MethodChannel('lauf_plan/calendar');

class DeviceCalendar {
  final int id;
  final String name;
  final String account;
  final bool primary;
  const DeviceCalendar(this.id, this.name, this.account, this.primary);
}

/// Argumente für den Kalender-Kanal (Datum + Uhrzeit als Ortszeit-Felder).
Map<String, Object?> calendarArgs(CalEvent e, {int? id}) => {
      'year': e.day.year,
      'month': e.day.month,
      'day': e.day.day,
      'start': e.startMinutes,
      'minutes': e.minutes,
      'allDay': e.allDay,
      'title': e.title,
      'description': e.description,
      'alarm': e.alarmMinutes,
      if (id != null) 'id': id,
    };

/// Kalender-App mit vorausgefülltem Termin öffnen. false = keine Kalender-App.
Future<bool> openInCalendarApp(CalEvent e) async {
  try {
    return await _channel.invokeMethod<bool>('insertIntent', calendarArgs(e)) ?? false;
  } catch (_) {
    return false;
  }
}

/// Einzelnen Termin in die Kalender-App, sonst Hinweis.
Future<void> addToCalendarApp(BuildContext context, CalEvent e) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!await openInCalendarApp(e)) {
    messenger?.showSnackBar(const SnackBar(
        content: Text('Keine Kalender-App gefunden. Nutze „Als Datei teilen“.')));
  }
}

/// Schreibt mehrere Termine direkt in einen Kalender. [keys] identifizieren die
/// Termine (z. B. Plan-Tag), damit ein erneuter Export sie aktualisiert.
/// Rückgabe: Anzahl eingetragener Termine, null bei Abbruch/Fehler.
Future<int?> writeToDeviceCalendar(BuildContext context, SharedPreferences prefs,
    List<String> keys, List<CalEvent> events) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String t) => messenger?.showSnackBar(SnackBar(content: Text(t)));
  try {
    final granted = await _channel.invokeMethod<bool>('requestPermission') ?? false;
    if (!granted) {
      say('Ohne Kalender-Berechtigung kann die App keine Termine eintragen.');
      return null;
    }
    final raw = await _channel.invokeListMethod<Map>('calendars') ?? [];
    final cals = [
      for (final c in raw)
        DeviceCalendar((c['id'] as num).toInt(), '${c['name']}', '${c['account']}',
            c['primary'] == true)
    ];
    if (cals.isEmpty) {
      say('Kein beschreibbarer Kalender gefunden.');
      return null;
    }
    final saved = prefs.getInt('cal_id');
    DeviceCalendar? cal = cals.where((c) => c.id == saved).firstOrNull;
    if (cal == null) {
      if (!context.mounted) return null;
      cal = await _pickCalendar(context, cals);
      if (cal == null) return null;
      await prefs.setInt('cal_id', cal.id);
    }
    final args = [
      for (var i = 0; i < events.length; i++)
        calendarArgs(events[i],
            id: prefs.getInt('cal_event_${cal.id}_${keys[i]}'))
    ];
    final ids = await _channel.invokeListMethod<num>(
            'writeEvents', {'calendarId': cal.id, 'events': args}) ??
        [];
    for (var i = 0; i < ids.length && i < keys.length; i++) {
      await prefs.setInt('cal_event_${cal.id}_${keys[i]}', ids[i].toInt());
    }
    return ids.length;
  } catch (e) {
    say('Eintragen fehlgeschlagen: $e');
    return null;
  }
}

/// Gemerkten Kalender vergessen (beim nächsten Eintragen neu wählen).
Future<void> forgetCalendarChoice(SharedPreferences prefs) => prefs.remove('cal_id');

Future<DeviceCalendar?> _pickCalendar(BuildContext context, List<DeviceCalendar> cals) {
  final sorted = [...cals]..sort((a, b) => (b.primary ? 1 : 0) - (a.primary ? 1 : 0));
  return showDialog<DeviceCalendar>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('In welchen Kalender?'),
      children: [
        for (final c in sorted)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, c),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month),
              title: Text(c.name),
              subtitle: c.account.isEmpty || c.account == c.name ? null : Text(c.account),
            ),
          ),
      ],
    ),
  );
}
