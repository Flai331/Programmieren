// Suchgebiete (Projekte), Teams/Markierungen und Datei-Austausch.
// Reine Logik ohne DOM, damit sie testbar ist.

import { newMission, normalizeMission } from './mission.js';
import { normalizeContact } from './contacts.js';
import { rangeLabel } from './grid.js';
import { normalizePois } from './pois.js';

export const TEAM_COLORS = ['#d50000', '#1565c0', '#ef6c00', '#6a1b9a', '#00838f', '#ad1457', '#4e342e', '#558b2f'];
// v107: „ohne Team“ ist fest Dunkelgrau (Umrisse und Felder); Grau gibt es nicht mehr als Team-/Markierungsfarbe
export const NO_TEAM_COLOR = '#616161';
// reservierte Team-ID in fills: Feld gehört zum Suchgebiet, ist aber noch keinem Team zugeteilt
export const NO_TEAM = '-';
export const MARK_COLORS = [...new Set([...TEAM_COLORS, '#f06292', '#00c853', '#2e7d32', '#fdd835', '#000000'])];

export function uid() {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
}

export function defaultMarks() {
  return [
    { id: uid(), kind: 'status', label: 'abgesucht', color: '#00c853' },
    { id: uid(), kind: 'status', label: 'teilweise abgesucht', color: '#fdd835' },
    { id: uid(), kind: 'status', label: 'nicht begehbar', color: '#616161' },
  ];
}

export function newProject(title = '') {
  const now = Date.now();
  return {
    id: uid(),
    title,
    leader: '',
    notes: '',
    caption: '', // Beschriftung auf dem PDF-Blatt
    created: now,
    updated: now,
    layerId: 'topplus',
    cellM: 100,
    area: null,
    fills: {}, // "c,r" -> Team-ID (bleibt, auch wenn das Feld abgesucht ist)
    status: {}, // "c,r" -> Status-ID (abgesucht, teilweise …), zusätzlich zum Team
    // Mehrere Rastergebiete: area/cellM/fills/status oben gehören zum gerade bearbeiteten,
    // die übrigen liegen in otherGrids [{ id, name, area, cellM, fills, status }]
    gridId: '',
    gridName: '',
    otherGrids: [],
    marks: defaultMarks(),
    items: [],
    meet: null, // {lat, lon, text}
    lead: { name: '', phone: '', call: '', elw: '' }, // Einsatzleitung: Name, Handy, Funkrufname EL, Funkrufname ELW
    radio: [], // weitere Funkrufnamen [{ call, who }]
    contacts: [], // Kontakte dieses Einsatzes (Kopien aus dem Adressbuch), gehen auf Wunsch mit dem Auftrag
    pois: [], // Lage-Orte (ELW-Infos)
    poiDel: {}, // gelöschte Lage-Orte { id: Zeit } für den Abgleich zwischen Geräten
    msgSeen: {}, msgRecv: {}, msgSnooze: 0, // v98 (nur dieses Gerät)
    msgDel: {}, // v95: gelöschte Status-Meldungen { id: Zeit }
    eid: '', // Einsatz-ID über Geräte hinweg (Übergabe Handy -> Tablet)
    // v90: Fortschritt senden (progress.js) und UA-Sperren (locks.js)
    itemDel: {}, // gelöschte Zeichnungen { id: Zeit } – blockieren Wiederanlegen durch Fortschritt
    cellBy: {}, // von welchem Gerät das Feld zuletzt ankam { Schlüssel: Name } (geht nicht zurück)
    cellT: {}, // Änderungszeit je Feld { "Raster|c,r|f" (Team) bzw. "|s" (Status): Zeit }
    gridT: {}, // Änderungszeit je Rastergebiet { Raster-ID: Zeit }
    glock: {}, gown: {}, // Sperren je Rastergebiet (nur im Unterabschnitt)
    peers: [], // Empfänger von „Fortschritt senden“: [{ name, lastSent }]
    showUtm: false,
    view: null,
    mission: newMission(), // Einsatzprotokoll
  };
}

// Leeres Suchgebiet ohne eigene Angaben („freie Karte“) – darf wiederverwendet werden
export function isBlankProject(p) {
  const m = p.mission || {};
  return !p.title && !p.area && !(p.items || []).length && !(p.otherGrids || []).length && !p.meet && !p.closed
    && !p.notes && !(p.contacts || []).length && !(p.pois || []).length
    && !m.person && !Object.keys(m.times || {}).length && !(m.forces || []).length
    && !(m.pages || []).length && !(m.photos || []).length && !m.summary;
}

