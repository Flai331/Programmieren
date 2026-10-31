// Fortschritt senden (#f): nur das Neue seit dem letzten Senden zwischen Geräten der Einsatzleitung
// (EL, Unterabschnitt/UA, ELW) – nur per QR-Code/Link, nie über den Status-Server.
// Zusammenführen NUR ergänzend (wie infos.js mergeInfos): Neues kommt dazu, Geändertes nur wenn der Absender
// es zuletzt bearbeitet hat (by === from) und neuer, nichts wird gelöscht, Löschvermerke des Empfängers
// blockieren Wiederanlegen. Feldkonflikt: neuere Änderung gewinnt, im UA-Gebiet entscheidet der UA.
// Richtung: UA -> EL nur UA-Gebiet + Neues des UA; EL -> UA alles, beim UA als lock 'base' (außer UA-eigenes).
import { allGrids, uid, NO_TEAM, isStatusUrl } from './store.js';
import { encodePts, decodePts, simplify } from './share.js';
import { mergeStatus, withoutDeleted } from './status.js';
import { normalizePois } from './pois.js';
import { infoTarget } from './infos.js';

const r6 = (v) => Math.round(v * 1e6) / 1e6;
const bool = (x) => !!x;

// ---------- Änderungen erkennen (läuft nach jeder Bearbeitung) ----------
// Hash einer Zeichnung ohne Zeit/Gerät/Sperre/Ausblenden (Linien nur grob: Länge + Enden)
const ihash = (it) => {
  const { t, by, lock, hidden, pts, pe, ...r } = it;
  return JSON.stringify([r, pts ? [pts.length, pts[0], pts[pts.length - 1]] : 0]);
};
const cellMap = (p) => {
  const m = new Map();
  for (const g of allGrids(p)) {
    for (const [k, v] of Object.entries(g.fills || {})) m.set(`${g.id}|${k}|f`, v);
    for (const [k, v] of Object.entries(g.status || {})) m.set(`${g.id}|${k}|s`, v);
  }
  return m;
};
const gridSig = (p) => new Map(allGrids(p).map((g) => [g.id, JSON.stringify([g.area, g.cellM])]));

// Ausgangsstand merken (vor einer Bearbeitung)
export function snapshotBase(p) {
  return {
    items: new Map((p.items || []).filter((i) => i.id).map((i) => [i.id, ihash(i)])),
    cells: cellMap(p), grids: gridSig(p), meet: p.meet ? JSON.stringify([p.meet.lat, p.meet.lon, p.meet.text]) : '',
  };
}

// Vergleicht mit dem Ausgangsstand: neue/geänderte Zeichnungen bekommen id, t und by, gelöschte einen Löschvermerk,
// geänderte Felder eine Zeit. Liefert den neuen Ausgangsstand.
export function stampChanges(p, base, by = '', now = Date.now()) {
  if (!p.itemDel) p.itemDel = {};
  if (!p.cellT) p.cellT = {};
  if (!p.gridT) p.gridT = {};
  for (const it of p.items) {
    if (!it.id) { it.id = uid(); it.t = now; it.by = by; continue; }
    const h = base && base.items.get(it.id);
    if (h !== undefined && h !== ihash(it)) { it.t = now; it.by = by; }
    delete p.itemDel[it.id]; // wieder da (Rückgängig)
  }
  if (base) {
    const ids = new Set(p.items.map((i) => i.id));
    for (const id of base.items.keys()) if (!ids.has(id)) p.itemDel[id] = now;
    const cur = cellMap(p);
    for (const [k, v] of cur) if (base.cells.get(k) !== v) { p.cellT[k] = now; if (p.cellBy) delete p.cellBy[k]; }
    for (const k of base.cells.keys()) if (!cur.has(k)) delete p.cellT[k];
    for (const [id, sig] of gridSig(p)) if (base.grids.get(id) !== sig) p.gridT[id] = now;
    if (p.meet) {
      const sig = JSON.stringify([p.meet.lat, p.meet.lon, p.meet.text]);
      if (sig !== base.meet) { p.meet.t = now; p.meet.by = by; }
    }
  }
  return snapshotBase(p);
}

// ---------- Empfänger ("An wen?") ----------
export const peerOf = (p, name) => (p.peers || []).find((x) => x.name === name) || null;
export function setPeer(p, name, lastSent) {
  if (!name) return null;
  name = String(name).slice(0, 60);
  p.peers = p.peers || [];
  let x = peerOf(p, name);
  if (!x) { x = { name, lastSent: 0 }; p.peers.push(x); }
  x.lastSent = lastSent;
  return x;
}

