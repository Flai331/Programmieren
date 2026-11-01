// v121: Wald erkennen und aufteilen – reine Logik (ohne DOM und Leaflet).
// Ablauf: Overpass-Abfrage (forestQuery) -> parseForest -> forestInLasso (Schnitt mit der Umkreisung)
// -> shares (Anteile aus dem Fenster) -> splitArea (Aufteilen, Wege bevorzugt) -> toTracks (Umrisse).
// Gerechnet wird in einer lokalen Ebene in Metern (äquirektangulär um die Mitte, wie polygonArea in gpx.js).
// Polygonoperationen: polygon-clipping (MIT, lib/polygon-clipping.esm.js).

import pc from './lib/polygon-clipping.esm.js';
import { simplify } from './share.js';

const KY = 6371008.8 * Math.PI / 180; // Meter je Breitengrad
const MIN_PART_M2 = 2000; // Kleinstteile des Waldes entfallen
const MIN_PART_FRAC = 0.005;
const SLIVER_M2 = 500; // Splitter eines Teils (z. B. Zipfel hinter einem Weg) entfallen, wenn der Teil größere Stücke hat
const WAY_TOL = 0.15; // Weg-Schnitt nur, wenn die Fläche höchstens 15 % vom Soll abweicht
const WAY_EXTEND_M = 60; // Wegenden bis zu 60 m vor dem Rand werden bis zum Rand verlängert
const WAY_HALF_M = 0.25; // Schnittbreite entlang eines Wegs: 0,5 m
const WAY_MIN_COS = Math.SQRT1_2; // Winkel zur Schnittrichtung unter 45°

export const OSM_NOTE = 'Wald und Wege: © OpenStreetMap-Mitwirkende';
export const MAX_PARTS = 8;
export const MAX_AREA_M2 = 25e6; // 25 km²
export const MIN_OUTLINE_M = 30;
const HIGHWAYS = 'track|path|footway|bridleway|cycleway|service|unclassified|residential|tertiary|secondary';

// ---------- Overpass ----------
// bbox: { south, west, north, east }
export function forestQuery(bbox) {
  const b = [bbox.south, bbox.west, bbox.north, bbox.east].map((v) => Number(v).toFixed(6)).join(',');
  return `[out:json][timeout:25];(`
    + `way["landuse"="forest"](${b});relation["landuse"="forest"](${b});`
    + `way["natural"="wood"](${b});relation["natural"="wood"](${b});`
    + `way["highway"~"^(${HIGHWAYS})$"](${b});`
    + `way["waterway"~"^(stream|river|ditch|canal)$"](${b});`
    + `);out geom;`;
}

const sameKey = (p) => `${p[0]},${p[1]}`;

// Offene Wege zu geschlossenen Ringen zusammensetzen (Enden verbinden, auch umgedreht); offene Reste entfallen
function stitch(segs) {
  const rest = segs.filter((s) => s.length >= 2).map((s) => s.slice());
  const rings = [];
  while (rest.length) {
    let cur = rest.pop();
    let guard = rest.length + 2;
    while (sameKey(cur[0]) !== sameKey(cur[cur.length - 1]) && guard-- > 0) {
      const end = sameKey(cur[cur.length - 1]);
      const k = rest.findIndex((s) => sameKey(s[0]) === end || sameKey(s[s.length - 1]) === end);
      if (k < 0) break;
      const [s] = rest.splice(k, 1);
      cur = cur.concat(sameKey(s[0]) === end ? s.slice(1) : s.slice(0, -1).reverse());
    }
    if (cur.length >= 4 && sameKey(cur[0]) === sameKey(cur[cur.length - 1])) rings.push(cur);
  }
  return rings;
}

