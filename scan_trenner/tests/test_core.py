import sys
from pathlib import Path

import pymupdf as fitz

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from scan_trenner_core import Einstellungen, verarbeite_datei, gruppen_bilden, sammle_dateien
import scan_trenner_cli


def baue_pdf(pfad: Path, muster: str, rauschen: bool = False) -> Path:
    """muster: T = Textseite, L = leer, R = leer mit Scannerrand/Rauschen."""
    doc = fitz.open()
    for i, c in enumerate(muster):
        seite = doc.new_page()
        if c == "T":
            seite.insert_text((72, 100), f"Seite {i} " + "Lorem ipsum dolor sit amet " * 3, fontsize=14)
            for z in range(12):
                seite.insert_text((72, 140 + z * 24), "Text Text Text Text Text Text Text Text", fontsize=12)
        elif c == "R":
            seite.draw_rect(fitz.Rect(0, 0, 8, 842), color=(0, 0, 0), fill=(0, 0, 0))  # Scannerkante
            seite.draw_circle(fitz.Point(15, 400), 4, color=(0, 0, 0), fill=(0, 0, 0))  # Lochung
    doc.save(str(pfad))
    doc.close()
    return pfad


def seitenzahlen(erg):
    out = []
    for p in erg.ausgabedateien:
        d = fitz.open(str(p))
        out.append(d.page_count)
        d.close()
    return out


def test_trennt_an_leerseiten(tmp_path):
    q = baue_pdf(tmp_path / "scan.pdf", "TTLTTTLT")
    erg = verarbeite_datei(q, tmp_path / "aus")
    assert erg.leerseiten == [3, 7]
    assert seitenzahlen(erg) == [2, 3, 1]
    assert [p.name for p in erg.ausgabedateien][0] == "scan_Dokument_01.pdf"


def test_mehrere_leerseiten_sind_ein_trenner(tmp_path):
    q = baue_pdf(tmp_path / "scan.pdf", "TLLLTT")
    erg = verarbeite_datei(q, tmp_path / "aus")
    assert seitenzahlen(erg) == [1, 2]


def test_scannerrand_und_lochung_zaehlen_als_leer(tmp_path):
    q = baue_pdf(tmp_path / "scan.pdf", "TRT")
    erg = verarbeite_datei(q, tmp_path / "aus")
    assert erg.leerseiten == [2]
    assert seitenzahlen(erg) == [1, 1]


def test_leerseite_am_anfang_und_ende(tmp_path):
    q = baue_pdf(tmp_path / "scan.pdf", "LTTL")
    erg = verarbeite_datei(q, tmp_path / "aus")
    assert seitenzahlen(erg) == [2]
    assert erg.ausgabedateien[0].name == "scan.pdf"  # nur ein Dokument: kein Suffix


def test_nur_loeschen_ohne_trennen(tmp_path):
    q = baue_pdf(tmp_path / "scan.pdf", "TLTLT")
    erg = verarbeite_datei(q, tmp_path / "aus", Einstellungen(trennen=False))
    assert seitenzahlen(erg) == [3]


def test_nur_trennen_leerseiten_behalten():
    g = gruppen_bilden([False, True, False], Einstellungen(leerseiten_loeschen=False))
    assert g == [[0], [1], [2]]


def test_nur_leerseiten_gibt_keine_ausgabe(tmp_path):
    q = baue_pdf(tmp_path / "scan.pdf", "LLL")
    erg = verarbeite_datei(q, tmp_path / "aus")
    assert erg.ausgabedateien == [] and erg.fehler is None


def test_defekte_datei_meldet_fehler(tmp_path):
    q = tmp_path / "kaputt.pdf"
    q.write_bytes(b"das ist kein pdf")
    erg = verarbeite_datei(q, tmp_path / "aus")
    assert erg.fehler


def test_bild_wird_verarbeitet(tmp_path):
    from PIL import Image
    weiss = tmp_path / "leer.png"
    Image.new("RGB", (600, 800), "white").save(weiss)
    erg = verarbeite_datei(weiss, tmp_path / "aus")
    assert erg.leerseiten == [1] and erg.ausgabedateien == []


def test_namenskollision_ueberschreibt_nicht(tmp_path):
    q = baue_pdf(tmp_path / "scan.pdf", "TT")
    verarbeite_datei(q, tmp_path / "aus")
    erg2 = verarbeite_datei(q, tmp_path / "aus")
    assert erg2.ausgabedateien[0].name == "scan_2.pdf"


def test_cli_ordner_einmal(tmp_path):
    baue_pdf(tmp_path / "a.pdf", "TLT")
    assert scan_trenner_cli.main([str(tmp_path)]) == 0
    assert len(list((tmp_path / "fertig").glob("*.pdf"))) == 2
    assert (tmp_path / "erledigt" / "a.pdf").exists()
    assert not (tmp_path / "a.pdf").exists()
