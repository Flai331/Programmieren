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
import { JUH_TEMPLATE, fillJuh } from './juh.js';
import {
  FORCE_KEYS, totalLine, usedColors, colorName, notePageImage, drawNotePage, PAGE_RATIO, shrinkPhoto, missionText,
  MAIL_PARTS, REPORT_SECTIONS, EXTRA_PARTS, hasReportText, newMailTo, mailAddresses,
} from './mission.js';
import { buildCustomMap, planCustomMap } from './kmz.js';
import { parseQuery, searchAddress, suggestPlaces, cornerBox, searchCorner } from './search.js';
import {
  newProject, normalizeProject, migrateV1, assignments, markLabel, cellOwner, cellStatus, mapFor,
  exportProject, importProject, uid, TEAM_COLORS,
} from './store.js';

// Bei jeder Änderung erhöhen (gleich wie VERSION in sw.js) – steht im Export-Fenster
const APP_VERSION = 'v27';
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
    // _getZoomForUrl berücksichtigt zoomOffset (512er-Kacheln)
    return tileUrl(this.options.def, this._getZoomForUrl(), coords.x, coords.y);
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
  // ältere Auswahl (z. B. Esri-Ebenen, die es nicht mehr gibt) -> Standard
  const known = (P.overlays || []).filter((id) => OVERLAYS.some((o) => o.id === id));
  return P.overlays && (known.length || !P.overlays.length) ? known : DEFAULT_OVERLAYS;
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
    opacity: l.opacity ?? 1,
    className: l.blend ? `blend-${l.blend}` : '',
    maxNativeZoom: l.maxNative,
    maxZoom: 20,
    attribution: l.attribution,
    // 512er-Kacheln (WMS): eine Zoomstufe versetzt, damit sie dieselbe Fläche wie 256er abdecken
    tileSize: l.tileSize || 256,
    zoomOffset: -Math.log2((l.tileSize || 256) / 256),
    // WMS rechnet langsam: erst nachladen, wenn Zoomen/Verschieben vorbei ist
    updateWhenZooming: !l.wms,
    updateWhenIdle: !!l.wms,
    keepBuffer: l.wms ? 1 : 2,
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
  pen: 'Mit dem Finger auf die Karte zeichnen. Zeichnung antippen: Namen geben (steht dann auch im GPX). Verschieben: „Bewegen“.',
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
  $('palette').querySelector('.penname').hidden = t !== 'pen';
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
let downPt = null; // Startpunkt der Berührung (Antippen erkennen)
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
  downPt = { x, y };
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
    // Antippen einer vorhandenen Zeichnung: benennen statt einen Punkt zu malen
    const tap = !cancelled && current.pts.length === 1 && Math.hypot(x - downPt.x, y - downPt.y) < 8;
    const hit = tap ? hitItem(P.items, toPx, downPt.x, downPt.y, 12) : -1;
    if (!cancelled && hit < 0) {
      snapshot();
      P.items.push(current);
    }
    current = null;
    changed();
    if (hit >= 0) renameItem(hit);
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

// Zeichnung, Track oder Textpunkt benennen (Name steht auf der Karte, im PDF und im GPX)
function renameItem(i) {
  const it = P.items[i];
  if (!it) return;
  if (it.kind === 'text') {
    const t = prompt('Text für diesen Punkt:', it.text);
    if (t === null || !t.trim() || t.trim() === it.text) return;
    snapshot();
    it.text = t.trim();
    changed();
    return;
  }
  const what = it.kind === 'track' ? 'des Tracks' : 'der Zeichnung';
  const t = prompt(`Name ${what} (steht so auf der Karte und im GPX für Garmin):`, it.name || '');
  if (t === null || t.trim() === (it.name || '')) return;
  snapshot();
  it.name = t.trim();
  changed();
  toast(it.name ? `Name „${it.name}“ gespeichert` : 'Name entfernt');
}

$('pen-name').addEventListener('click', () => {
  const i = P.items.map((it) => it.kind).lastIndexOf('stroke');
  if (i >= 0) renameItem(i);
});

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
  $('pen-name').disabled = !P.items.some((it) => it.kind === 'stroke');
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

// Deckkraft: wie stark Team-Farbe und Schraffur die Karte überdecken (Rand bleibt kräftig)
function renderAlpha() {
  const v = Math.round((P.markAlpha ?? 0.4) * 100);
  $('mark-alpha').value = String(v);
  $('mark-alpha-val').textContent = `${v} %`;
}
$('mark-alpha').addEventListener('input', () => {
  P.markAlpha = Number($('mark-alpha').value) / 100;
  P.updated = Date.now();
  renderAlpha();
  redraw();
  save();
});
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

