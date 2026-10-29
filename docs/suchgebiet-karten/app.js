import {
  makeGrid, cellCount, cellAt, cellBounds, cellLabel, parseCell, formatMeters, MAX_CELLS, remapCells,
} from './grid.js';
import { drawOverlay, hitItem } from './render.js';
import {
  LAYERS, OVERLAYS, DEFAULT_OVERLAYS, layerById, layerStack, tileUrl,
} from './layers.js';
import { buildPdf, planMultiSheets, planSheets, renderState } from './pdf.js';
import { formatMgrs } from './utm.js';
import { buildGpx, mergeGpx, parseGpx, trackDesc, trackLength, outlineName } from './gpx.js';
import { JUH_TEMPLATE, fillJuh } from './juh.js';
import {
  FORCE_KEYS, TIME_KEYS, totalLine, usedColors, colorName, notePageImage, drawNotePage, PAGE_RATIO, shrinkPhoto, missionText,
  MAIL_PARTS, REPORT_SECTIONS, MAP_PARTS, EXTRA_PARTS, hasReportText, newMailTo, mailAddresses,
} from './mission.js';
import { buildCustomMap, planCustomMap } from './kmz.js';
import {
  STATES, estimate, downloadRegion, deleteRegion, storageInfo, persistStorage, setHasOffline, cachedTileUrl, maxZoom, nativeJob,
  SQ_LAT, SQ_LON, squareKey, squareBounds, unionBounds,
} from './offline.js';
import {
  FIELDS as CT_FIELDS, normalizeContact, sortContacts, matches as ctMatches, telHref, toVcf, parseContacts, mergeContacts,
} from './contacts.js';
import {
  parseRescue, mergeRescue, nearest as nearestRescue, compass, inBounds, loadRescue, storeRescue, rescueNear,
  distance, bearing as bearingDeg,
} from './rescue.js';
import {
  fetchWeather, fetchStations, dirName, beaufort, approach, circularMean, sunTimes, windChanged, STRENGTHS, ICONS as WX_ICONS,
} from './weather.js';
import {
  PUBLIC_URL, pack, unpack, parseShared, shareLink, buildAssignment, projectFromAssignment, buildResult, applyResult,
} from './share.js';
import { parseQuery, searchAddress, suggestPlaces, cornerBox, searchCorner } from './search.js';
import {
  newProject, normalizeProject, migrateV1, assignments, markLabel, cellOwner, cellStatus, mapFor,
  exportProject, importProject, uid, TEAM_COLORS,
  allGrids, activateGrid, startNewGrid, removeActiveGrid, gridView, gridLabel,
} from './store.js';

// Bei jeder Änderung erhöhen (gleich wie VERSION in sw.js) – steht im Export-Fenster
const APP_VERSION = 'v62';
const STORE_KEY = 'suchgebiet-karten-v2';
const OLD_KEY = 'suchgebiet-karten-v1';
const COLORS = ['#d50000', '#1565c0', '#2e7d32', '#ef6c00', '#6a1b9a', '#f06292', '#000000', '#fdd835'];
const MARK_COLORS = [...new Set([...TEAM_COLORS, '#f06292', '#00c853', '#2e7d32', '#fdd835', '#616161', '#000000'])];
const COLOR_NAMES = {
  '#d50000': 'Rot', '#1565c0': 'Blau', '#ef6c00': 'Orange', '#6a1b9a': 'Lila', '#00838f': 'Türkis', '#ad1457': 'Pink', '#f06292': 'Rosa',
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
let draftTrack = null; // Umriss, der gerade Punkt für Punkt gesetzt wird
let draftPen = null; // Stift-Zeichnung in Arbeit: { strokes: [...] } – bis „Fertig“ oder „Abbrechen“
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
  syncGrid();
  restoreDrafts();
}
function restoreDrafts() {
  const d = P.drafts || {};
  draftTrack = d.track && Array.isArray(d.track.pts) ? d.track : null;
  draftPen = d.pen && Array.isArray(d.pen.strokes) && d.pen.strokes.length ? d.pen : null;
}

// grid neu aus dem bearbeiteten Rastergebiet berechnen
function syncGrid() {
  grid = P.area ? makeGrid(P.area, P.cellM) : null;
}

// Rastergebiet und Feld an einer Stelle (alle Gebiete, das bearbeitete zuerst)
function hitGrid(lat, lon) {
  const list = allGrids(P).sort((a, b) => b.active - a.active);
  for (const g of list) {
    const gg = g.active ? grid : makeGrid(g.area, g.cellM);
    const c = gg && cellAt(gg, lat, lon);
    if (c) return { ...c, g, grid: gg, label: allGrids(P).length > 1 ? `${gridLabel(P, g)} ` : '' };
  }
  return null;
}

// Liegt die Stelle in einem anderen Rastergebiet, wird dieses zum Bearbeiten geholt
function useGridAt(lat, lon) {
  const h = hitGrid(lat, lon);
  if (h && !h.g.active) {
    activateGrid(P, h.g.id);
    syncGrid();
    updateGridInfo();
  }
  return h;
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
  // offene Zeichnung/Umriss überstehen Neustart und Projektwechsel
  P.drafts = { track: draftTrack, pen: draftPen };
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(db));
  } catch { toast('Speichern nicht möglich (Speicher voll?)'); }
}
window.addEventListener('pagehide', saveNow);
document.addEventListener('visibilitychange', () => { if (document.hidden) saveNow(); });

function snapshot() {
  undoStack.push(JSON.stringify({
    area: P.area, cellM: P.cellM, fills: P.fills, status: P.status, items: P.items, marks: P.marks, meet: P.meet,
    gridId: P.gridId, gridName: P.gridName, otherGrids: P.otherGrids,
  }));
  if (undoStack.length > 60) undoStack.shift();
}

function undo() {
  const s = undoStack.pop();
  if (!s) return toast('Nichts zum Rückgängigmachen');
  Object.assign(P, JSON.parse(s));
  syncGrid();
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
  // Offline gespeicherte Kachel zuerst (sofort, ohne Netz), sonst aus dem Internet
  createTile(coords, done) {
    const tile = document.createElement('img');
    L.DomEvent.on(tile, 'load', L.Util.bind(this._tileOnLoad, this, done, tile));
    L.DomEvent.on(tile, 'error', L.Util.bind(this._tileOnError, this, done, tile));
    if (this.options.crossOrigin || this.options.crossOrigin === '') tile.crossOrigin = this.options.crossOrigin === true ? '' : this.options.crossOrigin;
    tile.alt = '';
    tile.setAttribute('role', 'presentation');
    const url = this.getTileUrl(coords);
    cachedTileUrl(url).then((local) => {
      if (local) {
        tile.addEventListener('load', () => URL.revokeObjectURL(local), { once: true });
        tile.src = local;
      } else tile.src = url;
    });
    return tile;
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
let dragRect = null; // Vorschau beim Aufziehen des Suchgebiets
let offSel = new Set(); // angetippte Quadrate für Offline-Karten
let rescuePts = []; // Rettungspunkte (aus IndexedDB, siehe unten)

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
  // Hundeführer: aufgezeichneter Weg
  if (P.hf) for (const sg of P.hf.track) if (sg.pts.length > 1) items.push({ kind: 'track', open: true, color: hfColor(), w: 4, pts: sg.pts, name: '' });
  if (current) items.push(current);
  if (draftTrack && draftTrack.pts.length) items.push(draftTrack);
  const drafts = draftPen ? draftPen.strokes : [];
  items.push(...drafts);
  // Ausgeblendetes (Raster-Fenster → „Auf der Karte zeigen“); gilt nur für die Arbeitskarte.
  // Was gerade gezeichnet wird, bleibt sichtbar.
  const hide = P.hide || {};
  const hiddenMarks = new Set(P.marks.filter((m) => m.hidden).map((m) => m.id));
  const visible = (map) => Object.fromEntries(Object.entries(map).filter(([, id]) => !hiddenMarks.has(id)));
  const st = {
    ...renderState({
      ...P,
      fills: visible(P.fills),
      status: visible(P.status),
      otherGrids: P.otherGrids.map((g) => ({ ...g, fills: visible(g.fills), status: visible(g.status) })),
    }, grid),
    items: items.filter((it) => !it.hidden || it === current || it === draftTrack || drafts.includes(it)),
  };
  if (hide.meet) st.meet = null;
  st.rescue = rescueInView();
  // Raster aus: Markierungen als Flächen mit Namen darauf
  drawOverlay(ctx, toPx, st, {
    s: 1, width: W, height: H, view, utm: P.showUtm, noGrid: !!hide.grid, noEdge: !!hide.edge, areaLabels: 'on',
  });
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
  drawOffSquares(ctx);
  drawPicked(ctx);
  drawWindArrow(ctx);
}

// Windpfeile (Overlay, ein-/ausschaltbar: db.windArrows). Jeder Pfeil zeigt, wohin der Wind weht.
// Blau: DWD am Windpunkt bzw. über dem Suchgebiet und an den DWD-Messstationen ringsum.
// Grün: selbst gemessener Wind an der Messstelle (auch von Hundeführern zurückgemeldet).
function windArrowPoint() {
  const gs = allGrids(P);
  if (db.mode === 'hf' && !gs.length && P.items.length) {
    const pts = P.items.flatMap((it) => it.pts || (it.lat != null ? [[it.lat, it.lon]] : []));
    if (pts.length) {
      const la = pts.map((q) => q[0]);
      const lo = pts.map((q) => q[1]);
      return { lat: (Math.max(...la) + Math.min(...la)) / 2, lon: (Math.max(...lo) + Math.min(...lo)) / 2 };
    }
  }
  if (db.mode === 'hf' && gs.length) {
    const ns = gs.flatMap((g) => [g.area.north, g.area.south]);
    const ws = gs.flatMap((g) => [g.area.west, g.area.east]);
    return { lat: (Math.max(...ns) + Math.min(...ns)) / 2, lon: (Math.max(...ws) + Math.min(...ws)) / 2 };
  }
  return wxPoint();
}
function windArrows() {
  const out = [];
  const w = db.wxLast && db.wxLast.current;
  if (w && w.from != null && w.kmh != null) {
    const pt = windArrowPoint();
    out.push({ ...pt, from: w.from, kmh: w.kmh, color: '#1565c0', big: true,
      text: `Wind aus ${dirName(w.from)} ${Math.round(w.kmh)} km/h${w.gust ? `, Böen ${Math.round(w.gust)}` : ''} (DWD)` });
  }
  for (const st of (db.wxStations && db.wxStations.list) || []) {
    if (st.from == null || st.kmh == null) continue;
    out.push({ lat: st.lat, lon: st.lon, from: st.from, kmh: st.kmh, color: '#1565c0', station: true,
      text: `DWD ${st.name}: ${dirName(st.from)} ${Math.round(st.kmh)} km/h` });
  }
  const KMH = { light: 8, medium: 20, strong: 35 };
  for (const m of P.mission.wind || []) {
    if (m.src !== 'gemessen' || m.lat == null) continue;
    const t = new Date(m.t).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
    out.push({ lat: m.lat, lon: m.lon, from: m.from, kmh: KMH[m.strength] || 15, color: '#2e7d32', old: Date.now() - m.t > 2 * 3600e3,
      text: `${t}${m.by ? ` ${m.by}` : ''}: aus ${dirName(m.from)}, ${STRENGTHS[m.strength] ? STRENGTHS[m.strength].label : ''}` });
  }
  return out;
}
function drawWindArrow(c) {
  if (!db.windArrows) return;
  for (const a of windArrows()) drawArrowAt(c, a);
}
function drawArrowAt(c, w) {
  const [x, y] = toPx(w.lat, w.lon);
  const k = w.big ? 1 : 0.75;
  const ang = ((w.from + 180) * Math.PI) / 180; // 0 = Norden, im Uhrzeigersinn
  const len = (46 + Math.min(40, w.kmh)) * k; // stärkerer Wind = längerer Pfeil
  c.save();
  c.globalAlpha = w.old ? 0.5 : 1;
  c.translate(x, y);
  c.fillStyle = '#fff';
  c.strokeStyle = w.color;
  c.lineWidth = 3;
  c.beginPath();
  if (w.station) c.rect(-6, -6, 12, 12); else c.arc(0, 0, 7 * k, 0, Math.PI * 2);
  c.fill();
  c.stroke();
  c.rotate(ang);
  c.lineCap = 'round';
  for (const [col, wd] of [['rgba(255,255,255,0.95)', 11 * k], [w.color, 6 * k]]) {
    c.strokeStyle = col;
    c.lineWidth = wd;
    c.beginPath(); c.moveTo(0, -10); c.lineTo(0, -len); c.stroke();
    c.beginPath(); c.moveTo(-12 * k, -len + 14 * k); c.lineTo(0, -len - 2); c.lineTo(12 * k, -len + 14 * k); c.stroke();
  }
  c.restore();
  c.save();
  c.globalAlpha = w.old ? 0.5 : 1;
  c.font = `bold ${w.big ? 13 : 11}px sans-serif`;
  c.textAlign = 'center';
  c.textBaseline = 'top';
  c.lineWidth = 4;
  c.strokeStyle = 'rgba(255,255,255,0.95)';
  c.strokeText(w.text, x, y + 12);
  c.fillStyle = w.color;
  c.fillText(w.text, x, y + 12);
  c.restore();
}

// Quadrate für Offline-Karten: blau = gewählt, grün = gespeichert, orange = angefangen
function drawOffSquares(ctx) {
  if (tool !== 'offsquares' || map.getZoom() < 9) return;
  const b = map.getBounds();
  const i0 = Math.floor(b.getSouth() / SQ_LAT);
  const i1 = Math.floor(b.getNorth() / SQ_LAT);
  const j0 = Math.floor(b.getWest() / SQ_LON);
  const j1 = Math.floor(b.getEast() / SQ_LON);
  if ((i1 - i0 + 1) * (j1 - j0 + 1) > 4000) return;
  const stored = new Map();
  for (const r of db.offline) for (const k of r.squares || []) stored.set(k, stored.get(k) || r.finished);
  ctx.lineWidth = 1;
  ctx.strokeStyle = 'rgba(21,101,192,0.75)';
  for (let i = i0; i <= i1; i++) {
    for (let j = j0; j <= j1; j++) {
      const key = `${i}_${j}`;
      const sb = squareBounds(key);
      const [x0, y0] = toPx(sb.north, sb.west);
      const [x1, y1] = toPx(sb.south, sb.east);
      const fill = offSel.has(key) ? 'rgba(21,101,192,0.4)'
        : stored.has(key) ? (stored.get(key) ? 'rgba(46,125,50,0.35)' : 'rgba(239,108,0,0.35)') : null;
      if (fill) { ctx.fillStyle = fill; ctx.fillRect(x0, y0, x1 - x0, y1 - y0); }
      ctx.strokeRect(x0, y0, x1 - x0, y1 - y0);
    }
  }
}

map.on('move resize viewreset', redraw);
map.on('zoomstart', () => { canvas.style.visibility = 'hidden'; });
map.on('zoomend', () => { canvas.style.visibility = 'visible'; redraw(); save(); });
map.on('moveend', save);
window.addEventListener('resize', () => { map.invalidateSize(); resizeCanvas(); });

// ---------- Werkzeuge ----------
const HINTS = {
  pen: 'Mit dem Finger zeichnen – mehrere Striche gehören zu einer Zeichnung, bis „Fertig“. Zwischendurch „Bewegen“ und zurück geht. Vorhandene Zeichnung antippen: umbenennen.',
  text: 'Auf die Karte tippen, um einen Punkt mit Text zu setzen.',
  fill: 'Team/Markierung wählen, dann Felder antippen oder darüberwischen. Nochmal tippen entfernt.',
  erase: 'Antippen oder darüberwischen löscht Zeichnungen, Umrisse, Texte, B-Ort und Feldfarben.',
  grid: 'Suchgebiet als Rechteck mit dem Finger aufziehen.',
  offrect: 'Bereich für die Offline-Karte als Rechteck aufziehen.',
  windpt: 'Tippe auf die Karte, wo der Wind (DWD) angezeigt werden soll.',
  hffield: 'Feld antippen: abgesucht → teilweise → nicht begehbar → zurück. „Feld“ nochmal tippen = fertig.',
  sendpick: 'Felder für den Auftrag antippen (blau umrandet). Dann „Weiter“.',
  offsquares: 'Quadrate antippen (blau = gewählt, grün = schon gespeichert). Ziehen verschiebt die Karte.',
  meet: 'Auf die Karte tippen, um den B-Ort zu setzen.',
  track: 'Umriss: Punkte antippen. Karte mit dem Finger verschieben, Zoom mit +/−.',
};

let hintTimer = null;
function setTool(t) {
  // Offene Zeichnung/Umriss bleibt beim Werkzeugwechsel erhalten (bis „Fertig“ oder „Abbrechen“)
  if (tool === 'track' && t !== 'track') {
    if (draftTrack && !draftTrack.pts.length) draftTrack = null;
    else if (draftTrack) toast('Umriss bleibt offen – „Umriss“ antippen zum Weiterzeichnen');
  }
  if (tool === 'pen' && t !== 'pen' && draftPen) toast('Zeichnung bleibt offen – „Stift“ antippen zum Weiterzeichnen');
  if ((t === 'fill') && !allGrids(P).length) {
    toast('Bitte zuerst ein Raster anlegen');
    t = 'pan';
  }
  tool = t;
  document.querySelectorAll('.toolbar [data-tool]').forEach((b) => b.classList.toggle('active', b.dataset.tool === t));
  canvas.classList.toggle('active', t !== 'pan');
  $('palette').hidden = !['pen', 'text', 'fill', 'track'].includes(t);
  $('trackbar').hidden = t !== 'track';
  $('penbar').hidden = t !== 'pen';
  $('offsqbar').hidden = t !== 'offsquares';
  $('pickbar').hidden = t !== 'sendpick';
  $('hf-field').classList.toggle('on', t === 'hffield');
  if (t === 'offsquares') updateOffSqBar();
  updatePenbar();
  if (t === 'track' && !draftTrack) draftTrack = { kind: 'track', name: '', color: db.color, w: 4, pts: [] };
  updateTrackbar();
  $('palette').querySelector('.widths').hidden = t !== 'pen';
  $('palette').querySelector('.colors').hidden = t === 'fill';
  $('palette').querySelector('.marks').hidden = t !== 'fill';
  const hint = HINTS[t];
  $('hint').hidden = !hint;
  $('hint').textContent = hint || '';
  // Hinweis nach ein paar Sekunden ausblenden – mehr Karte sichtbar
  $('hint').classList.remove('fade');
  clearTimeout(hintTimer);
  if (hint) hintTimer = setTimeout(() => $('hint').classList.add('fade'), 5000);
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
  // erster Tipp in einem anderen Rastergebiet: dieses bearbeiten
  if (first) useGridAt(ll.lat, ll.lng);
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
    fillStroke = { map: mapFor(P, m), mode: mapFor(P, m)[key] === m.id ? 'clear' : 'set', seen: new Set(), prev: {} };
  }
  if (fillStroke.seen.has(key)) return;
  fillStroke.seen.add(key);
  fillStroke.prev[key] = fillStroke.map[key]; // für Abbruch durch zweiten Finger
  if (fillStroke.mode === 'clear') delete fillStroke.map[key];
  else fillStroke.map[key] = m.id;
  redraw();
}

