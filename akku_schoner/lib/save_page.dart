import 'package:flutter/material.dart';

import 'native.dart';

class _Shortcut {
  final IconData icon;
  final String title;
  final String text;
  final String setting;
  const _Shortcut(this.icon, this.title, this.text, this.setting);
}

/// Die größten Stromfresser – jeweils direkt zur passenden Systemeinstellung.
const _shortcuts = [
  _Shortcut(Icons.battery_saver, 'Energiesparmodus',
      'Bremst Hintergrund-Aktivität, Synchronisation und Animationen. Am besten automatisch ab 30–50 % einschalten.',
      'batterySaver'),
  _Shortcut(Icons.pie_chart_outline, 'Akkuverbrauch ansehen',
      'Android zeigt, welche App wie viel Akku gebraucht hat. Große Verbraucher dort auf „Eingeschränkt“ stellen.',
      'batteryUsage'),
  _Shortcut(Icons.brightness_6, 'Bildschirm',
      'Der Bildschirm ist der größte Verbraucher: automatische Helligkeit, kurze Bildschirm-Zeitüberschreitung (30 s), 60 Hz statt 120 Hz, dunkles Design.',
      'display'),
  _Shortcut(Icons.location_off_outlined, 'Standort',
      'GPS aus, wenn du es nicht brauchst. Sonst Apps nur „Während der Nutzung“ erlauben.',
      'location'),
  _Shortcut(Icons.bluetooth_disabled, 'Bluetooth',
      'Aus, wenn keine Kopfhörer/Uhr verbunden sind.', 'bluetooth'),
  _Shortcut(Icons.wifi, 'WLAN',
      'Zuhause WLAN statt Mobilfunk – das braucht deutlich weniger Strom. „WLAN-Suche“ unter Standort ausschalten.',
      'wifi'),
  _Shortcut(Icons.nfc, 'NFC', 'Aus, wenn du nicht mit dem Handy bezahlst.', 'nfc'),
  _Shortcut(Icons.sync_disabled, 'Konten-Synchronisierung',
      'Automatische Synchronisierung für unwichtige Konten ausschalten.', 'sync'),
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

class _SavePageState extends State<SavePage> {
  bool _samsungPhone = false;

  @override
  void initState() {
    super.initState();
    Native.status().then((s) {
      final m = (s['manufacturer'] as String? ?? '').toLowerCase();
      if (mounted) setState(() => _samsungPhone = m.contains('samsung'));
    }).catchError((_) {});
  }

  Widget _tile(_Shortcut s, ColorScheme cs) => ListTile(
        leading: Icon(s.icon, color: cs.primary),
        title: Text(s.title),
        subtitle: Text(s.text),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Native.openSettings(s.setting),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_samsungPhone) ...[
          for (final s in _samsung) _tile(s, cs),
          const Divider(),
        ],
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
                  'Der Akku-Wächter läuft unauffällig im Hintergrund und meldet sich nur, wenn die Ladegrenze (z. B. 80 %) erreicht ist, der Akku fast leer ist oder zu heiß wird. '
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
                  'Die Automatik läuft im selben unauffälligen Dienst wie der Akku-Wächter (eine stille Benachrichtigung „Akku-Schoner“).'),
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
