"""Wandelt die gerenderten PNGs in kleine WebP-Dateien für die App um.

    python to_webp.py <png-ordner> ../../assets/sprites
"""

import os
import sys

from PIL import Image

quelle, ziel = sys.argv[1], sys.argv[2]
os.makedirs(ziel, exist_ok=True)
for datei in sorted(os.listdir(quelle)):
    if not datei.endswith('.png'):
        continue
    bild = Image.open(os.path.join(quelle, datei))
    bild.save(os.path.join(ziel, datei[:-4] + '.webp'), 'WEBP', quality=88, method=6)
    print(datei)
