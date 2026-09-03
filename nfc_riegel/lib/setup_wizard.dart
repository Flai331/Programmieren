import 'dart:async';

import 'package:flutter/material.dart';

import 'app_picker_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

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

  /// Nach dem Anlernen wartet der Wizard darauf, dass die native Seite den Chip meldet.
  void _startTagPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final status = await widget.channel.getState();
      if (!mounted) return;
      setState(() => _status = status);
      if (status.tags.isNotEmpty) timer.cancel();
    });
  }

  /// Die App-Auswahl des Wizards gilt dem ersten Profil — mehr gibt es zu
  /// diesem Zeitpunkt noch nicht.
  Future<void> _pickApps() async {
    final profiles = _status?.profiles ?? const <ProfileInfo>[];
    if (profiles.isEmpty) return;
    final first = profiles.first;
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(
          selected: first.blockedPackages,
          channel: widget.channel,
        ),
      ),
    );
    if (picked != null) {
      await widget.channel.updateProfile(
        ProfileInfo(
          id: first.id,
          name: first.name,
          blockedPackages: picked,
          mode: first.mode,
          durationMinutes: first.durationMinutes,
          untilAt: first.untilAt,
          pinCalendarEnd: first.pinCalendarEnd,
          pauseEnabled: first.pauseEnabled,
          pauseStepMinutes: first.pauseStepMinutes,
          pauseBaseSeconds: first.pauseBaseSeconds,
          pauseResetMinutes: first.pauseResetMinutes,
          quietEnabled: first.quietEnabled,
          quietScope: first.quietScope,
          quietNumbers: first.quietNumbers,
          quietAfterEventMinutes: first.quietAfterEventMinutes,
          quietWhileLocked: first.quietWhileLocked,
          quietSchedules: first.quietSchedules,
        ),
      );
      await _refresh();
    }
  }

  Future<void> _generateCode() async {
    final code = await widget.channel.generateCode();
    await _refresh();
    if (mounted && code != null) setState(() => _code = code);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final blockedCount = status.profiles.isEmpty
        ? 0
        : status.profiles.first.blockedPackages.length;

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
                Text('$blockedCount Apps ausgewählt'),
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
                Text(
                  status.tags.isNotEmpty
                      ? 'Chip ist angelernt.'
                      : 'Noch kein Chip angelernt.',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    final profileId = status.profiles.isEmpty
                        ? ''
                        : status.profiles.first.id;
                    await widget.channel.startTagEnrollment(
                      label: 'Chip 1',
                      profileId: profileId,
                      isMaster: true,
                    );
                    _startTagPolling();
                  },
                  child: Text(
                    status.tags.isEmpty ? 'Chip anlernen' : 'Weiteren Chip anlernen',
                  ),
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
                const SizedBox(height: RiegelSpacing.s3),
                if (_code != null) ...[
                  _CodePlate(code: _code!),
                  const SizedBox(height: RiegelSpacing.s3),
                ],
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

/// Der Notfall-Code steht auf gestricheltem Rahmen: die Umrandung signalisiert
/// „zum Abschreiben", nicht „fertiger Inhalt". Mono mit weitem Buchstabenabstand,
/// damit sich beim Übertragen keine Zeichen verschlucken.
class _CodePlate extends StatelessWidget {
  const _CodePlate({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(RiegelSpacing.s5),
        child: Column(
          children: [
            SelectableText(
              code,
              style: const TextStyle(
                fontFamily: kMonoFamily,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: 4.5,
                color: RiegelColors.accent,
              ),
            ),
            const SizedBox(height: RiegelSpacing.s2),
            const Text(
              'Jetzt abschreiben — danach ist er weg',
              style: TextStyle(fontSize: 12, color: RiegelColors.fg3),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RiegelColors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(RiegelRadii.lg),
    );

    // Pfad in kurze Striche zerlegen: 6 px Strich, 4 px Lücke.
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