// ---------- Senden ----------
const packItem = (it) => {
  const { pts, hidden, ...r } = it;
  return pts ? { ...r, pe: encodePts(pts.length > 2 ? simplify(pts, 0.5) : pts) } : r;
};
const unpackItem = (x) => {
  const { pe, ...r } = x;
  return pe ? { ...r, pts: decodePts(pe) } : { ...r };
};
const packPoi = (x) => [x.id, x.cat, r6(x.lat), r6(x.lon), x.name || '', x.desc || '', x.t || 0, x.by || '', x.lock || ''];

// Neues/Geändertes seit since (0 = alles) für den Empfänger to. Leer -> null.
export function buildProgress(p, { from = '', to = '', since = 0, now = Date.now(), full = false } = {}) {
  const ua = !!p.parentEid;
  const nw = (t) => !since || (t || 0) > since;
  const own = (x) => !ua || x.lock !== 'base'; // UA schickt nichts vom Grund-Einsatz zurück
  const notTo = (x) => !to || x.by !== to; // was der Empfänger zuletzt bearbeitet hat, hat er schon
  const out = { k: 'f', v: 1, ...(full ? { full: 1 } : {}), eid: p.eid || p.id, ti: p.title || '', from, at: now, ...(p.parentEid ? { pe: p.parentEid } : {}) };
  let n = 0;
  const items = (p.items || []).filter((x) => x.id && own(x) && nw(x.t) && notTo(x));
  if (items.length) { out.it = items.map(packItem); n += items.length; }
  const cellT = p.cellT || {};
  const gs = [];
  for (const g of allGrids(p)) {
    const gl = ua ? (p.glock || {})[g.id] || '' : '';
    if (gl === 'base') continue;
    const w = gl === 'ua' && p.gown && Array.isArray(p.gown[g.id]) ? new Set(p.gown[g.id]) : null;
    const pick = (map, tag) => {
      const o = {};
      for (const [k, v] of Object.entries(map || {})) {
        if (w && !w.has(k)) continue;
        const ck = `${g.id}|${k}|${tag}`;
        const t = cellT[ck] || 0;
        if (nw(t) && !(to && (p.cellBy || {})[ck] === to)) o[k] = [v, t]; // vom Empfänger Gekommenes nicht zurückschicken
      }
      return o;
    };
    const f = pick(g.fills, 'f');
    const s = pick(g.status, 's');
    const cells = Object.keys(f).length + Object.keys(s).length;
    if (!cells && !nw((p.gridT || {})[g.id])) continue;
    gs.push({
      i: g.id, n: g.name || '', m: g.cellM, a: [r6(g.area.north), r6(g.area.south), r6(g.area.west), r6(g.area.east)], f, s,
      ...(gl ? { l: gl } : {}), ...(w ? { w: [...w] } : {}),
    });
    n += cells;
  }
  if (gs.length) out.g = gs;
  const pois = (p.pois || []).filter((x) => own(x) && nw(x.t) && notTo(x));
  if (pois.length) { out.po = pois.map(packPoi); n += pois.length; }
  if (p.meet && own(p.meet) && nw(p.meet.t) && notTo(p.meet)) out.me = { lat: r6(p.meet.lat), lon: r6(p.meet.lon), text: p.meet.text || '', t: p.meet.t || 0, by: p.meet.by || '', ...(p.meet.lock ? { lock: p.meet.lock } : {}) }, n++;
  const m = p.mission || {};
  const wind = (m.wind || []).filter((x) => nw(x.t));
  if (wind.length) { out.w = wind; n += wind.length; }
  if (!ua && (!since || (p.updated || 0) > since)) {
    if ((m.forces || []).length) { out.fo = m.forces; n += m.forces.length; }
    if (Object.keys(m.times || {}).length) { out.tm = m.times; n++; }
  }
  const imp = {};
  for (const it of items) if (it.resultKey && p.imported && p.imported[it.resultKey] != null) imp[it.resultKey] = p.imported[it.resultKey];
  if (Object.keys(imp).length) out.im = imp;
  const se = (p.sent || []).filter((x) => nw(Math.max(x.last || 0, x.acc || 0, x.at || 0)));
  if (se.length) { out.se = se.map(({ unlock, ...x }) => x); n += se.length; } // Freigabe (unlock) bleibt auf diesem Gerät
  const md = Object.fromEntries(Object.entries(p.msgDel || {}).filter(([, t]) => nw(t)));
  const ms = p.live ? withoutDeleted(p.live.msgs || [], p.msgDel).filter((x) => nw(x.t)) : [];
  if (ms.length) { out.ms = ms; n += ms.length; }
  if (Object.keys(md).length) { out.md = md; n += Object.keys(md).length; }
  if (!n) return null;
  // Status-Server: ein Schlüssel pro Einsatz – alle Geräte der Einsatzleitung lesen alle Meldungen
  if (p.live && p.live.url && p.live.key) out.lv = [p.live.url, p.live.key];
  out.mk = (p.marks || []).map(({ hidden, ...r }) => r);
  out.n = n;
  return out;
}

