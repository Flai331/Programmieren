import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';
import 'setup_wizard.dart';

void main() => runApp(const RiegelApp());

class RiegelApp extends StatelessWidget {
  const RiegelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riegel',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const _Entry(),
    );
  }
}

/// Entscheidet beim Start zwischen Einrichtung und Hauptscreen.
class _Entry extends StatefulWidget {
  const _Entry();

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  final _channel = const RiegelChannel();
  LockStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await _channel.getState();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return status.setupComplete
        ? const HomeScreen()
        : SetupWizard(onFinished: _load);
  }
}
