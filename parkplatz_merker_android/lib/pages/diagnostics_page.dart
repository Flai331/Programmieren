import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../logic/diagnostics.dart';
import '../logic/detection.dart';
import '../native.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({Key? key}) : super(key: key);

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  String _diagnosticText = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    final controller = context.read<AppController>();
    await controller.refresh();
    await controller.reloadConfig();
    final nativeStatus = await NativeBridge.getNativeStatus();
    final config = controller.config;
    final events = controller.events;

    // Berechtigungen
    final permissions = <String, String>{};
    permissions['Standort (wenn in Nutzung)'] =
        await Permission.locationWhenInUse.isDenied
        ? 'Verweigert'
        : (await Permission.locationWhenInUse.isGranted
              ? 'Gewährt'
              : 'Unbekannt');
    permissions['Standort (immer)'] = await Permission.locationAlways.isDenied
        ? 'Verweigert'
        : (await Permission.locationAlways.isGranted ? 'Gewährt' : 'Unbekannt');
    permissions['Aktivitätserkennung'] =
        await Permission.activityRecognition.isDenied
        ? 'Verweigert'
        : (await Permission.activityRecognition.isGranted
              ? 'Gewährt'
              : 'Unbekannt');
    permissions['Bluetooth'] = await Permission.bluetoothScan.isDenied
        ? 'Verweigert'
        : (await Permission.bluetoothScan.isGranted ? 'Gewährt' : 'Unbekannt');
    permissions['Benachrichtigungen'] = await Permission.notification.isDenied
        ? 'Verweigert'
        : (await Permission.notification.isGranted ? 'Gewährt' : 'Unbekannt');

    // Trip-Ergebnisse
    final now = DateTime.now().millisecondsSinceEpoch;
    final tripResults = evaluateTrips(events, now);

    // Text zusammenstellen
    final text = buildDiagnosticText(
      events: events,
      permissions: permissions,
      nativeStatus: nativeStatus,
      config: config,
      tripResults: tripResults,
    );

    if (mounted) {
      setState(() {
        _diagnosticText = text;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnose'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              _copyToClipboard();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _diagnosticText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
    );
  }

  void _copyToClipboard() async {
    // Auf Clipboard kopieren
    final data = ClipboardData(text: _diagnosticText);
    await Clipboard.setData(data);

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Diagnose kopiert')));
  }
}
