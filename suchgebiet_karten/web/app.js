import {
  makeGrid, cellCount, cellAt, cellBounds, cellLabel, parseCell, formatMeters, MAX_CELLS,
} from './grid.js';
import { drawOverlay, hitItem } from './render.js';
import {
  LAYERS, OVERLAYS, DEFAULT_OVERLAYS, layerById, layerStack, tileUrl,
} from './layers.js';
import { buildPdf, planSheets, renderState } from './pdf.js';
import { formatMgrs } from './utm.js';
import { buildGpx, trackLength, formatLength } from './gpx.js';
import { buildCustomMap, planCustomMap } from './kmz.js';
import { parseQuery, searchAddress } from './search.js';
import {
  newProject, normalizeProject, migrateV1, assignments, markLabel, cellOwner, cellStatus, mapFor,
  exportProject, importProject, uid, TEAM_COLORS,
} from './store.js';

const STORE_KEY = 'suchgebiet-karten-v2';
const OLD_KEY = 'suchgebiet-karten-v1';
const COLORS = ['#d50000', '#1565c0', '#2e7d32', '#ef6c00', '#6a1b9a', '#000000', '#fdd835'];
const MARK_COLORS = [...new Set([...TEAM_COLORS, '#00c853', '#2e7d32', '#fdd835', '#616161', '#000000'])];
const COLOR_NAMES = {
  '#d50000': 'Rot', '#1565c0': 'Blau', '#ef6c00': 'Orange', '#6a1b9a': 'Lila', '#00838f': 'Türkis', '#ad1457': 'Pink',
  '#4e342e': 'Braun', '#558b2f': 'Olivgrün', '#2e7d32': 'Dunkelgrün', '#00c853': 'Hellgrün', '#fdd835': 'Gelb', '#616161': 'Grau', '#000000': 'Schwarz',
};

const $ = (id) => document.getElementById(id);
const bridge = window.AndroidBridge || null; // gesetzt in der Android-App

// ---------- Zustand ----------
// db: alle Suchgebiete; P: das aktuelle; grid wird aus P.area + P.cellM berechnet
let db = { projects: {}, currentId: null, color: COLORS[0], w: 5, activeMark: null };
let P = null;
let grid = null;
let tool = 'pan';
let undoStack = [];

function load() {
  try {
    const s = JSON.parse(localStorage.getItem(STORE_KEY) || 'null');
    if (s && s.projects) db = { ...db, ...s };
  } catch { /* defekter Speicher -> Neustart */ }
  if (!Object.keys(db.projects).length) {
    let p = null;
    try {
      const old = JSON.parse(localStorage.getItem(OLD_KEY) || 'null');
      if (old) p = migrateV1(old);
    } catch { /* ignorieren */ }
    p = p || newProject('');
    db.projects[p.id] = p;
    db.currentId = p.id;
  }
  for (const id of Object.keys(db.projects)) db.projects[id] = normalizeProject(db.projects[id]);
  if (!db.projects[db.currentId]) db.currentId = Object.keys(db.projects)[0];
  P = db.projects[db.currentId];
  grid = P.area ? makeGrid(P.area, P.cellM) : null;
}

let saveTimer = null;
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(saveNow, 300);
}
function saveNow() {
  clearTimeout(saveTimer);
  if (map) {
    const c = map.getCenter();
    P.view = { lat: c.lat, lon: c.lng, z: map.getZoom() };
  }
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(db));
  } catch { toast('Speichern nicht möglich (Speicher voll?)'); }
}
window.addEventListener('pagehide', saveNow);
document.addEventListener('visibilitychange', () => { if (document.hidden) saveNow(); });

function snapshot() {
  undoStack.push(JSON.stringify({
    area: P.area, cellM: P.cellM, fills: P.fills, status: P.status, items: P.items, marks: P.marks, meet: P.meet,
  }));
  if (undoStack.length > 60) undoStack.shift();
}

function undo() {
  const s = undoStack.pop();
  if (!s) return toast('Nichts zum Rückgängigmachen');
  Object.assign(P, JSON.parse(s));
  grid = P.area ? makeGrid(P.area, P.cellM) : null;
  changed();
}

function changed() {
  P.updated = Date.now();
  updateGridInfo();
  renderPalette();
  if (!$('panel-teams').hidden) renderMarks();
  redraw();
  save();
}

// ---------- Karte ----------
load();
const map = L.map('map', { zoomControl: false, maxZoom: 20 });
L.control.zoom({ position: 'bottomright' }).addTo(map);

// Eine Kachelschicht für alle Dienste (auch WMS), dieselben URLs wie im PDF
const AppTiles = L.TileLayer.extend({
  getTileUrl(coords) {
    return tileUrl(this.options.def, coords.z, coords.x, coords.y);
  },
});

let baseLayer = null;
let overlayLayers = [];
function setLayer(id) {
  const l = layerById(id);
  P.layerId = l.id;
  if (baseLayer) map.removeLayer(baseLayer);
  baseLayer = makeTiles(l, true).addTo(map);
  updateOverlays();
  renderLayerList();
  save();
}

function activeOverlays() {
  return P.overlays || DEFAULT_OVERLAYS;
}

// Straßen/Wanderwege über Luftbildern. Auf dem Bildschirm ohne CORS-Anfrage, damit sie
// immer erscheinen; ins PDF kommen sie, wenn der Dienst es erlaubt.
function updateOverlays() {
  overlayLayers.forEach((o) => map.removeLayer(o));
  overlayLayers = [];
  if (!layerById(P.layerId).aerial) return;
  OVERLAYS.filter((o) => activeOverlays().includes(o.id)).forEach((o, i) => {
    overlayLayers.push(makeTiles(o, false, 10 + i).addTo(map));
  });
}

function makeTiles(l, cors, zIndex = 1) {
  const layer = new AppTiles('', {
    def: l,
    zIndex,
    maxNativeZoom: l.maxNative,
    maxZoom: 20,
    attribution: l.attribution,
    crossOrigin: cors ? 'anonymous' : undefined, // nötig, damit die Kacheln ins PDF dürfen
  });
  if (cors) {
    // Liefert ein Dienst keine CORS-Freigabe, ohne sie anzeigen (dann aber nicht im PDF)
    let ok = 0;
    let bad = 0;
    layer.on('tileload', () => { ok++; });
    layer.on('tileerror', () => {
      bad++;
      if (bad === 6 && ok === 0 && navigator.onLine && baseLayer === layer) {
        map.removeLayer(layer);
        baseLayer = makeTiles(l, false).addTo(map);
        toast('Diese Karte lässt sich nur anzeigen, aber nicht ins PDF übernehmen.');
      }
    });
  }
  return layer;
}