// Karte bewegen, während ein Werkzeug aktiv ist: zwei Finger verschieben/zoomen (ein angefangener
// Strich bzw. ein angefangenes Feld wird dann verworfen), rechte Maustaste verschiebt, Mausrad zoomt.
// Diese Handler stehen vor den Werkzeug-Handlern und halten Ereignisse der Geste von ihnen fern.
const touches = new Map(); // pointerId -> {x, y}
let gesture = null; // { mid, dist, zoom }
let mousePan = null;
const midOf = () => {
  const p = [...touches.values()];
  return { x: (p[0].x + p[1].x) / 2, y: (p[0].y + p[1].y) / 2, d: Math.hypot(p[0].x - p[1].x, p[0].y - p[1].y) || 1 };
};
function cancelToolAction() {
  if (current) { current = null; }
  if (fillStroke) {
    for (const [k, v] of Object.entries(fillStroke.prev || {})) { if (v === undefined) delete fillStroke.map[k]; else fillStroke.map[k] = v; }
    fillStroke = null;
  }
  dragRect = null;
  activePointer = null;
  redraw();
}
canvas.addEventListener('pointerdown', (e) => {
  const { x, y } = eventLatLng(e);
  if (e.pointerType === 'mouse' && e.button === 2) {
    mousePan = { x, y };
    try { canvas.setPointerCapture(e.pointerId); } catch { /* z. B. Zeiger schon weg */ }
    e.stopImmediatePropagation();
    return;
  }
  if (e.pointerType === 'mouse') return;
  touches.set(e.pointerId, { x, y });
  if (touches.size === 2 && !gesture) {
    cancelToolAction();
    const m = midOf();
    gesture = { mid: m, dist: m.d, zoom: map.getZoom() };
  }
  if (gesture) {
    try { canvas.setPointerCapture(e.pointerId); } catch { /* z. B. Zeiger schon weg */ }
    e.stopImmediatePropagation();
  }
});
canvas.addEventListener('pointermove', (e) => {
  const { x, y } = eventLatLng(e);
  if (mousePan) {
    map.panBy([mousePan.x - x, mousePan.y - y], { animate: false });
    mousePan = { x, y };
    e.stopImmediatePropagation();
    return;
  }
  if (!touches.has(e.pointerId)) return;
  touches.set(e.pointerId, { x, y });
  if (!gesture) return;
  e.stopImmediatePropagation();
  if (touches.size < 2) return;
  const m = midOf();
  map.panBy([gesture.mid.x - m.x, gesture.mid.y - m.y], { animate: false });
  gesture.mid = m;
  // Zoom in ganzen Stufen, sobald die Finger deutlich auseinander/zusammen gehen
  const want = Math.round(gesture.zoom + Math.log2(m.d / gesture.dist));
  if (want !== map.getZoom()) map.setZoomAround(L.point(m.x, m.y), want, { animate: false });
});
const endTouch = (e) => {
  if (mousePan) { mousePan = null; e.stopImmediatePropagation(); return; }
  if (!touches.has(e.pointerId)) return;
  touches.delete(e.pointerId);
  if (gesture) {
    e.stopImmediatePropagation();
    if (touches.size === 0) gesture = null;
  }
};
canvas.addEventListener('pointerup', endTouch);
canvas.addEventListener('pointercancel', endTouch);
canvas.addEventListener('contextmenu', (e) => e.preventDefault());
let wheelAt = 0;
canvas.addEventListener('wheel', (e) => {
  e.preventDefault();
  const now = Date.now();
  if (now - wheelAt < 180) return;
  wheelAt = now;
  const r = canvas.getBoundingClientRect();
  map.setZoomAround(L.point(e.clientX - r.left, e.clientY - r.top), map.getZoom() + (e.deltaY < 0 ? 1 : -1));
}, { passive: false });

canvas.addEventListener('pointerdown', (e) => {
  if (activePointer !== null) return;
  activePointer = e.pointerId;
  try { canvas.setPointerCapture(e.pointerId); } catch { /* z. B. Zeiger schon weg */ }
  const { x, y, ll } = eventLatLng(e);
  lastPt = { x, y };
  downPt = { x, y };
  erased = false;
  if (tool === 'pen') {
    current = { kind: 'stroke', color: db.color, w: db.w, pts: [[ll.lat, ll.lng]] };
    redraw();
  } else if (tool === 'grid' || tool === 'offrect') {
    dragRect = { a: ll, b: ll };
  } else if (tool === 'erase') {
    eraseAt(x, y);
  } else if (tool === 'fill') {
    fillAt(ll, true);
  } else if (['track', 'text', 'offsquares', 'hffield', 'sendpick', 'windpt'].includes(tool)) {
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
  } else if ((tool === 'grid' || tool === 'offrect') && dragRect) {
    dragRect.b = ll;
    redraw();
  } else if (tool === 'erase') {
    eraseAt(x, y);
  } else if (tool === 'fill' && fillStroke) {
    fillAt(ll, false);
  } else if (['track', 'text', 'offsquares', 'hffield', 'sendpick', 'windpt'].includes(tool)) {
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
      // Strich gehört zur offenen Zeichnung; gespeichert wird bei „Fertig“
      if (!draftPen) draftPen = { strokes: [] };
      draftPen.strokes.push(current);
      updatePenbar();
      save();
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
  } else if (tool === 'offrect' && dragRect) {
    // Bereich für Offline-Karten aufgezogen -> zurück ins Karte-Fenster
    const a = dragRect.a;
    dragRect = null;
    setTool('pan');
    redraw();
    if (!cancelled) {
      offRect = {
        north: Math.max(a.lat, ll.lat), south: Math.min(a.lat, ll.lat),
        west: Math.min(a.lng, ll.lng), east: Math.max(a.lng, ll.lng),
      };
      $('off-area').value = 'rect';
      openPanel('panel-offline');
      updateOffEstimate();
    }
  } else if (tool === 'windpt') {
    if (!cancelled && !panning) {
      P.windPt = { lat: Math.round(ll.lat * 1e5) / 1e5, lon: Math.round(ll.lng * 1e5) / 1e5 };
      if (!db.windArrows) { db.windArrows = true; $('quick-arrows').classList.add('on'); }
      setTool('pan');
      changed();
      loadWeather(true);
    }
  } else if (tool === 'hffield' || tool === 'sendpick') {
    if (!cancelled && !panning) (tool === 'hffield' ? hfFieldTap : sendPickTap)(ll);
    panning = false;
  } else if (tool === 'offsquares') {
    if (!cancelled && !panning) {
      if (map.getZoom() < 9) toast('Bitte näher heranzoomen, dann Quadrate antippen');
      else {
        const k = squareKey(ll.lat, ll.lng);
        if (offSel.has(k)) offSel.delete(k); else offSel.add(k);
        updateOffSqBar();
        redraw();
      }
    }
    panning = false;
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
  } else if (tool === 'text' && !panning && Math.hypot(x - downPt.x, y - downPt.y) < 10) {
    const text = prompt('Text für diesen Punkt (z. B. Fundstelle, Hinweis):');
    if (text && text.trim()) {
      snapshot();
      P.items.push({ kind: 'text', color: db.color, lat: ll.lat, lon: ll.lng, text: text.trim() });
      changed();
    }
  } else if (tool === 'meet') {
    const text = prompt('Bezeichnung des B-Orts:', (P.meet && P.meet.text) || 'B-Ort');
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

// Radierer: zuerst Zeichnungen/Tracks/Texte, dann B-Ort, dann Feldfarbe/Zuteilung.
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
    const h = hitGrid(ll.lat, ll.lng);
    const key = h && `${h.c},${h.r}`;
    const target = h && (h.g.active ? P : P.otherGrids.find((g) => g.id === h.g.id));
    if (!key || (!target.fills[key] && !target.status[key])) return;
    before();
    delete target.fills[key];
    delete target.status[key];
  }
  redraw();
}

// Nochmal auf das aktive Werkzeug tippen: zurück zu „Bewegen“
document.querySelectorAll('.toolbar [data-tool]').forEach((b) => b.addEventListener('click', () => {
  setTool(b.dataset.tool === tool ? 'pan' : b.dataset.tool);
}));
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
  const what = it.kind === 'track' ? 'des Umrisses' : 'der Zeichnung';
  const t = prompt(`Name ${what} (steht so auf der Karte und im GPX für Garmin):`, it.name || '');
  if (t === null || t.trim() === (it.name || '')) return;
  snapshot();
  // alle Striche einer Zeichnung heißen gleich
  for (const x of it.group ? P.items.filter((y) => y.group === it.group) : [it]) x.name = t.trim();
  changed();
  toast(it.name ? `Name „${it.name}“ gespeichert` : 'Name entfernt');
}

// ---------- Stift-Zeichnung ----------
function updatePenbar() {
  const n = draftPen ? draftPen.strokes.length : 0;
  $('pen-info').textContent = n
    ? `Zeichnung: ${n} Strich${n > 1 ? 'e' : ''} – weiterzeichnen, dann „Fertig“`
    : 'Zeichnung: mit dem Finger auf die Karte zeichnen';
  $('pen-back').disabled = !n;
  $('pen-done').disabled = !n;
  $('pen-cancel').disabled = !n;
}
function finishPen() {
  const d = draftPen;
  if (!d || !d.strokes.length) return;
  // wie beim Umriss: Name mit Vorschlag „Zeichnung 3“
  const groups = new Set(P.items.filter((it) => it.kind === 'stroke').map((it) => it.group || it));
  const def = `Zeichnung ${groups.size + 1}`;
  const t = prompt('Name der Zeichnung (erscheint so auf der Karte und auf dem Garmin):', def);
  if (t === null) return;
  const name = t.trim() || def;
  snapshot();
  const group = uid();
  for (const st of d.strokes) {
    st.group = group;
    st.name = name;
    P.items.push(st);
  }
  draftPen = null;
  changed();
  toast(`„${name}“ gespeichert`);
}
$('pen-back').addEventListener('click', () => {
  if (!draftPen) return;
  draftPen.strokes.pop();
  if (!draftPen.strokes.length) draftPen = null;
  updatePenbar();
  redraw();
  save();
});
$('pen-done').addEventListener('click', () => {
  finishPen();
  if (!draftPen) setTool('pan');
});
$('pen-cancel').addEventListener('click', () => {
  if (draftPen && !confirm('Zeichnung verwerfen?')) return;
  draftPen = null;
  setTool('pan');
  redraw();
  save();
});

// ---------- Track ----------
function updateTrackbar() {
  if (!draftTrack) return;
  const n = draftTrack.pts.length;
  $('track-info').textContent = n
    ? `Umriss: ${n} Punkt${n > 1 ? 'e' : ''} · ${trackDesc(draftTrack.pts)}`
    : 'Umriss: ersten Punkt auf die Karte tippen';
  $('track-back').disabled = !n;
  $('track-done').disabled = n < 2;
}

// auto = beim Wechsel des Werkzeugs: ohne Nachfrage mit Standardnamen speichern
function finishTrack(auto) {
  const d = draftTrack;
  draftTrack = null;
  if (!d || d.pts.length < 2) { redraw(); return; }
  // Vorschlag: Himmelsrichtung vom B-Ort + fortlaufende Nummer („Nordwest 2“)
  let name = outlineName(P.items, P.meet, d.pts);
  if (!auto) {
    const t = prompt('Name des Umrisses (erscheint so auf dem Garmin):', name);
    if (t === null) { draftTrack = d; return; }
    name = t.trim() || name;
  }
  snapshot();
  d.name = name;
  P.items.push(d);
  changed();
  toast(`„${name}“ gespeichert (${trackDesc(d.pts)})`);
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
  if (draftTrack && draftTrack.pts.length > 1 && !confirm('Umriss verwerfen?')) return;
  draftTrack = null;
  setTool('pan');
  redraw();
  save();
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
  // Teams und Status wandern auf die neuen Felder mit (neue Feldgröße oder neues Gebiet)
  if (grid) {
    P.fills = remapCells(grid, g, P.fills);
    P.status = remapCells(grid, g, P.status);
  }
  P.area = area;
  P.cellM = cellM;
  grid = g;
  changed();
  return true;
}

// Liste der Rastergebiete im Raster-Fenster: antippen = bearbeiten und hinzoomen
function renderGridList() {
  const box = $('grid-list');
  box.innerHTML = '';
  const list = allGrids(P);
  if (!P.area && list.length) {
    const p = document.createElement('p');
    p.className = 'small';
    p.textContent = `„${P.gridName || 'Neues Gebiet'}“ ist noch nicht aufgezogen – „Suchgebiet aufziehen“ oder „Aktuellen Ausschnitt nehmen“.`;
    box.appendChild(p);
  }
  for (const g of list) {
    const gg = g.active ? grid : makeGrid(g.area, g.cellM);
    const row = document.createElement('div');
    row.className = 'grow';
    const b = document.createElement('button');
    b.className = `gname${g.active ? ' active' : ''}`;
    b.innerHTML = '<span></span><small></small>';
    b.firstChild.textContent = gridLabel(P, g);
    b.lastChild.textContent = `${formatMeters(g.cellM)} · ${gg.cols}×${gg.rows}${g.active ? ' · wird bearbeitet' : ''}`;
    b.addEventListener('click', () => {
      if (!g.active) {
        snapshot();
        activateGrid(P, g.id);
        syncGrid();
        changed();
      }
      map.fitBounds([[g.area.south, g.area.west], [g.area.north, g.area.east]], { padding: [40, 40] });
    });
    const ren = document.createElement('button');
    ren.textContent = '✏️';
    ren.title = 'Umbenennen';
    ren.addEventListener('click', () => {
      const name = prompt('Name des Rastergebiets (z. B. Nord, Waldstück):', gridLabel(P, g));
      if (name === null || !name.trim()) return;
      snapshot();
      if (g.active) P.gridName = name.trim();
      else P.otherGrids.find((x) => x.id === g.id).name = name.trim();
      changed();
    });
    row.append(b, ren);
    box.appendChild(row);
  }
  $('grid-remove').textContent = list.length > 1 ? 'Dieses Rastergebiet entfernen' : 'Raster entfernen';
}
$('grid-add').addEventListener('click', () => {
  snapshot();
  startNewGrid(P);
  syncGrid();
  changed();
  closePanels();
  setTool('grid');
  toast(`${P.gridName}: Fläche auf der Karte aufziehen`);
});

