# Suchgebiet-Karten – Fahrplan

Dieser Fahrplan wird vom stündlichen Autopiloten abgearbeitet (siehe `AUTOPILOT.md`).
Live ist **v116**. Häkchen setzt der Autopilot; Klaas kann Einträge jederzeit ergänzen,
umsortieren oder streichen.

Legende: `[ ]` offen · `[~]` gebaut, wartet auf Klaas' Test (Testversion) · `[x]` freigegeben und live

## Neue Funktionen (gehen erst nach Klaas' Test live)

- [~] **v116 – ✅ Entscheidungen vom 31.10.**: Notion-Token nicht mehr in der APK (Fehlerberichte über den Status-Server); Freigabe sperrt nie im laufenden Einsatz, Notfallcode entsperrt 24 h; „Markieren → Fund“ meldet sofort an die EL; Meldungen mit Ort in GPX (BaseCamp-Wegpunkte), Karten-PDF und Abschlussbericht; „Einsatz abschließen“ listet offene Punkte; HF: 🎯 Mein Gebiet, 🧭 Navigation, GPS startet beim Auftrag; PIN-Hinweis.
- [~] **v115 – 👆 Bedienung (Prüfung 31.10.)**: Zoom-Knöpfe nicht mehr von Leisten verdeckt; Plakette und Aufträge zeigen die Meldungsart, Fund/Hilfe bleiben stehen; feste Team-Reihenfolge bei Chips und Aufträgen; „Standort melden“ ohne Vorauswahl; Rückfrage vor HF-Modus und vor Ersetzen eines laufenden Auftrags; Abschluss mit letztem Stand; zugeteilte Gebiete vorangekreuzt; GPX-Import ohne Duplikate; größere Tippziele, Dialoge im Querformat, bessere Kontraste und Texte.
- [~] **v114 – 🛡️ Robustheit (Prüfung 31.10.)**: Speicher-voll-Warnung statt falschem „gespeichert“; kaputter Link stoppt die Status-Synchronisation nicht mehr; Netz-Zeitlimits (Funkloch blockiert nichts mehr); Wetter-Endlosschleife behoben; Umrisse mit Schlusspunkt bleiben beim Senden erhalten; fremde Gerätenamen werden nicht mehr als HTML ausgeführt; Status-Server nur Google; Offline-Kacheln ohne sinnlose Wiederholung; Aufräumen.
- [~] **v113 – 🔒 Freigabe: Installationen abschalten**: jede Installation (APK und Web) meldet sich mit Geräte-ID beim Status-Server (Blatt „Geräte“); ein Eintrag in „Gesperrt“ sperrt ein Gerät, „App aktiv“ = NEIN im Blatt „Einstellungen“ sperrt alle. Wirkt beim nächsten Start; ohne Internet 14 Tage Frist. Sperrbildschirm mit Kontakt error.404.found@outlook.de, Geräte-ID und „Erneut prüfen“.
- [~] **v112 – 📍 Gebiete-Knopf neben der Suche**: eigenes Piktogramm (gestrichelte Fläche mit Fadenkreuz) neben dem eingeklappten Suchfeld; öffnet die Liste aller Umrisse (Name, Team, Fläche) und Raster (Felder). Antippen zentriert und zoomt die Karte auf das Gebiet, zweiter Tipp auf den Knopf schließt die Liste.
- [~] **v111 – ≡ Teams und Markierungen sortieren**: Griff ≡ an jeder Zeile (Teams-Fenster, „▦ Feld-Markierungen“) – gedrückt halten und ziehen; Teams bleiben unter Teams, Markierungen unter Markierungen. Reihenfolge gilt überall (Feld-Leiste, Listen, Legende), Zurück macht es rückgängig.
- [~] **v110 – Ausgeblendetes Team beim Malen wieder einblenden**: Wer „Feld“ wählt oder ein Team/eine Markierung zum Malen auswählt, bekommt das Raster und diese Markierung automatisch wieder eingeblendet (Hinweis „… wieder eingeblendet“) – vorher malte ein über „Felder“ ausgeblendetes Team still gar nicht.
- [~] **v109 – ✋ Langdruck auf Umriss = Punkte direkt ziehbar**: Langdruck startet sofort den Punkte-Modus (ohne Fenster). Name/Team/Notiz/Löschen weiter per Antippen.
- [~] **v108 – ✋ Umriss-Punkte, Langdruck, Ausgeblendetes geschützt**: Umriss-Fenster mit „✋ Punkte bearbeiten“ (Eckpunkte ziehen, Kantenmitte ziehen = neuer Punkt, Punkt antippen = löschen, min. 3 bzw. 2) und „🗑 Löschen“. Langdruck auf Umriss öffnet ihn (HF: eigener Bereich); Langdruck auf Feld im Raster öffnet nichts mehr. Langdruck auf „Feld“: Fenster „▦ Feld-Markierungen“ (wählen, ändern, löschen, + Team/+ Markierung). Ausgeblendetes Raster, ausgeblendete Feldfarben, B-Ort und Lage-Orte lassen sich per Tipp nicht verändern.
- [~] **v107 – 🩶 Grau für „ohne Team“**: Umrisse ohne Team immer dunkelgrau und gestrichelt (mit Team in Teamfarbe, Team weg → wieder grau). Feld-Leiste: „ohne Team“ malt Felder grau als Suchgebiet ohne Zuteilung (zählt nirgends als zugeteilt). Grau ist als Team-/Markierungsfarbe gesperrt; alte graue Teams bekommen beim Laden eine freie Farbe. PDF-Legende mit „ohne Team“.
- [~] **v106 – ↔ Raster nach dem Anlegen anpassen**: Nach dem Aufziehen (oder „Ausschnitt nehmen“) 2 Minuten lang Anfasser an Rändern und Ecken; Ziehen ändert Breite/Höhe in ganzen Feldern (mind. 1 Feld), gegenüberliegende Seite bleibt. Leiste unten mit Feldzahl, Countdown und „Fertig“. Rückgängig wie gewohnt.
- [~] **v105 – 🔍 Beschriftung und Markierungen je Zoomstufe**: Bis Stufe 14 nur Umrandungen – kein Text, keine Texte/Zeichnungen, keine Meldungs-Symbole (Fund/Hilfe, B-Ort und Lage-Orte bleiben). Stufe 15: Markierungen und Gebietsname (lange Texte gekürzt), 16: Gebietsname und Team untereinander, ab 17 dazu Fläche und Notiz. Stift/Text/Radierer zoomen bei Bedarf auf Stufe 15. PDF unverändert vollständig.
- [~] **v104 – 📋 Handy: Auftrags-Stand als eigener Reiter**: Auf dem Handy stehen keine Plaketten mehr an den Gebieten. Neben „📣 Teams“ klappt „📋 Aufträge“ eine Liste auf (Team · Gebiet, letzter Status, Stand %); Antippen zeigt das Gebiet. Teams- und Aufträge-Liste schließen sich gegenseitig, Tipp auf die Karte schließt. Tablet: Plaketten bleiben am Gebiet und jetzt sicher im Bild (nicht mehr hinter Knöpfen/außerhalb).
- [~] **v103 – 🔄 APK-Selbst-Update · 👆 Tippen schließt · 📍 Texte ändern/löschen · Plaketten nur am Gebiet**:
  - APK prüft beim Start (und unter ☰ Mehr → „Nach Update suchen“) auf eine neue Version, lädt sie und startet die Installation – nie mitten in einem offenen Einsatz ohne Rückfrage. Gilt ab der nächsten APK, v103 einmal von Hand installieren.
  - Tipp auf leere Karte schließt offene Fenster/Leisten (ohne dabei zu zeichnen); Tipp auf den dunklen Hintergrund schließt Dialoge (nicht bei Eingaben/wichtigen Rückfragen).
  - Text antippen (Bewegen oder Text-Werkzeug, auch auf die Schrift): Fenster „📍 Text“ mit Speichern / 🗑 Löschen (↶ rückgängig), 🔒-Schutz gilt.
  - Auftrags-Plaketten bleiben immer direkt am Gebiet/Raster (nicht mehr an den Bildschirmrand geschoben).
  - ✏️ Hundeführer ändern eigene Meldungen: antippen (Karte oder 📣 → „🗂 Meine Meldungen“) → Notiz ändern, 📍 verlegen, Standort entfernen, 🗑 löschen. Geht als Korrektur an die EL (Status-Server oder QR), dort „✏️ geändert“; zurückgezogene Fund/Hilfe bleiben durchgestrichen im Verlauf, Alarm endet. Eigene Bereiche umbenennen/löschen, Texte 📍 verlegen.
  - Fix: Handy-„Geisterklick“ traf nach dem Öffnen eines Fensters sofort dessen Knopf.
