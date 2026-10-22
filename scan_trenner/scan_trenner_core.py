"""Kernlogik: Leerseiten erkennen, Dokumente trennen, Leerseiten löschen.

Ohne Oberfläche, damit sie von GUI, Kommandozeile und Tests gleich genutzt wird.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Iterable

import pymupdf as fitz  # PyMuPDF

BILD_ENDUNGEN = {".jpg", ".jpeg", ".png", ".tif", ".tiff", ".bmp"}
PDF_ENDUNG = ".pdf"


@dataclass
class Einstellungen:
    # Anteil "dunkler" Pixel, unter dem eine Seite als leer gilt (0.003 = 0,3 %).
    # Normaler Text liegt meist bei 2-10 %, Scannerrauschen unter 0,1 %.
    tinten_schwelle: float = 0.003
    # Ab dieser Helligkeit (0-255) gilt ein Pixel als Papier, darunter als Tinte.
    helligkeit_papier: int = 170
    # Rand, der bei der Prüfung ignoriert wird (Scannerschatten, Lochung, Kanten).
    rand_prozent: float = 6.0
    # Auflösung, mit der geprüft wird. Niedrig = schnell, reicht völlig aus.
    pruef_dpi: int = 50
    # Mehrere Leerseiten hintereinander zählen als ein einziger Trenner.
    leerseiten_zusammenfassen: bool = True
    # True: an Leerseiten trennen. False: Leerseiten nur löschen.
    trennen: bool = True
    # Leere Rückseiten mitten im Dokument (Duplex) behalten? Nur relevant, wenn
    # trennen=False; beim Trennen ist jede Leerseite ein Trenner.
    leerseiten_loeschen: bool = True


@dataclass
class Ergebnis:
    quelle: Path
    seiten_gesamt: int = 0
    leerseiten: list[int] = field(default_factory=list)  # 1-basiert
    ausgabedateien: list[Path] = field(default_factory=list)
    fehler: str | None = None


def tinten_anteil(seite: fitz.Page, e: Einstellungen) -> float:
    """Anteil dunkler Pixel (0..1) im Innenbereich der Seite."""
    zoom = e.pruef_dpi / 72.0
    pix = seite.get_pixmap(matrix=fitz.Matrix(zoom, zoom), colorspace=fitz.csGRAY, alpha=False)
    breite, hoehe, daten = pix.width, pix.height, pix.samples
    rx = int(breite * e.rand_prozent / 100)
    ry = int(hoehe * e.rand_prozent / 100)
    dunkel = 0
    gesamt = 0
    for y in range(ry, hoehe - ry):
        zeile = daten[y * breite + rx : y * breite + breite - rx]
        gesamt += len(zeile)
        dunkel += sum(1 for p in zeile if p < e.helligkeit_papier)
    return dunkel / gesamt if gesamt else 0.0


def ist_leer(seite: fitz.Page, e: Einstellungen) -> bool:
    return tinten_anteil(seite, e) < e.tinten_schwelle


def _bild_als_pdf(pfad: Path) -> fitz.Document:
    """Bilddatei (auch mehrseitiges TIFF) als PDF-Dokument öffnen."""
    bild = fitz.open(str(pfad))
    pdf_bytes = bild.convert_to_pdf()
    bild.close()
    return fitz.open("pdf", pdf_bytes)


def _oeffnen(pfad: Path) -> fitz.Document:
    if pfad.suffix.lower() in BILD_ENDUNGEN:
        return _bild_als_pdf(pfad)
    return fitz.open(str(pfad))


def gruppen_bilden(leer: list[bool], e: Einstellungen) -> list[list[int]]:
    """Seitenindizes (0-basiert) in Dokumente aufteilen.

    Leerseiten werden nie übernommen, wenn leerseiten_loeschen gilt.
    """
    if not e.trennen:
        return [[i for i, l in enumerate(leer) if not (l and e.leerseiten_loeschen)]]
    gruppen: list[list[int]] = []
    aktuell: list[int] = []
    for i, ist_l in enumerate(leer):
        if ist_l:
            if aktuell:
                gruppen.append(aktuell)
                aktuell = []
            if not e.leerseiten_loeschen:
                gruppen.append([i])
        else:
            aktuell.append(i)
    if aktuell:
        gruppen.append(aktuell)
    return gruppen


def _freier_name(ordner: Path, basis: str) -> Path:
    ziel = ordner / f"{basis}.pdf"
    n = 2
    while ziel.exists():
        ziel = ordner / f"{basis}_{n}.pdf"
        n += 1
    return ziel


def verarbeite_datei(
    quelle: Path,
    ausgabe_ordner: Path,
    e: Einstellungen | None = None,
    fortschritt: Callable[[int, int], None] | None = None,
) -> Ergebnis:
    """Eine PDF-/Bilddatei prüfen, trennen und Leerseiten entfernen."""
    e = e or Einstellungen()
    erg = Ergebnis(quelle=quelle)
    try:
        doc = _oeffnen(quelle)
    except Exception as exc:  # defekte oder gesperrte Datei
        erg.fehler = f"Datei konnte nicht geöffnet werden: {exc}"
        return erg
    try:
        if doc.needs_pass:
            erg.fehler = "Datei ist passwortgeschützt."
            return erg
        n = doc.page_count
        erg.seiten_gesamt = n
        leer: list[bool] = []
        for i in range(n):
            leer.append(ist_leer(doc[i], e))
            if fortschritt:
                fortschritt(i + 1, n)
        erg.leerseiten = [i + 1 for i, l in enumerate(leer) if l]
        gruppen = gruppen_bilden(leer, e)
        ausgabe_ordner.mkdir(parents=True, exist_ok=True)
        stamm = quelle.stem
        if not gruppen:
            return erg  # nur Leerseiten: nichts zu speichern
        for nr, seiten in enumerate(gruppen, start=1):
            neu = fitz.open()
            for s in seiten:
                neu.insert_pdf(doc, from_page=s, to_page=s)
            basis = stamm if len(gruppen) == 1 else f"{stamm}_Dokument_{nr:02d}"
            ziel = _freier_name(ausgabe_ordner, basis)
            neu.save(str(ziel), garbage=3, deflate=True)
            neu.close()
            erg.ausgabedateien.append(ziel)
        return erg
    finally:
        doc.close()


def sammle_dateien(ordner: Path) -> list[Path]:
    endungen = BILD_ENDUNGEN | {PDF_ENDUNG}
    return sorted(p for p in ordner.iterdir() if p.is_file() and p.suffix.lower() in endungen)


def datei_ist_fertig(pfad: Path, alt: tuple[int, float] | None) -> tuple[bool, tuple[int, float]]:
    """Scanner schreiben Dateien nach und nach: erst wenn Größe und Zeitstempel
    zwischen zwei Prüfungen gleich bleiben, ist die Datei fertig."""
    try:
        st = pfad.stat()
    except OSError:
        return False, (0, 0.0)
    jetzt = (st.st_size, st.st_mtime)
    return (alt == jetzt and st.st_size > 0), jetzt
