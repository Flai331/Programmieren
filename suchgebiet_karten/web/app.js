import {
  makeGrid, cellCount, cellAt, cellBounds, cellLabel, parseCell, formatMeters, MAX_CELLS,
} from './grid.js';
import { drawOverlay, hitItem } from './render.js';
import { LAYERS, layerById } from './layers.js';
import { buildPdf, planSheets } from './pdf.js';

const STORE_KEY = 'suchgebiet-karten-v1';
const COLORS = ['#d50000', '#1565c0', '#2e7d32', '#ef6c00', '#6a1b9a', '#000000', '#fdd835'];

const $ = (id) => document.getElementById(id);

// ---------- Zustand ----------
const state = {
  title: '',
  layerId: 'osm',
  cellM: 100,
  area: null, // {north, south, west, east}
  grid: null, // abgeleitet aus area + cellM
  fills: {}, // "c,r" -> Farbe
  items: [], // Zeichnungen (Striche, Texte) in lat/lon
  color: COLORS[0],
  w: 5,
  view: null,
};
let tool = 'pan';
let undoStack = [];

function load() {
  try {
    const s = JSON.parse(localStorage.getItem(STORE_KEY) || 'null');
    if (s) Object.assign(state, s);
  } catch { /* defekter Speicher -> Neustart */ }
  state.grid = state.area ? makeGrid(state.area, state.cellM) : null;
}

function save() {
  const { grid, ...rest } = state;
  const c = map.getCenter();
  rest.view = { lat: c.lat, lon: c.lng, z: map.getZoom() };
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(rest));
  } catch { toast('Speichern nicht möglich (Speicher voll?)'); }
}

function snapshot() {
  undoStack.push(JSON.stringify({ area: state.area, cellM: state.cellM, fills: state.fills, items: state.items }));
  if (undoStack.length > 60) undoStack.shift();
}

function undo() {
  const s = undoStack.pop();
  if (!s) return toast('Nichts zum Rückgängigmachen');
  Object.assign(state, JSON.parse(s));
  state.grid = state.area ? makeGrid(state.area, state.cellM) : null;
  $('cell-size').value = String(state.cellM);
  changed();
}

function changed() {
  updateGridInfo();
  redraw();
  save();
}

// ---------- Karte ----------
load();
const map = L.map('map', { zoomControl: false, maxZoom: 20 });
if (state.view) map.setView([state.view.lat, state.view.lon], state.view.z);
else map.setView([51.1, 10.4], 6);
L.control.zoom({ position: 'bottomright' }).addTo(map);

let baseLayer = null;
function setLayer(id) {
  const l = layerById(id);
  state.layerId = l.id;
  if (baseLayer) map.removeLayer(baseLayer);
  baseLayer = L.tileLayer(l.url, {
    subdomains: l.subdomains || 'abc',
    maxNativeZoom: l.maxNative,
    maxZoom: 20,
    attribution: l.attribution,
    crossOrigin: true, // nötig, damit die Kacheln ins PDF dürfen
  }).addTo(map);
  renderLayerList();
  save();
}

// ---------- Overlay (Raster + Zeichnungen) ----------
const canvas = $('overlay');
const ctx = canvas.getContext('2d');
let current = null; // Strich, der gerade gezeichnet wird
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
  const items = current ? [...state.items, current] : state.items;
  drawOverlay(ctx, toPx, { grid: state.grid, fills: state.fills, items }, { s: 1, width: W, height: H, view });
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
  fill: 'Auf ein Feld tippen, um es einzufärben. Nochmal tippen entfernt die Farbe.',
  erase: 'Auf eine Zeichnung oder einen Text tippen, um sie zu löschen.',
  grid: 'Suchgebiet als Rechteck mit dem Finger aufziehen.',
};