// Fehlende Felder ergänzen (ältere Dateien, Importe)
export function normalizeProject(p) {
  const base = newProject();
  const out = { ...base, ...p };
  if (!Array.isArray(out.marks)) out.marks = base.marks;
  if (!Array.isArray(out.items)) out.items = [];
  out.mission = normalizeMission(out.mission);
  out.lead = { ...base.lead, ...(out.lead && typeof out.lead === 'object' ? out.lead : {}) };
  if (!out.lead.name && out.leader) out.lead.name = out.leader;
  for (const k of ['radio', 'contacts', 'pois']) if (!Array.isArray(out[k])) out[k] = [];
  out.pois = normalizePois(out.pois);
  if (!out.poiDel || typeof out.poiDel !== 'object' || Array.isArray(out.poiDel)) out.poiDel = {};
  if (!out.msgDel || typeof out.msgDel !== 'object' || Array.isArray(out.msgDel)) out.msgDel = {};
  // v98: ungelesene Status-Meldungen – nur dieses Gerät: msgSeen/msgRecv { id: Zeit }, msgSnooze = Erinnerung ruht bis (ms)
  for (const k of ['msgSeen', 'msgRecv']) {
    const o = out[k] && typeof out[k] === 'object' && !Array.isArray(out[k]) ? out[k] : {};
    out[k] = Object.fromEntries(Object.entries(o).filter(([, t]) => Number.isFinite(Number(t))).map(([i, t]) => [i, Number(t)]));
  }
  out.msgSnooze = Number(out.msgSnooze) > 0 ? Number(out.msgSnooze) : 0;
  // v95: Aufträge – acc = Zeit der Übernahme (ältere Aufträge gelten als übernommen), items/cells = was zum Auftrag gehört
  if (Array.isArray(out.sent)) {
    out.sent = out.sent.filter((x) => x && x.id).map((x) => {
      const y = { ...x, acc: x.acc === undefined ? Number(x.at) || 0 : Number(x.acc) || 0 };
      if (!Array.isArray(y.items)) delete y.items;
      if (!y.cells || typeof y.cells !== 'object' || Array.isArray(y.cells)) delete y.cells;
      if (!(Number(y.unlock) > 0)) delete y.unlock;
      return y;
    });
  }
  out.contacts = out.contacts.map(normalizeContact);
  if (!out.eid) out.eid = out.id;
  // v90: Zeichnungen bekommen feste ID, Änderungszeit (t) und Gerät (by); Sperren (lock) nur 'base' | 'ua'
  for (const k of ['itemDel', 'cellT', 'cellBy', 'gridT', 'glock', 'gown']) if (!out[k] || typeof out[k] !== 'object' || Array.isArray(out[k])) out[k] = {};
  out.peers = (Array.isArray(out.peers) ? out.peers : []).filter((x) => x && typeof x.name === 'string' && x.name).map((x) => ({ name: x.name, lastSent: Number(x.lastSent) || 0 }));
  out.items = out.items.map((it) => {
    const x = { ...it, id: it.id || uid(), t: Number(it.t) || out.updated || Date.now(), by: String(it.by || '') };
    if (x.lock !== 'base' && x.lock !== 'ua') delete x.lock;
    return x;
  });
  if (out.meet && typeof out.meet === 'object' && !out.meet.t) out.meet = { ...out.meet, t: out.updated || Date.now() };
  // v89: Status-Meldungen – EL: live { url, key, since, ack, msgs }, HF: hf.ls = [url, key], Warteschlange hf.outbox, eigene Meldungen hf.log
  if (out.live && typeof out.live === 'object' && out.live.url && out.live.key) {
    const l = out.live;
    out.live = { url: String(l.url), key: String(l.key), since: Number(l.since) || 0, ack: Array.isArray(l.ack) ? l.ack : [], msgs: Array.isArray(l.msgs) ? l.msgs.slice(-500) : [] };
  } else delete out.live;
  out.qmsgs = Array.isArray(out.qmsgs) ? out.qmsgs.slice(-500) : []; // Status-Meldungen aus QR-Rückmeldungen
  if (out.hf && typeof out.hf === 'object') {
    out.hf = { ...out.hf };
    if (!(Array.isArray(out.hf.ls) && out.hf.ls.length === 2 && out.hf.ls.every((x) => typeof x === 'string' && x))) delete out.hf.ls;
    for (const k of ['outbox', 'log']) if (!Array.isArray(out.hf[k])) out.hf[k] = [];
    out.hf.log = out.hf.log.slice(-100);
  }
  // v61: „Treffpunkt“ heißt jetzt „B-Ort“
  if (out.meet && out.meet.text === 'Treffpunkt') out.meet = { ...out.meet, text: 'B-Ort' };
  // v31: nur „Raster ausblenden“ -> allgemeine Anzeige-Schalter
  if (!out.hide || typeof out.hide !== 'object') out.hide = out.hideGrid ? { grid: true } : {};
  delete out.hide.marks; // v32: Gruppen-Schalter, jetzt je Team/Zeichnung (m.hidden / it.hidden)
  delete out.hide.items;
  delete out.hideGrid;
  if (!out.fills || typeof out.fills !== 'object') out.fills = {};
  if (!out.status || typeof out.status !== 'object') out.status = {};
  out.fills = { ...out.fills };
  out.status = { ...out.status };
  // v107: ein Team mit der Farbe „ohne Team“ (Grau) bekommt die erste freie Teamfarbe; seine Umrisse ziehen mit
  const greyTeams = out.marks.filter((m) => m.kind === 'team' && String(m.color).toLowerCase() === NO_TEAM_COLOR);
  if (greyTeams.length) {
    const used = new Set(out.marks.map((m) => String(m.color).toLowerCase()));
    out.marks = out.marks.map((m) => (greyTeams.includes(m) ? { ...m, color: MARK_COLORS.find((c) => !used.has(c)) || MARK_COLORS[0] } : m));
    const newColor = Object.fromEntries(greyTeams.map((m) => [m.id, out.marks.find((x) => x.id === m.id).color]));
    out.items = out.items.map((it) => (it.to && newColor[it.to] ? { ...it, color: newColor[it.to] } : it));
  }
  const kind = Object.fromEntries(out.marks.map((m) => [m.id, m.kind]));
  kind[NO_TEAM] = 'team';
  // Ältere Stände hatten Team und Status in einem Feld: Status-Einträge umziehen
  for (const k of Object.keys(out.fills)) {
    if (kind[out.fills[k]] === 'status' && !out.status[k]) out.status[k] = out.fills[k];
    if (kind[out.fills[k]] !== 'team') delete out.fills[k];
  }
  for (const k of Object.keys(out.status)) if (kind[out.status[k]] !== 'status') delete out.status[k];
  if (!out.gridId) out.gridId = uid();
  out.otherGrids = (Array.isArray(out.otherGrids) ? out.otherGrids : [])
    .filter((g) => g && g.area)
    .map((g) => ({
      id: g.id || uid(),
      name: String(g.name || ''),
      area: g.area,
      cellM: Number(g.cellM) || 100,
      fills: Object.fromEntries(Object.entries(g.fills || {}).filter(([, id]) => kind[id] === 'team')),
      status: Object.fromEntries(Object.entries(g.status || {}).filter(([, id]) => kind[id] === 'status')),
    }));
  return out;
}