- [~] **v102 – 🐛 APK: neu gescannter Auftrag öffnet sich (nicht der alte)**: Mit der Handy-Kamera gescannte Auftrags-Links öffneten in der laufenden APK manchmal den alten Auftrag – wenn Android die App im Hintergrund beendet oder neu aufgebaut hatte, wurde der zuerst geöffnete Link erneut geladen und der neue ging verloren. Jetzt wird jeder Link nur einmal verwendet, und ein neuer Link während des Ladens lädt die Seite mit dem neuen Link. Wartet auf Klaas' Test.
- [~] **v101 – ✅ Auftrag abschließen · Markierungen gehen an das nächste Team mit** (Plan: `PLAN-v101-auftrag-abschliessen.md`): Hundeführer: eigener Knopf „✅ Auftrag abschließen“ im 📣 Status-Fenster (Stand je Gebiet, Grund optional, auch bei unter 100 %), Meldung „Auftrag abgeschlossen“ und danach gleich 📤 Zurückgeben; Kopfzeile „✅ abgeschlossen – bitte zurückgeben“. Einsatzleitung: Karte und Team-Chip zeigen „✅ meldet abgeschlossen hh:mm (80 %)“; Rückfrage „Auftrag {Team} abschließen?“, sobald Meldung und QR-Rückmeldung da sind (egal in welcher Reihenfolge; nach „Noch offen lassen“ nicht doppelt), dazu Knopf „✅ Abschließen“ auf jeder übernommenen Auftragskarte. Abgeschlossen: Karte grau im aufklappbaren Bereich „✅ Abgeschlossen“ mit „↩ Wieder öffnen“, Chip weg (Team frei), grüne Plakette „✅ Team · 80 %“, 🔒-Schutz entfällt. Neue Vergabe eines Gebiets (auch über Teilen → Team) nimmt Wege/Markierungen der Vorgänger-Rückmeldungen als abwählbare Gruppe „Vom vorherigen Team (Team 1, 80 %)“ mit; beim neuen Hundeführer grau, nur zum Ansehen (🔒), mit „Vorher: 80 % von Team 1 abgesucht“ im Auftragstext, gehen nicht mit zurück. Wartet auf Klaas' Test.
- [~] **v100 – 🅿️ Parkplatz Auto mit Ort · Plaketten außerhalb**: Die Meldung „🅿️ Parkplatz Auto“ fragt „Wo steht das Auto?“ – 📍 Mein Standort (hier) oder 👆 Auf der Karte setzen. Der Ort geht mit an die Einsatzleitung und steht dort als 🅿️ auf der Karte. Status-Plaketten der Gebiete stehen immer außerhalb des Gebiets (mit Verbindungslinie) und weichen Markierungen, Lage-Orten, Gebietsnamen, anderen Plaketten und den Knöpfen am Rand aus. Wartet auf Klaas' Test.
- [~] **v99 – 📤 Teilen: erst „An wen?“, dann „Was?“, dann „Wie?“** (nur Einsatzleitung, Plan: `PLAN-v99-teilen-an-wen.md`): Empfänger zuerst wählen – Hundeführer/Team (Teamauswahl, Felder und Umrisse des Teams vorausgewählt, QR-Code = Auftrag, alle Wege), Unterabschnitt (Gebiet wählen, nur QR-Code = UA), EL/ELW (ganzer Einsatz, nur QR-Code), Sonstige (alle Wege außer QR). Zwischendialog „QR-Code für …“ entfällt. Zuletzt gewählter Empfänger wird pro Gerät gemerkt. Wartet auf Klaas' Test.
- [~] **v98 – 📣 Team-Stati auf der Karte, Status-Verlauf** (nur Einsatzleitung, Plan: `PLAN-v98-status-reiter.md`): Chips je Team mit laufendem Auftrag (Team, Hund, Gebiet, letzter Status mit Uhrzeit; Fund/Hilfe rot; weg nach QR-Rückmeldung, wieder da bei neuerer Meldung). Tablet: Chips in der Kopfleiste, Suchfeld als 🔍 eingeklappt, „+n“ bei Platzmangel; Handy: Knopf „📣 Teams“ mit aufklappbarer Liste. Chip antippen: Karte springt aufs Gebiet, Infofenster mit den letzten 3 Meldungen. Neue Meldungen ohne Toast: Chip blinkt, ungelesen-Liste bei mehreren, Tipp irgendwohin = gelesen; Erinnerung nach 5 min (Banner) und 7 min (Piepton, dann alle 2 min); 💤 Schlummern (Minuten frei oder 5/10/15/30, pro Gerät; Fund/Hilfe nie betroffen). Neue Kachel „📣 Status“ mit Verlauf, Filter, Sprung zur Karte, Löschen mit Warnung und Zahl ungelesener.
- [x] **v97 – 📣 Status-Fenster neu sortiert**: erstes Fenster nur Suchstand ohne Standort (🅿️ Parkplatz Auto, ▶️ Suche begonnen, ⏹ Suche beendet, ⏸ Pause, 📊 Stand / fertig, 🏁 Zurück am B-Ort); „Suche begonnen/beendet“ bei mehreren Gebieten mit Auswahl (eins, mehrere, alle); Hund zeigt an, Person gefunden, Brauche Hilfe unter „📍 Standort melden“ (mit Standort). EL-Karte: Prozent des Stands direkt am jeweiligen Umriss/Raster.
- [x] **v95 – 📲 Auftrag erst bei Übernahme · 🔒 Schutz übernommener Aufträge · 🗑 Meldungen löschen**: Ein Auftrag gilt erst als vergeben, wenn das Team ihn übernommen hat (automatische Quittung „📲 Auftrag übernommen“ vom Hundeführer-Handy, oder erste Meldung/QR-Rückmeldung, oder manuell „✓ Team hat übernommen“; nicht übernommene Aufträge stehen grau „wartet auf Übernahme“ und lassen sich verwerfen). Felder und Zeichnungen übernommener Aufträge ändern/löschen in der EL nur nach Warnung mit „Ändern freigeben“ (5 Minuten). Status-/Standort-Meldungen auf der EL-Karte antippen → löschen nach Warnung (Löschvermerke gehen mit dem Fortschritt an andere EL-Geräte). Fehler behoben: „☰ Menü“ im Hundeführer-Modus schließt beim zweiten Tipp (Plan: `PLAN-v95-auftrag-uebernommen.md`).
- [x] **v93 – 📊 Stand statt Berechnung, Status-Plaketten**: HF schätzt selbst, wie viel abgesucht ist (erst 100 % = „Gebiet fertig“, sonst „40 % abgesucht“), keine App-Berechnung mehr. EL-Karte zeigt an jedem Gebiet mit Auftrag eine Plakette (Team, letzter Status, abgesuchte Felder; grün wenn fertig, antippen = Auftrags-Übersicht). Status-Meldungen gehen auch mit der QR-Rückmeldung mit (ohne Status-Server).
- [x] **v90 – 🔒 UA-Sperren · 🔄 Fortschritt senden** Im Unterabschnitt sind Elemente des Grund-Einsatzes ausgegraut und nur ansehbar („🔒 Gehört zum Grund-Einsatz – nur ansehen“), dem UA übergebene sind bearbeitbar, aber nicht löschbar, neu angelegte frei. „🔄 Fortschritt senden“ (Weitergeben) schickt nur zwischen Geräten der Einsatzleitung (EL, UA, ELW) per QR-Code/Link (mehrteilig möglich, nie über die Google-Tabelle) das Neue seit dem letzten Senden an das gewählte Gerät (Felder, Zeichnungen, Wege, Lage-Orte, Protokoll), mit „Alles seit Beginn erneut senden“. Zusammenführen nur ergänzend (nichts wird gelöscht, Löschvermerke blocken, neuere Änderung gewinnt, im UA-Gebiet der UA); die Übergabe des ganzen Einsatzes bleibt jederzeit möglich und führt bei schon vorhandenem Einsatz zusammen (Plan: `PLAN-v90-fortschritt.md`).
- [x] **v89 – 📣 Status-Meldungen** Hundeführer melden bei Internet Status (Anfahrt, Suche begonnen, Pause, Gebiet fertig mit Prozent, Zurück am B-Ort, Anzeige, Fund, Hilfe) und wichtige Standorte an die Einsatzleitung – Ende-zu-Ende verschlüsselt über eine eigene Google-Tabelle (Apps Script, Anleitung in `apps-script/ANLEITUNG.md`). Ohne Netz Warteschlange mit automatischem Nachsenden; die QR-Rückmeldung bleibt als Rückfallweg. EL: Symbole auf der Karte, letzter Status in der Auftrags-Übersicht, Dringend-Dialog mit Ton bei Fund/Hilfe, „Lücken zeigen“ (Plan: `PLAN-status-meldungen.md`).
- [x] **v75 – GPX/KML aus WhatsApp & Co.** „Teilen“ bzw. „Öffnen mit“ → nach Nachfrage in den laufenden Einsatz (direkt mit Klaas gebaut).

