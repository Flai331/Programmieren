import 'package:flutter/material.dart';

import '../logic/progress.dart';
import 'common.dart';

class YearScreen extends StatelessWidget {
  const YearScreen({super.key});

  Future<void> _zielSetzen(BuildContext context, int jahr, int? aktuell) async {
    final c = TextEditingController(text: aktuell?.toString() ?? '12');
    final ziel = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Jahresziel $jahr'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Bücher',
            helperText: 'So viele Bauabschnitte bekommt das Bauwerk.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(c.text);
              if (n != null && n > 0) Navigator.pop(ctx, n);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    c.dispose();
    if (ziel != null && context.mounted) {
      await StoreScope.read(context).setYearGoal(jahr, ziel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final jahr = store.now.year;
    final goal = store.goalFor(jahr);
    final vergangene = store.yearGoals.where((g) => g.jahr < jahr).toList()
      ..sort((a, b) => b.jahr.compareTo(a.jahr));

    return Scaffold(
      appBar: AppBar(title: const Text('Jahresprojekt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (goal == null) ...[
            Text('Jahresprojekt $jahr', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Leg fest, wie viele Bücher du dieses Jahr lesen willst. Das Bauwerk bekommt genau so viele Bauabschnitte, jedes beendete Buch fügt einen hinzu.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.flag),
              label: const Text('Jahresziel festlegen'),
              onPressed: () => _zielSetzen(context, jahr, null),
            ),
          ] else
            _YearCard(
              progress: yearProgress(jahr, goal.zielBuecher, store.books),
              aktuell: true,
              onEdit: () => _zielSetzen(context, jahr, goal.zielBuecher),
            ),
          if (vergangene.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Denkmäler vergangener Jahre',
              style: theme.textTheme.titleMedium,
            ),
            for (final g in vergangene)
              _YearCard(
                progress: yearProgress(g.jahr, g.zielBuecher, store.books),
              ),
          ],
        ],
      ),
    );
  }
}

class _YearCard extends StatelessWidget {
  const _YearCard({required this.progress, this.aktuell = false, this.onEdit});
  final YearProgress progress;
  final bool aktuell;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = progress;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Jahresbauwerk ${p.jahr}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Ziel ändern',
                    icon: const Icon(Icons.edit),
                    onPressed: onEdit,
                  ),
              ],
            ),
            Text(
              '${p.beendet.length} von ${p.ziel} Büchern'
              '${p.fertig
                  ? ' – fertig gebaut!'
                  : aktuell
                  ? ' – noch ${p.ziel - p.beendet.length}'
                  : ''}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var i = 0; i < p.ziel; i++)
                  Tooltip(
                    message: i < p.beendet.length
                        ? p.beendet[i].titel
                        : 'Abschnitt ${i + 1}',
                    child: Container(
                      width: 26,
                      height: 18,
                      decoration: BoxDecoration(
                        color: i < p.abschnitte
                            ? const Color(0xFFD7B56D)
                            : Colors.transparent,
                        border: Border.all(color: const Color(0xFFB8964F)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
            if (p.extras.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Übererfüllt um ${p.uebererfuellt}: '
                '${p.extras.map((e) => e.label).join(', ')}',
              ),
            ],
            if (p.beendet.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final (i, b) in p.beendet.indexed)
                Text(
                  '${i + 1}. ${b.titel} (${datumFormat.format(b.beendetAm!)})',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