// ---------- Mehrere Rastergebiete ----------
// Alle Rastergebiete, nach Namen sortiert („Gebiet 2“ vor „Gebiet 10“); active = gerade bearbeitet
export function allGrids(p) {
  const own = p.area ? [{ id: p.gridId, name: p.gridName || '', area: p.area, cellM: p.cellM, fills: p.fills, status: p.status, active: true }] : [];
  return [...own, ...(p.otherGrids || []).map((g) => ({ ...g, active: false }))]
    .sort((a, b) => gridLabel(p, a).localeCompare(gridLabel(p, b), 'de', { numeric: true }));
}

// Anzeigename; das erste (ältere Stände: einzige) Gebiet heißt ohne Namen „Gebiet 1“
export function gridLabel(p, g) {
  return g.name || 'Gebiet 1';
}
function nextGridName(p) {
  const used = allGrids(p).map((g) => gridLabel(p, g));
  let n = 1;
  while (used.includes(`Gebiet ${n}`)) n++;
  return `Gebiet ${n}`;
}

function parkActive(p) {
  if (p.area) {
    p.otherGrids = [...(p.otherGrids || []), { id: p.gridId, name: p.gridName || '', area: p.area, cellM: p.cellM, fills: p.fills, status: p.status }];
  }
}

// Ein anderes Rastergebiet zum Bearbeiten holen
export function activateGrid(p, id) {
  if (id === p.gridId && p.area) return;
  const g = (p.otherGrids || []).find((x) => x.id === id);
  if (!g) return;
  parkActive(p);
  p.otherGrids = p.otherGrids.filter((x) => x.id !== id);
  Object.assign(p, { gridId: g.id, gridName: g.name, area: g.area, cellM: g.cellM, fills: g.fills, status: g.status });
}

