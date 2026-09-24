import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../logic/economy.dart';
import '../model/genre.dart';
import '../state/city_store.dart';

class StoreScope extends InheritedNotifier<CityStore> {
  const StoreScope({super.key, required CityStore store, required super.child})
    : super(notifier: store);

  static CityStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Ohne Abhängigkeit, für Aufrufe in Callbacks.
  static CityStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

final datumFormat = DateFormat('d.M.yyyy', 'de');
final monatFormat = DateFormat('MMMM yyyy', 'de');
final zahlFormat = NumberFormat.decimalPattern('de');

class MatChip extends StatelessWidget {
  const MatChip(this.mat, this.menge, {super.key, this.fehlt = false});
  final Mat mat;
  final int menge;
  final bool fehlt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: fehlt ? Border.all(color: theme.colorScheme.error) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: mat.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black26),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${zahlFormat.format(menge)} ${mat.label}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: fehlt ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

class MaterialsWrap extends StatelessWidget {
  const MaterialsWrap(
    this.materials, {
    super.key,
    this.inventar,
    this.hideZero = true,
  });
  final Materials materials;

  /// Wenn gesetzt, wird Fehlendes rot markiert.
  final Materials? inventar;
  final bool hideZero;

  @override
  Widget build(BuildContext context) {
    final items = Mat.values
        .where((m) => !hideZero || (materials[m] ?? 0) != 0)
        .toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in items)
          MatChip(
            m,
            materials[m] ?? 0,
            fehlt:
                inventar != null && (inventar![m] ?? 0) < (materials[m] ?? 0),
          ),
      ],
    );
  }
}

class GenreChips extends StatelessWidget {
  const GenreChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final List<Genre> selected;
  final ValueChanged<List<Genre>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final g in Genre.values)
          FilterChip(
            label: Text(g.label),
            avatar: CircleAvatar(backgroundColor: g.material.color, radius: 6),
            selected: selected.contains(g),
            onSelected: (on) => onChanged(
              on ? [...selected, g] : selected.where((x) => x != g).toList(),
            ),
          ),
      ],
    );
  }
}

IconData statusIcon(BookStatus s) => switch (s) {
  BookStatus.wunsch => Icons.bookmark_border,
  BookStatus.lesend => Icons.menu_book,
  BookStatus.beendet => Icons.check_circle_outline,
};

void showSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