function updateGridInfo() {
  renderGridList();
  $('cell-size').value = String(P.cellM);
  $('show-utm').checked = !!P.showUtm;
  renderViewToggles();
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
  if (!setArea(P.area, m)) $('cell-size').value = String(P.cellM);
});
$('show-utm').addEventListener('change', () => { P.showUtm = $('show-utm').checked; changed(); });
// Was auf der Arbeitskarte zu sehen ist – alles einzeln (nur Anzeige, PDF/Export unverändert)
function itemName(it, n) {
  if (it.kind === 'text') return `Text: ${it.text}`;
  if (it.kind === 'track') return `${it.open ? 'Track' : 'Umriss'}: ${it.name || 'ohne Namen'} (${trackDesc(it.pts, it.open)})`;
  return it.name ? `Zeichnung: ${it.name}` : `Stift ${n} (${COLOR_NAMES[it.color] || it.color})`;
}
function renderViewToggles() {
  updateQuick();
  const box = $('view-toggles');
  box.innerHTML = '';
  const hide = P.hide || {};
  const row = (label, checked, onChange, color) => {
    const l = document.createElement('label');
    l.className = 'check';
    l.innerHTML = '<input type="checkbox"><i></i><span></span>';
    l.querySelector('input').checked = checked;
    if (color) l.querySelector('i').style.background = color; else l.querySelector('i').remove();
    l.querySelector('span').textContent = label;
    l.querySelector('input').addEventListener('change', (e) => { onChange(e.target.checked); changed(); });
    box.appendChild(l);
  };
  const head = (t) => { const h = document.createElement('h4'); h.textContent = t; box.appendChild(h); };
  const setHide = (k) => (on) => { P.hide = { ...(P.hide || {}), [k]: !on }; };
  head('Raster');
  row('Rasterlinien und Feldnamen', !hide.grid, setHide('grid'));
  row('Randbeschriftung (A, B … / 1, 2 …)', !hide.edge, setHide('edge'));
  if (P.meet) row(`B-Ort${P.meet.text ? `: ${P.meet.text}` : ''}`, !hide.meet, setHide('meet'), '#0d47a1');
  const used = new Set(allGrids(P).flatMap((g) => [...Object.values(g.fills), ...Object.values(g.status)]));
  const marks = P.marks.filter((m) => used.has(m.id));
  if (marks.length) head('Teams und Markierungen');
  for (const m of marks) row(markLabel(m), !m.hidden, (on) => { m.hidden = !on; }, m.color);
  if (P.items.length) head('Zeichnungen, Umrisse, Texte');
  let n = 0;
  const seen = new Set();
  for (const it of P.items) {
    // eine Zeile je Zeichnung (alle Striche zusammen)
    if (it.group && seen.has(it.group)) continue;
    if (it.group) seen.add(it.group);
    if (it.kind === 'stroke') n++;
    const members = it.group ? P.items.filter((x) => x.group === it.group) : [it];
    row(itemName(it, n), !it.hidden, (on) => { for (const x of members) x.hidden = !on; }, it.color);
  }
}
// Schnellschalter links (gleiche Einstellungen wie in „Auf der Karte zeigen“)
function updateQuick() {
  const hide = P.hide || {};
  $('quick-grid').classList.toggle('on', !hide.grid || !hide.edge);
  $('quick-marks').classList.toggle('on', P.marks.some((m) => !m.hidden));
}
$('quick-grid').addEventListener('click', () => {
  const on = !$('quick-grid').classList.contains('on');
  P.hide = { ...(P.hide || {}), grid: !on, edge: !on };
  renderViewToggles();
  changed();
  toast(on ? 'Raster eingeblendet' : 'Raster ausgeblendet');
});
$('quick-marks').addEventListener('click', () => {
  const on = !$('quick-marks').classList.contains('on');
  for (const m of P.marks) m.hidden = !on;
  renderViewToggles();
  changed();
  toast(on ? 'Teams und Markierungen eingeblendet' : 'Teams und Markierungen ausgeblendet');
});

// Zoomleiste links: ziehen, tippen oder +/−
{
  const track = $('zs-track');
  const pos = () => {
    const min = map.getMinZoom();
    const max = map.getMaxZoom();
    const z = map.getZoom();
    if (!Number.isFinite(z)) return;
    $('zs-level').textContent = `St. ${Math.round(z)}`;
    const f = (z - min) / (max - min);
    const h = track.clientHeight - 12;
    $('zs-thumb').style.top = `${6 + (1 - f) * h}px`;
    $('zs-fill').style.height = `${f * h}px`;
  };
  const zoomAt = (e) => {
    const r = track.getBoundingClientRect();
    const f = 1 - Math.max(0, Math.min(1, (e.clientY - r.top - 6) / (r.height - 12)));
    const z = Math.round(map.getMinZoom() + f * (map.getMaxZoom() - map.getMinZoom()));
    if (z !== map.getZoom()) map.setZoom(z, { animate: !dragging });
  };
  let dragging = false;
  track.addEventListener('pointerdown', (e) => { dragging = true; track.setPointerCapture(e.pointerId); zoomAt(e); });
  track.addEventListener('pointermove', (e) => { if (dragging) zoomAt(e); });
  const stop = () => { dragging = false; };
  track.addEventListener('pointerup', stop);
  track.addEventListener('pointercancel', stop);
  $('zs-in').addEventListener('click', () => map.zoomIn());
  $('zs-out').addEventListener('click', () => map.zoomOut());
  map.on('zoomend', pos);
  window.addEventListener('resize', pos);
  pos();
}

function setAllVisible(on) {
  P.hide = { grid: !on, edge: !on, meet: !on };
  for (const m of P.marks) m.hidden = !on;
  for (const it of P.items) it.hidden = !on;
  renderViewToggles();
  changed();
}
$('view-none').addEventListener('click', () => setAllVisible(false));
$('view-all').addEventListener('click', () => setAllVisible(true));
$('grid-draw').addEventListener('click', () => { closePanels(); setTool('grid'); });
$('grid-view').addEventListener('click', () => {
  const b = map.getBounds().pad(-0.08);
  if (setArea({ north: b.getNorth(), south: b.getSouth(), west: b.getWest(), east: b.getEast() })) closePanels();
});
$('grid-remove').addEventListener('click', () => {
  const multi = allGrids(P).length > 1;
  if (!grid && !multi) return;
  if (!confirm(multi ? `Rastergebiet „${gridLabel(P, { name: P.gridName })}“ mit seinen Feldzuteilungen entfernen?` : 'Raster und Feldzuteilungen entfernen?')) return;
  snapshot();
  removeActiveGrid(P);
  syncGrid();
  changed();
});
$('clear-fills').addEventListener('click', () => {
  const any = allGrids(P).some((g) => Object.keys(g.fills).length || Object.keys(g.status).length);
  if (!any || !confirm('Alle Feldfarben und Zuteilungen löschen (in allen Rastergebieten)?')) return;
  snapshot();
  P.fills = {};
  P.status = {};
  P.otherGrids = P.otherGrids.map((g) => ({ ...g, fills: {}, status: {} }));
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
  if (allGrids(P).length) {
    const c = hitGrid(e.latlng.lat, e.latlng.lng);
    if (c) {
      const v = gridView(P, c.g);
      const m = cellOwner(v, c.c, c.r);
      const st = cellStatus(v, c.c, c.r);
      parts.push(`Feld ${c.label}${cellLabel(c.c, c.r)}${m ? ` – ${markLabel(m)}` : ''}${st ? ` (${st.label})` : ''}`);
    } else parts.push('Außerhalb des Rasters');
  }
  const rp = rescueAt(e.containerPoint);
  if (rp) parts.unshift(`🚑 Rettungspunkt ${rp.n} (${rp.lat.toFixed(5)}, ${rp.lon.toFixed(5)})`);
  if (P.showUtm) parts.push(formatMgrs(e.latlng.lat, e.latlng.lng));
  if (parts.length) toast(parts.join(' · '), rp ? 8000 : 3500);
});

// ---------- Offline-Karten ----------
// Bereiche (für alle Suchgebiete gemeinsam) in db.offline:
// { id, name, bounds, layerIds, zMin, zMax, done, total, failed, bytes, finished }
if (!Array.isArray(db.offline)) db.offline = [];
// Android-App: ein eigener Dienst lädt im Hintergrund und liefert die Bilder selbst aus.
// Im Browser-Speicher (Cache) liegen dann nur noch Bereiche aus älteren Versionen.
const NATIVE_OFF = !!(bridge && bridge.offlineStart);
const refreshHasOffline = () => setHasOffline(db.offline.some((r) => !(NATIVE_OFF && r.native)));
refreshHasOffline();
let offRect = null; // aufgezogenes Rechteck
let offJob = null; // { id, ctrl }
const fmtMB = (mb) => (mb >= 1024 ? `${(mb / 1024).toLocaleString('de-DE', { maximumFractionDigits: 1 })} GB` : `${Math.max(1, Math.round(mb))} MB`);
const fmtMin = (m) => (m >= 90 ? `ca. ${Math.round(m / 60)} Std.` : `ca. ${Math.max(1, Math.round(m))} Min.`);
const ZOOMS = {
  12: 'grobe Übersicht', 13: 'Übersicht', 14: 'Orte, Hauptstraßen', 15: 'Wege erkennbar',
  16: 'gut', 17: 'scharf', 18: 'sehr scharf', 19: 'volle Luftbild-Schärfe',
};

