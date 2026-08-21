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

  /// Zahl per Tastatur statt per Regler. Der Regler bleibt fuer das grobe
  /// Einstellen, die Eingabe fuer den genauen Wert — 37 Minuten trifft man mit
  /// dem Daumen nicht.
  Future<void> _zahlEingeben({
    required String titel,
    required String einheit,
    required int wert,
    required int min,
    required int max,
    required ValueChanged<int> uebernehmen,
  }) async {
    final neuerWert = await showDialog<int>(
      context: context,
      builder: (context) => _ZahlDialog(
        titel: titel,
        einheit: einheit,
        wert: wert,
        min: min,
        max: max,
      ),
    );
    // Unsinn wird geklemmt statt abgewiesen: wer 999 tippt, meint „so viel wie
    // geht", und eine Fehlermeldung dafuer ist Schikane.
    if (neuerWert != null) uebernehmen(neuerWert.clamp(min, max));
  }

  /// Beschriftung eines Reglers, mit Stift zum Tippen.
  Widget _zahlZeile(String text, VoidCallback bearbeiten) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: kMonoFamily,
            fontSize: 12,
            color: RiegelColors.fg2,
          ),
        ),
      ),
      IconButton(
        onPressed: bearbeiten,
        icon: const Icon(Icons.edit, size: 16),
        color: RiegelColors.fg3,
        visualDensity: VisualDensity.compact,
        tooltip: 'Zahl eingeben',
      ),
    ],
  );

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
              value: _duration.toDouble().clamp(5, 480),
              min: 5,
              max: 480,
              divisions: 95,
              onChanged: (v) => setState(() => _duration = v.round()),
            ),
            _zahlZeile(
              '$_duration Minuten',
              () => _zahlEingeben(
                titel: 'Dauer der Sperre',
                einheit: 'Minuten',
                wert: _duration,
                min: 5,
                max: 480,
                uebernehmen: (v) => setState(() => _duration = v),
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
              _zahlZeile(
                'Alle $_pauseStep Minuten am Stück',
                () => _zahlEingeben(
                  titel: 'Stufenabstand',
                  einheit: 'Minuten',
                  wert: _pauseStep,
                  min: 1,
                  max: 60,
                  uebernehmen: (v) => setState(() => _pauseStep = v),
                ),
              ),
              Slider(
                // Minutenweise. Fuenferschritte waren zu grob: die erste Stufe
                // entscheidet, ob die Pause im Weg steht oder etwas bewirkt.
                value: _pauseStep.toDouble().clamp(1, 60),
                min: 1,
                max: 60,
                divisions: 59,
                onChanged: (v) => setState(() => _pauseStep = v.round()),
              ),
              _zahlZeile(
                'Erste Pause $_pauseBase Sekunden, danach doppelt so lang',
                () => _zahlEingeben(
                  titel: 'Grundwartezeit',
                  einheit: 'Sekunden',
                  wert: _pauseBase,
                  min: 1,
                  max: 60,
                  uebernehmen: (v) => setState(() => _pauseBase = v),
                ),
              ),
              Slider(
                // Sekundenweise, nicht in Dreierschritten: bei so kurzen
                // Wartezeiten ist der Unterschied zwischen 5 und 6 Sekunden
                // spuerbar.
                value: _pauseBase.toDouble().clamp(1, 60),
                min: 1,
                max: 60,
                divisions: 59,
                onChanged: (v) => setState(() => _pauseBase = v.round()),
              ),
              _zahlZeile(
                'Nach $_pauseReset Minuten ohne die App beginnt die '
                'Staffelung von vorn',
                () => _zahlEingeben(
                  titel: 'Sitzungspause',
                  einheit: 'Minuten',
                  wert: _pauseReset,
                  min: 1,
                  max: 120,
                  uebernehmen: (v) => setState(() => _pauseReset = v),
                ),
              ),
              Slider(
                value: _pauseReset.toDouble().clamp(1, 120),
                min: 1,
                max: 120,
                divisions: 119,
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

/// Eigenes Widget, damit der Controller so lange lebt wie der Dialog. Wird er
/// gleich nach `showDialog` weggeraeumt, baut die Schliessanimation noch einmal
/// auf einen entsorgten Controller — und das schlaegt als Flutter-Fehler bis in
/// den Fehlermelder durch.
class _ZahlDialog extends StatefulWidget {
  const _ZahlDialog({
    required this.titel,
    required this.einheit,
    required this.wert,
    required this.min,
    required this.max,
  });

  final String titel;
  final String einheit;
  final int wert;
  final int min;
  final int max;

  @override
  State<_ZahlDialog> createState() => _ZahlDialogState();
}

class _ZahlDialogState extends State<_ZahlDialog> {
  late final _feld = TextEditingController(text: '${widget.wert}');

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  void _fertig() => Navigator.pop(context, int.tryParse(_feld.text.trim()));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titel),
    content: TextField(
      controller: _feld,
      autofocus: true,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        suffixText: widget.einheit,
        helperText: '${widget.min} bis ${widget.max}',
      ),
      onSubmitted: (_) => _fertig(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(onPressed: _fertig, child: const Text('Übernehmen')),
    ],
  );
}
