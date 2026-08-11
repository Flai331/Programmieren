# Gerätetest Riegel

Vor jeder Ablage einer neuen APK durchgehen. Braucht: Android-Handy mit NFC,
einen beschreibbaren NFC-Tag (NTAG213/215/216).

## Einrichtung

- [ ] App startet mit dem Wizard
- [ ] Bedienungshilfe lässt sich aus Schritt 1 heraus anschalten
- [ ] Geräteadministrator lässt sich aus Schritt 1 heraus aktivieren
- [ ] App-Auswahl listet die installierten Apps
- [ ] Chip anlernen: Tag wird beschrieben, Schritt meldet „Chip ist angelernt"
- [ ] Notfall-Code wird angezeigt — aufschreiben
- [ ] Nach „Fertig" erscheint der Hauptscreen

## Sperren und Freigeben

- [ ] Modus „Bis erneuter Scan" wählen, Chip scannen → Meldung „Riegel zu"
- [ ] Gesperrte App öffnen → Sperrschirm erscheint
- [ ] Nicht gesperrte App öffnen → normal nutzbar
- [ ] Chip erneut scannen → „Riegel offen", App wieder nutzbar

## Timer

- [ ] Modus „Auf Zeit" mit 15 Minuten wählen, Chip scannen
- [ ] Sperrschirm zeigt die Restzeit herunterzählend
- [ ] Chip vor Ablauf erneut scannen → sofort frei
- [ ] Neu sperren, Timer ablaufen lassen → Sperre endet von selbst

## Umgehungsschutz

- [ ] Während einer Sperre die Bedienungshilfen-Einstellungen öffnen → Rauswurf
- [ ] Während einer Sperre WLAN-Einstellungen öffnen → bleibt nutzbar
- [ ] Während einer Sperre App deinstallieren wollen → wird verhindert

## Sonderfälle

- [ ] Fremden NFC-Tag scannen → „Fremder Chip", Zustand unverändert
- [ ] Neustart während einer Sperre → Sperre besteht weiter
- [ ] Neustart, nachdem der Timer währenddessen ablief → frei beim Hochfahren
- [ ] Notfall-Code eingeben → Sperre endet
- [ ] Code 3× falsch → Meldung „Zu viele Versuche", 60 s warten

## v2 — Profile, mehrere Chips, Sperre bis Zeitpunkt

### Migration
- [ ] Update über eine bestehende v1-Installation: Profil „Standard" ist da, der alte Chip erscheint als Generalschlüssel
- [ ] Eine beim Update laufende Sperre besteht weiter

### Profile
- [ ] Zweites Profil anlegen, benennen, eigene Apps wählen
- [ ] Profil löschen — zugeordnete Chips zeigen danach auf das erste verbleibende
- [ ] Letztes Profil lässt sich nicht löschen
- [ ] Während „Arbeit" sperrt: „Arbeit" nicht bearbeitbar, „Nacht" schon

### Mehrere Chips
- [ ] Zweiten Chip anlernen, Label und Profil vergeben
- [ ] Chip A sperrt Profil A, erneuter Scan von A gibt frei
- [ ] Chip B während laufender A-Sperre: wechselt auf Profil B
- [ ] Generalschlüssel beendet die laufende Sperre
- [ ] Generalschlüssel bei freiem Riegel: sperrt sein eigenes Profil
- [ ] Chip löschen, danach Scan: „Fremder Chip"

### Sperre bis Zeitpunkt
- [ ] Profil auf „Bis Termin" stellen, Zeitpunkt in 5 Minuten wählen, sperren
- [ ] Sperrschirm zählt herunter, Sperre endet zum Zeitpunkt
- [ ] Erneuter Scan beendet vorzeitig
- [ ] Zeitpunkt in der Vergangenheit: Meldung, keine Sperre
- [ ] Neustart während einer UNTIL-Sperre: Sperre besteht weiter

## Fehlermeldesystem

- [ ] Käfer-Symbol oben rechts öffnet den Melde-Dialog
- [ ] Bericht mit Beschreibung abschicken → Erfolgsmeldung
- [ ] Eintrag erscheint in der Notion-Datenbank „🐛 Fehlerberichte Riegel"
- [ ] Im Eintrag stehen unter Protokoll: Sperre, Profile, Chips, Bedienungshilfe, Benachrichtigungen, Android-Version
- [ ] Im Eintrag stehen **keine** Tag-UIDs und kein Code-Hash
- [ ] Flugmodus an, Bericht abschicken → E-Mail-App öffnet sich als Rückfall

