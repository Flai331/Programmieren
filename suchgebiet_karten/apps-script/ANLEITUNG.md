# Status-Meldungen einrichten (einmalig, ca. 10 Minuten)

Mit den Status-Meldungen sehen Sie in der Einsatzleitung, wo Ihre Hundeführer gerade stehen
(„Suche begonnen“, „Pause“, „Gebiet fertig“, „Person gefunden“ …) und wo wichtige Standorte
liegen. Die Meldungen laufen über eine **Google-Tabelle**, die Sie selbst besitzen. Dazu
braucht es ein kostenloses Google-Konto und die folgenden Schritte. Programmieren müssen Sie
nichts – nur Text kopieren und einfügen. Am Computer geht es am einfachsten.

**Datenschutz:** Der Inhalt der Meldungen ist verschlüsselt. Der Schlüssel steckt nur in den
Aufträgen, die Sie selbst verschicken. In der Tabelle stehen nur unlesbare Zeichen; auch
Google kann den Inhalt nicht lesen. Nach 7 Tagen werden alle Zeilen automatisch gelöscht.
Ohne Internet geht es weiter wie bisher: Hundeführer geben ihre Rückmeldung per QR-Code.

## 1. Tabelle anlegen

1. Im Browser auf <https://sheets.google.com> gehen und mit dem Google-Konto anmelden.
2. **„Leer“** (neue, leere Tabelle) antippen bzw. anklicken.
3. Oben links den Namen ändern, z. B. in **„Suchgebiet Status“**.

## 2. Programm einfügen

1. In der Tabelle oben im Menü **„Erweiterungen“** → **„Apps Script“** wählen. Es öffnet sich
   ein neues Fenster mit einem Editor.
2. Im Editor steht schon etwas Text (`function myFunction() { … }`). Den **ganzen Text
   markieren und löschen** (Strg + A, Entf).
3. Den gesamten Inhalt der Datei `Code.gs` (aus diesem Ordner) kopieren und dort einfügen.
4. Oben auf das **Disketten-Symbol** („Projekt speichern“) klicken. Das Projekt darf einen
   beliebigen Namen bekommen, z. B. „Status-Server“.

## 3. Einmal einrichten („setup“ ausführen)

1. Oben in der Leiste neben „Ausführen“ ist eine Auswahl mit Funktionsnamen. Dort **`setup`**
   auswählen.
2. Auf **„Ausführen“** klicken.
3. Google fragt nach einer **Berechtigung**: „Berechtigung prüfen“ → eigenes Konto wählen →
   evtl. „Erweitert“ → „Status-Server (unsicher) öffnen“ → **„Zulassen“**. Das ist normal, weil
   das Programm von Ihnen selbst stammt und noch nicht von Google geprüft wurde.
4. Fertig, wenn unten „Ausführung abgeschlossen“ steht. In der Tabelle gibt es jetzt ein
   Blatt **„Meldungen“** (und ein tägliches Aufräumen ist eingerichtet).

## 4. Als Web-App bereitstellen

1. Oben rechts auf **„Bereitstellen“** → **„Neue Bereitstellung“**.
2. Links neben „Typ auswählen“ das **Zahnrad** anklicken → **„Web-App“**.
3. Einstellen:
   - **Beschreibung:** egal, z. B. „Status“
   - **Ausführen als:** **Ich** (Ihr Konto)
   - **Wer hat Zugriff:** **Jeder**
4. Auf **„Bereitstellen“** klicken (ggf. nochmal „Zugriff autorisieren“ bestätigen).
5. Es erscheint die **Web-App-URL**. Sie sieht so aus:
   `https://script.google.com/macros/s/AKfy…/exec`
   Auf **„Kopieren“** klicken.

*Tipp zum Prüfen:* Die kopierte URL in einem neuen Browser-Tab öffnen. Es muss
`{"ok":true,"info":"Suchgebiet-Karten Status-Server läuft."}` erscheinen.

## 5. Adresse in der App eintragen

1. In der Suchgebiet-App (Einsatzleitung): **⚙️ Mehr** → Abschnitt **„Dieses Gerät“** →
   Feld **„📣 Status-Server (Web-App-Adresse)“**.
2. Die kopierte URL dort einfügen. Das Feld speichert von selbst.
3. Ab jetzt tragen **neue Aufträge** die Verbindung mit. Aufträge, die Sie *vorher* verschickt
   haben, melden nichts – bitte neu verschicken.
4. Der Hundeführer sieht dann in seiner Ansicht den Knopf **„📣 Status“**. Seine Meldungen
   erscheinen bei Ihnen auf der Karte und in der Auftrags-Übersicht („Hunde“ → Aufträge).
   Eine zweite Einsatzleitungs-Stelle (Tablet/PC) bekommt die Verbindung mit der
   Einsatz-Übergabe automatisch.

Das Eintragen der Adresse ist nur auf den Geräten der **Einsatzleitung** nötig. Hundeführer
müssen nichts einstellen.

## Wenn etwas geändert werden soll

- Programmtext geändert (z. B. neue Version von `Code.gs`)? Im Apps-Script-Editor neu einfügen,
  speichern, dann **„Bereitstellen“ → „Bereitstellungen verwalten“ → Stift → Version: „Neue
  Version“ → Bereitstellen**. Die URL bleibt gleich.
- Meldungen löschen? In der Tabelle auf dem Blatt „Meldungen“ die Zeilen unter der Kopfzeile
  löschen. Nichts weiter nötig.
- Mehrere Einsätze gleichzeitig? Kein Problem: Jeder Einsatz hat seinen eigenen Schlüssel
  und damit seinen eigenen „Raum“. Eine Tabelle genügt für alle.

## Häufige Fragen

- **„Es kommt nichts an.“** Hat das Hundeführer-Handy Internet? Ohne Netz wartet die Meldung
  („⏳ wartet auf Netz“) und wird automatisch nachgesendet, sobald wieder Empfang da ist.
- **Adresse falsch?** Sie muss mit `https://script.google.com/` beginnen und auf `/exec`
  enden (nicht `/dev`).
- **Zugriff „Jeder“ ist doch unsicher?** Jeder, der die Adresse *und* einen Raum-Code kennt,
  könnte verschlüsselte Zeilen abholen – ohne den Schlüssel sind sie wertlos. Die Adresse
  bitte trotzdem nicht öffentlich posten.
- **Kosten?** Keine. Für Einsätze reicht das kostenlose Kontingent von Google weit aus.
