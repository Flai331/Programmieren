import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../controller.dart';
import '../logic/models.dart';
import '../logic/format.dart';
import '../storage.dart';

class SpotView extends StatefulWidget {
  final ParkingSpot spot;
  final LocSample? myLocation;

  const SpotView({
    Key? key,
    required this.spot,
    this.myLocation,
  }) : super(key: key);

  @override
  State<SpotView> createState() => _SpotViewState();
}

class _SpotViewState extends State<SpotView> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final now = DateTime.now();
    final headlineText = headline(spot, now);
    final accuracy = accuracyText(spot.acc);

    double? distance;
    if (widget.myLocation != null) {
      distance = haversineMeters(
        widget.myLocation!.lat,
        widget.myLocation!.lng,
        spot.lat,
        spot.lng,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Überschrift
        Text(
          headlineText,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        // Karte
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(spot.lat, spot.lng),
                initialZoom: 17,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.klaasotte.parkplatz_merker',
                ),
                MarkerLayer(
                  markers: [
                    // Auto-Marker
                    Marker(
                      point: LatLng(spot.lat, spot.lng),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: Icon(
                          Icons.directions_car,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                    // Eigener Standort-Marker (falls bekannt)
                    if (widget.myLocation != null)
                      Marker(
                        point: LatLng(
                          widget.myLocation!.lat,
                          widget.myLocation!.lng,
                        ),
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap-Mitwirkende',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Adresse
        if (spot.address != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              spot.address!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Adresse wird gesucht …',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

        // Genauigkeit
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(accuracy),
        ),

        // Entfernung
        if (distance != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Entfernung: ${formatDistance(distance)}'),
          ),

        // Quellen
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Erkannt über: ${spot.sourceLabel}'),
        ),
        const SizedBox(height: 16),

        // Navigation
        FilledButton.icon(
          onPressed: () async {
            final success = await context
                .read<AppController>()
                .parkHere(); // Sollte openNavigation sein
            if (!context.mounted) return;
            if (success != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Keine Karten-App gefunden'),
                ),
              );
            }
          },
          icon: const Icon(Icons.navigation),
          label: const Text('Navigation zum Auto'),
        ),
        const SizedBox(height: 16),

        // Notiz
        if (spot.note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(spot.note!),
              ),
            ),
          ),

        // Foto
        if (spot.photoPath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: Image.file(File(spot.photoPath!)),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(spot.photoPath!), height: 200),
              ),
            ),
          ),

        // Knöpfe
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () {
                _showNoteDialog(context, spot);
              },
              icon: const Icon(Icons.note),
              label: const Text('Notiz'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                _showPhotoSheet(context, spot);
              },
              icon: const Icon(Icons.photo),
              label: const Text('Foto'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                _showReminderDialog(context, spot);
              },
              icon: const Icon(Icons.alarm),
              label: const Text('Parkschein'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Falsch erkannt
        TextButton.icon(
          onPressed: () {
            _showDeleteConfirmation(context, spot.id);
          },
          icon: const Icon(Icons.delete_forever),
          label: const Text('Falsch erkannt'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
      ],
    );
  }

  void _showNoteDialog(BuildContext context, ParkingSpot spot) {
    final controller = TextEditingController(text: spot.note ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notiz'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'z. B. Parkhaus Ebene 3, Platz 112',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppController>().setNote(spot.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showPhotoSheet(BuildContext context, ParkingSpot spot) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () async {
                Navigator.pop(context);
                final image = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1600,
                  imageQuality: 80,
                );
                if (image != null && context.mounted) {
                  final photoPath =
                      await context.read<Storage>().savePhoto(spot.id, File(image.path));
                  if (photoPath != null) {
                    context.read<AppController>().setPhoto(spot.id, photoPath);
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () async {
                Navigator.pop(context);
                final image = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1600,
                  imageQuality: 80,
                );
                if (image != null && context.mounted) {
                  final photoPath =
                      await context.read<Storage>().savePhoto(spot.id, File(image.path));
                  if (photoPath != null) {
                    context.read<AppController>().setPhoto(spot.id, photoPath);
                  }
                }
              },
            ),
            if (spot.photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Foto entfernen'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<AppController>().removePhoto(spot.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showReminderDialog(BuildContext context, ParkingSpot spot) async {
    final initialTime = TimeOfDay.now();
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (!context.mounted) return;

    if (time != null) {
      final now = DateTime.now();
      final reminderTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      final nextDay = reminderTime.isBefore(now);
      final until = nextDay ? reminderTime.add(const Duration(days: 1)) : reminderTime;

      final error = await context.read<AppController>().setReminder(spot.id, until);

      if (!context.mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Parkschein bis ${formatClock(until)} · Erinnerung ${formatClock(until.subtract(const Duration(minutes: 15)))}',
            ),
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Löschen?'),
        content: const Text('Diesen Eintrag löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppController>().deleteSpot(id);
              Navigator.pop(context);
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}
