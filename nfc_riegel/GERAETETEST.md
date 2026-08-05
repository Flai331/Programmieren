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