- [x] **v76 – 🐛 Fehler melden (nur Android-APK)** (direkt mit Klaas gebaut)
- [x] **v77 – Abschließen räumt auf**: nach dem Abschluss freie Karte; abgeschlossene Einsätze nur ansehen/exportieren, Ändern erst nach „Wieder öffnen“ (direkt mit Klaas gebaut).
  - Kachel „⚙️ Mehr“ → „🐛 Fehler melden“: Beschreibung eintippen, senden. Nur in der APK
    sichtbar (Web-Version bekommt keine Meldefunktion).
  - Automatische Meldung bei JavaScript-Fehlern (`window.onerror`, `unhandledrejection`) und
    bei nativen Abstürzen; gleicher Fehler höchstens alle 30 s (Fingerprint). Kurzer Hinweis
    „Fehler wurde gemeldet“, kein Dialog mitten im Einsatz.
  - Mitgeschickt: Version, Modus (EL/HF), offenes Fenster/Werkzeug, Fehlertext + Stack,
    die letzten ca. 50 Bedienschritte (Fenster geöffnet, Werkzeug gewechselt, Knopf gedrückt),
    Gerät (`Build.MODEL`), Android-Version. **Keine Einsatzdaten**: keine Namen, Personen-
    beschreibung, Kontakte, Telefonnummern, Koordinaten, Notizen, Fotos.
  - Senden nativ in Kotlin (`@JavascriptInterface`), POST an die Notion-API
    (`https://api.notion.com/v1/pages`, `Notion-Version: 2022-06-28`) in die Datenbank
    `5574dcecd7e84a0aa79446bab3915a47` (🐞 Fehlerzentrale → 🐛 Suchgebiet-Karten).
    Eigenschaften: Titel, Status=Offen, Art (Absturz/Auto-Fehler/Manuelle Meldung),
    Plattform=Android, Beschreibung, Fehler, Protokoll, Seite, Benutzerrolle (EL/HF), Gerät,
    OS, Version, Fingerprint, Zeitstempel. Texte auf 2000 Zeichen je Feld kürzen.
  - **Seit v116:** Der Token steckt nicht mehr in der APK. Die App schickt `{ rep: {…} }` an den Status-Server
    (Apps Script, `bericht_`), der Token liegt dort in der Skripteigenschaft `NOTION_TOKEN` (siehe apps-script/ANLEITUNG.md).
    Die folgenden Angaben zum Token gelten nur bis v115.
  - Token: `BuildConfig.NOTION_TOKEN` aus der Umgebungsvariable `NOTION_TOKEN` (GitHub-Secret,
    im Workflow schon durchgereicht). Ohne Token oder ohne Netz: Meldung in einer Warteschlange
    (SharedPreferences) speichern und beim nächsten Start erneut senden; bei manueller Meldung
    ohne Token stattdessen Mail-App mit dem Bericht an klaasotte99@gmail.com öffnen.
  - Tests: Unit-Test für das Zusammenstellen des Berichts (keine Einsatzdaten enthalten,
    Kürzung, Fingerprint); im CI-Emulator-Test darf kein Bericht ausgelöst werden.

