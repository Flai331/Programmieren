import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../logic/diagnostics.dart';
import '../native.dart';

class RoutineTestPage extends StatefulWidget {
  const RoutineTestPage({super.key});

  @override
  State<RoutineTestPage> createState() => _RoutineTestPageState();
}

class _RoutineTestPageState extends State<RoutineTestPage> {
  int _intervalSeconds = 10;
  bool _testing = false;

  final _steps = <_TestStep>[];
  String _resultText = '';
  bool _resultReady = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final config = controller.config;
    final launchApps = ((config['launchApps'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final volumeEnabled = (config['volumeEnabled'] as bool?) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Ganze Routine testen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.inverseSurface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Der Test spielt eine echte Fahrt nach (wie in deinen Protokollen): Transmitter gefunden, ein kurzer Aussetzer, wieder gefunden, beim Aussteigen weg. '
                'Du musst nicht im Auto sein.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abstand zwischen den Suchen',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 5, label: Text('5 s')),
                    ButtonSegment(value: 10, label: Text('10 s')),
                    ButtonSegment(value: 20, label: Text('20 s')),
                  ],
                  selected: {_intervalSeconds},
                  onSelectionChanged: _testing
                      ? null
                      : (sel) => setState(() => _intervalSeconds = sel.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _testing ? null : () => _runTest(controller, config, launchApps, volumeEnabled),
            child: const Text('Test starten'),
          ),
          if (_steps.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            for (final step in _steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildStepRow(step),
              ),
            if (_resultReady) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resultText.contains('Alles in Ordnung') ? 'Alles in Ordnung ✓' : 'Prüfe folgende Punkte',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => _copyResult(),
                      child: const Text('Ergebnis kopieren'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(_TestStep step) {
    final isError = step.status == 'error';
    final isSkipped = step.status == 'skipped';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: step.status == 'running'
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                    ),
                  )
                : isError
                    ? Text('✗', style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.error))
                    : isSkipped
                        ? const Text('–', style: TextStyle(fontSize: 20))
                        : Text('✓', style: TextStyle(fontSize: 20, color: Colors.green[600])),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (step.detail.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    step.detail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _runTest(
    AppController controller,
    Map<String, dynamic> config,
    List<Map<String, dynamic>> launchApps,
    bool volumeEnabled,
  ) async {
    setState(() {
      _testing = true;
      _steps.clear();
      _resultText = '';
      _resultReady = false;
    });

    final testStart = DateTime.now().millisecondsSinceEpoch;
    bool allOk = true;

    try {
      // 1. Transmitter gefunden (RSSI −51)
      await _addStep('Transmitter gefunden (RSSI −51)', 'running', '');
      await NativeBridge.fakeDeviceSeen();
      await Future.delayed(const Duration(seconds: 6));
      if (!mounted) return;
      await controller.refresh();
      if (!mounted) return;

      final infoEvents = controller.events
          .where((e) => e.t >= testStart && e.type == 'info')
          .toList();

      bool allAppsOpened = true;
      String appDetail = '';

      if (launchApps.isEmpty) {
        _updateLastStep('Transmitter gefunden (RSSI −51)', 'ok', 'Keine Apps eingerichtet');
      } else {
        for (final app in launchApps) {
          final label = app['label'] as String?;
          final searchMsg = 'App geöffnet: $label';
          final found = infoEvents.any((e) => (e.str('msg') ?? '').contains(searchMsg));

          if (!found) {
            allAppsOpened = false;
            final hint = infoEvents.any((e) => (e.str('msg') ?? '').contains('Hinweis gezeigt'));
            appDetail = hint
                ? '$label: nur Benachrichtigung – „Über anderen Apps einblenden“ erlauben'
                : '$label wurde nicht geöffnet (siehe Ergebnis-Protokoll)';
            break;
          }
        }

        if (allAppsOpened) {
          String volumeDetail = '';
          if (volumeEnabled) {
            final volumeApplied = infoEvents.any((e) => (e.str('msg') ?? '').contains('Lautstärke-Profil angewendet'));
            if (volumeApplied) {
              volumeDetail = ' + Lautstärke-Profil angewendet';
            } else {
              allAppsOpened = false;
              appDetail = 'Lautstärke-Profil nicht angewendet';
            }
          }

          if (allAppsOpened) {
            _updateLastStep('Transmitter gefunden (RSSI −51)', 'ok', 'App(s) geöffnet$volumeDetail');
          } else {
            _updateLastStep('Transmitter gefunden (RSSI −51)', 'error', appDetail);
            allOk = false;
          }
        } else {
          _updateLastStep('Transmitter gefunden (RSSI −51)', 'error', appDetail);
          allOk = false;
        }
      }

      // 2. Abstand + Suche: nicht gefunden
      await _showCountdown(_intervalSeconds, 'Abstand');
      if (!mounted) return;

      await _addStep('Suche: nicht gefunden (einzelner Aussetzer)', 'running', '');
      await NativeBridge.fakeScan(false, 0);
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      await controller.refresh();
      if (!mounted) return;

      bool aussetzerIgnored = true;
      const endSessionMsg = 'Im Auto: Sitzung endet';
      final sessionEndEvent = controller.events
          .where((e) => e.t > testStart && e.type == 'info' && (e.str('msg') ?? '').contains(endSessionMsg))
          .firstOrNull;

      if (sessionEndEvent != null) {
        aussetzerIgnored = false;
      }

      bool allAppsStillRunning = true;
      // Nur prüfbar, wenn die Apps in Schritt 1 wirklich aufgegangen sind.
      if (launchApps.isNotEmpty && allAppsOpened) {
        for (final app in launchApps) {
          final pkg = app['package'] as String?;
          final isRunning = await NativeBridge.appRunning(pkg ?? '');
          if (!mounted) return;
          if (!isRunning) {
            allAppsStillRunning = false;
            break;
          }
        }
      }

      if (aussetzerIgnored && allAppsStillRunning) {
        _updateLastStep('Suche: nicht gefunden (einzelner Aussetzer)', 'ok', 'Aussetzer ignoriert, Apps bleiben offen');
      } else {
        _updateLastStep('Suche: nicht gefunden (einzelner Aussetzer)', 'error',
            sessionEndEvent != null ? 'Sitzung wurde beim ersten Aussetzer beendet' : 'Eine App lief nach dem Aussetzer nicht mehr');
        allOk = false;
      }

      // 3. Abstand + Suche: gefunden (RSSI −47)
      await _showCountdown(_intervalSeconds, 'Abstand');
      if (!mounted) return;

      await _addStep('Suche: gefunden (RSSI −47)', 'running', '');
      await NativeBridge.fakeScan(true, -47);
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      await controller.refresh();
      if (!mounted) return;

      const appOpenedMsg = 'App geöffnet:';
      final appOpenedEvents = controller.events
          .where((e) => e.t > testStart && e.type == 'info' && (e.str('msg') ?? '').contains(appOpenedMsg))
          .toList();

      bool noReopen = appOpenedEvents.length <= launchApps.length;

      if (noReopen) {
        _updateLastStep('Suche: gefunden (RSSI −47)', 'ok', 'Transmitter wieder da');
      } else {
        _updateLastStep('Suche: gefunden (RSSI −47)', 'error', 'Apps wurden erneut geöffnet');
        allOk = false;
      }

      // 4. Abstand + Suche: gefunden (RSSI −49)
      await _showCountdown(_intervalSeconds, 'Abstand');
      if (!mounted) return;

      await _addStep('Suche: gefunden (RSSI −49)', 'running', '');
      await NativeBridge.fakeScan(true, -49);
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      _updateLastStep('Suche: gefunden (RSSI −49)', 'ok', '');

      // 5. Abstand + Aussteigen
      await _showCountdown(
        _intervalSeconds,
        'Prüf jetzt: Apps offen? Lautstärke? Energiesparmodus aus (Samsung-Routine)?',
      );
      if (!mounted) return;

      await _addStep('Aussteigen: Transmitter weg (Motor aus)', 'running', '');
      await NativeBridge.fakeDeviceGone();
      await Future.delayed(const Duration(seconds: 6));
      if (!mounted) return;
      await controller.refresh();
      if (!mounted) return;

      bool allAppsClosed = true;
      String closeDetail = '';

      if (launchApps.isEmpty) {
        _updateLastStep('Aussteigen: Transmitter weg (Motor aus)', 'ok', '–');
      } else {
        for (final app in launchApps) {
          final pkg = app['package'] as String?;
          final isRunning = await NativeBridge.appRunning(pkg ?? '');
          if (!mounted) return;

          if (isRunning) {
            allAppsClosed = false;
            final closeEvents = controller.events
                .where((e) => e.t >= testStart && e.type == 'info')
                .toList();
            for (final event in closeEvents) {
              final msg = event.str('msg') ?? '';
              if (msg.contains('Ausschaltknopf von') || msg.contains('Widget-Knopf')) {
                closeDetail = msg;
                break;
              }
            }
            if (closeDetail.isEmpty) {
              closeDetail = 'läuft noch';
            }
            break;
          }
        }

        if (allAppsClosed) {
          String volumeRestore = '';
          if (volumeEnabled && (config['volumeRestore'] as bool?) == true) {
            final volumeRestored = controller.events
                .where((e) => e.t >= testStart && e.type == 'info')
                .any((e) => (e.str('msg') ?? '').contains('Lautstärke-Profil zurückgesetzt'));
            if (volumeRestored) {
              volumeRestore = ' + Lautstärke-Profil zurückgesetzt';
            }
          }
          _updateLastStep('Aussteigen: Transmitter weg (Motor aus)', 'ok', 'App(s) beendet$volumeRestore');
        } else {
          _updateLastStep('Aussteigen: Transmitter weg (Motor aus)', 'error', closeDetail);
          allOk = false;
        }
      }

      // 6. Ergebnis
      await _buildResult(controller, testStart, allOk);

      setState(() => _resultReady = true);
    } catch (e) {
      debugPrint('Test error: $e');
      _updateLastStep('Fehler', 'error', e.toString());
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _showCountdown(int seconds, String subtitle) async {
    setState(() {
      _steps.add(_TestStep(
        title: 'Abstand: Countdown',
        status: 'running',
        detail: subtitle,
      ));
    });

    for (int i = seconds; i > 0; i--) {
      if (!mounted) return;
      setState(() {
        _steps.last = _steps.last.copyWith(
          detail: 'Countdown: $i s | $subtitle',
        );
      });
      await Future.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      _steps.removeLast();
    }
  }

  Future<void> _buildResult(AppController controller, int testStart, bool allOk) async {
    final allEvents = controller.events
        .where((e) => e.t >= testStart)
        .toList();

    final buffer = StringBuffer();
    buffer.writeln('Routine-Test');
    buffer.writeln();

    // Schritte
    for (final step in _steps) {
      if (step.title != 'Abstand: Countdown') {
        buffer.writeln('${step.title}: ${step.status == 'ok' ? '✓' : step.status == 'error' ? '✗' : '–'}');
        if (step.detail.isNotEmpty && !step.detail.contains('Countdown')) {
          buffer.writeln('  ${step.detail}');
        }
      }
    }
    buffer.writeln();

    if (allOk) {
      buffer.writeln('Alles in Ordnung ✓');
    } else {
      buffer.writeln('Prüfe die ✗-Punkte oben');
    }
    buffer.writeln();

    // Ereignisse
    if (allEvents.isNotEmpty) {
      buffer.writeln('--- Ereignisse ---');
      for (final event in allEvents) {
        if (event.type == 'info' || event.type == 'scan') {
          buffer.writeln(describeEvent(event));
        }
      }
    }

    _resultText = buffer.toString();
  }

  Future<void> _addStep(String title, String status, String detail) async {
    if (!mounted) return;
    setState(() {
      _steps.add(_TestStep(title: title, status: status, detail: detail));
    });
  }

  void _updateLastStep(String title, String status, String detail) {
    if (_steps.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _steps.last = _steps.last.copyWith(title: title, status: status, detail: detail);
    });
  }

  Future<void> _copyResult() async {
    final text = StringBuffer();
    for (final step in _steps) {
      if (step.title != 'Abstand: Countdown') {
        text.writeln('${step.title}: ${step.status == 'ok' ? '✓' : step.status == 'error' ? '✗' : '–'}');
        if (step.detail.isNotEmpty && !step.detail.contains('Countdown')) {
          text.writeln('  ${step.detail}');
        }
      }
    }
    text.writeln();
    text.writeln(_resultText);

    final data = ClipboardData(text: text.toString());
    await Clipboard.setData(data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kopiert')),
    );
  }
}

class _TestStep {
  final String title;
  final String status; // running, ok, error, skipped
  final String detail;

  _TestStep({
    required this.title,
    required this.status,
    required this.detail,
  });

  _TestStep copyWith({String? title, String? status, String? detail}) {
    return _TestStep(
      title: title ?? this.title,
      status: status ?? this.status,
      detail: detail ?? this.detail,
    );
  }
}