// Overpass-Antwort -> { forests: [Ring [lat,lon] (geschlossen)…], lines: [[[lat,lon]…]…] }
export function parseForest(json) {
  const forests = [];
  const lines = [];
  const pts = (g) => (Array.isArray(g) ? g.filter((q) => q && Number.isFinite(q.lat) && Number.isFinite(q.lon)).map((q) => [q.lat, q.lon]) : []);
  for (const el of (json && json.elements) || []) {
    const tags = el.tags || {};
    const isForest = tags.landuse === 'forest' || tags.natural === 'wood';
    if (el.type === 'way') {
      const p = pts(el.geometry);
      if (isForest) {
        if (p.length >= 4 && sameKey(p[0]) === sameKey(p[p.length - 1])) forests.push(p);
      } else if ((tags.highway || tags.waterway) && p.length >= 2) lines.push(p);
    } else if (el.type === 'relation' && isForest) {
      const outer = (el.members || []).filter((m) => m.type === 'way' && (m.role === 'outer' || m.role === '')).map((m) => pts(m.geometry));
      forests.push(...stitch(outer));
    }
  }
  return { forests, lines };
}

// ---------- Ebene in Metern ----------
export function makeOrigin(lat, lon) {
  return { lat, lon, kx: KY * Math.cos(lat * Math.PI / 180) };
}
// Mitte des umschließenden Rechtecks von [lat, lon]-Punkten
export function originOf(pts) {
  const la = pts.map((p) => p[0]);
  const lo = pts.map((p) => p[1]);
  return makeOrigin((Math.max(...la) + Math.min(...la)) / 2, (Math.max(...lo) + Math.min(...lo)) / 2);
}
export const toXY = (p, o) => [(p[1] - o.lon) * o.kx, (p[0] - o.lat) * KY];
export const toLL = (q, o) => [o.lat + q[1] / KY, o.lon + q[0] / o.kx];

const closeRing = (r) => {
  const a = r[0];
  const b = r[r.length - 1];
  return a[0] === b[0] && a[1] === b[1] ? r : [...r, a];
};
function ringArea(r) {
  let a = 0;
  for (let i = 0; i < r.length - 1; i++) a += r[i][0] * r[i + 1][1] - r[i + 1][0] * r[i][1];
  return a / 2;
}
// Fläche eines Polygons (äußerer Ring minus Löcher) und einer Polygonliste
export const polyArea = (poly) => poly.reduce((s, r, i) => s + (i ? -1 : 1) * Math.abs(ringArea(closeRing(r))), 0);
export const mpArea = (mp) => mp.reduce((s, p) => s + polyArea(p), 0);

// Löcher weg (Lichtungen zählen mit, Umrisse haben keine Löcher), Überlappungen auflösen
function solid(mp) {
  if (!mp.some((p) => p.length > 1)) return mp;
  const polys = mp.map((p) => [p[0]]);
  return polys.length > 1 ? pc.union(...polys) : polys;
}

// Umkreisung ([lat, lon]) -> bereinigtes MultiPolygon (Selbstüberschneidungen aufgelöst, ohne Löcher)
export function lassoPolygon(lasso, o = originOf(lasso)) {
  if (!lasso || lasso.length < 3) return [];
  try {
    return solid(pc.union([closeRing(lasso.map((p) => toXY(p, o)))]));
  } catch {
    return [];
  }
}

// Kleinstteile (< 0,5 % der Gesamtfläche oder < 2000 m²) entfernen
function dropSmall(mp) {
  const total = mpArea(mp);
  return mp.filter((p) => polyArea(p) >= Math.max(MIN_PART_M2, total * MIN_PART_FRAC));
}

// Waldfläche innerhalb der Umkreisung -> MultiPolygon in Metern (Polygone ohne Löcher)
export function forestInLasso(forests, lasso, o = originOf(lasso)) {
  const L = lassoPolygon(lasso, o);
  const rings = (forests || []).map((r) => closeRing(r.map((p) => toXY(p, o)))).filter((r) => r.length >= 4);
  if (!L.length || !rings.length) return [];
  try {
    const f = pc.union(...rings.map((r) => [r]));
    return dropSmall(solid(pc.intersection(f, L)));
  } catch {
    return [];
  }
}

