// v130: Zusatz zum laufenden Auftrag – die Einsatzleitung schickt Punkte, Umrisse, Zeichnungen, Lage-Orte, Raster
// oder den B-Ort über den Status-Server (Google Sheets) an einen Hundeführer, ohne neuen QR-Code.
// Technisch eine normale Nachricht der EL (s: 'el') mit Anhang z: ältere Apps zeigen wenigstens den Text,
// Lesebestätigung, „wichtig“ und Warteschlange ohne Netz funktionieren wie bei jeder Nachricht.
// Reine Logik ohne DOM, testbar.
import { buildElMsg } from './status.js';
import { packItem, unpackItem } from './share.js';
import { allGrids, gridLabel } from './store.js';

const r6 = (v) => Math.round(v * 1e6) / 1e6;
// Obergrenze für den Anhang (JSON-Zeichen); verschlüsselt und Base64 kommen ~40 % dazu, der Server nimmt 20 000
export const ZUSATZ_MAX = 12000;
export const POINT_COLOR = '#c62828';

const q = (s) => `„${s}“`;
const itemName = (it) => (it.kind === 'text' ? it.text : it.name) || (it.kind === 'track' ? 'Umriss' : it.kind === 'text' ? 'Punkt' : 'Zeichnung');
const itemWord = (it) => (it.kind === 'track' ? 'Umriss' : it.kind === 'text' ? 'Punkt' : 'Zeichnung');

// sel: { to, teamId?, itemIdx: [], poiIds: [], gridIds: [], meet: bool, points: [{ lat, lon, name, task? }], task, prio }
// task: was dort geschehen soll – hängt an jedem gesendeten Objekt (steht beim HF auf der Karte) und in der Nachricht.
// Ein Punkt kann eine eigene Aufgabe haben (points[].task).
// Liefert { msg, size, parts: ['Umriss „Nord 1“', …] } oder null (nichts ausgewählt)
export function buildZusatz(p, sel) {
  const z = {};
  const parts = [];
  const task = String(sel.task || '').trim().slice(0, 200);
  const items = [];
  for (const i of sel.itemIdx || []) {
    const it = p.items[i];
    const x = it && packItem(it, 3);
    if (!x) continue;
    if (task) x.d = task;
    items.push(x);
    parts.push(`${itemWord(it)} ${q(itemName(it))}`);
  }
  for (const pt of sel.points || []) {
    if (!Number.isFinite(pt.lat) || !Number.isFinite(pt.lon)) continue;
    const name = String(pt.name || 'Punkt').slice(0, 60);
    const own = String(pt.task || '').trim().slice(0, 200);
    const note = own || task;
    items.push(packItem({ kind: 'text', color: pt.color || POINT_COLOR, text: name, lat: pt.lat, lon: pt.lon, ...(note ? { note } : {}) }, 3));
    parts.push(`Punkt ${q(name)}${own && own !== task ? ` (${own})` : ''}`);
  }
  if (items.length) z.i = items;
  const pois = (p.pois || []).filter((x) => (sel.poiIds || []).includes(x.id));
  if (pois.length) {
    z.po = pois.map((x) => [x.id, x.cat, r6(x.lat), r6(x.lon), x.name || '', [task, x.desc || ''].filter(Boolean).join(' · ').slice(0, 200)]);
    for (const x of pois) parts.push(`Ort ${q(x.name || 'Lage-Ort')}`);
  }
  const grids = allGrids(p).filter((g) => (sel.gridIds || []).includes(g.id) && g.area);
  if (grids.length) {
    z.g = grids.map((g) => ({
      i: g.id, n: gridLabel(p, g), m: g.cellM,
      a: [r6(g.area.north), r6(g.area.south), r6(g.area.west), r6(g.area.east)],
      f: sel.teamId ? Object.keys(g.fills || {}).filter((k) => g.fills[k] === sel.teamId) : [],
    }));
    for (const g of grids) parts.push(`Raster ${q(gridLabel(p, g))}`);
  }
  if (sel.meet && p.meet) {
    z.mp = [r6(p.meet.lat), r6(p.meet.lon), p.meet.text || ''];
    parts.push('B-Ort');
  }
  if (!parts.length) return null;
  const msg = buildElMsg({ to: sel.to, txt: zusatzText(parts, task), prio: sel.prio });
  msg.z = z;
  return { msg, size: JSON.stringify(z).length, parts };
}