- [x] **v80 – 📤 Weitergeben** statt Export: „Was?“ (ganzer Einsatz, Team, Gebiet, eigene Auswahl) und „Wie?“ (QR an HF oder EL/ELW, Garmin-App, Mail/BaseCamp, Speichern, PDF, Einsatz-Datei) (direkt mit Klaas gebaut).
- [x] **v88 – ▦ Feld lange drücken**: Team zuteilen, Markierung setzen, neue Teams/Markierungen anlegen, Markierungen umbenennen/umfärben/löschen. Teams-Fenster nur noch für Teams (keine Legende); Deckkraft-Regler ins Raster-Fenster.
- [x] **v87 – 📋 Auftrags-Übersicht für die EL** (Teams-Fenster): je Auftrag Team (Farbe, Hund), was (Gebiete/Felder, Umrisse, Hinweis), seit wann, Zahl und Zeit der Rückmeldungen mit gelaufenen km; > 60 min ohne Rückmeldung orange „nachfragen?“.
- [x] **v86 – 🗺️ Standard-Kartenart pro Gerät** (⚙️ Mehr → Dieses Gerät): gilt für neue Einsätze, übernommene Aufträge, Übergaben und geladene Dateien (`db.defaultLayer`).
- [x] **v85 – 📦 Offline-Paket fürs Einsatzgebiet** (Idee 9): ein Tipp unter „Karte“ bzw. im HF-Menü lädt die aktuelle Kartenart fürs ganze Einsatzgebiet (Raster, Zeichnungen, B-Ort, Lage-Orte + 500 m Rand) so scharf, wie der Speicher erlaubt (≤ 400 MB, Stufe 12–17), und speichert das Wetter (`missionBounds`, `packageZooms` in `web/offline.js`).
- [x] **v84 – Ein „📷 Scannen“-Knopf** für alles (Randleiste) und einheitliche Dateinamen `Einsatz_JJJJ-MM-TT_HHMM_Inhalt.ext` (`web/files.js`).
- [x] **v79 – GPX-Auswahl für die Garmin-App**: einzelne Umrisse, Striche, Texte, Lage-Orte, Felder antippen; Umriss nimmt alles darin mit, „Ganzes Raster“ alles im Gebiet (direkt mit Klaas gebaut).
- [x] **v78 – Freie Karte ohne Einsatz nur ansehen** (Einzeichnen erst nach „+ Neuer Einsatz“; Suchnadel verschwindet beim Wechsel).
- [x] **v78 – 📍 Lage-Orte** (direkt mit Klaas gebaut; Details: `PLAN-einsatz-assistent.md`, Abschnitt D)
  - Werkzeug „📍 Lage-Ort“ für EL-Geräte; Kategorien 🚐 ELW, 🅱️ Bereitstellungsraum,
    🅿️ Parkplatz, 🚻 Toilette, 🍲 Verpflegung, 🚰 Ver-/Entsorgung, 🚑 Sanität,
    ❓ letzter bekannter Ort, 📌 Sonstiges.
  - Ort per GPS, Kartentipp oder Adresse; Name und Beschreibung; antippen = bearbeiten/löschen.
  - Auf der Karte, im PDF (Karte + Liste auf der Infoseite) und im GPX (Wegpunkte für BaseCamp).
  - Gehen bei der Übergabe an ein weiteres EL-Gerät (`#e=`) mit.
  - Neue Logik in `web/pois.js` mit Unit-Tests.

