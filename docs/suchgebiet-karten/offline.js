// Offline-Karten: Kartenbilder für Bereiche vorab herunterladen (im WLAN, vor dem Einsatz).
// Gespeichert wird im Cache-Speicher des Browsers bzw. der App. Beim Anzeigen, im PDF und
// in der Garmin-Karte wird zuerst dort nachgesehen – das geht sofort und ohne Netz; nur was
// fehlt, kommt aus dem Internet.

import { tileUrl } from './layers.js';
import { mercX, mercY } from './grid.js';

export const TILE_CACHE = 'karten-offline-v1';

// Rechtecke um die Bundesländer (etwas Rand; außerhalb liefern die Luftbild-Dienste nur Leeres)
export const STATES = {
  ni: { name: 'Niedersachsen (ganzes Land)', bounds: { north: 53.90, south: 51.29, west: 6.65, east: 11.60 } },
  nw: { name: 'Nordrhein-Westfalen (ganzes Land)', bounds: { north: 52.53, south: 50.32, west: 5.86, east: 9.46 } },
};

const supported = () => typeof caches !== 'undefined';

// Zoomstufe der Adresse: 512er-Kacheln (Luftbild-WMS) liegen eine Stufe tiefer
const zoomOffset = (def) => Math.log2((def.tileSize || 256) / 256);

// Kachelnummern einer Zoomstufe (Kartenzoom wie in Leaflet), die das Rechteck berühren
export function tileRange(def, b, z) {
  const zu = z - zoomOffset(def);
  if (zu < 0) return null;
  const n = 2 ** zu;
  const px = (lon) => Math.floor((mercX(lon) / 256) * n);
  const py = (lat) => Math.floor((mercY(lat) / 256) * n);
  const clamp = (v) => Math.max(0, Math.min(n - 1, v));
  return { zu, x0: clamp(px(b.west)), x1: clamp(px(b.east)), y0: clamp(py(b.north)), y1: clamp(py(b.south)) };
}

// höchste sinnvolle Zoomstufe eines Dienstes (darüber vergrößert die Karte nur)
export const maxZoom = (def) => def.maxNative || 18;

export function countTiles(def, b, zMin, zMax) {
  let n = 0;
  for (let z = zMin; z <= Math.min(zMax, maxZoom(def)); z++) {
    const r = tileRange(def, b, z);
    if (r) n += (r.x1 - r.x0 + 1) * (r.y1 - r.y0 + 1);
  }
  return n;
}

// Alle Kachel-Adressen eines Bereichs (Generator: auch für sehr viele Kacheln)
export function* tileUrls(def, b, zMin, zMax) {
  for (let z = zMin; z <= Math.min(zMax, maxZoom(def)); z++) {
    const r = tileRange(def, b, z);
    if (!r) continue;
    for (let y = r.y0; y <= r.y1; y++) {
      for (let x = r.x0; x <= r.x1; x++) yield tileUrl(def, r.zu, x, y);
    }
  }
}

// Grobe Größe je Kachel in KB (Erfahrungswerte): Luftbild-JPEG 512 px, Karten-PNG 256 px
export function tileKB(def) {
  if (def.wms) return 90;
  if (def.blend) return 8; // Wege-Ebene über dem Luftbild: fast nur Weiß
  return 18;
}

// Schätzung für einen Bereich: { tiles, mb, minutes }
export function estimate(defs, b, zMin, zMax) {
  let tiles = 0;
  let kb = 0;
  let sec = 0;
  for (const d of defs) {
    const t = countTiles(d, b, zMin, zMax);
    tiles += t;
    kb += t * tileKB(d);
    // 4 gleichzeitig; WMS rechnet jede Kachel (~1 s), fertige Kacheln gehen schneller
    sec += t * (d.wms ? 0.3 : 0.08);
  }
  return { tiles, mb: kb / 1024, minutes: sec / 60 };
}

// Gespeicherte Kachel als Objekt-URL (oder null) – für Anzeige und PDF
let anyStored = null;
export function setHasOffline(v) { anyStored = v; }
export async function cachedTileUrl(url) {
  if (!supported() || anyStored === false) return null;
  try {
    const cache = await caches.open(TILE_CACHE);
    const res = await cache.match(url);
    if (!res) return null;
    return URL.createObjectURL(await res.blob());
  } catch {
    return null;
  }
}

