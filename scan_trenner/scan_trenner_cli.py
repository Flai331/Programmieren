"""Kommandozeile: einmalig verarbeiten oder Ordner überwachen."""
from __future__ import annotations

import argparse
import shutil
import sys
import time
from pathlib import Path

import rechnungen as rg
from scan_trenner_core import (
    Einstellungen, datei_ist_fertig, sammle_dateien, verarbeite_datei,
)


def bericht(erg) -> str:
    if erg.fehler:
        return f"FEHLER  {erg.quelle.name}: {erg.fehler}"
    return (f"{erg.quelle.name}: {erg.seiten_gesamt} Seiten, "
            f"{len(erg.leerseiten)} leer -> {len(erg.ausgabedateien)} Dokument(e)")


def rechnungen_erfassen(erg, aus: Path, buch: rg.Rechnungsbuch, re: rg.Rechnungseinstellungen) -> None:
    for pdf in erg.ausgabedateien:
        r, hinweis = rg.erfasse(pdf, buch, re, aus / "Erinnerungen")
        if hinweis:
            print(f"HINWEIS {hinweis}", flush=True)
        if r:
            print(f"  Rechnung {pdf.name}: {rg.kurzbericht(r)}", flush=True)


def offene_posten(buch: rg.Rechnungsbuch) -> None:
    for text in buch.faellige_erinnerungen():
        print(f"ERINNERUNG {text}")
    offen = buch.offene()
    print(f"Zu bezahlen: {len(offen)} · {rg.euro(sum(r.betrag_cent or 0 for r in offen)) or '0,00 €'}")
    for r in offen:
        markierung = "ÜBERFÄLLIG " if r.ueberfaellig() else ""
        print(f"  {markierung}{r.titel}: {rg.kurzbericht(r)}")
    erst = buch.offene_erstattungen()
    print(f"Erstattungen offen: {len(erst)}")
    for r, x in erst:
        print(f"  {x.stelle} ({x.status}): {r.titel} {rg.euro(r.betrag_cent)}")


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
    p.add_argument("--rechnungen", action="store_true",
                   help="Rechnungen erkennen (Betrag, Fälligkeit, Status) und Erinnerungen anlegen")
    p.add_argument("--stellen", default="Krankenkasse",
                   help="Wo Arztrechnungen eingereicht werden, kommagetrennt (z. B. \"Beihilfe,Heilfürsorge\")")
    p.add_argument("--vorlauf", type=int, default=3, help="Tage vor Fälligkeit erinnern (Standard 3)")
    p.add_argument("--offene", action="store_true",
                   help="Nur offene Rechnungen/Erstattungen aus dem Ausgabeordner anzeigen")
    a = p.parse_args(argv)
    re_e = rg.Rechnungseinstellungen(vorlauf_tage=a.vorlauf,
                                     stellen=[s.strip() for s in a.stellen.split(",") if s.strip()])

    e = Einstellungen(tinten_schwelle=a.schwelle / 100, trennen=not a.nicht_trennen,
                      leerseiten_loeschen=not a.leerseiten_behalten)
    if a.offene:
        aus = a.ausgabe or (a.eingang if a.eingang.is_dir() else a.eingang.parent) / "fertig"
        offene_posten(rg.Rechnungsbuch.im_ordner(aus))
        return 0
    if a.eingang.is_file():
        aus = a.ausgabe or a.eingang.parent / "fertig"
        erg = verarbeite_datei(a.eingang, aus, e)
        print(bericht(erg))
        if a.rechnungen and not erg.fehler:
            rechnungen_erfassen(erg, aus, rg.Rechnungsbuch.im_ordner(aus), re_e)
        return 1 if erg.fehler else 0

    aus = a.ausgabe or a.eingang / "fertig"
    buch = rg.Rechnungsbuch.im_ordner(aus) if a.rechnungen else None
    gesehen: dict[Path, tuple[int, float]] = {}
    while True:
        for f in sammle_dateien(a.eingang):
            fertig, gesehen[f] = datei_ist_fertig(f, gesehen.get(f))
            if fertig or not a.ueberwachen:  # Einmal-Lauf: Dateien sind schon fertig
                erg = verarbeite_datei(f, aus, e)
                print(bericht(erg), flush=True)
                if not erg.fehler:
                    if buch is not None:
                        rechnungen_erfassen(erg, aus, buch, re_e)
                    erledigt_verschieben(f, a.eingang)
                gesehen.pop(f, None)
        if not a.ueberwachen:
            return 0
        if buch is not None:
            for text in buch.faellige_erinnerungen():
                print(f"ERINNERUNG {text}", flush=True)
        time.sleep(2)


if __name__ == "__main__":
    sys.exit(main())