// gewählter Bereich als Liste von Rechtecken (Quadrate) oder null
function offAreas() {
  const v = $('off-area').value;
  if (v === 'squares') return offSel.size ? [...offSel].map(squareBounds) : null;
  const b = offBounds(v);
  return b ? [b] : null;
}
function offBounds(v) {
  if (STATES[v]) return STATES[v].bounds;
  if (v === 'rect') return offRect;
  if (v === 'grid') {
    const gs = allGrids(P);
    if (!gs.length) return null;
    const b = { north: -90, south: 90, west: 180, east: -180 };
    for (const g of gs) {
      b.north = Math.max(b.north, g.area.north, g.area.south); b.south = Math.min(b.south, g.area.north, g.area.south);
      b.west = Math.min(b.west, g.area.west, g.area.east); b.east = Math.max(b.east, g.area.west, g.area.east);
    }
    // 500 m Rand rundherum
    const dLat = 0.0045;
    const dLon = dLat / Math.cos((b.north * Math.PI) / 180);
    return { north: b.north + dLat, south: b.south - dLat, west: b.west - dLon, east: b.east + dLon };
  }
  return viewBounds();
}
function offLayerIds() {
  const id = $('off-layer').value;
  const def = layerById(id);
  return def.aerial && $('off-paths').checked ? [id, ...OVERLAYS.map((o) => o.id)] : [id];
}
const offDef = (id) => LAYERS.find((l) => l.id === id) || OVERLAYS.find((o) => o.id === id);
function offDefaultName() {
  const v = $('off-area').value;
  const area = STATES[v] ? STATES[v].name.replace(/ \(.*/, '')
    : v === 'squares' ? `${offSel.size} Quadrat${offSel.size === 1 ? '' : 'e'}`
      : v === 'grid' ? (P.title || 'Suchgebiet') : v === 'rect' ? 'Bereich' : 'Kartenausschnitt';
  const [a, b] = offZooms();
  return `${area} – ${layerById($('off-layer').value).name.replace(/ \(.*/, '')}, Stufe ${a === b ? a : `${a}–${b}`}`;
}
// gewählte Stufen [von, bis]
function offZooms() {
  const a = Number($('off-zmin').value);
  const b = Number($('off-zmax').value);
  return [Math.min(a, b), Math.max(a, b)];
}
// Vorgaben je Bereich: ganzes Land grob, Quadrate scharf
function offPresetZooms() {
  const v = $('off-area').value;
  if (STATES[v]) { $('off-zmin').value = '12'; $('off-zmax').value = '15'; }
  else if (v === 'squares') { $('off-zmin').value = '15'; $('off-zmax').value = '18'; }
}
function updateOffSqBar() {
  const n = offSel.size;
  let text = n ? `${n} Quadrat${n === 1 ? '' : 'e'} gewählt` : 'Quadrate antippen';
  if (n) {
    const [a, b] = offZooms();
    text += ` · Stufe ${a}–${b} ≈ ${fmtMB(estimate(offLayerIds().map(offDef), [...offSel].map(squareBounds), a, b).mb)}`;
  }
  $('offsq-info').textContent = text;
  $('offsq-done').disabled = !n;
}
$('offsq-clear').addEventListener('click', () => { offSel.clear(); updateOffSqBar(); redraw(); });
const backToOffline = () => { setTool('pan'); redraw(); renderOfflineForm(); openPanel('panel-offline'); };
$('offsq-done').addEventListener('click', () => { $('off-area').value = 'squares'; backToOffline(); });
$('offsq-cancel').addEventListener('click', backToOffline);
$('off-squares').addEventListener('click', () => {
  if ($('off-area').value !== 'squares') { $('off-area').value = 'squares'; offPresetZooms(); }
  closePanels();
  if (map.getZoom() < 10) toast('Zum gewünschten Ort zoomen, dann Quadrate antippen');
  setTool('offsquares');
  redraw();
});

function renderOfflineForm() {
  const sel = $('off-layer');
  $('off-wifi').parentElement.hidden = !NATIVE_OFF;
  $('off-help').textContent = NATIVE_OFF
    ? 'Vor dem Einsatz laden. Lädt im Hintergrund weiter, auch bei ausgeschaltetem Bildschirm (Fortschritt in der Benachrichtigung), und speichert auf der SD-Karte, falls vorhanden. Gespeicherte Bilder nimmt die App immer zuerst, auch für PDF und Garmin-Karte; Fehlendes kommt aus dem Internet.'
    : 'Vor dem Einsatz im WLAN laden. Gespeicherte Kartenbilder nimmt die App immer zuerst – sofort, auch ohne oder mit schlechtem Netz; nur Fehlendes kommt aus dem Internet. Gilt auch für PDF und Garmin-Karte. Beim Laden App geöffnet lassen; angehaltene Downloads laufen mit ▶ weiter.';
  if (!sel.options.length) {
    for (const l of LAYERS) sel.add(new Option(l.name, l.id));
    for (let z = 6; z <= 19; z++) {
      for (const id of ['off-zmin', 'off-zmax']) $(id).add(new Option(ZOOMS[z] ? `${z} – ${ZOOMS[z]}` : String(z), String(z)));
    }
    offPresetZooms();
  }
  if (!sel.dataset.touched) sel.value = P.layerId;
  $('off-area').querySelector('[value=grid]').disabled = !allGrids(P).length;
  if ($('off-area').value === 'grid' && !allGrids(P).length) $('off-area').value = 'view';
  updateOffEstimate();
  renderOfflineList();
}
// Speicher: { usedMB, freeMB, text }
async function offStorage() {
  if (NATIVE_OFF) {
    try {
      const s = JSON.parse(bridge.offlineStorage());
      return { usedMB: s.usedMB, freeMB: s.freeMB, text: `belegt ca. ${fmtMB(s.usedMB)}${s.place ? ` (${s.place})` : ''} · frei ${fmtMB(s.freeMB)}` };
    } catch { return null; }
  }
  const s = await storageInfo();
  return s && { usedMB: s.usedMB, freeMB: s.quotaMB - s.usedMB, text: `belegt ca. ${fmtMB(s.usedMB)} von ${fmtMB(s.quotaMB)}` };
}

async function updateOffEstimate() {
  const b = offAreas();
  $('off-paths').parentElement.hidden = !layerById($('off-layer').value).aerial;
  $('off-name').placeholder = offDefaultName();
  if (!b) {
    const v = $('off-area').value;
    $('off-est').textContent = v === 'rect' ? 'Noch kein Rechteck – „Rechteck aufziehen“ tippen.'
      : v === 'squares' ? 'Noch keine Quadrate – „Quadrate wählen“ tippen.' : 'Kein Bereich.';
    return;
  }
  const [zMin, z] = offZooms();
  const defs = offLayerIds().map(offDef);
  const e = estimate(defs, b, zMin, z);
  const capped = defs.some((d) => z > maxZoom(d));
  let text = `≈ ${e.tiles.toLocaleString('de-DE')} Kartenbilder · ≈ ${fmtMB(e.mb)} · Dauer ${fmtMin(e.minutes)} (je nach Netz)`;
  // je Stufe, damit man sieht, welche Stufe wie viel kostet
  if (z > zMin) {
    const per = [];
    for (let k = zMin; k <= z; k++) per.push(`St. ${k}: ${fmtMB(estimate(defs, b, k, k).mb)}`);
    text += ` · ${per.join(' · ')}`;
  }
  if (capped) text += ' · Karte hat höchstens Stufe ' + Math.min(...defs.map(maxZoom));
  const s = await offStorage();
  if (s && s.freeMB) {
    text += ` · frei ca. ${fmtMB(s.freeMB)}`;
    if (e.mb > s.freeMB * 0.9) text += ' ⚠️ passt vermutlich nicht auf dieses Gerät – geringere Stufe oder kleineren Bereich wählen';
  }
  $('off-est').textContent = text;
}
['off-area', 'off-layer', 'off-paths', 'off-zmin', 'off-zmax'].forEach((id) => $(id).addEventListener('change', () => {
  if (id === 'off-layer') $('off-layer').dataset.touched = '1';
  if (id === 'off-area') offPresetZooms();
  updateOffEstimate();
}));

let offListToken = 0;
async function renderOfflineList() {
  const box = $('off-list');
  // mehrere Aufrufe kurz nacheinander: nur der letzte zeichnet
  const token = ++offListToken;
  const s = await offStorage();
  if (token !== offListToken) return;
  box.innerHTML = '';
  $('off-storage').textContent = db.offline.length
    ? `Gespeichert: ${db.offline.length} Bereich${db.offline.length > 1 ? 'e' : ''}${s ? ` · ${s.text}` : ''}`
    : 'Noch keine Offline-Karten gespeichert.';
  for (const r of db.offline) {
    const row = document.createElement('div');
    row.className = 'offrow';
    const running = offJob && offJob.id === r.id;
    const pct = r.total ? Math.floor((100 * r.done) / r.total) : 0;
    const info = document.createElement('div');
    info.innerHTML = '<b></b><small></small>';
    info.firstChild.textContent = r.name;
    info.lastChild.textContent = r.finished
      ? `✔ fertig · ${r.total.toLocaleString('de-DE')} Bilder · ${fmtMB((r.bytes || 0) / 1048576)}${r.failed ? ` (${r.failed} fehlgeschlagen)` : ''}`
      : `${running ? (offWaiting ? `⏳ wartet auf ${offWaiting}` : '⏳ lädt') : '⏸ angehalten'} · ${pct} % (${r.done.toLocaleString('de-DE')} von ${r.total.toLocaleString('de-DE')}) · ${fmtMB((r.bytes || 0) / 1048576)}`;
    const btns = document.createElement('span');
    const act = document.createElement('button');
    act.textContent = running ? '⏸' : r.finished ? '↻' : '▶';
    act.title = running ? 'Anhalten (später weiterladen)' : r.finished ? 'Fehlende nachladen / aktualisieren' : 'Weiterladen';
    act.addEventListener('click', () => (running ? stopOffline() : runOffline(r)));
    const cancel = document.createElement('button');
    cancel.textContent = '✕';
    cancel.title = 'Download abbrechen';
    cancel.className = 'danger';
    cancel.addEventListener('click', () => cancelOffline(r));
    const go = document.createElement('button');
    go.textContent = '🔍';
    go.title = 'Auf der Karte zeigen';
    go.addEventListener('click', () => {
      closePanels();
      map.fitBounds([[r.bounds.south, r.bounds.west], [r.bounds.north, r.bounds.east]]);
    });
    const del = document.createElement('button');
    del.textContent = '🗑️';
    del.title = 'Löschen';
    del.addEventListener('click', async () => {
      if (running || !confirm(`Offline-Karte „${r.name}“ löschen?`)) return;
      del.disabled = true;
      del.textContent = '…';
      await removeOffline(r);
    });
    if (running) btns.append(act, cancel, go); else btns.append(act, go, del);
    row.append(info, btns);
    box.appendChild(row);
  }
}

// Bereich samt gespeicherter Kartenbilder löschen (Bilder, die ein anderer Bereich braucht, bleiben)
async function removeOffline(r) {
  const others = db.offline.filter((x) => x.id !== r.id);
  const defs = r.layerIds.map(offDef).filter(Boolean);
  if (NATIVE_OFF) {
    bridge.offlineDelete(JSON.stringify({
      region: { ...nativeJob(r, defs), layerIds: r.layerIds },
      others: others.map((o) => ({ bounds: o.bounds, areas: o.areas, zMin: o.zMin, zMax: o.zMax, layerIds: o.layerIds })),
    }));
  }
  // ältere Bereiche (oder Browser) liegen im Cache-Speicher
  if (!NATIVE_OFF || !r.native) await deleteRegion(r, defs, others, offDef);
  db.offline = others;
  refreshHasOffline();
  if (NATIVE_OFF) setTimeout(syncNativeOffline, 300);
  saveNow();
  renderOfflineList();
}
function stopOffline() {
  if (!offJob) return;
  if (offJob.native) bridge.offlineStop(); else offJob.ctrl.abort();
}
// Abbrechen: anhalten und (auf Wunsch) das bisher Geladene löschen
async function cancelOffline(r) {
  const choice = await openDlg((box, close) => {
    dlgHead(box, '✕ Download abbrechen?', `„${r.name}“ – bisher ${r.total ? Math.floor((100 * r.done) / r.total) : 0} % geladen.`);
    const list = document.createElement('div');
    list.className = 'dlg-btns';
    box.appendChild(list);
    dlgButton(list, 'Abbrechen und Geladenes löschen<small>Platz wird wieder frei</small>', 'primary', () => close('delete'));
    dlgButton(list, 'Nur anhalten<small>Später mit ▶ weiterladen</small>', '', () => close('pause'));
    dlgButton(list, 'Weiterladen', '', () => close(null));
  });
  if (!choice) return;
  stopOffline();
  if (choice === 'pause') return;
  toast('Download wird abgebrochen …');
  // warten, bis der Download wirklich steht, dann löschen
  for (let i = 0; i < 75 && offJob && offJob.id === r.id; i++) {
    if (NATIVE_OFF) syncNativeOffline();
    await new Promise((res) => setTimeout(res, 200));
  }
  await removeOffline(r);
  toast(`„${r.name}“ abgebrochen und gelöscht`);
}

// Android-App: Stand vom Dienst abholen (läuft auch weiter, wenn die App zu ist)
let offWaiting = '';
let offPoll = null;
function syncNativeOffline() {
  let st;
  try { st = JSON.parse(bridge.offlineStatus()); } catch { return; }
  for (const r of db.offline) {
    const n = st.regions[r.id];
    if (n) Object.assign(r, { done: n.done, total: n.total, failed: n.failed, bytes: n.bytes, finished: n.finished, native: true });
  }
  offWaiting = st.waiting || '';
  if (st.running && !offJob) offJob = { id: st.running, native: true };
  if (offJob && offJob.native && st.running !== offJob.id) {
    const r = db.offline.find((x) => x.id === offJob.id);
    offJob = null;
    if (st.error) toast('Offline-Karte: ' + st.error);
    else if (r) toast(r.finished ? `Offline-Karte „${r.name}“ fertig` : `„${r.name}“ angehalten – ▶ lädt weiter`);
    saveNow();
  } else save();
  // in der Benachrichtigung abgebrochen -> hier löschen
  for (const r of db.offline) {
    const n = st.regions[r.id];
    if (n && n.cancelled && st.running !== r.id && !(offJob && offJob.id === r.id)) setTimeout(() => removeOffline(r), 0);
  }
  if (!$('panel-offline').hidden) renderOfflineList();
  const busy = offJob || st.deleting;
  if (busy && !offPoll) offPoll = setInterval(syncNativeOffline, 1000);
  if (!busy && offPoll) { clearInterval(offPoll); offPoll = null; }
}
if (NATIVE_OFF) syncNativeOffline();

async function runOffline(r) {
  if (offJob) return toast('Es lädt bereits eine Offline-Karte.');
  if (NATIVE_OFF) {
    const defs = r.layerIds.map(offDef).filter(Boolean);
    r.native = true;
    r.finished = false;
    saveNow();
    bridge.offlineStart(JSON.stringify(nativeJob(r, defs, $('off-wifi').checked)));
    offJob = { id: r.id, native: true };
    toast('Lädt im Hintergrund – auch bei ausgeschaltetem Bildschirm. Fortschritt in der Benachrichtigung.');
    renderOfflineList();
    if (!offPoll) offPoll = setInterval(syncNativeOffline, 1000);
    return;
  }
  const ctrl = new AbortController();
  offJob = { id: r.id, ctrl };
  persistStorage();
  // Bildschirm anlassen, solange geladen wird (sonst hält das Handy die App an)
  let lock = null;
  try { lock = await navigator.wakeLock.request('screen'); } catch { /* nicht unterstützt */ }
  renderOfflineList();
  try {
    const startBytes = r.bytes || 0;
    const res = await downloadRegion(r, r.layerIds.map(offDef).filter(Boolean), (st) => {
      Object.assign(r, { done: st.done, total: st.total, failed: st.failed, bytes: startBytes + st.bytes });
      save();
      if (!$('panel-offline').hidden) renderOfflineList();
    }, ctrl.signal);
    Object.assign(r, { done: res.done, total: res.total, failed: res.failed, bytes: startBytes + res.bytes });
    r.finished = !ctrl.signal.aborted && res.done >= res.total;
    toast(r.finished ? `Offline-Karte „${r.name}“ fertig` : `„${r.name}“ angehalten – ▶ lädt weiter`);
  } catch (err) {
    toast('Offline-Karte: ' + err.message);
  } finally {
    offJob = null;
    if (lock) lock.release().catch(() => {});
    refreshHasOffline();
    saveNow();
    renderOfflineList();
  }
}

$('off-start').addEventListener('click', () => {
  if ($('off-area').value === 'rect' && !offRect) {
    closePanels();
    setTool('offrect');
    return;
  }
  if ($('off-area').value === 'squares' && !offSel.size) return $('off-squares').click();
  const areas = offAreas();
  if (!areas) return toast('Kein Bereich gewählt');
  const [zMin, z] = offZooms();
  const squares = $('off-area').value === 'squares' ? [...offSel] : null;
  const r = {
    id: uid(),
    name: $('off-name').value.trim() || offDefaultName(),
    bounds: unionBounds(areas),
    ...(squares ? { areas, squares } : {}),
    layerIds: offLayerIds(),
    zMin,
    zMax: z,
    done: 0,
    total: 0,
    failed: 0,
    finished: false,
  };
  db.offline.push(r);
  $('off-name').value = '';
  offRect = null;
  offSel = new Set();
  saveNow();
  runOffline(r);
});
$('off-redraw').addEventListener('click', () => { closePanels(); setTool('offrect'); });
// So sieht die gewählte Stufe aus: Karte dieser Art in genau dieser Zoomstufe zeigen
$('off-preview').addEventListener('click', () => {
  const z = Number($('off-zmax').value);
  const id = $('off-layer').value;
  if (P.layerId !== id) setLayer(id);
  closePanels();
  map.setZoom(z);
  toast(`Stufe ${z} (${ZOOMS[z]}) – so scharf wird die Offline-Karte. Stufe steht links am Zoom-Regler.`);
});

// ---------- Rettungspunkte ----------
// Für alle Einsätze gemeinsam, in IndexedDB (können zehntausende sein); db.rescueOn = anzeigen
if (db.rescueOn === undefined) db.rescueOn = true;
function rescueInView() {
  if (!db.rescueOn || !rescuePts.length || !map || map.getZoom() < 11) return null;
  const b = map.getBounds();
  const pts = inBounds(rescuePts, { north: b.getNorth(), south: b.getSouth(), west: b.getWest(), east: b.getEast() });
  return pts.length > 3000 ? null : pts;
}
function rescueAt(pt) {
  const pts = rescueInView();
  if (!pts) return null;
  let best = null;
  for (const p of pts) {
    const q = map.latLngToContainerPoint([p.lat, p.lon]);
    const d = Math.hypot(q.x - pt.x, q.y - pt.y);
    if (d < 22 && (!best || d < best.d)) best = { p, d };
  }
  return best && best.p;
}
// Für das PDF: Punkte rund um alle Rastergebiete und den Ausschnitt
function rescueForExport() {
  if (!db.rescueOn || !rescuePts.length) return null;
  const bs = allGrids(P).map((g) => ({
    north: Math.max(g.area.north, g.area.south), south: Math.min(g.area.north, g.area.south),
    west: Math.min(g.area.west, g.area.east), east: Math.max(g.area.west, g.area.east),
  }));
  bs.push(viewBounds());
  const pad = 0.05;
  return inBounds(rescuePts, {
    north: Math.max(...bs.map((b) => b.north)) + pad, south: Math.min(...bs.map((b) => b.south)) - pad,
    west: Math.min(...bs.map((b) => b.west)) - pad, east: Math.max(...bs.map((b) => b.east)) + pad,
  });
}
function renderRescueInfo() {
  $('rp-info').textContent = rescuePts.length
    ? `${rescuePts.length.toLocaleString('de-DE')} Rettungspunkte gespeichert${db.rescueOn ? ' – sichtbar ab Zoomstufe 11' : ''}.`
    : 'Noch keine Rettungspunkte importiert.';
  $('rp-show').checked = !!db.rescueOn;
  $('rp-nearest').disabled = !rescuePts.length;
  $('rp-clear').disabled = !rescuePts.length;
  $('quick-rp').hidden = !rescuePts.length;
}
// gespeicherte Punkte laden – nicht überschreiben, was ein Auftrag-Link inzwischen mitgebracht hat
loadRescue().then((pts) => { rescuePts = mergeRescue(pts, rescuePts); renderRescueInfo(); redraw(); });

let rpMarker = null;
function showNearestRescue() {
  if (!rescuePts.length) return toast('Noch keine Rettungspunkte importiert (Karte → Rettungspunkte)');
  const fromGps = !!gpsMarker;
  const o = fromGps ? gpsMarker.getLatLng() : map.getCenter();
  const r = nearestRescue(rescuePts, o.lat, o.lng);
  if (!r) return;
  closePanels();
  if (rpMarker) map.removeLayer(rpMarker);
  rpMarker = L.circleMarker([r.p.lat, r.p.lon], { radius: 18, color: '#1b7f3b', weight: 4, fill: false, className: 'rp-pulse' }).addTo(map);
  setTimeout(() => { if (rpMarker) { map.removeLayer(rpMarker); rpMarker = null; } }, 15000);
  map.setView([r.p.lat, r.p.lon], Math.max(map.getZoom(), 15));
  const dist = r.m >= 1000 ? `${(r.m / 1000).toLocaleString('de-DE', { maximumFractionDigits: 1 })} km` : `${Math.round(r.m)} m`;
  toast(`🚑 Nächster Rettungspunkt: ${r.p.n} – ${dist} Richtung ${compass(r.deg)} (${Math.round(r.deg)}°) vom ${fromGps ? 'GPS-Standort' : 'Kartenmittelpunkt'} · ${r.p.lat.toFixed(5)}, ${r.p.lon.toFixed(5)} · ${formatMgrs(r.p.lat, r.p.lon)}`, 15000);
}
$('rp-nearest').addEventListener('click', showNearestRescue);
$('quick-rp').addEventListener('click', showNearestRescue);
$('rp-show').addEventListener('change', () => { db.rescueOn = $('rp-show').checked; saveNow(); renderRescueInfo(); redraw(); });
$('rp-import').addEventListener('click', () => $('rp-file').click());
$('rp-file').addEventListener('change', async (e) => {
  const files = [...e.target.files];
  e.target.value = '';
  let added = [];
  for (const f of files) {
    try { added = added.concat(parseRescue(await f.text())); } catch { /* unten gemeldet */ }
  }
  if (!added.length) return toast('Keine Rettungspunkte in der Datei gefunden (GPX-Wegpunkte, KML-Punkte oder CSV mit Koordinaten)', 6000);
  rescuePts = mergeRescue(rescuePts, added);
  try {
    await storeRescue(rescuePts);
  } catch {
    return toast('Speichern fehlgeschlagen (Speicher voll?)');
  }
  db.rescueOn = true;
  saveNow();
  renderRescueInfo();
  redraw();
  toast(`${added.length.toLocaleString('de-DE')} Rettungspunkte übernommen – insgesamt ${rescuePts.length.toLocaleString('de-DE')}`, 5000);
});
$('rp-clear').addEventListener('click', async () => {
  if (!confirm(`Alle ${rescuePts.length} Rettungspunkte löschen?`)) return;
  rescuePts = [];
  await storeRescue([]).catch(() => {});
  renderRescueInfo();
  redraw();
});

// ---------- Wetter und Wind ----------
// Overlay zuschaltbar (db.wxOn); Daten vom DWD (Bright Sky), letzter Stand in db.wxLast.
// Gemessener Wind (Kompass) steht im Windprotokoll des Einsatzes (M().wind) und hat Vorrang.
if (db.wxOn === undefined) db.wxOn = false;
const hhmm = (t) => new Date(t).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
function wxPoint() {
  if (P.windPt) return P.windPt;
  if (P.area) return { lat: (P.area.north + P.area.south) / 2, lon: (P.area.west + P.area.east) / 2 };
  const c = map.getCenter();
  return { lat: c.lat, lon: c.lng };
}
function lastMeasured() {
  const w = [...(P.mission.wind || [])].reverse().find((x) => x.src === 'gemessen');
  return w && Date.now() - w.t < 3 * 3600e3 ? w : null;
}
function dwdText(c) {
  return `aus ${dirName(c.from)} (${Math.round(c.from)}°) · ${Math.round(c.kmh)} km/h${c.gust ? `, Böen ${Math.round(c.gust)}` : ''} · Bft ${beaufort(c.kmh)}`;
}
function renderWx() {
  $('quick-wx').classList.toggle('on', !!db.wxOn);
  $('wx').hidden = !db.wxOn;
  if (!db.wxOn) return;
  $('wx-body').hidden = !!db.wxMin;
  $('wx-min').textContent = db.wxMin ? '▸' : '▾';
  const wx = db.wxLast;
  const c = wx && wx.current && wx.current.from != null && wx.current.kmh != null ? wx.current : null;
  const meas = lastMeasured();
  const arrow = $('wx-arrow');
  const from = meas ? meas.from : c ? c.from : null;
  arrow.style.visibility = from == null ? 'hidden' : 'visible';
  // Pfeil zeigt, wohin der Wind weht
  if (from != null) arrow.style.transform = `rotate(${from + 180}deg)`;
  arrow.classList.toggle('measured', !!meas);
  const age = c ? Math.round((Date.now() - c.t) / 60000) : 0;
  const dwdSrc = c ? `DWD ${c.station}${c.km != null ? ` (${Math.round(c.km)} km)` : ''} · ${hhmm(c.t)}${age > 90 ? ` – Stand vor ${Math.round(age / 60)} Std.` : ''}` : '';
  if (meas) {
    $('wx-wind').textContent = `aus ${dirName(meas.from)} (${Math.round(meas.from)}°) · ${STRENGTHS[meas.strength].label}`;
    $('wx-src').textContent = `vor Ort gemessen · ${hhmm(meas.t)}`;
    $('wx-second').hidden = !c;
    if (c) $('wx-second').textContent = `${dwdSrc}: ${dwdText(c)}`;
  } else if (c) {
    $('wx-wind').textContent = dwdText(c);
    $('wx-src').textContent = dwdSrc;
    $('wx-second').hidden = true;
  } else {
    $('wx-wind').textContent = 'Noch kein Wind';
    $('wx-src').textContent = navigator.onLine ? 'Wird geladen … oder 🧭 Wind messen' : 'Kein Netz – 🧭 Wind messen';
    $('wx-second').hidden = true;
  }
  $('wx-approach').textContent = from != null ? `Ansatz: ${approach(from)}` : '';
  const more = [];
  if (c && c.temp != null) more.push(`${WX_ICONS[c.icon] || ''} ${Math.round(c.temp)} °C`.trim());
  if (c && c.rain) more.push(`Regen ${c.rain.toLocaleString('de-DE')} mm/h`);
  const pt = wxPoint();
  const sun = sunTimes(new Date(), pt.lat, pt.lon);
  if (sun) {
    const now = Date.now();
    if (now < sun.set && now > sun.rise) {
      const left = Math.round((sun.set - now) / 60000);
      more.push(`Sonnenuntergang ${hhmm(sun.set)} (noch ${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')} h)`);
    } else more.push(`Sonnenaufgang ${hhmm(now > sun.set ? sun.rise + 864e5 : sun.rise)}`);
  }
  $('wx-more').textContent = more.join(' · ');
  // anderes Suchgebiet / Windpunkt weit weg vom geladenen Ort: neu laden
  if (wx && !wxLoading && navigator.onLine && distance(wx.lat, wx.lon, pt.lat, pt.lon) > 3000) setTimeout(() => loadWeather(false), 0);
  const box = $('wx-hours');
  box.innerHTML = '';
  for (const h of (wx && wx.hours) || []) {
    if (h.from == null) continue;
    const d = document.createElement('div');
    d.innerHTML = `<div></div><i>↑</i><div></div>`;
    d.firstChild.textContent = `${new Date(h.t).getHours()} Uhr`;
    d.children[1].style.transform = `rotate(${h.from + 180}deg)`;
    d.lastChild.textContent = `${dirName(h.from)} ${Math.round(h.kmh)}${h.prob ? ` · ${h.prob}%` : ''}`;
    d.title = `${dirName(h.from)} ${Math.round(h.kmh)} km/h${h.gust ? `, Böen ${Math.round(h.gust)}` : ''}${h.prob != null ? `, Regen ${h.prob} %` : ''}`;
    box.appendChild(d);
  }
}
let wxLoading = false;
async function loadWeather(manual) {
  if (!(db.wxOn || db.windArrows) || wxLoading) return;
  wxLoading = true;
  $('wx-refresh').disabled = true;
  try {
    const pt = wxPoint();
    const wx = await fetchWeather(pt.lat, pt.lon);
    db.wxLast = wx;
    // Messstationen ringsum (für die Windpfeile)
    if (db.windArrows) db.wxStations = await fetchStations(pt.lat, pt.lon).catch(() => db.wxStations || null);
    const c = wx.current;
    // deutliche Änderung (Drehung ≥ 45° oder ±2 Bft) kommt ins Windprotokoll des Einsatzes
    if (c.from != null && c.kmh != null) {
      const last = [...(M().wind || [])].reverse().find((w) => w.src === 'DWD');
      if ((!last || last.t !== c.t) && windChanged(last, c)) {
        (M().wind ||= []).push({ t: c.t, from: c.from, kmh: c.kmh, gust: c.gust, station: c.station, src: 'DWD' });
        touch();
      }
    }
    saveNow();
  } catch {
    if (manual) toast('Wetter nicht abrufbar (kein Netz?) – angezeigt wird der letzte Stand');
  } finally {
    wxLoading = false;
    $('wx-refresh').disabled = false;
    renderWx();
    redraw();
  }
}
$('quick-wx').addEventListener('click', () => {
  db.wxOn = !db.wxOn;
  saveNow();
  renderWx();
  redraw();
  if (db.wxOn) loadWeather(true);
});
$('wx-refresh').addEventListener('click', () => loadWeather(true));
$('wx-min').addEventListener('click', () => { db.wxMin = !db.wxMin; saveNow(); renderWx(); });
setInterval(() => { if ((db.wxOn || db.windArrows) && navigator.onLine) loadWeather(false); else renderWx(); }, 15 * 60e3);
$('quick-arrows').addEventListener('click', () => {
  db.windArrows = !db.windArrows;
  saveNow();
  $('quick-arrows').classList.toggle('on', !!db.windArrows);
  redraw();
  if (db.windArrows) {
    const stale = !db.wxLast || Date.now() - db.wxLast.fetched > 10 * 60e3 || !db.wxStations;
    if (stale) loadWeather(true);
    toast('Windpfeile: blau = DWD (Punkt/Suchgebiet und Messstationen), grün = selbst gemessen');
  }
});
$('quick-arrows').classList.toggle('on', !!db.windArrows);
window.addEventListener('online', () => loadWeather(false));
renderWx();
if ((db.wxOn || db.windArrows) && (!db.wxLast || Date.now() - db.wxLast.fetched > 10 * 60e3)) loadWeather(false);

// Wind messen: Kompass des Handys (Oberkante zeigt, wohin das Puder fliegt)
let wmBuf = [];
let wmHeading = null;
let wmFrom = null;
let wmTimer = null;
function wmOri(e) {
  let h = null;
  if (typeof e.webkitCompassHeading === 'number' && !Number.isNaN(e.webkitCompassHeading)) h = e.webkitCompassHeading;
  else if ((e.absolute || e.type === 'deviceorientationabsolute') && e.alpha != null) h = 360 - e.alpha;
  if (h == null) return;
  const ang = (screen.orientation && screen.orientation.angle) || window.orientation || 0;
  h = (((h + ang) % 360) + 360) % 360;
  wmBuf.push(h);
  if (wmBuf.length > 10) wmBuf.shift();
  wmHeading = circularMean(wmBuf);
  const tilted = e.beta != null && Math.abs(e.beta) > 55;
  $('wm-needle').style.transform = `rotate(${-wmHeading}deg)`;
  $('wm-read').textContent = tilted ? 'Handy flacher halten …'
    : `Puder fliegt nach ${dirName(wmHeading)} (${Math.round(wmHeading)}°) → Wind kommt aus ${dirName(wmHeading + 180)}`;
  $('wm-take').disabled = tilted;
  $('wm-manual').hidden = true;
}
function wmStop() {
  window.removeEventListener('deviceorientationabsolute', wmOri);
  window.removeEventListener('deviceorientation', wmOri);
  clearTimeout(wmTimer);
}
function wmStep2(from) {
  wmFrom = (from + 360) % 360;
  wmStop();
  $('wm-step1').hidden = true;
  $('wm-step2').hidden = false;
  $('wm-dir').textContent = `Wind kommt aus ${dirName(wmFrom)} (${Math.round(wmFrom)}°)`;
}
async function openWindMeter() {
  wmBuf = [];
  wmHeading = null;
  $('windmeter').hidden = false;
  $('wm-step1').hidden = false;
  $('wm-step2').hidden = true;
  $('wm-take').disabled = true;
  $('wm-read').textContent = 'Kompass wird gestartet …';
  $('wm-manual').hidden = true;
  // iPhone: Erlaubnis für den Kompass (muss direkt aus dem Antippen kommen)
  if (window.DeviceOrientationEvent && typeof DeviceOrientationEvent.requestPermission === 'function') {
    try { await DeviceOrientationEvent.requestPermission(); } catch { /* dann Handauswahl */ }
  }
  window.addEventListener('deviceorientationabsolute', wmOri);
  window.addEventListener('deviceorientation', wmOri);
  wmTimer = setTimeout(() => {
    if (wmHeading != null) return;
    $('wm-read').textContent = 'Kein Kompass verfügbar – antippen, wohin das Puder fliegt:';
    $('wm-manual').hidden = false;
  }, 2500);
}
{
  const box = $('wm-manual');
  ['N', 'NO', 'O', 'SO', 'S', 'SW', 'W', 'NW'].forEach((n, i) => {
    const b = document.createElement('button');
    b.textContent = `→ ${n}`;
    b.addEventListener('click', () => wmStep2(i * 45 + 180));
    box.appendChild(b);
  });
}
$('wm-take').addEventListener('click', () => { if (wmHeading != null) wmStep2(wmHeading + 180); });
$('wm-cancel').addEventListener('click', () => { wmStop(); $('windmeter').hidden = true; });
document.querySelectorAll('.wm-str button').forEach((b) => b.addEventListener('click', () => {
  const s = b.dataset.s;
  const pos = gpsMarker ? gpsMarker.getLatLng() : map.getCenter();
  (M().wind ||= []).push({ t: Date.now(), from: Math.round(wmFrom), strength: s, src: 'gemessen', lat: pos.lat, lon: pos.lng });
  touch();
  $('windmeter').hidden = true;
  db.wxOn = true;
  saveNow();
  renderWx();
  redraw();
  toast(`Wind gemessen: aus ${dirName(wmFrom)}, ${STRENGTHS[s].label}. ${approach(wmFrom)}.`, 9000);
}));
$('wx-measure').addEventListener('click', openWindMeter);
$('wx-point').addEventListener('click', () => { setTool('windpt'); toast('Auf die Karte tippen: dort wird der Wind angezeigt'); });

// ---------- Hundeführer-Modus, Aufträge und Rückmeldungen per QR-Code ----------
// db.mode: 'el' (Einsatzleitung, alles) | 'hf' (Hundeführer, vereinfacht). Wechsel zur
// Einsatzleitung nur mit der festen PIN (hier nur als Prüfsumme hinterlegt).
const EL_PIN_HASH = '99d942b4880b6f1c';
delete db.pinHash; // früher frei wählbare PIN – gilt nicht mehr
async function pinHash(pin) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`suchgebiet:${pin}`));
  return [...new Uint8Array(d)].slice(0, 8).map((b) => b.toString(16).padStart(2, '0')).join('');
}
function openDlg(build) {
  const box = $('dlg-box');
  box.innerHTML = '';
  $('dlg').hidden = false;
  return new Promise((resolve) => {
    build(box, (v) => { $('dlg').hidden = true; resolve(v); });
  });
}
function dlgHead(box, title, text) {
  const h = document.createElement('h2');
  h.textContent = title;
  box.appendChild(h);
  if (text) { const p = document.createElement('p'); p.className = 'small'; p.textContent = text; box.appendChild(p); }
}
function dlgButton(box, label, cls, fn) {
  const b = document.createElement('button');
  b.innerHTML = label;
  if (cls) b.className = cls;
  b.addEventListener('click', fn);
  box.appendChild(b);
  return b;
}
function askPin(title, text) {
  return openDlg((box, close) => {
    dlgHead(box, title, text);
    const inp = document.createElement('input');
    inp.type = 'password';
    inp.inputMode = 'numeric';
    inp.className = 'pin';
    inp.autocomplete = 'off';
    box.appendChild(inp);
    const ok = () => close(inp.value.trim() || null);
    inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') ok(); });
    dlgButton(box, 'OK', 'primary', ok);
    dlgButton(box, 'Abbrechen', '', () => close(null));
    setTimeout(() => inp.focus(), 50);
  });
}
function applyMode() {
  const hf = db.mode === 'hf';
  document.body.classList.toggle('hf', hf);
  $('hfbar').hidden = !hf;
  if (hf && !['pan', 'hffield'].includes(tool)) setTool('pan');
  renderHfInfo();
  map.invalidateSize();
  resizeCanvas();
}
async function toHfMode() {
  db.mode = 'hf';
  saveNow();
  closePanels();
  applyMode();
  toast('Hundeführer-Modus');
}
async function toElMode() {
  const pin = await askPin('🔒 Einsatzleitung', 'PIN eingeben, um in die Einsatzleitung zu wechseln.');
  if (!pin) return;
  if ((await pinHash(pin)) !== EL_PIN_HASH) return toast('Falsche PIN');
  if (recWatch !== null) stopRec();
  db.mode = 'el';
  saveNow();
  closePanels();
  setTool('pan');
  applyMode();
  toast('Einsatzleitung');
}
$('mode-hf').addEventListener('click', toHfMode);
$('hfm-el').addEventListener('click', toElMode);

