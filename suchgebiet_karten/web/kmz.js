// Garmin „Custom Map“ (KMZ): Kartenbild mit Raster, Teams und Tracks als JPEG-Kacheln.
// Auf das Gerät in den Ordner Garmin/CustomMaps kopieren; es liegt dann über der
// installierten Karte. Garmin-Grenzen: Kacheln max. 1024×1024 px, je nach Gerät
// 100 (ältere) bis 500 Kacheln insgesamt.

import { mercLat, mercLon, mercX, mercY, metersPerUnit } from './grid.js';
import { renderSheet, renderState } from './pdf.js';
import { makeZip } from './zip.js';

export const TILE = 1024;
export const MAX_TILES = 100;
const MAX_PX = 6144;
const MAX_AREA = 25e6; // Canvas-Pixel insgesamt (Speichergrenze auf Handys)

function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Bildgröße für das Gebiet bei mPerPx Metern pro Pixel, begrenzt auf MAX_TILES Kacheln
export function planCustomMap(bounds, mPerPx) {
  const x0 = mercX(bounds.west);
  const x1 = mercX(bounds.east);
  const y0 = mercY(bounds.north);
  const y1 = mercY(bounds.south);
  const midLat = (bounds.north + bounds.south) / 2;
  let res = mPerPx;
  for (;;) {
    const W = Math.ceil(((x1 - x0) * metersPerUnit(midLat)) / res);
    const H = Math.ceil(((y1 - y0) * metersPerUnit(midLat)) / res);
    const tiles = Math.ceil(W / TILE) * Math.ceil(H / TILE);
    if ((tiles <= MAX_TILES && W <= MAX_PX && H <= MAX_PX && W * H <= MAX_AREA) || res > 1000) {
      return { W: Math.max(1, W), H: Math.max(1, H), tiles, mPerPx: res };
    }
    res *= 1.25;
  }
}

function canvasJpeg(canvas, quality) {
  return new Promise((resolve) => canvas.toBlob((b) => resolve(b), 'image/jpeg', quality));
}

export async function buildCustomMap(project, grid, layer, bounds, mPerPx, onProgress) {
  const plan = planCustomMap(bounds, mPerPx);
  const sheet = { bounds, pad: 0 };
  // Linienstärke wie auf dem Bildschirm (ca. 1 px = 1 Einheit bei 0,3 mm/px)
  const r = await renderSheet(renderState(project, grid), sheet, layer, plan.W, plan.H, plan.W * 0.3,
    { bare: true, utm: project.showUtm, maxTiles: 600 });
  const { canvas, box } = r;
  const files = [];
  const overlays = [];
  const nx = Math.ceil(plan.W / TILE);
  const ny = Math.ceil(plan.H / TILE);
  const toMercX = (px) => box.x0 + ((box.x1 - box.x0) * px) / plan.W;
  const toMercY = (py) => box.y0 + ((box.y1 - box.y0) * py) / plan.H;
  let n = 0;
  for (let ty = 0; ty < ny; ty++) {
    for (let tx = 0; tx < nx; tx++) {
      onProgress && onProgress(++n, nx * ny);
      const px0 = tx * TILE;
      const py0 = ty * TILE;
      const w = Math.min(TILE, plan.W - px0);
      const h = Math.min(TILE, plan.H - py0);
      const c = document.createElement('canvas');
      c.width = w;
      c.height = h;
      c.getContext('2d').drawImage(canvas, px0, py0, w, h, 0, 0, w, h);
      const blob = await canvasJpeg(c, 0.82);
      const name = `files/k_${ty}_${tx}.jpg`;
      files.push({ name, data: new Uint8Array(await blob.arrayBuffer()) });
      overlays.push(`  <GroundOverlay>
   <name>Kachel ${ty + 1}-${tx + 1}</name>
   <drawOrder>50</drawOrder>
   <Icon><href>${name}</href></Icon>
   <LatLonBox>
    <north>${mercLat(toMercY(py0)).toFixed(7)}</north>
    <south>${mercLat(toMercY(py0 + h)).toFixed(7)}</south>
    <east>${mercLon(toMercX(px0 + w)).toFixed(7)}</east>
    <west>${mercLon(toMercX(px0)).toFixed(7)}</west>
   </LatLonBox>
  </GroundOverlay>`);
    }
  }
  const title = project.title || 'Suchgebiet';
  const kml = `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
 <Folder>
  <name>${esc(title)}</name>
${overlays.join('\n')}
 </Folder>
</kml>
`;
  const zip = makeZip([{ name: 'doc.kml', data: new TextEncoder().encode(kml) }, ...files]);
  return {
    blob: new Blob([zip], { type: 'application/vnd.google-earth.kmz' }),
    tiles: nx * ny,
    mPerPx: plan.mPerPx,
    missing: r.missing,
  };
}
