// v116: Hundeführer – „Mein Gebiet“ und Navigation. Reine Logik ohne DOM (testbar).

import { allGrids, gridLabel, assigneeName } from './store.js';
import { makeGrid, cellBounds, gridBounds, parseCell } from './grid.js';
import { poiName, poiCat } from './pois.js';
import { mergeStatus, applyKor, withoutDeleted, EL_KINDS, msgLabel, isUrgent } from './status.js';
import { bearing } from './rescue.js';

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

// v130.37: Grenzen eines Gebiets nach Himmelsrichtung – wie weit ist die Nord-/Süd-/…-Grenze vom Standort entfernt?
const DIR16 = ['N', 'NNO', 'NO', 'ONO', 'O', 'OSO', 'SO', 'SSO', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
const dirIdx = (deg) => Math.round((((deg % 360) + 360) % 360) / 22.5) % 16;

// Kanten eines geschlossenen Vielecks [[lat,lon], …] zu Himmelsrichtungen gruppiert (nach außen zeigende Richtung der
// Kantenmitte von der Gebietsmitte aus) -> [{ label, segs: [[a, b], …] }]; Nachbarkanten mit gleicher Richtung
// zusammengefasst (bei einem Rechteck also genau 4 Grenzen: N, O, S, W)
export function borderSegments(ring) {
  const p = (ring || []).filter((q) => q && Number.isFinite(q[0]) && Number.isFinite(q[1]));
  if (p.length >= 2 && p[0][0] === p[p.length - 1][0] && p[0][1] === p[p.length - 1][1]) p.pop();
  if (p.length < 3) return [];
  const cy = p.reduce((s, q) => s + q[0], 0) / p.length;
  const cx = p.reduce((s, q) => s + q[1], 0) / p.length;
  const edges = p.map((a, i) => {
    const b = p[(i + 1) % p.length];
    const mid = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
    return { a, b, dir: dirIdx(bearing(cy, cx, mid[0], mid[1])) };
  });
  const groups = [];
  for (const e of edges) {
    const last = groups[groups.length - 1];
    if (last && last.dir === e.dir) last.segs.push([e.a, e.b]);
    else groups.push({ dir: e.dir, segs: [[e.a, e.b]] });
  }
  if (groups.length > 1 && groups[0].dir === groups[groups.length - 1].dir) groups[0].segs = [...groups.pop().segs, ...groups[0].segs];
  return groups.map((g) => ({ label: DIR16[g.dir], segs: g.segs }));
}

// Entfernung (m) von (lat, lon) zum nächsten Punkt eines Liniensegments [a, b] – lokale Meter-Projektion, für
// Gebietsgrößen im Einsatz genau genug
function distToSegment(lat, lon, a, b) {
  const mLat = 111320;
  const mLon = 111320 * Math.cos((lat * Math.PI) / 180);
  const ax = (a[1] - lon) * mLon;
  const ay = (a[0] - lat) * mLat;
  const bx = (b[1] - lon) * mLon;
  const by = (b[0] - lat) * mLat;
  const dx = bx - ax;
  const dy = by - ay;
  const len2 = dx * dx + dy * dy;
  const t = len2 ? Math.max(0, Math.min(1, (-ax * dx - ay * dy) / len2)) : 0;
  return Math.hypot(ax + t * dx, ay + t * dy);
}

// Grenzen eines Rings mit Entfernung (m) vom Standort -> [{ label, segs, dist }]; dist = null ohne Standort
// (segs bleibt dabei, damit sich daraus per triangulate() die eigene Position bestimmen lässt)
export function borderDistances(ring, lat, lon) {
  const has = Number.isFinite(lat) && Number.isFinite(lon);
  return borderSegments(ring).map((g) => ({ label: g.label, segs: g.segs, dist: has ? Math.min(...g.segs.map(([a, b]) => distToSegment(lat, lon, a, b))) : null }));
}

// v130.38: eigene Position aus der gemessenen Entfernung zu zwei nicht parallelen Grenzen triangulieren – nützlich
// bei schwachem/fehlendem GPS. borders = Ergebnis von borderDistances()/areaBorderList() (mit .segs); label1/label2
// = deren Bezeichner (z. B. 'N', 'O'); dist1/dist2 = gemessene Entfernung (m) zur jeweiligen Grenze; lat0/lon0 =
// grober eigener Standort (GPS), löst die Mehrdeutigkeit auf (von bis zu 4 möglichen Schnittpunkten wird der dem
// Standort nächste gewählt) -> { lat, lon } oder null (Grenze unbekannt, parallel, oder kein grober Standort)
export function triangulate(borders, label1, dist1, label2, dist2, lat0, lon0) {
  const b1 = (borders || []).find((b) => b.label === label1);
  const b2 = (borders || []).find((b) => b.label === label2);
  if (!b1 || !b2 || !Number.isFinite(dist1) || !Number.isFinite(dist2) || !Number.isFinite(lat0) || !Number.isFinite(lon0)) return null;
  const mLat = 111320;
  const mLon = 111320 * Math.cos((lat0 * Math.PI) / 180);
  const toXY = ([la, lo]) => [(lo - lon0) * mLon, (la - lat0) * mLat];
  const lineOf = (b) => {
    const a = toXY(b.segs[0][0]);
    const e = toXY(b.segs[b.segs.length - 1][1]);
    return { p: a, d: [e[0] - a[0], e[1] - a[1]] };
  };
  const l1 = lineOf(b1);
  const l2 = lineOf(b2);
  if (Math.hypot(...l1.d) < 1e-6 || Math.hypot(...l2.d) < 1e-6) return null;
  // zwei zur Linie parallele Linien im Abstand dist (eine je Seite) – die eigene Position liegt auf einer davon
  const offsetLines = (p, d, dist) => {
    const len = Math.hypot(d[0], d[1]);
    const n = [-d[1] / len, d[0] / len];
    return [{ p: [p[0] + n[0] * dist, p[1] + n[1] * dist], d }, { p: [p[0] - n[0] * dist, p[1] - n[1] * dist], d }];
  };
  const intersect = (a, b) => {
    const denom = a.d[0] * b.d[1] - a.d[1] * b.d[0];
    if (Math.abs(denom) < 1e-9) return null;
    const t = ((b.p[0] - a.p[0]) * b.d[1] - (b.p[1] - a.p[1]) * b.d[0]) / denom;
    return [a.p[0] + t * a.d[0], a.p[1] + t * a.d[1]];
  };
  let best = null;
  let bestD = Infinity;
  for (const o1 of offsetLines(l1.p, l1.d, dist1)) {
    for (const o2 of offsetLines(l2.p, l2.d, dist2)) {
      const pt = intersect(o1, o2);
      if (!pt) continue;
      const d = Math.hypot(pt[0], pt[1]); // Entfernung vom groben Standort (Ursprung) – wählt die richtige Seite
      if (d < bestD) { bestD = d; best = pt; }
    }
  }
  return best ? { lat: lat0 + best[1] / mLat, lon: lon0 + best[0] / mLon } : null;
}

// Alle Gebiete des Auftrags (Rasterfelder des Teams bzw. ganzes Raster, geschlossene Umrisse der EL) mit ihren
// Grenzen -> [{ name, borders: [{ label, dist }] }]
export function areaBorderList(p, lat, lon) {
  const out = [];
  for (const g of allGrids(p)) {
    const keys = Object.keys(g.fills || {}).filter((k) => g.fills[k] === 'team');
    let ring;
    if (keys.length) {
      const gr = makeGrid(g.area, g.cellM);
      const bs = keys.map((k) => { const [c, r] = k.split(',').map(Number); return cellBounds(gr, c, r); });
      const north = Math.max(...bs.map((b) => b.north));
      const south = Math.min(...bs.map((b) => b.south));
      const west = Math.min(...bs.map((b) => b.west));
      const east = Math.max(...bs.map((b) => b.east));
      ring = [[north, west], [north, east], [south, east], [south, west]];
    } else {
      ring = [[g.area.north, g.area.west], [g.area.north, g.area.east], [g.area.south, g.area.east], [g.area.south, g.area.west]];
    }
    out.push({ name: gridLabel(p, g), borders: borderDistances(ring, lat, lon) });
  }
  for (const it of p.items || []) {
    if (it.fromEl && !it.prev && it.kind === 'track' && !it.open && (it.pts || []).length > 2) {
      out.push({ name: it.name || 'Umriss', borders: borderDistances(it.pts, lat, lon) });
    }
  }
  return out;
}
