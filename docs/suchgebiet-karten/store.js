// Suchgebiete (Projekte), Teams/Markierungen und Datei-Austausch.
// Reine Logik ohne DOM, damit sie testbar ist.

import { rangeLabel } from './grid.js';

export const TEAM_COLORS = ['#d50000', '#1565c0', '#ef6c00', '#6a1b9a', '#00838f', '#ad1457', '#4e342e', '#558b2f'];

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
    layerId: 'osm',
    cellM: 100,
    area: null,
    fills: {}, // "c,r" -> Team-ID (bleibt, auch wenn das Feld abgesucht ist)
    status: {}, // "c,r" -> Status-ID (abgesucht, teilweise …), zusätzlich zum Team
    marks: defaultMarks(),
    items: [],
    meet: null, // {lat, lon, text}
    showUtm: false,
    view: null,
  };
}

// Fehlende Felder ergänzen (ältere Dateien, Importe)
export function normalizeProject(p) {
  const base = newProject();
  const out = { ...base, ...p };
  if (!Array.isArray(out.marks)) out.marks = base.marks;
  if (!Array.isArray(out.items)) out.items = [];
  if (!out.fills || typeof out.fills !== 'object') out.fills = {};
  if (!out.status || typeof out.status !== 'object') out.status = {};
  out.fills = { ...out.fills };
  out.status = { ...out.status };
  const kind = Object.fromEntries(out.marks.map((m) => [m.id, m.kind]));
  // Ältere Stände hatten Team und Status in einem Feld: Status-Einträge umziehen
  for (const k of Object.keys(out.fills)) {
    if (kind[out.fills[k]] === 'status' && !out.status[k]) out.status[k] = out.fills[k];
    if (kind[out.fills[k]] !== 'team') delete out.fills[k];
  }
  for (const k of Object.keys(out.status)) if (kind[out.status[k]] !== 'status') delete out.status[k];
  return out;
}

// Version 1 speicherte nur ein Gebiet mit Farben statt Markierungen
export function migrateV1(old) {
  const p = newProject(old.title || '');
  Object.assign(p, {
    layerId: old.layerId || 'osm',
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

export function markLabel(m) {
  if (m.kind === 'team' && m.dog) return `${m.label} (${m.dog})`;
  return m.label;
}

// Feldzuordnung, in der eine Markierung steht: Teams in fills, alles andere in status
export function mapFor(p, m) {
  return m.kind === 'team' ? p.fills : p.status;
}

// "c,r" -> Farbe (für die Darstellung); which = 'fills' (Teams) oder 'status'
export function resolveFills(p, which = 'fills') {
  const color = Object.fromEntries(p.marks.map((m) => [m.id, m.color]));
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

// Pro Markierung: zugeteilte Felder
export function assignments(p) {
  return p.marks.map((m) => {
    const map = mapFor(p, m);
    const keys = Object.keys(map).filter((k) => map[k] === m.id);
    return { mark: m, count: keys.length, text: cellsText(keys) };
  });
}

// Status innerhalb der Felder eines Teams, z. B. [{mark: abgesucht, count: 2, text: 'A3–B3'}]
export function teamStatus(p, team) {
  const own = Object.keys(p.fills).filter((k) => p.fills[k] === team.id);
  return p.marks.filter((m) => m.kind !== 'team').map((m) => {
    const keys = own.filter((k) => p.status[k] === m.id);
    return { mark: m, count: keys.length, text: cellsText(keys) };
  }).filter((x) => x.count);
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