// Text der Nachricht (für alte App-Versionen und die Nachrichtenliste)
export function zusatzText(parts, task = '') {
  const what = parts.length > 3 ? `${parts.slice(0, 3).join(', ')} und ${parts.length - 3} weitere` : parts.join(', ');
  const n = String(task || '').trim();
  return `📍 Neu auf deiner Karte: ${what}${n ? `. Auftrag: ${n}` : ''}`.slice(0, 300);
}

// Ist es ein Zusatz (mit Anhang)?
export const isZusatz = (m) => !!m && m.s === 'el' && !!m.z && typeof m.z === 'object';

// Zusatz beim Hundeführer ins Suchgebiet übernehmen (zweimal schadet nicht). Liefert { added, pts } – pts = alle
// Koordinaten zum Hinzoomen – oder null, wenn die Nachricht keinen Zusatz trägt.
export function applyZusatz(p, m) {
  if (!isZusatz(m)) return null;
  const z = m.z;
  const pts = [];
  let added = 0;
  // Zeichnungen, Umrisse, Punkte: einmal je Nachricht (zid), schreibgeschützt wie Auftragsinhalte (fromEl)
  if (Array.isArray(z.i) && !(p.items || []).some((it) => it.zid === m.id)) {
    for (const x of z.i) {
      let it;
      try { it = unpackItem(x, { fromEl: true, zid: m.id }); } catch { continue; }
      if (it.kind === 'text') pts.push([it.lat, it.lon]); else pts.push(...(it.pts || []));
      p.items.push(it);
      added++;
    }
  } else if (Array.isArray(z.i)) {
    for (const it of p.items.filter((x) => x.zid === m.id)) { if (it.kind === 'text') pts.push([it.lat, it.lon]); else pts.push(...(it.pts || [])); }
  }
  // Lage-Orte: gleiche ID = aktualisieren (z. B. verschobener Treffpunkt)
  if (Array.isArray(z.po)) {
    p.pois = p.pois || [];
    for (const [id, cat, lat, lon, name, desc] of z.po) {
      if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
      const o = { id, cat, lat, lon, name, desc, t: m.t, by: 'Einsatzleitung' };
      const k = p.pois.findIndex((x) => x.id === id);
      if (k >= 0) p.pois[k] = { ...p.pois[k], ...o }; else { p.pois.push(o); added++; }
      pts.push([lat, lon]);
    }
  }
  // Raster: zusätzlich anzeigen (Felder des Teams hervorgehoben); ein schon vorhandenes Raster bleibt, wie es ist
  if (Array.isArray(z.g)) {
    const have = new Set(allGrids(p).map((g) => g.id));
    for (const g of z.g) {
      const area = { north: g.a[0], south: g.a[1], west: g.a[2], east: g.a[3] };
      pts.push([area.north, area.west], [area.south, area.east]);
      if (have.has(g.i)) continue;
      const grid = { id: g.i, name: g.n, area, cellM: g.m, fills: Object.fromEntries((g.f || []).map((k) => [k, 'team'])), status: {} };
      if (!p.area) Object.assign(p, { gridId: grid.id, gridName: grid.name, area: grid.area, cellM: grid.cellM, fills: grid.fills, status: grid.status });
      else (p.otherGrids = p.otherGrids || []).push(grid);
      added++;
    }
  }
  if (Array.isArray(z.mp) && Number.isFinite(z.mp[0]) && Number.isFinite(z.mp[1])) {
    p.meet = { lat: z.mp[0], lon: z.mp[1], text: z.mp[2] || '' };
    pts.push([z.mp[0], z.mp[1]]);
    added++;
  }
  return { added, pts };
}
