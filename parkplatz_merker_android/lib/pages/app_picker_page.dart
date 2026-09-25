import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../native.dart';

class AppPickerPage extends StatefulWidget {
  final bool returnSelection;

  const AppPickerPage({super.key, this.returnSelection = false});

  @override
  State<AppPickerPage> createState() => _AppPickerPageState();
}

class _AppPickerPageState extends State<AppPickerPage> {
  List<Map<String, String>> _apps = [];
  List<Map<String, String>> _filtered = [];
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final apps = await NativeBridge.listApps();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _filtered = apps;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _updateSearch(String query) {
    setState(() {
      _search = query.toLowerCase();
      _filtered = _apps
          .where((app) {
            final label = (app['label'] ?? '').toLowerCase();
            return label.contains(_search);
          })
          .toList();
    });
  }

  void _selectApp(String? pkg, String? label) async {
    if (widget.returnSelection) {
      if (!mounted) return;
      Navigator.pop(context, {'package': pkg, 'label': label});
    } else {
      final controller = context.read<AppController>();
      await controller.updateConfig(
        launchPackage: pkg ?? '',
        launchLabel: label ?? '',
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App wählen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'App suchen …',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: _updateSearch,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        title: const Text('Keine App'),
                        onTap: () => _selectApp(null, null),
                      ),
                      ..._filtered.map((app) {
                        final pkg = app['package'] ?? '';
                        final label = app['label'] ?? '';
                        return ListTile(
                          title: Text(label),
                          subtitle: Text(pkg),
                          onTap: () => _selectApp(pkg, label),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
