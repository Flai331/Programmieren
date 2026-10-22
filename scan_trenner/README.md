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

## Starten

- **Windows mit Python:** `starten.bat` doppelklicken (installiert Abhängigkeiten selbst).
- **Als .exe:** `build_exe.bat` ausführen → `dist\Scan-Trenner.exe` (kein Python nötig).
- **Mac/Linux:** `pip install -r requirements.txt && python scan_trenner_gui.py`
  (unter Linux ggf. `python3-tk` installieren).

Im Fenster: Ordner wählen → **Überwachung starten**. Einzelne Dateien geht auch über
**Dateien einmal verarbeiten…**.

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
