import 'package:flutter/material.dart';

import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

/// Auswahl der zu sperrenden Apps. Gibt die gewählten Paketnamen zurück.
class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({
    super.key,
    required this.selected,
    this.channel = const RiegelChannel(),
  });

  final List<String> selected;
  final RiegelChannel channel;

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<InstalledAppInfo>? _apps;
  late final Set<String> _selected = widget.selected.toSet();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apps = await widget.channel.launchableApps();
    if (mounted) setState(() => _apps = apps);
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apps sperren'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected.toList()),
            child: const Text('Fertig'),
          ),
        ],
      ),
      body: apps == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                final selected = _selected.contains(app.packageName);
                return Container(
                  // Ausgewählte Zeile wird getönt, nicht nur abgehakt — bei
                  // langen Listen sieht man die Auswahl sonst erst beim Scrollen.
                  color: selected ? RiegelColors.accentTint : null,
                  child: CheckboxListTile(
                    title: Text(
                      app.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: RiegelColors.fg1,
                      ),
                    ),
                    // Paketname bleibt sichtbar: bei doppelten Anzeigenamen ist
                    // er das einzige Unterscheidungsmerkmal.
                    subtitle: Text(
                      app.packageName,
                      style: const TextStyle(
                        fontFamily: kMonoFamily,
                        fontSize: 12,
                        color: RiegelColors.fg3,
                      ),
                    ),
                    value: selected,
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _selected.add(app.packageName);
                      } else {
                        _selected.remove(app.packageName);
                      }
                    }),
                  ),
                );
              },
            ),
    );
  }
}