// ---------- Empfangen ----------
// Passender Einsatz (derselbe, Grund-Einsatz oder Unterabschnitt) – wie bei den Lage-Infos
export const progressTarget = (projects, f) => infoTarget(projects, f);

// Beziehung zum Absender: 'same' (gleicher Einsatz), 'base' (Absender ist mein Grund-Einsatz), 'ua' (Absender ist mein UA)
export function relation(p, f) {
  if (f.eid === p.eid) return 'same';
  if (p.parentEid && p.parentEid === f.eid) return 'base';
  if (f.pe && f.pe === p.eid) return 'ua';
  return '';
}

export const emptyRes = () => ({ fields: 0, ways: 0, items: 0, pois: 0, grids: 0, marks: 0, wind: 0, proto: 0, msgs: 0 });

// Ergänzt p um den Fortschritt f (ändert p) -> Zähler, bzw. null wenn f nicht zu p gehört
export function mergeProgress(p, f) {
  const rel = relation(p, f);
  if (!rel) return null;
  const res = emptyRes();
  const from = String(f.from || '');
  const sameBy = (x) => f.full || (from && x.by === from); // ganzer Stand (erneute Übergabe): jede Bearbeitung zählt, die neuere gewinnt
  // Sperre eines neu ankommenden Elements: vom Grund-Einsatz -> 'base', in den Grund-Einsatz -> keine
  const newLock = (l) => (rel === 'base' ? 'base' : rel === 'ua' ? '' : l || '');
  p.itemDel = p.itemDel || {};
  p.cellT = p.cellT || {};
  p.gridT = p.gridT || {};
  p.cellBy = p.cellBy || {};
  p.glock = p.glock || {};
  p.gown = p.gown || {};
  p.mission = p.mission || {};

  for (const m of Array.isArray(f.mk) ? f.mk : []) {
    if (m && m.id && (m.kind === 'team' || m.kind === 'status') && !p.marks.some((x) => x.id === m.id)) { p.marks.push({ ...m }); res.marks++; }
  }

  // Zeichnungen, Umrisse, Texte, Wege
  for (const x of Array.isArray(f.it) ? f.it : []) {
    if (!x || !x.id || p.itemDel[x.id]) continue;
    const inc = unpackItem(x);
    const old = p.items.find((i) => i.id === inc.id);
    const count = (it) => { if (it.resultKey || it.kind === 'track') res.ways++; else res.items++; };
    const keep = (o) => {
      const l = rel === 'same' ? inc.lock : o.lock; // bestehende Sperre bleibt
      const r = { ...inc };
      if (l) r.lock = l; else delete r.lock;
      if (o.hidden) r.hidden = true;
      return r;
    };
    // Weg derselben Rückmeldung unter anderer ID: nur die längere Fassung behalten
    const twin = inc.resultKey && p.items.find((i) => i.resultKey === inc.resultKey && i.id !== inc.id);
    if (twin) {
      if ((inc.pts || []).length > (twin.pts || []).length) { p.items[p.items.indexOf(twin)] = keep(twin); res.ways++; }
      continue;
    }
    if (!old) {
      const l = newLock(inc.lock);
      if (l) inc.lock = l; else delete inc.lock;
      p.items.push(inc);
      count(inc);
      continue;
    }
    let ok;
    if (rel === 'base') ok = old.lock === 'base' && sameBy(inc) && inc.t > (old.t || 0); // UA: eigene Sachen bleiben
    else if (rel === 'ua' && inc.lock === 'ua') ok = inc.t !== old.t || ihash(inc) !== ihash(old); // im UA-Gebiet entscheidet der UA
    else ok = sameBy(inc) && inc.t > (old.t || 0);
    if (ok && ihash(inc) !== ihash(old)) { p.items[p.items.indexOf(old)] = keep(old); count(inc); }
    else if (ok) old.t = inc.t;
  }

  // Raster und Felder
  for (const g of Array.isArray(f.g) ? f.g : []) {
    if (!g || !g.i || !Array.isArray(g.a)) continue;
    let loc = allGrids(p).find((x) => x.id === g.i);
    if (!loc) {
      const area = { north: g.a[0], south: g.a[1], west: g.a[2], east: g.a[3] };
      if (!p.area) Object.assign(p, { gridId: g.i, gridName: g.n || '', area, cellM: g.m, fills: {}, status: {} });
      else p.otherGrids.push({ id: g.i, name: g.n || '', area, cellM: g.m, fills: {}, status: {} });
      if (rel === 'base') p.glock[g.i] = 'base';
      p.gridT[g.i] = f.at || 0;
      loc = allGrids(p).find((x) => x.id === g.i);
      res.grids++;
    }
    const own = (k) => { // gehört das Feld im Absender dem UA?
      const l = g.l === 'ua' && (!Array.isArray(g.w) || g.w.includes(k));
      return l;
    };
    for (const [tag, src, dst] of [['f', g.f, loc.fills], ['s', g.s, loc.status]]) {
      for (const [k, v] of Object.entries(src || {})) {
        const [id, t] = Array.isArray(v) ? v : [v, 0];
        if (!(tag === 'f' && id === NO_TEAM) && !p.marks.some((m) => m.id === id) || !/^\d+,\d+$/.test(k)) continue;
        const ck = `${g.i}|${k}|${tag}`;
        const lt = p.cellT[ck] || 0;
        const cur = dst[k];
        let ok;
        if (rel === 'base') {
          const l = (p.glock[g.i] === 'ua' && (!Array.isArray(p.gown[g.i]) || p.gown[g.i].includes(k))) ? 'ua' : '';
          ok = cur === undefined || (l !== 'ua' && t > lt); // im UA-Gebiet entscheidet bei Konflikt der UA
        } else if (rel === 'ua' && own(k)) ok = cur !== id;
        else ok = cur === undefined || t > lt;
        if (cur === id) { if (t > lt) { p.cellT[ck] = t; p.cellBy[ck] = from; } continue; }
        if (!ok) continue;
        dst[k] = id;
        p.cellT[ck] = t;
        p.cellBy[ck] = from;
        res.fields++;
      }
    }
  }

  // Lage-Orte (wie mergeInfos, plus Sperren)
  const del = p.poiDel && typeof p.poiDel === 'object' ? p.poiDel : {};
  p.pois = p.pois || [];
  const inc = normalizePois((Array.isArray(f.po) ? f.po : []).map((a) => Array.isArray(a) && ({
    id: a[0], cat: a[1], lat: a[2], lon: a[3], name: a[4], desc: a[5], t: a[6], by: a[7] || '', lock: a[8] || '',
  })));
  for (const x of inc) {
    if (x.id in del) continue;
    const old = p.pois.find((y) => y.id === x.id);
    if (!old) {
      const l = newLock(x.lock);
      if (l) x.lock = l; else delete x.lock;
      p.pois.push(x);
      res.pois++;
      continue;
    }
    let ok;
    if (rel === 'base') ok = old.lock === 'base' && sameBy(x) && x.t > (old.t || 0);
    else if (rel === 'ua' && x.lock === 'ua') ok = x.t !== old.t;
    else ok = sameBy(x) && x.t > (old.t || 0);
    if (ok) {
      const l = rel === 'same' ? x.lock : old.lock;
      Object.assign(old, x);
      if (l) old.lock = l; else delete old.lock;
      res.pois++;
    }
  }
  // B-Ort: nur ergänzen
  if (f.me && !p.meet && Number.isFinite(f.me.lat) && Number.isFinite(f.me.lon)) {
    const l = newLock(f.me.lock);
    p.meet = { lat: f.me.lat, lon: f.me.lon, text: f.me.text || '', t: f.me.t || 0, by: f.me.by || '', ...(l ? { lock: l } : {}) };
    res.pois++;
  }

  // Protokoll: Wind-Messungen, Kräfte, Eckzeiten (nur Fehlendes), Aufträge, Rückmeldungen
  const wind = (p.mission.wind = p.mission.wind || []);
  const wk = (x) => `${x.t}|${x.src || ''}|${x.by || ''}`;
  const haveW = new Set(wind.map(wk));
  for (const x of Array.isArray(f.w) ? f.w : []) {
    if (x && Number.isFinite(x.t) && !haveW.has(wk(x))) { wind.push(x); haveW.add(wk(x)); res.wind++; }
  }
  wind.sort((a, b) => a.t - b.t);
  p.mission.forces = p.mission.forces || [];
  for (const x of Array.isArray(f.fo) ? f.fo : []) {
    if (x && x.org && !p.mission.forces.some((y) => y.org === x.org)) { p.mission.forces.push(x); res.proto++; }
  }
  p.mission.times = p.mission.times || {};
  for (const [k, v] of Object.entries(f.tm && typeof f.tm === 'object' ? f.tm : {})) {
    if (v && !p.mission.times[k]) { p.mission.times[k] = v; res.proto++; }
  }
  p.imported = p.imported || {};
  for (const [k, v] of Object.entries(f.im && typeof f.im === 'object' ? f.im : {})) if (!(k in p.imported)) p.imported[k] = v;
  p.sent = p.sent || [];
  for (const x of Array.isArray(f.se) ? f.se : []) {
    if (!x || !x.id) continue;
    const o = p.sent.find((y) => y.id === x.id);
    if (!o) { p.sent.push(x); res.proto++; } else {
      if ((x.last || 0) > (o.last || 0)) { Object.assign(o, { n: x.n, last: x.last, lastSum: x.lastSum }); res.proto++; }
      // Übernahme: früheste Zeit > 0 gewinnt; Zugehöriges (Items, Felder) ergänzen
      if (x.acc > 0 && !(o.acc > 0 && o.acc <= x.acc)) { o.acc = x.acc; res.proto++; }
      if (Array.isArray(x.items) && !o.items) o.items = x.items;
      if (x.cells && typeof x.cells === 'object' && !o.cells) o.cells = x.cells;
    }
  }
  // gelöschte Status-Meldungen ausblenden (Löschvermerke nur ergänzen)
  p.msgDel = p.msgDel || {};
  for (const [id, t] of Object.entries(f.md && typeof f.md === 'object' && !Array.isArray(f.md) ? f.md : {})) if (!p.msgDel[id]) p.msgDel[id] = Number(t) || Date.now();
  if (!p.live && Array.isArray(f.lv) && f.lv.length === 2 && isStatusUrl(f.lv[0]) && f.lv[1]) {
    p.live = { url: String(f.lv[0]), key: String(f.lv[1]), since: 0, ack: [], msgs: [] };
  }
  if (p.live && Array.isArray(f.ms)) {
    const before = p.live.msgs.length;
    p.live.msgs = mergeStatus(p.live.msgs, f.ms).slice(-500);
    res.msgs = Math.max(0, p.live.msgs.length - before);
  }
  p.updated = Date.now();
  return res;
}

