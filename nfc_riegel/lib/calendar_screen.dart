import 'package:flutter/material.dart';

import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

/// Was für alle Profile gilt: Schalter, Stichwort, Vorschau. Welche Kalender
/// ein Profil sperren, stellt man im Profil ein — dort, wo man es sucht.
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
  late final TextEditingController _marker =
      TextEditingController(text: widget.status.calendar.keywordMarker);

  @override
  void dispose() {
    _marker.dispose();
    super.dispose();
  }

  Future<void> _schalte(bool an) async {
    if (an && !_berechtigt) {
      final erteilt = await widget.channel.requestCalendarPermission();
      if (!erteilt) return;
      if (mounted) setState(() => _berechtigt = true);
    }
    setState(() => _an = an);
    await _speichere();
  }

  Future<void> _speichere() => widget.channel.setCalendarSettings(
    enabled: _an,
    keywordMarker: _marker.text,
  );

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
            const SizedBox(height: RiegelSpacing.s3),
            const Text(
              'Welche Kalender sperren, stellst du im jeweiligen Profil ein.',
              style: TextStyle(fontSize: 13, color: RiegelColors.fg2),
            ),
            const SizedBox(height: RiegelSpacing.s5),
            TextField(
              controller: _marker,
              decoration: const InputDecoration(
                labelText: 'Stichwort im Termintitel',
              ),
              onSubmitted: (_) => _speichere(),
            ),
            const SizedBox(height: RiegelSpacing.s5),
            Text('NÄCHSTE TERMINE', style: beschriftung),
            const SizedBox(height: RiegelSpacing.s2),
            if (widget.status.calendar.windows.isEmpty)
              const Text('Kein passender Termin in den nächsten 48 Stunden.')
            else
              for (final termin in _nachTermin(widget.status.calendar.windows))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(termin.first.title),
                  subtitle: Text(
                    '${_zeitraum(termin.first)} · ${_profilNamen(termin)}',
                  ),
                ),
          ],
        ],
      ),
    );
  }

  /// Ein Termin mit zwei Profilen kommt als zwei Fenster mit derselben
  /// `eventId`. Hier wird er wieder einer — in der Reihenfolge des ersten
  /// Auftretens, die Liste kommt schon nach Beginn sortiert.
  List<List<CalendarWindowInfo>> _nachTermin(List<CalendarWindowInfo> fenster) {
    final gruppen = <String, List<CalendarWindowInfo>>{};
    for (final f in fenster) {
      gruppen.putIfAbsent(f.eventId, () => []).add(f);
    }
    return gruppen.values.toList();
  }

  String _profilNamen(List<CalendarWindowInfo> termin) {
    final namen = <String>[];
    for (final f in termin) {
      for (final p in widget.status.profiles) {
        if (p.id == f.profileId) namen.add(p.name);
      }
    }
    return namen.join(', ');
  }

  String _zeitraum(CalendarWindowInfo w) {
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${w.startsAt.day}.${w.startsAt.month}. ${hhmm(w.startsAt)} – ${hhmm(w.endsAt)}';
  }
}
