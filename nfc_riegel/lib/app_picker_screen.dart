import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

/// Auswahl der zu sperrenden Apps. Gibt die gewählten Paketnamen zurück.
class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key, required this.selected});

  final List<String> selected;

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<AppInfo>? _apps;
  late Set<String> _selected = widget.selected.toSet();

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
                return CheckboxListTile(
                  title: Text(app.name),
                  subtitle: Text(app.packageName),
                  value: _selected.contains(app.packageName),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _selected.add(app.packageName);
                    } else {
                      _selected.remove(app.packageName);
                    }
                  }),
                );
              },
            ),
    );
  }
}
