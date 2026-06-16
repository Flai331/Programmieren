# Wärmefluss-Rechner

Konsolen-Programm (C++) zur Berechnung von Wärmefluss, Wärmeübergang und
Heizkosten – auf Basis des Fourier'schen Wärmeleitungsgesetzes und der
Wärmeübergangsberechnung nach DIN EN ISO 6946.

## Funktionen

| Modus | Berechnung |
|-------|-----------|
| 1 | Einfache (homogene) Wand – q, Q, R', U-Wert |
| 2 | Mehrschichtige Verbundwand – mit Temperaturprofil |
| 3 | Wärmestromdichte aus Temperaturgradient (`q = -λ·dT/dx`) |
| 4 | Wand mit Wärmeübergang – U-Wert (DIN EN ISO 6946), Oberflächentemperaturen, Tauwasser-Check |
| 5 | Rohr / Zylinder – radiale Wärmeleitung (mehrschichtig, optional Konvektion) |
| 6 | Energie & Heizkosten über Zeit (kWh, € – mit Hochrechnung) |
| 7 | Materialdatenbank (26 Materialien) |
| 8 | Protokoll als Textdatei exportieren |

## Verwenden (Windows)

Einfach **`waermefluss.exe`** doppelklicken – keine Installation nötig.
Die Datei ist statisch gelinkt und läuft eigenständig auf Windows 10/11
(64-Bit). Für korrekt dargestellte Sonderzeichen empfiehlt sich das
moderne *Windows Terminal*.

## Selbst bauen

```bash
./build.sh
```

Voraussetzungen:
- Linux/Mac:  `g++` (C++17)
- Windows-.exe (Cross-Build):  `sudo apt-get install g++-mingw-w64-x86-64`

Oder direkt:

```bash
# Linux
g++ -std=c++17 -O2 -o waermefluss waermefluss.cpp

# Windows-.exe (von Linux aus, eigenständig)
x86_64-w64-mingw32-g++ -std=c++17 -O2 -static -static-libgcc -static-libstdc++ \
    -o waermefluss.exe waermefluss.cpp
```
