import 'package:flutter/material.dart';

/// Was mit einem Dokument geschehen soll.
class TaskAction {
  final String key;
  final String label;

  /// Kurzform für Listen/Benachrichtigungen, z. B. „Versenden“.
  final String verb;
  final IconData icon;

  /// Vorschlag für die Notiz.
  final String hint;
  const TaskAction(this.key, this.label, this.verb, this.icon, this.hint);
}

const kTaskActions = <TaskAction>[
  TaskAction('ausfuellen', 'Ausfüllen', 'Ausfüllen', Icons.edit_document,
      'Welche Felder? z. B. Seite 2, Bankverbindung'),
  TaskAction('unterschreiben', 'Unterschreiben', 'Unterschreiben', Icons.draw,
      'Wer muss unterschreiben?'),
  TaskAction('versenden', 'Versenden', 'Versenden', Icons.send,
      'An wen und wie? z. B. Beihilfestelle per Mail'),
  TaskAction('bezahlen', 'Bezahlen', 'Bezahlen', Icons.payments,
      'Betrag, Überweisung oder Lastschrift prüfen'),
  TaskAction('einreichen', 'Einreichen', 'Einreichen', Icons.local_hospital,
      'Bei Krankenkasse, Beihilfe, Versicherung …'),
  TaskAction('kuendigen', 'Kündigen', 'Kündigen', Icons.cancel_presentation,
      'Frist beachten, Kündigung per Einschreiben?'),
  TaskAction('anrufen', 'Anrufen', 'Anrufen', Icons.phone,
      'Wen anrufen, was klären? Telefonnummer'),
  TaskAction('nachhaken', 'Nachhaken', 'Nachhaken', Icons.mark_email_unread,
      'Antwort ausstehend – nachfragen bei …'),
  TaskAction('pruefen', 'Prüfen', 'Prüfen', Icons.fact_check,
      'Was prüfen? z. B. Vertrag verlängern oder wechseln'),
  TaskAction('ablegen', 'Original ablegen', 'Ablegen', Icons.inventory_2,
      'Wohin? z. B. Ordner Versicherungen'),
  TaskAction('sonstiges', 'Sonstiges', 'Erledigen', Icons.task_alt,
      'Was ist zu tun?'),
];

TaskAction taskAction(String key) =>
    kTaskActions.firstWhere((a) => a.key == key,
        orElse: () => kTaskActions.last);

/// Wiederholungen.
const kTaskRepeats = <String, String>{
  '': 'Einmalig',
  'monatlich': 'Jeden Monat',
  'vierteljaehrlich': 'Alle 3 Monate',
  'jaehrlich': 'Jedes Jahr',
};

DateTime _addMonths(DateTime d, int months) {
  final y = d.year + (d.month - 1 + months) ~/ 12;
  final m = (d.month - 1 + months) % 12 + 1;
  // Tag begrenzen (31.01. + 1 Monat → 28./29.02.).
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > lastDay ? lastDay : d.day, d.hour, d.minute);
}

/// Nächster Termin einer wiederkehrenden Aufgabe – mindestens nach [now],
/// damit eine lange überfällige Aufgabe nicht sofort wieder fällig ist.
DateTime? nextDue(DateTime due, String repeat, {DateTime? now}) {
  final months = switch (repeat) {
    'monatlich' => 1,
    'vierteljaehrlich' => 3,
    'jaehrlich' => 12,
    _ => 0,
  };
  if (months == 0) return null;
  now ??= DateTime.now();
  var next = _addMonths(due, months);
  var i = 2;
  while (!next.isAfter(now)) {
    next = _addMonths(due, months * i++);
  }
  return next;
}

/// Schnellauswahl für Termine.
class DueChoice {
  final String label;
  final DateTime Function(DateTime now) at;
  const DueChoice(this.label, this.at);
}

DateTime _at(DateTime day, int hour) =>
    DateTime(day.year, day.month, day.day, hour);

final kDueChoices = <DueChoice>[
  DueChoice('Heute Abend', (n) {
    final evening = _at(n, 18);
    return evening.isAfter(n) ? evening : n.add(const Duration(hours: 1));
  }),
  DueChoice('Morgen', (n) => _at(n.add(const Duration(days: 1)), 9)),
  DueChoice('In 3 Tagen', (n) => _at(n.add(const Duration(days: 3)), 9)),
  DueChoice('Nächste Woche', (n) => _at(n.add(const Duration(days: 7)), 9)),
  DueChoice('In 2 Wochen', (n) => _at(n.add(const Duration(days: 14)), 9)),
  DueChoice('In 1 Monat', (n) => _at(_addMonths(n, 1), 9)),
];

/// Gruppe in der Aufgaben-Übersicht.
enum TaskGroup { overdue, today, week, later, done }

TaskGroup taskGroup(DateTime due, DateTime? doneAt, {DateTime? now}) {
  if (doneAt != null) return TaskGroup.done;
  now ??= DateTime.now();
  if (due.isBefore(now)) return TaskGroup.overdue;
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (due.isBefore(tomorrow)) return TaskGroup.today;
  if (due.isBefore(tomorrow.add(const Duration(days: 7)))) return TaskGroup.week;
  return TaskGroup.later;
}

const kTaskGroupLabels = {
  TaskGroup.overdue: 'Überfällig',
  TaskGroup.today: 'Heute',
  TaskGroup.week: 'Nächste 7 Tage',
  TaskGroup.later: 'Später',
  TaskGroup.done: 'Erledigt',
};