## Zeitsperren ohne Chip

- [ ] Profil auf `TIMER` mit 5 Minuten stellen, „Sperren" drücken, Dialog bestätigen
- [ ] Gesperrte App öffnen — Sperrschirm erscheint
- [ ] Normalen Chip dieses Profils scannen — Sperre bleibt bestehen, Meldung
      „Zeitsperre läuft"
- [ ] Chip eines anderen `OPEN`-Profils scannen — beide Sperren gelten gleichzeitig
- [ ] Generalschlüssel scannen — beide Sperren enden
- [ ] Erneut sperren, „Verlängern" drücken — Ende rückt nach hinten, nie nach vorn
- [ ] Profil auf `UNTIL` mit einem Zeitpunkt in der Vergangenheit stellen,
      „Sperren" drücken — Meldung statt Sperre
- [ ] Während laufender Zeitsperre: Profil öffnen — nicht bearbeitbar
- [ ] Während laufender Zeitsperre: Chips öffnen — nicht erreichbar
- [ ] Handy neu starten, während eine Zeitsperre läuft — Sperre gilt weiter,
      Benachrichtigung wieder da
- [ ] Timer ablaufen lassen — Sperre endet von selbst, Benachrichtigung verschwindet
- [ ] Ohne angelernten Generalschlüssel sperren — Dialog warnt in Rot
- [ ] Update über eine laufende v2-`UNTIL`-Sperre — sie läuft nach dem Update weiter

## Benachrichtigungsberechtigung

- [ ] App entfernen und neu installieren, beim ersten Start erscheint die Abfrage
      nach Benachrichtigungen
- [ ] Abfrage ablehnen, dann sperren — Sperre wirkt, nur die Benachrichtigung fehlt
- [ ] Fehlerbericht senden — im Zustandsblock steht „Benachrichtigungen: VERWEIGERT"

## Kalender

- [ ] Kalenderfunktion einschalten — Berechtigungsabfrage erscheint
- [ ] Abfrage ablehnen — Hinweis erscheint, Funktion bleibt aus
- [ ] Abfrage erlauben — Kalender des Geräts erscheinen in der Liste
- [ ] Einem Kalender ein Profil zuordnen, Trefferart „alle Termine"
- [ ] Termin in diesem Kalender anlegen, der in 2 Minuten beginnt und 5 Minuten dauert
- [ ] Bei Terminbeginn sperren die Apps des Profils
- [ ] Sperrschirm zeigt den Termintitel und „frei ab HH:MM"
- [ ] Bei Terminende geben sie wieder frei
- [ ] Ganztägiger Termin sperrt nicht

### Trefferart je Kalender

- [ ] Denselben Kalender auf „nur Stichwort" umstellen
- [ ] Termin **ohne** Stichwort im Titel sperrt jetzt **nicht** mehr
- [ ] Termin **mit** `[Riegel]` im Titel sperrt weiterhin, mit dem Profil des Kalenders

### Eigenständige Stichwortregel

- [ ] Stichwortregel ein Profil zuweisen, keinen Kalender ankreuzen
- [ ] Termin mit `[Riegel]` im Titel in einem **nicht** zugeordneten Kalender sperrt
- [ ] Jetzt nur einen bestimmten Kalender ankreuzen
- [ ] Termin mit `[Riegel]` in **diesem** Kalender sperrt
- [ ] Termin mit `[Riegel]` in einem **anderen** Kalender sperrt nicht mehr
- [ ] Kalender auf „alle Termine" gestellt und Stichwortregel aktiv: der Termin
      sperrt mit dem Profil des **Kalenders**, nicht dem der Stichwortregel

### Zusammenspiel mit den anderen Sperren

- [ ] Laufenden Termin im Kalender verschieben — Sperre verschiebt sich mit
- [ ] Laufenden Termin löschen — Sperre endet
- [ ] Bei `pinCalendarEnd` im Profil: laufenden Termin löschen — Sperre bleibt bis zum
      ursprünglichen Ende