// ---- Hundeführer-Ansicht ----
function hfColor() { return ((P.marks.find((m) => m.id === 'team') || {}).color) || '#d50000'; }
function renderHfInfo() {
  const show = db.mode === 'hf';
  $('hfinfo').hidden = !show;
  if (!show) return;
  const h = P.hf;
  $('hfinfo').style.setProperty('--team', hfColor());
  $('hfi-title').textContent = h ? `${h.team} · ${P.title.replace(/ – [^–]*$/, '')}` : 'Kein Auftrag';
  const rec = h ? h.track.reduce((a, sg) => a + pathLen(sg.pts), 0) : 0;
  $('hfi-text').textContent = h
    ? [h.hint && `⚠️ ${h.hint}`, `Auftrag ${hhmm(h.received)}`, rec ? `gelaufen ${fmtKm(rec)}` : ''].filter(Boolean).join(' · ')
    : 'QR-Code der Einsatzleitung mit der Handy-Kamera scannen.';
  $('hfinfo').classList.toggle('min', !!db.hfInfoMin);
  const m = $('hfm-info');
  m.textContent = '';
  if (h) {
    const lines = [`${h.team} – ${P.title}`, `Auftrag erhalten ${hhmm(h.received)}`];
    if (h.hint) lines.push(`Hinweis: ${h.hint}`);
    if (P.mission.person) lines.push(`Vermisste Person: ${P.mission.person}`);
    if (P.meet) lines.push(`B-Ort: ${P.meet.text || 'gesetzt'}`);
    m.textContent = lines.join('\n');
    m.style.whiteSpace = 'pre-line';
  } else m.textContent = 'Noch kein Auftrag. QR-Code der Einsatzleitung mit der Handy-Kamera scannen.';
  $('hfm-meet').disabled = !P.meet;
}
$('hfinfo').addEventListener('click', () => { db.hfInfoMin = !db.hfInfoMin; save(); renderHfInfo(); });
$('btn-hfmenu').addEventListener('click', () => { renderHfInfo(); openPanel('panel-hfmenu'); });
$('hfm-rp').addEventListener('click', showNearestRescue);
$('hfm-notes').addEventListener('click', () => { closePanels(); $('btn-notes').click(); });
$('hfm-contacts').addEventListener('click', () => { closePanels(); $('btn-contacts').click(); });
$('hfm-projects').addEventListener('click', () => { closePanels(); $('btn-projects').click(); });
$('hfm-meet').addEventListener('click', () => {
  if (!P.meet) return;
  closePanels();
  map.setView([P.meet.lat, P.meet.lon], Math.max(map.getZoom(), 16));
  if (lastPos) {
    const m = distance(lastPos[0], lastPos[1], P.meet.lat, P.meet.lon);
    const deg = bearingDeg(lastPos[0], lastPos[1], P.meet.lat, P.meet.lon);
    toast(`🎯 B-Ort: ${fmtKm(m)} Richtung ${compass(deg)} (${Math.round(deg)}°)`, 8000);
  }
});
function pathLen(pts) {
  let m = 0;
  for (let i = 1; i < pts.length; i++) m += distance(pts[i - 1][0], pts[i - 1][1], pts[i][0], pts[i][1]);
  return m;
}
const fmtKm = (m) => (m >= 1000 ? `${(m / 1000).toLocaleString('de-DE', { maximumFractionDigits: 1 })} km` : `${Math.round(m)} m`);

// Weg aufzeichnen (Bildschirm bleibt an; Browser zeichnen bei gesperrtem Bildschirm nicht auf)
let recWatch = null;
let recSeg = null;
let recLock = null;
let recTimer = null;
function ensureHf() {
  if (!P.hf) P.hf = { id: uid(), team: 'Ich', hint: '', received: Date.now(), grids: allGrids(P).map((g) => g.id), track: [] };
}
async function startRec() {
  if (!navigator.geolocation) return toast('Standort wird nicht unterstützt');
  ensureHf();
  recSeg = { t0: Date.now(), pts: [] };
  P.hf.track.push(recSeg);
  if (watchId === null) $('btn-gps').click();
  recWatch = navigator.geolocation.watchPosition((pos) => {
    if (pos.coords.accuracy > 40) return;
    const pt = [Math.round(pos.coords.latitude * 1e6) / 1e6, Math.round(pos.coords.longitude * 1e6) / 1e6];
    const last = recSeg.pts[recSeg.pts.length - 1];
    if (last && distance(last[0], last[1], pt[0], pt[1]) < 5) return;
    recSeg.pts.push(pt);
    save();
    redraw();
  }, (err) => toast('GPS: ' + err.message), { enableHighAccuracy: true, maximumAge: 0 });
  try { recLock = await navigator.wakeLock.request('screen'); } catch { if (bridge && bridge.keepScreenOn) bridge.keepScreenOn(true); }
  recTimer = setInterval(updateRecBtn, 5000);
  updateRecBtn();
  toast('Weg wird aufgezeichnet – Bildschirm bleibt an. Nicht sperren!', 6000);
}
function stopRec() {
  if (recWatch !== null) navigator.geolocation.clearWatch(recWatch);
  recWatch = null;
  if (recLock) recLock.release().catch(() => {});
  recLock = null;
  if (bridge && bridge.keepScreenOn) bridge.keepScreenOn(false);
  clearInterval(recTimer);
  if (recSeg && recSeg.pts.length < 2) P.hf.track = P.hf.track.filter((sg) => sg !== recSeg);
  recSeg = null;
  saveNow();
  updateRecBtn();
  redraw();
}
function updateRecBtn() {
  const on = recWatch !== null;
  $('hf-rec').classList.toggle('on', on);
  $('hf-rec').querySelector('span').textContent = on ? '⏹' : '⏺';
  $('hf-rec').querySelector('b').textContent = on
    ? `${fmtKm(pathLen(recSeg.pts))} · ${Math.round((Date.now() - recSeg.t0) / 60000)} min` : 'Weg';
  renderHfInfo();
}
document.addEventListener('visibilitychange', async () => {
  if (!document.hidden && recWatch !== null && !recLock) {
    try { recLock = await navigator.wakeLock.request('screen'); } catch { /* egal */ }
  }
});
$('hf-rec').addEventListener('click', () => (recWatch !== null ? stopRec() : startRec()));

