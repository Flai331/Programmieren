import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../logic/format.dart';
import 'spot_view.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verlauf')),
      body: Consumer<AppController>(
        builder: (context, controller, _) {
          final spots = controller.spots;

          if (spots.isEmpty) {
            return const Center(child: Text('Kein Verlauf'));
          }

          return ListView.builder(
            itemCount: spots.length,
            itemBuilder: (context, index) {
              final spot = spots[index];
              final dt = DateTime.fromMillisecondsSinceEpoch(spot.time);
              final dateStr = formatDateTime(dt);
              final address =
                  spot.address ??
                  '${spot.lat.toStringAsFixed(4)}, ${spot.lng.toStringAsFixed(4)}';

              return Dismissible(
                key: Key(spot.id),
                confirmDismiss: (_) => showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Falsch erkannt?'),
                    content: const Text('Diesen Eintrag löschen?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Abbrechen'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Löschen'),
                      ),
                    ],
                  ),
                ),
                onDismissed: (direction) {
                  controller.deleteSpot(spot.id);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Gelöscht')));
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                ),
                child: ListTile(
                  title: Text(dateStr),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(address),
                      Text(
                        spot.sourceLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever),
                    onPressed: () {
                      _showDeleteConfirmation(context, controller, spot.id);
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _SpotDetailPage(id: spot.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AppController controller,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Löschen?'),
        content: const Text('Diesen Eintrag wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              controller.deleteSpot(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Gelöscht')));
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}

/// Detailseite; liest den Eintrag live aus dem Controller (Notiz/Foto aktuell).
class _SpotDetailPage extends StatelessWidget {
  final String id;
  const _SpotDetailPage({required this.id});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final spot = controller.spotById(id);
    return Scaffold(
      appBar: AppBar(title: const Text('Parkplatz')),
      body: spot == null
          ? const Center(child: Text('Eintrag gelöscht'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SpotView(
                spot: spot,
                myLocation: controller.myLocation,
                onDeleted: () => Navigator.of(context).maybePop(),
              ),
            ),
    );
  }
}
