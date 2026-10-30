// Lage-Infos von einem anderen Gerät (z. B. ELW) an die Einsatzleitung: #i=…
// Die Infos ERGÄNZEN nur – löschen kann allein der Empfänger (Einsatzleiter) selbst:
// - neue Lage-Orte kommen dazu (feste IDs, mehrfach scannen schadet nicht),
// - geänderte werden nur übernommen, wenn der Absender sie zuletzt bearbeitet hat (sein eigener Eintrag),
// - was der Empfänger gelöscht hat, kommt nicht wieder (Löschvermerk poiDel),
// - Kontakte (optional) werden nur ergänzt, nie überschrieben.
import { compactContact, fromCompact } from './contacts.js';
import { normalizePois } from './pois.js';

const r6 = (v) => Math.round(v * 1e6) / 1e6;

// Lage-Ort löschen und merken, damit ihn spätere Infos nicht wieder anlegen
export function deletePoi(p, poi, now = Date.now()) {
  p.pois = (p.pois || []).filter((x) => x !== poi && x.id !== poi.id);
  if (!p.poiDel || typeof p.poiDel !== 'object') p.poiDel = {};
  p.poiDel[poi.id] = Math.max(p.poiDel[poi.id] || 0, now);
}

export function buildInfos(p, { from = '', contacts = false } = {}, now = Date.now()) {
  const out = {
    k: 'i', v: 1, eid: p.eid || p.id, ti: p.title || '', from, at: now,
    po: (p.pois || []).map((x) => [x.id, x.cat, r6(x.lat), r6(x.lon), x.name || '', x.desc || '', x.t || 0, x.by || '']),
  };
  if (contacts && (p.contacts || []).length) out.ct = p.contacts.map(compactContact);
  return out;
}

// Ergänzt p um die Infos (ändert p) -> { added, changed, contacts }
export function mergeInfos(p, inf) {
  const res = { added: 0, changed: 0, contacts: 0 };
  const del = p.poiDel && typeof p.poiDel === 'object' ? p.poiDel : {};
  p.pois = p.pois || [];
  const from = String(inf.from || '');
  const inc = normalizePois((Array.isArray(inf.po) ? inf.po : []).map((a) => Array.isArray(a) && ({
    id: a[0], cat: a[1], lat: a[2], lon: a[3], name: a[4], desc: a[5], t: a[6], by: a[7] || '',
  })));
  for (const x of inc) {
    if (x.id in del) continue;
    const old = p.pois.find((y) => y.id === x.id);
    if (!old) { p.pois.push(x); res.added++; continue; }
    // nur eigene Einträge des Absenders aktualisieren, nichts vom Empfänger überschreiben
    if (from && old.by === from && x.by === from && x.t > (old.t || 0)) { Object.assign(old, x); res.changed++; }
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

// „3 neu, 1 geändert, 2 Kontakte“ bzw. leer, wenn nichts Neues dabei war
export function infoSummary(r) {
  return [
    r.added && `${r.added} neu`, r.changed && `${r.changed} geändert`,
    r.contacts && `${r.contacts} Kontakt${r.contacts === 1 ? '' : 'e'}`,
  ].filter(Boolean).join(', ');
}