// Neues, noch leeres Rastergebiet (Fläche wird danach aufgezogen)
export function startNewGrid(p) {
  const name = nextGridName(p);
  parkActive(p);
  Object.assign(p, { gridId: uid(), gridName: name, area: null, fills: {}, status: {} });
}

// Bearbeitetes Rastergebiet löschen; das nächste wird aktiv
export function removeActiveGrid(p) {
  Object.assign(p, { area: null, fills: {}, status: {}, gridName: '' });
  p.gridId = uid();
  const next = (p.otherGrids || [])[0];
  if (next) activateGrid(p, next.id);
}

// Projekt-Ansicht mit nur einem Rastergebiet (für PDF/GPX je Gebiet)
export function gridView(p, g) {
  return { ...p, gridId: g.id, gridName: g.name, area: g.area, cellM: g.cellM, fills: g.fills, status: g.status, otherGrids: [] };
}

// Version 1 speicherte nur ein Gebiet mit Farben statt Markierungen
export function migrateV1(old) {
  const p = newProject(old.title || '');
  Object.assign(p, {
    layerId: old.layerId || 'topplus',
    cellM: old.cellM || 100,
    area: old.area || null,
    items: old.items || [],
    view: old.view || null,
  });
  const byColor = {};
  let n = 1;
  for (const [key, color] of Object.entries(old.fills || {})) {
    if (!byColor[color]) {
      const m = { id: uid(), kind: 'status', label: `Markierung ${n++}`, color };
      p.marks.push(m);
      byColor[color] = m.id;
    }
    p.status[key] = byColor[color];
  }
  return p;
}

// v107: geschlossener Umriss ohne Team ist immer Dunkelgrau (+ gestrichelt); mit Team, offene Linien,
// Stände vom Grund-Einsatz (gedämpft) und Items vom EL/Vorgänger bleiben in ihrer Farbe.
// grey = false: Hundeführer-Gerät, dort bleibt alles wie bisher
export function isNoTeamOutline(it, grey = true) {
  return grey && it.kind === 'track' && !it.open && !it.to && !it.fromEl && !it.prev && it.color !== '#9e9e9e';
}
export function outlineColor(it, grey = true) {
  return isNoTeamOutline(it, grey) ? NO_TEAM_COLOR : it.color;
}
// Umriss zugeteilt an ein Team (it.to = Team-ID) oder eine Einheit aus den Kräften (it.to = 'u:Name')
export function assignTargets(p) {
  const teams = p.marks.filter((m) => m.kind === 'team').map((m) => ({ to: m.id, label: markLabel(m) || 'Team', color: m.color }));
  const orgs = [...new Set(((p.mission && p.mission.forces) || []).map((f) => String(f.org || '').trim()).filter(Boolean))];
  return [...teams, ...orgs.map((o) => ({ to: `u:${o}`, label: o, color: null }))];
}
export function assigneeName(p, to) {
  if (!to || to === NO_TEAM) return '';
  if (to.startsWith('u:')) return to.slice(2);
  const m = p.marks.find((x) => x.id === to && x.kind === 'team');
  return m ? m.label : '';
}

export function markLabel(m) {
  if (m.kind !== 'team') return m.label;
  const h = m.helpers > 0 ? ` + ${m.helpers} Suchhelfer` : '';
  return `${m.label}${m.dog ? ` (${m.dog})` : ''}${h}`;
}

// Feldzuordnung, in der eine Markierung steht: Teams in fills, alles andere in status
export function mapFor(p, m) {
  return m.kind === 'team' ? p.fills : p.status;
}

// "c,r" -> Farbe (für die Darstellung); which = 'fills' (Teams) oder 'status'
export function resolveFills(p, which = 'fills') {
  const color = Object.fromEntries(p.marks.map((m) => [m.id, m.color]));
  color[NO_TEAM] = NO_TEAM_COLOR;
  const out = {};
  for (const [k, id] of Object.entries(p[which] || {})) if (color[id]) out[k] = color[id];
  return out;
}

// Zerlegt eine Feldmenge in möglichst große Rechtecke (für "A1–C3, D5")
export function cellRects(keys) {
  const set = new Set(keys);
  const cells = [...set].map((k) => k.split(',').map(Number)).sort((a, b) => a[1] - b[1] || a[0] - b[0]);
  const rects = [];
  for (const [c, r] of cells) {
    if (!set.has(`${c},${r}`)) continue;
    let c1 = c;
    while (set.has(`${c1 + 1},${r}`)) c1++;
    let r1 = r;
    const rowFull = (rr) => {
      for (let x = c; x <= c1; x++) if (!set.has(`${x},${rr}`)) return false;
      return true;
    };
    while (rowFull(r1 + 1)) r1++;
    for (let y = r; y <= r1; y++) for (let x = c; x <= c1; x++) set.delete(`${x},${y}`);
    rects.push({ c0: c, r0: r, c1, r1 });
  }
  return rects;
}

