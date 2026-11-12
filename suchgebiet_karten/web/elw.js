// v124: Zeichnung mit Auftrag an den ELW. Ein EL-Gerät schickt Umrisse/Striche samt Auftragstext über den
// Live-Raum (Ende-zu-Ende verschlüsselt wie die Statusmeldungen) an ein anderes EL-Gerät. Reine Logik ohne DOM.
// Nachrichtenarten: 'elw' (ganzer Auftrag) und 'elwp' (Teil eines großen Auftrags; der Server nimmt je Zeile
// höchstens 20000 Zeichen – verschlüsselt, Base64).

import { uid } from './store.js';
import { simplify } from './share.js';

export const ELW_KIND = 'elw';
export const ELW_PART = 'elwp';
export const ELW_KINDS = [ELW_KIND, ELW_PART];
export const ELW_ALL = '*';
// Klartext je Teil: Sonderzeichen werden als \uXXXX geschrieben (1 Zeichen = 1 Byte), Anführungszeichen im Teil
// werden beim Verpacken doppelt (\"), dazu Base64 (×4/3): 6000 → höchstens ~16000 < 20000
export const ELW_MAX_CHARS = 6000;
export const ELW_MAX_IN = 50;

export const elwTemplates = ['In 2 Gebiete aufteilen', 'In 3 Gebiete aufteilen', '2× DRK, 1× JUH', 'Aufzeichnen und drucken', 'Als Suchgebiet übernehmen'];

const r6 = (v) => Math.round(v * 1e6) / 1e6;
const rpts = (pts) => pts.map(([la, lo]) => [r6(la), r6(lo)]);
const str = (v, n) => String(v == null ? '' : v).slice(0, n);

// Zeichnung -> schlanke Kopie für den Versand: nur Form, Farbe, Name; keine IDs, Zeiten, Sperren, Team-ID
// (die Team-Zuordnung geht nur als Name toName mit). marks: Teams des Absenders [{ id, label }]
export function packElwItem(it, marks = []) {
  if (!it) return null;
  if (it.kind === 'text') {
    if (!Number.isFinite(it.lat) || !Number.isFinite(it.lon)) return null;
    return { kind: 'text', color: str(it.color, 20), lat: r6(it.lat), lon: r6(it.lon), text: str(it.text, 200) };
  }
  if ((it.kind !== 'track' && it.kind !== 'stroke') || !Array.isArray(it.pts) || it.pts.length < 2) return null;
  const pts = it.pts.length > 2 ? simplify(it.pts, 0.5) : it.pts;
  const o = { kind: it.kind, color: str(it.color, 20), w: Number(it.w) || 4, pts: rpts(pts) };
  if (it.name) o.name = str(it.name, 80);
  if (it.kind === 'track' && it.open) o.open = true;
  if (it.kind === 'stroke' && it.group) o.group = String(it.group).slice(0, 40);
  if (it.kind === 'track' && it.to) {
    const m = (marks || []).find((x) => x.id === it.to);
    if (m && m.label) o.toName = str(m.label, 60);
  }
  return o;
}

// Auftrag (Klartext-Nachricht). to: Name des Empfänger-Geräts oder '' / '*' = alle EL-Geräte
export function buildElwOrder({ from, to = '', txt = '', items = [], marks = [], t = Date.now(), id } = {}) {
  const its = (items || []).map((x) => packElwItem(x, marks)).filter(Boolean);
  return {
    s: ELW_KIND, a: 'EL', tm: 'Einsatzleitung', v: 1, id: id || uid(), t,
    from: str(from, 60), to: !to || to === ELW_ALL ? '' : str(to, 60), txt: str(txt, 300), items: its,
  };
}

// v130.23: Lesebestätigung für einen Auftrag (ref = dessen ID) – geht beim Öffnen automatisch zurück an „from“
export const ELW_ACK = 'elwq';
export function buildElwAck({ ref, to, from, t = Date.now(), id } = {}) {
  return { s: ELW_ACK, a: 'EL', tm: 'Einsatzleitung', v: 1, id: id || uid(), t, ref: str(ref, 40), to: str(to, 60), from: str(from, 60) };
}
export const isElwAck = (m) => !!m && m.s === ELW_ACK && typeof m.ref === 'string';