// ---------- Anteile ----------
// parts: [{ size: 'gleich' | 'kleiner' | 'größer', pct }] -> { shares: [Summe 1] } oder { error: 'Text' }
export function shares(parts) {
  if (!Array.isArray(parts) || !parts.length) return { error: 'Mindestens ein Teil nötig' };
  const w = [];
  for (let i = 0; i < parts.length; i++) {
    const { size, pct } = parts[i];
    const name = `Teil ${'ABCDEFGH'[i] || i + 1}`;
    if (size === 'kleiner' || size === 'größer') {
      const lo = size === 'kleiner' ? 1 : 101;
      const hi = size === 'kleiner' ? 99 : 400;
      const v = Number(pct);
      if (pct === '' || pct == null || !Number.isFinite(v)) return { error: `${name}: Prozentwert fehlt („% eines normalen Teils“)` };
      if (v < lo || v > hi) return { error: `${name}: Prozentwert ${lo} bis ${hi} eingeben` };
      w.push(v / 100);
    } else w.push(1);
  }
  const sum = w.reduce((a, b) => a + b, 0);
  return { shares: w.map((x) => x / sum) };
}

// ---------- Hilfen für Geometrie ----------
function convexHull(pts) {
  const p = pts.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  if (p.length < 3) return p;
  const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lo = [];
  for (const q of p) { while (lo.length >= 2 && cross(lo[lo.length - 2], lo[lo.length - 1], q) <= 0) lo.pop(); lo.push(q); }
  const up = [];
  for (const q of p.slice().reverse()) { while (up.length >= 2 && cross(up[up.length - 2], up[up.length - 1], q) <= 0) up.pop(); up.push(q); }
  return lo.slice(0, -1).concat(up.slice(0, -1));
}

// Hauptachse: Richtung der längeren Seite des kleinsten Hüllrechtecks -> Einheitsvektor
export function mainAxis(mp) {
  const hull = convexHull(mp.flatMap((p) => p[0]));
  let best = null;
  for (let i = 0; i < hull.length; i++) {
    const a = hull[i];
    const b = hull[(i + 1) % hull.length];
    const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    if (!len) continue;
    const ux = (b[0] - a[0]) / len;
    const uy = (b[1] - a[1]) / len;
    let s0 = Infinity; let s1 = -Infinity; let t0 = Infinity; let t1 = -Infinity;
    for (const q of hull) {
      const s = q[0] * ux + q[1] * uy;
      const t = -q[0] * uy + q[1] * ux;
      if (s < s0) s0 = s;
      if (s > s1) s1 = s;
      if (t < t0) t0 = t;
      if (t > t1) t1 = t;
    }
    const area = (s1 - s0) * (t1 - t0);
    if (!best || area < best.area) best = { area, ux, uy, w: s1 - s0, h: t1 - t0 };
  }
  if (!best) return [1, 0];
  return best.w >= best.h ? [best.ux, best.uy] : [-best.uy, best.ux];
}

