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

## 5. Adresse in der App

Die Adresse von Klaas' Tabelle ist seit v90 **fest in die App eingebaut** – auf den Geräten muss
nichts eingetragen werden. Nur wer eine **eigene** Tabelle benutzen will: in der App
**⚙️ Mehr** → **„Dieses Gerät“** → **„📣 Status-Server“** die eigene URL einfügen (leer = Standard).

- Neue Aufträge tragen die Verbindung mit; der Hundeführer sieht den Knopf **„📣 Status“**.
- Seine Meldungen erscheinen bei der Einsatzleitung auf der Karte und in der Auftrags-Übersicht.
- ELW und Unterabschnitte bekommen die Verbindung (und den Schlüssel) mit der Übergabe bzw.
  „🔄 Fortschritt senden“ automatisch.

## Wenn etwas geändert werden soll

- Programmtext geändert (z. B. neue Version von `Code.gs`)? Im Apps-Script-Editor neu einfügen,
  speichern, dann **„Bereitstellen“ → „Bereitstellungen verwalten“ → Stift → Version: „Neue
  Version“ → Bereitstellen**. Die URL bleibt gleich.
- Meldungen löschen? In der Tabelle auf dem Blatt „Meldungen“ die Zeilen unter der Kopfzeile
  löschen. Nichts weiter nötig.
- Mehrere Einsätze gleichzeitig? Kein Problem: Jeder Einsatz hat seinen eigenen Schlüssel
  und damit seinen eigenen „Raum“. Eine Tabelle genügt für alle.

## Geräte freigeben und sperren (seit v113)

Jede Installation meldet sich beim Start mit einer Geräte-ID beim Server. Sperren und
Hauptschalter pflegst du direkt in der Tabelle.

1. Neuen `Code.gs` im Apps-Script-Editor einfügen, speichern, dann **„Bereitstellen“ →
   „Bereitstellungen verwalten“ → Stift → Version: „Neue Version“ → Bereitstellen**. Die URL
   bleibt gleich. Danach einmal `setup` ausführen (legt die neuen Blätter an; sie entstehen
   sonst beim ersten Aufruf von selbst).
2. **Blatt „Geräte“:** Jedes Gerät steht hier mit ID, Name (den das Gerät unter „⚙️ Mehr →
   Dieses Gerät“ trägt), Modus, Plattform (`apk` oder `web`), Version, Modell sowie „zuerst“
   und „zuletzt gesehen“. **Gerät sperren:** ein `x` (oder `ja`, `1` …) in die Spalte
   „Gesperrt“. Leer, `nein` oder `0` = frei.
3. **Blatt „Einstellungen“:** `B1` = `JA` oder `NEIN`. **`NEIN` schaltet alle Geräte ab.**
   `B2` ist die Kontaktadresse, die auf dem Sperrbildschirm steht.
4. **Wirkung:** erst beim **nächsten Start** der App. Eine laufende Sitzung läuft zu Ende.
   Gesperrte Geräte zeigen „Bitte beim Administrator melden“ mit der Geräte-ID. Wird die
   Sperre entfernt, genügt auf dem Sperrbildschirm der Knopf „Erneut prüfen“.
5. **Ohne Internet** läuft die App 14 Tage ab der letzten erfolgreichen Prüfung (beim ersten
   Start ab dem Start) weiter. Danach erscheint „Freigabe abgelaufen“, bis wieder eine
   Prüfung gelingt.

**Grenzen:** Wer den Code kopiert oder eine eigene Tabelle benutzt, ist nicht betroffen. Die
Daten bleiben auf dem Gerät; die Sperre verhindert nur das Bedienen der App, sie löscht nichts.

### Notfallcode (seit v116)

Mit dem Notfallcode lässt sich ein gesperrtes Gerät kurz entsperren, z. B. mitten in der Nacht,
wenn niemand die Tabelle pflegen kann.

1. Blatt **„Einstellungen“**: in **`B3`** (Zeile „Notfallcode“, `A3`) einen Code eintragen, z. B.
   ein Wort mit Zahl. **Leer = kein Notfallcode.** `setup` legt die Zeile an (bei älteren Tabellen
   einmal `setup` ausführen).
