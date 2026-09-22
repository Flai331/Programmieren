import 'package:flutter/material.dart';

import 'app_picker_screen.dart';
import 'calendar_screen.dart';
import 'contact_picker_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

/// Ein Profil bearbeiten: Name, Apps, Modus, Dauer bzw. Zeitpunkt.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.channel,
    this.calendar = CalendarInfo.empty,
  });

  final ProfileInfo profile;
  final RiegelChannel channel;

  /// Hauptschalter, Berechtigung und Stichwort — gelten für alle Profile und
  /// entscheiden, ob der Abschnitt KALENDER Auswahl oder Hinweis zeigt.
  final CalendarInfo calendar;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.name,
  );
  late List<String> _packages = List.of(widget.profile.blockedPackages);
  late LockMode _mode = widget.profile.mode;
  late int _duration = widget.profile.durationMinutes;
  late DateTime? _untilAt = widget.profile.untilAt;
  late bool _pin = widget.profile.pinCalendarEnd;
  late bool _timedRelease = widget.profile.timedRelease;
  late bool _pause = widget.profile.pauseEnabled;
  late int _pauseStep = widget.profile.pauseStepMinutes;
  late int _pauseBase = widget.profile.pauseBaseSeconds;
  late int _pauseReset = widget.profile.pauseResetMinutes;
  late bool _quiet = widget.profile.quietEnabled;
  late QuietScope _quietScope = widget.profile.quietScope;
  late List<String> _quietNumbers = List.of(widget.profile.quietNumbers);
  late int _quietAfter = widget.profile.quietAfterEventMinutes;
  late bool _quietWhileLocked = widget.profile.quietWhileLocked;
  late List<QuietScheduleInfo> _quietSchedules = List.of(
    widget.profile.quietSchedules,
  );
  late RingerMode _quietRinger = widget.profile.quietRinger;
  late final Map<String, CalendarMatch> _kalenderAuswahl = Map.of(
    widget.profile.calendars,
  );
  late bool _stichwortUeberall = widget.profile.keywordEverywhere;
  late CalendarInfo _kalender = widget.calendar;
  List<DeviceCalendarInfo> _geraeteKalender = const [];
  bool? _usageGranted;
  bool _screeningVerfuegbar = false;
  bool? _screeningGehalten;
  bool? _dndErlaubt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ladeBerechtigung();
    _ladeKalender();
  }

  /// Rolle und Berechtigungen werden in Systemdialogen vergeben. Zurueck in der
  /// App muss der Schirm den neuen Stand zeigen, ohne dass man ihn neu oeffnet.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ladeBerechtigung();
  }

  Future<void> _ladeBerechtigung() async {
    final granted = await widget.channel.usageAccessGranted();
    final verfuegbar = await widget.channel.callScreeningAvailable();
    final gehalten = await widget.channel.callScreeningHeld();
    final dnd = await widget.channel.dndGranted();
    if (!mounted) return;
    setState(() {
      _usageGranted = granted;
      _screeningVerfuegbar = verfuegbar;
      _screeningGehalten = gehalten;
      _dndErlaubt = dnd;
    });
  }

  Future<void> _ladeKalender() async {
    if (!_kalender.enabled || !_kalender.permissionGranted) return;
    final liste = await widget.channel.deviceCalendars();
    if (mounted) setState(() => _geraeteKalender = liste);
  }

  /// Hauptschalter und Berechtigung liegen im Kalender-Schirm. Beim Zurückkommen
  /// den neuen Stand holen — sonst stünde der Hinweis noch da, obwohl der
  /// Kalender längst an ist.
  Future<void> _oeffneKalender() async {
    final status = await widget.channel.getState();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarScreen(status: status, channel: widget.channel),
      ),
    );
    final neu = await widget.channel.getState();
    if (!mounted) return;
    setState(() => _kalender = neu.calendar);
    await _ladeKalender();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    super.dispose();
  }

  Future<void> _waehleKontakte() async {
    final gewaehlt = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          selected: _quietNumbers,
          channel: widget.channel,
        ),
      ),
    );
    if (gewaehlt != null) setState(() => _quietNumbers = gewaehlt);
  }

  Future<void> _frageAnruffilter() async {
    await widget.channel.requestCallScreening();
    // Die Rolle vergibt das System in einem eigenen Dialog. Der Stand danach
    // kommt ueber didChangeAppLifecycleState zurueck.
  }

  /// [index] null legt ein neues Fenster an, sonst wird eines geaendert.
  Future<void> _planBearbeiten(int? index) async {
    const vorgabe = QuietScheduleInfo(
      // Mo–Fr 22:00–06:00 als Vorschlag: der haeufigste Fall ist die Nacht
      // unter der Woche.
      days: {2, 3, 4, 5, 6},
      startMinute: 22 * 60,
      endMinute: 6 * 60,
    );
    final plan = await showDialog<QuietScheduleInfo>(
      context: context,
      builder: (_) =>
          _PlanDialog(plan: index == null ? vorgabe : _quietSchedules[index]),
    );
    if (plan == null) return;
    setState(() {
      if (index == null) {
        _quietSchedules.add(plan);
      } else {
        _quietSchedules[index] = plan;
      }
    });
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
        timedRelease: _timedRelease,
        pauseEnabled: _pause,
        pauseStepMinutes: _pauseStep,
        pauseBaseSeconds: _pauseBase,
        pauseResetMinutes: _pauseReset,
        quietEnabled: _quiet,
        quietScope: _quietScope,
        quietNumbers: _quietNumbers,
        quietAfterEventMinutes: _quietAfter,
        quietWhileLocked: _quietWhileLocked,
        quietSchedules: _quietSchedules,
        quietRinger: _quietRinger,
        calendars: _kalenderAuswahl,
        keywordEverywhere: _stichwortUeberall,
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

  List<Widget> _kalenderAbschnitt() {
    if (!_kalender.enabled || !_kalender.permissionGranted) {
      return [
        const Text(
          'Die Kalenderfunktion ist aus.',
          style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
        ),
        const SizedBox(height: RiegelSpacing.s3),
        OutlinedButton(
          onPressed: _oeffneKalender,
          child: const Text('Zum Kalender'),
        ),
      ];
    }
    return [
      SwitchListTile(
        value: _stichwortUeberall,
        onChanged: (v) => setState(() => _stichwortUeberall = v),
        title: Text('Stichwort „${_kalender.keywordMarker}" in jedem Kalender'),
        subtitle: const Text(
          'Termine mit dem Stichwort im Titel sperren dieses Profil, egal in '
          'welchem Kalender sie stehen',
        ),
        contentPadding: EdgeInsets.zero,
      ),
      if (_geraeteKalender.isEmpty)
        const Text(
          'Kein Kalender auf diesem Gerät gefunden.',
          style: TextStyle(fontSize: 13, color: RiegelColors.fg3),
        ),
      // Kalender, die das Gerät nicht mehr kennt, bleiben in der Auswahl
      // gespeichert, erscheinen hier aber nicht — ändern lässt sich an ihnen
      // ohnehin nichts.
      for (final k in _geraeteKalender)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(k.name),
          subtitle: Text(k.account),
          trailing: DropdownButton<CalendarMatch?>(
            key: ValueKey('kalender-${k.id}'),
            value: _kalenderAuswahl[k.id],
            items: const [
              DropdownMenuItem<CalendarMatch?>(value: null, child: Text('aus')),
              DropdownMenuItem<CalendarMatch?>(
                value: CalendarMatch.all,
                child: Text('alle Termine'),
              ),
              DropdownMenuItem<CalendarMatch?>(
                value: CalendarMatch.keyword,
                child: Text('nur Stichwort'),
              ),
            ],
            onChanged: (art) => setState(() {
              if (art == null) {
                _kalenderAuswahl.remove(k.id);
              } else {
                _kalenderAuswahl[k.id] = art;
              }
            }),
          ),
        ),
    ];
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
          // Nur bei „Offen": eine Zeitsperre laesst sich ohnehin nicht per Chip
          // aufmachen, ein Schalter dafuer waere eine leere Zusage.
          if (_mode == LockMode.open)
            SwitchListTile(
              value: _timedRelease,
              onChanged: (v) => setState(() => _timedRelease = v),
              title: const Text('Freigabe auf Zeit'),
              subtitle: const Text(
                'Der Chip öffnet nur für eine gewählte Zeit. Danach sperrt es '
                'von selbst wieder.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
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
          Text('KALENDER', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          ..._kalenderAbschnitt(),
          const SizedBox(height: RiegelSpacing.s6),
          Text('ATEMPAUSE', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          if (_usageGranted == false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ohne Zugriff auf die Nutzungsdaten kann Anker nicht wissen, '
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
          const SizedBox(height: RiegelSpacing.s6),
          Text('RUHE', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          SwitchListTile(
            value: _quiet,
            onChanged: (v) => setState(() => _quiet = v),
            title: const Text('Anrufe stumm schalten'),
            subtitle: const Text(
              'Klingelt nicht und vibriert nicht. Der Anruf läuft weiter und '
              'steht danach im Anrufprotokoll — Anker legt nicht auf.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          if (_quiet) ...[
            const SizedBox(height: RiegelSpacing.s3),
            const Text('Klingelmodus während der Ruhe'),
            DropdownButton<RingerMode>(
              value: _quietRinger,
              isExpanded: true,
              items: [
                for (final m in RingerMode.values)
                  DropdownMenuItem(value: m, child: Text(ringerLabel(m))),
              ],
              onChanged: (m) =>
                  setState(() => _quietRinger = m ?? RingerMode.unveraendert),
            ),
            const Text(
              'Gilt fürs ganze Telefon, also auch für Benachrichtigungen.',
              style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
            ),
            if (_quietRinger == RingerMode.lautlos && _dndErlaubt == false)
              const Text(
                'Ohne „Bitte nicht stören" bleibt es beim Vibrieren.',
                style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
              ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<QuietScope>(
                segments: const [
                  ButtonSegment(value: QuietScope.alle, label: Text('Alle')),
                  ButtonSegment(
                    value: QuietScope.ausgewaehlte,
                    label: Text('Auswahl'),
                  ),
                  ButtonSegment(
                    value: QuietScope.alleAusser,
                    label: Text('Alle außer'),
                  ),
                ],
                selected: {_quietScope},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    setState(() => _quietScope = s.first),
              ),
            ),
            if (_quietScope != QuietScope.alle) ...[
              const SizedBox(height: RiegelSpacing.s3),
              OutlinedButton(
                onPressed: _waehleKontakte,
                child: Text('${_quietNumbers.length} Kontakte gewählt'),
              ),
            ],
            if (_screeningGehalten == false) ...[
              const SizedBox(height: RiegelSpacing.s3),
              const Text(
                'Anker ist nicht die Anruffilter-App. Ohne diese Rolle bleibt '
                'nur „Bitte nicht stören" — das stellt alles still, nicht nur '
                'die gewählten Nummern.',
                style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
              ),
              const SizedBox(height: RiegelSpacing.s2),
              if (_screeningVerfuegbar)
                OutlinedButton(
                  onPressed: _frageAnruffilter,
                  child: const Text('Anker zum Anruffilter machen'),
                ),
            ],
            // Der Zugriff wird an zwei Stellen gebraucht: als Rückfall für den
            // Anruffilter und für „Lautlos". Deshalb steht der Knopf hier
            // einmal für beide statt zweimal.
            if (_dndErlaubt == false &&
                (_screeningGehalten == false ||
                    _quietRinger == RingerMode.lautlos)) ...[
              const SizedBox(height: RiegelSpacing.s2),
              OutlinedButton(
                onPressed: widget.channel.openDndSettings,
                child: const Text('„Bitte nicht stören" erlauben'),
              ),
            ],
            const SizedBox(height: RiegelSpacing.s4),
            SwitchListTile(
              value: _quietWhileLocked,
              onChanged: (v) => setState(() => _quietWhileLocked = v),
              title: const Text('Auch während einer Sperre'),
              subtitle: const Text(
                'Solange dieses Profil sperrt, bleiben Anrufe still.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            _zahlZeile(
              _quietAfter == 0
                  ? 'Kein Nachlauf nach einem Termin'
                  : 'Noch $_quietAfter Minuten nach einem Termin',
              () => _zahlEingeben(
                titel: 'Nachlauf nach Terminende',
                einheit: 'Minuten',
                wert: _quietAfter,
                min: 0,
                max: 120,
                uebernehmen: (v) => setState(() => _quietAfter = v),
              ),
            ),
            Slider(
              value: _quietAfter.toDouble().clamp(0, 120),
              min: 0,
              max: 120,
              divisions: 120,
              onChanged: (v) => setState(() => _quietAfter = v.round()),
            ),
            const SizedBox(height: RiegelSpacing.s3),
            Text(
              'ZEITFENSTER',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            for (var i = 0; i < _quietSchedules.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _quietSchedules[i].label,
                  style: const TextStyle(fontFamily: kMonoFamily, fontSize: 13),
                ),
                trailing: IconButton(
                  onPressed: () =>
                      setState(() => _quietSchedules.removeAt(i)),
                  icon: const Icon(Icons.close, size: 18),
                  color: RiegelColors.fg3,
                  tooltip: 'Zeitfenster entfernen',
                ),
                onTap: () => _planBearbeiten(i),
              ),
            TextButton(
              onPressed: () => _planBearbeiten(null),
              child: const Text('+ Zeitfenster'),
            ),
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

/// Ein Zeitfenster einstellen: Wochentage und die beiden Uhrzeiten.
class _PlanDialog extends StatefulWidget {
  const _PlanDialog({required this.plan});

  final QuietScheduleInfo plan;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late final Set<int> _tage = {...widget.plan.days};
  late int _start = widget.plan.startMinute;
  late int _ende = widget.plan.endMinute;

  Future<void> _waehleZeit({required bool start}) async {
    final aktuell = start ? _start : _ende;
    final gewaehlt = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: aktuell ~/ 60, minute: aktuell % 60),
    );
    if (gewaehlt == null) return;
    setState(() {
      final minuten = gewaehlt.hour * 60 + gewaehlt.minute;
      if (start) {
        _start = minuten;
      } else {
        _ende = minuten;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Zeitfenster'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: RiegelSpacing.s2,
          children: kTagKuerzel.entries
              .map(
                (eintrag) => FilterChip(
                  label: Text(eintrag.value),
                  selected: _tage.contains(eintrag.key),
                  onSelected: (an) => setState(() {
                    if (an) {
                      _tage.add(eintrag.key);
                    } else {
                      _tage.remove(eintrag.key);
                    }
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: RiegelSpacing.s4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _waehleZeit(start: true),
                child: Text('ab ${uhrzeitAusMinuten(_start)}'),
              ),
            ),
            const SizedBox(width: RiegelSpacing.s2),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _waehleZeit(start: false),
                child: Text('bis ${uhrzeitAusMinuten(_ende)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: RiegelSpacing.s3),
        const Text(
          'Liegt das Ende vor dem Beginn, läuft das Fenster über Mitternacht.',
          style: TextStyle(fontSize: 12, color: RiegelColors.fg3),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        // Ohne Wochentag greift das Fenster nie — das ist kein Fenster.
        onPressed: _tage.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                QuietScheduleInfo(
                  days: _tage,
                  startMinute: _start,
                  endMinute: _ende,
                ),
              ),
        child: const Text('Übernehmen'),
      ),
    ],
  );
}
