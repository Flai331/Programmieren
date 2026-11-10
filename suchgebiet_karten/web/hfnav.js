// v116: Hundeführer – „Mein Gebiet“ und Navigation. Reine Logik ohne DOM (testbar).

import { allGrids, gridLabel, assigneeName } from './store.js';
import { makeGrid, cellBounds, gridBounds, parseCell } from './grid.js';
import { poiName, poiCat } from './pois.js';
import { mergeStatus, applyKor, withoutDeleted, EL_KINDS, msgLabel, isUrgent } from './status.js';

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
// v123: mode 'driving' (Auto) oder 'walking' (zu Fuß); alles andere wird zu 'driving'
export const navUrl = (lat, lon, mode = 'driving') => `https://www.google.com/maps/dir/?api=1&destination=${Number(lat).toFixed(6)},${Number(lon).toFixed(6)}&travelmode=${mode === 'walking' ? 'walking' : 'driving'}`;

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

// v123: Mitte des umschließenden Rechtecks einer Punktliste [[lat, lon], …] -> [lat, lon] oder null
export function boxCenter(pts) {
  const v = (pts || []).filter((q) => q && Number.isFinite(q[0]) && Number.isFinite(q[1]));
  if (!v.length) return null;
  const la = v.map((q) => q[0]);
  const lo = v.map((q) => q[1]);
  return [(Math.min(...la) + Math.max(...la)) / 2, (Math.min(...lo) + Math.max(...lo)) / 2];
}

// v130.2: Kompass-Navigation (Luftlinie) – zusätzlich zur Google-Maps-Route, auch ohne Internet/Straße nutzbar.
// Drehwinkel für die Pfeil-Anzeige: targetBearing (° zum Ziel, von Norden) minus die Blickrichtung des Handys
// (device Kompass-Heading, ° von Norden). Ohne Kompass (heading = null) zeigt der Pfeil die Gradzahl von Norden
// (Handy liegt dann gedanklich mit der Oberkante nach Norden) – damit bleibt die Anzeige auch ohne Sensor nützlich.
export function navNeedleDeg(targetBearing, heading) {
  const h = Number.isFinite(heading) ? heading : 0;
  return ((targetBearing - h) % 360 + 360) % 360;
}
// Entfernung „342 m“ / „1,4 km“
export function fmtDist(m) {
  if (!Number.isFinite(m)) return '';
  return m >= 1000 ? `${(m / 1000).toLocaleString('de-DE', { maximumFractionDigits: 1 })} km` : `${Math.round(m)} m`;
}

// v123: Mitte eines Rasterfelds wie „C4“ (grid = makeGrid(...)) -> [lat, lon] oder null (kein Feldname / außerhalb)
export function cellCenter(grid, label) {
  const q = parseCell(label);
  if (!grid || !q || q.c >= grid.cols || q.r >= grid.rows) return null;
  const b = cellBounds(grid, q.c, q.r);
  return [(b.north + b.south) / 2, (b.west + b.east) / 2];
}

const hm = (t) => (t ? new Date(t).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' }) : '');

// v123: Alle Ziele für die Einsatzleitung -> [{ key, icon, label, sub, lat, lon }]
// B-Ort, Lage-Orte, geschlossene Umrisse, Raster (Mitte), Meldungen mit Ort (Fund, Hilfe, Standort)
export function navTargetsAll(p) {
  const out = [];
  const add = (key, icon, label, sub, lat, lon) => {
    if (Number.isFinite(lat) && Number.isFinite(lon)) out.push({ key, icon, label, sub: sub || '', lat, lon });
  };
  if (p.meet) add('meet', '🎯', p.meet.text && p.meet.text !== 'B-Ort' ? `B-Ort (${p.meet.text})` : 'B-Ort / Treffpunkt', '', p.meet.lat, p.meet.lon);
  for (const q of p.pois || []) add(`poi-${q.id}`, poiCat(q.cat).icon, poiName(q), poiCat(q.cat).label, q.lat, q.lon);
  for (const [i, it] of (p.items || []).entries()) {
    if (it.kind !== 'track' || it.open || (it.pts || []).length < 3) continue;
    const c = boxCenter(it.pts);
    if (c) add(`outline-${it.id || i}`, '📐', it.name || 'Umriss', it.to ? assigneeName(p, it.to) : 'ohne Team', c[0], c[1]);
  }
  for (const g of allGrids(p)) {
    const b = gridBounds(makeGrid(g.area, g.cellM));
    add(`grid-${g.id || gridLabel(p, g)}`, '#', gridLabel(p, g), 'Raster (Mitte)', (b.north + b.south) / 2, (b.west + b.east) / 2);
  }
  const msgs = withoutDeleted(applyKor(mergeStatus((p.live && p.live.msgs) || [], p.qmsgs || []).filter((m) => !EL_KINDS.includes(m.s))), p.msgDel);
  for (const m of msgs) {
    if (m.gone || m.lat == null || !(isUrgent(m) || m.s === 'ort')) continue;
    add(`msg-${m.id}`, '📣', `${m.tm || 'Team'}: ${msgLabel(m)}`, hm(m.t), m.lat, m.lon);
  }
  return out;
}
