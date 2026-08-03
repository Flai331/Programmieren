import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'theme.dart';

/// Auswahl der zu sperrenden Apps. Gibt die gewählten Paketnamen zurück.
class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key, required this.selected});

  final List<String> selected;

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<AppInfo>? _apps;
  late final Set<String> _selected = widget.selected.toSet();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apps = await InstalledApps.getInstalledApps(true, true);
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