// Markieren: Art wählen, Position = GPS (sonst Kartenmitte)
const HF_MARKS = [['⚠️', 'Anzeige'], ['✅', 'Fund'], ['🐾', 'Spur'], ['🎒', 'Gegenstand'], ['❗', 'Gefahr'], ['📝', 'Hinweis']];
$('hf-mark').addEventListener('click', () => {
  const gps = !!lastPos;
  const pos = gps ? { lat: lastPos[0], lon: lastPos[1] } : { lat: map.getCenter().lat, lon: map.getCenter().lng };
  openDlg((box, close) => {
    dlgHead(box, '📍 Markieren', gps ? 'Position: dein GPS-Standort.' : 'Kein GPS – Position: Kartenmitte. Karte vorher passend schieben.');
    const note = document.createElement('input');
    note.type = 'text';
    note.placeholder = 'Notiz (optional)';
    box.appendChild(note);
    const list = document.createElement('div');
    list.className = 'dlg-btns';
    box.appendChild(list);
    for (const [ico, label] of HF_MARKS) {
      dlgButton(list, `${ico} ${label}`, '', () => {
        ensureHf();
        const text = `${ico} ${label} ${hhmm(Date.now())}${note.value.trim() ? `: ${note.value.trim()}` : ''}`;
        P.items.push({ kind: 'text', color: hfColor(), lat: pos.lat, lon: pos.lon, text, t: Date.now() });
        changed();
        close(true);
        toast(`${ico} ${label} markiert`);
      });
    }
    dlgButton(box, 'Abbrechen', '', () => close(false));
  });
});

// Feld abgesucht: antippen schaltet durch
$('hf-field').addEventListener('click', () => {
  if (!allGrids(P).length) return toast('Im Auftrag ist kein Raster');
  setTool(tool === 'hffield' ? 'pan' : 'hffield');
});
function hfFieldTap(ll) {
  const h = useGridAt(ll.lat, ll.lng);
  if (!h) return toast('Außerhalb des Rasters');
  const key = `${h.c},${h.r}`;
  const order = ['abgesucht', 'teilweise abgesucht', 'nicht begehbar'].map((l) => P.marks.find((m) => m.kind === 'status' && m.label === l)).filter(Boolean);
  const cur = order.findIndex((m) => m.id === P.status[key]);
  const next = order[cur + 1];
  if (next) P.status[key] = next.id; else delete P.status[key];
  ensureHf();
  changed();
  toast(`Feld ${h.label}${cellLabel(h.c, h.r)}: ${next ? next.label : 'zurückgesetzt'}`);
}
$('hf-wind').addEventListener('click', openWindMeter);

// ---- QR-Code anzeigen / Link teilen ----
function loadScript(src) {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) return resolve();
    const el = document.createElement('script');
    el.src = src;
    el.onload = resolve;
    el.onerror = () => reject(new Error(`${src} nicht ladbar`));
    document.head.appendChild(el);
  });
}
const QR_MAX = 1800; // Zeichen, die eine Handy-Kamera vom Bildschirm noch sicher liest
async function showQr(link, title, text) {
  await loadScript('lib/qrcode.js');
  $('qr-title').textContent = title;
  $('qr-text').textContent = text;
  const box = $('qr-code');
  if (link.length > QR_MAX) {
    box.innerHTML = '<p class="small">Zu viele Daten für einen QR-Code – bitte über „Teilen“ (WhatsApp, SMS …) senden.</p>';
  } else {
    const q = window.qrcode(0, link.length < 2000 ? 'M' : 'L');
    q.addData(link, 'Byte');
    q.make();
    box.innerHTML = q.createSvgTag({ cellSize: 4, margin: 4, scalable: true });
  }
  $('qrbox').dataset.link = link;
  $('qrbox').hidden = false;
}
async function shareLinkText(link, title, text) {
  const msg = `${text}\n${link}`;
  if (bridge && bridge.shareText) return bridge.shareText(title, msg);
  if (navigator.share) {
    try { await navigator.share({ title, text: msg }); return; } catch (e) { if (e.name === 'AbortError') return; }
  }
  copyText(link);
}
async function copyText(t) {
  try { await navigator.clipboard.writeText(t); toast('Link kopiert – z. B. in WhatsApp einfügen'); } catch { prompt('Link kopieren:', t); }
}
$('qr-close').addEventListener('click', () => { $('qrbox').hidden = true; });
$('qr-copy').addEventListener('click', () => copyText($('qrbox').dataset.link));
$('qr-share').addEventListener('click', () => shareLinkText($('qrbox').dataset.link, $('qr-title').textContent, $('qr-text').textContent));

// ---- Hundeführer: Rückmeldung zurückgeben ----
async function resultLink() {
  ensureHf();
  let link = '';
  for (const tol of [4, 8, 15, 30, 60]) {
    link = shareLink('r', await pack(buildResult(P, tol)), PUBLIC_URL);
    if (link.length <= QR_MAX) break;
  }
  return link;
}
$('hf-back').addEventListener('click', async () => {
  const link = await resultLink();
  const n = P.hf.track.reduce((a, sg) => a + pathLen(sg.pts), 0);
  showQr(link, `📤 Rückmeldung ${P.hf.team}`, `Die Einsatzleitung scannt diesen Code (Teams → „Rückmeldung scannen“). Gelaufen: ${fmtKm(n)}. Mehrfach zurückgeben schadet nicht – es kommt nichts doppelt an.`);
});

// ---- Einsatzleitung: Auftrag zusammenstellen ----
let sendPicked = {}; // gridId -> Set("c,r")
let sendCache = null;
function renderSend() {
  const teams = P.marks.filter((m) => m.kind === 'team');
  const sel = $('send-team');
  const prev = sel.value;
  sel.innerHTML = '';
  for (const t of teams) sel.add(new Option(`${t.label}${t.dog ? ` – ${t.dog}` : ''}`, t.id));
  sel.add(new Option('ohne Team (nur Gebiet)', ''));
  if (teams.some((t) => t.id === prev) || prev === '') sel.value = prev;
  const box = $('send-grids');
  const checked = new Set([...box.querySelectorAll('input:checked')].map((i) => i.value));
  box.innerHTML = '';
  for (const g of allGrids(P)) {
    const n = sel.value ? Object.values(g.fills).filter((id) => id === sel.value).length : 0;
    const l = document.createElement('label');
    l.className = 'check';
    l.innerHTML = '<input type="checkbox"><span></span>';
    l.firstChild.value = g.id;
    l.firstChild.checked = checked.size ? checked.has(g.id) : (!sel.value || n > 0 || allGrids(P).length === 1);
    l.lastChild.textContent = `${gridLabel(P, g)}${sel.value ? ` (${n} Felder des Teams)` : ''}`;
    box.appendChild(l);
  }
  if (!allGrids(P).length) box.textContent = 'Kein Raster – es werden nur Umrisse und Zeichnungen verschickt.';
  const ib = $('send-items');
  const ichecked = new Set([...ib.querySelectorAll('input:checked')].map((i) => i.value));
  ib.innerHTML = '';
  const seen = new Set();
  P.items.forEach((it, i) => {
    if (it.resultKey) return; // Rückmeldungen der Hundeführer nicht zurückschicken
    const label = it.kind === 'text' ? `Text: ${it.text}` : it.name || (it.kind === 'track' ? 'Umriss' : 'Zeichnung');
    if (it.group && seen.has(it.group)) return;
    if (it.group) seen.add(it.group);
    const l = document.createElement('label');
    l.className = 'check';
    l.innerHTML = '<input type="checkbox"><span></span>';
    l.firstChild.value = String(i);
    l.firstChild.checked = ichecked.has(String(i)) || (it.kind === 'track' && !it.open);
    l.lastChild.textContent = label;
    ib.appendChild(l);
  });
  if (!ib.children.length) ib.textContent = 'Keine.';
  $('send-meet').parentElement.hidden = !P.meet;
  $('send-person').parentElement.hidden = !P.mission.person.trim();
  const picked = Object.values(sendPicked).reduce((a, x) => a + x.size, 0);
  $('send-pickinfo').textContent = sendFields() === 'pick' ? `${picked} Felder angetippt.` : '';
  sendCache = null;
  updateSendSize();
}
const sendFields = () => (document.querySelector('input[name=send-fields]:checked') || {}).value || 'team';
function sendSelection() {
  const gridIds = [...$('send-grids').querySelectorAll('input:checked')].map((i) => i.value);
  const idx = [];
  for (const inp of $('send-items').querySelectorAll('input:checked')) {
    const it = P.items[Number(inp.value)];
    if (!it) continue;
    // ganze Zeichnung (alle Striche einer Gruppe)
    if (it.group) P.items.forEach((x, j) => { if (x.group === it.group) idx.push(j); }); else idx.push(Number(inp.value));
  }
  // Rettungspunkte: im Rastergebiet/Umriss und im Umkreis von 2 km um dessen Mitte
  let rescue = [];
  if ($('send-rescue').checked && rescuePts.length) {
    const shapes = allGrids(P).filter((g) => gridIds.includes(g.id)).map((g) => ({ rect: g.area }));
    for (const j of idx) {
      const it = P.items[j];
      if (it.pts && it.pts.length) shapes.push({ pts: it.pts });
    }
    rescue = rescueNear(rescuePts, shapes, 2, 80);
  }
  return {
    teamId: $('send-team').value, gridIds, fields: sendFields(),
    picked: Object.fromEntries(Object.entries(sendPicked).map(([k, v]) => [k, [...v]])),
    itemIdx: idx, meet: $('send-meet').checked && !!P.meet, rescue, hint: $('send-hint').value.trim(), person: $('send-person').checked,
  };
}
async function currentAssignment() {
  if (sendCache) return sendCache;
  const sel = sendSelection();
  const a = buildAssignment(P, sel);
  const link = shareLink('a', await pack(a), PUBLIC_URL);
  sendCache = { a, link, sel };
  return sendCache;
}
async function updateSendSize() {
  const { a, link } = await currentAssignment();
  const nf = a.g.reduce((x, g) => x + g.f.length, 0);
  $('send-size').textContent = `${a.g.length ? `${a.g.length} Rastergebiet${a.g.length === 1 ? '' : 'e'} · ${nf} hervorgehobene Felder · ` : ''}Umrisse/Zeichnungen: ${a.i.length} · ${a.rp ? `Rettungspunkte: ${a.rp.length} · ` : ''}`
    + (link.length <= QR_MAX ? `passt in einen QR-Code (${link.length} Zeichen)` : `zu groß für einen QR-Code (${link.length} Zeichen) – per WhatsApp senden oder weniger auswählen`);
}
['send-team', 'send-meet', 'send-rescue', 'send-person', 'send-hint'].forEach((id) => $(id).addEventListener(id === 'send-hint' ? 'input' : 'change', () => {
  if (id === 'send-team') { $('send-grids').innerHTML = ''; return renderSend(); }
  sendCache = null; updateSendSize();
}));
$('send-grids').addEventListener('change', () => { sendCache = null; updateSendSize(); });
$('send-items').addEventListener('change', () => { sendCache = null; updateSendSize(); });
document.querySelectorAll('input[name=send-fields]').forEach((r) => r.addEventListener('change', () => {
  sendCache = null;
  if (sendFields() === 'pick') { closePanels(); setTool('sendpick'); updatePickBar(); redraw(); } else renderSend();
}));
$('send-open').addEventListener('click', () => {
  if (!allGrids(P).length && !P.items.some((it) => !it.resultKey)) return toast('Nichts zu verschicken – zuerst ein Raster oder einen Umriss anlegen');
  $('send-grids').innerHTML = '';
  renderSend();
  openPanel('panel-send');
});
function sendPickTap(ll) {
  const h = hitGrid(ll.lat, ll.lng);
  if (!h) return toast('Außerhalb des Rasters');
  const set = sendPicked[h.g.id] || (sendPicked[h.g.id] = new Set());
  const key = `${h.c},${h.r}`;
  if (set.has(key)) set.delete(key); else set.add(key);
  updatePickBar();
  redraw();
}
function updatePickBar() {
  const n = Object.values(sendPicked).reduce((a, x) => a + x.size, 0);
  $('pick-info').textContent = `${n} Feld${n === 1 ? '' : 'er'} für den Auftrag gewählt`;
}
$('pick-done').addEventListener('click', () => {
  // Gebiete mit angetippten Feldern automatisch ankreuzen
  setTool('pan');
  redraw();
  renderSend();
  for (const inp of $('send-grids').querySelectorAll('input')) if (sendPicked[inp.value] && sendPicked[inp.value].size) inp.checked = true;
  sendCache = null;
  updateSendSize();
  openPanel('panel-send');
});
$('pick-clear').addEventListener('click', () => { sendPicked = {}; updatePickBar(); redraw(); });
function drawPicked(c) {
  if (tool !== 'sendpick') return;
  c.lineWidth = 3;
  c.strokeStyle = '#1565c0';
  c.fillStyle = 'rgba(21,101,192,0.25)';
  for (const g of allGrids(P)) {
    const set = sendPicked[g.id];
    if (!set || !set.size) continue;
    const gg = makeGrid(g.area, g.cellM);
    for (const k of set) {
      const [cc, rr] = k.split(',').map(Number);
      const b = cellBounds(gg, cc, rr);
      const [x0, y0] = toPx(b.north, b.west);
      const [x1, y1] = toPx(b.south, b.east);
      c.fillRect(x0, y0, x1 - x0, y1 - y0);
      c.strokeRect(x0, y0, x1 - x0, y1 - y0);
    }
  }
}
async function prepareSend() {
  const c = await currentAssignment();
  if (!c.a.g.length && !c.a.i.length) { toast('Bitte ein Rastergebiet oder einen Umriss ankreuzen'); return null; }
  P.sent = P.sent || [];
  if (!P.sent.some((x) => x.id === c.a.id)) {
    const team = P.marks.find((m) => m.id === c.sel.teamId);
    P.sent.push({ id: c.a.id, teamId: c.sel.teamId, team: team ? team.label : 'ohne Team', grids: c.a.g.map((g) => g.i), at: Date.now() });
    touch();
    renderSentList();
  }
  return c;
}
$('send-qr').addEventListener('click', async () => {
  const c = await prepareSend();
  if (!c) return;
  showQr(c.link, `📲 Auftrag ${c.a.tm ? c.a.tm.l : ''}`.trim(), 'Mit der Kamera des Hundeführer-Handys scannen und den Link öffnen – es braucht keine App. Beim ersten Öffnen ist Internet nötig.');
});
$('send-share').addEventListener('click', async () => {
  const c = await prepareSend();
  if (!c) return;
  shareLinkText(c.link, 'Suchauftrag', `Suchauftrag ${c.a.tm ? `für ${c.a.tm.l} ` : ''}(${P.title || 'Einsatz'}) – Link öffnen:`);
});
$('send-copy').addEventListener('click', async () => {
  const c = await prepareSend();
  if (c) copyText(c.link);
});
function renderSentList() {
  const box = $('sent-list');
  box.innerHTML = '';
  for (const x of [...(P.sent || [])].reverse()) {
    const d = document.createElement('div');
    d.textContent = `📲 ${hhmm(x.at)} Auftrag an ${x.team}${x.last ? ` · Rückmeldung ${hhmm(x.last)}` : ' · noch keine Rückmeldung'}`;
    box.appendChild(d);
  }
}
$('btn-teams').addEventListener('click', renderSentList);