// Fläche des Teils mit s = p·u <= c (Sutherland-Hodgman reicht für die Flächenrechnung, auch bei konkaven Ringen)
function clippedRingArea(ring, u, c) {
  const out = [];
  const n = ring.length - 1;
  for (let i = 0; i < n; i++) {
    const a = ring[i];
    const b = ring[i + 1];
    const sa = a[0] * u[0] + a[1] * u[1] - c;
    const sb = b[0] * u[0] + b[1] * u[1] - c;
    if (sa <= 0) out.push(a);
    if ((sa < 0 && sb > 0) || (sa > 0 && sb < 0)) {
      const t = sa / (sa - sb);
      out.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]);
    }
  }
  if (out.length < 3) return 0;
  return Math.abs(ringArea([...out, out[0]]));
}
function areaBelow(mp, u, c) {
  let s = 0;
  for (const poly of mp) poly.forEach((r, i) => { s += (i ? -1 : 1) * clippedRingArea(closeRing(r), u, c); });
  return s;
}
function sRange(mp, u) {
  let lo = Infinity;
  let hi = -Infinity;
  for (const poly of mp) for (const q of poly[0]) { const s = q[0] * u[0] + q[1] * u[1]; if (s < lo) lo = s; if (s > hi) hi = s; }
  return [lo, hi];
}
// Schnittlage c, bei der die Fläche mit s <= c das Soll hat (Bisektion)
function findCut(mp, u, target, tolRel) {
  let [lo, hi] = sRange(mp, u);
  const a0 = lo;
  const a1 = hi;
  if (target <= 0) return a0;
  for (let i = 0; i < 70; i++) {
    const c = (lo + hi) / 2;
    const a = areaBelow(mp, u, c);
    if (Math.abs(a - target) <= tolRel * target || hi - lo < 0.01) return c;
    if (a < target) lo = c; else hi = c;
  }
  return Math.min(a1, Math.max(a0, (lo + hi) / 2));
}
// Halbebene s <= c als großes Rechteck
function halfPlane(mp, u, c) {
  const v = [-u[1], u[0]];
  const pts = mp.flatMap((p) => p[0]);
  let s0 = Infinity; let t0 = Infinity; let t1 = -Infinity;
  for (const q of pts) {
    s0 = Math.min(s0, q[0] * u[0] + q[1] * u[1]);
    const t = q[0] * v[0] + q[1] * v[1];
    t0 = Math.min(t0, t);
    t1 = Math.max(t1, t);
  }
  s0 -= 10; t0 -= 10; t1 += 10;
  const at = (s, t) => [u[0] * s + v[0] * t, u[1] * s + v[1] * t];
  return [[at(s0, t0), at(c, t0), at(c, t1), at(s0, t1), at(s0, t0)]];
}

function centroid(poly) {
  const r = closeRing(poly[0]);
  let a = 0; let cx = 0; let cy = 0;
  for (let i = 0; i < r.length - 1; i++) {
    const f = r[i][0] * r[i + 1][1] - r[i + 1][0] * r[i][1];
    a += f;
    cx += (r[i][0] + r[i + 1][0]) * f;
    cy += (r[i][1] + r[i + 1][1]) * f;
  }
  if (Math.abs(a) < 1e-9) return r[0];
  return [cx / (3 * a), cy / (3 * a)];
}

// ---------- Wege ----------
// Schnittpunkt zweier Strecken a-b und c-d: Parameter t auf a-b (0..1) oder null
function segHit(a, b, c, d) {
  const rx = b[0] - a[0]; const ry = b[1] - a[1];
  const sx = d[0] - c[0]; const sy = d[1] - c[1];
  const den = rx * sy - ry * sx;
  if (Math.abs(den) < 1e-12) return null;
  const t = ((c[0] - a[0]) * sy - (c[1] - a[1]) * sx) / den;
  const w = ((c[0] - a[0]) * ry - (c[1] - a[1]) * rx) / den;
  return t >= 0 && t <= 1 && w >= 0 && w <= 1 ? t : null;
}
function inRing(p, ring) {
  let ins = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const a = ring[i];
    const b = ring[j];
    if ((a[1] > p[1]) !== (b[1] > p[1]) && p[0] < ((b[0] - a[0]) * (p[1] - a[1])) / (b[1] - a[1]) + a[0]) ins = !ins;
  }
  return ins;
}
const inMp = (p, mp) => mp.some((poly) => inRing(p, poly[0]) && !poly.slice(1).some((h) => inRing(p, h)));

