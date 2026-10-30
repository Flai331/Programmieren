// Status-Meldungen Hundeführer -> Einsatzleitung über eine Google-Tabelle (Apps-Script-Web-App).
// Alles Inhaltliche ist Ende-zu-Ende verschlüsselt (AES-GCM); der Server sieht nur eine Raum-Kennung,
// die Meldungs-ID und Zufallsbytes. Reine Logik ohne DOM, damit sie testbar ist.

import { allGrids } from './store.js';
import { makeGrid, cellBounds } from './grid.js';

export const STATUS_LIST = [
  { code: 'da', ico: '🅿️', label: 'Parkplatz Auto' }, // am Suchgebiet angekommen, Auto abgestellt
  { code: 'start', ico: '▶️', label: 'Suche begonnen' },
  { code: 'pause', ico: '⏸', label: 'Pause' },
  { code: 'fertig', ico: '📊', label: 'Stand / fertig' }, // HF schätzt, wie viel abgesucht ist (100 % = fertig)
  { code: 'zurueck', ico: '🏁', label: 'Zurück am B-Ort' },
  { code: 'anzeige', ico: '🐕', label: 'Hund zeigt an' },
  { code: 'fund', ico: '🟢', label: 'Person gefunden' },
  { code: 'hilfe', ico: '🆘', label: 'Brauche Hilfe' },
];
export const SPOT_LIST = [
  { code: 'anzeige', ico: '🐕', label: 'Anzeige' },
  { code: 'fund', ico: '🟢', label: 'Fund' },
  { code: 'hinweis', ico: '👕', label: 'Hinweis' },
  { code: 'gefahr', ico: '⚠️', label: 'Gefahr' },
  { code: 'sonst', ico: '📌', label: 'Sonstiges' },
];
export const URGENT = ['fund', 'hilfe'];

const find = (list, code) => list.find((x) => x.code === code);
// ältere Meldungen, die es als Taste nicht mehr gibt
const OLD_LIST = [{ code: 'anfahrt', ico: '🚗', label: 'Anfahrt' }];
export function statusLabel(code) {
  const s = find(STATUS_LIST, code) || find(OLD_LIST, code);
  return s ? `${s.ico} ${s.label}` : code === 'ort' ? '📍 Standort' : code === 'ok' ? '📲 Auftrag übernommen' : String(code || '');
}
export function spotLabel(cat) {
  const s = find(SPOT_LIST, cat);
  return s ? `${s.ico} ${s.label}` : '📌 Standort';
}
// Stand-Meldung: erst bei 100 % (oder ohne Angabe) „Gebiet fertig“, sonst „40 % abgesucht“
// Mehrere Gebiete: m.ar = [[Name, Prozent], …], fertig erst, wenn alle bei 100 % sind
const done = (m) => m.s === 'fertig' && (Array.isArray(m.ar) && m.ar.length ? m.ar.every((x) => x[1] >= 100) : (m.pc == null || m.pc >= 100));
const areaText = (m) => m.ar.map(([n, p]) => `${n} ${p >= 100 ? '✅' : `${p} %`}`).join(' · ');
// Text einer Meldung: Standort-Meldungen nach ihrer Art
export const msgLabel = (m) => (m.s === 'ort' ? spotLabel(m.cat)
  : m.s === 'fertig' ? (Array.isArray(m.ar) && m.ar.length
    ? (done(m) ? '✅ Alle Gebiete fertig' : `📊 ${areaText(m)}`)
    : (done(m) ? '✅ Gebiet fertig' : `📊 ${m.pc} % abgesucht`)) : statusLabel(m.s));
// Nur das Symbol (für die Karte)
export function msgIcon(m) {
  if (m.s === 'fertig') return done(m) ? '✅' : '📊';
  const s = m.s === 'ort' ? find(SPOT_LIST, m.cat) : find(STATUS_LIST, m.s) || find(OLD_LIST, m.s);
  return s ? s.ico : m.s === 'ok' ? '📲' : '📍';
}
export const isUrgent = (m) => URGENT.includes(m.s) || (m.s === 'ort' && m.cat === 'fund');

// ---------- Base64url ----------
const b64url = (bytes) => {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
const unb64url = (s) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((s.length + 3) % 4)), (c) => c.charCodeAt(0));

// ---------- Schlüssel, Raum, Verschlüsselung ----------
const cr = () => globalThis.crypto;
export const newLiveKey = () => b64url(cr().getRandomValues(new Uint8Array(16)));
// Raum-Kennung: aus dem Schlüssel abgeleitet, verrät ihn aber nicht
export async function roomOf(key) {
  const h = await cr().subtle.digest('SHA-256', new TextEncoder().encode(`sgk-room|${key}`));
  return b64url(new Uint8Array(h)).slice(0, 22);
}
const aesKey = (key, use) => cr().subtle.importKey('raw', unb64url(key), 'AES-GCM', false, [use]);
export async function encryptMsg(key, obj) {
  const iv = cr().getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(await cr().subtle.encrypt({ name: 'AES-GCM', iv }, await aesKey(key, 'encrypt'), new TextEncoder().encode(JSON.stringify(obj))));
  const out = new Uint8Array(12 + ct.length);
  out.set(iv);
  out.set(ct, 12);
  return b64url(out);
}
export async function decryptMsg(key, d) {
  const raw = unb64url(d);
  const pt = await cr().subtle.decrypt({ name: 'AES-GCM', iv: raw.slice(0, 12) }, await aesKey(key, 'decrypt'), raw.slice(12));
  return JSON.parse(new TextDecoder().decode(pt));
}