// Bereich herunterladen. region: { bounds, layerIds, zMin, zMax }, defs: Kartendienste.
// Bereits gespeicherte Kacheln werden übersprungen (Fortsetzen nach Abbruch).
// onProgress({ done, total, failed, bytes }); signal: AbortController.signal
export async function downloadRegion(region, defs, onProgress, signal, concurrency = 4) {
  if (!supported()) throw new Error('Dieser Browser kann keine Karten offline speichern.');
  const cache = await caches.open(TILE_CACHE);
  const total = defs.reduce((a, d) => a + countTiles(d, region.bounds, region.zMin, region.zMax), 0);
  const st = { done: 0, total, failed: 0, bytes: 0 };
  const queue = (function* all() {
    for (const d of defs) yield* tileUrls(d, region.bounds, region.zMin, region.zMax);
  }());
  let lastReport = 0;
  const report = (force) => {
    const now = Date.now();
    if (force || now - lastReport > 400) { lastReport = now; onProgress && onProgress({ ...st }); }
  };
  async function fetchOne(url) {
    if (await cache.match(url)) return;
    for (let attempt = 0; attempt < 3; attempt++) {
      if (signal && signal.aborted) return;
      try {
        const res = await fetch(url, { mode: 'cors', signal });
        const type = res.headers.get('content-type') || '';
        if (res.ok && type.startsWith('image/')) {
          const blob = await res.blob();
          st.bytes += blob.size;
          await cache.put(url, new Response(blob, { headers: { 'content-type': type } }));
          return;
        }
      } catch (e) {
        if (signal && signal.aborted) return;
      }
      await new Promise((r) => setTimeout(r, 800 * (attempt + 1)));
    }
    st.failed++;
  }
  async function worker() {
    for (;;) {
      if (signal && signal.aborted) return;
      const next = queue.next();
      if (next.done) return;
      await fetchOne(next.value);
      st.done++;
      report();
    }
  }
  await Promise.all(Array.from({ length: concurrency }, worker));
  report(true);
  anyStored = true;
  return st;
}

// Kacheln eines Bereichs löschen – außer denen, die ein anderer gespeicherter Bereich auch braucht
export async function deleteRegion(region, defs, others, defOf) {
  if (!supported()) return;
  const cache = await caches.open(TILE_CACHE);
  const keep = new Set();
  for (const o of others) {
    for (const id of o.layerIds) {
      const d = defOf(id);
      if (!d || !region.layerIds.includes(id)) continue;
      for (const u of tileUrls(d, o.bounds, o.zMin, o.zMax)) keep.add(u);
    }
  }
  for (const d of defs) {
    for (const u of tileUrls(d, region.bounds, region.zMin, region.zMax)) {
      if (!keep.has(u)) await cache.delete(u);
    }
  }
}

// Belegter und freier Speicher (Schätzung des Browsers), in MB
export async function storageInfo() {
  try {
    const e = await navigator.storage.estimate();
    return { usedMB: (e.usage || 0) / 1048576, quotaMB: (e.quota || 0) / 1048576 };
  } catch {
    return null;
  }
}

// Speicher als „dauerhaft“ anfragen, damit der Browser die Karten nicht von sich aus löscht
export async function persistStorage() {
  try { return await navigator.storage.persist(); } catch { return false; }
}

// ---------- Android-App: Download im Hintergrund (nativer Dienst) ----------
// Die App lädt selbst (läuft weiter bei ausgeschaltetem Bildschirm, speichert als Dateien –
// auch auf der SD-Karte, ohne Browser-Speichergrenze) und liefert die Bilder beim Anzeigen
// direkt aus. Damit dieselben Adressen entstehen wie hier, bekommt sie je Karte eine
// Vorlage plus Stichproben, die sie vor dem Start mit ihren eigenen Adressen vergleicht.
export function nativeLayer(def) {
  const off = zoomOffset(def);
  const layer = { zoomOffset: off, maxZoom: maxZoom(def) };
  if (def.wms) {
    const u = tileUrl(def, 0, 0, 0);
    layer.wmsPrefix = u.slice(0, u.indexOf('BBOX=') + 5);
  } else {
    layer.template = def.url;
    layer.subdomains = def.subdomains ? def.subdomains.join('') : '';
  }
  // Stichproben aus verschiedenen Zoomstufen und Kachelnummern
  layer.samples = [[3, 4, 2], [10, 531, 340], [15, 17030, 10870], [17, 68123, 43500]]
    .map(([z, x, y]) => ({ z, x, y, url: tileUrl(def, z, x, y) }));
  return layer;
}

export function nativeJob(region, defs, wifiOnly) {
  return {
    id: region.id,
    name: region.name,
    bounds: region.bounds,
    zMin: region.zMin,
    zMax: region.zMax,
    wifiOnly: !!wifiOnly,
    layers: defs.map(nativeLayer),
  };
}
