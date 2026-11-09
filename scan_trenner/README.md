# Scan-Trenner

Windows-/Mac-/Linux-Programm, das gescannte Stapel **automatisch an leeren Blättern
in einzelne Dokumente trennt** und die **leeren Seiten löscht**.

## So arbeitest du damit

1. Zwischen zwei Dokumente ein **leeres Blatt** legen und den ganzen Stapel in den Einzug.
2. Der Scanner speichert eine (mehrseitige) PDF oder Bilddateien im **Eingangsordner**.
3. Scan-Trenner erkennt die neue Datei, wartet bis der Scanner fertig geschrieben hat,
   und legt die Einzeldokumente im **Ausgabeordner** ab:
   `Scan_Dokument_01.pdf`, `Scan_Dokument_02.pdf`, …
   Das Original wandert nach `Eingang\erledigt`, nichts geht verloren.

Mehrere Leerseiten hintereinander zählen als *ein* Trenner. Leerseiten am Anfang/Ende
werden einfach entfernt. Scannerrand, Lochung und leichtes Rauschen werden ignoriert
(6 % Rand wird bei der Prüfung ausgelassen).

## Rechnungen im Blick (neu)

Ist **„Rechnungen erkennen“** angehakt, wird jedes fertige Dokument gelesen und – wenn es eine
Rechnung ist – im Reiter **Rechnungen** eingetragen (gespeichert als `rechnungen.json` im
Ausgabeordner):

- **Status:** zu bezahlen · wird abgebucht (Lastschrift) · bezahlt (Quittung, Kassenbon) · Gutschrift
- **Betrag** (Endbetrag, nicht MwSt/Positionen) und **Fälligkeit**: „zahlbar bis …“, „bitte überweisen
  Sie bis zum …“, „innerhalb von 14 Tagen“ (ab Rechnungsdatum), Skonto → Netto-Ziel, „sofort fällig“
- **Erinnerung** X Tage vor Fälligkeit: als Hinweisfenster, solange das Programm läuft, und als
  **Kalendereintrag** (`Ausgabe\Erinnerungen\*.ics`, Doppelklick → Outlook/Windows-Kalender) – der
  erinnert auch, wenn das Programm zu ist.
- **Arzt-/Zahnarzt-/Apothekenrechnungen** (GOÄ, GOZ, Liquidation …) werden zum **Einreichen** bei
  den eingestellten Stellen vorgemerkt: Krankenkasse, Private KV, Beihilfe, Heilfürsorge,
  Zusatzversicherung, Pflegekasse, BG, Arbeitgeber. Knöpfe *Eingereicht* → *Erstattet…* (mit Betrag,
  weniger als die Rechnung = „teilweise“) / *Abgelehnt*. Nach X Wochen ohne Erstattung kommt eine
  Nachfass-Erinnerung.
- Handwerker-/haushaltsnahe Rechnungen (§ 35a, Arbeitskosten) und Spendenbescheinigungen →
  „Steuererklärung“.

Die Erkennung braucht Text in der PDF. Am einfachsten im Scanner-Programm **„durchsuchbare PDF“
(OCR)** einstellen. Alternativ [Tesseract](https://github.com/UB-Mannheim/tesseract/wiki) mit
deutschem Sprachpaket installieren – dann liest Scan-Trenner reine Bild-Scans selbst.
Einzelne PDFs (z. B. E-Mail-Rechnungen) gehen über **„Datei als Rechnung aufnehmen…“**.

Die Regeln sind dieselben wie in der DokuBox-App (`dokumenten_system/dokubox`).

## Starten

- **Windows mit Python:** `starten.bat` doppelklicken (installiert Abhängigkeiten selbst).
- **Als .exe:** `build_exe.bat` ausführen → `dist\Scan-Trenner.exe` (kein Python nötig).
- **Mac/Linux:** `pip install -r requirements.txt && python scan_trenner_gui.py`
  (unter Linux ggf. `python3-tk` installieren).

Im Fenster: Ordner wählen → **Überwachung starten**. Einzelne Dateien geht auch über
**Dateien einmal verarbeiten…** – die Originale wandern danach in einen Ordner `erledigt` neben der jeweiligen Datei.

## Per WLAN ans Handy (DokuBox)

**„📶 Per WLAN ans Handy…“** → PDFs wählen (z. B. aus dem Ausgabeordner) → es erscheint ein
QR-Code. In der DokuBox-App *PDF importieren → Vom PC (WLAN)* wählen und den Code scannen; die
Dateien kommen direkt übers Heimnetz und werden wie ein Scan ausgelesen (Nummer, KI, Bestätigen).

- Handy und PC müssen im **selben WLAN** sein. Beim ersten Mal fragt Windows, ob Python im
  Netzwerk erlaubt ist → **„Private Netzwerke“** zulassen.
- Der Link enthält einen Zufallsschlüssel, gilt höchstens **15 Minuten** und endet mit
  „Beenden“. Es werden nur die ausgewählten Dateien ausgeliefert.
- Ohne App: denselben Link im Handy-Browser öffnen → einfache Download-Liste.

## Einstellungen

| Option | Bedeutung |
|---|---|
| Bei Leerseiten trennen | aus = Leerseiten nur löschen, alles bleibt ein Dokument |
| Leerseiten löschen | aus = Leerseiten als eigene Seite behalten (nur trennen) |
| Empfindlichkeit | Anteil dunkler Pixel, unter dem eine Seite „leer“ ist (Standard 0,30 %) |

**Wird eine Textseite fälschlich gelöscht** (z. B. fast leere Seite mit nur einer Zeile):
Empfindlichkeit senken. **Werden leere Seiten mit Flecken nicht erkannt:** erhöhen.
Der Wert wird gespeichert (`~/.scan_trenner.json`).

## Kommandozeile

```
python scan_trenner_cli.py scan.pdf                 # eine Datei
python scan_trenner_cli.py C:\Scans\Eingang         # Ordner einmal
python scan_trenner_cli.py C:\Scans\Eingang --ueberwachen
```

Weitere Optionen: `--nicht-trennen`, `--leerseiten-behalten`, `--schwelle 0.5`, `-o Ausgabe`.

Rechnungen: `--rechnungen` (erkennen + Kalendereintrag), `--stellen "Beihilfe,Heilfürsorge"`,
`--vorlauf 3`. Offene Posten anzeigen: `python scan_trenner_cli.py C:\Scans\Eingang --offene`.

## Hinweise

- Das Programm liest **Dateien**, es steuert den Scanner nicht selbst. Stelle im
  Scanner-Programm (Epson Scan, HP Smart, Brother iPrint&Scan, Windows-Faxen-und-Scannen …)
  den Speicherort auf den Eingangsordner ein.
- Duplex-Scans: Leere **Rückseiten** einzelner Blätter sind ebenfalls „leer“ und würden
  als Trenner wirken. Bei doppelseitigen Vorlagen deshalb „Bei Leerseiten trennen“
  ausschalten oder einseitig scannen.
- Scans ohne Text (Fotos, Bilder) werden mit ihren Pixeln übernommen, nicht neu komprimiert.

## Tests

```
pip install pytest
python -m pytest
```