// Wege, die an Knoten zusammenstoßen (genau zwei Enden), zu einer Linie verketten
export function chainLines(lines) {
  const key = (p) => `${Math.round(p[0] * 100)},${Math.round(p[1] * 100)}`;
  const ends = new Map();
  lines.forEach((l, i) => {
    if (l.length < 2) return;
    for (const w of [0, 1]) {
      const k = key(l[w ? l.length - 1 : 0]);
      if (!ends.has(k)) ends.set(k, []);
      ends.get(k).push({ i, w });
    }
  });
  const partner = (i, w) => {
    const e = ends.get(key(lines[i][w ? lines[i].length - 1 : 0]));
    if (!e || e.length !== 2) return null;
    const o = e.find((x) => !(x.i === i && x.w === w));
    return o && o.i !== i ? o : null;
  };
  const used = new Set();
  const out = [];
  lines.forEach((l, i) => {
    if (used.has(i) || l.length < 2) return;
    used.add(i);
    let chain = l.slice();
    let cur = { i, w: 1 };
    for (;;) {
      const p = partner(cur.i, cur.w);
      if (!p || used.has(p.i)) break;
      used.add(p.i);
      const seg = lines[p.i];
      chain = chain.concat(p.w === 0 ? seg.slice(1) : seg.slice(0, -1).reverse());
      cur = { i: p.i, w: p.w === 0 ? 1 : 0 };
    }
    cur = { i, w: 0 };
    for (;;) {
      const p = partner(cur.i, cur.w);
      if (!p || used.has(p.i)) break;
      used.add(p.i);
      const seg = lines[p.i];
      chain = (p.w === 1 ? seg.slice(0, -1) : seg.slice(1).reverse()).concat(chain);
      cur = { i: p.i, w: p.w === 1 ? 0 : 1 };
    }
    out.push(chain);
  });
  return out;
}

// Teilstücke der Wege innerhalb des Gebiets. Echte Wegenden im Wald werden bis zu 60 m bis zum Rand verlängert.
export function waysInside(lines, mp) {
  const edges = [];
  for (const poly of mp) for (const r0 of poly) { const r = closeRing(r0); for (let i = 0; i < r.length - 1; i++) edges.push([r[i], r[i + 1]]); }
  if (!edges.length) return [];
  let bx0 = Infinity; let by0 = Infinity; let bx1 = -Infinity; let by1 = -Infinity;
  for (const [a] of edges) { bx0 = Math.min(bx0, a[0]); by0 = Math.min(by0, a[1]); bx1 = Math.max(bx1, a[0]); by1 = Math.max(by1, a[1]); }
  const extend = (p, q) => { // von p in Richtung p-q bis zum Rand
    const len = Math.hypot(p[0] - q[0], p[1] - q[1]);
    if (!len) return null;
    const tip = [p[0] + ((p[0] - q[0]) / len) * WAY_EXTEND_M, p[1] + ((p[1] - q[1]) / len) * WAY_EXTEND_M];
    let best = null;
    for (const [c, d] of edges) {
      const t = segHit(p, tip, c, d);
      if (t != null && t > 1e-9 && (best == null || t < best)) best = t;
    }
    if (best == null) return null;
    const f = (best * WAY_EXTEND_M + 1) / WAY_EXTEND_M; // 1 m über den Rand hinaus
    return [p[0] + (tip[0] - p[0]) * f, p[1] + (tip[1] - p[1]) * f];
  };
  const runs = [];
  for (const line of chainLines(lines)) {
    if (line.length < 2) continue;
    let minx = Infinity; let miny = Infinity; let maxx = -Infinity; let maxy = -Infinity;
    for (const q of line) { minx = Math.min(minx, q[0]); miny = Math.min(miny, q[1]); maxx = Math.max(maxx, q[0]); maxy = Math.max(maxy, q[1]); }
    if (maxx < bx0 || minx > bx1 || maxy < by0 || miny > by1) continue;
    let run = null; // { pts, extStart }
    const close = (extEnd) => {
      if (run && run.pts.length >= 2) {
        if (run.extStart) { const e = extend(run.pts[0], run.pts[1]); if (e) run.pts.unshift(e); }
        if (extEnd) { const n = run.pts.length; const e = extend(run.pts[n - 1], run.pts[n - 2]); if (e) run.pts.push(e); }
        runs.push(run.pts);
      }
      run = null;
    };
    for (let i = 0; i < line.length - 1; i++) {
      const a = line[i];
      const b = line[i + 1];
      const ts = [0, 1];
      for (const [c, d] of edges) { const t = segHit(a, b, c, d); if (t != null) ts.push(t); }
      ts.sort((x, y) => x - y);
      for (let k = 0; k < ts.length - 1; k++) {
        const t0 = ts[k];
        const t1 = ts[k + 1];
        if (t1 - t0 < 1e-9) continue;
        const at = (t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
        if (inMp(at((t0 + t1) / 2), mp)) {
          if (!run) run = { pts: [at(t0)], extStart: i === 0 && t0 === 0 };
          run.pts.push(at(t1));
        } else close(false);
      }
    }
    close(true);
  }
  return runs;
}

// Streifen von 2 * WAY_HALF_M Breite um eine Linie (Vereinigung der Segmentrechtecke)
function strip(line) {
  const rects = [];
  for (let i = 0; i < line.length - 1; i++) {
    const a = line[i];
    const b = line[i + 1];
    const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    if (len < 1e-6) continue;
    const dx = ((b[0] - a[0]) / len) * WAY_HALF_M;
    const dy = ((b[1] - a[1]) / len) * WAY_HALF_M;
    const p = [a[0] - dx, a[1] - dy];
    const q = [b[0] + dx, b[1] + dy];
    rects.push([[[p[0] - dy, p[1] + dx], [q[0] - dy, q[1] + dx], [q[0] + dy, q[1] - dx], [p[0] + dy, p[1] - dx], [p[0] - dy, p[1] + dx]]]);
  }
  if (!rects.length) return [];
  return rects.length > 1 ? pc.union(...rects) : rects;
}

// Liegt p links der (ausgerichteten) Linie? Links = Seite des Achsenanfangs
function leftOf(p, line) {
  let best = Infinity; let side = 0;
  for (let i = 0; i < line.length - 1; i++) {
    const a = line[i]; const b = line[i + 1];
    const dx = b[0] - a[0]; const dy = b[1] - a[1];
    const l2 = dx * dx + dy * dy;
    if (!l2) continue;
    const t = Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2));
    const d = Math.hypot(p[0] - (a[0] + dx * t), p[1] - (a[1] + dy * t));
    if (d < best) { best = d; side = dx * (p[1] - a[1]) - dy * (p[0] - a[0]); }
  }
  return side > 0;
}

