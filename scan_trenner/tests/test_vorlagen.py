import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import vorlagen as vl


def unterschrift():
    return [
        vl.Strich([(10, 50), (30, 20), (50, 60), (70, 25), (90, 55)], dicke=3, farbe="#0D47A1"),
        vl.Strich([(100, 40)], dicke=4),  # i-Punkt
    ]


def test_bild_transparent_zugeschnitten_hochaufgeloest():
    bild = vl.striche_zu_bild(unterschrift(), skala=3, rand=6)
    assert bild.mode == "RGBA"
    # Zugeschnitten auf den beschriebenen Bereich (ca. 90 × 40 px × 3).
    assert 280 < bild.width < 360 and 120 < bild.height < 200
    # Ecken durchsichtig, in der Mitte der Linie blaue Tinte.
    assert bild.getpixel((0, 0))[3] == 0
    pixel = [bild.getpixel((x, y)) for x in range(bild.width) for y in range(bild.height)]
    farben = [p for p in pixel if p[3] == 255]
    assert farben, "keine Tinte gezeichnet"
    assert all(p[:3] in ((13, 71, 161), (0, 0, 0)) for p in farben)


def test_leer_ergibt_kein_bild(tmp_path):
    assert vl.striche_zu_bild([]) is None
    assert vl.speichere_vorlage([vl.Strich([])], tmp_path, "x") is None


def test_speichern_ohne_ueberschreiben(tmp_path):
    a = vl.speichere_vorlage(unterschrift(), tmp_path / "Vorlagen", 'Max: "Unterschrift"')
    b = vl.speichere_vorlage(unterschrift(), tmp_path / "Vorlagen", 'Max: "Unterschrift"')
    assert a.name == "Max Unterschrift.png" and b.name == "Max Unterschrift_2.png"
    with Image.open(a) as bild:
        assert bild.format == "PNG" and bild.mode == "RGBA"
    # Gleiches PNG-Format, das die App erwartet (Signatur + IHDR).
    assert a.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"


def test_vorlagen_ordner_neben_ausgabe():
    assert vl.vorlagen_ordner(Path("/home/x/Scans/Fertig")) == Path("/home/x/Scans/Vorlagen")


def test_glaetten_behaelt_endpunkte():
    pts = [(0, 0), (10, 0), (10, 10)]
    glatt = vl._glaetten(pts)
    assert glatt[0] == (0, 0) and glatt[-1] == (10, 10) and len(glatt) > len(pts)
