import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../data/tasks.dart';

final _dueFormat = DateFormat('EEE, dd.MM.yyyy · HH:mm', 'de_DE');

/// Lesbarer Termin: „heute 18:00“, „morgen 09:00“, sonst Datum.
String taskDueLabel(DateTime due, {DateTime? now}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.year, due.month, due.day);
  final time = DateFormat('HH:mm').format(due);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'heute $time';
  if (diff == 1) return 'morgen $time';
  if (diff == -1) return 'gestern $time';
  return _dueFormat.format(due);
}

/// Was der „Jetzt …“-Knopf einer Aufgabe auslöst.
enum TaskQuickAction { fill, share, paid }

TaskQuickAction? quickActionFor(String action) => switch (action) {
      'ausfuellen' || 'unterschreiben' => TaskQuickAction.fill,
      'versenden' => TaskQuickAction.share,
      'bezahlen' => TaskQuickAction.paid,
      _ => null,
    };

String quickActionLabel(TaskQuickAction a) => switch (a) {
      TaskQuickAction.fill => 'Jetzt ausfüllen',
      TaskQuickAction.share => 'Jetzt versenden',
      TaskQuickAction.paid => 'Bezahlt',
    };

/// Erinnerung anlegen oder bearbeiten. Speichert und plant die
/// Benachrichtigung; liefert true, wenn gespeichert wurde.
Future<bool> showTaskEditor(
  BuildContext context, {
  required Document doc,
  DocTask? task,
  String? presetAction,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TaskEditor(doc: doc, task: task, presetAction: presetAction),
  );
  return saved == true;
}

