import 'package:flutter/material.dart';

import '../logic/economy.dart';
import '../model/catalog.dart';
import 'common.dart';

/// Liste aller baubaren Gebäude. Gibt den gewählten Typ zurück, die Stadt
/// fragt dann nach dem Bauplatz.
class BuildMenuScreen extends StatelessWidget {
  const BuildMenuScreen({super.key});

  static const _titel = {
    Kategorie.grund: 'Grundgebäude',
    Kategorie.genre: 'Genre-Gebäude',
    Kategorie.kombi: 'Kombi-Gebäude',
  };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final inv = store.inventar;
    final stufe = store.stufe;
    final theme = Theme.of(context);
    final gebaut = <String, int>{};
    for (final b in store.buildings) {
      gebaut[b.typeId] = (gebaut[b.typeId] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Baumenü')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(padding: const EdgeInsets.all(16), child: MaterialsWrap(inv)),
          for (final kat in _titel.keys) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(_titel[kat]!, style: theme.textTheme.titleMedium),
            ),
            for (final typ in catalog.where((t) => t.kategorie == kat))
              _TypTile(
                typ: typ,
                inv: inv,
                gesperrt: typ.abStufe.index > stufe.index,
                anzahl: gebaut[typ.id] ?? 0,
                gepinnt: store.gepinnt == typ.id,
              ),
          ],
        ],
      ),
    );
  }
}

class _TypTile extends StatelessWidget {
  const _TypTile({
    required this.typ,
    required this.inv,
    required this.gesperrt,
    required this.anzahl,
    required this.gepinnt,
  });

  final BuildingType typ;
  final Materials inv;
  final bool gesperrt;
  final int anzahl;
  final bool gepinnt;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final bezahlbar = canAfford(inv, typ);
    final sub = [
      if (typ.genre != null) typ.genre!.label,
      if (gesperrt) 'ab ${typ.abStufe.label}',
      if (anzahl > 0) '$anzahl× gebaut',
    ].join(' · ');
    return Opacity(
      opacity: gesperrt ? 0.5 : 1,
      child: ListTile(
        title: Text(typ.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sub.isNotEmpty) Text(sub),
            const SizedBox(height: 4),
            MaterialsWrap(typ.kosten, inventar: inv),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: gepinnt ? 'Ziel lösen' : 'Als Nahziel anheften',
              icon: Icon(gepinnt ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => store.pin(gepinnt ? null : typ.id),
            ),
            FilledButton(
              onPressed: !gesperrt && bezahlbar
                  ? () => Navigator.pop(context, typ)
                  : null,
              child: const Text('Bauen'),
            ),
          ],
        ),
      ),
    );
  }
}
