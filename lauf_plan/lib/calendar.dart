import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

// Kalender-Export als .ics (iCalendar, RFC 5545).
// Zeiten werden als "floating" Ortszeit geschrieben (ohne Zeitzone):
// Der Kalender trägt sie in der eigenen Zeitzone ein.

class CalEvent {
  /// Feste ID: Ein erneuter Export derselben Einheit aktualisiert den Termin
  /// (sofern der Kalender das unterstützt), statt ihn doppelt anzulegen.
  final String uid;
  final String title;
  final String description;

  /// Kalendertag; bei [allDay] == false zählt zusätzlich [startMinutes].
  final DateTime day;
  final int startMinutes;
  final int minutes;
  final bool allDay;

  /// Erinnerung so viele Minuten vorher (0 = keine). Nur bei Terminen mit Uhrzeit.
  final int alarmMinutes;

  const CalEvent({
    required this.uid,
    required this.title,
    required this.day,
    this.description = '',
    this.startMinutes = 18 * 60,
    this.minutes = 60,
    this.allDay = false,
    this.alarmMinutes = 30,
  });
}

String _two(int n) => n.toString().padLeft(2, '0');
String _icsDate(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';
String _icsLocal(DateTime d) =>
    '${_icsDate(d)}T${_two(d.hour)}${_two(d.minute)}00';
String _icsUtc(DateTime d) {
  final u = d.toUtc();
  return '${_icsLocal(u)}Z';
}

/// Text nach RFC 5545 maskieren.
String icsEscape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n');

/// Zeilen über 75 Bytes umbrechen (Fortsetzung beginnt mit Leerzeichen),
/// ohne UTF-8-Zeichen zu zerschneiden.
String icsFold(String line) {
  final out = StringBuffer();
  var bytes = 0;
  var limit = 75;
  for (final rune in line.runes) {
    final ch = String.fromCharCode(rune);
    final len = utf8.encode(ch).length;
    if (bytes + len > limit) {
      out.write('\r\n ');
      bytes = 1;
      limit = 75;
    }
    out.write(ch);
    bytes += len;
  }
  return out.toString();
}

String buildIcs(List<CalEvent> events, {DateTime? now}) {
  final stamp = now ?? DateTime.now();
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Klaas//Laufplan//DE',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
  ];
  for (final e in events) {
    final day = DateTime(e.day.year, e.day.month, e.day.day);
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${e.uid}',
      'DTSTAMP:${_icsUtc(stamp)}',
      // Höhere Sequenz bei jedem Export -> Kalender übernimmt neue Zeiten.
      'SEQUENCE:${stamp.millisecondsSinceEpoch ~/ 1000 ~/ 60}',
    ]);
    if (e.allDay) {
      lines.addAll([
        'DTSTART;VALUE=DATE:${_icsDate(day)}',
        'DTEND;VALUE=DATE:${_icsDate(DateTime(day.year, day.month, day.day + 1))}',
      ]);
    } else {
      final start = DateTime(day.year, day.month, day.day, 0, e.startMinutes);
      final end = DateTime(day.year, day.month, day.day, 0, e.startMinutes + e.minutes);
      lines.addAll(['DTSTART:${_icsLocal(start)}', 'DTEND:${_icsLocal(end)}']);
    }
    lines.add('SUMMARY:${icsEscape(e.title)}');
    if (e.description.isNotEmpty) lines.add('DESCRIPTION:${icsEscape(e.description)}');
    lines.add('TRANSP:OPAQUE');
    if (!e.allDay && e.alarmMinutes > 0) {
      lines.addAll([
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'DESCRIPTION:${icsEscape(e.title)}',
        'TRIGGER:-PT${e.alarmMinutes}M',
        'END:VALARM',
      ]);
    }
    lines.add('END:VEVENT');
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(icsFold).join('\r\n')}\r\n';
}

/// Dateiname ohne Sonderzeichen, z. B. "laufplan-beine-a-2026-10-08.ics".
String icsFileName(String title, DateTime day) {
  const umlauts = {'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss'};
  var slug = title.toLowerCase();
  umlauts.forEach((k, v) => slug = slug.replaceAll(k, v));
  slug = slug.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) slug = 'einheit';
  return '$slug-${day.year}-${_two(day.month)}-${_two(day.day)}.ics';
}

/// .ics über das Teilen-Menü weitergeben (Kalender-App, Mail, Drive …).
Future<void> shareIcs(BuildContext context, List<CalEvent> events, String fileName) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (events.isEmpty) {
    messenger?.showSnackBar(const SnackBar(content: Text('Keine Termine zum Exportieren.')));
    return;
  }
  try {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(utf8.encode(buildIcs(events)), mimeType: 'text/calendar')],
      fileNameOverrides: [fileName],
      subject: events.length == 1 ? events.first.title : 'Laufplan – ${events.length} Termine',
    ));
  } catch (_) {
    messenger?.showSnackBar(
        const SnackBar(content: Text('Export fehlgeschlagen. Bitte erneut versuchen.')));
  }
}

String timeLabel(int minutes) => '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';

/// Auswahl beim Export: Uhrzeit oder ganztägig.
class ExportChoice {
  final int startMinutes;
  final bool allDay;
  const ExportChoice(this.startMinutes, this.allDay);
}

Future<ExportChoice?> askExportTime(BuildContext context,
    {required String title, required int initialMinutes, String? info}) {
  var minutes = initialMinutes;
  var allDay = false;
  return showDialog<ExportChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info != null) ...[Text(info), const SizedBox(height: 12)],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ganztägig'),
              value: allDay,
              onChanged: (v) => setState(() => allDay = v),
            ),
            if (!allDay)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('Beginn'),
                trailing: Text(timeLabel(minutes),
                    style: Theme.of(ctx).textTheme.titleMedium),
                onTap: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
                  );
                  if (t != null) setState(() => minutes = t.hour * 60 + t.minute);
                },
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, ExportChoice(minutes, allDay)),
            icon: const Icon(Icons.ios_share),
            label: const Text('Exportieren'),
          ),
        ],
      ),
    ),
  );
}
