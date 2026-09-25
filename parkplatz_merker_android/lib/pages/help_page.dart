import 'package:flutter/material.dart';

/// Abschnitte der Anleitung. Die Einstellungen verlinken gezielt hierher.
enum HelpTopic {
  start,
  detection,
  transmitter,
  appInCar,
  closeApp,
  widgets,
  extras,
  problems,
}

class _Section {
  final HelpTopic topic;
  final IconData icon;
  final String title;
  final List<String> paragraphs;

  const _Section(this.topic, this.icon, this.title, this.paragraphs);
}

/// Alle Anleitungen stehen hier – neue Funktionen bekommen immer einen Abschnitt.
const _sections = <_Section>[
  _Section(HelpTopic.start, Icons.rocket_launch_outlined, 'Erste Schritte', [
    'Einmal einrichten, dann läuft alles von selbst: Einstellungen → Abschnitt „Einrichtung“. '
        'Jede rote Zeile antippen → „Erlauben“.',
    '1. Standort → „Bei Nutzung der App“.\n'
        '2. Standort „Immer zulassen“ – im nächsten Fenster wirklich „Immer zulassen“ wählen, '
        'sonst klappt es nicht bei geschlossener App.\n'
        '3. Aktivitätserkennung („Körperliche Aktivität“).\n'
        '4. Bluetooth-Suche („Geräte in der Nähe“) – nur mit Transmitter/Beacon nötig.\n'
        '5. Benachrichtigungen.\n'
        '6. Akku „Nicht eingeschränkt“. Bei Samsung die App außerdem nicht unter „Apps im Standby“ eintragen.',
    'Schalter ausgegraut oder „Eingeschränkte Einstellung“? Einstellungen → „App-Info öffnen“ → '
        'oben rechts ⋮ → „Eingeschränkte Einstellungen zulassen“, dann den Schritt wiederholen.',
    'Wenn auf der Startseite kein Hinweis „Einrichtung unvollständig“ mehr steht, einfach losfahren.',
  ]),
  _Section(HelpTopic.detection, Icons.directions_car_outlined, 'So merkt sich die App dein Auto', [
    'Android meldet, wenn du im Fahrzeug bist. Dann erscheint die Benachrichtigung „Fahrt erkannt“: '
        'die App merkt sich alle 30 Sekunden die Position, sucht alle 2 Minuten kurz nach deinem '
        'Transmitter und achtet aufs Ladekabel.',
    'Beim Aussteigen nimmt sie den genauesten Hinweis: Ladekabel abgezogen → Transmitter verschwunden '
        '(Motor aus) → Aussteigen erkannt. Der Parkplatz ist die Position zu diesem Zeitpunkt. '
        'Unter dem Parkplatz steht, woran er erkannt wurde.',
    'Ignoriert werden Fahrten unter 3 Minuten und Halte unter 2 Minuten (Ampel, Stau). '
        'Ein langer Stau ohne Aussteigen zählt auch nicht.',
    'Ist ein Transmitter eingerichtet und wurde er während der Fahrt nie gesehen, speichert die App '
        'keinen Parkplatz – du warst dann vermutlich im Bus, Taxi oder einem anderen Auto.',
    'Falsch erkannt? Beim Parkplatz auf „Falsch erkannt“ tippen – der Eintrag wird gelöscht.',
  ]),
  _Section(HelpTopic.transmitter, Icons.bluetooth_searching, 'Transmitter oder Beacon einrichten', [
    'Die App verbindet sich nie mit dem Gerät – sie schaut nur, ob es in der Nähe ist. '
        'Dein Handy bleibt also frei für Musik und Anrufe.',
    '1. Auto an, Transmitter steckt. Handy NICHT mit dem Transmitter verbinden.\n'
        '2. Einstellungen → Gerät im Auto: „Transmitter“ → „Transmitter suchen“ → „Suche starten“.\n'
        '3. Nach ca. 15 Sekunden erscheint die Liste. Deiner hat meist das stärkste Signal '
        '(RSSI nahe 0, z. B. −45 dBm). Antippen → „Verwenden“.',
    'So testest du, ob die App deinen Transmitter sieht: Transmitter ausstecken → noch mal suchen → '
        'er darf nicht mehr erscheinen. Wieder einstecken → er ist wieder da.',
    'Nach der ersten Fahrt: Einstellungen → Diagnose → unter „Gerät“ muss „Zuletzt gesehen“ mit '
        'einer Uhrzeit während der Fahrt stehen.',
    'Taucht er nie auf? Bluetooth und Standort (GPS) müssen an sein, und kein anderes Handy darf '
        'gerade mit ihm verbunden sein.',
    'Beacon statt Transmitter: Gerät im Auto „Beacon“ wählen – funktioniert genauso, nur stromsparender '
        'und oft schneller erkannt.',
  ]),
  _Section(HelpTopic.appInCar, Icons.open_in_new, 'App im Auto öffnen (z. B. Blitzer.de)', [
    'Sobald dein Transmitter/Beacon während der Fahrt erkannt wird, öffnet sich die gewählte App. '
        'Das geht mit jeder App, die ein Symbol in deiner App-Übersicht hat.',
    '1. Einstellungen → „App im Auto“ → „Wählen“ → App aus der Liste tippen.\n'
        '2. „Über anderen Apps einblenden“ erlauben – nur dann geht die App von selbst auf. '
        'Ohne kommt eine Benachrichtigung zum Antippen.\n'
        '3. Mit „Jetzt testen“ ausprobieren.',
    'Die Suche beginnt, wenn Android „im Fahrzeug“ erkennt – meist 1–2 Minuten nach dem Losfahren '
        '(mit Beacon oft schneller).',
  ]),
  _Section(HelpTopic.closeApp, Icons.power_settings_new, 'App beim Aussteigen komplett beenden', [
    'Ist der Transmitter weg (Motor aus), wird die App geschlossen. Eine einzelne verpasste Suche '
        'während der Fahrt schließt nichts.',
    'Weg 1 – Ausschaltknopf (empfohlen): „Benachrichtigungszugriff“ erlauben. Dann drückt die App '
        'den Knopf in der Benachrichtigung der Blitzer-App – unsichtbar, auch bei gesperrtem Handy. '
        'Hat der Knopf nur ein Symbol: „Ausschaltknopf“ → „Wählen“ (dazu muss die Blitzer-App gerade laufen) '
        '→ z. B. „Knopf 1 (nur Symbol)“ und mit „Beenden jetzt testen“ prüfen.',
    'Weg 2 – „Beenden erzwingen“ (Ersatz): Schalter „Notfalls Beenden erzwingen“ an und die '
        'Bedienungshilfe „Parkplatz-Merker: App beenden“ einschalten (Einstellungen → Bedienungshilfen → '
        'Installierte Apps). Die App öffnet dann kurz die App-Info und drückt „Beenden erzwingen“. '
        'Klappt nur bei entsperrtem Handy – sonst beim nächsten Entsperren.',
    'Die Bedienungshilfe drückt ausschließlich Knöpfe, auf denen wirklich „Beenden erzwingen“ steht.',
  ]),
  _Section(HelpTopic.widgets, Icons.widgets_outlined, 'Widgets und Schnelleinstellung', [
    'Widget „Mein Auto“: Startbildschirm lange drücken → Widgets → Parkplatz-Merker → „Mein Auto“ '
        'hinziehen. Es zeigt eine kleine Karte, seit wann das Auto dort steht, Adresse und Notiz, '
        'dazu „Navigation“ und „Hier geparkt“. Nach dem Aussteigen aktualisiert es sich nach etwa '
        '1 Minute von selbst.',
    'Kleines Widget „Hier geparkt“: merkt mit einem Tipp die aktuelle Position.',
    'Schnelleinstellung: Benachrichtigungsleiste ganz herunterziehen → Stift/Bearbeiten → '
        '„Hier geparkt“ in die aktiven Kacheln ziehen.',
  ]),
  _Section(HelpTopic.extras, Icons.sticky_note_2_outlined, 'Notiz, Foto, Parkschein, Verlauf', [
    'Notiz und Foto: beim Parkplatz auf „Notiz“ bzw. „Foto“ tippen (z. B. „Parkhaus Ebene 3, Platz 112“).',
    'Parkschein: „Parkschein“ → Uhrzeit wählen, bis wann er gilt. 15 Minuten vorher kommt eine Erinnerung.',
    'Verlauf: Uhr-Symbol oben – die letzten 30 Parkplätze. Wischen oder „Falsch erkannt“ löscht einen Eintrag.',
    'Navigation zum Auto öffnet den Fußweg in Google Maps (sonst eine andere Karten-App).',
  ]),
  _Section(HelpTopic.problems, Icons.bug_report_outlined, 'Probleme? Diagnose', [
    'Einstellungen → Diagnose zeigt die letzten 100 Ereignisse (Fahrten, Suchen mit Signalstärke, '
        'Ladekabel, Standorte), die Berechtigungen und ob dein Transmitter gesehen wurde.',
    'Oben rechts „Kopieren“ tippen und den Text weiterschicken – daran lässt sich fast jedes Problem erkennen.',
    'Häufigste Ursachen: Standort nicht auf „Immer zulassen“, Akku eingeschränkt, oder die App wurde '
        'über „Beenden erzwingen“ gestoppt (dann einmal öffnen).',
  ]),
];

/// Anleitung zu allen Funktionen. [open] klappt einen Abschnitt direkt auf.
class HelpPage extends StatelessWidget {
  final HelpTopic? open;

  const HelpPage({super.key, this.open});

  static Future<void> show(BuildContext context, [HelpTopic? open]) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HelpPage(open: open)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Anleitung')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final s in _sections)
            ExpansionTile(
              key: PageStorageKey(s.topic),
              leading: Icon(s.icon),
              title: Text(s.title),
              initiallyExpanded: s.topic == open,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in s.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(p, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
