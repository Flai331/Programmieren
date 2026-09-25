"""Schneidet gemalte Gebäude und Figuren aus einer Vorlage aus.

    python cutout.py <vorlage.jpg> <ausgabeordner>

Die Vorlage hat einfarbige, leicht verlaufende Hintergründe. Der Hintergrund
wird von den Rändern jedes Ausschnitts aus entfernt (Flutfüllung, die dem
Farbverlauf folgt und an den dunklen Umrisslinien stoppt). Gebäude kommen im
selben Format wie die gerenderten Bilder heraus (320×480, Feldmitte bei
160/384) und bekommen einen weichen Schatten; Figuren werden 128 px hoch.
"""

import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

# Ausschnitte in der Vorlage: (links, oben, rechts, unten), Rechtecke mit
# Beschriftung, die vorher mit Hintergrund übermalt werden, und die Breite im
# Bild (ein Feld ist 256 px breit).
GEBAEUDE = {
    'wassermuehle': ((12, 12, 418, 384), [(12, 12, 212, 46)], 236),
    'baustelle_muehle': ((421, 54, 684, 311), [], 205),
    'baeckerei': ((708, 12, 1108, 384), [(708, 12, 850, 46)], 205),
    'baustelle_baeckerei': ((1113, 54, 1387, 311), [], 205),
}
FIGUREN = {
    'person_a_vorn': (40, 405, 248, 728),
    'person_a_hinten': (250, 405, 440, 728),
    'person_a_seite': (445, 405, 668, 728),
    'person_b_vorn': (760, 405, 990, 728),
    'person_b_hinten': (1150, 405, 1380, 728),
}

TOLERANZ = 14  # Summe der Farbabweichung zum Nachbarpixel


def hintergrund_maske(px: np.ndarray) -> np.ndarray:
    """True = Hintergrund (inklusive gemalter Schatten)."""
    h, w, _ = px.shape
    arr = px.astype(np.int16)
    bg = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        q.append((0, x))
        q.append((h - 1, x))
    for y in range(h):
        q.append((y, 0))
        q.append((y, w - 1))
    for (y, x) in q:
        bg[y, x] = True
    while q:
        y, x = q.popleft()
        c = arr[y, x]
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx]:
                if np.abs(arr[ny, nx] - c).sum() < TOLERANZ:
                    bg[ny, nx] = True
                    q.append((ny, nx))
    # Eingeschlossene Hintergrundreste (z. B. durch ein offenes Dachgerüst)
    # erkennt die Flutfüllung nicht; sie haben aber die Farbe des Randes.
    rand = np.concatenate([arr[0], arr[-1], arr[:, 0], arr[:, -1]])
    refs = rand[:: max(1, len(rand) // 60)]
    abstand = np.min(np.abs(arr[:, :, None, :] - refs[None, None, :, :]).sum(-1), axis=2)
    return bg | (abstand < 16)


def freistellen(bild: Image.Image, box, labels) -> Image.Image:
    teil = bild.crop(box).convert('RGB')
    px = np.array(teil)
    for (l, t, r, b) in labels:
        l, t, r, b = l - box[0], t - box[1], r - box[0], b - box[1]
        # Mit der Farbe direkt unter der Beschriftung übermalen.
        px[t:b, l:r] = px[min(b + 2, px.shape[0] - 1), l:r][None, :, :]
    bg = hintergrund_maske(px)
    alpha = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8))
    # Einzelne JPEG-Pixel am Rand wegnehmen und die Kante weich machen.
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    rgba = Image.fromarray(px).convert('RGBA')
    rgba.putalpha(alpha)
    return rgba.crop(rgba.getbbox())


def mit_schatten(sprite: Image.Image) -> Image.Image:
    a = sprite.getchannel('A')
    schatten = Image.new('RGBA', sprite.size, (20, 30, 15, 0))
    schatten.putalpha(a.point(lambda v: int(v * 0.32)))
    rand = 24
    ganz = Image.new('RGBA', (sprite.width + 2 * rand, sprite.height + 2 * rand), (0, 0, 0, 0))
    s = Image.new('RGBA', ganz.size, (0, 0, 0, 0))
    s.alpha_composite(schatten, (rand + 14, rand + 6))
    s = s.filter(ImageFilter.GaussianBlur(7))
    ganz.alpha_composite(s)
    ganz.alpha_composite(sprite, (rand, rand))
    return ganz, rand


def als_feld(sprite: Image.Image, breite=236) -> Image.Image:
    """Skaliert auf Feldbreite und setzt die Unterkante auf die untere
    Feldspitze (160, 448) im 320×480-Format."""
    k = breite / sprite.width
    klein = sprite.resize((round(sprite.width * k), round(sprite.height * k)), Image.LANCZOS)
    groesser, rand = mit_schatten(klein)
    out = Image.new('RGBA', (320, 480), (0, 0, 0, 0))
    x = 160 - klein.width // 2 - rand
    y = 444 - klein.height - rand
    out.alpha_composite(groesser, (x, max(-10_000, y)) if y >= 0 else (x, 0))
    return out


def main():
    vorlage, ziel = sys.argv[1], sys.argv[2]
    os.makedirs(ziel, exist_ok=True)
    bild = Image.open(vorlage)
    for name, (box, labels, breite) in GEBAEUDE.items():
        sprite = freistellen(bild, box, labels)
        als_feld(sprite, breite).save(os.path.join(ziel, name + '.png'))
        print(name, sprite.size)
    for name, box in FIGUREN.items():
        sprite = freistellen(bild, box, [])
        k = 128 / sprite.height
        sprite = sprite.resize((round(sprite.width * k), 128), Image.LANCZOS)
        sprite.save(os.path.join(ziel, name + '.png'))
        print(name, sprite.size)


if __name__ == '__main__':
    main()
