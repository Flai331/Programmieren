import 'dart:async';

import 'package:flutter/material.dart';

import 'app_picker_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';

/// Vier Schritte: Berechtigungen, Apps, Chip, Notfall-Code.
class SetupWizard extends StatefulWidget {
  const SetupWizard({
    super.key,
    required this.onFinished,
    this.channel = const RiegelChannel(),
  });

  final VoidCallback onFinished;
  final RiegelChannel channel;

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _step = 0;
  LockStatus? _status;
  String? _code;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = await widget.channel.getState();
    if (mounted) setState(() => _status = status);
  }

  /// Nach dem Anlernen wartet der Wizard darauf, dass die native Seite die UID meldet.
  void _startTagPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final status = await widget.channel.getState();
      if (!mounted) return;
      setState(() => _status = status);
      if (status.hasTag) timer.cancel();
    });
  }

  Future<void> _pickApps() async {
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(selected: _status?.blockedPackages ?? []),
      ),
    );
    if (picked != null) {
      await widget.channel.setBlockedPackages(picked);
      await _refresh();
    }
  }

  Future<void> _generateCode() async {
    final code = await widget.channel.generateCode();
    await _refresh();
    if (mounted) setState(() => _code = code);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Riegel einrichten')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () => setState(() => _step = (_step + 1).clamp(0, 3)),
        onStepCancel: () => setState(() => _step = (_step - 1).clamp(0, 3)),
        controlsBuilder: (context, details) => Row(
          children: [
            if (_step < 3)
              FilledButton(onPressed: details.onStepContinue, child: const Text('Weiter')),
            if (_step == 3)
              FilledButton(
                onPressed: status.setupComplete ? widget.onFinished : null,
                child: const Text('Fertig'),
              ),
            if (_step > 0)
              TextButton(onPressed: details.onStepCancel, child: const Text('Zurück')),
          ],
        ),
        steps: [
          Step(
            title: const Text('Berechtigungen'),
            isActive: _step >= 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Der Riegel braucht die Bedienungshilfe, um gesperrte Apps zu erkennen, '
                  'und den Geräteadministrator gegen Deinstallation.',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: widget.channel.openAccessibilitySettings,
                  child: const Text('Bedienungshilfe öffnen'),
                ),
                OutlinedButton(
                  onPressed: widget.channel.requestAdmin,
                  child: const Text('Geräteadministrator aktivieren'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Apps wählen'),
            isActive: _step >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${status.blockedPackages.length} Apps ausgewählt'),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _pickApps, child: const Text('Apps auswählen')),
              ],
            ),
          ),
          Step(
            title: const Text('Chip anlernen'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.hasTag ? 'Chip ist angelernt.' : 'Noch kein Chip angelernt.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    await widget.channel.startTagEnrollment();
                    _startTagPolling();
                  },
                  child: Text(status.hasTag ? 'Anderen Chip anlernen' : 'Chip anlernen'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Notfall-Code'),
            isActive: _step >= 3,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Der Code hebt eine Sperre auf, wenn der Chip nicht zur Hand ist. '
                  'Er wird nur dieses eine Mal angezeigt — aufschreiben.',
                ),
                const SizedBox(height: 12),
                if (_code != null)
                  SelectableText(
                    _code!,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                OutlinedButton(
                  onPressed: _generateCode,
                  child: Text(status.hasCode ? 'Neuen Code erzeugen' : 'Code erzeugen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