- [x] **v83 – 📲 Links in der App öffnen**: App-Links-Freigabe im Repo Flai331.github.io (`assetlinks.json`); zusätzlich fragt die Webseite im Android-Browser „In der App öffnen?“ (intent:-Link, `?h=…`, braucht APK ≥ v83).
- [x] **v82 – 🛰️ Standort: kein ungefragtes Springen** (direkt mit Klaas gebaut)
  - **Wind messen ohne aktuellen Standort**: vor dem Speichern den Standort neu holen
    (`getCurrentPosition`, kurz warten), statt die Kartenmitte zu nehmen; nur wenn das scheitert, Kartenmitte mit Hinweis.
  - **HF-Modus**: Karte folgt dem Standort nur, solange ein Weg aufgezeichnet wird (⏺ Weg).
    Ohne Aufzeichnung kein automatisches Springen – auch nicht, wenn der Standort für „Punkt melden“ eingeschaltet wird.
  - **EL-Modus**: nie automatisch zum Standort springen oder folgen; nur beim Tippen auf „GPS“
    (einmal hinspringen; ist GPS schon an, springt ein Tipp wieder hin, liegt man schon in der Mitte, schaltet er aus).
  - **Weg-Aufzeichnung nach dem Schließen fortsetzen**: Wird die App während „⏺ Weg“ geschlossen
    (oder vom Handy beendet), läuft die Aufzeichnung beim nächsten Öffnen automatisch weiter –
    aber erst, wenn wieder ein genauer Standort da ist (Genauigkeit ≤ 20 m), damit kein falscher Strich entsteht.
    Bis dahin Knopf „⏳ wartet auf GPS …“. Neues Wegstück (keine Linie quer über die Lücke).
    Umsetzung: `P.hf.recOn` speichern, beim Start `startRec({ resume: true })`.
  - Umsetzung: `btn-gps`-Handler in `startGps({ jump })` aufteilen; Mitführen nur bei `db.mode === 'hf' && recWatch !== null`;
    Wind: in `.wm-str`-Klick `lastPos` prüfen, sonst Position holen.
