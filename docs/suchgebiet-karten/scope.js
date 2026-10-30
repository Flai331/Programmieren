// Umfang beim Weitergeben: ganzer Einsatz, ein Team, ein Gebiet oder eigene Auswahl.
// Auswahl sel = { items: Set(Element aus p.items), pois: Set(Lage-Ort), meet: bool,
//                 cells: Map(Raster-ID -> Set("c,r")), edges: Set(Raster-ID) }
import { allGrids, newProject, normalizeProject, uid } from './store.js';

export function emptySel() {
  return { items: new Set(), pois: new Set(), meet: false, cells: new Map(), edges: new Set() };
}

function addCells(sel, id, keys) {
  if (!sel.cells.has(id)) sel.cells.set(id, new Set());
  const set = sel.cells.get(id);
  for (const k of keys) set.add(k);
}

// Alles: alle Zeichnungen, Lage-Orte, B-Ort, alle eingefärbten Felder und alle Rasterränder
export function selectAll(p) {
  const sel = emptySel();
  for (const it of p.items) if (!it.hidden) sel.items.add(it);
  for (const x of p.pois || []) sel.pois.add(x);
  sel.meet = !!p.meet;
  for (const g of allGrids(p)) {
    sel.edges.add(g.id);
    addCells(sel, g.id, new Set([...Object.keys(g.fills || {}), ...Object.keys(g.status || {})]));
  }
  return sel;
}

// Ein Team: seine Felder (mit Rasterrand), die ihm zugeteilten Umrisse, B-Ort und alle Lage-Orte
export function selectTeam(p, teamId) {
  const sel = emptySel();
  for (const it of p.items) if (it.to === teamId) sel.items.add(it);
  for (const g of allGrids(p)) {
    const keys = Object.keys(g.fills || {}).filter((k) => g.fills[k] === teamId);
    if (!keys.length) continue;
    sel.edges.add(g.id);
    addCells(sel, g.id, keys);
  }
  for (const x of p.pois || []) sel.pois.add(x);
  sel.meet = !!p.meet;
  return sel;
}

// Kurzbeschreibung für das Fenster, z. B. „2 Umrisse · 1 Text · 6 Felder · B-Ort · 3 Lage-Orte“
export function selSummary(p, sel) {
  const n = (k) => [...sel.items].filter((it) => it.kind === k).length;
  const cells = [...sel.cells.values()].reduce((a, s) => a + s.size, 0);
  const pl = (x, one, many) => `${x} ${x === 1 ? one : many}`;
  const parts = [];
  if (sel.edges.size) parts.push(pl(sel.edges.size, 'Rastergebiet', 'Rastergebiete'));
  if (cells) parts.push(pl(cells, 'Feld', 'Felder'));
  if (n('track')) parts.push(pl(n('track'), 'Umriss', 'Umrisse'));
  if (n('stroke')) parts.push(pl(n('stroke'), 'Strich', 'Striche'));
  if (n('text')) parts.push(pl(n('text'), 'Text', 'Texte'));
  if (sel.meet && p.meet) parts.push('B-Ort');
  if (sel.pois.size) parts.push(pl(sel.pois.size, 'Lage-Ort', 'Lage-Orte'));
  return parts.join(' · ');
}

export function selCount(sel) {
  return sel.items.size + sel.pois.size + (sel.meet ? 1 : 0) + sel.edges.size
    + [...sel.cells.values()].reduce((a, s) => a + s.size, 0);
}

// Teil-Einsatz (PDF) bzw. Unterabschnitt für ein weiteres Gerät der Einsatzleitung (ELW): nur das Ausgewählte.
// Rastergebiete mit Rand oder Feldern bleiben (mit nur den ausgewählten Feldfarben),
// Stammdaten (Einsatzleitung, Funk, Kontakte, Person, Zeiten) gehen mit,
// Notizen, Notizblock, Fotos, Aufträge und Bericht nicht. Neue Einsatz-ID: eigener Einsatz.
// base: Unterabschnitt – nur das ausgewählte Gebiet, aber alle übrigen Daten des Grund-Einsatzes
// (B-Ort, alle Lage-Orte, Einsatzprotokoll, Notizen); parentEid verbindet ihn mit dem Grund-Einsatz.
export function subsetProject(p, sel, title, { base = false } = {}) {
  const keep = (g) => sel.edges.has(g.id) || (sel.cells.get(g.id) || new Set()).size > 0;
  const pick = (map, id) => {
    const set = sel.cells.get(id) || new Set();
    return Object.fromEntries(Object.entries(map || {}).filter(([k]) => set.has(k)));
  };
  // UA (base): alle Rastergebiete mit allen Feldern – das Ausgewählte gehört dem UA, der Rest bleibt gesperrt
  const grids = allGrids(p).filter((g) => base || keep(g)).map((g) => ({
    id: g.id, name: g.name || '', area: { ...g.area }, cellM: g.cellM,
    fills: base ? { ...g.fills } : pick(g.fills, g.id), status: base ? { ...g.status } : pick(g.status, g.id),
  }));
  const clone = (x) => JSON.parse(JSON.stringify(x));
  const q = newProject(title);
  q.id = uid();
  q.eid = q.id;
  Object.assign(q, {
    leader: p.leader, lead: clone(p.lead || {}), radio: clone(p.radio || []), contacts: clone(p.contacts || []),
    layerId: p.layerId, showUtm: p.showUtm, view: p.view ? { ...p.view } : null, markAlpha: p.markAlpha,
    marks: clone(p.marks),
    items: clone(p.items.filter((it) => sel.items.has(it))),
    pois: clone((p.pois || []).filter((x) => sel.pois.has(x))),
    meet: sel.meet && p.meet ? { ...p.meet } : null,
  });
  q.mission.person = (p.mission && p.mission.person) || '';
  q.mission.times = clone((p.mission && p.mission.times) || {});
  if (base) {
    Object.assign(q, {
      pois: clone(p.pois || []), meet: p.meet ? { ...p.meet } : null, notes: p.notes || '',
      mission: clone(p.mission || q.mission), parentEid: p.eid || p.id, parentTitle: p.title || '',
      items: clone(p.items), itemDel: clone(p.itemDel || {}), cellT: clone(p.cellT || {}), gridT: clone(p.gridT || {}),
    });
    // gleicher Status-Schlüssel und Aufträge wie der Grund-Einsatz: der UA liest alle Meldungen mit
    if (p.live) q.live = { ...clone(p.live), since: 0 };
    if ((p.sent || []).length) q.sent = clone(p.sent);
    // Sperren: Ausgewähltes = 'ua' (bearbeitbar, nicht löschbar), alles andere = 'base' (nur ansehen)
    q.items.forEach((it, i) => { it.lock = sel.items.has(p.items[i]) ? 'ua' : 'base'; });
    q.pois.forEach((x, i) => { x.lock = sel.pois.has(p.pois[i]) ? 'ua' : 'base'; });
    if (q.meet) q.meet.lock = sel.meet ? 'ua' : 'base';
    q.glock = {};
    q.gown = {};
    for (const g of allGrids(p)) {
      q.glock[g.id] = keep(g) ? 'ua' : 'base';
      if (!sel.edges.has(g.id) && keep(g)) q.gown[g.id] = [...(sel.cells.get(g.id) || [])]; // nur einzelne Felder
    }
  }
  if (grids.length) {
    const [first, ...rest] = grids;
    Object.assign(q, { gridId: first.id, gridName: first.name, area: first.area, cellM: first.cellM, fills: first.fills, status: first.status, otherGrids: rest });
  }
  return normalizeProject(q);
}