function setTool(t) {
  if ((t === 'fill') && !state.grid) {
    toast('Bitte zuerst ein Raster anlegen');
    t = 'pan';
  }
  tool = t;
  document.querySelectorAll('.toolbar [data-tool]').forEach((b) => b.classList.toggle('active', b.dataset.tool === t));
  canvas.classList.toggle('active', t !== 'pan');
  $('palette').hidden = !['pen', 'text', 'fill'].includes(t);
  $('palette').querySelector('.widths').hidden = t !== 'pen';
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

canvas.addEventListener('pointerdown', (e) => {
  if (activePointer !== null) return;
  activePointer = e.pointerId;
  canvas.setPointerCapture(e.pointerId);
  const { x, y, ll } = eventLatLng(e);
  lastPt = { x, y };
  erased = false;
  if (tool === 'pen') {
    current = { kind: 'stroke', color: state.color, w: state.w, pts: [[ll.lat, ll.lng]] };
    redraw();
  } else if (tool === 'grid') {
    dragRect = { a: ll, b: ll };
  } else if (tool === 'erase') {
    eraseAt(x, y);
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
  }
});

function finishPointer(e, cancelled) {
  if (e.pointerId !== activePointer) return;
  activePointer = null;
  const { x, y, ll } = eventLatLng(e);
  if (tool === 'pen' && current) {
    if (!cancelled) {
      snapshot();
      state.items.push(current);
    }
    current = null;
    changed();
  } else if (tool === 'grid' && dragRect) {
    const a = dragRect.a;
    dragRect = null;
    if (!cancelled) setArea({ north: a.lat, south: ll.lat, west: a.lng, east: ll.lng });
    setTool('pan');
    redraw();
  } else if (cancelled) {
    return;
  } else if (tool === 'text' && Math.hypot(x - lastPt.x, y - lastPt.y) < 10) {
    const text = prompt('Text für diesen Punkt (z. B. Team 2, Fundstelle, Treffpunkt):');
    if (text && text.trim()) {
      snapshot();
      state.items.push({ kind: 'text', color: state.color, lat: ll.lat, lon: ll.lng, text: text.trim() });
      changed();
    }
  } else if (tool === 'fill') {
    const cell = state.grid && cellAt(state.grid, ll.lat, ll.lng);
    if (!cell) return toast('Außerhalb des Rasters');
    snapshot();
    const key = `${cell.c},${cell.r}`;
    if (state.fills[key] === state.color) delete state.fills[key];
    else state.fills[key] = state.color;
    changed();
  } else if (tool === 'erase' && erased) {
    changed();
  }
}
canvas.addEventListener('pointerup', (e) => finishPointer(e, false));
canvas.addEventListener('pointercancel', (e) => finishPointer(e, true));

function eraseAt(x, y) {
  const i = hitItem(state.items, toPx, x, y, 12);
  if (i < 0) return;
  if (!erased) snapshot();
  erased = true;
  state.items.splice(i, 1);
  redraw();
}

document.querySelectorAll('.toolbar [data-tool]').forEach((b) => b.addEventListener('click', () => setTool(b.dataset.tool)));
$('undo').addEventListener('click', undo);

// Palette
const colorBox = $('palette').querySelector('.colors');
COLORS.forEach((c) => {
  const b = document.createElement('button');
  b.style.background = c;
  b.title = c;
  b.addEventListener('click', () => { state.color = c; renderPalette(); save(); });
  colorBox.appendChild(b);
});
$('palette').querySelectorAll('.widths button').forEach((b) => b.addEventListener('click', () => {
  state.w = Number(b.dataset.w);
  renderPalette();
  save();
}));
function renderPalette() {
  colorBox.querySelectorAll('button').forEach((b, i) => b.classList.toggle('active', COLORS[i] === state.color));
  $('palette').querySelectorAll('.widths button').forEach((b) => b.classList.toggle('active', Number(b.dataset.w) === state.w));
}

// ---------- Raster ----------
function setArea(area, cellM = state.cellM) {
  if (Math.abs(area.north - area.south) < 1e-6 || Math.abs(area.east - area.west) < 1e-6) {
    // nur angetippt: ein Feld an dieser Stelle
    area = { north: area.north, west: area.west, south: area.north - 1e-6, east: area.west + 1e-6 };
  }
  const grid = makeGrid(area, cellM);
  if (cellCount(grid) > MAX_CELLS) {
    toast(`Zu viele Felder (${grid.cols} × ${grid.rows}). Bitte größere Feldgröße oder kleineres Gebiet wählen.`);
    return false;
  }
  snapshot();
  const sizeChanged = state.grid && (state.grid.cellM !== cellM);
  state.area = area;
  state.cellM = cellM;
  state.grid = grid;
  if (sizeChanged) state.fills = {};
  changed();
  return true;
}

function updateGridInfo() {
  const g = state.grid;
  if (!g) {
    $('grid-info').textContent = 'Noch kein Raster. „Suchgebiet aufziehen“ oder „Aktuellen Ausschnitt nehmen“.';
    return;
  }
  $('grid-info').textContent = `${g.cols} × ${g.rows} Felder à ${formatMeters(g.cellM)} · A1 bis ${cellLabel(g.cols - 1, g.rows - 1)} · `
    + `Gebiet ${formatMeters(g.cols * g.cellM)} × ${formatMeters(g.rows * g.cellM)}`;
}

$('cell-size').value = String(state.cellM);
$('cell-size').addEventListener('change', () => {
  const m = Number($('cell-size').value);
  if (!state.area) { state.cellM = m; save(); return; }
  if (Object.keys(state.fills).length && !confirm('Bei neuer Feldgröße ändern sich die Felder – die Feldfarben werden gelöscht. Fortfahren?')) {
    $('cell-size').value = String(state.cellM);
    return;
  }
  if (!setArea(state.area, m)) $('cell-size').value = String(state.cellM);
});
$('grid-draw').addEventListener('click', () => { closePanels(); setTool('grid'); });
$('grid-view').addEventListener('click', () => {
  const b = map.getBounds().pad(-0.08);
  if (setArea({ north: b.getNorth(), south: b.getSouth(), west: b.getWest(), east: b.getEast() })) closePanels();
});
$('grid-remove').addEventListener('click', () => {
  if (!state.grid || !confirm('Raster und Feldfarben entfernen?')) return;
  snapshot();
  state.area = null;
  state.grid = null;
  state.fills = {};
  changed();
});
$('clear-fills').addEventListener('click', () => {
  if (!Object.keys(state.fills).length) return;
  snapshot();
  state.fills = {};
  changed();
});
$('clear-drawings').addEventListener('click', () => {
  if (!state.items.length || !confirm('Alle Zeichnungen und Texte löschen?')) return;
  snapshot();
  state.items = [];
  changed();
});
function goToCell() {
  const p = parseCell($('cell-search').value);
  const g = state.grid;
  if (!g) return toast('Kein Raster vorhanden');
  if (!p || p.c >= g.cols || p.r >= g.rows) return toast('Dieses Feld gibt es nicht');
  const b = cellBounds(g, p.c, p.r);
  closePanels();
  map.fitBounds([[b.south, b.west], [b.north, b.east]], { padding: [60, 60] });
}
$('cell-go').addEventListener('click', goToCell);
$('cell-search').addEventListener('keydown', (e) => { if (e.key === 'Enter') goToCell(); });

// Antippen im Bewegen-Modus zeigt das Feld
map.on('click', (e) => {
  if (!state.grid) return;
  const c = cellAt(state.grid, e.latlng.lat, e.latlng.lng);
  toast(c ? `Feld ${cellLabel(c.c, c.r)}` : 'Außerhalb des Rasters');
});

// ---------- Kartenart ----------
function renderLayerList() {
  const box = $('layer-list');
  box.innerHTML = '';
  for (const l of LAYERS) {
    const b = document.createElement('button');
    b.textContent = l.name;
    b.classList.toggle('active', l.id === state.layerId);
    b.addEventListener('click', () => setLayer(l.id));
    box.appendChild(b);
  }
}

// ---------- GPS ----------
let watchId = null;
let gpsMarker = null;
let gpsCircle = null;
$('btn-gps').addEventListener('click', () => {
  if (watchId !== null) {
    navigator.geolocation.clearWatch(watchId);
    watchId = null;
    if (gpsMarker) { map.removeLayer(gpsMarker); map.removeLayer(gpsCircle); gpsMarker = null; }
    $('btn-gps').classList.remove('on');
    $('status').textContent = '';
    return;
  }
  if (!navigator.geolocation) return toast('Standort wird nicht unterstützt');
  let first = true;
  $('btn-gps').classList.add('on');
  watchId = navigator.geolocation.watchPosition((pos) => {
    const ll = [pos.coords.latitude, pos.coords.longitude];
    if (!gpsMarker) {
      gpsCircle = L.circle(ll, { radius: pos.coords.accuracy, weight: 1, color: '#1e88e5', fillOpacity: 0.1 }).addTo(map);
      gpsMarker = L.marker(ll, { icon: L.divIcon({ className: '', html: '<div class="gps-dot"></div>', iconSize: [22, 22] }) }).addTo(map);
    } else {
      gpsMarker.setLatLng(ll);
      gpsCircle.setLatLng(ll).setRadius(pos.coords.accuracy);
    }
    if (first) { map.setView(ll, Math.max(map.getZoom(), 16)); first = false; }
    const c = state.grid && cellAt(state.grid, ll[0], ll[1]);
    $('status').textContent = state.grid ? (c ? `📍 Feld ${cellLabel(c.c, c.r)}` : '📍 außerhalb') : `± ${Math.round(pos.coords.accuracy)} m`;
  }, (err) => {
    toast('Standort nicht verfügbar: ' + err.message);
  }, { enableHighAccuracy: true, maximumAge: 5000 });
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
$('btn-grid').addEventListener('click', () => { updateGridInfo(); openPanel('panel-grid'); });
$('btn-layers').addEventListener('click', () => openPanel('panel-layers'));
$('btn-pdf').addEventListener('click', () => { updatePdfPlan(); $('pdf-result').hidden = true; openPanel('panel-pdf'); });

// ---------- PDF ----------
let lastPdf = null;

function pdfOpts() {
  return {
    format: $('pdf-format').value,
    orient: $('pdf-orient').value,
    overview: $('pdf-overview').checked && !!state.grid,
    details: $('pdf-details').checked && !!state.grid,
    k: Number($('pdf-k').value),
    view: $('pdf-view').checked,
    title: state.title.trim() || 'Suchgebiet',
  };
}

function viewBounds() {
  const b = map.getBounds();
  return { north: b.getNorth(), south: b.getSouth(), west: b.getWest(), east: b.getEast() };
}

function updatePdfPlan() {
  const noGrid = !state.grid;
  $('pdf-overview').disabled = noGrid;
  $('pdf-details').disabled = noGrid;
  if (noGrid) $('pdf-view').checked = true;
  const sheets = planSheets(state, pdfOpts(), viewBounds());
  $('pdf-plan').textContent = sheets.length
    ? `${sheets.length} Seite${sheets.length > 1 ? 'n' : ''}: ${sheets.map((s) => s.title.replace(/^Blatt \d+ – /, '')).join(' · ')}`
    : 'Bitte mindestens eine Option wählen.';
  $('pdf-make').disabled = !sheets.length;
}
['pdf-format', 'pdf-orient', 'pdf-overview', 'pdf-details', 'pdf-k', 'pdf-view'].forEach((id) => $(id).addEventListener('change', updatePdfPlan));

function fileName() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const stamp = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}`;
  const umlaut = { ä: 'ae', ö: 'oe', ü: 'ue', Ä: 'Ae', Ö: 'Oe', Ü: 'Ue', ß: 'ss' };
  const t = (state.title.trim() || 'Suchgebiet').replace(/[äöüÄÖÜß]/g, (ch) => umlaut[ch])
    .replace(/[^\w-]+/g, '_').slice(0, 40);
  return `${t}_${stamp}.pdf`;
}

$('pdf-make').addEventListener('click', async () => {
  const btn = $('pdf-make');
  btn.disabled = true;
  $('pdf-result').hidden = true;
  try {
    const opts = pdfOpts();
    const res = await buildPdf(state, opts, layerById(state.layerId), viewBounds(), (i, n) => {
      btn.textContent = `Seite ${i} von ${n} wird erstellt …`;
    });
    lastPdf = { blob: res.blob, name: fileName(), title: opts.title };
    $('pdf-msg').textContent = `✔ ${res.pages} Seite${res.pages > 1 ? 'n' : ''} erstellt (${Math.round(res.blob.size / 1024)} KB)`
      + (res.missing ? ` – ${res.missing} Kartenkacheln fehlen (keine Verbindung?)` : '');
    $('pdf-result').hidden = false;
  } catch (err) {
    console.error(err);
    toast('PDF-Fehler: ' + err.message);
  } finally {
    btn.disabled = false;
    btn.textContent = 'PDF erstellen';
  }
});

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

function mailText() {
  const g = state.grid;
  return `Anbei die Karte zum Suchgebiet „${lastPdf.title}“.`
    + (g ? `\nRaster: ${formatMeters(g.cellM)}-Felder, A1 = Nordwest-Ecke, Felder A1 bis ${cellLabel(g.cols - 1, g.rows - 1)}.` : '');
}

$('pdf-share').addEventListener('click', async () => {
  if (!lastPdf) return;
  const file = new File([lastPdf.blob], lastPdf.name, { type: 'application/pdf' });
  if (navigator.canShare && navigator.canShare({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: lastPdf.title, text: mailText() });
    } catch (err) {
      if (err.name !== 'AbortError') toast('Teilen fehlgeschlagen: ' + err.message);
    }
  } else {
    toast('Direktes Teilen geht in diesem Browser nicht – PDF wird heruntergeladen und das E-Mail-Programm geöffnet.');
    download(lastPdf.blob, lastPdf.name);
    openMail();
  }
});
$('pdf-download').addEventListener('click', () => lastPdf && download(lastPdf.blob, lastPdf.name));

function openMail() {
  const body = `${mailText()}\n\n(Bitte die heruntergeladene Datei ${lastPdf.name} anhängen.)`;
  location.href = `mailto:?subject=${encodeURIComponent('Karte: ' + lastPdf.title)}&body=${encodeURIComponent(body)}`;
}
$('pdf-mail').addEventListener('click', () => lastPdf && openMail());

// ---------- Sonstiges ----------
let toastTimer = null;
function toast(msg) {
  const t = $('toast');
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { t.hidden = true; }, 3500);
}

$('title').value = state.title;
$('title').addEventListener('input', () => { state.title = $('title').value; save(); });

setLayer(state.layerId);
renderPalette();
setTool('pan');
updateGridInfo();
resizeCanvas();

if ('serviceWorker' in navigator && location.protocol === 'https:') {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}

// Für Tests
window.__app = { state, map, setArea, setTool };
