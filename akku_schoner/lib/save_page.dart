import 'dart:async';

import 'package:flutter/material.dart';

import 'logic.dart';
import 'native.dart';

class _Shortcut {
  final IconData icon;
  final String title;
  final String text;
  final String setting;
  const _Shortcut(this.icon, this.title, this.text, this.setting);
}

/// Was keine App selbst umstellen darf – hier nur der direkte Weg zur Einstellung.
const _shortcuts = [
  _Shortcut(Icons.pie_chart_outline, 'Akkuverbrauch ansehen',
      'Android zeigt, welche App wie viel Akku gebraucht hat. Große Verbraucher dort auf „Eingeschränkt“ stellen.',
      'batteryUsage'),
  _Shortcut(Icons.brightness_6, 'Dunkles Design & 60 Hz',
      'Anzeige → Dunkler Modus an, Bewegungsglättung auf „Standard“ (60 Hz). Darf nur das System umschalten.',
      'display'),
  _Shortcut(Icons.wifi, 'WLAN',
      'Zuhause WLAN statt Mobilfunk – das braucht deutlich weniger Strom.',
      'wifi'),
  _Shortcut(Icons.data_saver_on, 'Datensparmodus',
      'Verhindert, dass Apps im Hintergrund mobile Daten nutzen.', 'dataSaver'),
  _Shortcut(Icons.playlist_remove, 'Akku-Optimierung',
      'Liste der Apps, die von der Akku-Optimierung ausgenommen sind. Hier sollte fast nichts „nicht optimiert“ sein.',
      'batteryOptimization'),
];

const _tips = [
  'Zwischen 20 % und 80 % laden – volle 100 % und leer bis 0 % stressen einen kaputten Akku am meisten (Akku-Wächter warnt dich).',
  'Wärme ist Gift: nicht unter dem Kopfkissen, in der Sonne oder mit dicker Hülle laden. Beim Laden nicht spielen.',
  'Langsames Laden (schwaches Netzteil, Schnellladen in den Einstellungen aus) schont mehr als Schnellladen.',
  'Wenn das Handy bei 15–30 % plötzlich ausgeht, ist der Akku verschlissen – dann früher laden und Tausch einplanen.',
  'Aufgeblähter Akku (Display hebt sich, Rückseite wölbt sich): nicht mehr laden, sofort tauschen lassen – Brandgefahr.',
  'Widgets, Live-Hintergründe und „Always-On-Display“ entfernen bzw. ausschalten.',
  'Benachrichtigungen unwichtiger Apps abschalten – jede weckt das Handy auf.',
];

/// Nur auf Samsung-Handys (One UI) – öffnet die „Gerätewartung“.
const _samsung = [
  _Shortcut(Icons.shield_outlined, 'Samsung: Akku schützen',
      'Wichtigste Einstellung für einen kaputten Akku: Akku → Weitere Akkueinstellungen → „Akku schützen“ '
          '(lädt nur bis 80–85 %). Wirkt direkt im Ladechip – besser als jede Warnung.',
      'samsungBattery'),
  _Shortcut(Icons.bedtime_outlined, 'Samsung: Schlafende Apps',
      'Akku → Hintergrund-Nutzungsbegrenzungen: selten genutzte Apps in „Tief schlafende Apps“ legen. '
          'Spotify, Messenger und Wecker NICHT – sonst geht Play am Kopfhörer bzw. kommen keine Nachrichten.',
      'samsungSleeping'),
];

class SavePage extends StatefulWidget {
  const SavePage({super.key});

  @override
  State<SavePage> createState() => _SavePageState();
}