class _TaskEditor extends StatefulWidget {
  final Document doc;
  final DocTask? task;
  final String? presetAction;
  const _TaskEditor({required this.doc, this.task, this.presetAction});

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late String _action;
  late final TextEditingController _note;
  late DateTime _due;
  late String _repeat;
  String? _choice;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _action = t?.action ?? widget.presetAction ?? 'versenden';
    _note = TextEditingController(text: t?.note ?? '');
    _due = t?.dueAt ?? kDueChoices[1].at(DateTime.now()); // morgen 9 Uhr
    _choice = t == null ? kDueChoices[1].label : null;
    _repeat = t?.repeat ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickCustom() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    if (!mounted) return;
    setState(() {
      _due = DateTime(date.year, date.month, date.day, time?.hour ?? 9,
          time?.minute ?? 0);
      _choice = null;
    });
  }

  Future<void> _save() async {
    final repo = services.repository;
    final t = widget.task;
    if (t == null) {
      await repo.createTask(
        documentId: widget.doc.id,
        action: _action,
        note: _note.text,
        dueAt: _due,
        repeat: _repeat,
      );
    } else {
      await repo.updateTask(t.id,
          action: _action, note: _note.text, dueAt: _due, repeat: _repeat);
    }
    await services.notifications.syncDocument(widget.doc.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = taskAction(_action);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.task == null ? 'Neue Erinnerung' : 'Erinnerung ändern',
                style: theme.textTheme.titleLarge),
            Text(
              '${widget.doc.docNumber} · '
              '${widget.doc.title.isEmpty ? 'ohne Titel' : widget.doc.title}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text('Was ist zu tun?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in kTaskActions)
                  ChoiceChip(
                    avatar: Icon(a.icon, size: 18),
                    label: Text(a.label),
                    selected: a.key == _action,
                    onSelected: (_) => setState(() => _action = a.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Notiz (optional)',
                hintText: action.hint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text('Wann erinnern?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in kDueChoices)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _choice == c.label,
                    onSelected: (_) => setState(() {
                      _due = c.at(DateTime.now());
                      _choice = c.label;
                    }),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Datum & Uhrzeit…'),
                  onPressed: _pickCustom,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.alarm, size: 18),
                const SizedBox(width: 6),
                Text(taskDueLabel(_due), style: theme.textTheme.bodyLarge),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _repeat,
              decoration: const InputDecoration(
                labelText: 'Wiederholen',
                border: OutlineInputBorder(),
                helperText:
                    'z. B. jährlich Versicherung prüfen – nach dem Abhaken '
                    'kommt die nächste Erinnerung',
                helperMaxLines: 2,
              ),
              items: [
                for (final e in kTaskRepeats.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _repeat = v ?? ''),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.alarm_add),
                label: const Text('Erinnerung speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine Aufgabe in einer Liste: abhaken, „Jetzt …“, Menü.
class TaskTile extends StatelessWidget {
  final DocTask task;

  /// In der Gesamtübersicht: Dokument mit anzeigen.
  final Document? doc;
  final VoidCallback? onTap;
  final void Function(TaskQuickAction action)? onQuickAction;
  final VoidCallback? onEdit;

  const TaskTile({
    super.key,
    required this.task,
    this.doc,
    this.onTap,
    this.onQuickAction,
    this.onEdit,
  });

  Future<void> _toggle(BuildContext context) async {
    final repo = services.repository;
    if (task.doneAt != null) {
      await repo.reopenTask(task.id);
    } else {
      final next = await repo.completeTask(task.id);
      if (next != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erledigt – nächste Erinnerung ${taskDueLabel(next.dueAt)}'),
        ));
      }
    }
    await services.notifications.syncDocument(task.documentId);
  }

  Future<void> _snooze(Duration by) async {
    await services.repository.snoozeTask(task.id, by);
    await services.notifications.syncDocument(task.documentId);
  }

  Future<void> _delete() async {
    await services.repository.deleteTask(task.id);
    await services.notifications.syncDocument(task.documentId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = taskAction(task.action);
    final done = task.doneAt != null;
    final overdue = !done && task.dueAt.isBefore(DateTime.now());
    final quick = done ? null : quickActionFor(task.action);
    final docLine = doc == null
        ? null
        : '${doc!.docNumber} · ${doc!.title.isEmpty ? 'ohne Titel' : doc!.title}';
    return ListTile(
      onTap: onTap,
      leading: Checkbox(
        value: done,
        onChanged: (_) => _toggle(context),
      ),
      title: Row(
        children: [
          Icon(action.icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              docLine == null ? action.label : '${action.verb}: ${doc!.title.isEmpty ? doc!.docNumber : doc!.title}',
              style: done
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.note.isNotEmpty) Text(task.note),
          Text(
            [
              if (done) 'erledigt ${taskDueLabel(task.doneAt!)}' else taskDueLabel(task.dueAt),
              if (task.repeat.isNotEmpty) kTaskRepeats[task.repeat]!,
              if (docLine != null) doc!.docNumber,
            ].join(' · '),
            style: TextStyle(
              color: overdue ? theme.colorScheme.error : null,
              fontWeight: overdue ? FontWeight.bold : null,
            ),
          ),
          if (quick != null && onQuickAction != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => onQuickAction!(quick),
                icon: Icon(action.icon, size: 18),
                label: Text(quickActionLabel(quick)),
              ),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'edit':
              onEdit?.call();
            case 'day':
              await _snooze(const Duration(days: 1));
            case 'week':
              await _snooze(const Duration(days: 7));
            case 'delete':
              await _delete();
          }
        },
        itemBuilder: (_) => [
          if (onEdit != null)
            const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
          if (!done) ...[
            const PopupMenuItem(value: 'day', child: Text('+1 Tag verschieben')),
            const PopupMenuItem(
                value: 'week', child: Text('+1 Woche verschieben')),
          ],
          const PopupMenuItem(value: 'delete', child: Text('Löschen')),
        ],
      ),
    );
  }
}

/// Nach Ausfüllen/Versenden: passende offene Aufgabe abhaken?
Future<void> offerCompleteTasks(
  BuildContext context, {
  required String documentId,
  required Set<String> actions,
  required String question,
}) async {
  final open = await services.repository.openTasksFor(documentId, actions);
  if (open.isEmpty || !context.mounted) return;
  final labels = open
      .map((t) => taskAction(t.action).label +
          (t.note.isEmpty ? '' : ' – ${t.note}'))
      .join('\n');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(question),
      content: Text(labels),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Noch nicht'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Erledigt'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  for (final t in open) {
    await services.repository.completeTask(t.id);
  }
  await services.notifications.syncDocument(documentId);
}