// ---------- Overlay (Raster + Zeichnungen) ----------
const canvas = $('overlay');
const ctx = canvas.getContext('2d');
let current = null; // Strich, der gerade gezeichnet wird
let draftTrack = null; // Track, der gerade Punkt für Punkt gesetzt wird
let dragRect = null; // Vorschau beim Aufziehen des Suchgebiets

function toPx(lat, lon) {
  const p = map.latLngToContainerPoint([lat, lon]);
  return [p.x, p.y];
}

function resizeCanvas() {
  const el = map.getContainer();
  const dpr = window.devicePixelRatio || 1;
  canvas.style.width = el.clientWidth + 'px';
  canvas.style.height = el.clientHeight + 'px';
  canvas.width = Math.round(el.clientWidth * dpr);
  canvas.height = Math.round(el.clientHeight * dpr);
  redraw();
}


function redraw() {
  const dpr = window.devicePixelRatio || 1;
  const W = canvas.width / dpr;
  const H = canvas.height / dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, W, H);
  const b = map.getBounds();
  const view = { north: b.getNorth(), south: b.getSouth(), west: b.getWest(), east: b.getEast() };
  const items = [...P.items];
  if (current) items.push(current);
  if (draftTrack && draftTrack.pts.length) items.push(draftTrack);
  drawOverlay(ctx, toPx, { ...renderState(P, grid), items }, { s: 1, width: W, height: H, view, utm: P.showUtm });
  if (dragRect) {
    const [x0, y0] = toPx(dragRect.a.lat, dragRect.a.lng);
    const [x1, y1] = toPx(dragRect.b.lat, dragRect.b.lng);
    ctx.setLineDash([6, 4]);
    ctx.strokeStyle = '#c62828';
    ctx.lineWidth = 2;
    ctx.fillStyle = 'rgba(198,40,40,0.1)';
    ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
    ctx.strokeRect(x0, y0, x1 - x0, y1 - y0);
    ctx.setLineDash([]);
  }
}

map.on('move resize viewreset', redraw);
map.on('zoomstart', () => { canvas.style.visibility = 'hidden'; });
map.on('zoomend', () => { canvas.style.visibility = 'visible'; redraw(); save(); });
map.on('moveend', save);
window.addEventListener('resize', () => { map.invalidateSize(); resizeCanvas(); });

// ---------- Werkzeuge ----------
const HINTS = {
  pen: 'Mit dem Finger auf die Karte zeichnen. Zum Verschieben „Bewegen“ wählen.',
  text: 'Auf die Karte tippen, um einen Punkt mit Text zu setzen.',
  fill: 'Team/Markierung wählen, dann Felder antippen oder darüberwischen. Nochmal tippen entfernt.',
  erase: 'Antippen oder darüberwischen löscht Zeichnungen, Tracks, Texte, Treffpunkt und Feldfarben.',
  grid: 'Suchgebiet als Rechteck mit dem Finger aufziehen.',
  meet: 'Auf die Karte tippen, um den Treffpunkt zu setzen.',
  track: 'Track: Punkte antippen. Karte mit dem Finger verschieben, Zoom mit +/−.',
};

function setTool(t) {
  if (tool === 'track' && t !== 'track') finishTrack(true);
  if ((t === 'fill') && !grid) {
    toast('Bitte zuerst ein Raster anlegen');
    t = 'pan';
  }
  tool = t;
  document.querySelectorAll('.toolbar [data-tool]').forEach((b) => b.classList.toggle('active', b.dataset.tool === t));
  canvas.classList.toggle('active', t !== 'pan');
  $('palette').hidden = !['pen', 'text', 'fill', 'track'].includes(t);
  $('trackbar').hidden = t !== 'track';
  if (t === 'track' && !draftTrack) draftTrack = { kind: 'track', name: '', color: db.color, w: 4, pts: [] };
  updateTrackbar();
  $('palette').querySelector('.widths').hidden = t !== 'pen';
  $('palette').querySelector('.colors').hidden = t === 'fill';
  $('palette').querySelector('.marks').hidden = t !== 'fill';
  const hint = HINTS[t];
  $('hint').hidden = !hint;
  $('hint').textContent = hint || '';
}

function eventLatLng(e) {
  const r = canvas.getBoundingClientRect();
  const x = e.clientX - r.left;
  const y = e.clientY - r.top;
  return { x, y, ll: map.containerPointToLatLng([x, y]) };
}

let activePointer = null;
let lastPt = null;
let erased = false;
let fillStroke = null; // beim Wischen über Felder: {mode: 'set'|'clear', seen}
let panning = false;

function activeMark() {
  return P.marks.find((m) => m.id === db.activeMark) || P.marks[0] || null;
}

function fillAt(ll, first) {
  const cell = grid && cellAt(grid, ll.lat, ll.lng);
  if (!cell) {
    if (first) toast('Außerhalb des Rasters');
    return;
  }
  const m = activeMark();
  if (!m) return toast('Bitte zuerst ein Team oder eine Markierung anlegen');
  const key = `${cell.c},${cell.r}`;
  if (first) {
    snapshot();
    // Teams und Status liegen getrennt: „abgesucht“ überschreibt nicht das Team
    fillStroke = { map: mapFor(P, m), mode: mapFor(P, m)[key] === m.id ? 'clear' : 'set', seen: new Set() };
  }
  if (fillStroke.seen.has(key)) return;
  fillStroke.seen.add(key);
  if (fillStroke.mode === 'clear') delete fillStroke.map[key];
  else fillStroke.map[key] = m.id;
  redraw();
}

canvas.addEventListener('pointerdown', (e) => {
  if (activePointer !== null) return;
  activePointer = e.pointerId;
  canvas.setPointerCapture(e.pointerId);
  const { x, y, ll } = eventLatLng(e);
  lastPt = { x, y };
  erased = false;
  if (tool === 'pen') {
    current = { kind: 'stroke', color: db.color, w: db.w, pts: [[ll.lat, ll.lng]] };
    redraw();
  } else if (tool === 'grid') {
    dragRect = { a: ll, b: ll };
  } else if (tool === 'erase') {
    eraseAt(x, y);
  } else if (tool === 'fill') {
    fillAt(ll, true);
  } else if (tool === 'track') {
    panning = false;
  }
});