// Schnitt entlang des besten Wegs: { piece, rest } oder null
function wayCut(R, runs, u, target, total) {
  const v = [-u[1], u[0]];
  const c0 = findCut(R, u, target, 0.02);
  const cLo = findCut(R, u, target * (1 - WAY_TOL), 0.04);
  const cHi = findCut(R, u, Math.min(target * (1 + WAY_TOL), mpArea(R) * 0.999), 0.04);
  const cands = [];
  for (const run0 of runs) {
    const d = [run0[run0.length - 1][0] - run0[0][0], run0[run0.length - 1][1] - run0[0][1]];
    const dl = Math.hypot(d[0], d[1]);
    if (dl < 1) continue;
    const dv = (d[0] * v[0] + d[1] * v[1]) / dl;
    if (Math.abs(dv) < WAY_MIN_COS) continue;
    const run = dv < 0 ? run0.slice().reverse() : run0; // Richtung wie v, links = Achsenanfang
    let s0 = Infinity; let s1 = -Infinity;
    for (const q of run) { const s = q[0] * u[0] + q[1] * u[1]; s0 = Math.min(s0, s); s1 = Math.max(s1, s); }
    if (s1 < cLo - 5 || s0 > cHi + 5) continue;
    cands.push({ run, mid: (s0 + s1) / 2 });
  }
  cands.sort((a, b) => Math.abs(a.mid - c0) - Math.abs(b.mid - c0));
  let best = null;
  for (const { run } of cands.slice(0, 25)) {
    let pieces;
    try { pieces = pc.difference(R, strip(run)); } catch { continue; }
    const low = []; const high = [];
    for (const poly of pieces) (leftOf(centroid(poly), run) ? low : high).push(poly);
    if (!low.length || !high.length) continue;
    const a = mpArea(low);
    const dev = Math.abs(a - target);
    if (dev > WAY_TOL * target || mpArea(high) < 0.01 * total) continue;
    if (!best || dev < best.dev) best = { dev, piece: low, rest: high };
  }
  return best;
}

