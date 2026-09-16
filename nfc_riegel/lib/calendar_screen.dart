import 'package:flutter/material.dart';

import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

/// Kalenderfunktion einrichten: Schalter, Kalenderzuordnung, Stichwort, Vorschau.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.status,
    this.channel = const RiegelChannel(),
  });

  final LockStatus status;
  final RiegelChannel channel;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late bool _an = widget.status.calendar.enabled;
  late bool _berechtigt = widget.status.calendar.permissionGranted;
  late final Map<String, CalendarRuleInfo> _regeln =
      Map.of(widget.status.calendar.calendarRules);
  late String? _stichwortProfil = widget.status.calendar.keywordProfileId;
  late final Set<String> _stichwortKalender =
      Set.of(widget.status.calendar.keywordCalendarIds);
  late final TextEditingController _marker =
      TextEditingController(text: widget.status.calendar.keywordMarker);
  List<DeviceCalendarInfo> _geraeteKalender = const [];

  @override
  void initState() {
    super.initState();
    if (_an && _berechtigt) _ladeKalender();
  }

  @override
  void dispose() {
    _marker.dispose();
    super.dispose();
  }

  Future<void> _ladeKalender() async {
    final liste = await widget.channel.deviceCalendars();
    if (mounted) setState(() => _geraeteKalender = liste);
  }

  Future<void> _schalte(bool an) async {
    if (an && !_berechtigt) {
      final erteilt = await widget.channel.requestCalendarPermission();
      if (!erteilt) return;
      if (mounted) setState(() => _berechtigt = true);
    }
    setState(() => _an = an);
    await _speichere();
    if (an) await _ladeKalender();
  }

  Future<void> _speichere() async {
    await widget.channel.setCalendarSettings(
      enabled: _an,
      calendarRules: _regeln,
      keywordMarker: _marker.text,
      keywordProfileId: _stichwortProfil,
      keywordCalendarIds: _stichwortKalender,
    );
  }

  @override
  Widget build(BuildContext context) {
    final beschriftung = Theme.of(context).textTheme.labelSmall;
    return Scaffold(
      appBar: AppBar(title: const Text('Kalender')),
      body: ListView(
        padding: const EdgeInsets.all(RiegelSpacing.s4),
        children: [
          if (!_berechtigt)
            Padding(
              padding: const EdgeInsets.only(bottom: RiegelSpacing.s4),
              child: Text(
                'Ohne Berechtigung für den Kalender kann Anker keine Termine sehen.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RiegelColors.danger,
                ),
              ),
            ),
          SwitchListTile(
            title: const Text('Termine sperren'),
            subtitle: const Text('Läuft ein passender Termin, sperrt sein Profil'),
            value: _an,
            onChanged: _schalte,
          ),
          if (_an) ...[
            const SizedBox(height: RiegelSpacing.s4),
            Text('KALENDER DES GERÄTS', style: beschriftung),
            const SizedBox(height: RiegelSpacing.s2),
            if (_geraeteKalender.isEmpty)
              const Text('Kein Kalender auf diesem Gerät gefunden.'),
            for (final kalender in _geraeteKalender)
              _KalenderZeile(
                kalender: kalender,
                profile: widget.status.profiles,
                regel: _regeln[kalender.id],
                onProfil: (profilId) async {
                  setState(() {
                    if (profilId == null) {
                      _regeln.remove(kalender.id);
                    } else {
                      _regeln[kalender.id] = CalendarRuleInfo(
                        profileId: profilId,
                        match: _regeln[kalender.id]?.match ?? CalendarMatch.all,
                      );
                    }
                  });
                  await _speichere();
                },
                onTrefferart: (art) async {
                  final vorhanden = _regeln[kalender.id];
                  if (vorhanden == null) return;
                  setState(() {
                    _regeln[kalender.id] = CalendarRuleInfo(
                      profileId: vorhanden.profileId,
                      match: art,
                    );
                  });
                  await _speichere();
                },
              ),
            const SizedBox(height: RiegelSpacing.s5),
            Text('STICHWORTREGEL', style: beschriftung),
            const SizedBox(height: RiegelSpacing.s2),
            const Text(
              'Greift zusätzlich, unabhängig von den Regeln oben.',
              style: TextStyle(fontSize: 12, color: RiegelColors.fg3),
            ),
            const SizedBox(height: RiegelSpacing.s3),
            TextField(
              controller: _marker,
              decoration: const InputDecoration(
                labelText: 'Stichwort im Termintitel',
              ),
              onSubmitted: (_) => _speichere(),
            ),
            const SizedBox(height: RiegelSpacing.s3),
            DropdownButtonFormField<String?>(
              initialValue: _stichwortProfil,
              decoration: const InputDecoration(labelText: 'Profil für Treffer'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('aus')),
                for (final p in widget.status.profiles)
                  DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (wert) async {
                setState(() => _stichwortProfil = wert);
                await _speichere();
              },
            ),
            const SizedBox(height: RiegelSpacing.s3),
            const Text(
              'In welchen Kalendern gesucht wird. Nichts angekreuzt heißt: in allen.',
              style: TextStyle(fontSize: 12, color: RiegelColors.fg3),
            ),
            for (final kalender in _geraeteKalender)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(kalender.name),
                value: _stichwortKalender.contains(kalender.id),
                onChanged: (an) async {
                  setState(() {
                    if (an == true) {
                      _stichwortKalender.add(kalender.id);
                    } else {
                      _stichwortKalender.remove(kalender.id);
                    }
                  });
                  await _speichere();
                },
              ),
            const SizedBox(height: RiegelSpacing.s5),
            Text('NÄCHSTE TERMINE', style: beschriftung),
            const SizedBox(height: RiegelSpacing.s2),
            if (widget.status.calendar.windows.isEmpty)
              const Text('Kein passender Termin in den nächsten 48 Stunden.')
            else
              for (final fenster in widget.status.calendar.windows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(fenster.title),
                  subtitle: Text(_zeitraum(fenster)),
                ),
          ],
        ],
      ),
    );
  }

  String _zeitraum(CalendarWindowInfo w) {
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${w.startsAt.day}.${w.startsAt.month}. ${hhmm(w.startsAt)} – ${hhmm(w.endsAt)}';
  }
}