- [x] **v81 – 📑 Unterabschnitt an andere EL**: Gebiet/Umriss per QR an EL/ELW → Frage „ganzer Einsatz“ oder „Unterabschnitt“ (nur das Gebiet + B-Ort, Lage-Orte, Stammdaten, Protokoll; Infos fließen zum Grund-Einsatz zurück).
- [x] **v81 – 📍 Infos an EL senden** (in „📤 Weitergeben“, `#i=`, Logik in `web/infos.js`; ergänzt beim Einsatzleiter nur – löschen nur er selbst; direkt mit Klaas gebaut)
  - „📤 Infos senden“: neue/geänderte/gelöschte Lage-Orte (optional Kontakte) per QR-Code
    oder Link, mit Gerätename (`db.deviceName`) als Absender; beide Richtungen.
  - Zusammenführen ohne Duplikate (feste IDs + Änderungszeit), gelöschte verschwinden auch
    beim Empfänger, mehrfach scannen schadet nicht. Meldung z. B.
    „📥 Infos von ELW 11-1: 3 neu, 1 geändert“.
  - `#i=` in `parseShared`, Android-`sharedHash` und Tab-Übergabe (`handOff`) ist schon vorbereitet.
  - Ohne Gerätename vor dem ersten Senden danach fragen.