canvas.addEventListener('pointermove', (e) => {
  if (e.pointerId !== activePointer) return;
  const { x, y, ll } = eventLatLng(e);
  if (tool === 'pen' && current) {
    if (Math.hypot(x - lastPt.x, y - lastPt.y) < 2) return;
    current.pts.push([ll.lat, ll.lng]);
    lastPt = { x, y };
    redraw();
  } else if (tool === 'grid' && dragRect) {
    dragRect.b = ll;
    redraw();
  } else if (tool === 'erase') {
    eraseAt(x, y);
  } else if (tool === 'fill' && fillStroke) {
    fillAt(ll, false);
  } else if (tool === 'track') {
    // Im Track-Modus verschiebt Ziehen die Karte, Tippen setzt Punkte
    if (!panning && Math.hypot(x - lastPt.x, y - lastPt.y) < 8) return;
    panning = true;
    map.panBy([lastPt.x - x, lastPt.y - y], { animate: false });
    lastPt = { x, y };
  }
});

function finishPointer(e, cancelled) {
  if (e.pointerId !== activePointer) return;
  activePointer = null;
  const { x, y, ll } = eventLatLng(e);
  if (tool === 'pen' && current) {
    if (!cancelled) {
      snapshot();
      P.items.push(current);
    }
    current = null;
    changed();
  } else if (tool === 'grid' && dragRect) {
    const a = dragRect.a;
    dragRect = null;
    if (!cancelled) setArea({ north: a.lat, south: ll.lat, west: a.lng, east: ll.lng });
    setTool('pan');
    redraw();
  } else if (tool === 'fill') {
    if (fillStroke) changed();
    fillStroke = null;
  } else if (tool === 'track') {
    if (!cancelled && !panning && draftTrack) {
      draftTrack.pts.push([ll.lat, ll.lng]);
      updateTrackbar();
      redraw();
    }
    panning = false;
  } else if (cancelled) {
    return;
  } else if (tool === 'text' && Math.hypot(x - lastPt.x, y - lastPt.y) < 10) {
    const text = prompt('Text für diesen Punkt (z. B. Fundstelle, Hinweis):');
    if (text && text.trim()) {
      snapshot();
      P.items.push({ kind: 'text', color: db.color, lat: ll.lat, lon: ll.lng, text: text.trim() });
      changed();
    }
  } else if (tool === 'meet') {
    const text = prompt('Bezeichnung des Treffpunkts:', (P.meet && P.meet.text) || 'Treffpunkt');
    if (text !== null) {
      snapshot();
      P.meet = { lat: ll.lat, lon: ll.lng, text: text.trim() };
      changed();
    }
    setTool('pan');
  } else if (tool === 'erase' && erased) {
    changed();
  }
}
canvas.addEventListener('pointerup', (e) => finishPointer(e, false));
canvas.addEventListener('pointercancel', (e) => finishPointer(e, true));

// Radierer: zuerst Zeichnungen/Tracks/Texte, dann Treffpunkt, dann Feldfarbe/Zuteilung.
// Das Raster selbst bleibt (Raster → „Raster entfernen“).
function eraseAt(x, y) {
  const before = () => {
    if (!erased) snapshot();
    erased = true;
  };
  const i = hitItem(P.items, toPx, x, y, 12);
  if (i >= 0) {
    before();
    P.items.splice(i, 1);
  } else if (P.meet && Math.hypot(toPx(P.meet.lat, P.meet.lon)[0] - x, toPx(P.meet.lat, P.meet.lon)[1] - y) <= 16) {
    before();
    P.meet = null;
  } else {
    const ll = map.containerPointToLatLng([x, y]);
    const cell = grid && cellAt(grid, ll.lat, ll.lng);
    const key = cell && `${cell.c},${cell.r}`;
    if (!key || (!P.fills[key] && !P.status[key])) return;
    before();
    delete P.fills[key];
    delete P.status[key];
  }
  redraw();
}

document.querySelectorAll('.toolbar [data-tool]').forEach((b) => b.addEventListener('click', () => setTool(b.dataset.tool)));
$('undo').addEventListener('click', undo);

// ---------- Track ----------
function updateTrackbar() {
  if (!draftTrack) return;
  const n = draftTrack.pts.length;
  $('track-info').textContent = n
    ? `Track: ${n} Punkt${n > 1 ? 'e' : ''} · ${formatLength(trackLength(draftTrack.pts))}`
    : 'Track: ersten Punkt auf die Karte tippen';
  $('track-back').disabled = !n;
  $('track-done').disabled = n < 2;
}

// auto = beim Wechsel des Werkzeugs: ohne Nachfrage mit Standardnamen speichern
function finishTrack(auto) {
  const d = draftTrack;
  draftTrack = null;
  if (!d || d.pts.length < 2) { redraw(); return; }
  const n = P.items.filter((it) => it.kind === 'track').length + 1;
  let name = `Track ${n}`;
  if (!auto) {
    const t = prompt('Name des Tracks (erscheint so auf dem Garmin):', name);
    if (t === null) { draftTrack = d; return; }
    name = t.trim() || name;
  }
  snapshot();
  d.name = name;
  P.items.push(d);
  changed();
  toast(`„${name}“ gespeichert (${formatLength(trackLength(d.pts))})`);
}

$('track-back').addEventListener('click', () => {
  if (!draftTrack) return;
  draftTrack.pts.pop();
  updateTrackbar();
  redraw();
});
$('track-done').addEventListener('click', () => {
  finishTrack(false);
  if (!draftTrack) setTool('pan');
});
$('track-cancel').addEventListener('click', () => {
  if (draftTrack && draftTrack.pts.length > 1 && !confirm('Track verwerfen?')) return;
  draftTrack = null;
  setTool('pan');
  redraw();
});

// Palette
const colorBox = $('palette').querySelector('.colors');
COLORS.forEach((c) => {
  const b = document.createElement('button');
  b.style.background = c;
  b.title = c;
  b.addEventListener('click', () => {
    db.color = c;
    if (draftTrack) { draftTrack.color = c; redraw(); }
    renderPalette();
    save();
  });
  colorBox.appendChild(b);
});
$('palette').querySelectorAll('.widths button').forEach((b) => b.addEventListener('click', () => {
  db.w = Number(b.dataset.w);
  renderPalette();
  save();
}));
function renderPalette() {
  colorBox.querySelectorAll('button').forEach((b, i) => b.classList.toggle('active', COLORS[i] === db.color));
  $('palette').querySelectorAll('.widths button').forEach((b) => b.classList.toggle('active', Number(b.dataset.w) === db.w));
  const box = $('palette').querySelector('.marks');
  box.innerHTML = '';
  const act = activeMark();
  for (const m of P.marks) {
    const b = document.createElement('button');
    b.innerHTML = '<i></i><span></span>';
    b.querySelector('i').style.background = m.color;
    b.querySelector('span').textContent = m.label || '(ohne Namen)';
    b.classList.toggle('active', act && act.id === m.id);
    b.addEventListener('click', () => { db.activeMark = m.id; renderPalette(); save(); });
    box.appendChild(b);
  }
  const add = document.createElement('button');
  add.textContent = '+ Team';
  add.addEventListener('click', () => { addMark('team'); });
  box.appendChild(add);
}