// Aufteilen: Teile werden entlang der Hauptachse nacheinander abgeschnitten, das letzte ist der Rest.
// mp: MultiPolygon in Metern; sh: Anteile (Summe 1); lines: Wege/Bäche in Metern.
// -> [{ polys: [Ring…], area, onWay }]; onWay: eine Grenze des Teils folgt einem Weg
export function splitArea(mp, sh, lines = [], opts = {}) {
  const total = mpArea(mp);
  const sum = sh.reduce((a, b) => a + b, 0) || 1;
  const w = sh.map((x) => x / sum);
  if (w.length <= 1 || !mp.length) return [{ polys: mp.map((p) => closeRing(p[0])), area: total, onWay: false }];
  const axis = mainAxis(mp);
  const runs = opts.followWays && lines.length ? waysInside(lines, mp) : [];
  let R = mp;
  const pieces = [];
  const cutWay = [];
  let done = 0; // v121: bisher abgeschnittene Fläche – jedes Teil gleicht die Abweichung der vorigen aus, nichts sammelt sich im letzten
  for (let i = 0; i < w.length - 1; i++) {
    const want = w.slice(0, i + 1).reduce((a, b) => a + b, 0) * total - done;
    const target = Math.min(Math.max(want, w[i] * total * 0.5), mpArea(R) * 0.98);
    let piece = null; let rest = null; let way = false;
    if (runs.length) {
      const cut = wayCut(R, runs, axis, target, total);
      if (cut) { piece = cut.piece; rest = cut.rest; way = true; }
    }
    if (!piece) {
      const hp = halfPlane(R, axis, findCut(R, axis, target, 0.002));
      piece = pc.intersection(R, hp);
      rest = pc.difference(R, hp);
    }
    pieces.push(piece);
    done += mpArea(piece);
    cutWay.push(way);
    R = rest;
  }
  pieces.push(R);
  return pieces.map((m, i) => {
    let polys = solid(m).map((p) => closeRing(p[0]));
    const big = polys.filter((r) => Math.abs(ringArea(r)) >= SLIVER_M2);
    if (big.length) polys = big;
    polys.sort((x, y) => Math.abs(ringArea(y)) - Math.abs(ringArea(x))); // größtes Stück zuerst
    return { polys, area: polys.reduce((s, r) => s + Math.abs(ringArea(r)), 0), onWay: !!(cutWay[i - 1] || cutWay[i]) };
  });
}

// Soll-Flächen in m²
export const targetAreas = (sh, total) => sh.map((x) => x * total);

// Teile -> Umrisse: [{ name, to, pts: [[lat, lon]…], part }]; Stücke ab dem zweiten: „Name (2)“ …
// names/teams je Teil; Punkte auf 6 Stellen, mit simplify (3 m) ausgedünnt, höchstens ~400 je Umriss.
export function toTracks(parts, names, teams, o) {
  const out = [];
  parts.forEach((part, i) => {
    const rings = part.polys.slice().sort((a, b) => Math.abs(ringArea(b)) - Math.abs(ringArea(a)));
    rings.forEach((ring, k) => {
      let pts = ring.map((q) => toLL(q, o));
      for (let tol = 3; ; tol = Math.ceil(tol * 1.6)) {
        const s = simplify(pts, tol);
        if (s.length <= 400 || tol > 200) { pts = s; break; }
      }
      pts = pts.slice(0, -1).map((q) => [Math.round(q[0] * 1e6) / 1e6, Math.round(q[1] * 1e6) / 1e6]);
      if (pts.length < 3) return;
      const base = names[i] || `Teil ${i + 1}`;
      const t = { name: k ? `${base} (${k + 1})` : base, pts, part: i };
      if (teams && teams[i]) t.to = teams[i];
      out.push(t);
    });
  });
  return out;
}