- [x] **v80 – Lage-Orte an Hundeführer**: im Auftrag anhakbar (alle vorausgewählt), erscheinen auf der HF-Karte (mit v80 gebaut).

## Aus „💡 Ideen & Features“ übernommen

(Der Autopilot trägt hier neue Ideen mit App = „RHS Einsatz App“ ein.)

## Fehlerbehebungen (gehen sofort live)

(Der Autopilot trägt hier behobene Meldungen aus der 🐞 Fehlerzentrale ein: Datum, Version, Kurzbeschreibung.)

- 30.10.2026, v96: Status-Taste „🚗 Anfahrt“ ersetzt durch „🅿️ Parkplatz Auto“ (am Suchgebiet angekommen, mit Standort).
- 30.10.2026, v94: Einsatzleitung holt Status-Meldungen alle 15 s (statt 30 s). Stand je Gebiet: wer mehrere Gebiete hat, meldet je Gebiet einen eigenen Regler („📊 Nord 40 % · Süd ✅“); „Alle Gebiete fertig“ erst bei 100 % überall.
- 30.10.2026, v92: Auftrag/Weitergeben: Texte und Zeichnungen, die im Umriss oder in den Feldern des Teams liegen, sind vorausgewählt; ein angehaktes Raster nimmt alles darin mit (außer Umrissen anderer Teams).
- 30.10.2026, v91: Uhrzeiten (Alarmierung, Eintreffen …) im Assistenten und im Fenster „Einsatz“ als eigenes Feld mit Ziffern-Tastatur (z. B. 1430) statt Android-Uhrzeit-Dialog, dem der Bestätigen-Knopf fehlte.
- 30.10.2026, v86: Einsatz-/Auftragsliste zeigt Namen vollständig (Knöpfe darunter); doppelter Zoom (+/−) unten rechts entfernt – die rechte Leiste verdeckte ihn, der Zoom-Regler links bleibt.

## Rückfragen an Klaas

(Offene Fragen zu Ideen oder Meldungen; die Frage steht zusätzlich als Kommentar in Notion.)