// ---------- Meldungen ----------
const r6 = (v) => Math.round(v * 1e6) / 1e6;
// Neue Meldung (Klartext). pos: { lat, lon, acc? } oder null
export function buildMsg({ a, tm, s, cat, txt, pos, pc, pa, ar, t = Date.now(), id }) {
  const m = { v: 1, id: id || b64url(cr().getRandomValues(new Uint8Array(9))), a, tm, t, s };
  if (pos && Number.isFinite(pos.lat) && Number.isFinite(pos.lon)) {
    m.lat = r6(pos.lat);
    m.lon = r6(pos.lon);
    if (pos.acc != null) m.acc = Math.round(pos.acc);
  }
  if (txt) m.txt = String(txt).slice(0, 300);
  if (pc != null) m.pc = pc;
  if (pa != null) m.pa = pa;
  if (Array.isArray(ar) && ar.length) m.ar = ar.map(([n, p]) => [String(n).slice(0, 40), Number(p)]);
  if (cat) m.cat = cat;
  return m;
}
const okMsg = (m) => m && typeof m === 'object' && typeof m.id === 'string' && Number.isFinite(m.t) && typeof m.s === 'string';
// Neue Meldungen in die Liste einmischen: ohne Doppelte (id), nach Zeit sortiert
export function mergeStatus(list, msgs) {
  const byId = new Map();
  for (const m of [...(list || []), ...(msgs || [])]) if (okMsg(m) && !byId.has(m.id)) byId.set(m.id, m);
  return [...byId.values()].sort((x, y) => x.t - y.t);
}
// Gelöschte Meldungen (del: { id: Zeit }) aus der Liste nehmen
export const withoutDeleted = (list, del) => (del && Object.keys(del).length ? (list || []).filter((m) => !del[m.id]) : list || []);
// Letzte Meldung (und letzte „fertig“-Meldung) eines Auftrags
export function latestFor(list, a) {
  const own = (list || []).filter((m) => m.a === a);
  return { last: own[own.length - 1] || null, done: own.filter((m) => m.s === 'fertig').pop() || null };
}

// ---------- Übertragung (fetchFn austauschbar für Tests) ----------
const reqUrl = (url, q) => `${url}${url.includes('?') ? '&' : '?'}${q}`;
export async function postMsg(url, room, id, d, f = fetch) {
  const res = await f(url, { method: 'POST', redirect: 'follow', headers: { 'Content-Type': 'text/plain;charset=utf-8' }, body: JSON.stringify({ r: room, id, d }) });
  const j = await res.json();
  if (!j || !j.ok) throw new Error('abgelehnt');
  return true;
}
// Warteschlange abarbeiten (der Reihe nach, bei Fehler Stopp). Liefert { sent: [ids], left: [Meldungen] }
export async function flushOutbox(ls, outbox, f = fetch) {
  const [url, key] = ls;
  const room = await roomOf(key);
  const sent = [];
  for (const m of outbox) {
    try { await postMsg(url, room, m.id, await encryptMsg(key, m), f); } catch { break; }
    sent.push(m.id);
  }
  return { sent, left: outbox.filter((m) => !sent.includes(m.id)) };
}
// Neue Meldungen abholen: { msgs, since }. Nicht entschlüsselbare Zeilen (anderer Schlüssel) werden übergangen.
export async function pollMessages(live, f = fetch) {
  const room = await roomOf(live.key);
  const res = await f(reqUrl(live.url, `r=${encodeURIComponent(room)}&since=${live.since || 0}`));
  const j = await res.json();
  if (!j || !j.ok || !Array.isArray(j.rows)) throw new Error('keine Antwort');
  const msgs = [];
  let newest = 0;
  for (const [tm, , d] of j.rows) {
    newest = Math.max(newest, Number(tm) || 0);
    try { const m = await decryptMsg(live.key, d); if (okMsg(m)) msgs.push(m); } catch { /* fremde Zeile */ }
  }
  // eine Millisekunde zurück: eine gleichzeitig eingetroffene Zeile geht nicht verloren (Doppelte fallen weg)
  return { msgs, since: newest ? Math.max(live.since || 0, newest - 1) : live.since || 0 };
}

