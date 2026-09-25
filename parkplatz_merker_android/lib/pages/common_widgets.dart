import 'package:flutter/material.dart';

import 'help_page.dart';

/// Gemeinsamer Hilfe-Header für Einstellungs-Abschnitte
class SectionHeader extends StatelessWidget {
  final String text;
  final HelpTopic? help;

  const SectionHeader(this.text, {super.key, this.help});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 16, help == null ? 16 : 4, 4),
    child: Row(
      children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
        if (help != null)
          IconButton(
            tooltip: 'Anleitung',
            icon: const Icon(Icons.help_outline),
            onPressed: () => HelpPage.show(context, help),
          ),
      ],
    ),
  );
}

/// Berechtigungszugriff-Tile
class PermTile extends StatelessWidget {
  final String title;
  final String? hint;
  final bool ok;
  final VoidCallback? onFix;

  const PermTile({
    super.key,
    required this.title,
    required this.ok,
    this.hint,
    this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        ok ? Icons.check_circle : Icons.error_outline,
        color: ok ? Colors.green : scheme.error,
      ),
      title: Text(title),
      subtitle: hint == null ? null : Text(hint!),
      trailing: ok
          ? null
          : FilledButton(onPressed: onFix, child: const Text('Erlauben')),
    );
  }
}
