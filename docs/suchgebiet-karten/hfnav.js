// v116: Hundeführer – „Mein Gebiet“ und Navigation. Reine Logik ohne DOM (testbar).

import { allGrids } from './store.js';
import { makeGrid, cellBounds } from './grid.js';
import { poiName } from './pois.js';

// Punkte aller Gebiete des Auftrags: Felder des Teams (sonst das ganze Raster) und geschlossene Umrisse der Einsatzleitung
// (ohne die grauen Umrisse des vorherigen Teams)
export function areaPoints(p) {
  const pts = [];
  for (const g of allGrids(p)) {
    const keys = Object.keys(g.fills || {}).filter((k) => g.fills[k] === 'team');
    if (!keys.length) { pts.push([g.area.north, g.area.west], [g.area.south, g.area.east]); continue; }
    const gr = makeGrid(g.area, g.cellM);
    for (const k of keys) {
      const [c, r] = k.split(',').map(Number);
      const b = cellBounds(gr, c, r);
      pts.push([b.north, b.west], [b.south, b.east]);
    }
  }
  for (const it of p.items || []) {
    if (it.fromEl && !it.prev && it.kind === 'track' && !it.open && (it.pts || []).length > 2) pts.push(...it.pts);
  }
  return pts;
}

// -> [[süd, west], [nord, ost]] oder null
export function areaBounds(p) {
  const pts = areaPoints(p);
  if (!pts.length) return null;
  const la = pts.map((q) => q[0]);
  const lo = pts.map((q) => q[1]);
  return [[Math.min(...la), Math.min(...lo)], [Math.max(...la), Math.max(...lo)]];
}

// Google-Maps-Routenlink zu einem Ziel
export const navUrl = (lat, lon) => `https://www.google.com/maps/dir/?api=1&destination=${Number(lat).toFixed(6)},${Number(lon).toFixed(6)}`;

// Ziele im Auftrag: Parkplätze (Lage-Orte), B-Ort bzw. Treffpunkt, Gebiet (Mittelpunkt) -> [{ key, icon, label, lat, lon, url }]
export function navTargets(p) {
  const out = [];
  const add = (key, icon, label, lat, lon) => {
    if (Number.isFinite(lat) && Number.isFinite(lon)) out.push({ key, icon, label, lat, lon, url: navUrl(lat, lon) });
  };
  for (const q of (p.pois || []).filter((x) => x.cat === 'park')) add(`poi-${q.id}`, '🅿️', poiName(q), q.lat, q.lon);
  if (p.meet) add('meet', '🎯', p.meet.text && p.meet.text !== 'B-Ort' ? `B-Ort (${p.meet.text})` : 'B-Ort / Treffpunkt', p.meet.lat, p.meet.lon);
  const b = areaBounds(p);
  if (b) add('area', '🗺️', 'Gebiet (Mitte)', (b[0][0] + b[1][0]) / 2, (b[0][1] + b[1][1]) / 2);
  return out;
}