/// Ein Kalender mit seiner Regel: welches Profil, und ob alle Termine oder nur
/// die mit Stichwort. Die Trefferart erscheint erst, wenn ein Profil gewählt ist —
/// vorher hat sie nichts, worauf sie sich beziehen könnte.
class _KalenderZeile extends StatelessWidget {
  const _KalenderZeile({
    required this.kalender,
    required this.profile,
    required this.regel,
    required this.onProfil,
    required this.onTrefferart,
  });

  final DeviceCalendarInfo kalender;
  final List<ProfileInfo> profile;
  final CalendarRuleInfo? regel;
  final ValueChanged<String?> onProfil;
  final ValueChanged<CalendarMatch> onTrefferart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(kalender.name),
          subtitle: Text(kalender.account),
          trailing: DropdownButton<String?>(
            value: regel?.profileId,
            hint: const Text('aus'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('aus')),
              for (final p in profile)
                DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
            ],
            onChanged: onProfil,
          ),
        ),
        if (regel != null)
          Padding(
            padding: const EdgeInsets.only(
              left: RiegelSpacing.s4,
              bottom: RiegelSpacing.s3,
            ),
            child: SegmentedButton<CalendarMatch>(
              segments: const [
                ButtonSegment(
                  value: CalendarMatch.all,
                  label: Text('alle Termine'),
                ),
                ButtonSegment(
                  value: CalendarMatch.keyword,
                  label: Text('nur Stichwort'),
                ),
              ],
              selected: {regel!.match},
              onSelectionChanged: (auswahl) => onTrefferart(auswahl.first),
            ),
          ),
      ],
    );
  }
}