class _SavePageState extends State<SavePage> with WidgetsBindingObserver {
  bool _samsungPhone = false;
  bool _accessibility = false;
  bool _canWrite = false;
  Map<dynamic, dynamic> _state = {};
  Map<dynamic, dynamic> _saving = {};
  Set<String> _ids = {'saver', 'timeout', 'brightness', 'haptic', 'nfc'};
  bool _auto = false;
  double _autoLevel = 30;
  bool _hasBackup = false;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Zurück aus den Einstellungen (Erlaubnis erteilt, Schalter umgelegt …)
    if (state == AppLifecycleState.resumed && _poll == null) _load();
  }

  Future<void> _load() async {
    try {
      final st = await Native.status();
      final p = await Native.profile();
      final ps = await Native.profileState();
      if (!mounted) return;
      setState(() {
        _samsungPhone = (st['manufacturer'] as String? ?? '').toLowerCase().contains('samsung');
        _accessibility = st['accessibility'] == true;
        _ids = ((p['ids'] as List?) ?? []).cast<String>().toSet();
        _auto = p['auto'] == true;
        _autoLevel = ((p['autoLevel'] as num?) ?? 30).toDouble();
        _hasBackup = p['hasBackup'] == true;
        _state = (ps['state'] as Map?) ?? {};
        _saving = (ps['saving'] as Map?) ?? {};
        _canWrite = ps['canWrite'] == true;
      });
    } catch (_) {}
  }

  Future<void> _saveConfig() => Native.setProfile({
        'ids': _ids.toList(),
        'auto': _auto,
        'autoLevel': _autoLevel.round(),
      });

  Future<void> _run(Future<Map<dynamic, dynamic>> Function() action) async {
    setState(() => _busy = true);
    final r = await action();
    final direct = ((r['direct'] as Map?) ?? {}).cast<String, String>();
    final toggles = ((r['toggles'] as List?) ?? []).cast<String>();
    final started = r['started'] == true;
    final lines = [
      for (final e in direct.entries) '${profileLabel(e.key)}: ${e.value}',
    ];
    if (toggles.isNotEmpty && !started) {
      lines.add('${toggles.map(profileLabel).join(', ')}: Bedienungshilfe ist aus');
    }
    if (started) {
      // Die Bedienungshilfe arbeitet die Schalter ab – warten, dann alles zusammen zeigen.
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(milliseconds: 800), (_) async {
        final s = await Native.forceStopState();
        if (((s['pending'] as List?) ?? []).isNotEmpty) return;
        _poll?.cancel();
        _poll = null;
        for (final m in ((s['results'] as List?) ?? []).cast<Map>()) {
          lines.add('${profileLabel(m['pkg'] as String)}: ${m['result']}');
        }
        _finish(lines);
      });
    } else {
      _finish(lines);
    }
  }

  Future<void> _finish(List<String> lines) async {
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sparprofil'),
        content: Text(lines.isEmpty ? 'Alles war schon eingestellt.' : lines.join('\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Widget _tile(_Shortcut s, ColorScheme cs) => ListTile(
        leading: Icon(s.icon, color: cs.primary),
        title: Text(s.title),
        subtitle: Text(s.text),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Native.openSettings(s.setting),
      );

  Widget _profileCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final needWrite = !_canWrite &&
        profileItems.any((p) => _ids.contains(p.id) && p.way == ProfileWay.write);
    final needA11y = !_accessibility &&
        profileItems.any((p) => _ids.contains(p.id) && p.way == ProfileWay.accessibility);
    final todo = profileItems
        .where((p) => _ids.contains(p.id) && _state[p.id] != null && _saving[p.id] != true)
        .length;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.eco, color: cs.primary),
            title: const Text('Sparprofil', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(todo == 0
                ? 'Alle gewählten Punkte sparen schon ✓'
                : '$todo gewählte Punkte sind noch nicht im Sparzustand'),
          ),
          if (needWrite)
            _hint(context, 'Für Timeout, Helligkeit und Vibration: „Systemeinstellungen ändern“ für den Akku-Schoner erlauben.',
                'Erlauben', () => Native.openSettings('writeSettings')),
          if (needA11y)
            _hint(context, 'Energiesparmodus, NFC, Standort und Bluetooth darf keine App direkt umschalten – '
                'das macht die Bedienungshilfe (Reiter „Apps“).',
                'Einschalten', () => Native.openSettings('accessibility')),
          for (final p in profileItems)
            CheckboxListTile(
              dense: true,
              value: _ids.contains(p.id),
              onChanged: _state[p.id] == null
                  ? null
                  : (v) {
                      setState(() => v == true ? _ids.add(p.id) : _ids.remove(p.id));
                      _saveConfig();
                    },
              title: Text('${p.title} → ${p.action}'),
              subtitle: Text('${p.note}\nJetzt: ${profileStateText(p.id, _state[p.id])}'
                  '${_saving[p.id] == true ? ' ✓' : ''}'),
              isThreeLine: true,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.bolt),
                    label: const Text('Jetzt sparen'),
                    onPressed: _busy || _ids.isEmpty
                        ? null
                        : () => _run(() => Native.applyProfile(_ids.toList())),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy || !_hasBackup ? null : () => _run(Native.restoreProfile),
                  child: const Text('Zurücksetzen'),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          SwitchListTile(
            title: Text('Automatisch unter ${_autoLevel.round()} %'),
            subtitle: const Text('Fällt der Akku darunter, stellt die App das Profil selbst um '
                '(Schalter beim nächsten Entsperren). Läuft in der Bedienungshilfe mit.'),
            value: _auto,
            onChanged: (v) {
              setState(() => _auto = v);
              _saveConfig();
            },
          ),
          if (_auto)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Slider(
                value: _autoLevel.clamp(10, 60),
                min: 10,
                max: 60,
                divisions: 10,
                label: '${_autoLevel.round()} %',
                onChanged: (v) => setState(() => _autoLevel = v),
                onChangeEnd: (_) => _saveConfig(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hint(BuildContext context, String text, String button, VoidCallback onTap) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text)),
            TextButton(onPressed: onTap, child: Text(button)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _profileCard(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Nur von Hand möglich', style: Theme.of(context).textTheme.titleMedium),
          ),
          if (_samsungPhone)
            for (final s in _samsung) _tile(s, cs),
          for (final s in _shortcuts) _tile(s, cs),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Tipps für einen schwachen Akku',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final t in _tips)
            ListTile(
              dense: true,
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(t),
            ),
        ],
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final h = Theme.of(context).textTheme.titleMedium;
    Widget section(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: h),
              const SizedBox(height: 6),
              Text(body),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Hilfe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section('Reiter „Akku“',
              'Zeigt Ladestand, Temperatur, Spannung, Strom und Zustand. Hinweise erscheinen, wenn der Akku zu warm, zu voll oder zu leer ist.\n\n'
                  'Der Akku-Wächter läuft ohne dauerhafte Benachrichtigung in der Bedienungshilfe mit und meldet sich nur, wenn die Ladegrenze (z. B. 80 %) erreicht ist, der Akku fast leer ist oder zu heiß wird. '
                  'Er nutzt nur die Akku-Meldungen, die Android ohnehin verschickt – kein Timer, kein GPS, kein Internet.'),
          section('Reiter „Apps“ – drei Stufen',
              'Jede App hat eine Stufe. Die Automatik wählt sie nach deiner Nutzung der letzten 7 Tage:\n'
                  '• Wichtig (an mindestens 4 Tagen benutzt): wird nie angefasst. Eine App, die du ständig öffnest, '
                  'jedes Mal kalt neu zu starten, kostet mehr Strom als sie im Speicher zu lassen.\n'
                  '• Sanft (ab und zu benutzt, Musik-Apps wie Spotify, Messenger, Wecker, Navigation): fliegt nur aus dem Speicher. '
                  'Push-Nachrichten kommen weiter an, und Play am Kopfhörer startet Spotify wieder – auch bei gesperrtem Handy.\n'
                  '• Komplett (7 Tage nicht benutzt): „Beenden erzwingen“. Läuft gar nicht mehr, bis du die App selbst öffnest.\n\n'
                  'Antippen einer App: Stufe von Hand festlegen (umrandet = von Hand) oder zurück auf „Automatisch“. '
                  'Startbildschirm und Tastatur sind immer geschützt, vorinstallierte Apps automatisch „Wichtig“.\n\n'
                  'Ohne Nutzungszugriff weiß die App nicht, was du oft benutzt – dann ist alles vorsichtshalber „Sanft“.'),
          section('Automatik',
              'Bildschirm aus: 15 s nach dem Ausschalten werden „Sanft“- und „Komplett“-Apps sanft beendet. Geht ohne Entsperren und ist unsichtbar. '
                  'Gerade laufende Musik bleibt an.\n\n'
                  'Entsperren: War der Bildschirm länger aus (einstellbar, Standard 30 min), werden „Komplett“-Apps, die sich inzwischen wieder gestartet haben, '
                  'komplett beendet. Dabei blitzt kurz die App-Info auf, danach landest du auf dem Startbildschirm. Bei einem Anruf passiert nichts.\n\n'
                  'Automatik und Akku-Wächter laufen in der Bedienungshilfe mit – deshalb gibt es keine dauerhafte Benachrichtigung. Ohne Bedienungshilfe sind beide aus.'),
          section('Reiter „Sparen“ – Sparprofil',
              'Die App stellt die Spar-Einstellungen selbst um, statt sie nur zu beschreiben. Du hakst an, was umgestellt werden soll, und tippst „Jetzt sparen“. '
                  '„Zurücksetzen“ stellt deine vorherigen Werte wieder her.\n\n'
                  '• Bildschirm-Timeout (30 s), automatische Helligkeit, Vibration bei Berührung: stellt die App direkt um. Dafür einmal „Systemeinstellungen ändern“ erlauben.\n'
                  '• Automatische Synchronisierung: direkt, ohne Extra-Erlaubnis (standardmäßig nicht angehakt, weil E-Mails dann evtl. später kommen).\n'
                  '• Energiesparmodus, NFC, Standort, Bluetooth: Android lässt keine App diese Schalter direkt umlegen. Die Bedienungshilfe öffnet kurz die Einstellungsseite und drückt den Schalter – wie beim Beenden von Apps. '
                  'Bluetooth ist standardmäßig nicht angehakt, sonst wären deine Kopfhörer getrennt.\n\n'
                  'Automatisch: Fällt der Akku unter die eingestellte Grenze, wendet die App das Profil einmal selbst an (Schalter beim nächsten Entsperren) und meldet das. '
                  'Nach dem Laden ist die Automatik wieder bereit.\n\n'
                  'Nicht möglich (nur das System darf es): dunkles Design, 60/120 Hz, Samsungs „Akku schützen“ – dafür gibt es darunter die direkten Links.'),
          section('Warum braucht das die Bedienungshilfe?',
              'Android erlaubt keiner normalen App, andere Apps zu beenden. Ohne Bedienungshilfe kann der Akku-Schoner Apps nur „sanft“ beenden – Apps mit eigenem Dienst starten dann sofort neu.\n\n'
                  'Mit Bedienungshilfe öffnet die App für jede gewählte App die App-Info und drückt „Beenden erzwingen“ – genau so, wie du es von Hand tun würdest. '
                  'Der Dienst wird nur aktiv, wenn du in der App auf „Beenden“ tippst.\n\n'
                  'Einschalten: Einstellungen → Bedienungshilfen → Installierte Apps → „Akku-Schoner: Apps beenden“. '
                  'Ist der Schalter ausgegraut, zuerst App-Info → ⋮ (oben rechts) → „Eingeschränkte Einstellungen zulassen“.'),
          section('Dauerhaft statt immer wieder beenden',
              'Am wirksamsten: Für Apps, die nicht im Hintergrund laufen sollen, in der App-Info unter „Akku“ die Option „Eingeschränkt“ wählen (Samsung: „Tief schlafende Apps“, Reiter „Sparen“). '
                  'Nicht für Spotify/Musik-Apps – die dürfen dann bei gesperrtem Handy nicht mehr spielen. '
                  'Dann hält Android sie selbst dauerhaft an. Im Reiter „Apps“ führt dich „Akkunutzung einschränken“ direkt dorthin.'),
          section('Grenzen',
              'Die App kann die Akku-Kapazität nicht messen oder reparieren und das Laden nicht selbst stoppen – sie warnt dich nur. '
                  'Manche Handys (z. B. Samsung, Pixel) haben eine eingebaute Ladebegrenzung auf 80–85 % („Akku schützen“) – die ist besser als jede Warnung, schalte sie ein, falls vorhanden.'),
        ],
      ),
    );
  }
}