// ---- Einsatzleitung: Rückmeldung übernehmen (Kamera oder eingefügter Link) ----
async function handleShared(text) {
  const sh = parseShared(text);
  if (!sh) return toast('Kein Auftrag und keine Rückmeldung erkannt');
  let data;
  try { data = await unpack(sh.data); } catch { return toast('Code beschädigt oder unvollständig'); }
  if (data.k === 'a') return takeAssignment(data);
  if (data.k !== 'r') return toast('Unbekannter Inhalt');
  // Suchgebiet finden, an das der Auftrag ging
  const target = Object.values(db.projects).find((p) => (p.sent || []).some((x) => x.id === data.a));
  if (target && target !== P) switchProject(target.id);
  const res = applyResult(P, data);
  const sent = (P.sent || []).find((x) => x.id === data.a);
  if (sent) sent.last = Date.now();
  changed();
  renderSentList();
  toast(`📥 Rückmeldung ${res.who}: ${res.ways} Weg${res.ways === 1 ? '' : 'e'}, ${res.marks} Markierung${res.marks === 1 ? '' : 'en'}, ${res.fields} Feld${res.fields === 1 ? '' : 'er'}${res.winds ? `, ${res.winds} Wind-Messung${res.winds === 1 ? '' : 'en'}` : ''}${res.known ? '' : ' (Auftrag hier unbekannt – ins aktuelle Suchgebiet übernommen)'}${res.ways + res.marks + res.fields + res.winds ? '' : ' – nichts Neues'}`, 9000);
}
async function takeAssignment(a) {
  const known = Object.values(db.projects).find((p) => p.hf && p.hf.id === a.id);
  if (db.mode === 'el' && !known) {
    const ok = await openDlg((box, close) => {
      dlgHead(box, '📲 Suchauftrag', `Auftrag „${a.t}${a.tm ? ` – ${a.tm.l}` : ''}“ auf diesem Gerät als Hundeführer übernehmen? Die App wechselt in den Hundeführer-Modus.`);
      dlgButton(box, 'Übernehmen', 'primary', () => close(true));
      dlgButton(box, 'Abbrechen', '', () => close(false));
    });
    if (!ok) return;
  }
  let p = known;
  if (!p) {
    p = projectFromAssignment(a);
    db.projects[p.id] = p;
    if (p.hfRescue.length) {
      rescuePts = mergeRescue(rescuePts, p.hfRescue);
      storeRescue(rescuePts).catch(() => {});
      renderRescueInfo();
    }
  }
  db.mode = 'hf';
  switchProject(p.id);
  // auf Raster und Umrisse/Zeichnungen des Auftrags zoomen
  const lats = [];
  const lons = [];
  for (const g of allGrids(P)) { lats.push(g.area.north, g.area.south); lons.push(g.area.west, g.area.east); }
  for (const it of P.items) {
    for (const [la, lo] of it.pts || (it.lat != null ? [[it.lat, it.lon]] : [])) { lats.push(la); lons.push(lo); }
  }
  if (lats.length && !known) {
    map.fitBounds([[Math.min(...lats), Math.min(...lons)], [Math.max(...lats), Math.max(...lons)]], { padding: [30, 30], maxZoom: 17 });
  }
  saveNow();
  applyMode();
  toast(known ? 'Auftrag ist schon da' : `📲 Auftrag übernommen: ${p.hf.team}`, 5000);
}
$('recv-paste').addEventListener('click', () => openDlg((box, close) => {
  dlgHead(box, '📋 Rückmeldung einfügen', 'Den Link aus WhatsApp/SMS hier einfügen.');
  const ta = document.createElement('textarea');
  ta.rows = 4;
  box.appendChild(ta);
  dlgButton(box, 'Übernehmen', 'primary', () => { close(true); handleShared(ta.value); });
  dlgButton(box, 'Abbrechen', '', () => close(false));
  setTimeout(() => ta.focus(), 50);
}));
// Kamera-Scanner: BarcodeDetector (falls vorhanden), sonst jsQR
let scanStream = null;
let scanRun = false;
async function startScan() {
  $('scanbox').hidden = false;
  $('scan-text').textContent = 'Kamera wird gestartet …';
  try {
    scanStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' }, audio: false });
  } catch (e) {
    $('scan-text').textContent = 'Keine Kamera verfügbar oder nicht erlaubt. Alternativ: Link per WhatsApp schicken lassen und „Rückmeldung einfügen“.';
    return;
  }
  const v = $('scan-video');
  v.srcObject = scanStream;
  await v.play().catch(() => {});
  $('scan-text').textContent = 'Kamera auf den QR-Code richten …';
  let detector = null;
  if ('BarcodeDetector' in window) { try { detector = new BarcodeDetector({ formats: ['qr_code'] }); } catch { detector = null; } }
  if (!detector) await loadScript('lib/jsQR.js');
  const cv = document.createElement('canvas');
  const cx = cv.getContext('2d', { willReadFrequently: true });
  scanRun = true;
  const tick = async () => {
    if (!scanRun) return;
    if (v.readyState >= 2) {
      let text = null;
      if (detector) {
        try { const r = await detector.detect(v); if (r.length) text = r[0].rawValue; } catch { /* nächster Versuch */ }
      } else {
        const w = Math.min(800, v.videoWidth);
        const h = Math.round((v.videoHeight / v.videoWidth) * w);
        cv.width = w; cv.height = h;
        cx.drawImage(v, 0, 0, w, h);
        const r = window.jsQR(cx.getImageData(0, 0, w, h).data, w, h, { inversionAttempts: 'dontInvert' });
        if (r) text = r.data;
      }
      if (text) { stopScan(); handleShared(text); return; }
    }
    setTimeout(tick, 200);
  };
  tick();
}
function stopScan() {
  scanRun = false;
  if (scanStream) scanStream.getTracks().forEach((t) => t.stop());
  scanStream = null;
  $('scanbox').hidden = true;
}
$('recv-scan').addEventListener('click', startScan);
$('scan-close').addEventListener('click', stopScan);

// Link mit Auftrag/Rückmeldung (Kamera-App, WhatsApp …) – beim Start und wenn er sich ändert
async function handleHash() {
  if (!parseShared(location.hash)) return;
  const h = location.hash;
  history.replaceState(null, '', location.pathname + location.search);
  await handleShared(h);
}
window.addEventListener('hashchange', handleHash);

// Erster Start: Modus wählen (vorhandene Daten -> Einsatzleitung)
async function chooseModeIfNeeded() {
  if (db.mode) return;
  if (parseShared(location.hash)) return; // Auftrag-Link legt den Modus fest
  if (Object.values(db.projects).some((p) => p.area || p.items.length)) { db.mode = 'el'; saveNow(); return; }
  const m = await openDlg((box, close) => {
    dlgHead(box, 'Wie nutzt du die App?', 'Lässt sich später unter „Gebiete“ ändern.');
    const list = document.createElement('div');
    list.className = 'dlg-btns';
    box.appendChild(list);
    dlgButton(list, '🧭 Einsatzleitung<small>Alles: Raster, Teams, Aufträge, Berichte</small>', 'primary', () => close('el'));
    dlgButton(list, '🐕 Hundeführer<small>Vereinfacht: Auftrag, Weg, Markieren, Zurückgeben</small>', '', () => close('hf'));
  });
  if (m === 'hf') await toHfMode(); else { db.mode = 'el'; saveNow(); }
}

// ---------- Nachtmodus ----------
// aus → dunkel → rot (schont die Nachtsicht) → aus; gilt fürs Gerät (db.night)
function applyNight() {
  const n = db.night || '';
  document.documentElement.classList.toggle('night', !!n);
  document.documentElement.classList.toggle('red', n === 'red');
  $('quick-night').classList.toggle('on', !!n);
  $('quick-night').lastChild.textContent = n === 'red' ? 'Rot' : n ? 'Dunkel' : 'Nacht';
}
$('quick-night').addEventListener('click', () => {
  db.night = !db.night ? 'dark' : db.night === 'dark' ? 'red' : '';
  applyNight();
  saveNow();
  toast(db.night === 'red' ? 'Nachtmodus rot – schont die Nachtsicht' : db.night ? 'Nachtmodus dunkel' : 'Tagmodus');
});
applyNight();

// ---------- Adressbuch ----------
// Kontakte für alle Suchgebiete gemeinsam in db.contacts
if (!Array.isArray(db.contacts)) db.contacts = [];
db.contacts = db.contacts.map(normalizeContact);
let ctEditing = null; // id oder 'new'

function renderContacts() {
  const box = $('ct-list');
  box.innerHTML = '';
  const q = $('ct-search').value;
  const list = sortContacts(db.contacts).filter((c) => ctMatches(c, q));
  if (!db.contacts.length) box.innerHTML = '<p class="small">Noch keine Kontakte. „+ Neuer Kontakt“ oder Handy-Kontakte als vCard importieren.</p>';
  else if (!list.length) box.innerHTML = '<p class="small">Kein Treffer.</p>';
  for (const c of list) {
    const row = document.createElement('div');
    row.className = 'ctrow';
    const info = document.createElement('div');
    info.className = 'ctinfo';
    const b = document.createElement('b');
    b.textContent = c.name;
    info.appendChild(b);
    const sub = [c.role, c.org, c.call && `📻 ${c.call}`].filter(Boolean).join(' · ');
    if (sub) { const sm = document.createElement('small'); sm.textContent = sub; info.appendChild(sm); }
    const link = (href, text) => { const a = document.createElement('a'); a.href = href; a.textContent = text; info.appendChild(a); };
    if (c.phone) link(telHref(c.phone), `📞 ${c.phone}`);
    if (c.phone2) link(telHref(c.phone2), `📞 ${c.phone2}`);
    if (c.email) link(`mailto:${c.email}`, `✉️ ${c.email}`);
    if (c.note) { const sm = document.createElement('small'); sm.textContent = c.note; info.appendChild(sm); }
    const edit = document.createElement('button');
    edit.textContent = '✏️';
    edit.title = 'Bearbeiten';
    edit.addEventListener('click', () => openContactForm(c.id));
    row.append(info, edit);
    box.appendChild(row);
  }
}

function openContactForm(id) {
  ctEditing = id;
  const c = id === 'new' ? normalizeContact({}) : db.contacts.find((x) => x.id === id);
  const f = $('ct-form');
  f.innerHTML = '';
  for (const [k, label] of CT_FIELDS) {
    const l = document.createElement('label');
    l.textContent = label;
    const inp = document.createElement(k === 'note' ? 'textarea' : 'input');
    inp.id = `ct-f-${k}`;
    if (k === 'phone' || k === 'phone2') { inp.type = 'tel'; inp.inputMode = 'tel'; }
    if (k === 'email') { inp.type = 'email'; inp.inputMode = 'email'; }
    if (k === 'note') inp.rows = 2;
    inp.value = c[k];
    l.appendChild(inp);
    f.appendChild(l);
  }
  const btns = document.createElement('div');
  btns.className = 'row';
  btns.innerHTML = '<button class="primary">Speichern</button><button>Abbrechen</button>' + (id === 'new' ? '' : '<button class="danger">🗑️ Löschen</button>');
  const [ok, cancel, del] = btns.querySelectorAll('button');
  ok.addEventListener('click', () => {
    const data = { id: c.id };
    for (const [k] of CT_FIELDS) data[k] = $(`ct-f-${k}`).value;
    const n = normalizeContact(data);
    if (!n.name) return toast('Bitte einen Namen eingeben');
    const i = db.contacts.findIndex((x) => x.id === n.id);
    if (i >= 0) db.contacts[i] = n; else db.contacts.push(n);
    saveNow();
    closeContactForm();
    toast(`Kontakt „${n.name}“ gespeichert`);
  });
  cancel.addEventListener('click', closeContactForm);
  if (del) {
    del.addEventListener('click', () => {
      if (!confirm(`Kontakt „${c.name}“ löschen?`)) return;
      db.contacts = db.contacts.filter((x) => x.id !== c.id);
      saveNow();
      closeContactForm();
    });
  }
  f.appendChild(btns);
  f.hidden = false;
  $('ct-list').hidden = true;
  $('ct-search').hidden = true;
  $(`ct-f-name`).focus();
}
function closeContactForm() {
  ctEditing = null;
  $('ct-form').hidden = true;
  $('ct-list').hidden = false;
  $('ct-search').hidden = false;
  renderContacts();
}

