# Abgleich über Google-Tabelle einrichten (einmalig, ca. 10 Minuten)

Damit PC und Handy denselben Stand haben (Rollen, Lagerplätze, Drucke, Aufträge, Fotos),
dient eine **eigene Google-Tabelle** als Server. Fotos und angehängte Dateien landen in einem
Ordner in **deinem Google Drive**. Die App funktioniert weiter offline und gleicht ab, sobald
wieder Internet da ist. Am Computer geht die Einrichtung am einfachsten.

## 1. Tabelle anlegen
1. <https://sheets.google.com> öffnen, mit dem Google-Konto anmelden.
2. **Leere Tabelle** anlegen, oben links umbenennen, z. B. in **„Filament-Manager“**.

## 2. Programm einfügen
1. Menü **Erweiterungen → Apps Script**.
2. Den vorhandenen Text (`function myFunction() { … }`) komplett löschen.
3. Den gesamten Inhalt von `Code.gs` (dieser Ordner) einfügen.
4. **Speichern** (Disketten-Symbol). Projektname z. B. „Filament-Server“.

## 3. Einmal „setup“ ausführen
1. Oben neben „Ausführen“ die Funktion **`setup`** auswählen → **Ausführen**.
2. Google fragt nach Berechtigungen: **Berechtigung prüfen** → Konto wählen → **Erweitert** →
   **„Filament-Server (unsicher) öffnen“** → **Zulassen**. Das ist normal bei eigenen Skripten.
   Benötigt werden: Tabelle bearbeiten, Drive (Foto-Ordner), externe Dienste (Bambu-Cloud) und
   Zeitauslöser (Drucke alle 30 Minuten holen).
3. In der Tabelle gibt es jetzt die Blätter **Einrichtung**, **Rollen**, **Drucke**,
   **Auftraege**, **Einstellungen**, **Eingang** und in Drive den Ordner
   **„Filament-Manager Fotos & Dateien“**.

## 4. Als Web-App veröffentlichen
1. **Bereitstellen → Neue Bereitstellung**.
2. Zahnrad neben „Typ auswählen“ → **Web-App**.
3. **Ausführen als: Ich**, **Zugriff: Jeder** → **Bereitstellen**.
4. Die **Web-App-URL** kopieren (`https://script.google.com/macros/s/…/exec`).

„Jeder“ ist nötig, damit die App ohne Google-Anmeldung zugreifen kann. Geschützt ist alles
durch den **Schlüssel**: Ohne ihn antwortet der Server nur mit „Falscher Schlüssel“.

## 5. In der App verbinden (auf jedem Gerät)
1. Filament-Manager → **Mehr → Abgleich zwischen Geräten**.
2. Web-App-URL und den **Schlüssel** (Blatt „Einrichtung“, Zelle B1) eintragen → **Verbinden**.
3. Zuerst am Gerät mit den Daten verbinden (z. B. PC), dann am Handy.

Oben rechts zeigt die App den Stand: ☁️✓ abgeglichen · ☁️• Änderungen offen · ⟳ läuft · ⚠️ Fehler
(antippen = sofort abgleichen).

## 6. Bambu-Cloud: Drucke automatisch holen (optional)
1. In der App: **Mehr → Bambu-Cloud → Bei Bambu anmelden**.
2. E-Mail und Passwort deines Bambu-Kontos eingeben, Datum „Drucke übernehmen ab“ wählen
   (Standard: heute – ältere Drucke würden sonst von Rollen abgezogen, die du schon frisch erfasst hast).
3. Bambu schickt einen **Code per E-Mail** → in der App eingeben.
4. Fertig. Das Google-Script holt jetzt **alle 30 Minuten** neue, fertige Drucke (auch wenn PC und Handy aus
   sind). In der App erscheint unter „Drucke“ **„Neue Drucke vom Drucker“** – Rollen prüfen, **Buchen**.

- Gespeichert wird im Script nur das Zugangs-Token, **nicht das Passwort**. Das Token wird automatisch
  verlängert; falls nicht, zeigt die App „bitte neu anmelden“.
- Abgebrochene Drucke: Bambu meldet den geplanten Verbrauch – bei „Gedruckt bis (%)“ angeben, wie weit er kam.
- Drucke mit unklarem Status (Bambu nennt die Codes nicht) bekommen den Hinweis „Ergebnis prüfen“.
- Die Bambu-Schnittstelle ist nicht offiziell dokumentiert. Falls der Abruf vom Google-Server aus nicht
  klappt (Fehler in „Mehr → Bambu-Cloud“), geht es vom Laptop aus:
  `python tools/bambu_cloud_export.py --save-token --server <Web-App-URL> --key <Schlüssel>`
  – das legt die Drucke in denselben Eingang.

## Update von einer älteren Code.gs-Version
1. Code.gs komplett ersetzen und speichern.
2. **`setup` erneut ausführen** – neue Berechtigungen erlauben (Zugriff auf externe Dienste für Bambu,
   Zeitauslöser). Daten und Schlüssel bleiben erhalten.
3. **Bereitstellen → Bereitstellungen verwalten → Bearbeiten → Version: Neue Version → Bereitstellen.**

## Gut zu wissen
- **Konflikte:** Ändern zwei Geräte denselben Eintrag, gewinnt die spätere Änderung.
- **Tabelle nur ansehen:** Die Spalten ab „Marke“/„Datum“/„Titel“ sind eine Übersicht zum
  Filtern und Drucken. Änderungen dort werden nicht in die App übernommen – bitte in der App ändern.
  Die Spalten ID bis Prüfsumme nicht anfassen.
- **Gelöschte Einträge** bleiben als Zeile mit „Gelöscht = 1“ stehen (damit alle Geräte es erfahren).
- **Fotos:** Entfernte Fotos landen im Drive-Papierkorb.
- **Neue Code.gs-Version:** Code ersetzen, speichern, dann **Bereitstellen → Bereitstellungen
  verwalten → Bearbeiten (Stift) → Version: Neue Version → Bereitstellen**. So bleibt die URL gleich.
- **Schlüssel geändert/verraten?** Im Apps-Script-Editor: Projekteinstellungen → Skripteigenschaften →
  `schluessel` löschen, `setup` erneut ausführen, neuen Schlüssel auf allen Geräten eintragen.
