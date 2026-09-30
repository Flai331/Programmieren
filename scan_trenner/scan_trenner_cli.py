"""Kommandozeile: einmalig verarbeiten oder Ordner überwachen."""
from __future__ import annotations

import argparse
import shutil
import sys
import time
from pathlib import Path

from scan_trenner_core import (
    Einstellungen, datei_ist_fertig, sammle_dateien, verarbeite_datei,
)


def bericht(erg) -> str:
    if erg.fehler:
        return f"FEHLER  {erg.quelle.name}: {erg.fehler}"
    return (f"{erg.quelle.name}: {erg.seiten_gesamt} Seiten, "
            f"{len(erg.leerseiten)} leer -> {len(erg.ausgabedateien)} Dokument(e)")


def erledigt_verschieben(quelle: Path, eingang: Path) -> None:
    ziel = eingang / "erledigt"
    ziel.mkdir(exist_ok=True)
    name = quelle.name
    if (ziel / name).exists():
        name = f"{quelle.stem}_{int(time.time())}{quelle.suffix}"
    shutil.move(str(quelle), str(ziel / name))


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Scans an Leerseiten trennen und Leerseiten löschen.")
    p.add_argument("eingang", type=Path, help="Datei oder Ordner")
    p.add_argument("-o", "--ausgabe", type=Path, help="Ausgabeordner (Standard: <eingang>/fertig)")
    p.add_argument("--ueberwachen", action="store_true", help="Ordner dauerhaft überwachen")
    p.add_argument("--nicht-trennen", action="store_true", help="Leerseiten nur löschen, nicht trennen")
    p.add_argument("--leerseiten-behalten", action="store_true", help="Leerseiten nicht löschen")
    p.add_argument("--schwelle", type=float, default=0.3, help="Tinten-Schwelle in Prozent (Standard 0.3)")
    a = p.parse_args(argv)

    e = Einstellungen(tinten_schwelle=a.schwelle / 100, trennen=not a.nicht_trennen,
                      leerseiten_loeschen=not a.leerseiten_behalten)
    if a.eingang.is_file():
        aus = a.ausgabe or a.eingang.parent / "fertig"
        erg = verarbeite_datei(a.eingang, aus, e)
        print(bericht(erg))
        return 1 if erg.fehler else 0

    aus = a.ausgabe or a.eingang / "fertig"
    gesehen: dict[Path, tuple[int, float]] = {}
    while True:
        for f in sammle_dateien(a.eingang):
            fertig, gesehen[f] = datei_ist_fertig(f, gesehen.get(f))
            if fertig or not a.ueberwachen:  # Einmal-Lauf: Dateien sind schon fertig
                erg = verarbeite_datei(f, aus, e)
                print(bericht(erg), flush=True)
                if not erg.fehler:
                    erledigt_verschieben(f, a.eingang)
                gesehen.pop(f, None)
        if not a.ueberwachen:
            return 0
        time.sleep(2)


if __name__ == "__main__":
    sys.exit(main())
