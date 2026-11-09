"""Unterschriften und handschriftliche Vorlagen: Striche → PNG (transparent).

Die PNGs landen im Ordner „Vorlagen“ (neben dem Ausgabeordner) und können per
WLAN an die DokuBox-App geschickt werden. Dort lassen sie sich beim Ausfüllen
eines Dokuments einsetzen, verschieben und in der Größe ändern.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image, ImageDraw

FARBEN = {"Schwarz": "#000000", "Blau": "#0D47A1"}


@dataclass
class Strich:
    punkte: list[tuple[float, float]] = field(default_factory=list)
    dicke: float = 3.0
    farbe: str = "#000000"


def _glaetten(punkte: list[tuple[float, float]], runden: int = 2) -> list[tuple[float, float]]:
    """Chaikin-Glättung: macht Mauslinien weicher, Endpunkte bleiben."""
    for _ in range(runden):
        if len(punkte) < 3:
            return punkte
        neu = [punkte[0]]
        for (x0, y0), (x1, y1) in zip(punkte, punkte[1:]):
            neu.append((0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1))
            neu.append((0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1))
        neu.append(punkte[-1])
        punkte = neu
    return punkte


def _farbe_rgba(hexfarbe: str) -> tuple[int, int, int, int]:
    h = hexfarbe.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255


def striche_zu_bild(striche: list[Strich], skala: int = 3, rand: int = 6) -> Image.Image | None:
    """Zeichnet die Striche in hoher Auflösung (×[skala]) auf transparenten
    Grund und schneidet auf den beschriebenen Bereich zu. None, wenn leer."""
    alle = [p for s in striche for p in s.punkte]
    if not alle:
        return None
    dick = max(s.dicke for s in striche)
    x0 = min(p[0] for p in alle) - rand - dick
    y0 = min(p[1] for p in alle) - rand - dick
    x1 = max(p[0] for p in alle) + rand + dick
    y1 = max(p[1] for p in alle) + rand + dick
    breite = max(1, int((x1 - x0) * skala))
    hoehe = max(1, int((y1 - y0) * skala))
    bild = Image.new("RGBA", (breite, hoehe), (0, 0, 0, 0))
    zeichnen = ImageDraw.Draw(bild)
    for s in striche:
        if not s.punkte:
            continue
        farbe = _farbe_rgba(s.farbe)
        w = max(1, round(s.dicke * skala))
        pts = [((x - x0) * skala, (y - y0) * skala) for x, y in _glaetten(s.punkte)]
        if len(pts) > 1:
            zeichnen.line(pts, fill=farbe, width=w, joint="curve")
        r = w / 2
        for x, y in (pts[0], pts[-1]) if len(pts) > 1 else pts:  # runde Enden / Punkt
            zeichnen.ellipse((x - r, y - r, x + r, y + r), fill=farbe)
    return bild


def vorlagen_ordner(ausgabe: Path) -> Path:
    """Ordner „Vorlagen“ neben dem Ausgabeordner (z. B. ~/Scans/Vorlagen)."""
    return Path(ausgabe).parent / "Vorlagen"


def sicherer_name(name: str) -> str:
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "", name).strip().strip(".")
    return name[:60] or "Unterschrift"


def speichere_vorlage(striche: list[Strich], ordner: Path, name: str) -> Path | None:
    """Speichert die Striche als PNG; gleichnamige werden nicht überschrieben."""
    bild = striche_zu_bild(striche)
    if bild is None:
        return None
    ordner.mkdir(parents=True, exist_ok=True)
    basis = sicherer_name(name)
    ziel = ordner / f"{basis}.png"
    n = 2
    while ziel.exists():
        ziel = ordner / f"{basis}_{n}.png"
        n += 1
    bild.save(ziel, "PNG", optimize=True)
    return ziel
