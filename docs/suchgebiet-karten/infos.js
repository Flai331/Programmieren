// Lage-Infos zwischen Geräten der Einsatzleitung abgleichen (ELW <-> EL, beide Richtungen): #i=…
// Es geht immer der ganze Stand der Lage-Orte mit (plus Löschvermerke), der Empfänger führt zusammen:
// feste IDs + Änderungszeit, Neueres gewinnt, gelöschte verschwinden auch beim Empfänger.
// Mehrfach scannen schadet nicht. Kontakte (optional) werden nur ergänzt, nie überschrieben.
import { compactContact, fromCompact } from './contacts.js';
import { normalizePois } from './pois.js';

const r6 = (v) => Math.round(v * 1e6) / 1e6;

// Lage-Ort löschen und merken, damit das Löschen beim Abgleich mitgeht
export function deletePoi(p, poi, now = Date.now()) {
  p.pois = (p.pois || []).filter((x) => x !== poi && x.id !== poi.id);
  if (!p.poiDel || typeof p.poiDel !== 'object') p.poiDel = {};
  p.poiDel[poi.id] = Math.max(p.poiDel[poi.id] || 0, now);
}

export function buildInfos(p, { from = '', contacts = false } = {}, now = Date.now()) {
  const out = {
    k: 'i', v: 1, eid: p.eid || p.id, ti: p.title || '', from, at: now,
    po: (p.pois || []).map((x) => [x.id, x.cat, r6(x.lat), r6(x.lon), x.name || '', x.desc || '', x.t || 0, x.by || '']),
    dl: Object.entries(p.poiDel || {}),
  };
  if (contacts && (p.contacts || []).length) out.ct = p.contacts.map(compactContact);
  return out;
}

// Führt die Infos in p zusammen (ändert p) -> { added, changed, removed, contacts }
export function mergeInfos(p, inf) {
  const res = { added: 0, changed: 0, removed: 0, contacts: 0 };
  if (!p.poiDel || typeof p.poiDel !== 'object') p.poiDel = {};
  p.pois = p.pois || [];
  for (const [id, t] of Array.isArray(inf.dl) ? inf.dl : []) {
    if (typeof id !== 'string' || !(Number(t) > 0)) continue;
    const i = p.pois.findIndex((x) => x.id === id);
    if (i >= 0 && (p.pois[i].t || 0) <= t) { p.pois.splice(i, 1); res.removed++; }
    p.poiDel[id] = Math.max(p.poiDel[id] || 0, Number(t));
  }
  const inc = normalizePois((Array.isArray(inf.po) ? inf.po : []).map((a) => Array.isArray(a) && ({
    id: a[0], cat: a[1], lat: a[2], lon: a[3], name: a[4], desc: a[5], t: a[6], by: a[7] || '',
  })));
  for (const x of inc) {
    const old = p.pois.find((y) => y.id === x.id);
    if (old) {
      if (x.t > (old.t || 0)) { Object.assign(old, x); res.changed++; }
    } else if (!(x.id in p.poiDel) || p.poiDel[x.id] < x.t) {
      p.pois.push(x);
      res.added++;
    }
  }
  const key = (c) => `${c.name.toLowerCase()}|${c.phone.replace(/\D/g, '')}`;
  const have = new Set((p.contacts || []).map(key));
  for (const a of Array.isArray(inf.ct) ? inf.ct : []) {
    const c = fromCompact(a);
    if (!c.name || have.has(key(c))) continue;
    have.add(key(c));
    p.contacts = [...(p.contacts || []), c];
    res.contacts++;
  }
  return res;
}

// „3 neu, 1 geändert, 1 gelöscht, 2 Kontakte“ bzw. leer, wenn nichts Neues dabei war
export function infoSummary(r) {
  return [
    r.added && `${r.added} neu`, r.changed && `${r.changed} geändert`, r.removed && `${r.removed} gelöscht`,
    r.contacts && `${r.contacts} Kontakt${r.contacts === 1 ? '' : 'e'}`,
  ].filter(Boolean).join(', ');
}