// Sonderzeichen als \uXXXX, damit die Länge in Zeichen der Länge in Bytes entspricht
const asciiJson = (o) => JSON.stringify(o).replace(/[\u0080-￿]/g, (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, '0')}`);

// Auftrag in Teile schneiden, wenn die JSON-Länge maxChars übersteigt; sonst [msg]
export function splitElwOrder(msg, maxChars = ELW_MAX_CHARS) {
  const json = asciiJson(msg);
  if (json.length <= maxChars) return [msg];
  const of = Math.ceil(json.length / maxChars);
  return Array.from({ length: of }, (_, n) => ({
    s: ELW_PART, a: 'EL', tm: 'Einsatzleitung', v: 1, id: `${msg.id}.${n}`, t: msg.t, oid: msg.id, n, of,
    part: json.slice(n * maxChars, (n + 1) * maxChars),
  }));
}

const okOrder = (m) => m && m.s === ELW_KIND && typeof m.id === 'string' && Array.isArray(m.items);
// Teile (und ganze Aufträge) zusammensetzen -> vollständige Aufträge; fehlt ein Teil, entsteht nichts
export function joinElwParts(msgs) {
  const out = new Map();
  const groups = new Map();
  for (const m of msgs || []) {
    if (!m) continue;
    if (okOrder(m)) { if (!out.has(m.id)) out.set(m.id, m); continue; }
    if (m.s !== ELW_PART || typeof m.oid !== 'string' || !(m.of > 0) || !(m.n >= 0) || m.n >= m.of || typeof m.part !== 'string') continue;
    const g = groups.get(m.oid) || { of: m.of, parts: new Map() };
    if (g.of === m.of) g.parts.set(m.n, m.part);
    groups.set(m.oid, g);
  }
  for (const [oid, g] of groups) {
    if (out.has(oid) || g.parts.size !== g.of) continue;
    try {
      const o = JSON.parse(Array.from({ length: g.of }, (_, i) => g.parts.get(i)).join(''));
      if (okOrder(o) && o.id === oid) out.set(oid, o);
    } catch { /* beschädigt: ignorieren */ }
  }
  return [...out.values()];
}

// Teile eines Auftrags, die noch fehlen (zum Anzeigen / Aufräumen): { oid: { have, of } }
export function elwPending(msgs) {
  const res = {};
  const done = new Set((msgs || []).filter(okOrder).map((m) => m.id));
  for (const m of msgs || []) {
    if (!m || m.s !== ELW_PART || done.has(m.oid)) continue;
    const g = res[m.oid] || (res[m.oid] = { have: new Set(), of: m.of });
    g.have.add(m.n);
  }
  return Object.fromEntries(Object.entries(res).map(([k, v]) => [k, { have: v.have.size, of: v.of }]));
}

// Empfangene Aufträge für dieses Gerät: nicht von mir, an alle oder an mich gerichtet, neueste zuerst, ohne Doppelte
export function elwInbox(msgs, myName) {
  const me = String(myName || '').trim().toLowerCase();
  const seen = new Set();
  const out = [];
  for (const m of msgs || []) {
    if (!okOrder(m) || seen.has(m.id)) continue;
    const to = String(m.to || '').trim().toLowerCase();
    if (me && String(m.from || '').trim().toLowerCase() === me) continue;
    if (to && to !== ELW_ALL && to !== 'alle' && to !== me) continue;
    seen.add(m.id);
    out.push(m);
  }
  return out.sort((x, y) => y.t - x.t);
}

// Liste der gespeicherten Aufträge (max. ELW_MAX_IN, neueste zuerst) um neue ergänzen; vorhandene (auch erledigte) bleiben
export function addElwIn(list, orders) {
  const have = new Set((list || []).map((o) => o.id));
  const fresh = (orders || []).filter((o) => o && !have.has(o.id));
  return { list: [...fresh, ...(list || [])].sort((x, y) => y.t - x.t).slice(0, ELW_MAX_IN), fresh };
}

// Aufträge einfügen: nur ergänzen. Items bekommen neue IDs; Herkunft elw (Auftrags-ID) + ei (Nr.) merken,
// damit dasselbe Einfügen nicht doppelt anlegt. Striche derselben Zeichnung bleiben eine Gruppe.
// Team-Zuordnung: nur wenn es ein Team mit dem Namen toName gibt. -> { added: [Items], skipped: Anzahl }
// v127: gleiche Zeichnung schon im Einsatz? (Art + Name/Text + Eckpunkte/Umfang, ~2 m Toleranz – der Versand
// vereinfacht die Linien, daher nicht Punkt für Punkt vergleichen)
const TOL = 2e-5;
const near = (a, b) => Math.abs(a - b) <= TOL;
function shapeKey(it) {
  if (it.kind === 'text') return Number.isFinite(it.lat) ? { k: 'text', n: String(it.text || '').trim().toLowerCase(), a: [it.lat, it.lon], b: [it.lat, it.lon], box: [it.lat, it.lon, it.lat, it.lon] } : null;
  if (!Array.isArray(it.pts) || it.pts.length < 2) return null;
  const la = it.pts.map((q) => q[0]);
  const lo = it.pts.map((q) => q[1]);
  return { k: it.kind, n: String(it.name || '').trim().toLowerCase(), a: it.pts[0], b: it.pts[it.pts.length - 1], box: [Math.min(...la), Math.min(...lo), Math.max(...la), Math.max(...lo)] };
}
export function sameDrawing(x, y) {
  const a = shapeKey(x);
  const b = shapeKey(y);
  if (!a || !b || a.k !== b.k || a.n !== b.n) return false;
  const ends = (near(a.a[0], b.a[0]) && near(a.a[1], b.a[1]) && near(a.b[0], b.b[0]) && near(a.b[1], b.b[1]))
    || (a.k !== 'track' && near(a.a[0], b.b[0]) && near(a.a[1], b.b[1]) && near(a.b[0], b.a[0]) && near(a.b[1], b.a[1]));
  return ends && a.box.every((v, i) => near(v, b.box[i]));
}

export function mergeElwItems(p, items, oid, { by = '', now = Date.now() } = {}) {
  p.items = p.items || [];
  const have = new Set(p.items.filter((i) => i.elw === oid).map((i) => i.ei));
  const existing = p.items.slice(); // nur gegen Bestehendes prüfen, nicht gegen Gleiches im selben Auftrag
  const groups = new Map();
  const added = [];
  let skipped = 0;
  (items || []).forEach((src, ei) => {
    if (!src || have.has(ei) || (src.id && existing.some((i) => i.id === src.id)) || existing.some((i) => sameDrawing(i, src))) { skipped++; return; }
    const it = { ...src, id: uid(), t: now, by, elw: oid, ei };
    if (Array.isArray(src.pts)) it.pts = src.pts.map((q) => [q[0], q[1]]);
    if (src.group) {
      if (!groups.has(src.group)) groups.set(src.group, uid());
      it.group = groups.get(src.group);
    }
    if (src.toName) {
      const m = (p.marks || []).find((x) => x.kind === 'team' && x.label === src.toName);
      if (m) it.to = m.id;
      delete it.toName;
    }
    p.items.push(it);
    added.push(it);
  });
  return { added, skipped };
}

// Eckpunkte aller Zeichnungen für „Zeigen“: [[lat, lon], …]
export const elwPoints = (items) => (items || []).flatMap((it) => (Array.isArray(it.pts) ? it.pts : Number.isFinite(it.lat) ? [[it.lat, it.lon]] : []));

// Kurzbeschreibung „2 Umrisse, 1 Zeichnung, 1 Text“
export function elwCounts(items) {
  const n = (k) => (items || []).filter((i) => i.kind === k).length;
  const groups = new Set((items || []).filter((i) => i.kind === 'stroke').map((i, x) => i.group || `s${x}`)).size;
  const pl = (c, one, many) => (c ? `${c} ${c === 1 ? one : many}` : '');
  return [pl(n('track'), 'Umriss', 'Umrisse'), pl(groups, 'Zeichnung', 'Zeichnungen'), pl(n('text'), 'Text', 'Texte')].filter(Boolean).join(', ') || 'nichts';
}