2. Bei jeder Prüfung schickt der Server nur den **Hash** (SHA-256) des Codes mit, nie den Code selbst.
   Die App speichert den Hash und kann den Code deshalb auch **ohne Internet** prüfen.
3. Auf dem Sperrbildschirm: **„🔑 Notfallcode eingeben“**. Ein richtiger Code entsperrt das Gerät
   **24 Stunden**, danach gilt wieder die normale Sperre. Ein falscher Code meldet „Falscher Code“.
   Kennt das Gerät keinen Code (noch nie geprüft oder leer), steht dort „Kein Notfallcode
   hinterlegt – Kontakt: …“.
4. Code nach Gebrauch ändern oder leeren – er gilt für alle Geräte.

### Nie im laufenden Einsatz (seit v116)

Läuft auf dem Gerät ein Einsatz (Einsatzleitung: Einsatz offen, nicht abgeschlossen; Hundeführer:
Auftrag vorhanden), erscheint der Sperrbildschirm **nicht**. Stattdessen steht unten ein kleiner
Hinweis „Diese Installation ist gesperrt – nach Einsatzende nicht mehr nutzbar“. Das gilt für
Sperre, Hauptschalter und abgelaufene Freigabe. Die Sperre greift beim nächsten Start bzw. bei der
nächsten Prüfung, wenn kein Einsatz mehr offen ist.

## Fehlerberichte (Notion)

Die Android-App schickt Fehlerberichte (automatisch bei Abstürzen/Fehlern und über „🐛 Fehler melden“)
an diesen Status-Server, der sie in die Notion-Fehlerzentrale (🐞 → 🐛 Suchgebiet-Karten) einträgt.
Der Notion-Token steckt **nur hier im Skript** – nicht mehr in der APK. Einrichtung (einmalig):

1. In Notion unter *Einstellungen → Verbindungen → Integrationen* die bisherige Integration öffnen und
   den **alten Token widerrufen bzw. neu erzeugen** (der alte steckt in öffentlichen APK-Versionen bis v115).
   Die Integration muss weiter Zugriff auf die Datenbank „🐛 Suchgebiet-Karten“ haben.
2. Im Apps-Script-Editor links auf das **Zahnrad (Projekteinstellungen)**, nach unten zu
   **„Skripteigenschaften“** → **„Skripteigenschaft hinzufügen“**: Name **`NOTION_TOKEN`**, Wert der
   neue Token → **Speichern**.
3. Den neuen `Code.gs` einfügen, speichern, einmal **`setup`** ausführen (Google fragt nach der
   zusätzlichen Berechtigung „Externe Dienste“ → zulassen), dann **„Bereitstellen“ →
   „Bereitstellungen verwalten“ → Stift → Version: „Neue Version“ → Bereitstellen**. Der Notion-Code
   wird also erst mit dieser neuen Version wirksam. Die URL bleibt gleich.
4. Prüfen: In der App unter „⚙️ Mehr“ **„🐛 Fehler melden“** → kurzen Text senden. Nach wenigen
   Sekunden steht eine Seite in Notion.

**Wichtig:** Ein Token gehört nie in den Code, in eine Datei im Repository oder in einen Chat.
Fehlt die Skripteigenschaft, antwortet der Server `kein Token`; die App hebt die Berichte dann auf
und sendet sie später erneut. Schutz vor Missbrauch: jedes Textfeld wird auf 2000 Zeichen gekürzt, es
werden höchstens 30 Berichte pro Stunde angenommen (danach `zu viele`).

## Häufige Fragen

- **„Es kommt nichts an.“** Hat das Hundeführer-Handy Internet? Ohne Netz wartet die Meldung
  („⏳ wartet auf Netz“) und wird automatisch nachgesendet, sobald wieder Empfang da ist.
- **Adresse falsch?** Sie muss mit `https://script.google.com/` beginnen und auf `/exec`
  enden (nicht `/dev`).
- **Zugriff „Jeder“ ist doch unsicher?** Jeder, der die Adresse *und* einen Raum-Code kennt,
  könnte verschlüsselte Zeilen abholen – ohne den Schlüssel sind sie wertlos. Die Adresse
  bitte trotzdem nicht öffentlich posten.
- **Kosten?** Keine. Für Einsätze reicht das kostenlose Kontingent von Google weit aus.
