import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../data/tasks.dart';
import 'document_detail_screen.dart';
import 'task_widgets.dart';

/// Alle Aufgaben/Erinnerungen über alle Dokumente, nach Dringlichkeit.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  void _open(BuildContext context, Document doc, {TaskQuickAction? action}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          DocumentDetailScreen(documentId: doc.id, initialAction: action),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben')),
      body: StreamBuilder<List<({DocTask task, Document doc})>>(
        stream: services.repository.watchAllTasks(),
        builder: (context, snap) {
          final rows = snap.data;
          if (rows == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Keine Aufgaben.\n\nIn einem Dokument unter „Aufgaben & '
                  'Erinnerungen“ → „Neu“ legst du fest, was wann zu tun ist – '
                  'z. B. ausfüllen, versenden oder bezahlen.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final now = DateTime.now();
          final groups = <TaskGroup, List<({DocTask task, Document doc})>>{};
          for (final r in rows) {
            groups
                .putIfAbsent(
                    taskGroup(r.task.dueAt, r.task.doneAt, now: now), () => [])
                .add(r);
          }
          // Erledigte: neueste zuerst.
          groups[TaskGroup.done]
              ?.sort((a, b) => b.task.doneAt!.compareTo(a.task.doneAt!));
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              for (final g in TaskGroup.values)
                if (groups[g]?.isNotEmpty ?? false) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      '${kTaskGroupLabels[g]} (${groups[g]!.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: g == TaskGroup.overdue
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  for (final r in groups[g]!)
                    TaskTile(
                      key: ValueKey(r.task.id),
                      task: r.task,
                      doc: r.doc,
                      onTap: () => _open(context, r.doc),
                      onQuickAction: (a) => _open(context, r.doc, action: a),
                      onEdit: () =>
                          showTaskEditor(context, doc: r.doc, task: r.task),
                    ),
                ],
            ],
          );
        },
      ),
    );
  }
}