$('btn-contacts').addEventListener('click', () => {
  if (ctEditing) closeContactForm(); else renderContacts();
  openPanel('panel-contacts');
});
$('ct-search').addEventListener('input', renderContacts);
$('ct-add').addEventListener('click', () => openContactForm('new'));
$('ct-import').addEventListener('click', () => $('ct-file').click());
$('ct-file').addEventListener('change', async (e) => {
  const file = e.target.files[0];
  e.target.value = '';
  if (!file) return;
  try {
    const incoming = parseContacts(await file.text());
    if (!incoming.length) return toast('Keine Kontakte in der Datei gefunden');
    const m = mergeContacts(db.contacts, incoming);
    db.contacts = m.list;
    saveNow();
    renderContacts();
    toast(m.added ? `${m.added} Kontakt${m.added === 1 ? '' : 'e'} übernommen${incoming.length > m.added ? ` (${incoming.length - m.added} schon vorhanden)` : ''}` : 'Alle Kontakte waren schon vorhanden');
  } catch {
    toast('Datei konnte nicht gelesen werden (vCard .vcf oder .json)');
  }
});
const contactsFile = () => new Blob([toVcf(sortContacts(db.contacts))], { type: 'text/vcard' });
$('ct-share').addEventListener('click', () => {
  if (!db.contacts.length) return toast('Noch keine Kontakte');
  shareFile(contactsFile(), 'Kontakte-Suchgebiet.vcf', 'Kontakte', 'Adressbuch (vCard) – in Suchgebiet-Karten unter Kontakte → Importieren öffnen.');
});
$('ct-save').addEventListener('click', () => {
  if (!db.contacts.length) return toast('Noch keine Kontakte');
  saveFile(contactsFile(), 'Kontakte-Suchgebiet.vcf');
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
  if (allGrids(P).length) {
    const c = hitGrid(lat, lon);
    parts.push(c ? `📍 ${c.label}${cellLabel(c.c, c.r)}` : '📍 außerhalb');
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
  syncGrid();
  restoreDrafts();
  setTool('pan');
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
    ? `${m.text || 'B-Ort'}: ${m.lat.toFixed(5)}, ${m.lon.toFixed(5)}${P.showUtm ? ` · ${formatMgrs(m.lat, m.lon)}` : ''}`
    : 'Kein B-Ort gesetzt.';
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
$('notes').addEventListener('input', () => { P.notes = $('notes').value; $('nt-text').value = P.notes; P.updated = Date.now(); save(); });
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
    if (/\.gpx$/i.test(f.name) || /^\s*(<\?xml[^>]*>\s*)?<gpx\b/i.test(text)) {
      importGpx(new TextDecoder().decode(buf), f.name);
      return;
    }
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

// GPX (z. B. aus BaseCamp) ins aktuelle Suchgebiet: Tracks/Routen als Umrisse, Wegpunkte als Text
function importGpx(xml, fileName) {
  const g = parseGpx(xml);
  const base = fileName.replace(/\.gpx$/i, '');
  const added = [];
  for (const t of g.tracks) {
    const [a, z] = [t.pts[0], t.pts[t.pts.length - 1]];
    // geschlossen (Ende am Anfang, < 30 m): Fläche anzeigen, sonst offener Weg
    const open = trackLength([a, z]) > 30;
    added.push({ kind: 'track', name: t.name || base, color: t.color || db.color, w: 4, pts: t.pts, ...(open ? { open: true } : {}) });
  }
  for (const w of g.waypoints) added.push({ kind: 'text', color: db.color, lat: w.lat, lon: w.lon, text: w.name });
  if (!added.length) {
    toast(g.skipped ? 'Nur Raster/Feldnamen in der Datei – nichts übernommen' : 'Keine Tracks oder Wegpunkte in der Datei');
    return;
  }
  P.items.push(...added);
  save();
  redraw();
  closePanels();
  const pts = added.flatMap((it) => (it.pts ? it.pts : [[it.lat, it.lon]]));
  map.fitBounds(pts, { padding: [40, 40], maxZoom: 17 });
  const parts = [];
  if (g.tracks.length) parts.push(`${g.tracks.length} Track${g.tracks.length > 1 ? 's' : ''}`);
  if (g.waypoints.length) parts.push(`${g.waypoints.length} Wegpunkt${g.waypoints.length > 1 ? 'e' : ''}`);
  toast(`${parts.join(' und ')} übernommen${g.skipped ? ` (${g.skipped} Raster-Einträge übersprungen)` : ''}`);
}

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
// Seitenknopf nochmal antippen, während sein Fenster offen ist: Fenster schließen
const SIDE_PANELS = {
  'btn-projects': 'panel-projects', 'btn-grid': 'panel-grid', 'btn-teams': 'panel-teams',
  'btn-layers': 'panel-layers', 'btn-contacts': 'panel-contacts', 'btn-offline': 'panel-offline', 'btn-pdf': 'panel-pdf', 'btn-mission': 'panel-mission', 'btn-notes': 'panel-notes',
};
for (const [btn, panel] of Object.entries(SIDE_PANELS)) {
  $(btn).addEventListener('click', (e) => {
    if ($(panel).hidden) return;
    e.stopImmediatePropagation();
    closePanels();
  }, { capture: true });
}
$('btn-projects').addEventListener('click', () => { fillProjectForm(); renderProjects(); openPanel('panel-projects'); });
$('btn-grid').addEventListener('click', () => { updateGridInfo(); openPanel('panel-grid'); });
$('btn-teams').addEventListener('click', () => { renderMarks(); renderAlpha(); openPanel('panel-teams'); });
$('btn-layers').addEventListener('click', () => openPanel('panel-layers'));
$('btn-offline').addEventListener('click', () => { renderOfflineForm(); openPanel('panel-offline'); });
$('app-version').textContent = `Version ${APP_VERSION}`;
$('btn-pdf').addEventListener('click', () => {
  $('pdf-caption').value = P.caption || '';
  renderExportGrids();
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

// ---------- Rastergebiete im Export ----------
// Abgewählte Gebiete (Export-Fenster); alle anderen gehen mit
const exportSkip = new Set();
function exportGrids() {
  return allGrids(P).filter((g) => !exportSkip.has(g.id));
}
function renderExportGrids() {
  const list = allGrids(P);
  $('export-grids-box').hidden = list.length < 2;
  const box = $('export-grids');
  box.innerHTML = '';
  for (const g of list) {
    const l = document.createElement('label');
    l.className = 'check';
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = !exportSkip.has(g.id);
    cb.addEventListener('change', () => {
      if (cb.checked) exportSkip.delete(g.id); else exportSkip.add(g.id);
      updatePdfPlan();
      updateKmzPlan();
    });
    l.append(cb, ` ${gridLabel(P, g)} (${formatMeters(g.cellM)})`);
    box.appendChild(l);
  }
}
// Mehrere Gebiete: je Gebiet eine Projekt-Ansicht; die übrigen gewählten werden mitgezeichnet
function exportViews() {
  if (allGrids(P).length < 2) return null;
  const sel = exportGrids();
  return sel.map((g) => ({
    project: { ...gridView(P, g), otherGrids: sel.filter((o) => o.id !== g.id) },
    grid: makeGrid(g.area, g.cellM),
    label: gridLabel(P, g),
  }));
}
// Projekt + Raster für Ausgaben mit einem Bild (Garmin-Karte): erstes gewähltes Gebiet, Rest dazu
function exportBase() {
  const v = exportViews();
  if (!v) return { project: P, grid };
  if (!v.length) return { project: { ...P, area: null, fills: {}, status: {}, otherGrids: [] }, grid: null };
  return v[0];
}

// ---------- PDF ----------
function pdfOpts() {
  const views = exportViews();
  const hasGrid = views ? views.length > 0 : !!grid;
  return {
    format: $('pdf-format').value,
    orient: $('pdf-orient').value,
    overview: $('pdf-overview').checked && hasGrid,
    details: $('pdf-details').checked && hasGrid,
    gridIds: views ? views.map((v) => v.project.gridId) : null,
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
  const views = exportViews();
  const noGrid = views ? !views.length : !grid;
  $('pdf-overview').disabled = noGrid;
  $('pdf-details').disabled = noGrid;
  if (noGrid) $('pdf-view').checked = true;
  const sheets = views ? planMultiSheets(views, pdfOpts(), viewBounds()) : planSheets(grid, pdfOpts(), viewBounds());
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
  const opts = { ...pdfOpts(), views: exportViews() };
  const res = await buildPdf(P, grid, { ...opts, rescue: rescueForExport() }, layerStack(P.layerId, activeOverlays()), viewBounds(), (i, n) => progress(`Seite ${i} von ${n} …`));
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
  return { grid: $('gpx-grid').value, cells: $('gpx-cells').value, gridIds: exportGrids().map((g) => g.id) };
}

function gpxMarkOpts() {
  return {
    tracks: $('gpx-tracks').checked,
    drawings: $('gpx-drawings').checked,
    teams: $('gpx-teams').checked,
    points: $('gpx-points').checked,
    gridIds: exportGrids().map((g) => g.id),
  };
}

// Mehrere Rastergebiete: je Gebiet ein Teil (Raster „Raster Titel Nord“, Team-Tracks mit Gebiet),
// Zeichnungen und Punkte nur einmal
function gpxMulti(opts, part) {
  const views = exportViews();
  if (!views) return buildGpx(P, grid, opts, part);
  if (!views.length) return buildGpx({ ...P, otherGrids: [] }, null, opts, part);
  const title = P.title || 'Suchgebiet';
  return mergeGpx(views.map((v, i) => buildGpx(
    { ...v.project, title: `${title} ${v.label}` },
    v.grid,
    { ...opts, prefix: `${v.label} `, ...(i ? { tracks: false, drawings: false, points: false } : {}) },
    part,
  )), `${title} – ${part}`);
}

function gpxBuilder(opts, part, empty) {
  return async () => {
    const gpx = gpxMulti(opts, part);
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
  const sel = allGrids(P).length > 1 ? exportGrids() : (grid ? [{ area: P.area, cellM: P.cellM }] : []);
  if ($('kmz-area').value === 'grid' && sel.length) {
    // alle gewählten Rastergebiete, mit einem halben Feld Rand
    const pad = 0.5;
    const b = { north: -90, south: 90, west: 180, east: -180 };
    for (const g of sel) {
      const gg = makeGrid(g.area, g.cellM);
      b.north = Math.max(b.north, gg.originLat + gg.dLat * pad);
      b.south = Math.min(b.south, gg.originLat - gg.rows * gg.dLat - gg.dLat * pad);
      b.west = Math.min(b.west, gg.originLon - gg.dLon * pad);
      b.east = Math.max(b.east, gg.originLon + gg.cols * gg.dLon + gg.dLon * pad);
    }
    return b;
  }
  return viewBounds();
}

function updateKmzPlan() {
  const any = allGrids(P).length > 1 ? exportGrids().length > 0 : !!grid;
  if (!any) $('kmz-area').value = 'view';
  $('kmz-area').querySelector('[value=grid]').disabled = !any;
  const plan = planCustomMap(kmzBounds(), Number($('kmz-res').value));
  $('kmz-plan').textContent = `${plan.tiles} Kachel${plan.tiles > 1 ? 'n' : ''} · ${plan.W} × ${plan.H} Bildpunkte · `
    + `${plan.mPerPx.toLocaleString('de-DE', { maximumFractionDigits: 1 })} m pro Bildpunkt`
    + (plan.mPerPx > Number($('kmz-res').value) + 0.01 ? ' (für Garmin-Grenze vergröbert)' : '');
}
['kmz-area', 'kmz-res'].forEach((id) => $(id).addEventListener('change', updateKmzPlan));

async function buildKmzFile(progress) {
  const base = exportBase();
  const res = await buildCustomMap(base.project, base.grid, layerStack(P.layerId, activeOverlays()), kmzBounds(), Number($('kmz-res').value),
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
const kmzKey = () => exportKey([$('kmz-area').value, $('kmz-res').value, exportGrids().map((g) => g.id)]);
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
// Eckzeiten: „Jetzt“ trägt die aktuelle Uhrzeit ein, sonst von Hand
function renderTimes() {
  const box = $('ms-times');
  box.innerHTML = '';
  const t = M().times;
  const pad = (v) => String(v).padStart(2, '0');
  for (const [k, label] of TIME_KEYS) {
    const row = document.createElement('div');
    row.className = 'trow';
    row.innerHTML = '<span></span><input type="time"><button class="now">Jetzt</button><button class="clr" title="Löschen">✕</button>';
    row.querySelector('span').textContent = label;
    const inp = row.querySelector('input');
    inp.value = t[k] || '';
    inp.addEventListener('input', () => { t[k] = inp.value; touch(); });
    row.querySelector('.now').addEventListener('click', () => {
      const d = new Date();
      t[k] = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
      if (k === 'alarm') t.alarmDate = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
      touch();
      renderTimes();
    });
    row.querySelector('.clr').addEventListener('click', () => {
      delete t[k];
      if (k === 'alarm') delete t.alarmDate;
      touch();
      renderTimes();
    });
    box.appendChild(row);
    if (k === 'alarm') {
      // Datum der Alarmierung (für das JUH-Formular)
      const dr = document.createElement('div');
      dr.className = 'trow';
      dr.innerHTML = '<span>Datum der Alarmierung</span><input type="date">';
      const di = dr.querySelector('input');
      di.value = t.alarmDate || '';
      di.addEventListener('input', () => { t.alarmDate = di.value; touch(); });
      box.appendChild(dr);
    }
  }
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

// Vorschaubilder im Einsatz-Fenster und im Notizen-Fenster
function renderThumbs() {
  const boxes = [$('ms-thumbs'), $('nt-thumbs')];
  for (const b of boxes) b.innerHTML = '';
  const add = (src, label, open, remove) => {
    for (const box of boxes) {
      const d = document.createElement('div');
      d.className = 'thumb';
      d.innerHTML = '<img alt=""><small></small><button title="Löschen">✕</button>';
      d.querySelector('img').src = src;
      d.querySelector('small').textContent = label;
      d.querySelector('img').addEventListener('click', open);
      d.querySelector('button').addEventListener('click', remove);
      box.appendChild(d);
    }
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
  M().photos.forEach((p, i) => add(p.src, `Foto ${i + 1}`, () => {
    // Foto groß ansehen: im Einsatz-Fenster (Einsatzende) mit Zoom
    if ($('panel-mission').hidden) { renderMission(); openPanel('panel-mission'); }
    showTab('ende'); viewIdx = sources().findIndex((s) => s.photo === i); renderViewer(); }, () => {
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

// Zoomen: Knöpfe, Zwei-Finger-Geste, Doppeltippen/-klick, Strg+Mausrad.
// Verschieben: Finger oder mit der Maus ziehen.
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
  box.classList.toggle('zoomed', zoom > 1);
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
  // Maus: gezoomtes Bild mit gedrückter Taste frei in alle Richtungen ziehen
  let drag = null;
  let mouse = false;
  box.addEventListener('pointerdown', (e) => {
    mouse = e.pointerType === 'mouse';
    if (e.pointerType === 'mouse') {
      if (e.button !== 0 || zoom <= 1 || !box.querySelector('img')) return;
      e.preventDefault();
      drag = { id: e.pointerId, x: e.clientX, y: e.clientY, sl: box.scrollLeft, st: box.scrollTop };
      box.setPointerCapture(e.pointerId);
      box.classList.add('dragging');
      return;
    }
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
    if (drag && e.pointerId === drag.id) {
      box.scrollLeft = drag.sl - (e.clientX - drag.x);
      box.scrollTop = drag.st - (e.clientY - drag.y);
      return;
    }
    if (!pts.has(e.pointerId)) return;
    pts.set(e.pointerId, local(e));
    if (pinch && pts.size === 2) {
      e.preventDefault();
      const [a, b] = [...pts.values()];
      const d = Math.hypot(a[0] - b[0], a[1] - b[1]);
      setZoom(pinch.z * (d / pinch.d), (a[0] + b[0]) / 2, (a[1] + b[1]) / 2);
    }
  });
  const up = (e) => {
    if (drag && e.pointerId === drag.id) { drag = null; box.classList.remove('dragging'); }
    pts.delete(e.pointerId);
    if (pts.size < 2) pinch = null;
  };
  box.addEventListener('dblclick', (e) => { if (!mouse) return; const [x, y] = local(e); setZoom(zoom > 1.2 ? 1 : 2.5, x, y); });
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
    box.innerHTML = '<p class="small">Noch keine Stift-Zeichnungen oder Umrisse auf der Karte. Teams und Status stehen ohnehin in der Legende.</p>';
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
  renderTimes();
  renderForces();
  renderThumbs();
  showTab(db.missionTab || 'lage');
}
$('btn-mission').addEventListener('click', () => { renderMission(); openPanel('panel-mission'); });
// Notizen-Fenster: getippte Notizen (P.notes, wie im Einsatz-Fenster), Notizblock, Fotos
$('btn-notes').addEventListener('click', () => {
  $('nt-text').value = P.notes || '';
  renderThumbs();
  openPanel('panel-notes');
});
$('nt-text').addEventListener('input', () => {
  P.notes = $('nt-text').value;
  $('notes').value = P.notes;
  P.updated = Date.now();
  save();
});
$('nt-pad').addEventListener('click', () => openPad());
$('nt-photo').addEventListener('click', () => $('ms-photo-file').click());
[['ms-person', 'person'], ['ms-summary', 'summary'], ['ms-author', 'author']].forEach(([id, key]) => {
  $(id).addEventListener('input', () => { M()[key] = $(id).value; touch(); });
});

// Notizblock: Seiten mit Stift/Finger beschreiben, Punkte in Seitenbreiten gespeichert
let padIdx = 0;
let padColor = '#000000';
let padStroke = null;
const padCanvas = $('pad-canvas');

// Bild-in-Bild nur, wenn neben dem kleinen Notizblock noch genug Karte bleibt
const pipPossible = () => window.innerWidth >= 700 && window.innerHeight >= 480;
function applyPip() {
  const on = !!db.padPip && pipPossible();
  $('notepad').classList.toggle('pip', on);
  if (!on) Object.assign($('notepad').style, { left: '', top: '', right: '', width: '', height: '' });
  $('pad-pip').hidden = !pipPossible();
  $('pad-pip').textContent = on ? '⛶ Groß' : '🗗 Klein';
  // klein: Fenster dahinter schließen, damit die Karte frei ist
  if (on && !$('notepad').hidden) closePanels();
}
$('pad-pip').addEventListener('click', () => {
  db.padPip = !db.padPip;
  save();
  applyPip();
  padSize();
  padDraw();
});
// kleines Fenster an der Leiste verschieben (nicht an den Knöpfen)
{
  const bar = document.querySelector('#notepad .padbar');
  let mv = null;
  bar.addEventListener('pointerdown', (e) => {
    if (!$('notepad').classList.contains('pip') || e.target.closest('button')) return;
    const r = $('notepad').getBoundingClientRect();
    mv = { id: e.pointerId, dx: e.clientX - r.left, dy: e.clientY - r.top };
    bar.setPointerCapture(e.pointerId);
  });
  bar.addEventListener('pointermove', (e) => {
    if (!mv || e.pointerId !== mv.id) return;
    const n = $('notepad');
    const x = Math.max(0, Math.min(window.innerWidth - 120, e.clientX - mv.dx));
    const y = Math.max(0, Math.min(window.innerHeight - 60, e.clientY - mv.dy));
    Object.assign(n.style, { left: `${x}px`, top: `${y}px`, right: 'auto' });
  });
  const stop = () => { mv = null; };
  bar.addEventListener('pointerup', stop);
  bar.addEventListener('pointercancel', stop);
  // Größe ändern (Ecke unten rechts am PC): Seite neu einpassen
  if (window.ResizeObserver) {
    new ResizeObserver(() => { if (!$('notepad').hidden) { padSize(); padDraw(); } }).observe($('notepad'));
  }
}
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
  applyPip();
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
window.addEventListener('resize', () => { if (!$('notepad').hidden) { applyPip(); padSize(); padDraw(); } });

// Abschlussbericht der App (ohne Karte) mit den angekreuzten Inhalten
// Karte nur, wenn angekreuzt: ohne Raster, Flächen beschriftet, Liste am Rand
async function reportPdf(sec, progress) {
  const withMap = !!sec.map;
  const parts = { ...sec, legend: withMap };
  const hasPad = parts.pad !== false && M().pages.some((pg) => pg.strokes.length);
  const hasPhotos = parts.photos !== false && M().photos.length;
  if (!hasReportText(parts) && !hasPad && !hasPhotos && !withMap) return null;
  progress('Bericht wird erstellt …');
  const opts = {
    ...pdfOpts(),
    orient: withMap ? pdfOpts().orient : 'portrait',
    overview: !!grid,
    details: false,
    info: false,
    view: !grid,
    noMap: !withMap,
    mapTeams: sec.mapTeams !== false,
    mapStatus: sec.mapStatus !== false,
    noGrid: true,
    fitContent: true,
    areaLabels: 'edge',
    report: parts,
    title: `Einsatzbericht ${P.title.trim() || 'Suchgebiet'}`,
  };
  const res = await buildPdf(P, grid, { ...opts, rescue: rescueForExport() }, layerStack(P.layerId, activeOverlays()), viewBounds(), (i, n) => progress(`Karte ${i} von ${n} …`));
  return { blob: res.blob, name: safeName(hasReportText(parts) ? '_Abschlussbericht.pdf' : hasPad || hasPhotos ? '_Notizen.pdf' : '_Karte.pdf'), title: opts.title, pages: res.pages };
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
    el.innerHTML = '<div class="top"><input type="text" inputmode="email"><select title="Empfänger aus den Kontakten"></select><button class="del" title="Zeile löschen">✕</button></div><div class="groups"></div><button class="send primary"></button>';
    const inp = el.querySelector('input');
    inp.value = row.to;
    // Empfänger aus dem Adressbuch anhängen
    const pick = el.querySelector('select');
    pick.add(new Option('📇', ''));
    for (const c of sortContacts(db.contacts).filter((x) => x.email)) pick.add(new Option(`${c.name}${c.role ? ` (${c.role})` : ''} – ${c.email}`, c.email));
    pick.hidden = pick.options.length < 2;
    pick.addEventListener('change', () => {
      if (!pick.value) return;
      const have = inp.value.split(',').map((x) => x.trim()).filter(Boolean);
      if (!have.includes(pick.value)) have.push(pick.value);
      inp.value = row.to = have.join(', ');
      pick.value = '';
      touch();
    });
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
    group('Karte zeigt:', MAP_PARTS);
    group('Zusätzlich:', EXTRA_PARTS);
    // „Karte zeigt“ nur, wenn die Karte angekreuzt ist
    const mapGroup = el.querySelectorAll('.groups .parts')[1];
    const syncMap = () => { mapGroup.hidden = !row.map; };
    syncMap();
    el.querySelectorAll('.groups .parts')[0].querySelectorAll('input').forEach((inp, idx) => {
      if (REPORT_SECTIONS[idx][0] === 'map') inp.addEventListener('change', syncMap);
    });
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
function toast(msg, ms = 3500) {
  const t = $('toast');
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { t.hidden = true; }, ms);
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

// Modus anwenden, beim ersten Start fragen, Auftrag/Rückmeldung aus dem Link übernehmen
applyMode();
chooseModeIfNeeded().then(handleHash);