- [ ] Normalen Chip während einer Kalendersperre scannen — sperrt weiter
- [ ] Generalschlüssel während einer Kalendersperre — gibt frei, und der Termin
      sperrt bis zu seinem Ende nicht erneut
- [ ] Nächster Termin sperrt danach wieder normal
- [ ] Notfall-Code während einer Kalendersperre — gibt ebenfalls frei
- [ ] Kalenderberechtigung in den Systemeinstellungen entziehen — Warnung erscheint
- [ ] Handy neu starten während einer Kalendersperre — sperrt danach weiter
- [ ] Fehlerbericht senden — Zeile „Kalender" steht drin, **ohne** Termintitel

### Am Emulator geprüft (2026-08-08, Build 5)

Der Emulator hat kein NFC — alles mit Chip bleibt offen. Der Zustand wurde per
`run-as` gesetzt, Kalender und Termine über `content insert` angelegt.

- [x] Kalender des Geräts erscheinen in der Liste
- [x] Trefferart „alle Termine": jeder Termin des Kalenders sperrt
- [x] Trefferart „nur Stichwort": nur Termine mit `[Riegel]` sperren
- [x] Stichwortregel ohne Kalenderauswahl greift in allen Kalendern
- [x] Stichwortregel mit Auswahl greift nur dort
- [x] Kalenderregel schlägt die Stichwortregel
- [x] Ganztägiger Termin sperrt nicht
- [x] Sperrschirm zeigt Termintitel und „frei ab HH:MM"
- [x] Termin endet — Sperre fällt von allein
- [x] Laufenden Termin löschen — Sperre endet
- [x] Mit `pinCalendarEnd`: laufenden Termin löschen — Sperre bleibt
- [x] Notfall-Code während einer Kalendersperre — gibt frei, Termin sperrt bis zu
      seinem Ende nicht erneut

### Ebenfalls am Emulator geprüft (Build 6)

- [x] Frische Installation startet ohne Absturz, Abfrage nach Benachrichtigungen erscheint
- [x] „Bedienungshilfe öffnen" führt in die Bedienungshilfen-Einstellungen
- [x] „Geräteadministrator aktivieren" führt in den Admin-Dialog, Aktivieren wirkt
- [x] App-Auswahl listet alle Apps mit Startsymbol (Chrome, Gmail, Maps …), Riegel selbst nicht

**Hinweis zum Testen:** `uiautomator dump` registriert UiAutomation als
alleinigen Bedienungshilfe-Dienst und setzt beim Loslassen
`accessibility_enabled` auf 0. Danach sperrt nichts mehr — das ist kein Fehler
der App. Vor jeder Sperrprüfung neu setzen.

## Screenzeit

- [x] Reiter „Screenzeit" ist da, Reiter „Sperre" zeigt weiterhin alles wie vorher
- [x] Ohne Berechtigung: Hinweis und Knopf, keine Liste
- [x] „Zugriff erlauben" führt in den Systemschirm für Nutzungsdaten
- [x] Nach dem Erteilen und Zurückkommen erscheinen Tagessumme und Liste von selbst
- [ ] Liste ist absteigend sortiert, Riegel selbst fehlt
- [x] Apps unter einer Minute fehlen, Fußzeile nennt ihre Zahl
- [ ] Zahlen grob gegen „Digital Wellbeing" gegenprüfen — kleine Abweichungen
      sind normal, große weisen auf einen Fehler in den Rändern hin
- [x] Gesperrte App öffnen: Sperrschirm zeigt „Heute: …" für genau diese App
- [ ] Zweite gesperrte App öffnen: die Zeile wechselt mit
- [ ] Berechtigung entziehen: Zeile auf dem Sperrschirm verschwindet, Reiter
      zeigt wieder den Hinweis
- [ ] Nach Mitternacht: Summen fangen wieder bei null an
- [ ] Fehlerbericht enthält „Nutzungsdaten: erlaubt", aber keine Zeiten

Am Emulator geprüft (Build 7). Offen bleibt, was der Emulator nicht hergibt:
Gegenrechnen mit „Digital Wellbeing" über einen ganzen Tag, der Wechsel über
Mitternacht und der Fehlerbericht in Notion.
