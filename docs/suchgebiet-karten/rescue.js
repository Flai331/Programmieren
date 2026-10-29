// Rettungspunkte (Forst-Rettungspunkte, z. B. vom KWF oder den Landesforsten): einmal als
// Datei importieren (GPX, KML oder CSV), dann offline auf der Karte, im PDF und als
// „nächster Rettungspunkt“. Punkt: { n: Nummer/Name, lat, lon }

import { fromUtm } from './utm.js';

const num = (s) => Number(String(s).trim().replace(',', '.'));
const valid = (p) => p.n && Number.isFinite(p.lat) && Number.isFinite(p.lon) && Math.abs(p.lat) <= 90 && Math.abs(p.lon) <= 180;
const text = (el, tag) => {
  const m = el.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, 'i'));
  return m ? m[1].replace(/<!\[CDATA\[|\]\]>/g, '').replace(/<[^>]+>/g, ' ').replace(/&amp;/g, '&').trim() : '';
};

function parseGpx(t) {
  const out = [];
  for (const m of t.matchAll(/<wpt\b([^>]*)>([\s\S]*?)<\/wpt>/gi)) {
    const lat = num((m[1].match(/lat="([^"]+)"/) || [])[1]);
    const lon = num((m[1].match(/lon="([^"]+)"/) || [])[1]);
    out.push({ n: text(m[2], 'name') || text(m[2], 'desc'), lat, lon });
  }
  return out;
}

function parseKml(t) {
  const out = [];
  for (const m of t.matchAll(/<Placemark\b[\s\S]*?<\/Placemark>/gi)) {
    const pm = m[0];
    const c = (pm.match(/<Point\b[\s\S]*?<coordinates>([^<]+)<\/coordinates>/i) || [])[1];
    if (!c) continue;
    const [lon, lat] = c.trim().split(/[\s]+/)[0].split(',').map(Number);
    // Nummer steht manchmal nur in ExtendedData
    let n = text(pm, 'name');
    if (!n) {
      const d = pm.match(/<(?:Simple)?Data name="(?:RP_?NR|RP_?Nummer|Nummer|NAME|rettungspunkt)[^"]*"[^>]*>(?:\s*<value>)?([^<]+)/i);
      if (d) n = d[1].trim();
    }
    out.push({ n, lat, lon });
  }
  return out;
}

// CSV/Text: Spalten werden am Kopf erkannt (Breite/Länge, lat/lon, x/y oder UTM-Ostwert/-Nordwert)
function parseCsv(t) {
  const lines = t.replace(/^﻿/, '').split(/\r?\n/).filter((l) => l.trim());
  if (lines.length < 2) return [];
  const sep = [';', '\t', ','].find((s) => lines[0].includes(s)) || ';';
  const split = (l) => l.split(sep).map((x) => x.trim().replace(/^"|"$/g, ''));
  const head = split(lines[0]).map((h) => h.toLowerCase().replace(/[^a-zäöü0-9]/g, ''));
  const col = (re) => head.findIndex((h) => re.test(h));
  let iLat = col(/^(lat|latitude|breite|breitengrad|wgs84lat|ywgs84|wgs84y|nb)$|lat$/);
  let iLon = col(/^(lon|lng|long|longitude|laenge|länge|laengengrad|längengrad|wgs84lon|xwgs84|wgs84x|el)$|lon$/);
  const iE = col(/^(ostwert|rechtswert|easting|east|utmost|utme|rw|x)$/);
  const iN = col(/^(nordwert|hochwert|northing|north|utmnord|utmn|hw|y)$/);
  const iZone = col(/^(zone|utmzone)$/);
  let iName = col(/^(rpnr|rpnummer|rettungspunkt|rettungspunktnr|nummer|nr|name|bezeichnung|rp|rpid|kennung|id)$/);
  if (iName < 0) iName = col(/rp|nr|name|nummer/);
  const out = [];
  for (const l of lines.slice(1)) {
    const c = split(l);
    const n = iName >= 0 ? c[iName] : '';
    if (iLat >= 0 && iLon >= 0) {
      out.push({ n, lat: num(c[iLat]), lon: num(c[iLon]) });
    } else if (iE >= 0 && iN >= 0) {
      // UTM: Ostwert evtl. mit Zone davor (32xxxxxx)
      let e = num(c[iE]);
      let zone = iZone >= 0 ? num(c[iZone]) : 32;
      if (e > 1e7) { zone = Math.floor(e / 1e6); e %= 1e6; }
      const ll = fromUtm(zone, e, num(c[iN]));
      out.push({ n, lat: ll.lat, lon: ll.lon });
    }
  }
  return out;
}

export function parseRescue(t) {
  const s = t.trim();
  let pts;
  if (/<gpx\b/i.test(s)) pts = parseGpx(s);
  else if (/<kml\b|<Placemark\b/i.test(s)) pts = parseKml(s);
  else pts = parseCsv(s);
  return pts.map((p) => ({ n: String(p.n).trim(), lat: Math.round(p.lat * 1e6) / 1e6, lon: Math.round(p.lon * 1e6) / 1e6 })).filter(valid);
}

// Neue Punkte dazunehmen; gleiche Nummer = ersetzt (aktualisierte Liste)
export function mergeRescue(existing, incoming) {
  const map = new Map(existing.map((p) => [p.n, p]));
  for (const p of incoming) map.set(p.n, p);
  return [...map.values()];
}

const R = 6371000;
export function distance(lat1, lon1, lat2, lon2) {
  const toR = Math.PI / 180;
  const dLat = (lat2 - lat1) * toR;
  const dLon = (lon2 - lon1) * toR;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * toR) * Math.cos(lat2 * toR) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}
export function bearing(lat1, lon1, lat2, lon2) {
  const toR = Math.PI / 180;
  const y = Math.sin((lon2 - lon1) * toR) * Math.cos(lat2 * toR);
  const x = Math.cos(lat1 * toR) * Math.sin(lat2 * toR) - Math.sin(lat1 * toR) * Math.cos(lat2 * toR) * Math.cos((lon2 - lon1) * toR);
  return ((Math.atan2(y, x) / toR) + 360) % 360;
}
const DIRS = ['N', 'NO', 'O', 'SO', 'S', 'SW', 'W', 'NW'];
export const compass = (deg) => DIRS[Math.round(deg / 45) % 8];

// nächster Punkt: { p, m (Meter), deg } oder null
export function nearest(points, lat, lon) {
  let best = null;
  for (const p of points) {
    // grob vorsortieren (schnell auch bei vielen tausend Punkten)
    const approx = Math.abs(p.lat - lat) + Math.abs(p.lon - lon) * 0.6;
    if (best && approx > best.approx) continue;
    const m = distance(lat, lon, p.lat, p.lon);
    if (!best || m < best.m) best = { p, m, approx: approx + 0.05 };
  }
  return best && { p: best.p, m: best.m, deg: bearing(lat, lon, best.p.lat, best.p.lon) };
}

// Rettungspunkte für einen Auftrag: im Umkreis (km) um den Mittelpunkt jedes übertragenen
// Rastergebiets bzw. Umrisses (Mitte des umschließenden Rechtecks), nächste zuerst.
// shapes: [{ rect: {north, south, west, east} } | { pts: [[lat, lon]…] }]
export function rescueNear(points, shapes, km = 3, max = 80) {
  const centers = shapes.map((s) => {
    if (s.rect) return [(s.rect.north + s.rect.south) / 2, (s.rect.west + s.rect.east) / 2];
    const la = s.pts.map((q) => q[0]);
    const lo = s.pts.map((q) => q[1]);
    return [(Math.max(...la) + Math.min(...la)) / 2, (Math.max(...lo) + Math.min(...lo)) / 2];
  });
  if (!centers.length) return [];
  const out = [];
  for (const pt of points) {
    const d = Math.min(...centers.map(([la, lo]) => distance(la, lo, pt.lat, pt.lon)));
    if (d <= km * 1000) out.push({ pt, d });
  }
  return out.sort((a, b) => a.d - b.d).slice(0, max).map((x) => x.pt);
}

export const inBounds = (points, b) => points.filter((p) => p.lat <= b.north && p.lat >= b.south && p.lon >= b.west && p.lon <= b.east);

// ---------- Speicher (IndexedDB – auch für zehntausende Punkte) ----------
function idb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open('suchgebiet', 1);
    req.onupgradeneeded = () => req.result.createObjectStore('data');
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
export async function loadRescue() {
  try {
    const d = await idb();
    return await new Promise((resolve) => {
      const r = d.transaction('data').objectStore('data').get('rescue');
      r.onsuccess = () => resolve(r.result || []);
      r.onerror = () => resolve([]);
    });
  } catch { return []; }
}
export async function storeRescue(points) {
  const d = await idb();
  await new Promise((resolve, reject) => {
    const tx = d.transaction('data', 'readwrite');
    tx.objectStore('data').put(points, 'rescue');
    tx.oncomplete = resolve;
    tx.onerror = () => reject(tx.error);
  });
}