// ---------- Teams & Legende ----------
function addMark(kind) {
  snapshot();
  const used = new Set(P.marks.map((m) => m.color));
  const color = MARK_COLORS.find((c) => !used.has(c)) || MARK_COLORS[P.marks.length % MARK_COLORS.length];
  const n = P.marks.filter((m) => m.kind === 'team').length + 1;
  const m = kind === 'team'
    ? { id: uid(), kind: 'team', label: `Team ${n}`, dog: '', color }
    : { id: uid(), kind: 'status', label: 'Markierung', color };
  P.marks.push(m);
  db.activeMark = m.id;
  changed();
  openPanel('panel-teams');
  const inp = $('mark-list').querySelector(`[data-id="${m.id}"] input`);
  if (inp) { inp.focus(); inp.select(); }
}

function renderMarks() {
  const box = $('mark-list');
  box.innerHTML = '';
  const as = Object.fromEntries(assignments(P).map((a) => [a.mark.id, a]));
  const act = activeMark();
  for (const m of P.marks) {
    const el = document.createElement('div');
    el.className = 'mark' + (act && act.id === m.id ? ' active' : '');
    el.dataset.id = m.id;
    const a = as[m.id];
    el.innerHTML = `
      <button class="swatch" title="Zum Einfärben auswählen"></button>
      <div class="fields">
        <input type="text" class="name" placeholder="${m.kind === 'team' ? 'Teamname / Hundeführer' : 'Bedeutung'}">
        ${m.kind === 'team' ? '<input type="text" class="dog" placeholder="Hund">' : ''}
        <select class="color" aria-label="Farbe"></select>
        <div class="cells"></div>
      </div>
      <button class="del" title="Löschen">✕</button>`;
    el.querySelector('.swatch').style.background = m.color;
    el.querySelector('.name').value = m.label;
    if (m.kind === 'team') el.querySelector('.dog').value = m.dog || '';
    el.querySelector('.cells').textContent = a && a.count ? `${a.count} Feld${a.count > 1 ? 'er' : ''}: ${a.text}` : 'keine Felder';
    const sel = el.querySelector('.color');
    for (const c of MARK_COLORS) {
      const o = document.createElement('option');
      o.value = c;
      o.textContent = COLOR_NAMES[c] || c;
      sel.appendChild(o);
    }
    if (!MARK_COLORS.includes(m.color)) {
      const o = document.createElement('option');
      o.value = m.color;
      o.textContent = 'eigene Farbe';
      sel.appendChild(o);
    }
    sel.value = m.color;
    el.querySelector('.swatch').addEventListener('click', () => {
      db.activeMark = m.id;
      closePanels();
      setTool('fill');
      renderPalette();
    });
    el.querySelector('.name').addEventListener('input', (e) => { m.label = e.target.value; renderPalette(); redraw(); save(); });
    if (m.kind === 'team') el.querySelector('.dog').addEventListener('input', (e) => { m.dog = e.target.value; save(); });
    sel.addEventListener('change', () => { m.color = sel.value; changed(); renderMarks(); });
    el.querySelector('.del').addEventListener('click', () => {
      const cnt = a ? a.count : 0;
      if (!confirm(`„${markLabel(m) || 'Eintrag'}“ löschen?${cnt ? ` ${cnt} zugeteilte Felder werden freigegeben.` : ''}`)) return;
      snapshot();
      P.marks = P.marks.filter((x) => x.id !== m.id);
      const map = mapFor(P, m);
      for (const k of Object.keys(map)) if (map[k] === m.id) delete map[k];
      changed();
      renderMarks();
    });
    box.appendChild(el);
  }
}
$('team-add').addEventListener('click', () => addMark('team'));
$('mark-add').addEventListener('click', () => addMark('status'));

// ---------- Raster ----------
function setArea(area, cellM = P.cellM) {
  if (Math.abs(area.north - area.south) < 1e-6 || Math.abs(area.east - area.west) < 1e-6) {
    // nur angetippt: ein Feld an dieser Stelle
    area = { north: area.north, west: area.west, south: area.north - 1e-6, east: area.west + 1e-6 };
  }
  const g = makeGrid(area, cellM);
  if (cellCount(g) > MAX_CELLS) {
    toast(`Zu viele Felder (${g.cols} × ${g.rows}). Bitte größere Feldgröße oder kleineres Gebiet wählen.`);
    return false;
  }
  snapshot();
  const sizeChanged = grid && (grid.cellM !== cellM);
  P.area = area;
  P.cellM = cellM;
  grid = g;
  if (sizeChanged) { P.fills = {}; P.status = {}; }
  changed();
  return true;
}

function updateGridInfo() {
  $('cell-size').value = String(P.cellM);
  $('show-utm').checked = !!P.showUtm;
  if (!grid) {
    $('grid-info').textContent = 'Noch kein Raster. „Suchgebiet aufziehen“ oder „Aktuellen Ausschnitt nehmen“.';
    return;
  }
  $('grid-info').textContent = `${grid.cols} × ${grid.rows} Felder à ${formatMeters(grid.cellM)} · A1 bis ${cellLabel(grid.cols - 1, grid.rows - 1)} · `
    + `Gebiet ${formatMeters(grid.cols * grid.cellM)} × ${formatMeters(grid.rows * grid.cellM)}`;
}

$('cell-size').addEventListener('change', () => {
  const m = Number($('cell-size').value);
  if (!P.area) { P.cellM = m; save(); return; }
  if ((Object.keys(P.fills).length || Object.keys(P.status).length) && !confirm('Bei neuer Feldgröße ändern sich die Felder – die Feldzuteilungen werden gelöscht. Fortfahren?')) {
    $('cell-size').value = String(P.cellM);
    return;
  }
  if (!setArea(P.area, m)) $('cell-size').value = String(P.cellM);
});
$('show-utm').addEventListener('change', () => { P.showUtm = $('show-utm').checked; changed(); });
$('grid-draw').addEventListener('click', () => { closePanels(); setTool('grid'); });
$('grid-view').addEventListener('click', () => {
  const b = map.getBounds().pad(-0.08);
  if (setArea({ north: b.getNorth(), south: b.getSouth(), west: b.getWest(), east: b.getEast() })) closePanels();
});
$('grid-remove').addEventListener('click', () => {
  if (!grid || !confirm('Raster und Feldzuteilungen entfernen?')) return;
  snapshot();
  P.area = null;
  grid = null;
  P.fills = {};
  P.status = {};
  changed();
});
$('clear-fills').addEventListener('click', () => {
  if ((!Object.keys(P.fills).length && !Object.keys(P.status).length) || !confirm('Alle Feldfarben und Zuteilungen löschen?')) return;
  snapshot();
  P.fills = {};
  P.status = {};
  changed();
});
$('clear-drawings').addEventListener('click', () => {
  if (!P.items.length || !confirm('Alle Zeichnungen und Texte löschen?')) return;
  snapshot();
  P.items = [];
  changed();
});
function goToCell() {
  const p = parseCell($('cell-search').value);
  if (!grid) return toast('Kein Raster vorhanden');
  if (!p || p.c >= grid.cols || p.r >= grid.rows) return toast('Dieses Feld gibt es nicht');
  const b = cellBounds(grid, p.c, p.r);
  closePanels();
  map.fitBounds([[b.south, b.west], [b.north, b.east]], { padding: [60, 60] });
}
$('cell-go').addEventListener('click', goToCell);
$('cell-search').addEventListener('keydown', (e) => { if (e.key === 'Enter') goToCell(); });

