import 'package:flutter/material.dart';

import 'app_picker_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

/// Ein Profil bearbeiten: Name, Apps, Modus, Dauer bzw. Zeitpunkt.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.channel,
  });

  final ProfileInfo profile;
  final RiegelChannel channel;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.name,
  );
  late List<String> _packages = List.of(widget.profile.blockedPackages);
  late LockMode _mode = widget.profile.mode;
  late int _duration = widget.profile.durationMinutes;
  late DateTime? _untilAt = widget.profile.untilAt;
  late bool _pin = widget.profile.pinCalendarEnd;
  late bool _pause = widget.profile.pauseEnabled;
  late int _pauseStep = widget.profile.pauseStepMinutes;
  late int _pauseBase = widget.profile.pauseBaseSeconds;
  late int _pauseReset = widget.profile.pauseResetMinutes;
  bool? _usageGranted;

  @override
  void initState() {
    super.initState();
    _ladeBerechtigung();
  }

  Future<void> _ladeBerechtigung() async {
    final granted = await widget.channel.usageAccessGranted();
    if (mounted) setState(() => _usageGranted = granted);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickApps() async {
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AppPickerScreen(selected: _packages, channel: widget.channel),
      ),
    );
    if (picked != null) setState(() => _packages = picked);
  }

  Future<void> _pickUntil() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _untilAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_untilAt ?? now),
    );
    if (time == null) return;
    setState(() {
      _untilAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final ok = await widget.channel.updateProfile(
      ProfileInfo(
        id: widget.profile.id,
        name: _name.text.trim().isEmpty ? 'Profil' : _name.text.trim(),
        blockedPackages: _packages,
        mode: _mode,
        durationMinutes: _duration,
        untilAt: _untilAt,
        pinCalendarEnd: _pin,
        pauseEnabled: _pause,
        pauseStepMinutes: _pauseStep,
        pauseBaseSeconds: _pauseBase,
        pauseResetMinutes: _pauseReset,
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dieses Profil sperrt gerade')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await widget.channel.deleteProfile(widget.profile.id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nicht möglich — letztes Profil oder gerade gesperrt'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [TextButton(onPressed: _save, child: const Text('Sichern'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(RiegelSpacing.s4),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: RiegelSpacing.s6),
          Text('APPS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          OutlinedButton(
            onPressed: _pickApps,
            child: Text('${_packages.length} Apps ausgewählt'),
          ),
          const SizedBox(height: RiegelSpacing.s6),
          Text('MODUS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<LockMode>(
              segments: const [
                ButtonSegment(value: LockMode.open, label: Text('Bis Scan')),
                ButtonSegment(value: LockMode.timer, label: Text('Auf Zeit')),
                ButtonSegment(value: LockMode.until, label: Text('Bis Termin')),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          if (_mode == LockMode.timer) ...[
            Slider(
              value: _duration.toDouble(),
              min: 15,
              max: 480,
              divisions: 31,
              onChanged: (v) => setState(() => _duration = v.round()),
            ),
            Text(
              '$_duration Minuten',
              style: const TextStyle(
                fontFamily: kMonoFamily,
                fontSize: 12,
                color: RiegelColors.fg2,
              ),
            ),
          ],
          if (_mode == LockMode.until) ...[
            const SizedBox(height: RiegelSpacing.s3),
            OutlinedButton(
              onPressed: _pickUntil,
              child: Text(
                _untilAt == null
                    ? 'Zeitpunkt wählen'
                    : '${_untilAt!.day}.${_untilAt!.month}. '
                          '${_untilAt!.hour.toString().padLeft(2, '0')}:'
                          '${_untilAt!.minute.toString().padLeft(2, '0')}',
              ),
            ),
          ],
          const SizedBox(height: RiegelSpacing.s6),
          SwitchListTile(
            value: _pin,
            onChanged: (v) => setState(() => _pin = v),
            title: const Text('Kalender-Ende festnageln'),
            subtitle: const Text(
              'Sperre läuft bis zum ursprünglichen Terminende, auch wenn der '
              'Termin verschoben oder gelöscht wird',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: RiegelSpacing.s6),
          Text('ATEMPAUSE', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          if (_usageGranted == false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ohne Zugriff auf die Nutzungsdaten kann Riegel nicht wissen, '
                  'wie lange du in einer App warst.',
                  style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
                ),
                const SizedBox(height: RiegelSpacing.s3),
                OutlinedButton(
                  onPressed: widget.channel.openUsageAccessSettings,
                  child: const Text('Zugriff erlauben'),
                ),
              ],
            )
          else ...[
            SwitchListTile(
              value: _pause,
              onChanged: (v) => setState(() => _pause = v),
              title: const Text('Atempause'),
              subtitle: const Text(
                'Hält dich nach jeder Stufe kurz auf. Sperrt nicht — nach dem '
                'Countdown geht es weiter.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (_pause) ...[
              Text(
                'Alle $_pauseStep Minuten am Stück',
                style: const TextStyle(
                  fontFamily: kMonoFamily,
                  fontSize: 12,
                  color: RiegelColors.fg2,
                ),
              ),
              Slider(
                value: _pauseStep.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                onChanged: (v) => setState(() => _pauseStep = v.round()),
              ),
              Text(
                'Erste Pause $_pauseBase Sekunden, danach doppelt so lang',
                style: const TextStyle(
                  fontFamily: kMonoFamily,
                  fontSize: 12,
                  color: RiegelColors.fg2,
                ),
              ),
              Slider(
                // Sekundenweise, nicht in Dreierschritten: bei so kurzen
                // Wartezeiten ist der Unterschied zwischen 5 und 6 Sekunden
                // spuerbar.
                value: _pauseBase.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                onChanged: (v) => setState(() => _pauseBase = v.round()),
              ),
              Text(
                'Nach $_pauseReset Minuten ohne die App beginnt die '
                'Staffelung von vorn',
                style: const TextStyle(
                  fontFamily: kMonoFamily,
                  fontSize: 12,
                  color: RiegelColors.fg2,
                ),
              ),
              Slider(
                value: _pauseReset.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                onChanged: (v) => setState(() => _pauseReset = v.round()),
              ),
            ],
          ],
          const SizedBox(height: RiegelSpacing.s8),
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: RiegelColors.danger),
            child: const Text('Profil löschen'),
          ),
        ],
      ),
    );
  }
}
