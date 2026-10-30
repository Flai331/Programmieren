// Aufträge (Einsatzleitung -> Hundeführer) und Rückmeldungen (Hundeführer -> Einsatzleitung)
// ohne Server: Inhalt kompakt als JSON, komprimiert (deflate) und Base64url – im Link
// (#a=… / #r=…) oder im QR-Code. Reine Logik ohne DOM, damit sie testbar ist.

import { newProject, normalizeProject, uid, allGrids, gridLabel } from './store.js';
import { compactContact, fromCompact } from './contacts.js';
import { newLiveKey, mergeStatus, qrMsgs } from './status.js';
import { makeGrid, cellBounds } from './grid.js';

export const PUBLIC_URL = 'https://flai331.github.io/Programmieren/suchgebiet-karten/';

// ---------- Packen ----------
const b64url = (bytes) => {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
const unb64url = (s) => {
  const bin = atob(s.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((s.length + 3) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
};
async function pipe(bytes, stream) {
  const out = new Response(new Blob([bytes]).stream().pipeThrough(stream));
  return new Uint8Array(await out.arrayBuffer());
}
export async function pack(obj) {
  return b64url(await pipe(new TextEncoder().encode(JSON.stringify(obj)), new CompressionStream('deflate-raw')));
}
export async function unpack(str) {
  return JSON.parse(new TextDecoder().decode(await pipe(unb64url(str.trim()), new DecompressionStream('deflate-raw'))));
}
// Link oder nackter Inhalt (aus QR-Code, eingefügtem Text …) -> { kind: 'a'|'r', data }
export function parseShared(text) {
  // a = Auftrag, r = Rückmeldung, e = Einsatz-Übergabe, m = Teil eines mehrteiligen QR-Codes, i = Lage-Infos (ELW <-> EL)
  const m = String(text).match(/#([areimf])=([A-Za-z0-9_-]+)/);
  return m ? { kind: m[1], data: m[2] } : null;
}
export const shareLink = (kind, data, base = PUBLIC_URL) => `${base}#${kind}=${data}`;

// intent:-Link, der einen Link (mit #a=… usw.) an die Android-App gibt. Der #-Teil geht als ?h=… mit,
// weil ein intent:-Link selbst keinen tragen kann; ohne App zurück auf die Seite (?web=1: nicht nochmal fragen).
export function appIntentUrl(href, pkg) {
  const u = new URL(href);
  const path = u.pathname.replace(/index\.html$/, '');
  const back = `${u.origin}${path}?web=1${u.hash}`;
  return `intent://${u.host}${path}?h=${encodeURIComponent(u.hash.slice(1))}#Intent;scheme=https;package=${pkg};S.browser_fallback_url=${encodeURIComponent(back)};end`;
}

// ---------- Koordinaten kompakt: ganze Zahlen (1e-5° ≈ 1 m), ab dem 2. Punkt als Differenz ----------
const E5 = 1e5;
export function encodePts(pts) {
  const out = [];
  let la = 0;
  let lo = 0;
  for (const [lat, lon] of pts) {
    const a = Math.round(lat * E5);
    const o = Math.round(lon * E5);
    out.push(a - la, o - lo);
    la = a;
    lo = o;
  }
  return out;
}
export function decodePts(arr) {
  const out = [];
  let la = 0;
  let lo = 0;
  for (let i = 0; i + 1 < arr.length; i += 2) {
    la += arr[i];
    lo += arr[i + 1];
    out.push([la / E5, lo / E5]);
  }
  return out;
}

// Linie vereinfachen (Douglas-Peucker), Toleranz in Metern
export function simplify(pts, tolM = 5) {
  if (pts.length < 3) return pts.slice();
  const k = Math.cos((pts[0][0] * Math.PI) / 180);
  const xy = pts.map(([la, lo]) => [lo * 111320 * k, la * 110540]);
  const keep = new Uint8Array(pts.length);
  keep[0] = keep[pts.length - 1] = 1;
  const stack = [[0, pts.length - 1]];
  while (stack.length) {
    const [a, b] = stack.pop();
    const [ax, ay] = xy[a];
    const [bx, by] = xy[b];
    const dx = bx - ax;
    const dy = by - ay;
    const len = Math.hypot(dx, dy) || 1;
    let best = -1;
    let bi = -1;
    for (let i = a + 1; i < b; i++) {
      const d = Math.abs(dy * (xy[i][0] - ax) - dx * (xy[i][1] - ay)) / len;
      if (d > best) { best = d; bi = i; }
    }
    if (best > tolM) { keep[bi] = 1; stack.push([a, bi], [bi, b]); }
  }
  return pts.filter((_, i) => keep[i]);
}

const r6 = (v) => Math.round(v * 1e6) / 1e6;
const STATUS_CODES = { abgesucht: 'a', 'teilweise abgesucht': 't', 'nicht begehbar': 'n' };
const CODE_STATUS = Object.fromEntries(Object.entries(STATUS_CODES).map(([k, v]) => [v, k]));

// Zeichnung/Umriss/Text -> kompakt (nur, was der Hundeführer braucht)
function packItem(it, tol) {
  if (it.kind === 'text') return { k: 'x', c: it.color, n: it.text, p: encodePts([[it.lat, it.lon]]) };
  if (!it.pts || it.pts.length < 1) return null;
  return { k: it.kind === 'track' ? 't' : 's', c: it.color, n: it.name || '', o: it.open ? 1 : 0, p: encodePts(simplify(it.pts, tol)), ...(it.note ? { d: it.note } : {}) };
}
function unpackItem(x, extra = {}) {
  const pts = decodePts(x.p);
  if (x.k === 'x') return { kind: 'text', color: x.c, lat: pts[0][0], lon: pts[0][1], text: x.n, ...extra };
  if (x.k === 't') return { kind: 'track', color: x.c, name: x.n, w: 4, open: !!x.o, pts, ...(x.d ? { note: x.d } : {}), ...extra };
  return { kind: 'stroke', color: x.c, name: x.n, w: 4, pts, ...extra };
}

// ---------- Auftrag (Einsatzleitung) ----------
// Kurzbeschreibung eines Auftrags für die Übersicht der Einsatzleitung, z. B. „Gebiet 1: 6 Felder · Nordhang · „Bachlauf zuerst““
export function assignmentSummary(a) {
  const parts = [];
  for (const g of a.g || []) {
    const n = (g.f || []).length;
    parts.push(n ? `${g.n}: ${n} Feld${n === 1 ? '' : 'er'}` : `${g.n} (ganzes Gebiet)`);
  }
  const tracks = (a.i || []).filter((x) => x.k === 't' && !x.pv).map((x) => x.n || 'Umriss');
  if (tracks.length) parts.push(tracks.join(', '));
  if (a.pr) parts.push(`Vorher: ${a.pr}`);
  if (a.h) parts.push(`„${a.h.length > 60 ? `${a.h.slice(0, 59)}…` : a.h}“`);
  return parts.join(' · ');
}

// Dauer seit t (ms) als „12 min“ bzw. „1 h 05 min“
export function sinceText(t, now = Date.now()) {
  const m = Math.max(0, Math.floor((now - t) / 60000));
  return m < 60 ? `${m} min` : `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')} min`;
}

// sel: { teamId, gridIds: [], fields: 'team'|'all'|'pick', picked: {gridId: ["c,r"]}, itemIdx: [], meet, poiIds: [], rescue: [pts], hint, person, liveUrl }
// liveUrl: Adresse des Status-Servers (Einstellung dieses Geräts) -> Auftrag trägt Adresse und Schlüssel (ls), Einsatz bekommt p.live
export function buildAssignment(p, sel) {
  const team = p.marks.find((m) => m.id === sel.teamId && m.kind === 'team') || null;
  const statusById = Object.fromEntries(p.marks.filter((m) => m.kind === 'status').map((m) => [m.id, STATUS_CODES[m.label] || '']));
  const grids = allGrids(p).filter((g) => sel.gridIds.includes(g.id)).map((g) => {
    let f;
    if (sel.fields === 'pick') f = (sel.picked && sel.picked[g.id]) || [];
    else f = team ? Object.keys(g.fills).filter((k) => g.fills[k] === team.id) : [];
    // „nur Felder des Teams“: das Gebiet bleibt sichtbar, Felder des Teams hervorgehoben
    const s = Object.entries(g.status || {}).filter(([, id]) => statusById[id]).map(([k, id]) => `${k}${statusById[id]}`);
    const out = {
      i: g.id, n: gridLabel(p, g), m: g.cellM,
      a: [r6(g.area.north), r6(g.area.south), r6(g.area.west), r6(g.area.east)], f, s,
    };
    // „ganzes Gebiet“: Felder der anderen Teams grau mitschicken
    if (sel.fields === 'all') out.o = Object.keys(g.fills).filter((k) => !team || g.fills[k] !== team.id);
    return out;
  });
  const items = (sel.itemIdx || []).map((i) => p.items[i]).filter(Boolean).map((it) => packItem(it, 3)).filter(Boolean);
  // v101: Wege/Markierungen des vorherigen Teams (sel.prev = [{ team, pct, itemIdx }]) – beim neuen Team grau, nur zum Ansehen
  const prev = sel.prev || [];
  for (const g of prev) {
    for (const i of g.itemIdx || []) {
      const x = p.items[i] && packItem(p.items[i], 6);
      if (x) items.push({ ...x, pv: g.team });
    }
  }
  const out = { v: 1, k: 'a', id: uid(), t: p.title || 'Suchgebiet', at: Date.now(), g: grids, i: items };
  if (team) out.tm = { l: team.label, c: team.color, d: team.dog || '' };
  if (sel.hint) out.h = sel.hint;
  const pvText = prev.filter((g) => (g.itemIdx || []).length).map((g) => (g.pct != null ? `${g.pct} % von ${g.team} abgesucht` : `${g.team} war schon hier`)).join(' · ');
  if (pvText) out.pr = pvText;
  if (sel.meet && p.meet) out.mp = [r6(p.meet.lat), r6(p.meet.lon), p.meet.text || ''];
  // Lage-Orte (ELW, Verpflegung …): [id, Art, lat, lon, Name, Hinweis]
  const pois = (p.pois || []).filter((x) => (sel.poiIds || []).includes(x.id));
  if (pois.length) out.po = pois.map((x) => [x.id, x.cat, r6(x.lat), r6(x.lon), x.name || '', (x.desc || '').slice(0, 200)]);
  if (sel.rescue && sel.rescue.length) out.rp = sel.rescue.map((r) => [r.n, r6(r.lat), r6(r.lon)]);
  if (sel.person && p.mission && p.mission.person) out.vp = p.mission.person.trim().slice(0, 400);
  if (sel.contacts && sel.contacts.length) out.ct = sel.contacts.map(compactContact);
  if (sel.liveUrl) {
    if (!p.live) p.live = { url: sel.liveUrl, key: newLiveKey(), since: 0, ack: [], msgs: [] };
    p.live.url = sel.liveUrl;
    out.ls = [p.live.url, p.live.key];
  }
  return out;
}

// Mitte eines Auftrags für die Status-Plakette der Einsatzleitung: Felder des Teams, sonst Raster, sonst Umrisse
export function assignmentCenter(a) {
  const pts = [];
  for (const g of a.g || []) {
    const area = { north: g.a[0], south: g.a[1], west: g.a[2], east: g.a[3] };
    if (!(g.f || []).length) { pts.push([area.north, area.west], [area.south, area.east]); continue; }
    const gr = makeGrid(area, g.m);
    for (const k of g.f) {
      const [c, r] = k.split(',').map(Number);
      const b = cellBounds(gr, c, r);
      pts.push([b.north, b.west], [b.south, b.east]);
    }
  }
  if (!pts.length) for (const x of a.i || []) pts.push(...decodePts(x.p));
  if (!pts.length) return null;
  const la = pts.map((q) => q[0]);
  const lo = pts.map((q) => q[1]);
  return [r6((Math.min(...la) + Math.max(...la)) / 2), r6((Math.min(...lo) + Math.max(...lo)) / 2)];
}

// Auftrag -> neues Suchgebiet auf dem Handy des Hundeführers
export function projectFromAssignment(a) {
  const p = newProject(`${a.t}${a.tm ? ` – ${a.tm.l}` : ''}`);
  const team = { id: 'team', kind: 'team', label: a.tm ? a.tm.l : 'Mein Auftrag', color: a.tm ? a.tm.c : '#d50000', dog: a.tm ? a.tm.d : '' };
  const others = { id: 'others', kind: 'team', label: 'andere Teams', color: '#9e9e9e', dog: '' };
  p.marks = [team, ...(a.g.some((g) => g.o && g.o.length) ? [others] : []), ...p.marks];
  const statusId = (code) => (p.marks.find((m) => m.kind === 'status' && m.label === CODE_STATUS[code]) || {}).id;
  const grids = a.g.map((g) => {
    const fills = Object.fromEntries([...(g.o || []).map((k) => [k, 'others']), ...g.f.map((k) => [k, 'team'])]);
    const status = {};
    for (const s of g.s || []) { const id = statusId(s.slice(-1)); if (id) status[s.slice(0, -1)] = id; }
    return { id: g.i, name: g.n, area: { north: g.a[0], south: g.a[1], west: g.a[2], east: g.a[3] }, cellM: g.m, fills, status };
  });
  if (grids.length) {
    const [first, ...rest] = grids;
    Object.assign(p, { gridId: first.id, gridName: first.name, area: first.area, cellM: first.cellM, fills: first.fills, status: first.status, otherGrids: rest });
  }
  p.items = (a.i || []).map((x) => unpackItem(x, { fromEl: true, ...(x.pv ? { prev: String(x.pv) } : {}) }));
  p.contacts = (a.ct || []).map(fromCompact).filter((c) => c.name || c.phone);
  if (a.mp) p.meet = { lat: a.mp[0], lon: a.mp[1], text: a.mp[2] };
  p.pois = (a.po || []).map(([id, cat, lat, lon, name, desc]) => ({ id, cat, lat, lon, name, desc, t: a.at, by: 'Einsatzleitung' }));
  if (a.vp) p.mission.person = a.vp;
  p.hf = {
    id: a.id, at: a.at, received: Date.now(), team: team.label, hint: a.h || '', ...(a.pr ? { prev: String(a.pr) } : {}), grids: a.g.map((g) => g.i),
    track: [], // aufgezeichnete Wege: [{ t0, pts: [[lat, lon]] }]
    outbox: [], log: [], // Status-Meldungen: noch nicht gesendet / alle eigenen
    ...(Array.isArray(a.ls) && a.ls.length === 2 && /^https:\/\/script\.google\.com\//.test(String(a.ls[0])) ? { ls: [String(a.ls[0]), String(a.ls[1])] } : {}), // Status-Server: [Adresse, Schlüssel]
  };
  p.hfRescue = (a.rp || []).map(([n, lat, lon]) => ({ n, lat, lon }));
  return normalizeProject(p);
}

// ---------- Rückmeldung (Hundeführer) ----------
// Wege, eigene Markierungen/Zeichnungen und Feldstatus seit Auftragseingang
export function buildResult(p, tol = 5) {
  const statusCode = Object.fromEntries(p.marks.filter((m) => m.kind === 'status').map((m) => [m.id, STATUS_CODES[m.label] || '']));
  const d = [];
  for (const g of allGrids(p)) {
    const gi = p.hf.grids.indexOf(g.id);
    if (gi < 0) continue;
    for (const [k, id] of Object.entries(g.status || {})) if (statusCode[id]) d.push(`${gi}:${k}${statusCode[id]}`);
  }
  const tr = p.hf.track.filter((s) => s.pts.length > 1).map((s) => ({ t: s.t0, p: encodePts(simplify(s.pts, tol)) }));
  const items = p.items.filter((it) => !it.fromEl && !it.rec).map((it) => ({ ...packItem(it, 3), t: it.t || 0 })).filter((x) => x.p);
  // Wind-Messungen des Hundeführers: [Zeit, aus °, Stärke, Breite, Länge]
  const w = (p.mission.wind || []).filter((x) => x.src === 'gemessen' && x.t >= (p.hf.received || 0) && !x.by)
    .map((x) => [x.t, Math.round(x.from), x.strength, r6(x.lat ?? 0), r6(x.lon ?? 0)]);
  // Status-Meldungen (Stand, Pause …) gehen auch mit der QR-Rückmeldung mit – die letzten 20
  const sm = qrMsgs(p.hf.log).map(({ ok, ...m }) => m);
  return { v: 1, k: 'r', a: p.hf.id, tm: p.hf.team, at: Date.now(), tr, i: items, d, w, ...(sm.length ? { sm } : {}) };
}

// Rückmeldung ins Suchgebiet der Einsatzleitung übernehmen. sent: Liste gesendeter Aufträge
// (p.sent = [{ id, teamId, grids: [gridId…] }]). Liefert eine Zusammenfassung.
export function applyResult(p, r) {
  const sent = (p.sent || []).find((s) => s.id === r.a);
  let team = sent && p.marks.find((m) => m.id === sent.teamId);
  if (!team) team = p.marks.find((m) => m.kind === 'team' && m.label === r.tm);
  const color = team ? team.color : '#000000';
  const who = team ? team.label : (r.tm || 'Hundeführer');
  const hh = (t) => new Date(t).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
  const imp = p.imported || (p.imported = {});
  const key = (x) => `${r.a}|${x}`;
  let ways = 0;
  let marks = 0;
  let fields = 0;
  for (const s of r.tr || []) {
    if (imp[key(`t${s.t}`)] === (s.p.length)) continue; // schon übernommen (gleich lang)
    // ältere, kürzere Fassung desselben Wegs ersetzen
    p.items = p.items.filter((it) => it.resultKey !== key(`t${s.t}`));
    p.items.push({ kind: 'track', open: true, color, w: 4, name: `Weg ${who} ab ${hh(s.t)}`, pts: decodePts(s.p), resultKey: key(`t${s.t}`) });
    imp[key(`t${s.t}`)] = s.p.length;
    ways++;
  }
  for (const x of r.i || []) {
    const k = key(`i${x.t}|${x.n}|${x.p[0]},${x.p[1]}`);
    if (imp[k]) continue;
    p.items.push(unpackItem({ ...x, c: x.c || color }, { resultKey: k }));
    imp[k] = 1;
    marks++;
  }
  const grids = sent ? sent.grids : [];
  const statusId = (code) => (p.marks.find((m) => m.kind === 'status' && m.label === CODE_STATUS[code]) || {}).id;
  for (const e of r.d || []) {
    const [gi, rest] = e.split(':');
    const gid = grids[Number(gi)];
    const id = statusId(rest.slice(-1));
    const cell = rest.slice(0, -1);
    const g = gid && (gid === p.gridId ? p : (p.otherGrids || []).find((x) => x.id === gid));
    if (!g || !id) continue;
    if (g.status[cell] !== id) { g.status[cell] = id; fields++; }
  }
  let winds = 0;
  p.mission.wind = p.mission.wind || [];
  for (const [t, from, strength, lat, lon] of r.w || []) {
    const k = key(`w${t}`);
    if (imp[k]) continue;
    p.mission.wind.push({ t, from, strength, src: 'gemessen', lat, lon, by: who });
    imp[k] = 1;
    winds++;
  }
  p.mission.wind.sort((a, b) => a.t - b.t);
  // Status-Meldungen aus der QR-Rückmeldung (ohne Status-Server): p.qmsgs
  const before = (p.qmsgs || []).length;
  p.qmsgs = mergeStatus(p.qmsgs || [], (Array.isArray(r.sm) ? r.sm : []).filter((m) => m && m.a === r.a)).slice(-500);
  const msgs = p.qmsgs.length - before;
  p.updated = Date.now();
  return { who, ways, marks, fields, winds, msgs, known: !!sent };
}
