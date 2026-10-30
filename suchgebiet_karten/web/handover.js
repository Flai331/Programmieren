// Übergabe eines ganzen Einsatzes an ein weiteres Gerät der Einsatzleitung (Handy -> Tablet/PC):
// Link #e=…, ein QR-Code oder – wenn es nicht in einen passt – mehrere, die durchwechseln (#m=…).
// Reine Logik ohne DOM, damit sie testbar ist.

import { normalizeProject, uid } from './store.js';
import { encodePts, decodePts, simplify } from './share.js';

const r3 = (v) => Math.round(v * 1000) / 1000;

// Einsatz -> kompakt. tol: Linien vereinfachen (Meter), pages: Notizblock mitnehmen. Fotos nie (nur per Datei).
export function buildHandover(p, { tol = 2, pages = true, from = '' } = {}) {
  const c = JSON.parse(JSON.stringify(p));
  delete c.view;
  delete c.handedOver;
  delete c.peers; // Empfänger von „Fortschritt senden“ gehören zu diesem Gerät
  c.items = (c.items || []).map((it) => {
    if (!Array.isArray(it.pts)) return it;
    const { pts, ...rest } = it;
    return { ...rest, pe: encodePts(tol ? simplify(pts, tol) : pts) };
  });
  const m = c.mission || {};
  const out = { v: 1, k: 'e', at: Date.now(), p: c, ...(from ? { from } : {}) }; // from: Name des sendenden Geräts
  if (m.photos && m.photos.length) out.np = m.photos.length;
  m.photos = [];
  const used = (m.pages || []).filter((pg) => pg.strokes && pg.strokes.length);
  if (pages) {
    m.pages = used.map((pg) => ({ ...pg, strokes: pg.strokes.map((s) => ({ ...s, pts: s.pts.map(([x, y]) => [r3(x), r3(y)]) })) }));
  } else {
    if (used.length) out.nn = used.length;
    m.pages = [];
  }
  return out;
}

// Übergabe -> Einsatz (neue lokale ID, Einsatz-ID bleibt)
export function projectFromHandover(e) {
  const c = { ...e.p };
  c.items = (c.items || []).map((it) => {
    if (!it.pe) return it;
    const { pe, ...rest } = it;
    return { ...rest, pts: decodePts(pe) };
  });
  const p = normalizeProject(c);
  p.id = uid();
  return p;
}

// Ersetzen eines vorhandenen Einsatzes: was nicht mitkam (Fotos, ggf. Notizblock), bleibt erhalten
export function replaceWithHandover(old, inc, e) {
  const p = { ...inc, id: old.id };
  p.mission = { ...inc.mission };
  if (old.mission && old.mission.photos && old.mission.photos.length) p.mission.photos = old.mission.photos;
  if (e.nn && old.mission && old.mission.pages) p.mission.pages = old.mission.pages;
  return p;
}

// ---------- Mehrteiliger QR-Code ----------
// Inhalt je Teil: 4 Zeichen Kennung, Teil-Nr. und Anzahl je 2 Zeichen (Basis 36), dann das Stück
const b36 = (n) => n.toString(36).padStart(2, '0');
export function splitParts(data, size = 1000) {
  const n = Math.max(1, Math.ceil(data.length / size));
  if (n > 36 * 36 - 1) throw new Error('zu groß');
  const sid = uid().slice(0, 4);
  return Array.from({ length: n }, (_, i) => `${sid}${b36(i)}${b36(n)}${data.slice(i * size, (i + 1) * size)}`);
}
// Sammelt Teile in store (Objekt); liefert { n, have, done } – done ist der zusammengesetzte Inhalt
export function addPart(store, part) {
  const sid = part.slice(0, 4);
  const i = parseInt(part.slice(4, 6), 36);
  const n = parseInt(part.slice(6, 8), 36);
  if (!(n > 0) || !(i >= 0) || i >= n) return { n: 0, have: 0, done: null };
  if (store.sid !== sid) { store.sid = sid; store.n = n; store.parts = {}; }
  store.parts[i] = part.slice(8);
  const have = Object.keys(store.parts).length;
  const done = have === n ? Array.from({ length: n }, (_, k) => store.parts[k]).join('') : null;
  return { n, have, done };
}