export function cellsText(keys) {
  return cellRects(keys).map((q) => rangeLabel(q.c0, q.r0, q.c1, q.r1)).join(', ');
}

// Mehrere Rastergebiete: Feldtexte je Gebiet mit Namen davor („Nord: A1–B2; Süd: C3“)
function perGrid(p, fn) {
  const grids = allGrids(p);
  if (grids.length < 2) return fn(p.fills, p.status, '');
  const parts = grids.map((g) => fn(g.fills, g.status, `${gridLabel(p, g)}: `));
  return parts;
}
function joinParts(parts) {
  if (!Array.isArray(parts)) return parts;
  const used = parts.filter((x) => x.count);
  return { count: used.reduce((a, x) => a + x.count, 0), text: used.map((x) => x.text).join('; ') };
}

// Pro Markierung: zugeteilte Felder
export function assignments(p) {
  return p.marks.map((m) => joinParts(perGrid(p, (fills, status, pre) => {
    const map = m.kind === 'team' ? fills : status;
    const keys = Object.keys(map).filter((k) => map[k] === m.id);
    return { count: keys.length, text: keys.length ? pre + cellsText(keys) : '' };
  }))).map((a, i) => ({ mark: p.marks[i], ...a }));
}

// Status innerhalb der Felder eines Teams, z. B. [{mark: abgesucht, count: 2, text: 'A3–B3'}]
export function teamStatus(p, team) {
  return p.marks.filter((m) => m.kind !== 'team').map((m) => ({ mark: m, ...joinParts(perGrid(p, (fills, status, pre) => {
    const keys = Object.keys(fills).filter((k) => fills[k] === team.id && status[k] === m.id);
    return { count: keys.length, text: keys.length ? pre + cellsText(keys) : '' };
  })) })).filter((x) => x.count);
}

// Team eines Feldes
export function cellOwner(p, c, r) {
  const id = p.fills[`${c},${r}`];
  return id ? p.marks.find((m) => m.id === id) || null : null;
}

// Status eines Feldes (abgesucht …)
export function cellStatus(p, c, r) {
  const id = p.status[`${c},${r}`];
  return id ? p.marks.find((m) => m.id === id) || null : null;
}

// ---------- Datei-Austausch ----------
const MARK = 'SUCHGEBIET-KARTEN-V1';

function toBase64(str) {
  const bytes = new TextEncoder().encode(str);
  let bin = '';
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(bin);
}

function fromBase64(b64) {
  const bin = atob(b64);
  const bytes = Uint8Array.from(bin, (ch) => ch.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

export function exportProject(p) {
  const { view, ...rest } = p;
  return JSON.stringify({ format: MARK, exported: new Date().toISOString(), project: { ...rest, view } }, null, 1);
}

// Eingebettet ins PDF (XMP-Metadaten), damit das PDF selbst wieder importiert werden kann
export function embedMarker(p) {
  return `${MARK}:${toBase64(exportProject(p))}:${MARK}`;
}

// Nimmt JSON-Text oder den Inhalt eines PDFs (als latin1-Text) entgegen
export function importProject(text) {
  let json = null;
  const m = new RegExp(`${MARK}:([A-Za-z0-9+/=\\s]+):${MARK}`).exec(text);
  if (m) json = fromBase64(m[1].replace(/\s+/g, ''));
  else if (text.trim().startsWith('{')) json = text;
  if (!json) throw new Error('Keine Suchgebiet-Daten in der Datei gefunden.');
  const data = JSON.parse(json);
  if (data.format !== MARK || !data.project) throw new Error('Unbekanntes Dateiformat.');
  const p = normalizeProject(data.project);
  p.id = uid();
  return p;
}


// v111: Reihenfolge der Teams bzw. Markierungen ändern. ids = neue Reihenfolge einer Art (team/status);
// die Plätze der anderen Art in marks bleiben, wo sie sind. Unbekannte/fehlende ids: Rest in alter Reihenfolge hinten an.
export function reorderMarks(marks, kind, ids) {
  const own = marks.filter((m) => m.kind === kind);
  const byId = new Map(own.map((m) => [m.id, m]));
  const order = [...new Set(ids)].filter((id) => byId.has(id)).map((id) => byId.get(id));
  for (const m of own) if (!order.includes(m)) order.push(m);
  let i = 0;
  return marks.map((m) => (m.kind === kind ? order[i++] : m));
}