// „12 Felder, 2 Wege, 3 Protokolleinträge“ bzw. leer, wenn nichts Neues dabei war
export function progressSummary(r) {
  const pl = (n, one, many) => n && `${n} ${n === 1 ? one : many}`;
  return [
    pl(r.fields, 'Feld', 'Felder'), pl(r.ways, 'Weg', 'Wege'), pl(r.items, 'Zeichnung', 'Zeichnungen'), pl(r.grids, 'Rastergebiet', 'Rastergebiete'),
    pl(r.pois, 'Lage-Ort', 'Lage-Orte'), pl(r.wind + r.proto, 'Protokolleintrag', 'Protokolleinträge'), pl(r.msgs, 'Status-Meldung', 'Status-Meldungen'),
  ].filter(bool).join(', ');
}

// Kurzbeschreibung eines Pakets vor dem Senden (Anzahl je Art)
export function progressPreview(f) {
  const cells = (f.g || []).reduce((a, g) => a + Object.keys(g.f || {}).length + Object.keys(g.s || {}).length, 0);
  const tr = (f.it || []).filter((x) => x.kind === 'track').length;
  return progressSummary({
    fields: cells, ways: tr, items: (f.it || []).length - tr, grids: 0, pois: (f.po || []).length + (f.me ? 1 : 0),
    wind: (f.w || []).length, proto: (f.fo || []).length + (f.se || []).length + (f.tm ? 1 : 0), msgs: (f.ms || []).length,
  });
}