// ---------- Abdeckung (Prozent des Gebiets, das der Weg im Umkreis radiusM streift) ----------
const M_LAT = 111320;
const MAX_SAMPLES = 200000;
// shapes: [{ north, south, west, east }] oder [{ pts: [[lat, lon], …] }] (Umriss); track: [[[lat, lon], …], …] (mehrere Wege)
function sample(track, shapes, radiusM) {
  const segs = track.length && typeof track[0][0] === 'number' ? [track] : track;
  const box = shapes.map((s) => (s.pts ? {
    north: Math.max(...s.pts.map((q) => q[0])), south: Math.min(...s.pts.map((q) => q[0])),
    west: Math.min(...s.pts.map((q) => q[1])), east: Math.max(...s.pts.map((q) => q[1])),
  } : s));
  if (!box.length) return { total: 0, covered: 0, step: 5, cells: [] };
  const lat0 = (Math.max(...box.map((b) => b.north)) + Math.min(...box.map((b) => b.south))) / 2;
  const lon0 = (Math.max(...box.map((b) => b.east)) + Math.min(...box.map((b) => b.west))) / 2;
  const k = Math.cos((lat0 * Math.PI) / 180);
  const px = (lat, lon) => [(lon - lon0) * M_LAT * k, (lat - lat0) * M_LAT];
  // Weg dicht auffüllen und in ein Raster der Kantenlänge radiusM sortieren
  const hash = new Map();
  const gap = Math.max(1, Math.min(5, radiusM / 2));
  const put = (x, y) => {
    const key = Math.floor(x / radiusM) * 200003 + Math.floor(y / radiusM);
    const l = hash.get(key);
    if (l) l.push(x, y); else hash.set(key, [x, y]);
  };
  for (const sg of segs) {
    let prev = null;
    for (const [la, lo] of sg) {
      const q = px(la, lo);
      if (prev) {
        const n = Math.ceil(Math.hypot(q[0] - prev[0], q[1] - prev[1]) / gap);
        for (let i = 1; i < n; i++) put(prev[0] + ((q[0] - prev[0]) * i) / n, prev[1] + ((q[1] - prev[1]) * i) / n);
      }
      put(q[0], q[1]);
      prev = q;
    }
  }
  const near = (x, y) => {
    const cx = Math.floor(x / radiusM);
    const cy = Math.floor(y / radiusM);
    for (let i = cx - 1; i <= cx + 1; i++) {
      for (let j = cy - 1; j <= cy + 1; j++) {
        const l = hash.get(i * 200003 + j);
        if (l) for (let n = 0; n < l.length; n += 2) if ((l[n] - x) ** 2 + (l[n + 1] - y) ** 2 <= radiusM * radiusM) return true;
      }
    }
    return false;
  };
  const area = box.reduce((a, b) => a + (b.east - b.west) * k * M_LAT * (b.north - b.south) * M_LAT, 0);
  const step = Math.max(5, Math.sqrt(area / MAX_SAMPLES));
  let total = 0;
  let covered = 0;
  const cells = [];
  shapes.forEach((s, si) => {
    const b = box[si];
    const [x0, y1] = px(b.north, b.west);
    const [x1, y0] = px(b.south, b.east);
    const poly = s.pts ? s.pts.map(([la, lo]) => px(la, lo)) : null;
    for (let y = y0 + step / 2; y < y1; y += step) {
      for (let x = x0 + step / 2; x < x1; x += step) {
        if (poly && !inPoly(poly, x, y)) continue;
        total++;
        if (near(x, y)) covered++; else cells.push([lat0 + y / M_LAT, lon0 + x / (M_LAT * k)]);
      }
    }
  });
  return { total, covered, step, cells };
}
function inPoly(poly, x, y) {
  let in_ = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i];
    const [xj, yj] = poly[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) in_ = !in_;
  }
  return in_;
}
// 0–100, auf 5 gerundet; ohne Gebiet null
export function coveragePct(track, shapes, radiusM = 30) {
  const r = sample(track || [], shapes || [], radiusM);
  return r.total ? Math.round((r.covered / r.total) * 20) * 5 : null;
}
// Nicht abgedeckte Stellen: { step (m), pts: [[lat, lon], …] } – jede Stelle steht für ein Quadrat der Kantenlänge step
export function coverageGaps(track, shapes, radiusM = 30) {
  const r = sample(track || [], shapes || [], radiusM);
  return { step: r.step, pts: r.cells };
}
// Gebiet eines Auftrags als Formen: die Felder des Teams (teamId) in den Rastergebieten gridIds,
// sonst das ganze Raster; ohne Raster die geschlossenen Umrisse
export function areaShapes(p, { gridIds, teamId = 'team' } = {}) {
  const ids = gridIds || (p.hf && p.hf.grids) || [];
  const out = [];
  for (const g of allGrids(p).filter((x) => ids.includes(x.id))) {
    const keys = teamId ? Object.keys(g.fills).filter((q) => g.fills[q] === teamId) : [];
    if (!keys.length) { out.push({ ...g.area }); continue; }
    const gg = makeGrid(g.area, g.cellM);
    for (const q of keys) { const [c, r] = q.split(',').map(Number); out.push(cellBounds(gg, c, r)); }
  }
  if (!out.length && !ids.length) {
    for (const it of p.items || []) if (it.kind === 'track' && !it.open && !it.resultKey && it.pts && it.pts.length >= 3) out.push({ pts: it.pts });
  }
  return out;
}