// withTime=false: nur Datum (kürzer, z. B. als Listenname in BaseCamp)
function safeName(ext, withTime = true) {
  const umlaut = { ä: 'ae', ö: 'oe', ü: 'ue', Ä: 'Ae', Ö: 'Oe', Ü: 'Ue', ß: 'ss' };
  const t = (P.title.trim() || 'Suchgebiet').replace(/[äöüÄÖÜß]/g, (ch) => umlaut[ch])
    .replace(/[^\w-]+/g, '_').slice(0, 40);
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const date = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  return withTime ? `${t}_${date}_${pad(d.getHours())}${pad(d.getMinutes())}${ext}` : `${t}_${date}${ext}`;
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
// Zurück-Taste/-Geste im Browser: schließt Notizblock bzw. Fenster statt die Seite zu verlassen.
// Solange etwas offen ist, liegt ein zusätzlicher Verlaufseintrag oben.
function pushOverlay() {
  if (!(history.state && history.state.overlay)) history.pushState({ overlay: 1 }, '');
}
function dropOverlay() {
  if (history.state && history.state.overlay) history.back();
}
function openPanel(id) {
  document.querySelectorAll('.panel').forEach((p) => { p.hidden = true; });
  closeSearch();
  $(id).hidden = false;
  pushOverlay();
}
function closePanels() {
  document.querySelectorAll('.panel').forEach((p) => { p.hidden = true; });
  if ($('notepad').hidden) dropOverlay();
}
document.querySelectorAll('.panel .close').forEach((b) => b.addEventListener('click', closePanels));
$('btn-projects').addEventListener('click', () => { fillProjectForm(); renderProjects(); openPanel('panel-projects'); });
$('btn-grid').addEventListener('click', () => { updateGridInfo(); openPanel('panel-grid'); });
$('btn-teams').addEventListener('click', () => { renderMarks(); renderAlpha(); openPanel('panel-teams'); });
$('btn-layers').addEventListener('click', () => openPanel('panel-layers'));
$('app-version').textContent = `Version ${APP_VERSION}`;
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
    noGrid: $('pdf-nogrid').checked,
    areaLabels: 'edge',
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
['pdf-format', 'pdf-orient', 'pdf-overview', 'pdf-details', 'pdf-k', 'pdf-info', 'pdf-view', 'pdf-nogrid'].forEach((id) => $(id).addEventListener('change', updatePdfPlan));

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

// Mehrere Dateien: App -> Ordner wählen bzw. ein Teilen-Dialog; Browser -> Web Share oder Downloads
async function filesPayload(files) {
  return JSON.stringify(await Promise.all(files.map(async (f) => ({
    b64: await blobToBase64(f.blob), name: f.name, mime: f.blob.type,
  }))));
}

async function saveFiles(files) {
  if (bridge && bridge.saveFiles) {
    bridge.saveFiles(await filesPayload(files));
    return;
  }
  for (const f of files) {
    download(f.blob, f.name);
    await new Promise((r) => setTimeout(r, 400)); // Browser blockieren sonst den zweiten Download
  }
  toast(`${files.length} Dateien werden im Download-Ordner gespeichert.`);
}

async function shareFiles(files, title, text) {
  if (bridge && bridge.shareFiles) {
    bridge.shareFiles(await filesPayload(files), title, text);
    return;
  }
  const list = files.map((f) => new File([f.blob], f.name, { type: f.blob.type }));
  if (navigator.canShare && navigator.canShare({ files: list })) {
    try {
      await navigator.share({ files: list, title, text });
      return;
    } catch (err) {
      if (err.name === 'AbortError') return;
    }
  }
  toast('Teilen geht hier nicht – die Dateien werden heruntergeladen.');
  await saveFiles(files);
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
// Zwei GPX-Dateien = zwei Listen in BaseCamp: Raster und Markierungen
function gpxGridOpts() {
  return { grid: $('gpx-grid').value, cells: $('gpx-cells').value };
}

function gpxMarkOpts() {
  return {
    tracks: $('gpx-tracks').checked,
    drawings: $('gpx-drawings').checked,
    teams: $('gpx-teams').checked,
    points: $('gpx-points').checked,
  };
}

function gpxBuilder(opts, part, empty) {
  return async () => {
    const gpx = buildGpx(P, grid, opts, part);
    if (!/<(trk|wpt)[ >]/.test(gpx)) {
      toast(empty);
      return null;
    }
    return {
      blob: new Blob([gpx], { type: 'application/gpx+xml' }),
      // Dateiname = Listenname in BaseCamp
      name: safeName(`_${part}.gpx`, false),
      title: `${P.title || 'Suchgebiet'} – ${part}`,
      text: 'GPX für Garmin: in BaseCamp öffnen (Datei → In „Meine Sammlung“ importieren) und an das Gerät senden.',
    };
  };
}

const gridGpx = () => gpxBuilder(gpxGridOpts(), 'Raster', 'Kein Raster vorhanden – erst ein Raster anlegen.');
const markGpx = () => gpxBuilder(gpxMarkOpts(), 'Markierungen', 'Keine Markierungen vorhanden.');
// „Alles für BaseCamp“: beide GPX-Dateien auf einmal (in BaseCamp je eine Liste)
async function runExportAll(btn, action) {
  const btns = [...btn.parentElement.querySelectorAll('button')];
  btns.forEach((b) => { b.disabled = true; });
  try {
    const files = [];
    for (const build of [gridGpx(), markGpx()]) {
      const f = await build();
      if (f) files.push(f);
    }
    if (!files.length) return;
    if (action === 'save') await saveFiles(files);
    else await shareFiles(files, `${P.title || 'Suchgebiet'} – GPX`, files[0].text);
  } catch (err) {
    console.error(err);
    toast('Fehler: ' + err.message);
  } finally {
    btns.forEach((b) => { b.disabled = false; });
  }
}
$('gpx-all-share').addEventListener('click', () => runExportAll($('gpx-all-share'), 'share'));
$('gpx-all-save').addEventListener('click', () => runExportAll($('gpx-all-save'), 'save'));

$('gpx-grid-share').addEventListener('click', () => runExport('gpx-grid', $('gpx-grid-share'), exportKey(gpxGridOpts()), gridGpx(), 'share'));
$('gpx-grid-save').addEventListener('click', () => runExport('gpx-grid', $('gpx-grid-save'), exportKey(gpxGridOpts()), gridGpx(), 'save'));
$('gpx-share').addEventListener('click', () => runExport('gpx', $('gpx-share'), exportKey(gpxMarkOpts()), markGpx(), 'share'));
$('gpx-save').addEventListener('click', () => runExport('gpx', $('gpx-save'), exportKey(gpxMarkOpts()), markGpx(), 'save'));

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

// ---------- Einsatzprotokoll ----------
const M = () => P.mission;
function touch() { P.updated = Date.now(); save(); }

function renderForces() {
  const box = $('ms-forces');
  box.innerHTML = '';
  M().forces.forEach((f, i) => {
    const row = document.createElement('div');
    row.className = 'force';
    const field = (key, label, cls, type = 'number') => {
      const l = document.createElement('label');
      if (cls) l.className = cls;
      l.innerHTML = `<small>${label}</small><input type="${type}" ${type === 'number' ? 'min="0" inputmode="numeric"' : ''}>`;
      const inp = l.querySelector('input');
      inp.value = f[key] ?? '';
      if (key === 'org') inp.placeholder = 'z. B. DRK RHS Celle, Feuerwehr, Polizei';
      inp.addEventListener('input', () => { f[key] = type === 'number' ? inp.value : inp.value; touch(); renderTotal(); });
      row.appendChild(l);
    };
    field('org', 'Organisation', 'org', 'text');
    // „eigene“ Organisation (für das JUH-Formular: eigene/fremde Kräfte)
    const own = document.createElement('label');
    own.className = 'own';
    own.innerHTML = '<input type="checkbox"> eigene';
    own.querySelector('input').checked = !!f.own || (!M().forces.some((x) => x.own) && i === 0);
    own.querySelector('input').addEventListener('change', (e) => {
      if (!M().forces.some((x) => x.own)) M().forces[0].own = true; // bisher stillschweigend die erste
      f.own = e.target.checked;
      touch();
      renderForces();
    });
    row.querySelector('.org small').appendChild(own);
    FORCE_KEYS.forEach(([k, l]) => field(k, l));
    const del = document.createElement('button');
    del.textContent = '✕';
    del.title = 'Zeile löschen';
    del.addEventListener('click', () => { M().forces.splice(i, 1); touch(); renderForces(); });
    row.appendChild(del);
    box.appendChild(row);
  });
  renderTotal();
}
function renderTotal() {
  $('ms-total').textContent = M().forces.length ? totalLine(M().forces) : '';
}
$('ms-force-add').addEventListener('click', () => {
  M().forces.push({ org: '', lead: '', helpers: '', dogs: '', vehicles: '' });
  touch();
  renderForces();
  const inputs = $('ms-forces').querySelectorAll('.org input');
  inputs[inputs.length - 1].focus();
});

// Quellen für die Zusammenfassung: getippte Notizen, Notizblock-Seiten, Fotos
function sources() {
  const out = [];
  if ((P.notes || '').trim()) out.push({ title: 'Getippte Notizen', text: P.notes.trim() });
  M().pages.forEach((p, i) => { if (p.strokes.length) out.push({ title: `Notizblock Seite ${i + 1}`, page: p, idx: i }); });
  M().photos.forEach((p, i) => out.push({ title: `Foto ${i + 1}`, src: p.src, photo: i }));
  return out;
}

function renderThumbs() {
  const box = $('ms-thumbs');
  box.innerHTML = '';
  const add = (src, label, open, remove) => {
    const d = document.createElement('div');
    d.className = 'thumb';
    d.innerHTML = '<img alt=""><small></small><button title="Löschen">✕</button>';
    d.querySelector('img').src = src;
    d.querySelector('small').textContent = label;
    d.querySelector('img').addEventListener('click', open);
    d.querySelector('button').addEventListener('click', remove);
    box.appendChild(d);
  };
  M().pages.forEach((p, i) => {
    if (!p.strokes.length) return;
    add(notePageImage(p, 160), `Seite ${i + 1}`, () => openPad(i), () => {
      if (!confirm(`Notizblock-Seite ${i + 1} löschen?`)) return;
      M().pages.splice(i, 1);
      touch();
      renderThumbs();
    });
  });
  M().photos.forEach((p, i) => add(p.src, `Foto ${i + 1}`, () => { showTab('ende'); viewIdx = sources().findIndex((s) => s.photo === i); renderViewer(); }, () => {
    if (!confirm(`Foto ${i + 1} löschen?`)) return;
    M().photos.splice(i, 1);
    touch();
    renderThumbs();
  }));
}

$('ms-photo').addEventListener('click', () => $('ms-photo-file').click());
$('ms-photo-file').addEventListener('change', async () => {
  const f = $('ms-photo-file').files[0];
  $('ms-photo-file').value = '';
  if (!f) return;
  try {
    M().photos.push({ t: Date.now(), src: await shrinkPhoto(f) });
    touch();
    saveNow();
    renderThumbs();
    toast('Foto gespeichert');
  } catch (err) {
    toast('Foto: ' + err.message);
  }
});

let viewIdx = 0;
function renderViewer() {
  const list = sources();
  viewIdx = Math.max(0, Math.min(viewIdx, list.length - 1));
  const s = list[viewIdx];
  const box = $('ms-view');
  box.innerHTML = '';
  $('ms-prev').disabled = viewIdx <= 0;
  $('ms-next').disabled = viewIdx >= list.length - 1;
  if (!s) {
    $('ms-view-title').textContent = 'Keine Notizen';
    box.innerHTML = '<pre>Noch keine Notizen, Notizblock-Seiten oder Fotos.</pre>';
    return;
  }
  $('ms-view-title').textContent = `${s.title} (${viewIdx + 1}/${list.length})`;
  if (s.text) {
    const pre = document.createElement('pre');
    pre.textContent = s.text;
    box.appendChild(pre);
  } else {
    const img = document.createElement('img');
    img.src = s.page ? notePageImage(s.page, 2000) : s.src; // Seiten scharf genug zum Zoomen
    img.draggable = false;
    box.appendChild(img);
  }
  setZoom(1);
}
$('ms-prev').addEventListener('click', () => { viewIdx--; renderViewer(); });
$('ms-next').addEventListener('click', () => { viewIdx++; renderViewer(); });

// Zoomen: Knöpfe, Zwei-Finger-Geste, Doppeltippen, Strg+Mausrad. Verschieben = Scrollen.
let zoom = 1;
function setZoom(z, cx, cy) {
  const box = $('ms-view');
  const img = box.querySelector('img');
  const old = zoom;
  zoom = Math.max(1, Math.min(6, z));
  $('ms-zoom-fit').textContent = `${Math.round(zoom * 100)} %`;
  if (!img) return;
  // Punkt unter Finger/Maus (cx, cy relativ zur Box) bleibt an seiner Stelle
  const r = box.getBoundingClientRect();
  const px = cx ?? r.width / 2;
  const py = cy ?? r.height / 2;
  const ix = (box.scrollLeft + px) / old;
  const iy = (box.scrollTop + py) / old;
  img.style.width = `${zoom * 100}%`;
  box.scrollLeft = ix * zoom - px;
  box.scrollTop = iy * zoom - py;
}
$('ms-zoom-in').addEventListener('click', () => setZoom(zoom * 1.5));
$('ms-zoom-out').addEventListener('click', () => setZoom(zoom / 1.5));
$('ms-zoom-fit').addEventListener('click', () => setZoom(1));
$('ms-zoom-full').addEventListener('click', () => {
  const v = document.querySelector('#panel-mission .viewer');
  const full = v.classList.toggle('full');
  $('ms-zoom-full').textContent = full ? '✕ Schließen' : '⛶ Vollbild';
  setZoom(zoom);
});
{
  const box = $('ms-view');
  const pts = new Map();
  let pinch = null;
  let lastTap = 0;
  const local = (e) => { const r = box.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
  box.addEventListener('pointerdown', (e) => {
    if (e.pointerType === 'mouse') return;
    pts.set(e.pointerId, local(e));
    if (pts.size === 2) {
      const [a, b] = [...pts.values()];
      pinch = { d: Math.hypot(a[0] - b[0], a[1] - b[1]) || 1, z: zoom };
    } else if (pts.size === 1) {
      const now = Date.now();
      if (now - lastTap < 300) { const [x, y] = local(e); setZoom(zoom > 1.2 ? 1 : 2.5, x, y); }
      lastTap = now;
    }
  });
  box.addEventListener('pointermove', (e) => {
    if (!pts.has(e.pointerId)) return;
    pts.set(e.pointerId, local(e));
    if (pinch && pts.size === 2) {
      e.preventDefault();
      const [a, b] = [...pts.values()];
      const d = Math.hypot(a[0] - b[0], a[1] - b[1]);
      setZoom(pinch.z * (d / pinch.d), (a[0] + b[0]) / 2, (a[1] + b[1]) / 2);
    }
  });
  const up = (e) => { pts.delete(e.pointerId); if (pts.size < 2) pinch = null; };
  box.addEventListener('pointerup', up);
  box.addEventListener('pointercancel', up);
  box.addEventListener('wheel', (e) => {
    if (!e.ctrlKey && !e.metaKey) return;
    e.preventDefault();
    const [x, y] = local(e);
    setZoom(zoom * (e.deltaY < 0 ? 1.2 : 1 / 1.2), x, y);
  }, { passive: false });
}

function renderLegend() {
  const box = $('ms-legend');
  box.innerHTML = '';
  const colors = usedColors(P);
  if (!colors.length) {
    box.innerHTML = '<p class="small">Noch keine Stift-Zeichnungen oder Tracks auf der Karte. Teams und Status stehen ohnehin in der Legende.</p>';
    return;
  }
  for (const c of colors) {
    const row = document.createElement('div');
    row.className = 'legrow';
    row.innerHTML = '<i></i><input type="text">';
    row.querySelector('i').style.background = c;
    const inp = row.querySelector('input');
    inp.placeholder = `Bedeutung von ${colorName(c)}, z. B. Spur, Bachlauf, Absperrung`;
    inp.value = M().legend[c] || '';
    inp.addEventListener('input', () => { M().legend[c] = inp.value; touch(); });
    box.appendChild(row);
  }
}

function endFullView() {
  const v = document.querySelector('#panel-mission .viewer');
  if (v.classList.contains('full')) { v.classList.remove('full'); $('ms-zoom-full').textContent = '⛶ Vollbild'; }
}
function showTab(t) {
  endFullView();
  document.querySelectorAll('#panel-mission .tabs button').forEach((b) => b.classList.toggle('active', b.dataset.tab === t));
  $('tab-lage').hidden = t !== 'lage';
  $('tab-ende').hidden = t !== 'ende';
  db.missionTab = t;
  if (t === 'ende') { renderViewer(); renderLegend(); }
}
document.querySelectorAll('#panel-mission .tabs button').forEach((b) => b.addEventListener('click', () => showTab(b.dataset.tab)));

function renderMission() {
  $('ms-person').value = M().person;
  $('notes').value = P.notes || '';
  $('ms-summary').value = M().summary;
  if (!M().author && P.leader) M().author = P.leader;
  $('ms-author').value = M().author;
  renderMailTo();
  $('ms-msg').textContent = '';
  renderForces();
  renderThumbs();
  showTab(db.missionTab || 'lage');
}
$('btn-mission').addEventListener('click', () => { renderMission(); openPanel('panel-mission'); });
[['ms-person', 'person'], ['ms-summary', 'summary'], ['ms-author', 'author']].forEach(([id, key]) => {
  $(id).addEventListener('input', () => { M()[key] = $(id).value; touch(); });
});

// Notizblock: Seiten mit Stift/Finger beschreiben, Punkte in Seitenbreiten gespeichert
let padIdx = 0;
let padColor = '#000000';
let padStroke = null;
const padCanvas = $('pad-canvas');

function padSize() {
  const wrap = padCanvas.parentElement;
  const w = Math.max(200, Math.min(wrap.clientWidth - 20, (wrap.clientHeight - 20) / PAGE_RATIO));
  const dpr = window.devicePixelRatio || 1;
  padCanvas.style.width = `${w}px`;
  padCanvas.style.height = `${w * PAGE_RATIO}px`;
  padCanvas.width = Math.round(w * dpr);
  padCanvas.height = Math.round(w * PAGE_RATIO * dpr);
  return w;
}
function padDraw() {
  const page = M().pages[padIdx];
  const c = padCanvas.getContext('2d');
  drawNotePage(c, padStroke ? { strokes: [...page.strokes, padStroke] } : page, padCanvas.width);
  $('pad-title').textContent = `Seite ${padIdx + 1} von ${M().pages.length}`;
  $('pad-prev').disabled = padIdx === 0;
  $('pad-next').disabled = padIdx >= M().pages.length - 1;
  $('pad-undo').disabled = !page.strokes.length;
}
function openPad(i) {
  pushOverlay();
  if (!M().pages.length) M().pages.push({ t: Date.now(), strokes: [] });
  padIdx = Math.max(0, Math.min(i ?? M().pages.length - 1, M().pages.length - 1));
  $('notepad').hidden = false;
  padSize();
  padDraw();
}
function closePad() {
  // leere Seiten nicht aufheben
  M().pages = M().pages.filter((p) => p.strokes.length);
  $('notepad').hidden = true;
  touch();
  saveNow();
  renderThumbs();
  // Fenster darunter noch offen -> Verlaufseintrag behalten, sonst entfernen
  if (![...document.querySelectorAll('.panel')].some((p) => !p.hidden)) dropOverlay();
}
window.addEventListener('popstate', () => {
  const panelOpen = () => [...document.querySelectorAll('.panel')].some((p) => !p.hidden);
  if (document.querySelector('#panel-mission .viewer.full')) {
    endFullView();
    pushOverlay();
  } else if (!$('notepad').hidden) {
    closePad();
    if (panelOpen()) pushOverlay(); // Einsatz-Fenster bleibt offen, nächstes Zurück schließt es
  } else if (panelOpen()) {
    document.querySelectorAll('.panel').forEach((p) => { p.hidden = true; });
  }
});
$('ms-pad').addEventListener('click', () => openPad());
$('pad-done').addEventListener('click', closePad);
$('pad-prev').addEventListener('click', () => { padIdx--; padDraw(); });
$('pad-next').addEventListener('click', () => { padIdx++; padDraw(); });
$('pad-new').addEventListener('click', () => {
  const pages = M().pages;
  if (!pages[pages.length - 1].strokes.length) { padIdx = pages.length - 1; padDraw(); return; }
  pages.push({ t: Date.now(), strokes: [] });
  padIdx = pages.length - 1;
  touch();
  padDraw();
});
$('pad-undo').addEventListener('click', () => { M().pages[padIdx].strokes.pop(); touch(); padDraw(); });
$('pad-del').addEventListener('click', () => {
  if (!M().pages[padIdx].strokes.length || !confirm('Diese Seite leeren?')) return;
  M().pages[padIdx].strokes = [];
  touch();
  padDraw();
});
document.querySelectorAll('.padcolors button').forEach((b) => b.addEventListener('click', () => {
  padColor = b.dataset.c;
  document.querySelectorAll('.padcolors button').forEach((x) => x.classList.toggle('active', x === b));
}));
const padPt = (e) => {
  const r = padCanvas.getBoundingClientRect();
  return [(e.clientX - r.left) / r.width, (e.clientY - r.top) / r.width];
};
padCanvas.addEventListener('pointerdown', (e) => {
  if (padStroke) return;
  padCanvas.setPointerCapture(e.pointerId);
  padStroke = { color: padColor, w: e.pointerType === 'pen' ? 0.0025 : 0.003, pts: [padPt(e)], id: e.pointerId };
  padDraw();
});
padCanvas.addEventListener('pointermove', (e) => {
  if (!padStroke || e.pointerId !== padStroke.id) return;
  const p = padPt(e);
  const last = padStroke.pts[padStroke.pts.length - 1];
  if (Math.hypot(p[0] - last[0], p[1] - last[1]) < 0.002) return;
  padStroke.pts.push([+p[0].toFixed(4), +p[1].toFixed(4)]);
  padDraw();
});
const padEnd = (e) => {
  if (!padStroke || e.pointerId !== padStroke.id) return;
  const { id, ...s } = padStroke;
  void id;
  padStroke = null;
  M().pages[padIdx].strokes.push(s);
  touch();
  padDraw();
};
padCanvas.addEventListener('pointerup', padEnd);
padCanvas.addEventListener('pointercancel', padEnd);
window.addEventListener('resize', () => { if (!$('notepad').hidden) { padSize(); padDraw(); } });

// Abschlussbericht der App (ohne Karte) mit den angekreuzten Inhalten
async function reportPdf(sec, progress) {
  const parts = { ...sec, legend: false };
  const hasPad = parts.pad && M().pages.some((pg) => pg.strokes.length);
  const hasPhotos = parts.photos && M().photos.length;
  if (!hasReportText(parts) && !hasPad && !hasPhotos) return null;
  progress('Bericht wird erstellt …');
  const opts = { ...pdfOpts(), orient: 'portrait', noMap: true, report: parts, title: `Einsatzbericht ${P.title.trim() || 'Suchgebiet'}` };
  const res = await buildPdf(P, grid, opts, layerStack(P.layerId, activeOverlays()), viewBounds(), () => {});
  return { blob: res.blob, name: safeName(hasReportText(parts) ? '_Abschlussbericht.pdf' : '_Notizen.pdf'), title: opts.title, pages: res.pages };
}

async function buildReportFile(progress) {
  const f = await reportPdf({}, progress);
  $('ms-msg').textContent = `✔ Abschlussbericht mit ${f.pages} Seite${f.pages > 1 ? 'n' : ''} (${Math.round(f.blob.size / 1024)} KB)`;
  return { ...f, text: missionText(P, grid, 'Abschlussbericht im Anhang (PDF).') };
}
const reportKey = () => exportKey(['report', $('pdf-format').value]);
$('ms-share').addEventListener('click', () => runExport('report', $('ms-share'), reportKey(), buildReportFile, 'share'));
$('ms-save').addEventListener('click', () => runExport('report', $('ms-save'), reportKey(), buildReportFile, 'save'));

// JUH-Vorlage ausgefüllt (Felder bleiben beschreibbar)
async function juhFile(progress) {
  progress('JUH-Formular …');
  const res = await fetch(JUH_TEMPLATE);
  if (!res.ok) throw new Error('JUH-Vorlage nicht gefunden');
  const bytes = await fillJuh(new Uint8Array(await res.arrayBuffer()), P);
  return {
    blob: new Blob([bytes], { type: 'application/pdf' }),
    name: safeName('_JUH-Einsatzbericht.pdf'),
    title: `JUH-Einsatzbericht ${P.title.trim() || 'Suchgebiet'}`,
    text: 'JUH-Einsatzbericht Rettungshundestaffel – vorausgefüllt, alle Felder sind weiter ausfüllbar.',
  };
}
const juhKey = () => exportKey(['juh']);
$('ms-juh-share').addEventListener('click', () => runExport('juh', $('ms-juh-share'), juhKey(), juhFile, 'share'));
$('ms-juh-save').addEventListener('click', () => runExport('juh', $('ms-juh-save'), juhKey(), juhFile, 'save'));

// Empfänger: je Zeile Adresse(n) und Häkchen, was mitgeht
function renderMailTo() {
  const box = $('ms-mailto');
  box.innerHTML = '';
  if (!M().mailTo.length) M().mailTo.push(newMailTo());
  M().mailTo.forEach((row, i) => {
    const el = document.createElement('div');
    el.className = 'mrow';
    el.innerHTML = '<div class="top"><input type="text" inputmode="email"><button class="del" title="Zeile löschen">✕</button></div><div class="groups"></div><button class="send primary"></button>';
    const inp = el.querySelector('input');
    inp.value = row.to;
    inp.placeholder = 'z. B. staffel@example.org, leitung@example.org';
    inp.addEventListener('input', () => { row.to = inp.value; touch(); });
    const group = (title, list) => {
      const g = document.createElement('div');
      g.className = 'parts';
      g.innerHTML = '<b></b>';
      g.querySelector('b').textContent = title;
      for (const [k, label] of list) {
        const l = document.createElement('label');
        l.innerHTML = '<input type="checkbox"><span></span>';
        l.querySelector('input').checked = !!row[k];
        l.querySelector('span').textContent = label;
        l.querySelector('input').addEventListener('change', (e) => { row[k] = e.target.checked; touch(); });
        g.appendChild(l);
      }
      el.querySelector('.groups').appendChild(g);
    };
    group('Abschlussbericht:', REPORT_SECTIONS);
    group('Zusätzlich:', EXTRA_PARTS);
    el.querySelector('.del').addEventListener('click', () => {
      if (row.to.trim() && !confirm(`Empfänger „${row.to}“ entfernen?`)) return;
      M().mailTo.splice(i, 1);
      touch();
      renderMailTo();
    });
    const send = el.querySelector('.send');
    send.textContent = '📧 Senden';
    send.addEventListener('click', () => sendMailRow(row, send));
    box.appendChild(el);
  });
}
$('ms-mailto-add').addEventListener('click', () => {
  M().mailTo.push(newMailTo());
  touch();
  renderMailTo();
  const ins = $('ms-mailto').querySelectorAll('.top input');
  ins[ins.length - 1].focus();
});

// Dateien einer Zeile bauen (zwischengespeichert, falls das Teilen einen zweiten Tipp braucht)
const mailCache = new Map();
async function mailFiles(row, progress) {
  const key = exportKey(['mail', $('pdf-format').value, ...MAIL_PARTS.map(([k]) => !!row[k])]);
  if (mailCache.has(key)) return mailCache.get(key);
  const files = [];
  const pdf = await reportPdf(row, progress);
  if (pdf) files.push(pdf);
  if (row.juh) files.push(await juhFile(progress));
  if (row.gpx) {
    for (const build of [gridGpx(), markGpx()]) {
      const f = await build();
      if (f) files.push(f);
    }
  }
  mailCache.set(key, files);
  return files;
}

async function sendMailRow(row, btn) {
  const to = mailAddresses(row);
  if (!MAIL_PARTS.some(([k]) => row[k])) { toast('Bitte ankreuzen, was mitgeschickt werden soll.'); return; }
  if (!to.length && !confirm('Keine gültige E-Mail-Adresse in dieser Zeile. Trotzdem senden?')) return;
  const label = btn.textContent;
  btn.disabled = true;
  try {
    const files = await mailFiles(row, (t) => { btn.textContent = t; });
    if (!files.length) { toast('Nichts zum Senden – keine Notizblock-Seiten/Fotos bzw. kein Raster vorhanden.'); return; }
    const names = files.map((f) => f.name).join(', ');
    const text = missionText(P, grid, `Im Anhang: ${names}`, row);
    const title = `Einsatzbericht ${P.title.trim() || 'Suchgebiet'}`;
    if (bridge && bridge.emailFilesTo) {
      bridge.emailFilesTo(await filesPayload(files), title, text, to.join(','));
    } else if (bridge) {
      bridge.shareFiles(await filesPayload(files), title, text);
    } else {
      if (to.length && navigator.clipboard) {
        try {
          await navigator.clipboard.writeText(to.join(', '));
          toast('Empfänger kopiert – im Mailprogramm ins „An“-Feld einfügen.');
        } catch { /* Zwischenablage nicht erlaubt */ }
      }
      const list = files.map((f) => new File([f.blob], f.name, { type: f.blob.type }));
      let shared = false;
      if (navigator.canShare && navigator.canShare({ files: list })) {
        try {
          await navigator.share({ files: list, title, text });
          shared = true;
        } catch (err) {
          if (err.name === 'AbortError') return;
          if (err.name === 'NotAllowedError') { toast('Dateien sind fertig – bitte nochmal auf „Senden“ tippen.'); return; }
        }
      }
      if (!shared) {
        // PC: Dateien herunterladen, Mailprogramm mit Empfängern und Text öffnen
        for (const f of files) { download(f.blob, f.name); await new Promise((r) => setTimeout(r, 400)); }
        const body = `${text}\n\n(Bitte die heruntergeladenen Dateien anhängen: ${files.map((f) => f.name).join(', ')})`;
        location.href = `mailto:${to.map(encodeURIComponent).join(',')}?subject=${encodeURIComponent(title)}&body=${encodeURIComponent(body)}`;
      }
    }
    btn.classList.add('done');
    btn.textContent = '✔ Gesendet – nochmal senden';
    return;
  } catch (err) {
    console.error(err);
    toast('Fehler: ' + err.message);
  } finally {
    btn.disabled = false;
  }
  btn.textContent = label;
}

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

function goToPlace(r) {
  if (r.bounds && r.bounds[0] !== r.bounds[1]) {
    map.fitBounds([[r.bounds[0], r.bounds[2]], [r.bounds[1], r.bounds[3]]], { maxZoom: 17 });
  } else map.setView([r.lat, r.lon], 17);
  showSearchPin(r.lat, r.lon, r.name);
  closeSearch();
}

// Trefferliste: [{name, sub, go()}]
let shownResults = [];
function showResults(list, credit) {
  shownResults = list;
  const box = $('search-results');
  box.innerHTML = '';
  for (const r of list) {
    const b = document.createElement('button');
    b.innerHTML = '<b></b><small></small>';
    b.querySelector('b').textContent = r.name;
    b.querySelector('small').textContent = r.sub || '';
    // pointerdown statt click: kommt vor dem Schließen der Handy-Tastatur
    b.addEventListener('pointerdown', (e) => { e.preventDefault(); $('search-input').blur(); r.go(); });
    box.appendChild(b);
  }
  if (credit) {
    const p = document.createElement('p');
    p.className = 'credit';
    p.textContent = credit;
    box.appendChild(p);
  }
  $('searchbar').hidden = !list.length && !credit;
}

// Sofort-Vorschläge für Feldnamen und Koordinaten (ohne Internet)
function localResult(q) {
  if (q.type === 'cell' && grid && q.c < grid.cols && q.r < grid.rows) {
    const label = cellLabel(q.c, q.r);
    return {
      name: `Feld ${label}`,
      sub: 'im Raster anzeigen',
      go() {
        const b = cellBounds(grid, q.c, q.r);
        map.fitBounds([[b.south, b.west], [b.north, b.east]], { padding: [60, 60] });
        closeSearch();
      },
    };
  }
  if (q.type === 'coords') {
    return {
      name: `${q.lat.toFixed(5)}, ${q.lon.toFixed(5)}`,
      sub: 'Koordinaten anzeigen',
      go() {
        map.setView([q.lat, q.lon], Math.max(map.getZoom(), 16));
        showSearchPin(q.lat, q.lon, `${q.lat.toFixed(5)}, ${q.lon.toFixed(5)}`);
        closeSearch();
      },
    };
  }
  return null;
}

const asResult = (r) => ({ ...r, go: () => goToPlace(r) });
let suggestTimer = null;
let suggestAbort = null;

// Kreuzung („Hauptstraße Ecke Bahnhofstraße, Celle“): erst auf Enter/Antippen suchen,
// die Overpass API ist für Abfragen bei jedem Tastendruck zu schwer
const cornerEntry = (q) => ({
  name: `Kreuzung suchen: ${q.a} / ${q.b}`,
  sub: q.place ? `in ${q.place}` : 'rund 10 km um die Kartenmitte – oder Ort mit Komma anhängen',
  go: () => findCorner(q),
});

async function findCorner(q) {
  if (suggestAbort) suggestAbort.abort();
  suggestAbort = new AbortController();
  const { signal } = suggestAbort;
  showResults([], `Suche Kreuzung ${q.a} / ${q.b} …`);
  const c = map.getCenter();
  try {
    let ref = { lat: c.lat, lon: c.lng };
    let bounds = null;
    if (q.place) {
      const places = await suggestPlaces(q.place, ref, signal);
      if (!places.length) { showResults([], `Ort „${q.place}“ nicht gefunden.`); return; }
      ref = { lat: places[0].lat, lon: places[0].lon };
      bounds = places[0].bounds;
    }
    const list = await searchCorner(q.a, q.b, cornerBox(ref, bounds), ref, signal);
    if (signal.aborted) return;
    if (!list.length) {
      showResults([], `Keine Kreuzung ${q.a} / ${q.b} gefunden${q.place ? ` in ${q.place}` : ' im Umkreis von 10 km'}. `
        + `Tipp: Straßennamen prüfen${q.place ? '' : ' oder den Ort mit Komma anhängen, z. B. „…, Celle“'}.`);
      return;
    }
    if (list.length === 1) {
      goToPlace(list[0]);
      toast(`${list[0].name} – ${list[0].sub}`);
      return;
    }
    showResults(list.map(asResult), 'Kreuzungen: © OpenStreetMap-Mitwirkende (Overpass API)');
  } catch (err) {
    if (err.name === 'AbortError') return;
    const msg = err.message.startsWith('Kreuzungssuche') ? err.message : `Kreuzungssuche fehlgeschlagen: ${err.message}`;
    showResults([], navigator.onLine === false ? 'Keine Internetverbindung – Kreuzungssuche nicht möglich.' : msg);
  }
}

async function updateSuggestions(immediate = false) {
  clearTimeout(suggestTimer);
  if (suggestAbort) suggestAbort.abort();
  const text = $('search-input').value.trim();
  const q = parseQuery(text);
  if (!q) { closeSearch(); return; }
  const local = localResult(q);
  if (local) { showResults([local]); return; }
  if (q.type === 'corner') {
    if (immediate) await findCorner(q);
    else showResults([cornerEntry(q)]);
    return;
  }
  if (q.type !== 'address' || text.length < 3) { closeSearch(); return; }
  const run = async () => {
    suggestAbort = new AbortController();
    const c = map.getCenter();
    try {
      const list = await suggestPlaces(text, { lat: c.lat, lon: c.lng }, suggestAbort.signal);
      if ($('search-input').value.trim() !== text) return; // inzwischen weitergetippt
      if (list.length) showResults(list.map(asResult), 'Vorschläge: © OpenStreetMap-Mitwirkende (Photon)');
      else showResults([], 'Nichts gefunden. Tipp: Ort mit angeben, z. B. „Waldweg 5, Musterstadt“.');
    } catch (err) {
      if (err.name === 'AbortError') return;
      if (!immediate) return; // beim Tippen still bleiben, Enter versucht es nochmal
      try {
        // Ersatz: Nominatim (nur auf Knopfdruck erlaubt)
        const list = await searchAddress(text, viewBounds());
        showResults(list.map(asResult), list.length ? 'Suche: © OpenStreetMap-Mitwirkende (Nominatim)' : 'Nichts gefunden.');
      } catch (err2) {
        showResults([], navigator.onLine === false ? 'Keine Internetverbindung – Adresssuche nicht möglich.' : `Suche fehlgeschlagen: ${err2.message}`);
      }
    }
  };
  if (immediate) await run();
  else suggestTimer = setTimeout(run, 250);
}

$('search-input').addEventListener('input', () => updateSuggestions(false));
$('search-input').addEventListener('focus', () => { if (shownResults.length) $('searchbar').hidden = false; });
$('search-close').addEventListener('click', closeSearch);
// Vorschläge schließen, sobald man mit der Karte arbeitet
map.on('movestart click', closeSearch);
canvas.addEventListener('pointerdown', closeSearch);
$('search-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  closePanels();
  const q = parseQuery($('search-input').value);
  if (!q) return;
  const local = localResult(q);
  if (local) { $('search-input').blur(); local.go(); return; }
  if (q.type === 'cell' && grid) { toast('Dieses Feld gibt es im Raster nicht.'); return; }
  // Enter: ersten Vorschlag nehmen, sonst sofort suchen
  if (shownResults.length && !$('searchbar').hidden) {
    $('search-input').blur();
    shownResults[0].go();
    return;
  }
  showResults([], 'Suche läuft …');
  await updateSuggestions(true);
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
  navigator.serviceWorker.register('sw.js', { updateViaCache: 'none' }).catch(() => {});
  // Neue Version installiert -> Hinweis (Daten sind gespeichert, Neuladen ist gefahrlos)
  let hadController = !!navigator.serviceWorker.controller;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (hadController) toast('Neue Version da – bitte die Seite einmal neu laden.');
    hadController = true;
  });
}

// Startmeldung (der Emulator-Test der Android-App wartet darauf)
console.info(`Suchgebiet-Karten bereit (${bridge ? 'Android-App' : 'Browser'})`);

// Für Tests
window.__app = {
  get P() { return P; }, get grid() { return grid; }, get db() { return db; }, map, setArea, setTool, saveNow,
};
