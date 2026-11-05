# PLAN v128 – Einheiten, Funkmeldungen, Track-Import, ELW-Funde (nach v127)

Grundlage: Audit `/tmp/claude-0/-home-user/60dd75c4-66ed-54b1-a58f-5ea0be39595d/scratchpad/EINSATZ-DURCHLAUF.md`
(Abschnitte 3 und 4). Entscheidungen von Klaas (05.11.):

1. **Team-Typ (S1, K6):** Typ 🐕 Hund / 🚶 Fußtrupp-Kette / 🚙 Fahrzeug-Quad / 🚁 Drohne, Organisation
   (FF, BW, DRK, JUH, ASB, MHD, THW, Polizei, frei), Funkrufname, Personenzahl. Typ-Symbol statt festem 🐕
   (Auswahl, Chips, Plaketten, PDF-Legende). Kräfteübersicht aus Teams automatisch summiert. HF-Texte je
   Typ („Trupp zeigt an“ statt „Hund zeigt an“). Typ/Org/Funkruf gehen mit Auftrag, Übergabe, Fortschritt.
2. **Funkmeldung (M5):** „✍️ Meldung für Team eintragen“ am Team-Chip und im Status-Fenster: Suche begonnen,
   Stand %, Fund/Hinweis mit Ort (Karte tippen), Pause, abgeschlossen, Uhrzeit (Standard jetzt).
   Zählt wie HF-Meldung (Quelle „Funk“, Gerät), Auftrag gilt als übernommen, geht live/Fortschritt zum EL,
   steht im Bericht.
3. **Track-Import (M4, ohne „als abgesucht“):** Auswahlliste vor dem Import (Name, Länge, Start–Ende,
   Häkchen; „ACTIVE LOG“/ältere als 24 h vorab abgewählt), je Track Team/Auftrag zuordnen + Kennzeichen
   Hund/Mensch/Drohne, Zeit aus `<time>` speichern und anzeigen; zugeordnete Tracks zählen in der
   Auftragsübersicht (km, Zeit) wie eine HF-Rückmeldung. Tractive exportiert GPX → normal lesbar.
4. **ELW-Fund (S5):** „Fund/Hinweis eintragen“ am EL: Art (Kleidungsstück, Gegenstand, Spur, Wärmequelle,
   Sonstiges), Beschreibung, Uhrzeit, Finder (Team/Einheit/Person), Foto, Status offen/geprüft,
   optional „Prüfauftrag an Team X“ (Nachricht v117). Als Meldung mit Ort: Bericht, alle UAs (Fund/Hinweis
   gelten als „für alle“), GPX/PDF, Dringend bei Fund.
5. **UA aus mehreren Gebieten (S7):** Mehrfachauswahl Umrisse/Raster beim UA-Bilden; UA-Name umbenennbar,
   kein „UA UA …“.
6. **Auto-Abschluss (S10):** HF meldet abgeschlossen + 100 % → Auftrag ohne Rückfrage geschlossen, Toast mit
   Rückgängig. Abschlussdialog: „Als erledigt markieren“ je offenem Auftrag.
7. **UA-Übersicht beim Haupt-ELW (K3):** Tabelle UA → Teams → Stand/letzte Meldung/offen; Ampel bei UA ohne
   Rückmeldung > 60 min.
8. **Einsatzzeiten je Team (K1/K7):** Start, Pausen, Ablösung (neue Statusart), Ende/zurück am B-Ort;
   Einsatzzeit und Personenstunden im Bericht; Liste „wer ist noch draußen?“.

**Grundsatz (Klaas):** Der Einsatz muss komplett auch **ohne ELW-Laptop** nur mit Tablet oder Handy
führbar sein (Gebiete anlegen/verteilen, UAs, Aufträge, Rückmeldungen, Funkmeldungen, Funde, Übersicht,
Bericht). „ELW“ ist nur ein Gerätename, keine Voraussetzung. Alle neuen Fenster müssen auf dem Handy
(360×740, Hoch- und Querformat) bedienbar sein; Track-Import auch per Android-Dateiauswahl in der APK;
UA-Übersicht (Punkt 7) auf jedem EL-Gerät des Grund-Einsatzes. e2e: Gesamtablauf einmal nur mit
Handy-EL + HF-Handys (ohne ELW/PC) durchspielen.

Nicht: Menschenkette-Werkzeug, Drohnen-Details, „Felder entlang Spur abgesucht“.
