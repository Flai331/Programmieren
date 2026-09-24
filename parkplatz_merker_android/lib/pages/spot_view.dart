import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../logic/format.dart';
import '../logic/models.dart';
import '../native.dart';

/// Karte und Details eines Parkplatzes (Startseite und Verlauf).
class SpotView extends StatelessWidget {
  final ParkingSpot spot;
  final LocSample? myLocation;

  /// Wird nach „Falsch erkannt“ aufgerufen (z. B. Detailseite schließen).
  final VoidCallback? onDeleted;

  const SpotView({
    super.key,
    required this.spot,
    this.myLocation,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final carPoint = LatLng(spot.lat, spot.lng);
    final me = myLocation;
    final distance = me == null
        ? null
        : haversineMeters(me.lat, me.lng, spot.lat, spot.lng);
    final reminderAt = spot.reminderAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          headline(spot, DateTime.now()),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              // Neuer Parkplatz → Karte neu zentrieren.
              key: ValueKey('${spot.id}-${spot.lat}-${spot.lng}'),
              options: MapOptions(initialCenter: carPoint, initialZoom: 17),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.klaasotte.parkplatz_merker',
                ),
                MarkerLayer(
                  markers: [
                    if (me != null)
                      Marker(
                        point: LatLng(me.lat, me.lng),
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    Marker(
                      point: carPoint,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.directions_car,
                          color: theme.colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap-Mitwirkende'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.place,
          text: spot.address ?? 'Adresse wird gesucht …',
        ),
        _InfoRow(icon: Icons.gps_fixed, text: accuracyText(spot.acc)),
        if (distance != null)
          _InfoRow(
            icon: Icons.directions_walk,
            text: 'Entfernung: ${formatDistance(distance)}',
          ),
        _InfoRow(
          icon: Icons.sensors,
          text: 'erkannt über: ${spot.sourceLabel}',
        ),
        if (reminderAt != null)
          _InfoRow(
            icon: Icons.alarm,
            text:
                'Parkschein bis ${formatClock(DateTime.fromMillisecondsSinceEpoch(reminderAt))}'
                ' · Erinnerung ${formatClock(DateTime.fromMillisecondsSinceEpoch(reminderAt - 15 * 60 * 1000))}',
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () async {
            final ok = await NativeBridge.openNavigation(spot.lat, spot.lng);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Keine Karten-App gefunden')),
              );
            }
          },
          icon: const Icon(Icons.navigation),
          label: const Text('Navigation zum Auto'),
        ),
        const SizedBox(height: 16),
        if (spot.note != null && spot.note!.trim().isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.sticky_note_2_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(spot.note!, style: theme.textTheme.bodyLarge),
                  ),
                ],
              ),
            ),
          ),
        if (spot.photoPath != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    child: Image.file(File(spot.photoPath!)),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(spot.photoPath!),
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Text('Foto nicht gefunden'),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _editNote(context),
              icon: const Icon(Icons.edit_note),
              label: const Text('Notiz'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _photoSheet(context),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Foto'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _ticket(context),
              icon: const Icon(Icons.alarm),
              label: const Text('Parkschein'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Falsch erkannt'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editNote(BuildContext context) async {
    final controller = context.read<AppController>();
    final text = TextEditingController(text: spot.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notiz'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'z. B. Parkhaus Ebene 3, Platz 112',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, text.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result != null) await controller.setNote(spot.id, result.trim());
  }

  Future<void> _photoSheet(BuildContext context) async {
    final controller = context.read<AppController>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (spot.photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Foto entfernen'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      await controller.removePhoto(spot.id);
      return;
    }
    try {
      final image = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (image == null) return;
      // Alten Foto-Pfad erst nach dem Speichern des neuen löschen.
      final old = spot.photoPath;
      final saved = await controller.storage.savePhoto(
        '${spot.id}-${DateTime.now().millisecondsSinceEpoch}',
        File(image.path),
      );
      if (saved == null) throw Exception('Speichern fehlgeschlagen');
      await controller.setPhoto(spot.id, saved);
      if (old != null) await controller.storage.deletePhoto(old);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Foto nicht möglich: $e')));
      }
    }
  }

  Future<void> _ticket(BuildContext context) async {
    final controller = context.read<AppController>();
    if (spot.reminderAt != null) {
      final clear = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Parkschein'),
          content: Text(
            'Parkschein bis ${formatClock(DateTime.fromMillisecondsSinceEpoch(spot.reminderAt!))}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Neue Uhrzeit'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Erinnerung löschen'),
            ),
          ],
        ),
      );
      if (clear == null) return;
      if (clear) {
        await controller.clearReminder(spot.id);
        return;
      }
      if (!context.mounted) return;
    }
    final time = await showTimePicker(
      context: context,
      helpText: 'Parkschein gültig bis',
      initialTime: TimeOfDay.fromDateTime(
        DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;
    final now = DateTime.now();
    var until = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (until.isBefore(now)) until = until.add(const Duration(days: 1));
    final error = await controller.setReminder(spot.id, until);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Parkschein bis ${formatClock(until)} · Erinnerung um '
                  '${formatClock(until.subtract(const Duration(minutes: 15)))}',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final controller = context.read<AppController>();
    final ok = await showDialog<bool>(
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
    );
    if (ok != true) return;
    await controller.deleteSpot(spot.id);
    onDeleted?.call();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