// Antippen im Bewegen-Modus zeigt Feld, Zuteilung und ggf. UTMREF
map.on('click', (e) => {
  const parts = [];
  if (grid) {
    const c = cellAt(grid, e.latlng.lat, e.latlng.lng);
    if (c) {
      const m = cellOwner(P, c.c, c.r);
      const st = cellStatus(P, c.c, c.r);
      parts.push(`Feld ${cellLabel(c.c, c.r)}${m ? ` – ${markLabel(m)}` : ''}${st ? ` (${st.label})` : ''}`);
    } else parts.push('Außerhalb des Rasters');
  }
  if (P.showUtm) parts.push(formatMgrs(e.latlng.lat, e.latlng.lng));
  if (parts.length) toast(parts.join(' · '));
});

// ---------- Kartenart ----------
function renderLayerList() {
  const box = $('layer-list');
  box.innerHTML = '';
  for (const l of LAYERS) {
    const b = document.createElement('button');
    b.textContent = l.name;
    b.classList.toggle('active', l.id === P.layerId);
    b.addEventListener('click', () => setLayer(l.id));
    box.appendChild(b);
  }
  const ovBox = $('overlay-list');
  ovBox.innerHTML = '';
  for (const o of OVERLAYS) {
    const lab = document.createElement('label');
    lab.className = 'check';
    lab.innerHTML = '<input type="checkbox"> <span></span>';
    lab.querySelector('span').textContent = o.name;
    const cb = lab.querySelector('input');
    cb.checked = activeOverlays().includes(o.id);
    cb.addEventListener('change', () => {
      const set = new Set(activeOverlays());
      if (cb.checked) set.add(o.id); else set.delete(o.id);
      P.overlays = OVERLAYS.map((x) => x.id).filter((x) => set.has(x));
      P.updated = Date.now();
      updateOverlays();
      save();
    });
    ovBox.appendChild(lab);
  }
}

// ---------- GPS ----------
let watchId = null;
let gpsMarker = null;
let gpsCircle = null;
let lastPos = null;

function updateStatus() {
  if (!lastPos) { $('status').textContent = ''; return; }
  const [lat, lon] = lastPos;
  const parts = [];
  if (grid) {
    const c = cellAt(grid, lat, lon);
    parts.push(c ? `📍 ${cellLabel(c.c, c.r)}` : '📍 außerhalb');
  }
  if (P.showUtm) parts.push(formatMgrs(lat, lon));
  $('status').textContent = parts.join(' · ') || '📍';
}

$('btn-gps').addEventListener('click', () => {
  if (watchId !== null) {
    navigator.geolocation.clearWatch(watchId);
    watchId = null;
    lastPos = null;
    if (gpsMarker) { map.removeLayer(gpsMarker); map.removeLayer(gpsCircle); gpsMarker = null; }
    $('btn-gps').classList.remove('on');
    updateStatus();
    return;
  }
  if (!navigator.geolocation) return toast('Standort wird nicht unterstützt');
  let first = true;
  $('btn-gps').classList.add('on');
  watchId = navigator.geolocation.watchPosition((pos) => {
    const ll = [pos.coords.latitude, pos.coords.longitude];
    lastPos = ll;
    if (!gpsMarker) {
      gpsCircle = L.circle(ll, { radius: pos.coords.accuracy, weight: 1, color: '#1e88e5', fillOpacity: 0.1 }).addTo(map);
      gpsMarker = L.marker(ll, { icon: L.divIcon({ className: '', html: '<div class="gps-dot"></div>', iconSize: [22, 22] }) }).addTo(map);
    } else {
      gpsMarker.setLatLng(ll);
      gpsCircle.setLatLng(ll).setRadius(pos.coords.accuracy);
    }
    if (first) { map.setView(ll, Math.max(map.getZoom(), 16)); first = false; }
    updateStatus();
  }, (err) => {
    toast('Standort nicht verfügbar: ' + err.message);
  }, { enableHighAccuracy: true, maximumAge: 5000 });
});

// ---------- Suchgebiete (Projekte) ----------
function switchProject(id) {
  saveNow();
  db.currentId = id;
  P = db.projects[id];
  grid = P.area ? makeGrid(P.area, P.cellM) : null;
  undoStack = [];
  if (P.view) map.setView([P.view.lat, P.view.lon], P.view.z);
  else if (grid) map.fitBounds([[P.area.south, P.area.west], [P.area.north, P.area.east]]);
  setLayer(P.layerId);
  fillProjectForm();
  changed();
  updateStatus();
}

function fillProjectForm() {
  $('title').value = P.title;
  $('leader').value = P.leader || '';
  $('notes').value = P.notes || '';
  renderMeet();
}

function renderMeet() {
  const m = P.meet;
  $('meet-info').textContent = m
    ? `${m.text || 'Treffpunkt'}: ${m.lat.toFixed(5)}, ${m.lon.toFixed(5)}${P.showUtm ? ` · ${formatMgrs(m.lat, m.lon)}` : ''}`
    : 'Kein Treffpunkt gesetzt.';
  $('meet-remove').disabled = !m;
}

function renderProjects() {
  const box = $('project-list');
  box.innerHTML = '';
  const list = Object.values(db.projects).sort((a, b) => b.updated - a.updated);
  for (const p of list) {
    const el = document.createElement('div');
    el.className = 'proj' + (p.id === P.id ? ' current' : '');
    const g = p.area ? makeGrid(p.area, p.cellM) : null;
    el.innerHTML = '<div class="meta"><b></b><span></span></div>';
    el.querySelector('b').textContent = p.title || '(ohne Titel)';
    el.querySelector('span').textContent = `${new Date(p.updated).toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' })}`
      + (g ? ` · ${g.cols}×${g.rows} Felder à ${formatMeters(g.cellM)}` : ' · kein Raster');
    const btn = (label, fn) => {
      const b = document.createElement('button');
      b.textContent = label;
      b.addEventListener('click', fn);
      el.appendChild(b);
    };
    if (p.id !== P.id) btn('Öffnen', () => { switchProject(p.id); renderProjects(); });
    btn('Kopie', () => {
      const c = normalizeProject(JSON.parse(JSON.stringify(p)));
      c.id = uid();
      c.title = `${p.title || 'Suchgebiet'} (Kopie)`;
      c.created = c.updated = Date.now();
      db.projects[c.id] = c;
      switchProject(c.id);
      renderProjects();
    });
    btn('Löschen', () => {
      if (!confirm(`„${p.title || 'ohne Titel'}“ endgültig löschen?`)) return;
      delete db.projects[p.id];
      if (p.id === P.id) {
        const rest = Object.values(db.projects).sort((a, b) => b.updated - a.updated);
        if (!rest.length) {
          const n = newProject('');
          db.projects[n.id] = n;
          rest.push(n);
        }
        switchProject(rest[0].id);
      } else saveNow();
      renderProjects();
    });
    box.appendChild(el);
  }
}

$('proj-new').addEventListener('click', () => {
  const t = prompt('Name des neuen Suchgebiets:', '');
  if (t === null) return;
  const p = newProject(t.trim());
  p.layerId = P.layerId;
  p.cellM = P.cellM;
  const c = map.getCenter();
  p.view = { lat: c.lat, lon: c.lng, z: map.getZoom() };
  db.projects[p.id] = p;
  switchProject(p.id);
  renderProjects();
});

$('leader').addEventListener('input', () => { P.leader = $('leader').value; P.updated = Date.now(); save(); });
$('pdf-caption').addEventListener('input', () => { P.caption = $('pdf-caption').value; P.updated = Date.now(); save(); });
$('notes').addEventListener('input', () => { P.notes = $('notes').value; P.updated = Date.now(); save(); });
$('meet-set').addEventListener('click', () => { closePanels(); setTool('meet'); });
$('meet-remove').addEventListener('click', () => {
  if (!P.meet) return;
  snapshot();
  P.meet = null;
  changed();
  renderMeet();
});

function safeName(ext) {
  const umlaut = { ä: 'ae', ö: 'oe', ü: 'ue', Ä: 'Ae', Ö: 'Oe', Ü: 'Ue', ß: 'ss' };
  const t = (P.title.trim() || 'Suchgebiet').replace(/[äöüÄÖÜß]/g, (ch) => umlaut[ch])
    .replace(/[^\w-]+/g, '_').slice(0, 40);
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${t}_${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${ext}`;
}

$('proj-share').addEventListener('click', async () => {
  saveNow();
  const text = exportProject(P);
  const title = P.title || 'Suchgebiet';
  const msg = `Suchgebiet „${title}“ – in der App Suchgebiet-Karten unter „Gebiete → Datei öffnen“ laden.`;
  const json = new Blob([text], { type: 'application/json' });
  await shareFile(json, safeName('.suchgebiet.json'), title, msg, null, true);
});

$('proj-import').addEventListener('click', () => $('import-file').click());
$('import-file').addEventListener('change', async () => {
  const f = $('import-file').files[0];
  $('import-file').value = '';
  if (!f) return;
  try {
    const buf = await f.arrayBuffer();
    const text = new TextDecoder('latin1').decode(buf);
    // JSON-Dateien sind UTF-8, PDFs werden nur nach dem eingebetteten Block durchsucht
    const p = importProject(text.trimStart().startsWith('{') ? new TextDecoder().decode(buf) : text);
    p.updated = Date.now();
    db.projects[p.id] = p;
    switchProject(p.id);
    renderProjects();
    toast(`„${p.title || 'Suchgebiet'}“ geladen`);
  } catch (err) {
    toast('Datei konnte nicht geladen werden: ' + err.message);
  }
});

// ---------- Panels ----------
function openPanel(id) {
  closePanels();
  $(id).hidden = false;
}
function closePanels() {
  document.querySelectorAll('.panel').forEach((p) => { p.hidden = true; });
}
document.querySelectorAll('.panel .close').forEach((b) => b.addEventListener('click', closePanels));
$('btn-projects').addEventListener('click', () => { fillProjectForm(); renderProjects(); openPanel('panel-projects'); });
$('btn-grid').addEventListener('click', () => { updateGridInfo(); openPanel('panel-grid'); });
$('btn-teams').addEventListener('click', () => { renderMarks(); openPanel('panel-teams'); });
$('btn-layers').addEventListener('click', () => openPanel('panel-layers'));
$('btn-pdf').addEventListener('click', () => {
  $('pdf-caption').value = P.caption || '';
  updatePdfPlan();
  updateKmzPlan();
  $('pdf-msg').textContent = '';
  $('kmz-msg').textContent = '';
  openPanel('panel-pdf');
});

// ---------- Export (PDF, GPX, Garmin-Karte): Teilen oder Speichern ----------
// Fertige Dateien werden kurz zwischengespeichert: Der Browser erlaubt das Teilen nur
// direkt nach einem Tipp – dauert das Erstellen zu lange, reicht dann ein zweiter Tipp.
const exportCache = {};

function exportKey(extra) {
  return JSON.stringify([P.id, P.updated, P.layerId, P.showUtm, viewBounds(), extra]);
}

async function runExport(kind, btn, key, build, action) {
  const btns = [...btn.parentElement.querySelectorAll('button')];
  const label = btn.textContent;
  btns.forEach((b) => { b.disabled = true; });
  try {
    let f = exportCache[kind];
    if (!f || f.key !== key) {
      f = await build((text) => { btn.textContent = text; });
      if (!f) return;
      f.key = key;
      exportCache[kind] = f;
    }
    if (action === 'save') await saveFile(f.blob, f.name);
    else if (action === 'mail') await mailFile(f);
    else await shareFile(f.blob, f.name, f.title, f.text, f);
  } catch (err) {
    console.error(err);
    toast('Fehler: ' + err.message);
  } finally {
    btns.forEach((b) => { b.disabled = false; });
    btn.textContent = label;
    updatePdfPlan();
  }
}

// ---------- PDF ----------
function pdfOpts() {
  return {
    format: $('pdf-format').value,
    orient: $('pdf-orient').value,
    overview: $('pdf-overview').checked && !!grid,
    details: $('pdf-details').checked && !!grid,
    k: Number($('pdf-k').value),
    info: $('pdf-info').checked,
    view: $('pdf-view').checked,
    title: P.title.trim() || 'Suchgebiet',
  };
}

function viewBounds() {
  const b = map.getBounds();
  return { north: b.getNorth(), south: b.getSouth(), west: b.getWest(), east: b.getEast() };
}

function updatePdfPlan() {
  const noGrid = !grid;
  $('pdf-overview').disabled = noGrid;
  $('pdf-details').disabled = noGrid;
  if (noGrid) $('pdf-view').checked = true;
  const sheets = planSheets(grid, pdfOpts(), viewBounds());
  $('pdf-plan').textContent = sheets.length
    ? `${sheets.length} Seite${sheets.length > 1 ? 'n' : ''}: ${sheets.map((s) => s.title.replace(/^Blatt \d+ – /, '')).join(' · ')}`
    : 'Bitte mindestens eine Karte wählen.';
  $('pdf-share').disabled = !sheets.length;
  $('pdf-mail').disabled = !sheets.length;
  $('pdf-save').disabled = !sheets.length;
}
['pdf-format', 'pdf-orient', 'pdf-overview', 'pdf-details', 'pdf-k', 'pdf-info', 'pdf-view'].forEach((id) => $(id).addEventListener('change', updatePdfPlan));

function mailText(title) {
  return `Anbei die Karte zum Suchgebiet „${title}“.`
    + (grid ? `\nRaster: ${formatMeters(grid.cellM)}-Felder, A1 = Nordwest-Ecke, Felder A1 bis ${cellLabel(grid.cols - 1, grid.rows - 1)}.` : '')
    + '\nDas PDF lässt sich in der App Suchgebiet-Karten öffnen, um weiterzuarbeiten.';
}

async function buildPdfFile(progress) {
  const opts = pdfOpts();
  const res = await buildPdf(P, grid, opts, layerStack(P.layerId, activeOverlays()), viewBounds(), (i, n) => progress(`Seite ${i} von ${n} …`));
  $('pdf-msg').textContent = `✔ ${res.pages} Seite${res.pages > 1 ? 'n' : ''} (${Math.round(res.blob.size / 1024)} KB)`
    + (res.missing ? ` – ${res.missing} Kartenkacheln fehlen (keine Verbindung oder Karte nicht exportierbar)` : '');
  return {
    blob: res.blob,
    name: safeName('.pdf'),
    title: opts.title,
    text: mailText(opts.title),
    // Kein Teilen möglich (z. B. PC-Browser): herunterladen und E-Mail-Programm öffnen
    fallback(f) {
      const body = `${f.text}\n\n(Bitte die heruntergeladene Datei ${f.name} anhängen.)`;
      location.href = `mailto:?subject=${encodeURIComponent('Karte: ' + f.title)}&body=${encodeURIComponent(body)}`;
    },
  };
}
$('pdf-mail').addEventListener('click', () => runExport('pdf', $('pdf-mail'), exportKey(pdfOpts()), buildPdfFile, 'mail'));
$('pdf-share').addEventListener('click', () => runExport('pdf', $('pdf-share'), exportKey(pdfOpts()), buildPdfFile, 'share'));
$('pdf-save').addEventListener('click', () => runExport('pdf', $('pdf-save'), exportKey(pdfOpts()), buildPdfFile, 'save'));

function download(blob, name) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
}

function blobToBase64(blob) {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result).split(',')[1]);
    r.onerror = () => reject(r.error);
    r.readAsDataURL(blob);
  });
}

// Speichern: Android-App -> Ordner wählen; Browser -> Download-Ordner
async function saveFile(blob, name) {
  if (bridge && bridge.saveFile) {
    bridge.saveFile(await blobToBase64(blob), name, blob.type);
    return;
  }
  download(blob, name);
  toast(`${name} wird im Download-Ordner gespeichert.`);
}

// E-Mail mit Anhang: Android-App -> nur Mail-Apps, PDF hängt an. Browser können keine
// Anhänge an mailto: geben -> Teilen-Menü (Handy, Windows: Outlook/Mail), sonst Download + mailto
async function mailFile(f) {
  if (bridge && bridge.emailFile) {
    bridge.emailFile(await blobToBase64(f.blob), f.name, f.blob.type, `Karte: ${f.title}`, f.text);
    return;
  }
  await shareFile(f.blob, f.name, `Karte: ${f.title}`, f.text, f);
}

// Teilen: Android-App -> Teilen-Dialog; Browser -> Web Share; sonst Download (+ f.fallback)
async function shareFile(blob, name, title, text, f = null, allowTxt = false) {
  if (bridge) {
    bridge.shareFile(await blobToBase64(blob), name, blob.type, title, text);
    return true;
  }
  const tries = [new File([blob], name, { type: blob.type })];
  // Chrome teilt keine .json/.gpx/.kmz-Dateien direkt, wohl aber Text – nur für Suchgebiet-Dateien sinnvoll
  if (allowTxt) tries.push(new File([blob], name.replace(/\.json$/, '.txt'), { type: 'text/plain' }));
  for (const file of tries) {
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      try {
        await navigator.share({ files: [file], title, text });
        return true;
      } catch (err) {
        if (err.name === 'AbortError') return false;
        if (err.name === 'NotAllowedError') {
          toast('Datei ist fertig – bitte nochmal auf „Teilen“ tippen.');
          return false;
        }
      }
    }
  }
  toast('Teilen geht in diesem Browser nicht – die Datei wird heruntergeladen.');
  download(blob, name);
  if (f && f.fallback) f.fallback(f);
  return false;
}

// ---------- Garmin: GPX ----------
function gpxOpts() {
  return {
    tracks: $('gpx-tracks').checked,
    teams: $('gpx-teams').checked,
    grid: $('gpx-grid').value,
    points: $('gpx-points').checked,
    cells: $('gpx-cells').checked,
    drawings: $('gpx-drawings').checked,
  };
}

async function buildGpxFile() {
  const gpx = buildGpx(P, grid, gpxOpts());
  if (!/<(trk|wpt)[ >]/.test(gpx)) {
    toast('Nichts zum Exportieren – erst einen Track zeichnen oder ein Raster anlegen.');
    return null;
  }
  return {
    blob: new Blob([gpx], { type: 'application/gpx+xml' }),
    name: safeName('.gpx'),
    title: P.title || 'Suchgebiet',
    text: 'GPX für Garmin: in BaseCamp öffnen (Datei → Importieren) und an das Gerät senden.',
  };
}
$('gpx-share').addEventListener('click', () => runExport('gpx', $('gpx-share'), exportKey(gpxOpts()), buildGpxFile, 'share'));
$('gpx-save').addEventListener('click', () => runExport('gpx', $('gpx-save'), exportKey(gpxOpts()), buildGpxFile, 'save'));

// ---------- Garmin: Custom Map (KMZ) ----------
function kmzBounds() {
  if ($('kmz-area').value === 'grid' && grid) {
    const pad = 0.5;
    return {
      north: grid.originLat + grid.dLat * pad,
      south: grid.originLat - grid.rows * grid.dLat - grid.dLat * pad,
      west: grid.originLon - grid.dLon * pad,
      east: grid.originLon + grid.cols * grid.dLon + grid.dLon * pad,
    };
  }
  return viewBounds();
}

function updateKmzPlan() {
  if (!grid) $('kmz-area').value = 'view';
  $('kmz-area').querySelector('[value=grid]').disabled = !grid;
  const plan = planCustomMap(kmzBounds(), Number($('kmz-res').value));
  $('kmz-plan').textContent = `${plan.tiles} Kachel${plan.tiles > 1 ? 'n' : ''} · ${plan.W} × ${plan.H} Bildpunkte · `
    + `${plan.mPerPx.toLocaleString('de-DE', { maximumFractionDigits: 1 })} m pro Bildpunkt`
    + (plan.mPerPx > Number($('kmz-res').value) + 0.01 ? ' (für Garmin-Grenze vergröbert)' : '');
}
['kmz-area', 'kmz-res'].forEach((id) => $(id).addEventListener('change', updateKmzPlan));

async function buildKmzFile(progress) {
  const res = await buildCustomMap(P, grid, layerStack(P.layerId, activeOverlays()), kmzBounds(), Number($('kmz-res').value),
    (i, n) => progress(`Kachel ${i} von ${n} …`));
  $('kmz-msg').textContent = `✔ ${res.tiles} Kachel${res.tiles > 1 ? 'n' : ''} (${Math.round(res.blob.size / 1024)} KB)`
    + (res.missing ? ` – ${res.missing} Kartenkacheln fehlen (keine Verbindung oder Karte nicht exportierbar)` : '');
  return {
    blob: res.blob,
    name: safeName('.kmz'),
    title: P.title || 'Suchgebiet',
    text: 'Garmin-Karte: per USB in den Ordner Garmin/CustomMaps auf dem GPS-Gerät kopieren.',
  };
}
const kmzKey = () => exportKey([$('kmz-area').value, $('kmz-res').value]);
$('kmz-share').addEventListener('click', () => runExport('kmz', $('kmz-share'), kmzKey(), buildKmzFile, 'share'));
$('kmz-save').addEventListener('click', () => runExport('kmz', $('kmz-save'), kmzKey(), buildKmzFile, 'save'));

// ---------- Suche (Adresse, Feld, Koordinaten) ----------
let searchPin = null;

function showSearchPin(lat, lon, label) {
  if (searchPin) map.removeLayer(searchPin);
  searchPin = L.marker([lat, lon], {
    icon: L.divIcon({ className: 'search-pin', html: '📍', iconSize: [30, 30], iconAnchor: [15, 28] }),
  }).addTo(map).bindTooltip(label, { direction: 'top', offset: [0, -24] }).openTooltip();
  searchPin.on('click', () => { map.removeLayer(searchPin); searchPin = null; });
}

function closeSearch() {
  $('searchbar').hidden = true;
}

function searchResult(text) {
  const box = $('search-results');
  box.innerHTML = '';
  const p = document.createElement('p');
  p.textContent = text;
  box.appendChild(p);
}

async function runSearch() {
  const q = parseQuery($('search-input').value);
  if (!q) return;
  if (q.type === 'cell' && grid) {
    if (q.c >= grid.cols || q.r >= grid.rows) return searchResult('Dieses Feld gibt es im Raster nicht.');
    const b = cellBounds(grid, q.c, q.r);
    map.fitBounds([[b.south, b.west], [b.north, b.east]], { padding: [60, 60] });
    closeSearch();
    return;
  }
  if (q.type === 'coords') {
    map.setView([q.lat, q.lon], Math.max(map.getZoom(), 16));
    showSearchPin(q.lat, q.lon, `${q.lat.toFixed(5)}, ${q.lon.toFixed(5)}`);
    closeSearch();
    return;
  }
  searchResult('Suche läuft …');
  try {
    const list = await searchAddress(q.q || $('search-input').value.trim(), viewBounds());
    const box = $('search-results');
    box.innerHTML = '';
    if (!list.length) return searchResult('Nichts gefunden. Tipp: Ort mit angeben, z. B. „Waldweg 5, Musterstadt“.');
    for (const r of list) {
      const b = document.createElement('button');
      b.textContent = r.name;
      b.addEventListener('click', () => {
        if (r.bounds) map.fitBounds([[r.bounds[0], r.bounds[2]], [r.bounds[1], r.bounds[3]]], { maxZoom: 17 });
        else map.setView([r.lat, r.lon], 17);
        showSearchPin(r.lat, r.lon, r.name.split(',').slice(0, 2).join(','));
        closeSearch();
      });
      box.appendChild(b);
    }
    const credit = document.createElement('p');
    credit.className = 'credit';
    credit.textContent = 'Suche: © OpenStreetMap-Mitwirkende (Nominatim)';
    box.appendChild(credit);
  } catch (err) {
    searchResult(navigator.onLine === false ? 'Keine Internetverbindung – Adresssuche nicht möglich.' : `Suche fehlgeschlagen: ${err.message}`);
  }
}

$('btn-search').addEventListener('click', () => {
  const bar = $('searchbar');
  bar.hidden = !bar.hidden;
  if (!bar.hidden) {
    closePanels();
    $('search-input').focus();
    $('search-input').select();
  }
});
$('search-close').addEventListener('click', closeSearch);
$('search-form').addEventListener('submit', (e) => {
  e.preventDefault();
  runSearch();
});

// ---------- Sonstiges ----------
let toastTimer = null;
function toast(msg) {
  const t = $('toast');
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { t.hidden = true; }, 3500);
}

$('title').addEventListener('input', () => { P.title = $('title').value; P.updated = Date.now(); save(); });

if (P.view) map.setView([P.view.lat, P.view.lon], P.view.z);
else map.setView([51.1, 10.4], 6);
setLayer(P.layerId);
fillProjectForm();
renderPalette();
setTool('pan');
updateGridInfo();
resizeCanvas();

if ('serviceWorker' in navigator && location.protocol === 'https:' && !bridge) {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}

// Startmeldung (der Emulator-Test der Android-App wartet darauf)
console.info(`Suchgebiet-Karten bereit (${bridge ? 'Android-App' : 'Browser'})`);

// Für Tests
window.__app = {
  get P() { return P; }, get grid() { return grid; }, get db() { return db; }, map, setArea, setTool, saveNow,
};
