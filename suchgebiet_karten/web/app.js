import {
  makeGrid, cellCount, cellAt, cellBounds, cellLabel, parseCell, formatMeters, MAX_CELLS, remapCells, gridBounds, fitGridArea,
} from './grid.js';
import { cellEditable, cellLayers, canPaint } from './celledit.js';
import { removeVertex, insertVertex, moveVertex, edgeMids, vertexCount, minPoints } from './vertex.js';
import { drawOverlay, hitItem as hitItemAll, labelDetail, trackLabel, markHidden, outlineColor } from './render.js';
import {
  LAYERS, OVERLAYS, DEFAULT_OVERLAYS, layerById, layerStack, tileUrl, FALLBACK, isBkg,
} from './layers.js';
import { buildPdf, planMultiSheets, planSheets, renderState } from './pdf.js';
import { formatMgrs } from './utm.js';
import { areaBounds, navTargets, navTargetsAll, navUrl, boxCenter, cellCenter as navCellCenter, navNeedleDeg, fmtDist } from './hfnav.js';
import { buildGpx, mergeGpx, parseGpx, dedupeImport, parseKml, pointInPolygon, selectionGpx, gridWithLabels, gridPath, labelTracks, cellComponents, cellOutlines, hasArea, polygonArea, formatArea, trackDesc, trackLength, outlineName, msgWaypoints, msgRows } from './gpx.js';
import { JUH_TEMPLATE, fillJuh } from './juh.js';
import { buildReport, describeTarget, makeDedup, makeLog, validReportUrl } from './report.js';
import { POI_CATS, newPoi, poiCat, poiLabel, poiName, sortPois } from './pois.js';
import { fileName } from './files.js';
import { buildInfos, deletePoi, infoSummary, infoTarget, mergeInfos } from './infos.js';
import { emptySel, selectAll, selSummary, selCount, subsetProject, itemsWithin, itemsInGrids, unionSel } from './scope.js';
import { MSG_VIEW, MSG_DELETE, ownTeamMsgs, isUA, lockOf, canEdit, canDelete, canEditCell, canEditGrid, denied, deniedGrid, gridLock, assignedOf, assignedCell, assignedGrid, markAccepted, isAccepted, unlockUntil } from './locks.js';
import { isDone, openPoints, guardApplies, msgPct, closeMsg, sentPct, closeAsk, autoCloseDue, declineClose, closeSent, reopenSent, predecessorGroups, predecessorText } from './closeout.js';
import { ELW_KINDS, elwTemplates, buildElwOrder, splitElwOrder, joinElwParts, elwInbox, addElwIn, mergeElwItems, elwPoints, elwCounts } from './elw.js'; // v124
import { nextTeamLabel, uaPrefix, sameTeamName, uaName, uaTitle, joinUaNames, renameUa } from './uateam.js';
import { typeIcon, typeText, unitType, isDog, unitLine, cleanUnit, nextFunkrufname, UNIT_TYPES, ORGS, forcesFromTeams, forcesText, whoText } from './units.js'; // v128
import { FUNK_KINDS, funkKind, funkLabel, timeOfDay, funkTargets, buildFunkMsg, addFunkMsg, buildFindMsg, msgSource } from './funk.js'; // v128
import { FIND_KINDS, findKind, findLabel, FIND_A, forAllUa, checkText, isFind, findStatusText } from './finds.js'; // v128
import { buildZusatz, applyZusatz, isZusatz, ZUSATZ_MAX } from './zusatz.js'; // v130
import { listTracks, trackInfo, importItems, noteImport, importTag, TRACK_KINDS, guessKind, durText } from './tracks.js'; // v128
import { teamTimes, timeRows, outsideTeams, stateText, totalPersonHours, timeLine } from './times.js'; // v128
import { uaOverview, levelIcon, agoText, hasUas, BASE_UA } from './uaover.js'; // v128
import { CAM_KEY, backCameras, pickCamera, nextCamera, cameraConstraints, wantsContinuousFocus } from './camera.js';
import { rebuildAssignment, teamsWithoutOrder, planAssign, applyAssign, planCount, assignText, teamClock } from './sentops.js';
import { buildProgress, mergeProgress, progressSummary, progressPreview, progressTarget, snapshotBase, stampChanges, setPeer, setPeerId, peerOf } from './progress.js';
import {
  FORCE_KEYS, TIME_KEYS, totalLine, usedColors, colorName, notePageImage, drawNotePage, PAGE_RATIO, shrinkPhoto, missionText,
  MAIL_PARTS, REPORT_SECTIONS, MAP_PARTS, EXTRA_PARTS, hasReportText, newMailTo, mailAddresses,
  normTime,
} from './mission.js';
import { buildCustomMap, planCustomMap } from './kmz.js';
import {
  STATES, estimate, downloadRegion, deleteRegion, storageInfo, persistStorage, setHasOffline, cachedTileUrl, maxZoom, nativeJob,
  SQ_LAT, SQ_LON, squareKey, squareBounds, unionBounds, missionBounds, packageZooms,
} from './offline.js';
import {
  FIELDS as CT_FIELDS, normalizeContact, sortContacts, matches as ctMatches, telHref, toVcf, parseContacts, mergeContacts,
} from './contacts.js';
import {
  parseRescue, mergeRescue, nearest as nearestRescue, compass, inBounds, loadRescue, storeRescue, rescueNear,
  distance, bearing as bearingDeg,
} from './rescue.js';
import {
  fetchWeather, fetchStations, dirName, beaufort, approach, circularMean, nextLightEvents, windChanged, STRENGTHS, ICONS as WX_ICONS, CONDITIONS,
} from './weather.js';
import {
  PUBLIC_URL, pack, unpack, parseShared, shareLink, appIntentUrl, assignmentSummary, sinceText, buildAssignment, projectFromAssignment, buildResult, applyResult,
  assignmentCenter, ensureLive,
} from './share.js';
import {
  STATUS_LIST, CLOSE_STATUS, RELIEF_STATUS, SPOT_LIST, SPOT_HINTS, NO_POS, URGENT, spotLabel, msgLabel, msgIcon, isUrgent, buildMsg, buildKor, applyKor, mergeStatus, withoutDeleted, latestFor, headMsg, flushOutbox, pollMessages, coverageGaps, areaShapes,
  EL_ALL, EL_KINDS, buildAck, buildElMsg, buildReadAck, buildReply, replyContext, QUICK_REPLIES, needsAck, forHf, ackedIds, mergeReads, splitIncoming, elTargets, readSummary,
} from './status.js';
import {
  teamChips, teamOrder, todoFirst, chipText, teamAssignments, unreadMsgs, noteReceived, markSeen, prune, unreadAlert, unreadAge, bannerText, parseSnooze,
  snoozeUntilFrom, snoozeText, historyFilter, historyTeams, SNOOZE_PICKS,
} from './statusbar.js';
import { einsatzOffen, shouldOfferUpdate, updateText, PERMISSION_HINT } from './update.js';
import { tapVerdict, backdropAction } from './tapclose.js';
import {
  LIC_KEY, LIC_CHECK_MS, LIC_TIMEOUT, LIC_CONTACT, DEFERRED_TEXT, licenceState, applyLicenceReply, applyEmergencyCode, newLicence, normalizeLicence, checkUrl, lockTitle, lockText, mailtoHref,
} from './licence.js';
import { WIZ_STEPS, wizTitle, lastLead, hhmmOf, isoDate } from './wizard.js';
import { buildHandover, projectFromHandover, replaceWithHandover, splitParts, addPart } from './handover.js';
import { placeBadges, boxOf } from './badgeplace.js';
import { parseQuery, searchAddress, suggestPlaces, cornerBox, searchCorner, overpass } from './search.js';
import { OSM_NOTE, MAX_PARTS, MAX_AREA_M2, MIN_OUTLINE_M, forestQuery, parseForest, originOf, toXY, toLL, forestInLasso, lassoPolygon, shares as forestShares, splitArea, toTracks, mpArea } from './forest.js';
import {
  newProject, normalizeProject, isBlankProject, migrateV1, assignments, markLabel, cellOwner, cellStatus, mapFor, cellsText,
  exportProject, importProject, uid, reorderMarks, MARK_COLORS, NO_TEAM, NO_TEAM_COLOR, assignTargets, assigneeName,
  allGrids, activateGrid, startNewGrid, removeActiveGrid, gridView, gridLabel, gridTeams, loadProjects, mergeTrackBackup,
} from './store.js';

// Bei jeder Änderung erhöhen (gleich wie VERSION in sw.js) – steht im Export-Fenster
const APP_VERSION = 'v130.13';
// Status-Server (Google-Tabelle von Klaas); pro Gerät unter „⚙️ Mehr → Dieses Gerät“ überschreibbar
const STATUS_URL = 'https://script.google.com/macros/s/AKfycbzDnsK7N-7uJigNMewDMQx8o2U7FhlOIHpPnzgXb3HKqjahrnQJXwgPKUf8U8G604CRxg/exec';
const STORE_KEY = 'suchgebiet-karten-v2';
let userMovedAt = 0; // zuletzt von Hand verschoben (GPS-Mitführen pausiert kurz)
let recWatch = null; // Weg-Aufzeichnung (HF): watchPosition-ID, siehe startRec
let locked = false; // v118: ein anderes Fenster arbeitet (siehe „Nur ein Fenster“): dieses speichert und sendet nichts
let handedOff = false; // dieser Tab hat eine Rückmeldung an einen offenen Tab abgegeben und speichert nichts mehr
const OLD_KEY = 'suchgebiet-karten-v1';
const COLORS = ['#d50000', '#1565c0', '#2e7d32', '#ef6c00', '#6a1b9a', '#f06292', '#000000', '#fdd835'];
const COLOR_NAMES = {
  '#d50000': 'Rot', '#1565c0': 'Blau', '#ef6c00': 'Orange', '#6a1b9a': 'Lila', '#00838f': 'Türkis', '#ad1457': 'Pink', '#f06292': 'Rosa',
  '#4e342e': 'Braun', '#558b2f': 'Olivgrün', '#2e7d32': 'Dunkelgrün', '#00c853': 'Hellgrün', '#fdd835': 'Gelb', '#616161': 'Grau', '#000000': 'Schwarz',
};

const $ = (id) => document.getElementById(id);
const bridge = window.AndroidBridge || null; // gesetzt in der Android-App
// Fehlerberichte nur in der Android-App; sie gehen über den Status-Server an Notion (der Token liegt im Apps Script)
const canReport = !!(bridge && bridge.reportError);
const repLog = makeLog();
const repDedup = makeDedup();

// ---------- Zustand ----------
// db: alle Suchgebiete; P: das aktuelle; grid wird aus P.area + P.cellM berechnet
let db = { projects: {}, currentId: null, color: COLORS[0], w: 5, activeMark: null, teamsOpen: false };
let P = null;
let grid = null;
let tool = 'pan';
let draftTrack = null; // Umriss, der gerade Punkt für Punkt gesetzt wird
let draftPen = null; // Stift-Zeichnung in Arbeit: { strokes: [...] } – bis „Fertig“ oder „Abbrechen“
let undoStack = [];
let vtx = null; // v108 Punkte-Modus: { it, id, hs: [Marker Eckpunkte], ms: [Marker Kantenmitten] }
let searchPin = null; // Nadel des letzten Suchergebnisses (gehört zu keinem Einsatz)
let gpxSel = null; // Auswahl auf der Karte (Werkzeug „gpxsel“), siehe unten
let selMode = null; // 'export' (GPX direkt), 'share' (für „Weitergeben“), 'area' (Gebiet antippen)
let gapView = null; // „Lücken zeigen“ (Einsatzleitung): { a, step, pts }
let moveTapAt = 0; // Zeit des letzten „Verlegen“-Tipps (der Klick danach öffnet nichts)
let pendingMove = null; // „📍 Verlegen“ mit Tippen auf die Karte: { msg: Meldung } (Hundeführer) bzw. { item: Textpunkt }
const NO_RP_HF = 'Die Einsatzleitung hat keine Rettungspunkte mitgeschickt.';
let pendingSpot = null; // „Standort melden“ mit Tippen auf die Karte (Hundeführer): { cat, txt }
let elwPollBusy = false; // v124: Abholen der Aufträge an den ELW läuft
let elwLayer = null; // v124: Vorschau eines Auftrags auf der Karte
let elwShown = ''; // v124: ID des Auftrags, dessen Vorschau steht
let liveBusy = false; // Abholen der Status-Meldungen läuft
let urgentOpen = false; // Dringend-Dialog steht
let flushBusy = false; // Warteschlange wird gesendet
let flushAgain = false;
let gpxSelGrid = null;
let areaPicks = []; // v128: gewählte Gebiete beim UA aus mehreren Gebieten: [{ key, name, sel }] // zuletzt angetipptes Rastergebiet (für „Ganzes Raster“)

// v118: defekte Einsätze beiseitelegen (höchstens 3, die ältesten fliegen), defekten Gesamtspeicher einmal sichern
const QUARANTINE = 'sgk-quarantaene-';
const CORRUPT_KEY = 'sgk-defekt-';
const TRACK_KEY = 'sgk-track-';
let startNotice = ''; // Hinweis nach dem Start (toast gibt es erst später)
let trackKeysDone = []; // Weg-Sicherungen, die eingearbeitet sind und nach dem nächsten Speichern gelöscht werden
function quarantine(id, raw) {
  try {
    localStorage.setItem(`${QUARANTINE}${id}`, JSON.stringify({ t: Date.now(), id, raw }));
    const all = Object.keys(localStorage).filter((k) => k.startsWith(QUARANTINE)).map((k) => {
      let t = 0;
      try { t = JSON.parse(localStorage.getItem(k)).t || 0; } catch { /* defekt -> älteste */ }
      return { k, t };
    }).sort((a, b) => b.t - a.t);
    for (const x of all.slice(3)) localStorage.removeItem(x.k);
  } catch { /* Speicher voll: egal */ }
}
function saveCorrupt(raw) {
  try {
    for (const k of Object.keys(localStorage)) if (k.startsWith(CORRUPT_KEY)) localStorage.removeItem(k);
    localStorage.setItem(`${CORRUPT_KEY}${Date.now()}`, raw);
  } catch { /* egal */ }
}
// Weg-Sicherungen (sgk-track-<Einsatz>) in die Wege der Einsätze einarbeiten
function mergeTrackBackups(projects) {
  for (const p of Object.values(projects)) {
    if (!p.hf) continue;
    let raw = null;
    try { raw = localStorage.getItem(`${TRACK_KEY}${p.id}`); } catch { /* egal */ }
    if (raw === null) continue;
    try {
      const r = mergeTrackBackup(p.hf.track, JSON.parse(raw));
      if (r.merged) p.hf.track = r.track;
    } catch { /* defekte Sicherung */ }
    trackKeysDone.push(`${TRACK_KEY}${p.id}`);
  }
}
function load() {
  let raw = null;
  try { raw = localStorage.getItem(STORE_KEY); } catch { /* privater Modus */ }
  try {
    const s = JSON.parse(raw || 'null');
    if (s && s.projects) db = { ...db, ...s };
    if (!['ua', 'el', 'other'].includes(db.shareTo)) db.shareTo = null; // v99: zuletzt gewählter Empfänger beim Teilen (pro Gerät)
    db.teamsOpen = !!db.teamsOpen; // v98: Team-Liste auf dem Handy offen (pro Gerät)
  } catch { if (raw) { saveCorrupt(raw); startNotice = '⚠️ Der Speicher war beschädigt und wurde gesichert (Mehr → Fehlerbericht senden)'; } } // defekter Speicher -> Neustart, Rohdaten bleiben erhalten
  const ld = loadProjects(db.projects);
  db.projects = ld.projects;
  for (const b of ld.broken) quarantine(b.id, b.raw);
  if (ld.broken.length) startNotice = '⚠️ Ein Einsatz war beschädigt und wurde beiseitegelegt (Mehr → Fehlerbericht senden)';
  if (!Object.keys(db.projects).length) {
    let p = null;
    try {
      const old = JSON.parse(localStorage.getItem(OLD_KEY) || 'null');
      if (old) p = migrateV1(old);
    } catch { /* ignorieren */ }
    p = normalizeProject(p || newProject(''));
    db.projects[p.id] = p;
    db.currentId = p.id;
  }
  if (!db.projects[db.currentId]) db.currentId = Object.keys(db.projects)[0];
  mergeTrackBackups(db.projects);
  P = db.projects[db.currentId];
  ensureLiveOpen();
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
// true = gespeichert, false = Speicher voll (rote Leiste); wer „gespeichert“ meldet, prüft das
function saveNow() {
  clearTimeout(saveTimer);
  if (handedOff || locked) return true;
  if (map) {
    const c = map.getCenter();
    P.view = { lat: c.lat, lon: c.lng, z: map.getZoom() };
  }
  // offene Zeichnung/Umriss überstehen Neustart und Projektwechsel
  P.drafts = { track: draftTrack, pen: draftPen };
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(db));
    $('save-warn').hidden = true;
    return true;
  } catch {
    $('save-warn').hidden = false; // dauerhaft, bis ein Speichern wieder klappt
    return false;
  }
}
window.addEventListener('pagehide', saveNow);
document.addEventListener('visibilitychange', () => { if (document.hidden) saveNow(); });

// v90: Änderungen erkennen (feste IDs, Änderungszeit, Löschvermerke) – Grundlage für „Fortschritt senden“
const progBase = new WeakMap();
const devBy = () => db.deviceName || (P.parentEid ? 'UA' : 'EL');
// v125: eindeutige Geräte-ID (aus der Freigabe, licence.js) – Herkunft von Änderungen; der Name ist nur Anzeige
const devId = () => { try { return (lic && lic.id) || ''; } catch { return ''; } };
function stamp() { progBase.set(P, stampChanges(P, progBase.get(P), devBy(), Date.now(), devId())); }
function snapshot() {
  if (!progBase.has(P)) progBase.set(P, snapshotBase(P));
  undoStack.push(JSON.stringify({
    area: P.area, cellM: P.cellM, fills: P.fills, status: P.status, items: P.items, marks: P.marks, meet: P.meet, pois: P.pois, poiDel: P.poiDel,
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
  syncVertex();
}

function changed() {
  P.updated = Date.now();
  stamp();
  renderHanded();
  applyClosed();
  renderStatusBtn();
  renderTeamBar();
  updateGridInfo();
  renderPalette();
  if (!$('panel-teams').hidden) renderMarks();
  redraw();
  save();
}

// ---------- Karte ----------
load();
const map = L.map('map', { zoomControl: false, maxZoom: 20, zoomSnap: 0, zoomDelta: 1, wheelPxPerZoomLevel: 300 });
L.control.zoom({ position: 'bottomright' }).addTo(map);
map.on('dragstart', () => { userMovedAt = Date.now(); });
// Quellenangabe: kurz ausgeklappt, dann nur „ⓘ“ (verdeckt sonst Bedienelemente); antippen klappt sie auf
const attrBox = map.attributionControl.getContainer();
setTimeout(() => attrBox.classList.add('folded'), 6000);
attrBox.addEventListener('click', (e) => {
  if (e.target.closest('a') && !attrBox.classList.contains('folded')) return;
  e.preventDefault();
  attrBox.classList.toggle('folded');
});

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
let layerByUser = false; // Karte aktiv gewählt (nicht beim Start): nur dann der PDF-Hinweis
let fallbackFor = null; // v122: Karte, für die gerade die Ersatzkarte läuft
let probeTimer = null;
function setLayer(id, byUser = false) {
  layerByUser = byUser;
  const l = layerById(id);
  P.layerId = l.id;
  stopFallback();
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
        if (layerByUser && db.mode === 'el') toast('Diese Karte lässt sich nur anzeigen, aber nicht ins PDF übernehmen.'); // HF hat kein PDF
      }
    });
  } else if (isBkg(l) && zIndex === 1) {
    // v122: kommt die BKG-Karte auch ohne CORS nicht, Ersatzkarte zeigen
    let ok = 0;
    let bad = 0;
    layer.on('tileload', () => { ok++; });
    layer.on('tileerror', () => {
      bad++;
      if (bad === 6 && ok === 0 && navigator.onLine && baseLayer === layer) startFallback(l);
    });
  }
  return layer;
}

// v122: Ersatzkarte (OpenStreetMap), solange der BKG-Server keine Kacheln liefert; alle 2 min nachsehen
function startFallback(l) {
  if (baseLayer) map.removeLayer(baseLayer);
  fallbackFor = l;
  baseLayer = makeTiles(FALLBACK, false).addTo(map);
  toast('⚠️ Karte vom Bundesamt (BKG) lädt gerade nicht – Ersatzkarte OpenStreetMap wird gezeigt. Die App schaltet von selbst zurück.', 9000);
  clearInterval(probeTimer);
  probeTimer = setInterval(probeBkg, 120e3);
}
function stopFallback() {
  clearInterval(probeTimer);
  probeTimer = null;
  fallbackFor = null;
}
function probeBkg() {
  const l = fallbackFor;
  if (!l || !navigator.onLine) return;
  const z = Math.min(Math.max(Math.round(map.getZoom()), 5), 15);
  const c = map.project(map.getCenter(), z).divideBy(256).floor();
  const img = new Image();
  img.onload = () => {
    if (fallbackFor !== l) return;
    stopFallback();
    map.removeLayer(baseLayer);
    baseLayer = makeTiles(l, true).addTo(map);
    toast('✅ BKG-Karte ist wieder da.', 5000);
  };
  img.src = `${tileUrl(l, z, c.x, c.y)}?probe=${Date.now()}`;
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
  // weit herausgezoomt: nur Umrandungen – Texte und Zeichnungen weg (außer dem, was gerade gezeichnet wird)
  const dz = labelDetail(map.getZoom());
  if (dz === 0) st.items = st.items.filter((it) => !markHidden(it, 0) || it === current || drafts.includes(it));
  // v101: Spuren des vorherigen Teams (beim neuen Hundeführer): gedämpft, nur zum Ansehen
  if (st.items.some((it) => it.prev)) st.items = st.items.map((it) => (it.prev ? { ...it, color: '#9e9e9e', name: it.name ? `${it.name} 🔒` : '🔒' } : it));
  if (isUA(P)) {
    // Unterabschnitt: Elemente des Grund-Einsatzes ausgegraut
    const GREY = '#9e9e9e';
    const grey = (o) => Object.fromEntries(Object.keys(o || {}).map((k) => [k, GREY]));
    st.items = st.items.map((it) => (lockOf(P, it) === 'base' ? { ...it, color: GREY } : it));
    if (gridLock(P, P.gridId) === 'base') { st.fills = grey(st.fills); st.status = grey(st.status); }
    st.others = (st.others || []).map((o, i) => (gridLock(P, P.otherGrids[i].id) === 'base' ? { ...o, fills: grey(o.fills), status: grey(o.status) } : o));
  }
  st.noTeamGrey = db.mode !== 'hf'; // Umrisse ohne Team grau (Hundeführer-Gerät: wie bisher)
  if (hide.meet) st.meet = null;
  if (hide.pois) st.pois = [];
  st.rescue = rescueInView();
  st.detail = labelDetail(map.getZoom()); // je weiter weg, desto weniger Beschriftung
  // Raster aus: Markierungen als Flächen mit Namen darauf
  drawOverlay(ctx, toPx, st, {
    s: 1, width: W, height: H, view, utm: P.showUtm, noGrid: !!hide.grid, noEdge: !!hide.edge, areaLabels: 'on',
  });
  drawGpxSel();
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
  drawGaps(ctx);
  drawSentBadges(ctx);
  drawStatusMarks(ctx);
  drawWindArrow(ctx);
}

// Windpfeile (Overlay, ein-/ausschaltbar: db.windArrows). Jeder Pfeil zeigt, wohin der Wind weht.
// Hundeführer – Blau: DWD am Windpunkt bzw. über dem Suchgebiet und an den DWD-Messstationen ringsum.
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
// Gemessener Wind (grün) an der Messstelle; Hundeführer: eigene und zurückgemeldete, Einsatzleitung: die der Teams
function measuredArrows(teamsOnly) {
  const KMH = { light: 8, medium: 20, strong: 35 };
  const out = [];
  for (const m of P.mission.wind || []) {
    if (m.src !== 'gemessen' || m.lat == null || (teamsOnly && !m.by)) continue;
    const t = new Date(m.t).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
    out.push({ lat: m.lat, lon: m.lon, from: m.from, kmh: KMH[m.strength] || 15, color: '#2e7d32', old: Date.now() - m.t > 2 * 3600e3,
      text: `${t}${m.by ? ` ${m.by}` : ''}: aus ${dirName(m.from)}, ${STRENGTHS[m.strength] ? STRENGTHS[m.strength].label : ''}` });
  }
  return out;
}
// Einsatzleitung: DWD-Wind (blau) in der Mitte jedes Rasters und jedes Umrisses, dazu die Messpunkte der Teams
function areaWindArrows(w) {
  const out = [];
  const dwd = `aus ${dirName(w.from)} ${Math.round(w.kmh)} km/h${w.gust ? `, Böen ${Math.round(w.gust)}` : ''} (DWD)`;
  const add = (name, ns, ws) => out.push({ lat: (Math.max(...ns) + Math.min(...ns)) / 2, lon: (Math.max(...ws) + Math.min(...ws)) / 2,
    from: w.from, kmh: w.kmh, color: '#1565c0', big: true, text: `${name}: ${dwd}` });
  for (const g of allGrids(P)) add(gridLabel(P, g), [g.area.north, g.area.south], [g.area.west, g.area.east]);
  for (const it of P.items) {
    if (it.kind !== 'track' || it.open || it.resultKey || !it.pts || it.pts.length < 3) continue;
    add(it.name || 'Umriss', it.pts.map((q) => q[0]), it.pts.map((q) => q[1]));
  }
  if (!out.length) out.push({ ...wxPoint(), from: w.from, kmh: w.kmh, color: '#1565c0', big: true, text: `Wind ${dwd}` });
  return out;
}
function windArrows() {
  const w = db.wxLast && db.wxLast.current;
  const dwdOk = w && w.from != null && w.kmh != null;
  if (db.mode !== 'hf') return [...(dwdOk ? areaWindArrows(w) : []), ...measuredArrows(true)];
  const out = [];
  if (dwdOk) {
    const pt = windArrowPoint();
    out.push({ ...pt, from: w.from, kmh: w.kmh, color: '#1565c0', big: true,
      text: `Wind aus ${dirName(w.from)} ${Math.round(w.kmh)} km/h${w.gust ? `, Böen ${Math.round(w.gust)}` : ''} (DWD)` });
  }
  for (const st of (db.wxStations && db.wxStations.list) || []) {
    if (st.from == null || st.kmh == null) continue;
    out.push({ lat: st.lat, lon: st.lon, from: st.from, kmh: st.kmh, color: '#1565c0', station: true,
      text: `DWD ${st.name}: ${dirName(st.from)} ${Math.round(st.kmh)} km/h` });
  }
  return [...out, ...measuredArrows(false)];
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
// v118: während der Weg-Aufzeichnung verschiebt das Mitführen die Karte bei jedem Punkt – die Ansicht steht dann im 30-s-Speichern (recPersist)
const saveView = () => { if (recWatch === null) save(); };
map.on('zoomend', () => { canvas.style.visibility = 'visible'; redraw(); saveView(); });
map.on('moveend', saveView);
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
  hfmarkpt: 'Tippe auf die Karte, wo der Punkt hin soll.',
  hfspotpt: 'Tippe auf die Karte, wo der Standort gemeldet werden soll.',
  ptpick: 'Tippe auf die Karte, wo der Ort sein soll.',
  hfmovept: 'Tippe auf die Karte, wo die Meldung hin soll.',
  textmove: 'Tippe auf die Karte, wo der Punkt hin soll.',
  hfdraw: 'Mit dem Finger einmal um den Bereich herum malen.',
  forestdraw: 'Mit dem Finger einmal um den Wald herum malen. Die Karte bewegt sich dabei nicht.',
  hffield: 'Feld antippen: abgesucht → teilweise → nicht begehbar → zurück. „Feld“ nochmal tippen = fertig.',
  sendpick: 'Felder für den Auftrag antippen (blau umrandet). Dann „Weiter“.',
  gpxsel: 'Antippen, was als GPX mit soll. Ein Umriss nimmt alles mit, was darin liegt.',
  offsquares: 'Quadrate antippen (blau = gewählt, grün = schon gespeichert). Ziehen verschiebt die Karte.',
  meet: 'Auf die Karte tippen, um den B-Ort zu setzen.',
  poi: 'Auf die Karte tippen, um den Lage-Ort zu setzen.',
  track: 'Umriss: Punkte antippen. Karte mit dem Finger verschieben, Zoom mit +/−.',
};

let hintTimer = null;
// v110: wer eine Markierung zum Malen auswählt, will sie sehen – ausgeblendete Markierung (bzw. Raster) wieder einblenden
function showForPaint(m) {
  const back = [];
  if (m && m.hidden) { delete m.hidden; back.push(`„${m.label || 'Markierung'}“`); }
  if (P.hide && P.hide.grid && tool === 'fill') { P.hide = { ...P.hide, grid: false }; back.push('Raster'); }
  if (!back.length) return;
  updateQuick();
  changed();
  toast(`${back.join(' und ')} wieder eingeblendet`);
}
function setTool(t) {
  endVertex();
  if (!$('forestbar').hidden && t !== 'pan') { const f = forestBarDone; forestClear(); if (f) f('cancel'); } // v121: Wald-Vorschau offen
  // Einzeichnen nur in einem offenen Einsatz (Offline-Bereich wählen u. Ä. geht immer)
  if (['pen', 'text', 'fill', 'track', 'forestdraw', 'erase', 'meet', 'poi', 'grid'].includes(t) && isLocked()) { lockedToast(); t = 'pan'; }
  if (t !== tool) repLog.add(`Werkzeug ${t}`);
  if (t !== 'ptpick') pendingPick = null; // v128
  // Texte/Zeichnungen sind erst ab Stufe 15 zu sehen: zum Einzeichnen dorthin zoomen
  if (['pen', 'text', 'erase', 'hfmarkpt', 'textmove'].includes(t) && labelDetail(map.getZoom()) === 0) map.setZoom(15);
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
  if (t === 'fill') showForPaint(activeMark());
  document.querySelectorAll('.toolbar [data-tool]').forEach((b) => b.classList.toggle('active', b.dataset.tool === t));
  canvas.classList.toggle('active', t !== 'pan');
  $('palette').hidden = !['pen', 'text', 'fill', 'track'].includes(t);
  $('trackbar').hidden = t !== 'track';
  $('penbar').hidden = t !== 'pen';
  $('offsqbar').hidden = t !== 'offsquares';
  $('pickbar').hidden = t !== 'sendpick';
  if (t === 'gpxsel' && !gpxSel) gpxSel = emptySel();
  if (t !== 'gpxsel') { gpxSel = null; selMode = null; }
  $('gpxselbar').hidden = t !== 'gpxsel';
  if (t === 'gpxsel') updateGpxSelBar();
  $('hf-field').classList.toggle('on', t === 'hffield');
  $('hf-draw').classList.toggle('on', t === 'hfdraw');
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

// „ohne Team“ ist keine echte Markierung (steht nicht in P.marks), malt aber in fills
const NO_TEAM_MARK = { id: NO_TEAM, kind: 'team', label: 'ohne Team', color: NO_TEAM_COLOR };
function activeMark() {
  if (db.activeMark === NO_TEAM) return NO_TEAM_MARK;
  return P.marks.find((m) => m.id === db.activeMark) || P.marks[0] || null;
}

// v108: Ausgeblendetes lässt sich nicht verändern (Raster aus, Markierung aus) – ein Tipp tut dann gar nichts
const hideGrid = () => !!(P.hide && P.hide.grid);
function cellMarks(src, key) {
  const of = (id) => (id && id !== NO_TEAM ? P.marks.find((m) => m.id === id) || null : null);
  return { fillMark: of(src.fills[key]), statusMark: of(src.status[key]) };
}

function fillAt(ll, first) {
  if (hideGrid()) return;
  const am = activeMark();
  if (am && am.hidden) return;
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
  if (!canEditCell(P, P.gridId, key)) {
    if (first) toast(MSG_VIEW, 4000);
    return;
  }
  if (!first && !fillStroke) return;
  if (!canPaint({ hideGrid: false, mark: m, ...cellMarks(P, key) })) return;
  if (guardAssigned(assignedCell(P, P.gridId, key))) return;
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
    userMovedAt = Date.now();
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
  userMovedAt = Date.now();
  gesture.mid = m;
  // v130.5: stufenlos zoomen, nicht mehr auf ganze Stufen springen
  const want = gesture.zoom + Math.log2(m.d / gesture.dist);
  if (Math.abs(want - map.getZoom()) > 0.001) map.setZoomAround(L.point(m.x, m.y), want, { animate: false });
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
  if (now - wheelAt < 16) return;
  wheelAt = now;
  const r = canvas.getBoundingClientRect();
  // v130.5: stufenlos statt fest ±1 pro Tick – Mausrad (Zeilen) und Trackpad (Pixel) unterschiedlich skaliert
  const delta = -e.deltaY * (e.deltaMode === 1 ? 0.12 : 0.0033);
  const z = Math.max(map.getMinZoom(), Math.min(map.getMaxZoom(), map.getZoom() + delta));
  map.setZoomAround(L.point(e.clientX - r.left, e.clientY - r.top), z, { animate: false });
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
  } else if (tool === 'hfdraw') {
    current = { kind: 'stroke', color: hfColor(), w: 4, pts: [[ll.lat, ll.lng]] };
    redraw();
  } else if (tool === 'forestdraw') {
    // v121: Wald umkreisen (nur Einsatzleitung)
    current = { kind: 'stroke', color: '#2e7d32', w: 4, pts: [[ll.lat, ll.lng]] };
    redraw();
  } else if (tool === 'grid' || tool === 'offrect') {
    dragRect = { a: ll, b: ll };
  } else if (tool === 'erase') {
    eraseAt(x, y);
  } else if (tool === 'fill') {
    fillAt(ll, true);
  } else if (['track', 'text', 'offsquares', 'hffield', 'sendpick', 'windpt', 'hfmarkpt', 'hfspotpt', 'ptpick', 'hfmovept', 'textmove', 'gpxsel'].includes(tool)) {
    panning = false;
  }
});

canvas.addEventListener('pointermove', (e) => {
  if (e.pointerId !== activePointer) return;
  const { x, y, ll } = eventLatLng(e);
  if ((tool === 'pen' || tool === 'hfdraw' || tool === 'forestdraw') && current) {
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
  } else if (['track', 'text', 'offsquares', 'hffield', 'sendpick', 'windpt', 'hfmarkpt', 'hfspotpt', 'ptpick', 'hfmovept', 'textmove', 'gpxsel'].includes(tool)) {
    // Im Track-Modus verschiebt Ziehen die Karte, Tippen setzt Punkte
    if (!panning && Math.hypot(x - lastPt.x, y - lastPt.y) < 8) return;
    panning = true;
    map.panBy([lastPt.x - x, lastPt.y - y], { animate: false });
    userMovedAt = Date.now();
    lastPt = { x, y };
  }
});

function finishPointer(e, cancelled) {
  if (e.pointerId !== activePointer) return;
  activePointer = null;
  const { x, y, ll } = eventLatLng(e);
  if (tool === 'hfdraw' && current) {
    const pts = current.pts;
    current = null;
    setTool('pan');
    redraw();
    if (!cancelled) hfAreaDone(pts);
  } else if (tool === 'forestdraw' && current) {
    const pts = current.pts;
    current = null;
    setTool('pan');
    redraw();
    if (!cancelled) forestLassoDone(pts);
  } else if (tool === 'pen' && current) {
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
    if (!cancelled && setArea({ north: a.lat, south: ll.lat, west: a.lng, east: ll.lng })) startGridFit();
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
  } else if (tool === 'hfmarkpt') {
    if (!cancelled && !panning) {
      setTool('pan');
      hfMarkDialog({ lat: ll.lat, lon: ll.lng }, 'Position: auf der Karte angetippt.');
    }
  } else if (tool === 'ptpick') {
    if (!cancelled && !panning) {
      const pp = pendingPick;
      pendingPick = null;
      setTool('pan');
      if (pp) pp({ lat: ll.lat, lon: ll.lng });
    }
    panning = false;
  } else if (tool === 'hfspotpt') {
    if (!cancelled && !panning) {
      setTool('pan');
      const sp = pendingSpot;
      pendingSpot = null;
      if (sp) sendStatus({ s: sp.s || 'ort', cat: sp.cat, txt: sp.txt, pos: { lat: ll.lat, lon: ll.lng } });
    }
  } else if (tool === 'hfmovept' || tool === 'textmove') {
    if (!cancelled && !panning) {
      const mv = pendingMove;
      pendingMove = null;
      moveTapAt = Date.now();
      setTool('pan');
      if (mv && mv.msg) sendKor(mv.msg, { pos: { lat: ll.lat, lon: ll.lng } });
      else if (mv && mv.item && P.items.includes(mv.item)) {
        snapshot();
        mv.item.lat = ll.lat;
        mv.item.lon = ll.lng;
        changed();
        toast('Punkt verlegt (↶ macht es rückgängig)', 4000);
      }
    }
    panning = false;
  } else if (tool === 'windpt') {
    if (!cancelled && !panning) {
      P.windPt = { lat: Math.round(ll.lat * 1e5) / 1e5, lon: Math.round(ll.lng * 1e5) / 1e5 };
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
    const ti = hitItem(P.items, toPx, downPt.x, downPt.y, 12);
    if (ti >= 0 && P.items[ti].kind === 'text') return textDialog(ti); // vorhandenen Text ändern/löschen
    const text = prompt('Text für diesen Punkt (z. B. Fundstelle, Hinweis):');
    if (text && text.trim()) {
      snapshot();
      P.items.push({ kind: 'text', color: db.color, lat: ll.lat, lon: ll.lng, text: text.trim() });
      changed();
    }
  } else if (tool === 'gpxsel' && !panning && Math.hypot(x - downPt.x, y - downPt.y) < 10) {
    gpxTap(x, y, ll);
  } else if (tool === 'poi' && !panning && Math.hypot(x - downPt.x, y - downPt.y) < 10) {
    setTool('pan');
    placePoi(ll.lat, ll.lng);
  } else if (tool === 'meet' && P.meet && blocked(P.meet)) {
    setTool('pan');
  } else if (tool === 'meet') {
    const text = prompt('Bezeichnung des B-Orts:', (P.meet && P.meet.text) || 'B-Ort');
    if (text !== null) {
      snapshot();
      P.meet = { lat: ll.lat, lon: ll.lng, text: text.trim(), ...(P.meet && P.meet.lock ? { lock: P.meet.lock } : {}) };
      changed();
    }
    setTool('pan');
    if (wizMeet) { wizGo(P.wiz + (text !== null ? 1 : 0)); wizMeet = false; }
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
    if (blocked(P.items[i], 'delete') || guardAssigned(assignedOf(P, P.items[i]))) return;
    before();
    P.items.splice(i, 1);
  } else if (!(P.hide || {}).pois && poiAt(x, y) >= 0) { // ausgeblendet: nicht radierbar
    if (blocked(P.pois[poiAt(x, y)], 'delete')) return;
    before();
    deletePoi(P, P.pois[poiAt(x, y)]);
    renderPois();
  } else if (P.meet && !(P.hide || {}).meet && Math.hypot(toPx(P.meet.lat, P.meet.lon)[0] - x, toPx(P.meet.lat, P.meet.lon)[1] - y) <= 16) {
    if (blocked(P.meet, 'delete')) return;
    before();
    P.meet = null;
  } else {
    const ll = map.containerPointToLatLng([x, y]);
    if (hideGrid()) return;
    const h = hitGrid(ll.lat, ll.lng);
    const key = h && `${h.c},${h.r}`;
    const target = h && (h.g.active ? P : P.otherGrids.find((g) => g.id === h.g.id));
    if (!key) return;
    // ausgeblendete Ebenen (Team bzw. Markierung) bleiben stehen
    const mk = cellMarks(target, key);
    const lay = cellLayers({ hideGrid: false, ...mk });
    const delT = cellEditable({ hideGrid: false, ...mk }) && lay.team && target.fills[key];
    const delS = cellEditable({ hideGrid: false, ...mk }) && lay.status && target.status[key];
    if (!delT && !delS) return;
    if (!canEditCell(P, h.g.id, key)) return toast(MSG_VIEW, 4000);
    if (guardAssigned(assignedCell(P, h.g.id, key))) return;
    before();
    if (delT) delete target.fills[key];
    if (delS) delete target.status[key];
  }
  redraw();
}

// Nochmal auf das aktive Werkzeug tippen: zurück zu „Bewegen“
document.querySelectorAll('.toolbar [data-tool]').forEach((b) => b.addEventListener('click', () => {
  setTool(b.dataset.tool === tool ? 'pan' : b.dataset.tool);
}));
$('undo').addEventListener('click', undo);

// Treffer nur auf sichtbare Dinge (weit herausgezoomt keine Texte/Zeichnungen)
const hitItem = (items, toPx, x, y, tol) => hitItemAll(items, toPx, x, y, tol, labelDetail(map.getZoom()));

// Textpunkt angetippt: Text ändern oder löschen
function textDialog(i) {
  const it = P.items[i];
  if (!it || it.kind !== 'text') return;
  if (isLocked()) return lockedToast();
  if (blocked(it) || guardAssigned(assignedOf(P, it))) return;
  openDlg((box, close) => {
    dlgHead(box, '📍 Text', 'Ändern oder löschen.');
    const inp = document.createElement('input');
    inp.type = 'text';
    inp.id = 'txt-edit';
    inp.value = it.text;
    inp.defaultValue = it.text;
    inp.style.width = '100%';
    inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') close({ text: inp.value }); });
    box.appendChild(inp);
    dlgButton(box, '💾 Speichern', 'primary', () => close({ text: inp.value }));
    dlgButton(box, '📍 Verlegen', '', () => close({ move: true }));
    dlgNavButton(box, close, null, it.text || 'Text', it.lat, it.lon); // v123
    dlgButton(box, '🗑 Löschen', 'urgent', () => close({ del: true }));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  }).then((r) => {
    const k = P.items.indexOf(it);
    if (!r || k < 0) return;
    if (r.move) {
      pendingMove = { item: it };
      setTool('textmove');
      return toast('Neuen Ort auf der Karte antippen', 6000);
    }
    if (r.del) {
      if (blocked(it, 'delete')) return;
      snapshot();
      P.items.splice(k, 1);
      changed();
      return toast('Text gelöscht (↶ macht es rückgängig)', 4000);
    }
    const t = r.text.trim();
    if (!t || t === it.text) return;
    snapshot();
    it.text = t;
    changed();
  });
}

// Zeichnung, Track oder Textpunkt benennen (Name steht auf der Karte, im PDF und im GPX)
function renameItem(i) {
  const it = P.items[i];
  if (!it) return;
  if (it.kind === 'text') return textDialog(i);
  if (isLocked()) return lockedToast();
  if (blocked(it) || guardAssigned(assignedOf(P, it))) return;
  if (it.kind === 'track') {
    outlineDialog(it, '📐 Umriss', { edit: true }).then((r) => {
      if (!r || !P.items.includes(it)) return;
      if (r.del) return deleteOutline(it);
      if (r.vtx) return startVertex(it);
      if (r.zus) return zusatzDialog({ itemIdx: [P.items.indexOf(it)] });
      snapshot();
      applyOutline(it, { ...r, name: r.name || it.name });
      changed();
      if (!$('panel-teams').hidden) renderMarks();
    });
    return;
  }
  strokeDialog(it, '✏️ Zeichnung').then((r) => {
    if (!r || !P.items.includes(it)) return;
    snapshot();
    // alle Striche einer Zeichnung heißen gleich und tragen dieselbe Teamzuteilung
    for (const x of it.group ? P.items.filter((y) => y.group === it.group) : [it]) {
      x.name = r.name;
      if (r.teams.length) x.teams = [...r.teams]; else delete x.teams;
    }
    changed();
    toast(r.name ? `„${r.name}“ gespeichert` : 'Name entfernt');
  });
}
// Zeichnung (Stift): Name und Zuteilung an ein oder mehrere Teams
function strokeDialog(it, title) {
  return openDlg((box, close) => {
    dlgHead(box, title, 'Name steht so auf der Karte, im PDF und im GPX für Garmin.');
    const name = dlgField(box, 'Name', Object.assign(document.createElement('input'), { type: 'text', value: it.name || '' }));
    const teams = P.marks.filter((m) => m.kind === 'team');
    const picked = new Set(it.teams || []);
    if (teams.length) {
      const h = document.createElement('p');
      h.className = 'small';
      h.textContent = 'Zugeteilt an (ein oder mehrere Teams):';
      box.appendChild(h);
      for (const t of teams) {
        const l = document.createElement('label');
        l.className = 'check';
        const c = Object.assign(document.createElement('input'), { type: 'checkbox', checked: picked.has(t.id) });
        c.addEventListener('change', () => { if (c.checked) picked.add(t.id); else picked.delete(t.id); });
        const sp = document.createElement('span');
        sp.textContent = `${typeIcon(t)} ${t.label}`;
        l.append(c, sp);
        box.appendChild(l);
      }
    }
    dlgButton(box, 'Speichern', 'primary', () => close({ name: name.value.trim(), teams: [...picked] }));
    dlgButton(box, 'Abbrechen', '', () => close(null));
    setTimeout(() => { name.focus(); name.select(); }, 50);
  });
}

// Umriss: Name, Zuteilung (Team oder Einheit aus „Einsatz → Kräfte“) und Notiz
function outlineDialog(it, title, opts = {}) {
  return openDlg((box, close) => {
    dlgHead(box, title, 'Name und Notiz stehen so auf der Karte, im PDF und auf dem Garmin.');
    const field = (label, el) => {
      const l = document.createElement('label');
      l.textContent = label;
      l.appendChild(el);
      box.appendChild(l);
      return el;
    };
    const name = field('Name', Object.assign(document.createElement('input'), { type: 'text', value: it.name || '' }));
    const sel = field('Zugeteilt an', document.createElement('select'));
    sel.add(new Option('– niemand –', ''));
    for (const t of assignTargets(P)) sel.add(new Option(`${t.ico || (t.to.startsWith('u:') ? '🚒' : '🐕')} ${t.label}`, t.to));
    if (it.to && ![...sel.options].some((o) => o.value === it.to)) sel.add(new Option(assigneeName(P, it.to) || '(gelöscht)', it.to));
    sel.value = it.to || '';
    const note = field('Notiz', Object.assign(document.createElement('textarea'), { rows: 2, value: it.note || '' }));
    const p = document.createElement('p');
    p.className = 'small';
    p.textContent = 'Teams unter „Teams“, weitere Einheiten (Feuerwehr, Polizei …) unter „Einsatz → Kräfte“.';
    box.appendChild(p);
    dlgButton(box, 'Speichern', 'primary', () => close({ name: name.value.trim(), to: sel.value, note: note.value.trim() }));
    if (opts.edit) {
      const ctr = boxCenter(it.pts);
      if (!it.open && (it.pts || []).length > 2 && ctr) dlgNavButton(box, close, null, it.name || 'Umriss', ctr[0], ctr[1]); // v123: nur gespeicherte, geschlossene Umrisse
      if (db.mode === 'el' && P.live && elTargets(P.sent, P.marks).length) dlgButton(box, '📤 An Team senden', '', () => close({ zus: true })); // v130
      dlgButton(box, '✋ Punkte bearbeiten', '', () => close({ vtx: true }));
      dlgButton(box, '🗑 Löschen', 'urgent', () => close({ del: true }));
    }
    dlgButton(box, 'Abbrechen', '', () => close(null));
    setTimeout(() => { name.focus(); name.select(); }, 50);
  });
}
function applyOutline(it, r) {
  if (r.name) it.name = r.name;
  if (r.to) {
    // einem Team zugeteilt: Umriss in der Teamfarbe (ohne Team zeichnet render.js automatisch grau)
    if (r.to !== it.to) { const m = P.marks.find((x) => x.id === r.to); if (m) it.color = m.color; }
    it.to = r.to;
  } else delete it.to;
  if (r.note) it.note = r.note; else delete it.note;
}

// Umriss löschen (Fenster am Umriss, Langdruck): Sperren wie beim Radierer, vorher fragen
async function deleteOutline(it) {
  if (blocked(it, 'delete') || guardAssigned(assignedOf(P, it))) return;
  const ok = await openDlg((box, close) => {
    dlgHead(box, '🗑 Umriss löschen?', `„${it.name || 'Umriss'}“ wird gelöscht.`);
    dlgButton(box, '🗑 Löschen', 'urgent', () => close(true));
    dlgButton(box, 'Abbrechen', 'primary', () => close(false));
  });
  const k = P.items.indexOf(it);
  if (!ok || k < 0) return;
  snapshot();
  P.items.splice(k, 1);
  changed();
  toast('Umriss gelöscht (↶ macht es rückgängig)', 4000);
}

// ---------- v108: Punkte eines Umrisses bearbeiten ----------
// Eckpunkte ziehen, auf der Kantenmitte ziehen = neuer Punkt, Punkt antippen = löschen. Jede Aktion hat ihr eigenes snapshot().
function startVertex(it) {
  if (isLocked()) return lockedToast();
  if (blocked(it) || guardAssigned(assignedOf(P, it))) return;
  if (db.mode === 'el' ? !canEdit(P, it) : (it.fromEl || it.prev)) return toast(MSG_VIEW, 4000);
  if (tool !== 'pan') setTool('pan');
  endVertex();
  vtx = { it, id: it.id || null, hs: [], ms: [] };
  buildVertex();
  $('vtxbar').hidden = false;
}
function clearVertex() {
  if (!vtx) return;
  for (const m of [...vtx.hs, ...vtx.ms]) m.remove();
  vtx.hs = [];
  vtx.ms = [];
}
function endVertex() {
  if (!vtx) return;
  clearVertex();
  vtx = null;
  $('vtxbar').hidden = true;
  redraw();
}
function buildVertex() {
  clearVertex();
  const it = vtx.it;
  const mk = (cls, size, ll) => L.marker(ll, {
    draggable: true, keyboard: false, zIndexOffset: cls === 'vtx-h' ? 1100 : 1000,
    icon: L.divIcon({ className: cls, iconSize: [size, size] }),
  }).addTo(map);
  for (let i = 0, n = vertexCount(it.pts, it.open); i < n; i++) {
    const m = mk('vtx-h', 24, it.pts[i]);
    m.on('dragstart', () => snapshot());
    m.on('drag', () => { const ll = m.getLatLng(); moveVertex(it.pts, i, ll.lat, ll.lng, it.open); redraw(); });
    m.on('dragend', () => { changed(); buildMids(); });
    m.on('click', () => askRemoveVertex(i));
    vtx.hs.push(m);
  }
  buildMids();
}
function buildMids() {
  if (!vtx) return;
  const it = vtx.it;
  for (const m of vtx.ms) m.remove();
  vtx.ms = edgeMids(it.pts, it.open).map((e) => {
    const m = L.marker([e.lat, e.lon], {
      draggable: true, keyboard: false, zIndexOffset: 1000,
      icon: L.divIcon({ className: 'vtx-mid', iconSize: [16, 16] }),
    }).addTo(map);
    let j = -1;
    m.on('dragstart', () => { snapshot(); const ll = m.getLatLng(); j = insertVertex(it.pts, e.i, ll.lat, ll.lng); });
    m.on('drag', () => { const ll = m.getLatLng(); moveVertex(it.pts, j, ll.lat, ll.lng, it.open); redraw(); });
    m.on('dragend', () => { changed(); setTimeout(() => vtx && vtx.it === it && buildVertex(), 0); });
    return m;
  });
}
async function askRemoveVertex(i) {
  const it = vtx && vtx.it;
  if (!it) return;
  if (vertexCount(it.pts, it.open) <= minPoints(it.open)) return toast(`Mindestens ${minPoints(it.open)} Punkte`);
  const ok = await openDlg((box, close) => {
    dlgHead(box, '🗑 Punkt löschen?', 'Der Punkt wird aus dem Umriss entfernt.');
    dlgButton(box, '🗑 Löschen', 'urgent', () => close(true));
    dlgButton(box, 'Abbrechen', 'primary', () => close(false));
  });
  if (!ok || !vtx || vtx.it !== it) return;
  snapshot();
  if (!removeVertex(it.pts, i, it.open)) return;
  changed();
  buildVertex();
}
// nach Rückgängig: Umriss über die ID neu finden (Undo ersetzt die Objekte), sonst Modus beenden
function syncVertex() {
  if (!vtx) return;
  const it = vtx.id ? P.items.find((x) => x.id === vtx.id) : null;
  if (!it) return endVertex();
  vtx.it = it;
  buildVertex();
}
$('vtx-done').addEventListener('click', endVertex);

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
async function finishPen() {
  const d = draftPen;
  if (!d || !d.strokes.length) return;
  // wie beim Umriss: Name mit Vorschlag „Zeichnung 3“
  const groups = new Set(P.items.filter((it) => it.kind === 'stroke').map((it) => it.group || it));
  const def = `Zeichnung ${groups.size + 1}`;
  const r = await strokeDialog({ name: def, teams: [] }, '✏️ Zeichnung speichern');
  if (!r || draftPen !== d) return;
  const name = r.name || def;
  draftPen = null;
  snapshot();
  const group = uid();
  for (const st of d.strokes) {
    st.group = group;
    st.name = name;
    if (r.teams.length) st.teams = [...r.teams];
    P.items.push(st);
  }
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
$('pen-done').addEventListener('click', async () => {
  await finishPen();
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
async function finishTrack(auto) {
  const d = draftTrack;
  if (!d || d.pts.length < 2) { draftTrack = null; redraw(); return; }
  // Vorschlag: Himmelsrichtung vom B-Ort + fortlaufende Nummer („Nordwest 2“)
  let name = outlineName(P.items, P.meet, d.pts);
  let r = null;
  if (!auto) {
    r = await outlineDialog({ ...d, name }, '📐 Umriss speichern');
    if (!r || draftTrack !== d) return;
    name = r.name || name;
  }
  draftTrack = null;
  snapshot();
  d.name = name;
  if (r) applyOutline(d, r);
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
$('track-done').addEventListener('click', async () => {
  await finishTrack(false);
  if (!draftTrack) setTool('pan');
});
$('track-cancel').addEventListener('click', () => {
  if (draftTrack && draftTrack.pts.length > 1 && !confirm('Umriss verwerfen?')) return;
  draftTrack = null;
  setTool('pan');
  redraw();
  save();
});

// ---------- v121: Wald erkennen und aufteilen ----------
// Waldstück mit dem Finger umkreisen -> Waldflächen aus OpenStreetMap (Overpass) -> in N Teile aufteilen (forest.js).
// Die Teile werden als normale Umrisse (kind 'track') übernommen, mit einem Schritt Rückgängig.
const forestPreview = L.layerGroup().addTo(map);
const FOREST_COLORS = ['#d81b60', '#1e88e5', '#fb8c00', '#8e24aa', '#00897b', '#6d4c41', '#7cb342', '#3949ab'];
const FOREST_LETTERS = 'ABCDEFGH';
const forestHa = (m2) => (m2 / 1e4).toLocaleString('de-DE', { maximumFractionDigits: 1 });
let forestBarDone = null; // wartet auf einen Knopf der Vorschau-Leiste

function forestClear() {
  forestPreview.clearLayers();
  $('forestbar').hidden = true;
  forestBarDone = null;
}
function forestStart() {
  if (tool === 'forestdraw') return setTool('pan');
  setTool('forestdraw');
  if (tool === 'forestdraw') toast('Mit dem Finger einmal um den Wald herum malen', 5000);
}
$('track-forest').addEventListener('click', forestStart);
$('more-forest').addEventListener('click', () => { closePanels(); forestStart(); });
function forestBarWait() {
  $('forestbar').hidden = false;
  return new Promise((resolve) => { forestBarDone = resolve; });
}
for (const [id, v] of [['forest-edit', 'edit'], ['forest-ok', 'apply'], ['forest-cancel', 'cancel']]) {
  $(id).addEventListener('click', () => { const f = forestBarDone; forestBarDone = null; $('forestbar').hidden = true; if (f) f(v); });
}
const forestLassoLayer = (pts) => L.polygon(pts, { color: '#2e7d32', weight: 3, dashArray: '2 6', fill: false, interactive: false });

async function forestLassoDone(raw) {
  // Punkte ausdünnen (ca. alle 3 m)
  const pts = [];
  for (const q of raw) {
    const l = pts[pts.length - 1];
    if (!l || distance(l[0], l[1], q[0], q[1]) >= 3) pts.push([Math.round(q[0] * 1e6) / 1e6, Math.round(q[1] * 1e6) / 1e6]);
  }
  if (pts.length < 3 || pathLen(pts) < MIN_OUTLINE_M) return toast('Zu klein – nochmal „🌲 Wald“ und größer umkreisen');
  const o = originOf(pts);
  const lassoMp = lassoPolygon(pts, o);
  const lassoM2 = mpArea(lassoMp);
  if (lassoM2 < 1) return toast('Zu klein – nochmal „🌲 Wald“ und größer umkreisen');
  if (lassoM2 > MAX_AREA_M2) return toast('Bitte kleiner umkreisen (höchstens 25 km²)', 5000);
  $('toast').hidden = true;
  forestClear();
  forestPreview.addLayer(forestLassoLayer(pts));
  const la = pts.map((q) => q[0]);
  const lo = pts.map((q) => q[1]);
  const bbox = { south: Math.min(...la) - 0.0005, north: Math.max(...la) + 0.0005, west: Math.min(...lo) - 0.0008, east: Math.max(...lo) + 0.0008 };
  // Laden (abbrechbar)
  const ctl = new AbortController();
  let closeLoad = null;
  openDlg((box, close) => {
    closeLoad = close;
    dlgHead(box, '🌲 Waldflächen werden geladen …', OSM_NOTE);
    dlgButton(box, 'Abbrechen', '', () => { ctl.abort(); close(null); });
  }, { keep: true });
  let data = null;
  let reason = '';
  try {
    data = parseForest(await overpass(forestQuery(bbox), ctl.signal, 'Waldsuche'));
  } catch (err) {
    if (ctl.signal.aborted) { forestClear(); return; }
    reason = (err && err.message) || 'Keine Verbindung';
  }
  if (closeLoad) closeLoad(null);
  let mp = data ? forestInLasso(data.forests, pts, o) : [];
  const lines = data ? data.lines.map((l) => l.map((q) => toXY(q, o))) : [];
  let forest = true;
  if (!mp.length) {
    // v121: kein Wald erkannt oder Netzfehler -> die umkreiste Fläche selbst aufteilen?
    const ok = await openDlg((box, close) => {
      dlgHead(box, reason ? '🌲 Waldsuche fehlgeschlagen' : '🌲 Kein Wald erkannt', reason ? `${reason}. Die umkreiste Fläche selbst aufteilen?` : 'Kein Wald erkannt – die umkreiste Fläche selbst aufteilen?');
      dlgButton(box, 'Umkreiste Fläche aufteilen', 'primary', () => close(true));
      dlgButton(box, 'Abbrechen', '', () => close(false));
    });
    if (!ok) { forestClear(); return; }
    mp = lassoMp;
    forest = false;
  }
  await forestPlan({ mp, lines, o, forest, pts });
}

// Fenster „Wald aufteilen“, Vorschau und Übernehmen
async function forestPlan(ctx) {
  const total = mpArea(ctx.mp);
  const st = { n: 2, follow: true, rows: [], base: outlineName(P.items, P.meet, ctx.pts) };
  for (;;) {
    while (st.rows.length < st.n) st.rows.push({ size: 'gleich', pct: '', name: `${st.base} ${FOREST_LETTERS[st.rows.length]}`, to: '' });
    const act = await forestDialog(st, ctx, total);
    if (act !== 'preview' && act !== 'apply') { forestClear(); return; }
    if (isLocked()) { forestClear(); return lockedToast(); }
    const res = await forestCompute(st, ctx, total);
    if (!res) continue;
    if (act === 'apply') { forestClear(); return forestCommit(res.tracks); }
    forestShow(st, ctx, res);
    const a = await forestBarWait();
    if (a === 'apply') { forestClear(); return forestCommit(res.tracks); }
    if (a !== 'edit') { forestClear(); return; }
    forestPreview.clearLayers();
    forestPreview.addLayer(forestLassoLayer(ctx.pts));
  }
}

function forestDialog(st, ctx, total) {
  const teams = assignTargets(P);
  return openDlg((box, close) => {
    const n0 = ctx.mp.length;
    dlgHead(box, '🌲 Wald aufteilen', ctx.forest ? `Erkannt: ${forestHa(total)} ha Wald (${n0} Stück${n0 === 1 ? '' : 'e'})` : `Umkreiste Fläche: ${forestHa(total)} ha`);
    const src = document.createElement('p');
    src.className = 'small';
    src.textContent = OSM_NOTE;
    box.appendChild(src);
    const lab = document.createElement('label');
    lab.textContent = 'Anzahl Teile';
    box.appendChild(lab);
    const nbox = document.createElement('div');
    nbox.className = 'wald-n';
    box.appendChild(nbox);
    const list = document.createElement('div');
    box.appendChild(list);
    const follow = document.createElement('label');
    follow.className = 'check';
    const fcb = document.createElement('input');
    fcb.type = 'checkbox';
    fcb.id = 'wald-follow';
    fcb.checked = st.follow;
    fcb.addEventListener('change', () => { st.follow = fcb.checked; });
    follow.append(fcb, ' Grenzen an Wegen/Bächen ausrichten');
    box.appendChild(follow);
    const note = document.createElement('p');
    note.className = 'small';
    note.textContent = 'Mit Wegen sind die Flächen nur ungefähr gleich (± 15 %); ohne passenden Weg wird gerade geschnitten.';
    box.appendChild(note);
    const hint = document.createElement('p');
    hint.className = 'wald-hint';
    hint.id = 'wald-hint';
    hint.hidden = true;
    box.appendChild(hint);
    // Knöpfe unten fest in einer Zeile (auf dem Handy sonst erst nach langem Scrollen erreichbar)
    const acts = document.createElement('div');
    acts.className = 'wald-acts';
    box.appendChild(acts);
    const bPrev = dlgButton(acts, '👁 Vorschau', '', () => close('preview'));
    bPrev.id = 'wald-preview';
    const bOk = dlgButton(acts, '✅ Übernehmen', 'primary', () => close('apply'));
    bOk.id = 'wald-apply';
    dlgButton(acts, 'Abbrechen', '', () => close(null));

    const sollEls = [];
    const rowEls = [];
    const refresh = () => {
      const r = forestShares(st.rows.slice(0, st.n).map((x) => ({ size: st.n === 1 ? 'gleich' : x.size, pct: x.pct })));
      hint.hidden = !r.error;
      hint.textContent = r.error || '';
      bPrev.disabled = !!r.error;
      bOk.disabled = !!r.error;
      st.rows.slice(0, st.n).forEach((x, i) => {
        const bad = st.n > 1 && forestShares([{ size: x.size, pct: x.pct }]).error;
        rowEls[i].classList.toggle('bad', !!bad);
        sollEls[i].textContent = r.shares ? `Soll ${forestHa(r.shares[i] * total)} ha` : 'Soll – ha';
      });
      follow.hidden = st.n === 1;
      note.hidden = st.n === 1;
    };
    const build = () => {
      nbox.innerHTML = '';
      for (let k = 1; k <= MAX_PARTS; k++) {
        const b = document.createElement('button');
        b.textContent = String(k);
        b.dataset.n = String(k);
        if (k === st.n) b.className = 'primary';
        b.addEventListener('click', () => {
          st.n = k;
          while (st.rows.length < k) st.rows.push({ size: 'gleich', pct: '', name: `${st.base} ${FOREST_LETTERS[st.rows.length]}`, to: '' });
          build();
        });
        nbox.appendChild(b);
      }
      list.innerHTML = '';
      sollEls.length = 0;
      rowEls.length = 0;
      st.rows.slice(0, st.n).forEach((x, i) => {
        const row = document.createElement('div');
        row.className = 'wald-row';
        row.style.borderLeftColor = FOREST_COLORS[i];
        const name = document.createElement('input');
        name.type = 'text';
        name.value = x.name;
        name.setAttribute('aria-label', `Name Teil ${FOREST_LETTERS[i]}`);
        name.addEventListener('input', () => { x.name = name.value; });
        row.appendChild(name);
        if (st.n > 1) {
          const size = document.createElement('select');
          size.setAttribute('aria-label', `Größe Teil ${FOREST_LETTERS[i]}`);
          for (const v of ['gleich', 'kleiner', 'größer']) size.add(new Option(v === 'gleich' ? 'gleich groß' : v, v));
          size.value = x.size;
          row.appendChild(size);
          const pl = document.createElement('label');
          pl.className = 'wald-pct';
          const pct = document.createElement('input');
          pct.type = 'number';
          pct.inputMode = 'numeric';
          pct.step = 'any';
          pct.value = x.pct;
          pct.setAttribute('aria-label', `Prozent Teil ${FOREST_LETTERS[i]}`);
          pl.append(pct, '% eines normalen Teils');
          pl.hidden = x.size === 'gleich';
          row.appendChild(pl);
          size.addEventListener('change', () => { x.size = size.value; pl.hidden = x.size === 'gleich'; refresh(); });
          pct.addEventListener('input', () => { x.pct = pct.value; refresh(); });
        }
        const team = document.createElement('select');
        team.setAttribute('aria-label', `Team Teil ${FOREST_LETTERS[i]}`);
        team.add(new Option('ohne Team', ''));
        for (const t of teams) team.add(new Option(`${t.ico || (t.to.startsWith('u:') ? '🚒' : '🐕')} ${t.label}`, t.to));
        team.value = [...team.options].some((op) => op.value === x.to) ? x.to : '';
        team.addEventListener('change', () => { x.to = team.value; });
        row.appendChild(team);
        const soll = document.createElement('div');
        soll.className = 'wald-soll';
        row.appendChild(soll);
        sollEls.push(soll);
        rowEls.push(row);
        list.appendChild(row);
      });
      refresh();
    };
    build();
  });
}

// Aufteilen rechnen -> { parts, tracks, soll } oder null (Fehler, Fenster geht wieder auf)
async function forestCompute(st, ctx, total) {
  const rows = st.rows.slice(0, st.n);
  const r = forestShares(rows.map((x) => ({ size: st.n === 1 ? 'gleich' : x.size, pct: x.pct })));
  if (r.error) { toast(r.error); return null; }
  toast('Wird berechnet …', 2000);
  await new Promise((resolve) => setTimeout(resolve, 30)); // Meldung vor der Rechnung anzeigen
  try {
    const parts = splitArea(ctx.mp, r.shares, ctx.lines, { followWays: st.follow && st.n > 1 });
    const tracks = toTracks(parts, rows.map((x, i) => x.name.trim() || `${st.base} ${FOREST_LETTERS[i]}`), rows.map((x) => x.to), ctx.o);
    if (!tracks.length) { toast('Aufteilen ergab keine Fläche'); return null; }
    $('toast').hidden = true;
    return { parts, tracks, soll: r.shares.map((x) => x * total) };
  } catch (err) {
    repLog.add(`Wald aufteilen fehlgeschlagen: ${err && err.message}`);
    toast('Aufteilen ging nicht – bitte anders umkreisen');
    return null;
  }
}

function forestShow(st, ctx, res) {
  forestPreview.clearLayers();
  forestPreview.addLayer(forestLassoLayer(ctx.pts));
  const infos = [];
  res.parts.forEach((part, i) => {
    const c = FOREST_COLORS[i % FOREST_COLORS.length];
    // zweizeilig und kurz: schmale Teile auf dem Handy dürfen sich nicht überdecken
    const label = `${FOREST_LETTERS[i]} ${forestHa(part.area)} ha${part.onWay ? ' 🛤' : ''}${st.n > 1 ? `<br><small>Soll ${forestHa(res.soll[i])}</small>` : ''}`;
    infos.push(`${FOREST_LETTERS[i]} ${forestHa(part.area)}${part.onWay ? '🛤' : ''}`);
    part.polys.forEach((ring, k) => {
      const poly = L.polygon(ring.map((q) => toLL(q, ctx.o)), { color: c, weight: 3, dashArray: '8 6', fillColor: c, fillOpacity: 0.18, interactive: false });
      if (k === 0) poly.bindTooltip(label, { permanent: true, direction: 'center', className: 'forest-tip' });
      forestPreview.addLayer(poly);
    });
  });
  $('forest-info').textContent = `Vorschau (ha): ${infos.join(' · ')}`;
}

function forestCommit(tracks) {
  snapshot();
  for (const t of tracks) {
    const m = t.to ? P.marks.find((x) => x.id === t.to) : null;
    const it = { kind: 'track', name: t.name, color: m ? m.color : db.color, w: 4, pts: t.pts };
    if (t.to) it.to = t.to;
    P.items.push(it);
  }
  changed();
  toast(`🌲 ${tracks.length} Umriss${tracks.length === 1 ? '' : 'e'} gespeichert (↶ macht es rückgängig) · ${OSM_NOTE}`, 6000);
}

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
  for (const m of [NO_TEAM_MARK, ...P.marks]) {
    const b = document.createElement('button');
    b.innerHTML = '<i></i><span></span>';
    b.querySelector('i').style.background = m.color;
    b.querySelector('span').textContent = m === NO_TEAM_MARK ? 'ohne Team' : `${m.kind === 'team' && !isDog(m) ? `${typeIcon(m)} ` : ''}${m.label || '(ohne Namen)'}`; // v128: Typ-Symbol (außer Hund)
    b.classList.toggle('active', act && act.id === m.id);
    b.addEventListener('click', () => { db.activeMark = m.id; showForPaint(m); renderPalette(); save(); });
    box.appendChild(b);
  }
  const add = document.createElement('button');
  add.textContent = '+ Team';
  add.addEventListener('click', () => { addMark('team', true); });
  box.appendChild(add);
}

// ---------- Teams & Legende ----------
// quick: aus der Feld-Leiste – nur nach dem Namen fragen, kein Teams-Fenster
function addMark(kind, quick = false) {
  let label = kind === 'team' ? nextTeamLabel(P) : 'Markierung'; // v125: im UA „N-Team 1“
  if (quick) {
    const t = prompt(kind === 'team' ? 'Name des Teams:' : 'Bedeutung der Markierung (z. B. „Fundstelle“, „Gefahr“):', label);
    if (t === null) return null;
    label = t.trim() || label;
    const dup = kind === 'team' && sameTeamName(P.marks, label);
    if (dup && !confirm(`Gibt es schon: ${dup.label} – trotzdem?`)) return null; // v127
  }
  snapshot();
  const used = new Set(P.marks.map((m) => m.color));
  const color = MARK_COLORS.find((c) => !used.has(c)) || MARK_COLORS[P.marks.length % MARK_COLORS.length];
  const m = kind === 'team'
    ? { id: uid(), kind: 'team', label, dog: '', color, ...(P.parentEid ? { ua: uaName(P.title) } : {}) } // v128: im UA angelegt -> UA-Name (für die UA-Übersicht)
    : { id: uid(), kind: 'status', label, color };
  P.marks.push(m);
  db.activeMark = m.id;
  changed();
  if (quick) return m;
  openPanel('panel-teams');
  const inp = $('mark-list').querySelector(`[data-id="${m.id}"] input`);
  if (inp) { inp.focus(); inp.select(); }
}

// Team oder Markierung löschen (Teams-Fenster und Fenster „Feld-Markierungen“): fragt nach, gibt ihre Felder frei
function deleteMark(m, cnt = null) {
  const maps = [mapFor(P, m), ...(P.otherGrids || []).map((g) => mapFor(g, m))];
  const n = cnt ?? maps.reduce((a, mp) => a + Object.values(mp).filter((v) => v === m.id).length, 0);
  if (!confirm(`„${markLabel(m) || 'Eintrag'}“ löschen?${n ? ` ${n} zugeteilte Felder werden freigegeben.` : ''}`)) return false;
  snapshot();
  P.marks = P.marks.filter((x) => x.id !== m.id);
  for (const mp of maps) for (const k of Object.keys(mp)) if (mp[k] === m.id) delete mp[k];
  changed();
  return true;
}

// v111: Zeilen am Griff ≡ ziehen (Maus und Finger). rows: Elemente mit data-id und data-kind; nur innerhalb derselben Art.
function makeSortable(list, onDone) {
  list.querySelectorAll('.grip').forEach((g) => {
    g.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'mouse' && e.button !== 0) return;
      e.preventDefault();
      const row = g.closest('[data-id]');
      const kind = row.dataset.kind;
      row.classList.add('dragging');
      // v129: hohe Team-Zeilen (Typ, Organisation …) – am oberen/unteren Rand scrollt die Liste beim Ziehen mit
      let sc = list.parentElement;
      while (sc && sc !== document.body && !(sc.scrollHeight > sc.clientHeight + 2 && /auto|scroll/.test(getComputedStyle(sc).overflowY))) sc = sc.parentElement;
      let lastY = e.clientY;
      let dragging = true;
      const place = (y) => {
        const sibs = [...list.querySelectorAll(`[data-kind="${kind}"]`)].filter((x) => x !== row);
        const next = sibs.find((x) => { const r = x.getBoundingClientRect(); return y < r.top + r.height / 2; });
        if (next) { if (row.nextElementSibling !== next) list.insertBefore(row, next); } else { const last = sibs[sibs.length - 1]; if (last && last.nextElementSibling !== row) last.after(row); }
      };
      const tick = () => {
        if (!dragging) return;
        if (sc && sc !== document.body) {
          const r = sc.getBoundingClientRect();
          const edge = 60;
          const dy = lastY < r.top + edge ? -Math.ceil((r.top + edge - lastY) / 4) : lastY > r.bottom - edge ? Math.ceil((lastY - r.bottom + edge) / 4) : 0;
          if (dy) { const before = sc.scrollTop; sc.scrollTop += dy; if (sc.scrollTop !== before) place(lastY); }
        }
        requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
      // Listener am Fenster: das Umhängen der Zeile im DOM beendet sonst ein setPointerCapture
      const move = (ev) => {
        if (ev.pointerId !== e.pointerId) return;
        lastY = ev.clientY;
        place(ev.clientY);
      };
      const up = (ev) => {
        if (ev.pointerId !== e.pointerId) return;
        dragging = false;
        window.removeEventListener('pointermove', move);
        window.removeEventListener('pointerup', up);
        window.removeEventListener('pointercancel', up);
        row.classList.remove('dragging');
        const ids = [...list.querySelectorAll(`[data-kind="${kind}"]`)].map((x) => x.dataset.id);
        const before = P.marks.filter((m) => m.kind === kind).map((m) => m.id);
        if (ids.join() === before.join()) return;
        snapshot();
        P.marks = reorderMarks(P.marks, kind, ids);
        changed();
        renderPalette();
        onDone && onDone();
      };
      window.addEventListener('pointermove', move);
      window.addEventListener('pointerup', up);
      window.addEventListener('pointercancel', up);
    });
  });
}
function renderMarks() {
  const box = $('mark-list');
  box.innerHTML = '';
  const as = Object.fromEntries(assignments(P).map((a) => [a.mark.id, a]));
  const act = activeMark();
  // nur Teams; Markierungen (abgesucht, Fundstelle …) setzt und ändert man per langem Druck aufs Feld
  for (const m of P.marks.filter((x) => x.kind === 'team')) {
    const el = document.createElement('div');
    el.className = 'mark' + (act && act.id === m.id ? ' active' : '');
    el.dataset.id = m.id;
    el.dataset.kind = m.kind;
    const a = as[m.id];
    el.innerHTML = `
      <span class="grip" title="Ziehen zum Verschieben">≡</span>
      <button class="swatch" title="Zum Einfärben auswählen"></button>
      <div class="fields">
        ${m.kind === 'team' ? '<div class="uname" title="Automatisch: Organisation + laufende Nummer"></div>' : '<input type="text" class="name" placeholder="Bedeutung">'}
        ${m.kind === 'team' ? `<div class="pair one"><label><small>Typ</small><select class="uty" aria-label="Typ der Einheit">${UNIT_TYPES.map((t) => `<option value="${t.code}">${t.ico} ${t.label}</option>`).join('')}</select></label></div>
        <div class="pair one"><label><small>Organisation</small><input type="text" class="uorg" list="org-list" placeholder="FF, DRK, …" maxlength="30"></label></div>
        <div class="pair dogrow"><label class="doghund"><small>Hund</small><input type="text" class="dog" placeholder="Name"></label><label><small>Suchhelfer</small><input type="number" class="helpers" min="0" inputmode="numeric" placeholder="Anzahl"></label></div>` : ''}
        <select class="color" aria-label="Farbe"></select>
        <div class="cells"></div>
      </div>
      <button class="del" title="Löschen">✕</button>`;
    el.querySelector('.swatch').style.background = m.color;
    if (m.kind === 'team') {
      el.querySelector('.uname').textContent = m.label || 'Team';
      el.querySelector('.dog').value = m.dog || ''; el.querySelector('.helpers').value = m.helpers || '';
      el.querySelector('.uty').value = unitType(m); el.querySelector('.uorg').value = m.org || '';
      el.querySelector('.doghund').hidden = !isDog(m); // Hundename nur beim Hund-Team, Suchhelfer bei allen
    } else {
      el.querySelector('.name').value = m.label;
    }
    const outl = m.kind === 'team' ? P.items.filter((it) => it.kind === 'track' && it.to === m.id).map((it) => it.name || 'Umriss') : [];
    // v130.7: Stift-Zeichnungen, die diesem Team zugeteilt sind (je Gruppe nur einmal)
    const drGroups = new Set();
    const assigned = (it) => it.kind === 'stroke' && (it.teams || []).includes(m.id) && (!it.group || !drGroups.has(it.group));
    const draw = m.kind === 'team'
      ? P.items.filter(assigned).map((it) => { if (it.group) drGroups.add(it.group); return it.name || 'Zeichnung'; })
      : [];
    el.querySelector('.cells').textContent = (a && a.count ? `${a.count} Feld${a.count > 1 ? 'er' : ''}: ${a.text}` : 'keine Felder')
      + (outl.length ? ` · Umriss${outl.length > 1 ? 'e' : ''}: ${outl.join(', ')}` : '')
      + (draw.length ? ` · Zeichnung${draw.length > 1 ? 'en' : ''}: ${draw.join(', ')}` : '');
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
    if (m.kind !== 'team') {
      let prevLabel = m.label;
      el.querySelector('.name').addEventListener('input', (e) => { m.label = e.target.value; renderPalette(); redraw(); save(); });
      // v127: doppelter Teamname -> nachfragen (beim Verlassen des Feldes), sonst alter Name zurück
      el.querySelector('.name').addEventListener('change', (e) => {
        const dup = sameTeamName(P.marks, m.label, m.id);
        if (dup && !confirm(`Gibt es schon: ${dup.label} – trotzdem?`)) {
          m.label = prevLabel;
          e.target.value = prevLabel;
          renderPalette(); redraw(); save();
          return;
        }
        prevLabel = m.label;
      });
    }
    if (m.kind === 'team') {
      // v130.6: Typ, Organisation (Funkrufname/Name entstehen daraus automatisch), Suchhelfer
      el.querySelector('.uty').addEventListener('change', (e) => { m.ty = e.target.value; cleanUnit(m); changed(); renderMarks(); renderPalette(); });
      el.querySelector('.uorg').addEventListener('input', (e) => { m.org = e.target.value; cleanUnit(m); save(); });
      // Funkrufname (und damit der Teamname) erst beim Verlassen des Felds neu bilden – sonst würde er
      // bei jedem Tastendruck wechseln (die laufende Nummer hängt vom vollständigen Organisationsnamen ab)
      el.querySelector('.uorg').addEventListener('change', (e) => {
        m.org = e.target.value; cleanUnit(m);
        m.fk = nextFunkrufname(m.org, P.marks, m.id);
        if (m.fk) m.label = m.fk;
        changed(); renderMarks();
      });
      el.querySelector('.dog').addEventListener('input', (e) => { m.dog = e.target.value; save(); });
      el.querySelector('.helpers').addEventListener('input', (e) => { const n = parseInt(e.target.value, 10); if (n > 0) m.helpers = n; else delete m.helpers; save(); });
    }
    sel.addEventListener('change', () => { m.color = sel.value; changed(); renderMarks(); });
    el.querySelector('.del').addEventListener('click', () => { if (deleteMark(m, a ? a.count : 0)) renderMarks(); });
    box.appendChild(el);
  }
  makeSortable(box, renderMarks);
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

// ---------- Raster ----------
function setArea(area, cellM = P.cellM) {
  if (P.area && (blockedGrid(P.gridId) || guardAssigned(assignedGrid(P, P.gridId)))) return false;
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

// Neues Raster: 2 Minuten lang Breite und Höhe an Anfassern (Ränder, Ecken) ändern – immer in ganzen Feldern
const GRID_FIT_MS = 120e3;
let gridFit = null; // { gid, until, marks: [L.marker], timer }
function startGridFit() {
  endGridFit();
  if (!grid) return;
  gridFit = { gid: P.gridId, until: Date.now() + GRID_FIT_MS, marks: [] };
  for (const k of ['n', 's', 'w', 'e', 'nw', 'ne', 'sw', 'se']) {
    const m = L.marker([0, 0], {
      draggable: true, zIndexOffset: 1000, keyboard: false,
      icon: L.divIcon({ className: `gfit-h gfit-${k.length > 1 ? 'c' : k}`, iconSize: [28, 28] }),
    }).addTo(map);
    m.on('drag', () => { gridFit.until = Math.max(gridFit.until, Date.now() + 15e3); const r = fitGridArea(grid, k, m.getLatLng()); dragRect = { a: { lat: r.north, lng: r.west }, b: { lat: r.south, lng: r.east } }; redraw(); });
    m.on('dragend', () => { const r = fitGridArea(grid, k, m.getLatLng()); dragRect = null; setArea(r); placeGridFit(); });
    m.k = k;
    gridFit.marks.push(m);
  }
  placeGridFit();
  $('gridfitbar').hidden = false;
  gridFit.timer = setInterval(tickGridFit, 1000);
  tickGridFit();
}
function placeGridFit() {
  if (!gridFit || !grid) return;
  const b = gridBounds(grid);
  const mid = { lat: (b.north + b.south) / 2, lng: (b.west + b.east) / 2 };
  const at = { n: [b.north, mid.lng], s: [b.south, mid.lng], w: [mid.lat, b.west], e: [mid.lat, b.east], nw: [b.north, b.west], ne: [b.north, b.east], sw: [b.south, b.west], se: [b.south, b.east] };
  for (const m of gridFit.marks) m.setLatLng(at[m.k]);
}
function tickGridFit() {
  if (!gridFit) return;
  const left = gridFit.until - Date.now();
  if (left <= 0 || P.gridId !== gridFit.gid || !grid) return endGridFit();
  const s = Math.ceil(left / 1000);
  $('gridfit-info').textContent = `↔ Ränder ziehen · ${grid.cols} × ${grid.rows} Felder · noch ${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}
function endGridFit() {
  if (!gridFit) return;
  clearInterval(gridFit.timer);
  for (const m of gridFit.marks) m.remove();
  gridFit = null;
  dragRect = null;
  $('gridfitbar').hidden = true;
  redraw();
}
$('gridfit-done').addEventListener('click', endGridFit);

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
    + `Fläche ${formatMeters(grid.cols * grid.cellM)} × ${formatMeters(grid.rows * grid.cellM)}`;
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
  if (it.kind === 'track') return `${it.open ? 'Track' : 'Umriss'}: ${it.name || 'ohne Namen'} (${trackDesc(it.pts, it.open)}${importTag(it) ? ` · ${importTag(it)}` : ''})`; // v128: Kennzeichen + Zeit importierter Tracks
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
  if (P.pois.length) row(`Lage-Orte (${P.pois.length})`, !hide.pois, setHide('pois'), '#c62828');
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
    row(itemName(it, n), !it.hidden, (on) => { for (const x of members) x.hidden = !on; }, outlineColor(it, db.mode !== 'hf'));
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
    // v130.5: stufenlos – nur beim Klicken/Loslassen (nicht beim Ziehen) auf ganze Stufe einrasten
    const raw = map.getMinZoom() + f * (map.getMaxZoom() - map.getMinZoom());
    const z = dragging ? raw : Math.round(raw);
    if (Math.abs(z - map.getZoom()) > 0.001) map.setZoom(z, { animate: !dragging });
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
  if (setArea({ north: b.getNorth(), south: b.getSouth(), west: b.getWest(), east: b.getEast() })) { closePanels(); startGridFit(); }
});
$('grid-remove').addEventListener('click', () => {
  const multi = allGrids(P).length > 1;
  if (!grid && !multi) return;
  if (blockedGrid(P.gridId, 'delete') || guardAssigned(assignedGrid(P, P.gridId))) return;
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
  // im Unterabschnitt bleiben Felder des Grund-Einsatzes stehen
  const free = (gid) => canEditGrid(P, gid) && !(P.gown && P.gown[gid]) && !assignedGrid(P, gid); // Raster übernommener Aufträge bleiben stehen
  if (allGrids(P).some((g) => assignedGrid(P, g.id))) toast('🔒 Felder übernommener Aufträge bleiben stehen – einzeln ändern (mit Freigabe)', 6000);
  if (free(P.gridId)) { P.fills = {}; P.status = {}; }
  P.otherGrids = P.otherGrids.map((g) => (free(g.id) ? { ...g, fills: {}, status: {} } : g));
  changed();
});
$('clear-drawings').addEventListener('click', () => {
  if (!P.items.length || !confirm('Alle Zeichnungen und Texte löschen?')) return;
  snapshot();
  const keep = (it) => !canDelete(P, it) || assignedOf(P, it); // übernommene Aufträge: Zeichnungen bleiben stehen
  const keepN = P.items.filter((it) => !canDelete(P, it)).length;
  const asgN = P.items.filter((it) => canDelete(P, it) && assignedOf(P, it)).length;
  P.items = P.items.filter(keep);
  changed();
  if (keepN) toast(`${MSG_DELETE} (${keepN} Element${keepN === 1 ? '' : 'e'} bleiben erhalten)`, 5000);
  else if (asgN) toast(`🔒 ${asgN} Element${asgN === 1 ? '' : 'e'} übernommener Aufträge bleiben stehen – einzeln löschen (mit Freigabe)`, 6000);
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
// ---------- Langer Druck ----------
// Auf der Karte: Umriss/Linie unter dem Finger → Fenster (Name, Zuteilung, Punkte bearbeiten, Löschen).
// Auf dem Knopf „Feld“: Fenster „Feld-Markierungen“ (Teams und Markierungen wählen, anlegen, ändern).
const LONG_PRESS = 550; // ms
let pressT = null;
let pressAt = null;
let longPressedAt = 0;
const mapEl = map.getContainer();
mapEl.addEventListener('pointerdown', (e) => {
  clearTimeout(pressT);
  if (!e.isPrimary || (e.pointerType === 'mouse' && e.button !== 0) || tool !== 'pan' || vtx) return;
  if (e.target.closest && e.target.closest('.leaflet-control, .gfit-h, .vtx-h, .vtx-mid, button, a')) return;
  pressAt = { x: e.clientX, y: e.clientY };
  pressT = setTimeout(() => {
    pressT = null;
    longPressedAt = Date.now(); // der folgende Klick gehört dazu
    const r = mapEl.getBoundingClientRect();
    const i = hitItem(P.items, toPx, pressAt.x - r.left, pressAt.y - r.top, 14);
    const it = i >= 0 ? P.items[i] : null;
    if (!it || it.kind !== 'track') return;
    if (navigator.vibrate) navigator.vibrate(30);
    // v109: Langdruck = Punkte direkt ziehbar (Name/Team/Notiz/Löschen per Antippen)
    if (db.mode === 'el' || (!it.fromEl && !it.prev)) startVertex(it);
  }, LONG_PRESS);
});
mapEl.addEventListener('pointermove', (e) => {
  if (pressT && pressAt && Math.hypot(e.clientX - pressAt.x, e.clientY - pressAt.y) > 10) { clearTimeout(pressT); pressT = null; }
});
for (const ev of ['pointerup', 'pointercancel']) mapEl.addEventListener(ev, () => { clearTimeout(pressT); pressT = null; });
map.on('zoomstart movestart', () => { clearTimeout(pressT); pressT = null; });
mapEl.addEventListener('contextmenu', (e) => e.preventDefault());

// Langer Druck auf „Feld“ (Werkzeugleiste): Teams/Markierungen verwalten. Ein Tipp wählt weiterhin das Werkzeug.
const fillBtn = document.querySelector('.toolbar [data-tool="fill"]');
let fillPressT = null;
let fillLongAt = 0;
fillBtn.addEventListener('pointerdown', (e) => {
  clearTimeout(fillPressT);
  fillLongAt = 0; // neuer Druck: der nächste Klick gehört wieder zum Tipp
  if (!e.isPrimary || (e.pointerType === 'mouse' && e.button !== 0) || db.mode !== 'el') return;
  fillPressT = setTimeout(() => {
    fillPressT = null;
    fillLongAt = Date.now();
    if (navigator.vibrate) navigator.vibrate(30);
    if (isLocked()) return lockedToast();
    markDialog();
  }, LONG_PRESS);
});
for (const ev of ['pointerup', 'pointercancel', 'pointerleave']) fillBtn.addEventListener(ev, () => { clearTimeout(fillPressT); fillPressT = null; });
fillBtn.addEventListener('contextmenu', (e) => e.preventDefault());
// Klick nach einem langen Druck darf das Werkzeug nicht umschalten (Capture-Phase, vor dem Werkzeug-Handler)
fillBtn.addEventListener('click', (e) => {
  if (Date.now() - fillLongAt < 1000) { e.stopImmediatePropagation(); e.preventDefault(); }
}, true);

// Fenster „Feld-Markierungen“: alle Teams und Markierungen, wählen / ändern / löschen / neu
function markDialog() {
  let edit = null; // Markierung, die gerade geändert wird
  return openDlg((box, close) => {
    const pick = (m) => { db.activeMark = m.id; renderPalette(); save(); close(true); setTool('fill'); showForPaint(m); };
    const render = () => {
      box.innerHTML = '';
      if (edit) {
        const m = edit;
        dlgHead(box, '✏️ Markierung ändern', 'Gilt für alle Felder mit dieser Markierung und für die Legende im PDF.');
        const inp = document.createElement('input');
        inp.type = 'text';
        inp.id = 'mk-name';
        inp.value = m.label;
        const sel = document.createElement('select');
        sel.id = 'mk-color';
        for (const c of [...new Set([...MARK_COLORS, m.color])]) sel.add(new Option(COLOR_NAMES[c] || 'eigene Farbe', c));
        sel.value = m.color;
        box.append(inp, sel);
        dlgButton(box, 'Speichern', 'primary', () => {
          snapshot();
          m.label = inp.value.trim() || m.label;
          m.color = sel.value;
          changed();
          renderPalette();
          edit = null;
          render();
        });
        dlgButton(box, '🗑️ Löschen', 'danger', () => { if (deleteMark(m)) { edit = null; render(); } });
        dlgButton(box, '‹ Zurück', '', () => { edit = null; render(); });
        return;
      }
      dlgHead(box, '▦ Feld-Markierungen', 'Antippen wählt die Markierung und das Werkzeug „Feld“.');
      const act = activeMark();
      const list = document.createElement('div');
      list.className = 'mklist';
      const row = (m, editable) => {
        const r = document.createElement('div');
        r.className = 'mkrow' + (act && act.id === m.id ? ' on' : '');
        r.dataset.id = m.id;
        if (editable) r.dataset.kind = m.kind;
        r.innerHTML = `${editable ? '<span class="grip" title="Ziehen zum Verschieben">≡</span>' : '<span class="grip off"></span>'}<button class="mkpick"><i></i><span></span><small></small></button>`;
        const pk = r.querySelector('.mkpick');
        pk.querySelector('i').style.background = m.color;
        pk.querySelector('span').textContent = m === NO_TEAM_MARK ? 'ohne Team' : markLabel(m) || '(ohne Namen)';
        pk.querySelector('small').textContent = m === NO_TEAM_MARK ? 'Team' : `${m.kind === 'team' ? 'Team' : 'Markierung'}${m.hidden ? ' · ausgeblendet' : ''}`;
        pk.addEventListener('click', () => pick(m));
        if (editable) {
          const ed = document.createElement('button');
          ed.className = 'mkedit';
          ed.textContent = '✏️';
          ed.title = 'Ändern';
          ed.addEventListener('click', () => { edit = m; render(); });
          r.appendChild(ed);
        }
        list.appendChild(r);
      };
      for (const m of P.marks) row(m, true);
      row(NO_TEAM_MARK, false);
      box.appendChild(list);
      makeSortable(list, render);
      dlgButton(box, '+ Team', '', () => { const m = addMark('team', true); if (m) render(); });
      dlgButton(box, '+ Markierung', '', () => { const m = addMark('status', true); if (m) render(); });
      dlgButton(box, 'Schließen', 'primary', () => close(true));
    };
    render();
  });
}

map.on('click', (e) => {
  if (vtx) return; // Punkte-Modus: Tipps auf die Karte öffnen nichts
  if (Date.now() - longPressedAt < 1000) return; // gehört zum langen Druck
  if (Date.now() - moveTapAt < 700) return; // gehört zum Tipp „neuen Ort setzen“
  const sm = statusMarkAt(e.containerPoint.x, e.containerPoint.y);
  if (sm) return db.mode === 'el' ? msgDialog(sm.m) : hfMsgDialog(sm.m);
  const sb = tool === 'pan' && badgeAt(e.containerPoint.x, e.containerPoint.y);
  if (sb) { renderSentList(); return openPanel('panel-teams'); } // Plakette: Auftrags-Übersicht
  // Text angetippt: ändern oder löschen
  if (tool === 'pan') {
    const ti = hitItem(P.items, toPx, e.containerPoint.x, e.containerPoint.y, 12);
    if (ti >= 0 && P.items[ti].kind === 'text') return textDialog(ti);
  }
  // v123: B-Ort angetippt: Fenster mit „🧭 Navigieren“
  if (tool === 'pan' && P.meet && !(P.hide || {}).meet) {
    const [mx, my] = toPx(P.meet.lat, P.meet.lon);
    if (Math.hypot(mx - e.containerPoint.x, my - e.containerPoint.y) <= 16) return meetDialog();
  }
  // Linie eines Umrisses angetippt (Einsatzleitung): Name, Zuteilung, Notiz bearbeiten
  if (db.mode === 'el' && tool === 'pan') {
    const pi = poiAt(e.containerPoint.x, e.containerPoint.y);
    if (pi >= 0) {
      const p = P.pois[pi];
      if (isLocked() || !canEdit(P, p)) return toast(`${poiLabel(p)}${p.desc ? ` – ${p.desc}` : ''}${canEdit(P, p) ? '' : ` · ${MSG_VIEW}`}`, 6000);
      editPoi(p);
      return;
    }
    const i = hitItem(P.items, toPx, e.containerPoint.x, e.containerPoint.y, 12);
    if (i >= 0 && !canEdit(P, P.items[i])) { toast(MSG_VIEW, 4000); return; }
    if (i >= 0 && P.items[i].kind === 'track') { renameItem(i); return; }
  }
  // Hundeführer: eigenen Bereich antippen (Name/Notiz ändern, löschen); Zeichnungen/Wege der Einsatzleitung bleiben unberührt
  if (db.mode === 'hf' && tool === 'pan') {
    const i = hitItem(P.items, toPx, e.containerPoint.x, e.containerPoint.y, 12);
    if (i >= 0 && P.items[i].kind === 'track' && !P.items[i].fromEl && !P.items[i].prev) return hfAreaEdit(P.items[i]);
  }
  const parts = [];
  if (allGrids(P).length && !hideGrid()) {
    const c = hitGrid(e.latlng.lat, e.latlng.lng);
    if (c) {
      const v = gridView(P, c.g);
      const m = cellOwner(v, c.c, c.r);
      const st = cellStatus(v, c.c, c.r);
      parts.push(`Feld ${c.label}${cellLabel(c.c, c.r)}${m ? ` – ${markLabel(m)}` : ''}${st ? ` (${st.label})` : ''}${canEditCell(P, c.g.id, `${c.c},${c.r}`) ? '' : ` · ${MSG_VIEW}`}`);
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
    if (res.full) toast(`Speicher voll – „${r.name}“ angehalten. Alte Offline-Karten löschen, dann ▶ lädt weiter`, 9000);
    else toast(r.finished ? `Offline-Karte „${r.name}“ fertig` : `„${r.name}“ angehalten – ▶ lädt weiter`);
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

// 📦 Offline-Paket: ein Tipp lädt Karte (aktuelle Kartenart, so scharf wie der Speicher erlaubt) fürs ganze
// Einsatzgebiet und speichert das Wetter – vor der Anfahrt ins Funkloch. Rettungspunkte sind ohnehin offline.
async function offlinePackage() {
  const b = missionBounds(P);
  if (!b) return toast('Noch kein Einsatzgebiet – erst Raster, Umriss, B-Ort oder Lage-Ort anlegen');
  if (offJob) return toast('Es lädt bereits eine Offline-Karte – bitte warten.');
  const def = layerById(P.layerId);
  const layerIds = def.aerial ? [def.id, ...OVERLAYS.map((o) => o.id)] : [def.id];
  const defs = layerIds.map(offDef).filter(Boolean);
  const s = await offStorage();
  const budget = Math.min(400, s && s.freeMB ? s.freeMB * 0.5 : 400);
  const z = packageZooms(defs, b, { budgetMB: budget });
  const km = (distance(b.north, b.west, b.north, b.east) / 1000) * (distance(b.north, b.west, b.south, b.west) / 1000);
  const rp = rescuePts.filter((q) => q.lat <= b.north && q.lat >= b.south && q.lon >= b.west && q.lon <= b.east).length;
  const short = def.name.replace(/ \(.*/, '');
  const go = await openDlg((box, close) => {
    dlgHead(box, `📦 Offline-Paket „${P.title || 'Einsatz'}“`, [
      `🗺️ Karte „${short}“ für das Einsatzgebiet mit 500 m Rand (≈ ${km.toLocaleString('de-DE', { maximumFractionDigits: 1 })} km²), Stufe ${z.zMin}–${z.zMax} (${ZOOMS[z.zMax] || ''})`,
      `≈ ${fmtMB(z.mb)} · Dauer ${fmtMin(z.minutes)} (je nach Netz)`,
      '🌦️ Wetter wird gespeichert',
      rp ? `🚑 ${rp} Rettungspunkt${rp === 1 ? '' : 'e'} im Gebiet – schon offline` : rescuePts.length ? '🚑 Keine Rettungspunkte im Gebiet' : `🚑 ${db.mode === 'hf' ? NO_RP_HF : 'Noch keine Rettungspunkte importiert (Karte → Rettungspunkte)'}`,
      'Andere Kartenart? Vorher unter „Karte“ umstellen.',
    ].join('\n'));
    dlgButton(box, '📦 Jetzt laden', 'primary', () => close(true));
    dlgButton(box, 'Abbrechen', '', () => close(false));
  });
  if (!go) return;
  const r = {
    id: uid(), name: `📦 ${P.title || 'Einsatz'} – ${short}, Stufe ${z.zMin}–${z.zMax}`, eid: P.eid,
    bounds: b, layerIds, zMin: z.zMin, zMax: z.zMax, done: 0, total: 0, failed: 0, finished: false,
  };
  db.offline.push(r);
  saveNow();
  closePanels();
  runOffline(r);
  try {
    const pt = wxPoint();
    db.wxLast = await fetchWeather(pt.lat, pt.lon);
    saveNow();
    renderWx();
  } catch { /* ohne Netz: Wetter bleibt beim letzten Stand */ }
}
$('layers-package').addEventListener('click', offlinePackage);
$('hfm-package').addEventListener('click', offlinePackage);
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
    : db.mode === 'hf' ? NO_RP_HF : 'Noch keine Rettungspunkte importiert.';
  $('rp-show').checked = !!db.rescueOn;
  $('rp-nearest').disabled = !rescuePts.length;
  $('rp-clear').disabled = !rescuePts.length;
  $('quick-rp').hidden = !rescuePts.length;
}
// gespeicherte Punkte laden – nicht überschreiben, was ein Auftrag-Link inzwischen mitgebracht hat
loadRescue().then((pts) => { rescuePts = mergeRescue(pts, rescuePts); renderRescueInfo(); redraw(); });

let rpMarker = null;
function showNearestRescue() {
  if (!rescuePts.length) return toast(db.mode === 'hf' ? NO_RP_HF : 'Noch keine Rettungspunkte importiert (Karte → Rettungspunkte)');
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
// Gemessener Wind (Kompass) steht im Windprotokoll des Einsatzes (M().wind); angezeigt wird immer zuerst der DWD-Wind.
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
  // immer der Wind vom Wetterdienst; eine Messung vor Ort steht nur darunter (ohne DWD-Daten als Ersatz)
  const meas = lastMeasured();
  const arrow = $('wx-arrow');
  const from = c ? c.from : meas ? meas.from : null;
  arrow.style.visibility = from == null ? 'hidden' : 'visible';
  // Pfeil zeigt, wohin der Wind weht
  if (from != null) arrow.style.transform = `rotate(${from + 180}deg)`;
  arrow.classList.toggle('measured', !c && !!meas);
  const age = c ? Math.round((Date.now() - c.t) / 60000) : 0;
  const measText = meas && `aus ${dirName(meas.from)} (${Math.round(meas.from)}°) · ${STRENGTHS[meas.strength].label}`;
  if (c) {
    $('wx-wind').textContent = dwdText(c);
    $('wx-src').textContent = `DWD ${c.station}${c.km != null ? ` (${Math.round(c.km)} km)` : ''} · ${hhmm(c.t)}${age > 90 ? ` – Stand vor ${Math.round(age / 60)} Std.` : ''}`;
    $('wx-second').hidden = !meas;
    if (meas) $('wx-second').textContent = `Vor Ort gemessen ${hhmm(meas.t)}${meas.by ? ` (${meas.by})` : ''}: ${measText}`;
  } else if (meas) {
    $('wx-wind').textContent = measText;
    $('wx-src').textContent = `kein DWD-Wind – vor Ort gemessen · ${hhmm(meas.t)}`;
    $('wx-second').hidden = true;
  } else {
    $('wx-wind').textContent = 'Noch kein Wind';
    $('wx-src').textContent = navigator.onLine ? 'Wird geladen …' : 'Kein Netz – letzter Stand fehlt';
    $('wx-second').hidden = true;
  }
  $('wx-approach').textContent = from != null ? `Ansatz: ${approach(from)}` : '';
  const more = [];
  if (c && c.temp != null) more.push(`${WX_ICONS[c.icon] || ''} ${Math.round(c.temp)} °C`.trim());
  if (c && c.rain) more.push(`Regen ${c.rain.toLocaleString('de-DE')} mm/h`);
  const pt = wxPoint();
  // v121: nächster Sonnenauf-/-untergang und wann es dunkel bzw. wieder hell wird (bürgerliche Dämmerung), je mit Restzeit
  const now = Date.now();
  for (const e of nextLightEvents(now, pt.lat, pt.lon)) {
    const left = Math.round((e.t - now) / 60000);
    const icon = { Sonnenuntergang: '🌇', Dunkel: '🌑', Hell: '🌄', Sonnenaufgang: '🌅' }[e.name];
    more.push(`${icon} ${e.name === 'Dunkel' ? 'Dunkel ab' : e.name === 'Hell' ? 'Hell ab' : e.name} ${hhmm(e.t)} (noch ${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')} h)`);
  }
  // v121: jeder Eintrag bleibt beim Umbruch zusammen (Handy)
  $('wx-more').replaceChildren(...more.flatMap((t, i) => {
    const sp = document.createElement('span');
    sp.className = 'wx-item';
    sp.textContent = t;
    return i ? [' · ', sp] : [sp];
  }));
  // anderes Suchgebiet / Windpunkt weit weg vom geladenen Ort: neu laden
  if (wx && !wxLoading && navigator.onLine && Date.now() - wxFailAt > 60e3 && distance(wx.lat, wx.lon, pt.lat, pt.lon) > 3000) setTimeout(() => loadWeather(false), 0);
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
let wxFailAt = 0; // letzter Fehlschlag: automatisches Nachladen aus renderWx frühestens 60 s danach
async function loadWeather(manual) {
  if (!(db.wxOn || db.windArrows) || wxLoading) return;
  wxLoading = true;
  $('wx-refresh').disabled = true;
  try {
    const pt = wxPoint();
    const wx = await fetchWeather(pt.lat, pt.lon);
    db.wxLast = wx;
    // Messstationen ringsum (für die Windpfeile)
    if (db.windArrows && db.mode === 'hf') db.wxStations = await fetchStations(pt.lat, pt.lon).catch(() => db.wxStations || null);
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
    wxFailAt = 0;
  } catch {
    wxFailAt = Date.now();
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
    const stale = !db.wxLast || Date.now() - db.wxLast.fetched > 10 * 60e3 || (db.mode === 'hf' && !db.wxStations);
    if (stale) loadWeather(true);
    toast(db.mode === 'hf' ? 'Windpfeile: blau = DWD (Punkt/Suchgebiet und Messstationen), grün = selbst gemessen'
      : 'Wind: blau = DWD in der Mitte jedes Rasters/Umrisses, grün = von den Teams gemessen', 6000);
  }
});
$('quick-arrows').classList.toggle('on', !!db.windArrows);
// Hundeführer: gemessener Wind soll sofort als Pfeil zu sehen sein (Einsatzleitung schaltet „Wind“ selbst ein)
function showWindArrows() {
  if (db.windArrows || db.mode !== 'hf') return;
  db.windArrows = true;
  $('quick-arrows').classList.add('on');
  saveNow();
  redraw();
}
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
  // Wind messen nur die Hundeführer vor Ort; die Einsatzleitung bekommt ihre Messungen per Rückmeldung
  if (db.mode !== 'hf') return toast('Wind messen nur im Hundeführer-Modus – Messungen der Teams kommen mit der Rückmeldung');
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
// Ort der Messung: aktueller Standort; ist keiner da, kurz holen (sonst Kartenmitte)
function windPos() {
  if (lastPos) return Promise.resolve({ lat: lastPos[0], lng: lastPos[1] });
  const center = () => ({ ...map.getCenter(), center: true });
  if (!navigator.geolocation) return Promise.resolve(center());
  toast('Standort wird für die Messung geholt …', 15000);
  return new Promise((res) => navigator.geolocation.getCurrentPosition(
    (p) => res({ lat: p.coords.latitude, lng: p.coords.longitude }),
    () => res(center()),
    { enableHighAccuracy: true, timeout: 15000, maximumAge: 30000 },
  ));
}
document.querySelectorAll('.wm-str button').forEach((b) => b.addEventListener('click', async () => {
  const s = b.dataset.s;
  $('windmeter').hidden = true;
  const from = wmFrom;
  const pos = await windPos();
  (M().wind ||= []).push({ t: Date.now(), from: Math.round(from), strength: s, src: 'gemessen', lat: pos.lat, lon: pos.lng });
  touch();
  $('windmeter').hidden = true;
  // Wetterspalte bleibt, wie sie ist – die Messung erscheint als grüner Pfeil auf der Karte
  showWindArrows();
  saveNow();
  renderWx();
  redraw();
  toast(`Wind gemessen: aus ${dirName(from)}, ${STRENGTHS[s].label}. ${approach(from)}.${pos.center ? ' Kein Standort – an der Kartenmitte gespeichert.' : ''}`, 9000);
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
// opts.keep: Tipp auf den dunklen Hintergrund schließt den Dialog nicht (laufender Vorgang)
// Fenster, die beim Loslassen des Fingers aufgehen: der Klick, den das Handy danach schickt, darf nicht den
// Knopf treffen, der jetzt unter dem Finger liegt (sonst z. B. sofort „Speichern“)
let dlgOpenedAt = 0;
let lastDownAt = 0;
document.addEventListener('pointerdown', () => { lastDownAt = Date.now(); }, true);
$('dlg-box').addEventListener('click', (e) => {
  // nur Klicks ohne eigenes Antippen nach dem Öffnen; .click() aus dem Code geht durch
  if (e.isTrusted && lastDownAt < dlgOpenedAt && Date.now() - dlgOpenedAt < 600) { e.stopPropagation(); e.preventDefault(); }
}, true);
function openDlg(build, opts = {}) {
  if ($('toast-act')) $('toast').hidden = true; // v127: Hinweis mit Knopf („weiterleiten?“) soll keinen Dialog verdecken
  const box = $('dlg-box');
  dlgOpenedAt = Date.now();
  box.innerHTML = '';
  box.dataset.keep = opts.keep ? '1' : '';
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
// Fremdtext (Namen, Meldungstexte aus Links/QR) für dlgButton/wizBtn maskieren – diese setzen innerHTML
const esc = (t) => String(t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
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
  renderHanded();
  applyClosed();
  renderTeamBar();
  renderDeviceName();
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
  const pin = await askPin('🔒 Einsatzleitung', 'PIN eingeben, um in die Einsatzleitung zu wechseln. Die PIN schützt vor versehentlichem Wechsel, nicht die Daten.');
  if (!pin) return false;
  if ((await pinHash(pin)) !== EL_PIN_HASH) { toast('Falsche PIN'); return false; }
  if (recWatch !== null) stopRec();
  db.mode = 'el';
  saveNow();
  closePanels();
  setTool('pan');
  applyMode();
  toast('Einsatzleitung');
  return true;
}
// Mehr -> Hundeführer-Modus: erst nachfragen, zurück geht nur mit der EL-PIN
$('mode-hf').addEventListener('click', async () => {
  const go = await openDlg((box, close) => {
    dlgHead(box, 'In den Hundeführer-Modus wechseln?', 'Zurück zur Einsatzleitung geht nur mit der EL-PIN. Die PIN schützt vor versehentlichem Wechsel, nicht die Daten.');
    dlgButton(box, '🐕 Wechseln', 'primary', () => close(true));
    dlgButton(box, 'Abbrechen', '', () => close(false));
  });
  if (go) toHfMode();
});
$('hfm-el').addEventListener('click', toElMode);

// ---- Hundeführer-Ansicht ----
// Das Wetter-Fenster liegt im HF-Modus unter der Auftragskarte: deren Unterkante als CSS-Variable merken
new ResizeObserver(() => {
  const e = $('hfinfo');
  document.documentElement.style.setProperty('--hfi-b', e.hidden ? '52px' : `${Math.round(e.getBoundingClientRect().bottom)}px`);
}).observe($('hfinfo'));
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
    ? [h.closed && `✅ abgeschlossen ${hhmm(h.closed)} – bitte zurückgeben`, h.prev && `🐕 Vorher: ${h.prev}`, h.hint && `⚠️ ${h.hint}`, `Auftrag ${hhmm(h.received)}`, rec ? `gelaufen ${fmtKm(rec)}` : ''].filter(Boolean).join(' · ')
    : 'QR-Code der Einsatzleitung scannen: Knopf „📷 Scannen“ rechts (oder Menü → „📷 Auftrag scannen“).';
  $('hfinfo').classList.toggle('min', !!db.hfInfoMin);
  $('hfinfo').classList.toggle('closed', !!(h && h.closed));
  const m = $('hfm-info');
  m.textContent = '';
  if (h) {
    const lines = [P.title.endsWith(` – ${h.team}`) ? P.title : `${h.team} – ${P.title}`, `Auftrag erhalten ${hhmm(h.received)}`];
    if (h.closed) lines.push(`✅ Auftrag abgeschlossen ${hhmm(h.closed)} – bitte zurückgeben`);
    if (h.prev) lines.push(`Vorher abgesucht: ${h.prev} (graue Wege und Markierungen)`);
    if (h.hint) lines.push(`Hinweis: ${h.hint}`);
    if (P.mission.person) lines.push(`Vermisste Person: ${P.mission.person}`);
    if (P.meet) lines.push(`B-Ort: ${P.meet.text || 'gesetzt'}`);
    const el = P.contacts.find((c) => c.role === 'Einsatzleitung');
    if (el) lines.push(`Einsatzleitung: ${[el.name, el.call && `📻 ${el.call}`, el.phone && `📞 ${el.phone}`].filter(Boolean).join(' · ')}`);
    m.textContent = lines.join('\n');
    m.style.whiteSpace = 'pre-line';
  } else m.textContent = 'Noch kein Auftrag. QR-Code der Einsatzleitung scannen: Knopf „📷 Scannen“ rechts (oder Menü → „📷 Auftrag scannen“).';
  $('hfm-meet').disabled = !P.meet;
  const hasArea = !!h && !!areaBounds(P);
  $('hfm-area').disabled = !hasArea;
  $('hfi-area').hidden = !hasArea;
  $('hfm-nav').disabled = !h; // v123: auch ohne Ziel gibt es die Kartenmitte
  $('hfm-contacts').hidden = !P.contacts.length;
  $('hfm-contacts').textContent = `📞 Kontakte (${P.contacts.length})`;
  renderHfMsgBtn();
}
$('hfinfo').addEventListener('click', () => { db.hfInfoMin = !db.hfInfoMin; save(); renderHfInfo(); });
$('btn-hfmenu').addEventListener('click', () => { renderHfInfo(); openPanel('panel-hfmenu'); });
$('hfm-rp').addEventListener('click', showNearestRescue);
$('hfm-contacts').addEventListener('click', () => {
  const box = $('hfc-list');
  box.innerHTML = '';
  for (const c of P.contacts) { const row = document.createElement('div'); row.className = 'ctrow'; row.appendChild(contactInfo(c)); box.appendChild(row); }
  openPanel('panel-hfcontacts');
});
// direkt öffnen (openPanel schließt das Menü; closePanels davor ginge im Verlauf zurück und schlösse das neue Fenster gleich wieder)
$('hfm-notes').addEventListener('click', () => $('btn-notes').click());
$('hfm-projects').addEventListener('click', () => $('btn-projects').click());
// v116: 🎯 Mein Gebiet – alle Gebiete des Auftrags (Felder des Teams, Umrisse) ins Bild
function showMyArea() {
  const b = areaBounds(P);
  if (!b) return toast('Im Auftrag ist kein Gebiet eingetragen');
  closePanels();
  map.fitBounds(b, { paddingTopLeft: [30, 120], paddingBottomRight: [30, 90], maxZoom: 17 });
}
$('hfm-area').addEventListener('click', showMyArea);
$('hfi-area').addEventListener('click', (e) => { e.stopPropagation(); showMyArea(); }); // der Tipp auf die Karte klappt sonst die Auftragskarte zu
// Externen Link öffnen: in der Android-App über die WebView (die reicht https-Adressen an die Maps-App weiter), sonst neuer Tab
function openLink(url) {
  if (bridge) location.href = url;
  else window.open(url, '_blank', 'noopener');
}
// v123: B-Ort angetippt (Werkzeug „Bewegen“)
function meetDialog() {
  const m = P.meet;
  if (!m) return;
  openDlg((box, close) => {
    dlgHead(box, `🎯 ${m.text || 'B-Ort'}`, `${m.lat.toFixed(5)}, ${m.lon.toFixed(5)}${P.showUtm ? ` · ${formatMgrs(m.lat, m.lon)}` : ''}`);
    dlgNavButton(box, close, null, m.text && m.text !== 'B-Ort' ? `B-Ort (${m.text})` : 'B-Ort', m.lat, m.lon);
    dlgButton(box, 'Schließen', 'primary', () => close(null));
  });
}
// v123: Auswahl Auto / zu Fuß für ein Ziel; die Route öffnet sich in Google Maps bzw. der Karten-App (Start ist der aktuelle Standort)
// v130.2: zusätzlich „🧭 Kompass (Luftlinie)“ – ohne Straßen/Internet, direkt zum Punkt
function navChooser(label, lat, lon) {
  return openDlg((box, close) => {
    dlgHead(box, `🧭 Navigieren zu ${label}`, `${Number(lat).toFixed(5)}, ${Number(lon).toFixed(5)}`);
    box.querySelector('h2').style.overflowWrap = 'anywhere';
    dlgButton(box, '🚗 Auto', 'primary', () => { close(true); openLink(navUrl(lat, lon, 'driving')); });
    dlgButton(box, '🚶 Zu Fuß', '', () => { close(true); openLink(navUrl(lat, lon, 'walking')); });
    dlgButton(box, '🧭 Kompass (Luftlinie)', '', () => { close(true); openCompassNav(label, lat, lon); });
    dlgButton(box, 'Abbrechen', '', () => close(false));
  });
}
// v130.2: Kompass-Navigation (Luftlinie) – Entfernung und Richtung zum Ziel, live aus GPS und (falls vorhanden)
// dem Kompass des Handys; ohne Kompass zeigt der Pfeil die Gradzahl ab Norden (Handy mit der Oberkante nach Norden halten).
let navWatchId = null;
let navOriOn = false;
let navFallbackTimer = null;
function navOri(e) {
  let h = null;
  if (typeof e.webkitCompassHeading === 'number' && !Number.isNaN(e.webkitCompassHeading)) h = e.webkitCompassHeading;
  else if ((e.absolute || e.type === 'deviceorientationabsolute') && e.alpha != null) h = 360 - e.alpha;
  if (h == null) return;
  const ang = (screen.orientation && screen.orientation.angle) || window.orientation || 0;
  navHeading = (((h + ang) % 360) + 360) % 360;
  clearTimeout(navFallbackTimer);
  navUpdateNav();
}
let navHeading = null;
let navTarget = null; // { label, lat, lon }
function navStop() {
  if (navWatchId !== null) { navigator.geolocation.clearWatch(navWatchId); navWatchId = null; }
  if (navOriOn) { window.removeEventListener('deviceorientationabsolute', navOri); window.removeEventListener('deviceorientation', navOri); navOriOn = false; }
  clearTimeout(navFallbackTimer);
  navTarget = null;
  navHeading = null;
}
function navUpdateNav() {
  if (!navTarget) return;
  const from = lastPos || (map ? [map.getCenter().lat, map.getCenter().lng] : null);
  if (!from) { $('nav-read').textContent = 'Standort wird gesucht …'; return; }
  const m = distance(from[0], from[1], navTarget.lat, navTarget.lon);
  const deg = bearingDeg(from[0], from[1], navTarget.lat, navTarget.lon);
  $('nav-dist').textContent = fmtDist(m);
  $('nav-needle').style.transform = `rotate(${navNeedleDeg(deg, navHeading)}deg)`;
  $('nav-read').textContent = navHeading == null
    ? `Richtung ${compass(deg)} (${Math.round(deg)}°) ab Norden – ohne Kompass: Handy-Oberkante nach Norden halten`
    : `Richtung ${compass(deg)} (${Math.round(deg)}°)${!lastPos ? ' · Standort: Kartenmitte (kein GPS)' : ''}`;
}
async function openCompassNav(label, lat, lon) {
  navStop();
  navTarget = { label, lat, lon };
  $('nav-title').textContent = `🧭 Kompass zu ${label}`;
  $('navmeter').hidden = false;
  $('nav-dist').textContent = '–';
  $('nav-read').textContent = 'Standort wird gesucht …';
  $('nav-needle').style.transform = 'rotate(0deg)';
  navUpdateNav();
  if (navigator.geolocation) {
    navWatchId = navigator.geolocation.watchPosition((pos) => {
      lastPos = [pos.coords.latitude, pos.coords.longitude];
      navUpdateNav();
    }, () => {}, { enableHighAccuracy: true, maximumAge: 2000 });
  }
  if (window.DeviceOrientationEvent && typeof DeviceOrientationEvent.requestPermission === 'function') {
    try { await DeviceOrientationEvent.requestPermission(); } catch { /* dann ohne Kompass */ }
  }
  if (!navTarget) return; // Fenster inzwischen geschlossen
  window.addEventListener('deviceorientationabsolute', navOri);
  window.addEventListener('deviceorientation', navOri);
  navOriOn = true;
  navFallbackTimer = setTimeout(() => { if (navHeading == null) navUpdateNav(); }, 1500);
}
$('nav-cancel').addEventListener('click', () => { navStop(); $('navmeter').hidden = true; });
// v123: Knopf „🧭 Navigieren“ in Objekt-Fenstern (nur mit gültigem Ziel)
// (schließt das Fenster wie „Abbrechen“ mit cancelVal und öffnet dann die Auswahl)
function dlgNavButton(box, close, cancelVal, label, lat, lon) {
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return;
  dlgButton(box, '🧭 Navigieren', '', () => { close(cancelVal); navChooser(label, lat, lon); });
}
// v123: Zielliste (HF: Parkplatz, B-Ort, Gebiet; EL: alles) mit „⌖ Kartenmitte“ als letztem Eintrag; Antippen öffnet die Auswahl Auto / zu Fuß
function navList(title, list) {
  closePanels();
  openDlg((box, close) => {
    dlgHead(box, title, 'Wohin soll die Route gehen? Sie öffnet sich in der Karten-App.');
    const l = document.createElement('div');
    l.className = 'dlg-btns';
    box.appendChild(l);
    for (const t of list) {
      dlgButton(l, `${t.icon} ${esc(t.label)}${t.sub ? ` <small>${esc(t.sub)}</small>` : ''}`, '', () => { close(true); navChooser(t.label, t.lat, t.lon); });
    }
    dlgButton(l, '⌖ Kartenmitte <small>(Karte vorher aufs Ziel schieben)</small>', '', () => {
      close(true);
      const c = map.getCenter();
      navChooser('Kartenmitte', c.lat, c.lng);
    });
    dlgButton(box, 'Abbrechen', '', () => close(false));
  });
}
// v116: 🧭 Navigation – Parkplatz, B-Ort bzw. Treffpunkt, Gebiet (Mitte) als Ziel in Google Maps
$('hfm-nav').addEventListener('click', () => navList('🧭 Navigation', navTargets(P)));
// v123: Einsatzleitung: Panel „Mehr“ -> Navigation zu …
$('more-nav').addEventListener('click', () => navList('🧭 Navigation zu …', navTargetsAll(P)));
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
let recSeg = null;
let recLock = null;
let recTimer = null;
// v118: Jeder GPS-Punkt ruft nicht mehr save() auf (JSON.stringify des ganzen Speichers). Stattdessen: das laufende Wegstück
// höchstens alle 5 s in einen kleinen eigenen Schlüssel, der Gesamtspeicher höchstens alle 30 s (sowie pagehide/hidden/Stopp).
const REC_BACKUP_MS = 5000;
const REC_FULL_MS = 30000;
let recKey = null;
let recBackupAt = 0;
let recFullAt = 0;
function recPersist() {
  if (locked || !recSeg || !recKey) return;
  const now = Date.now();
  if (now - recBackupAt >= REC_BACKUP_MS) {
    recBackupAt = now;
    try { localStorage.setItem(recKey, JSON.stringify({ t0: recSeg.t0, pts: recSeg.pts })); } catch { /* Speicher voll */ }
  }
  if (now - recFullAt >= REC_FULL_MS) { recFullAt = now; saveNow(); }
}
function ensureHf() {
  if (!P.hf) P.hf = { id: uid(), team: 'Ich', hint: '', received: Date.now(), grids: allGrids(P).map((g) => g.id), track: [] };
}
// resume: nach dem Schließen der App weiter aufzeichnen – neues Wegstück erst bei genauem Standort
const REC_ACC = 40; // m, ungenauere Punkte werden verworfen
const RESUME_ACC = 20; // m, ab dieser Genauigkeit geht es nach dem Wiederöffnen weiter
async function startRec(resume = false) {
  if (!navigator.geolocation) return toast('Standort wird nicht unterstützt');
  ensureHf();
  recSeg = null;
  recKey = `${TRACK_KEY}${P.id}`;
  recBackupAt = 0;
  recFullAt = Date.now();
  if (!resume) {
    recSeg = { t0: Date.now(), pts: [] };
    P.hf.track.push(recSeg);
  }
  P.hf.recOn = true;
  saveNow();
  startGps(false);
  recWatch = navigator.geolocation.watchPosition((pos) => {
    if (pos.coords.accuracy > (recSeg ? REC_ACC : RESUME_ACC)) return;
    if (!recSeg) {
      recSeg = { t0: Date.now(), pts: [] };
      P.hf.track.push(recSeg);
      updateRecBtn();
      toast('Standort genau – Weg wird weiter aufgezeichnet');
    }
    const pt = [Math.round(pos.coords.latitude * 1e6) / 1e6, Math.round(pos.coords.longitude * 1e6) / 1e6];
    const last = recSeg.pts[recSeg.pts.length - 1];
    if (last && distance(last[0], last[1], pt[0], pt[1]) < 5) return;
    recSeg.pts.push(pt);
    recPersist();
    redraw();
  }, (err) => toast('GPS: ' + (err.message || 'kein GPS-Empfang')), { enableHighAccuracy: true, maximumAge: 0 });
  try { recLock = await navigator.wakeLock.request('screen'); } catch { if (bridge && bridge.keepScreenOn) bridge.keepScreenOn(true); }
  recTimer = setInterval(updateRecBtn, 5000);
  updateRecBtn();
  toast(resume ? 'Aufzeichnung läuft weiter, sobald der Standort genau ist (⏳)' : 'Weg wird aufgezeichnet – Bildschirm bleibt an. Nicht sperren!', 6000);
}
function stopRec() {
  if (locked) return;
  if (recWatch !== null) navigator.geolocation.clearWatch(recWatch);
  recWatch = null;
  if (recLock) recLock.release().catch(() => {});
  recLock = null;
  if (bridge && bridge.keepScreenOn) bridge.keepScreenOn(false);
  clearInterval(recTimer);
  if (recSeg && recSeg.pts.length < 2) P.hf.track = P.hf.track.filter((sg) => sg !== recSeg);
  recSeg = null;
  if (P.hf) P.hf.recOn = false;
  if (saveNow() && recKey) { try { localStorage.removeItem(recKey); } catch { /* egal */ } } // Sicherung erst weg, wenn der Gesamtspeicher steht
  recKey = null;
  updateRecBtn();
  redraw();
}
function updateRecBtn() {
  const on = recWatch !== null;
  $('hf-rec').classList.toggle('on', on);
  const wait = on && !recSeg;
  $('hf-rec').querySelector('span').textContent = wait ? '⏳' : on ? '⏹' : '⏺';
  $('hf-rec').querySelector('b').textContent = wait ? 'wartet auf GPS …' : on
    ? `${fmtKm(pathLen(recSeg.pts))} · ${Math.round((Date.now() - recSeg.t0) / 60000)} min` : 'Weg';
  renderHfInfo();
}
document.addEventListener('visibilitychange', async () => {
  if (!document.hidden && recWatch !== null && !recLock) {
    try { recLock = await navigator.wakeLock.request('screen'); } catch { /* egal */ }
  }
});
$('hf-rec').addEventListener('click', () => (recWatch !== null ? stopRec() : startRec()));

// Markieren: Art wählen, Position = GPS-Standort oder auf der Karte angetippt
const HF_MARKS = [['⚠️', 'Anzeige'], ['✅', 'Fund'], ['🐾', 'Spur'], ['🎒', 'Gegenstand'], ['❗', 'Gefahr'], ['📝', 'Hinweis']];
// Mit GPS: Punkt am Standort. Ohne GPS: fragen – auf der Karte antippen oder Standort einschalten
$('hf-mark').addEventListener('click', () => {
  if (lastPos) return hfMarkDialog({ lat: lastPos[0], lon: lastPos[1] }, 'Position: dein GPS-Standort.');
  openDlg((box, close) => {
    dlgHead(box, '📍 Markieren', 'Der Standort (GPS) ist aus. Wo soll der Punkt hin?');
    const list = document.createElement('div');
    list.className = 'dlg-btns';
    box.appendChild(list);
    dlgButton(list, '👆 Punkt auf der Karte antippen', '', () => {
      close(true);
      setTool('hfmarkpt');
      toast('Auf die Karte tippen: dort wird der Punkt gesetzt', 5000);
    });
    const gpsBtn = dlgButton(list, '🛰️ Standort einschalten', 'primary', () => {
      if (!navigator.geolocation) return toast('Standort wird nicht unterstützt');
      startGps(false);
      gpsBtn.disabled = true;
      gpsBtn.textContent = '🛰️ Standort wird gesucht …';
      const t0 = Date.now();
      const wait = setInterval(() => {
        if ($('dlg').hidden) return clearInterval(wait); // abgebrochen
        if (lastPos) {
          clearInterval(wait);
          close(true);
          hfMarkDialog({ lat: lastPos[0], lon: lastPos[1] }, 'Position: dein GPS-Standort.');
        } else if (Date.now() - t0 > 60e3) {
          clearInterval(wait);
          gpsBtn.disabled = false;
          gpsBtn.textContent = '🛰️ Nochmal versuchen';
          toast('Kein Standort gefunden – ggf. Punkt auf der Karte antippen');
        }
      }, 500);
    });
    dlgButton(box, 'Abbrechen', '', () => close(false));
  });
});
async function fundLive(text, pos) {
  const res = await sendStatus({ s: 'ort', cat: 'fund', txt: text, pos: { lat: pos.lat, lon: pos.lon }, quiet: true });
  if (res === 'rejected') return;
  if (res === 'queued') toast('✅ Fund markiert – wartet auf Netz, wird automatisch an die Einsatzleitung gemeldet', 6000);
  else if (res === 'saved') toast('✅ Fund markiert – geht mit der nächsten QR-Rückmeldung an die Einsatzleitung', 6000);
  else toast('✅ Fund markiert und an die Einsatzleitung gemeldet', 5000);
}
function hfMarkDialog(pos, where) {
  openDlg((box, close) => {
    dlgHead(box, '📍 Markieren', where);
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
        P.items.push({ kind: 'text', color: hfColor(), lat: pos.lat, lon: pos.lon, text, t: Date.now(), marker: true }); // v130.2: immer sichtbar, großes Symbol
        changed();
        close(true);
        // v116: „✅ Fund“ geht zusätzlich sofort live an die Einsatzleitung (wie „📍 Standort melden → 🟢 Person gefunden“).
        // Löschen der Markierung nimmt die Meldung nicht zurück – das geht über „🗂 Meine Meldungen“.
        if (label === 'Fund' && Array.isArray(P.hf.log)) return fundLive(text.replace(`${ico} `, ''), pos); // ohne Symbol: PDF-Schrift kann kein Emoji
        toast(`${ico} ${label} markiert`);
      });
    }
    dlgButton(box, 'Abbrechen', '', () => close(false));
  });
}

// Bereich umkreisen: ein Zug mit dem Finger, wird ein geschlossener Umriss (geht mit der Rückmeldung an die EL, dort im GPX)
$('hf-draw').addEventListener('click', () => {
  if (tool === 'hfdraw') return setTool('pan');
  setTool('hfdraw');
  toast('Mit dem Finger einmal um den Bereich herum malen', 5000);
});
function hfAreaDone(raw) {
  // Punkte ausdünnen (ca. alle 3 m) – genug für Garmin, klein genug für den QR-Code
  const pts = [];
  for (const q of raw) {
    const l = pts[pts.length - 1];
    if (!l || distance(l[0], l[1], q[0], q[1]) >= 3) pts.push([Math.round(q[0] * 1e6) / 1e6, Math.round(q[1] * 1e6) / 1e6]);
  }
  if (pts.length < 3 || pathLen(pts) < 30) return toast('Zu klein – nochmal „✏️ Bereich“ und größer umkreisen');
  const n = P.items.filter((it) => it.kind === 'track' && /^Bereich \d+$/.test(it.name || '')).length + 1;
  openDlg((box, close) => {
    dlgHead(box, '✏️ Bereich', 'Name und Notiz erscheinen so bei der Einsatzleitung und auf dem Garmin.');
    const name = document.createElement('input');
    name.type = 'text';
    name.value = `Bereich ${n}`;
    const note = document.createElement('textarea');
    note.rows = 3;
    note.placeholder = 'Notiz (optional), z. B. Hund zeigt hier Interesse, dichtes Unterholz …';
    box.append(name, note);
    dlgButton(box, '💾 Speichern', 'primary', () => {
      ensureHf();
      const it = { kind: 'track', name: name.value.trim() || `Bereich ${n}`, color: hfColor(), w: 4, pts, t: Date.now() };
      if (note.value.trim()) it.note = note.value.trim();
      P.items.push(it);
      changed();
      close(true);
      toast('Bereich gespeichert – geht mit „Zurückgeben“ an die Einsatzleitung');
    });
    dlgButton(box, 'Verwerfen', '', () => { close(false); redraw(); });
    name.focus();
    name.select();
  });
}

// v103: eigenen Bereich (Umkreisung) ändern oder löschen
async function hfAreaEdit(it) {
  const r = await openDlg((box, close) => {
    dlgHead(box, `✏️ ${it.name || 'Bereich'}`, 'Name und Notiz ändern oder den Bereich löschen.');
    const name = document.createElement('input');
    name.type = 'text';
    name.id = 'area-name';
    name.value = it.name || '';
    const note = document.createElement('textarea');
    note.id = 'area-note';
    note.rows = 3;
    note.value = it.note || '';
    note.placeholder = 'Notiz (optional)';
    box.append(name, note);
    dlgButton(box, '💾 Speichern', 'primary', () => close({ name: name.value.trim(), note: note.value.trim() }));
    dlgButton(box, '✋ Punkte bearbeiten', '', () => close({ vtx: true }));
    dlgButton(box, '🗑 Löschen', 'urgent', () => close({ del: true }));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!r || !P.items.includes(it)) return;
  if (r.vtx) return startVertex(it);
  if (r.del) {
    const ok = await openDlg((box, close) => {
      dlgHead(box, '🗑 Bereich löschen?', `„${it.name || 'Bereich'}“ wird gelöscht und geht nicht mehr an die Einsatzleitung.`);
      dlgButton(box, 'Löschen', 'urgent', () => close(true));
      dlgButton(box, 'Abbrechen', 'primary', () => close(false));
    });
    if (!ok || !P.items.includes(it)) return;
    snapshot();
    P.items.splice(P.items.indexOf(it), 1);
    changed();
    return toast('Bereich gelöscht (↶ macht es rückgängig)', 4000);
  }
  snapshot();
  if (r.name) it.name = r.name;
  if (r.note) it.note = r.note; else delete it.note;
  changed();
}

// Feld abgesucht: antippen schaltet durch
$('hf-field').addEventListener('click', () => {
  if (!allGrids(P).length) return toast('Im Auftrag ist kein Raster');
  setTool(tool === 'hffield' ? 'pan' : 'hffield');
});
function hfFieldTap(ll) {
  if (hideGrid()) return;
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
const scriptLoads = {}; // src -> Promise: gleichzeitige Aufrufe warten auf dasselbe Laden
function loadScript(src) {
  return scriptLoads[src] ||= new Promise((resolve, reject) => {
    const el = document.createElement('script');
    el.src = src;
    el.onload = resolve;
    el.onerror = () => { el.remove(); delete scriptLoads[src]; reject(new Error(`${src} nicht ladbar`)); };
    document.head.appendChild(el);
  });
}
const QR_MAX = 1800; // Zeichen, die eine Handy-Kamera vom Bildschirm noch sicher liest
const QR_INTERVAL = 1500; // v130.13: etwas langsamer als vorher (900ms) – mehr Zeit zum Fokussieren/Lesen
let qrCycle = null;
let qrParts = null; // { svgs, i, paused } – für Pause/◀/▶ bei mehrteiligen Codes
function qrSvg(data) {
  const q = window.qrcode(0, data.length < 2000 ? 'M' : 'L');
  q.addData(data, 'Byte');
  q.make();
  return q.createSvgTag({ cellSize: 4, margin: 4, scalable: true });
}
function qrShowPart() {
  const { svgs, i } = qrParts;
  $('qr-code').innerHTML = `${svgs[i]}<b class="qr-part">Teil ${i + 1} von ${svgs.length}</b>`;
}
function qrPause(paused) {
  qrParts.paused = paused;
  $('qr-pause').textContent = paused ? '▶️ Weiter' : '⏸️ Pause';
}
// parts: mehrere QR-Inhalte, die im Wechsel angezeigt werden (Scanner in der App sammelt sie)
async function showQr(link, title, text, parts = null) {
  await loadScript('lib/qrcode.js');
  $('qr-title').textContent = title;
  $('qr-text').textContent = text;
  const box = $('qr-code');
  clearInterval(qrCycle);
  qrCycle = null;
  qrParts = null;
  $('qr-nav').hidden = true;
  if (parts && parts.length > 1) {
    qrParts = { svgs: parts.map(qrSvg), i: 0, paused: false };
    qrShowPart();
    qrPause(false);
    qrCycle = setInterval(() => { if (!qrParts.paused) { qrParts.i = (qrParts.i + 1) % qrParts.svgs.length; qrShowPart(); } }, QR_INTERVAL);
    $('qr-nav').hidden = false;
  } else if (link.length > QR_MAX) {
    box.innerHTML = '<p class="small">Zu viele Daten für einen QR-Code – bitte über „Teilen“ (WhatsApp, SMS …) senden.</p>';
  } else {
    box.innerHTML = qrSvg(link);
  }
  $('qrbox').dataset.link = link;
  $('qrbox').hidden = false;
}
// v130.13: mehrteiliger Code manuell steuern – praktisch, wenn die Kamera des Scanners einen Teil immer wieder verpasst
$('qr-pause').addEventListener('click', () => qrPause(!qrParts.paused));
$('qr-prev').addEventListener('click', () => { qrPause(true); qrParts.i = (qrParts.i - 1 + qrParts.svgs.length) % qrParts.svgs.length; qrShowPart(); });
$('qr-next').addEventListener('click', () => { qrPause(true); qrParts.i = (qrParts.i + 1) % qrParts.svgs.length; qrShowPart(); });
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
const qrDone = [];
$('qr-close').addEventListener('click', () => {
  clearInterval(qrCycle);
  $('qrbox').hidden = true;
  while (qrDone.length) qrDone.shift()();
});
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
async function showBack() {
  const link = await resultLink();
  const n = P.hf.track.reduce((a, sg) => a + pathLen(sg.pts), 0);
  showQr(link, `📤 Rückmeldung ${P.hf.team}`, `Die Einsatzleitung scannt diesen Code (Teams → „Rückmeldung scannen“). Gelaufen: ${fmtKm(n)}. Mehrfach zurückgeben schadet nicht – es kommt nichts doppelt an.`);
}
$('hf-back').addEventListener('click', showBack);

// ---- Einsatzleitung: Auftrag zusammenstellen ----
let sendPicked = {}; // gridId -> Set("c,r")
let sendCache = null;
function renderSend() {
  const teams = P.marks.filter((m) => m.kind === 'team');
  const sel = $('send-team');
  const prev = sel.options.length ? sel.value : null; // beim ersten Öffnen: erstes Team
  sel.innerHTML = '';
  for (const t of teams) sel.add(new Option(`${typeIcon(t)} ${t.label}${t.dog ? ` – ${t.dog}` : ''}`, t.id));
  sel.add(new Option('ohne Team (nur Gebiet)', ''));
  if (teams.some((t) => t.id === prev) || prev === '') sel.value = prev;
  const box = $('send-grids');
  // schon gezeigte Häkchen bleiben, wie sie sind (auch abgewählt); Vorauswahl nur für neue Einträge
  const was = (el) => Object.fromEntries([...el.querySelectorAll('input')].map((i) => [i.value, i.checked]));
  const checked = was(box);
  box.innerHTML = '';
  for (const g of allGrids(P)) {
    const n = sel.value ? Object.values(g.fills).filter((id) => id === sel.value).length : 0;
    const l = document.createElement('label');
    l.className = 'check';
    l.innerHTML = '<input type="checkbox"><span></span>';
    l.firstChild.value = g.id;
    l.firstChild.checked = g.id in checked ? checked[g.id] : n > 0; // Raster mit Feldern des Teams vorangekreuzt, sonst nur auf Wunsch
    l.lastChild.textContent = `${gridLabel(P, g)}${sel.value ? ` (${n} Felder des Teams)` : ''}`;
    box.appendChild(l);
  }
  if (!allGrids(P).length) box.textContent = 'Kein Raster – es werden nur Umrisse und Zeichnungen verschickt.';
  syncSendFields();
  const ib = $('send-items');
  const ichecked = was(ib);
  ib.innerHTML = '';
  const seen = new Set();
  // vorausgewählt: die dem Team zugeteilten Umrisse (ohne Team: die nicht zugeteilten geschlossenen)
  // und Texte/Zeichnungen, die darin oder in den Feldern des Teams liegen
  const team = $('send-team').value;
  const pre = new Set(P.items.filter((it) => it.kind === 'track' && (team ? it.to === team : !it.to && !it.open)));
  for (const it of itemsWithin(P, pre, team ? (g, k) => g.fills[k] === team : null)) pre.add(it);
  // angehakte Raster: alles darin
  const gids = [...$('send-grids').querySelectorAll('input:checked')].map((x) => x.value);
  for (const it of itemsInGrids(P, gids, team)) pre.add(it);
  P.items.forEach((it, i) => {
    if (it.resultKey) return; // Rückmeldungen der Hundeführer nicht zurückschicken
    const label = it.kind === 'text' ? `Text: ${it.text}` : it.name || (it.kind === 'track' ? 'Umriss' : 'Zeichnung');
    if (it.group && seen.has(it.group)) return;
    if (it.group) seen.add(it.group);
    const l = document.createElement('label');
    l.className = 'check';
    l.innerHTML = '<input type="checkbox"><span></span>';
    l.firstChild.value = String(i);
    l.firstChild.checked = String(i) in ichecked ? ichecked[String(i)] : pre.has(it);
    l.lastChild.textContent = label;
    ib.appendChild(l);
  });
  if (!ib.children.length) ib.textContent = 'Keine.';
  renderPrev();
  $('send-meet').parentElement.hidden = !P.meet;
  // Lage-Orte: alle vorausgewählt (Verpflegung, ELW … helfen dem Hundeführer), einzeln abwählbar
  const pb = $('send-pois');
  const poff = new Set([...pb.querySelectorAll('input:not(:checked)')].map((i) => i.value));
  pb.innerHTML = '';
  for (const x of sortPois(P.pois)) {
    const l = document.createElement('label');
    l.className = 'check';
    l.innerHTML = '<input type="checkbox"><span></span>';
    l.firstChild.value = x.id;
    l.firstChild.checked = !poff.has(x.id);
    l.lastChild.textContent = poiLabel(x);
    pb.appendChild(l);
  }
  pb.hidden = !P.pois.length;
  $('send-pois-label').hidden = !P.pois.length;
  $('send-person').parentElement.hidden = !P.mission.person.trim();
  // Kontakte: alle vorausgewählt, einzeln abwählbar; Einsatzleitung immer dabei
  const cts = sendContactsAll();
  const cb = $('send-ct-list');
  const off = new Set([...cb.querySelectorAll('input:not(:checked)')].map((i) => i.value));
  cb.innerHTML = '';
  for (const c of cts) {
    const l = document.createElement('label');
    l.className = 'check';
    l.innerHTML = '<input type="checkbox"><span></span>';
    l.firstChild.value = c.id;
    l.firstChild.checked = !off.has(c.id);
    l.firstChild.disabled = c.id === 'lead';
    l.lastChild.textContent = [c.name, c.role, c.phone].filter(Boolean).join(' · ');
    cb.appendChild(l);
  }
  $('send-contacts').parentElement.hidden = !cts.length;
  $('send-contacts-label').textContent = `Kontakte mitgeben (${cts.length})`;
  cb.hidden = !cts.length || !$('send-contacts').checked;
  const picked = Object.values(sendPicked).reduce((a, x) => a + x.size, 0);
  $('send-pickinfo').textContent = sendFields() === 'pick' ? `${picked} Felder angetippt.` : '';
  sendCache = null;
  updateSendSize();
}
// v101: Wege/Markierungen früherer Teams im gewählten Gebiet (Rückmeldungen): eigene Gruppe, vorausgewählt, abwählbar
let sendPrev = []; // zuletzt gezeigte Gruppen (predecessorGroups)
function prevSel() {
  const items = [...$('send-items').querySelectorAll('input:checked')].map((i) => P.items[Number(i.value)]).filter(Boolean);
  return {
    teamId: $('send-team').value, gridIds: [...$('send-grids').querySelectorAll('input:checked')].map((i) => i.value), fields: sendFields(),
    picked: Object.fromEntries(Object.entries(sendPicked).map(([k, v]) => [k, [...v]])), areaItems: items,
  };
}
function renderPrev() {
  const box = $('send-prev');
  const off = new Set([...box.querySelectorAll('input:not(:checked)')].map((i) => i.value)); // abgewählt bleibt abgewählt
  box.innerHTML = '';
  sendPrev = predecessorGroups(P, prevSel(), allMsgs());
  for (const g of sendPrev) {
    const l = document.createElement('label');
    l.className = 'check';
    l.innerHTML = '<input type="checkbox"><span></span>';
    l.firstChild.value = g.a;
    l.firstChild.checked = !off.has(g.a);
    l.lastChild.textContent = predecessorText(g);
    box.appendChild(l);
  }
  box.hidden = !sendPrev.length;
  $('send-prev-label').hidden = !sendPrev.length;
}
const sendContactsAll = () => [leadContact(), ...P.contacts].filter(Boolean);
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
    itemIdx: idx, meet: $('send-meet').checked && !!P.meet, rescue,
    prev: sendPrev.filter((g) => $('send-prev').querySelector(`input[value="${g.a}"]:checked`))
      .map((g) => ({ team: g.team, pct: g.pct, itemIdx: g.items.map((it) => P.items.indexOf(it)).filter((i) => i >= 0) })),
    poiIds: [...$('send-pois').querySelectorAll('input:checked')].map((i) => i.value), hint: $('send-hint').value.trim(), person: $('send-person').checked,
    liveUrl: db.statusUrl || (P.live && P.live.url) || STATUS_URL, // eigene Einstellung, sonst Server des Einsatzes, sonst Standard
    contacts: $('send-contacts').checked
      ? sendContactsAll().filter((c) => c.id === 'lead' || !$('send-ct-list').querySelector(`input[value="${c.id}"]:not(:checked)`)) : [],
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
// v125: Sperren des Unterabschnitts beachten (Grund-Einsatz bleibt unverändert)
const assignLocks = () => ({ canItem: (it) => canEdit(P, it), canCell: (gid, k) => canEditCell(P, gid, k) });
async function updateSendSize() {
  const { a, link, sel } = await currentAssignment();
  const tm = P.marks.find((m) => m.id === sel.teamId);
  $('send-assign').textContent = tm ? assignText(planAssign(P, sel, assignLocks()), tm.label) : '';
  const nf = a.g.reduce((x, g) => x + g.f.length, 0);
  const np = a.i.filter((x) => x.pv).length;
  $('send-size').textContent = `${a.g.length ? `${a.g.length} Rastergebiet${a.g.length === 1 ? '' : 'e'} · ${nf} hervorgehobene Felder · ` : ''}Umrisse/Zeichnungen: ${a.i.length - np} · ${np ? `Spuren des vorherigen Teams: ${np} · ` : ''}${a.po ? `Lage-Orte: ${a.po.length} · ` : ''}${a.rp ? `Rettungspunkte: ${a.rp.length} · ` : ''}${a.ct ? `Kontakte: ${a.ct.length} · ` : ''}`
    + (link.length <= QR_MAX ? `passt in einen QR-Code (${link.length} Zeichen)` : `zu groß für einen QR-Code (${link.length} Zeichen) – per WhatsApp senden oder weniger auswählen`);
}
['send-team', 'send-meet', 'send-rescue', 'send-person', 'send-hint'].forEach((id) => $(id).addEventListener(id === 'send-hint' ? 'input' : 'change', () => {
  if (id === 'send-team') { $('send-grids').innerHTML = ''; $('send-items').innerHTML = ''; $('send-prev').innerHTML = ''; return renderSend(); }
  sendCache = null; updateSendSize();
}));
// ohne Raster gibt es keine Felder auszuwählen
function syncSendFields() {
  $('send-fields-sub').hidden = !$('send-grids').querySelector('input:checked');
}
$('send-grids').addEventListener('change', (e) => {
  // Raster angehakt: alles, was darin liegt, gleich mit auswählen
  if (e.target.checked) {
    const inside = itemsInGrids(P, [e.target.value], $('send-team').value);
    for (const inp of $('send-items').querySelectorAll('input')) if (inside.has(P.items[Number(inp.value)])) inp.checked = true;
  }
  syncSendFields(); renderPrev(); sendCache = null; updateSendSize();
});
$('send-items').addEventListener('change', () => { renderPrev(); sendCache = null; updateSendSize(); });
$('send-prev').addEventListener('change', () => { sendCache = null; updateSendSize(); });
$('send-pois').addEventListener('change', () => { sendCache = null; updateSendSize(); });
$('send-ct-list').addEventListener('change', () => { sendCache = null; updateSendSize(); });
$('send-contacts').addEventListener('change', () => { $('send-ct-list').hidden = !$('send-contacts').checked; sendCache = null; updateSendSize(); });
document.querySelectorAll('input[name=send-fields]').forEach((r) => r.addEventListener('change', () => {
  sendCache = null;
  if (sendFields() === 'pick') { closePanels(); setTool('sendpick'); updatePickBar(); redraw(); } else { renderSend(); renderPrev(); }
}));
$('send-open').addEventListener('click', () => {
  if (!allGrids(P).length && !P.items.some((it) => !it.resultKey)) return toast('Nichts zu verschicken – zuerst ein Raster oder einen Umriss anlegen');
  $('send-grids').innerHTML = '';
  $('send-items').innerHTML = '';
  $('send-prev').innerHTML = '';
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
  renderPrev();
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
    // v125: noch nicht zugeteilte Umrisse/Felder gehören ab jetzt diesem Team (ein Rückgängig-Schritt)
    const plan = planAssign(P, c.sel, assignLocks());
    if (planCount(plan)) { snapshot(); applyAssign(P, plan, c.sel.teamId); changed(); toast(`✅ ${assignText(plan, team ? team.label : 'Team', true)}`, 6000); }
    // v125: Link merken, damit der QR-Code später unverändert erneut gezeigt werden kann (P.sentLinks)
    if (c.link.length <= 30000) (P.sentLinks = P.sentLinks || {})[c.a.id] = c.link;
    // acc 0 = noch nicht übernommen; items/cells merken, was zum Auftrag gehört (Schutz nach der Übernahme)
    P.sent.push({
      id: c.a.id, teamId: c.sel.teamId, team: team ? team.label : 'ohne Team', grids: c.a.g.map((g) => g.i), at: Date.now(),
      what: assignmentSummary(c.a), n: 0, ctr: assignmentCenter(c.a), ...(c.a.ls ? { live: true } : {}),
      acc: 0, items: (c.sel.itemIdx || []).map((i) => P.items[i] && (P.items[i].id || (P.items[i].id = uid()))).filter(Boolean), cells: Object.fromEntries(c.a.g.map((g) => [g.i, [...g.f]])),
    });
    renderSentList();
  }
  touch(); // auch den (neuen) Status-Schlüssel des Einsatzes sichern
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
// Übersicht der Einsatzleitung: welches Team hat welchen Auftrag, seit wann, kamen Rückmeldungen?
const SENT_QUIET = 60 * 60e3; // so lange ohne Rückmeldung: orange markieren
// v130.4: Pausenzeit bzw. „noch kein Auftrag“ + Anzahl/Gesamtzeit abgeschlossener Aufträge eines Teams
// (für „Teams ohne Auftrag“ – läuft gerade kein Auftrag, zeigt, wie lange die Pause schon dauert)
function teamClockText(teamId) {
  const c = teamClock(P, teamId);
  const now = Date.now();
  const stats = c.count ? `${c.count} Auftrag${c.count === 1 ? '' : 'e'} bisher, insgesamt ${durText(c.totalMs)}` : '';
  if (c.state === 'new') return 'Noch keinen Auftrag gehabt';
  if (c.state === 'pause') return `😴 Pause seit ${hhmm(c.since)} (${sinceText(c.since, now)})${stats ? ` · ${stats}` : ''}`;
  return stats; // 'waiting'/'active' kommen hier nicht vor (Team hat dann einen laufenden Auftrag, s.u.)
}
// v130.4: Anzahl/Gesamtzeit früherer Aufträge eines Teams, als Zusatzzeile unter einer laufenden Auftragskarte
function teamStatsText(teamId) {
  const c = teamClock(P, teamId);
  return c.count ? `Bisher ${c.count} Auftrag${c.count === 1 ? '' : 'e'}, insgesamt ${durText(c.totalMs)}` : '';
}
function renderSentList() {
  renderTeamBar();
  const box = $('sent-list');
  box.innerHTML = '';
  const list = teamOrder([...(P.sent || [])].reverse(), P.marks); // feste Team-Reihenfolge, je Team neueste zuerst
  // v125: Teams mit Gebieten, aber noch ohne Auftrag
  const wo = db.mode === 'el' && !P.closed ? teamsWithoutOrder(P) : [];
  if (wo.length) {
    const wh = document.createElement('h2');
    wh.className = 'sub';
    wh.textContent = `🕓 Teams ohne Auftrag (${wo.length})`;
    box.appendChild(wh);
    for (const w of wo) {
      const d = document.createElement('div');
      d.className = 'sent-card wait';
      d.innerHTML = '<b><i></i><span></span></b><div class="what"></div><div class="tclock"></div>';
      d.querySelector('i').style.background = w.team.color;
      d.querySelector('b span').textContent = `${typeIcon(w.team)} ${w.team.label}${w.team.dog ? ` – ${w.team.dog}` : ''}`;
      d.querySelector('.what').textContent = [w.cells && `${w.cells} Feld${w.cells === 1 ? '' : 'er'}`, w.areas && `${w.areas} Umriss${w.areas === 1 ? '' : 'e'}`].filter(Boolean).join(' · ');
      d.querySelector('.tclock').textContent = teamClockText(w.team.id); // v130.4: Pausenzeit bzw. „noch kein Auftrag“, Anzahl/Gesamtzeit
      const nb = document.createElement('button');
      nb.className = 'mini';
      nb.textContent = '📲 Auftrag erstellen';
      nb.addEventListener('click', () => openSendFor(w.team.id));
      d.appendChild(nb);
      box.appendChild(d);
    }
  }
  if (!list.length) return;
  const open = list.filter((x) => !isDone(x));
  const fin = list.filter(isDone);
  const h = document.createElement('h2');
  h.className = 'sub';
  h.textContent = `📋 Aufträge (${open.length})`;
  box.appendChild(h);
  // abgeschlossene Aufträge: eigener, aufklappbarer Bereich unter den offenen
  let finBox = null;
  if (fin.length) {
    finBox = document.createElement('details');
    finBox.className = 'sent-done';
    finBox.open = !!db.finOpen;
    finBox.innerHTML = '<summary></summary>';
    finBox.firstChild.textContent = `✅ Abgeschlossen (${fin.length})`;
    finBox.addEventListener('toggle', () => { db.finOpen = finBox.open; });
  }
  const now = Date.now();
  for (const x of list) {
    const team = P.marks.find((m) => m.id === x.teamId);
    const { last: last0, done: dm } = latestFor(allMsgs(), x.id);
    const lm = headMsg(allMsgs().filter((m) => m.a === x.id)); // dringende Meldung bleibt stehen
    const quiet = now - Math.max(x.last || 0, x.acc || x.at, last0 ? last0.t : 0) > SENT_QUIET;
    const d = document.createElement('div');
    const acc = isAccepted(x);
    const fini = isDone(x);
    const zu = closeMsg(allMsgs(), x.id);
    d.className = 'sent-card' + (acc && quiet && !fini ? ' quiet' : '') + (acc ? '' : ' wait') + (fini ? ' done' : '');
    d.innerHTML = '<b><i></i><span></span></b><div class="what"></div><div class="since"></div><div class="back"></div>';
    d.querySelector('i').style.background = team ? team.color : '#999';
    d.querySelector('b span').textContent = `${team && !isDog(team) ? `${typeIcon(team)} ` : ''}${team ? team.label : x.team}${team && team.dog ? ` – ${team.dog}` : ''}${team && team.org ? ` · ${team.org}` : ''}`;
    const what = x.what || allGrids(P).filter((g) => (x.grids || []).includes(g.id)).map((g) => gridLabel(P, g)).join(', ');
    d.querySelector('.what').textContent = what || 'Auftrag';
    d.querySelector('.since').textContent = acc ? `📲 Auftrag seit ${hhmm(x.acc)} (${sinceText(x.acc, now)}) – übernommen` : `⏳ QR erstellt ${hhmm(x.at)} – noch nicht übernommen`;
    // v130.4: bisherige Aufträge/Gesamtzeit dieses Teams – hilft abzuschätzen, ob der Hund noch kann
    if (acc && !fini) {
      const stats = teamStatsText(x.teamId);
      if (stats) { const sn = document.createElement('div'); sn.className = 'since tstats'; sn.textContent = stats; d.querySelector('.since').insertAdjacentElement('afterend', sn); }
    }
    const n = x.n || (x.last ? 1 : 0);
    d.querySelector('.back').textContent = !acc ? 'Gilt erst als vergeben, wenn das Team ihn übernommen hat.' : x.last
      ? `📥 ${n} Rückmeldung${n === 1 ? '' : 'en'}, zuletzt ${hhmm(x.last)} (vor ${sinceText(x.last, now)})${x.lastSum ? ` – ${x.lastSum}` : ''}`
      : lm ? 'Weg und Markierungen kommen mit der QR-Rückmeldung' : `⏳ noch keine Rückmeldung${quiet ? ' – nachfragen?' : ''}`;
    if (fini) {
      const dn = document.createElement('div');
      dn.className = 'closed';
      dn.textContent = `✅ abgeschlossen ${hhmm(x.done)}${x.pct != null ? ` (${x.pct} % abgesucht)` : ''}`;
      d.appendChild(dn);
    } else if (zu) {
      const dn = document.createElement('div');
      dn.className = 'closed';
      dn.textContent = `✅ meldet abgeschlossen ${hhmm(zu.t)}${msgPct(zu) != null ? ` (${msgPct(zu)} %)` : ''}${zu.txt ? ` – ${zu.txt}` : ''}`;
      d.appendChild(dn);
    }
    if (lm && !fini) {
      const lv = document.createElement('div');
      lv.className = 'live';
      lv.textContent = `📣 ${msgLabel(lm)} · ${hhmm(lm.t)}${lm.lat != null ? ' · 📍' : ''}${lm.s === 'fertig' && lm.txt ? ` – ${lm.txt}` : ''}`;
      const at = [...allMsgs()].reverse().find((m) => m.a === x.id && m.lat != null);
      if (at) lv.addEventListener('click', () => showStatusMark(at));
      d.appendChild(lv);
      if (dm && dm !== lm) {
        const dn = document.createElement('div');
        dn.className = 'back';
        dn.textContent = `${msgLabel(dm)} · ${hhmm(dm.t)}${dm.txt ? ` – ${dm.txt}` : ''}`;
        d.appendChild(dn);
      }
    }
    const bar = document.createElement('div');
    if (db.mode === 'el') { // v125: jeden Auftrags-QR erneut zeigen (laufend und abgeschlossen)
      const qb = document.createElement('button');
      qb.className = 'mini';
      qb.textContent = '📲 QR-Code erneut zeigen';
      qb.addEventListener('click', () => showSentQr(x));
      bar.appendChild(qb);
    }
    if (!fini && db.mode === 'el' && canEnter()) {
      const fb = document.createElement('button');
      fb.className = 'mini';
      fb.textContent = '✍️ Meldung eintragen';
      fb.addEventListener('click', () => funkDialog(x.id));
      bar.appendChild(fb);
    }
    if (acc && !fini) {
      const cb = document.createElement('button');
      cb.className = 'mini';
      cb.textContent = '✅ Abschließen';
      cb.addEventListener('click', () => askClose(x, false));
      bar.appendChild(cb);
    }
    if (fini) {
      const ob = document.createElement('button');
      ob.className = 'mini';
      ob.textContent = '↩ Wieder öffnen';
      ob.addEventListener('click', () => {
        reopenSent(x, allMsgs());
        changed();
        redraw();
        renderSentList();
        toast(`↩ Auftrag ${x.team} ist wieder offen`);
      });
      bar.appendChild(ob);
    }
    if (!acc) {
      const ab = document.createElement('button');
      ab.className = 'mini';
      ab.textContent = '✓ Team hat übernommen';
      ab.addEventListener('click', () => { x.acc = Date.now(); changed(); renderSentList(); toast(`✓ Auftrag ${x.team} gilt als übernommen`); });
      bar.appendChild(ab);
    }
    const rb = document.createElement('button');
    rb.className = 'mini';
    rb.textContent = acc ? '🗑 Auftrag entfernen' : '✕ Verwerfen';
    rb.addEventListener('click', async () => {
      if (acc && !(await openDlg((box, close) => {
        dlgHead(box, '🗑 Übernommenen Auftrag entfernen?', `Der Auftrag ${x.team} ist seit ${hhmm(x.acc)} übernommen. Wirklich entfernen? Der Schutz seiner Felder und Zeichnungen entfällt.`);
        dlgButton(box, 'Entfernen', 'urgent', () => close(true));
        dlgButton(box, 'Abbrechen', 'primary', () => close(false));
      }))) return;
      P.sent = P.sent.filter((y) => y !== x);
      if (P.sentLinks) delete P.sentLinks[x.id];
      if (gapView && gapView.a === x.id) gapView = null;
      changed();
      redraw();
      renderSentList();
    });
    bar.appendChild(rb);
    d.appendChild(bar);
    if (!fini && P.items.some((it) => it.resultKey && it.resultKey.startsWith(`${x.id}|t`))) {
      const gb = document.createElement('button');
      gb.className = 'mini gaps';
      gb.textContent = gapView && gapView.a === x.id ? '🕳 Lücken ausblenden' : '🕳 Lücken zeigen';
      gb.addEventListener('click', () => toggleGaps(x));
      d.appendChild(gb);
    }
    (fini ? finBox : box).appendChild(d);
  }
  if (finBox) box.appendChild(finBox);
}
// v125: Auftrags-QR erneut zeigen – gemerkter Link, sonst aus den Daten des Auftrags (gleiche ID, gleicher Live-Kanal)
async function showSentQr(x) {
  let link = (P.sentLinks || {})[x.id] || '';
  let again = false;
  if (!link) {
    try { link = shareLink('a', await pack(rebuildAssignment(P, x)), PUBLIC_URL); again = true; } catch { return toast('QR-Code konnte nicht erstellt werden'); }
  }
  showQr(link, `📲 Auftrag ${x.team}`, `Gleicher Auftrag wie beim ersten Mal – nichts Neues angelegt. Mit der Kamera des Hundeführer-Handys scannen und den Link öffnen.${again ? ' (Hinweistext und Kontakte des ersten Codes sind hier nicht enthalten.)' : ''}`);
}
// v125: Auftrags-Fenster für ein Team öffnen (aus „Teams ohne Auftrag“)
function openSendFor(teamId) {
  $('send-grids').innerHTML = '';
  $('send-items').innerHTML = '';
  $('send-prev').innerHTML = '';
  renderSend();
  $('send-team').value = teamId;
  $('send-grids').innerHTML = '';
  $('send-items').innerHTML = '';
  renderSend();
  openPanel('panel-send');
}
// v101: Auftrag abschließen – Rückfrage. reported: das Team hat „✅ Auftrag abgeschlossen“ gemeldet und die Rückmeldung ist da
async function askClose(x, reported) {
  const proj = P;
  const pc = sentPct(x, allMsgs());
  const ok = await openDlg((box, close) => {
    dlgHead(box, `✅ Auftrag ${x.team} abschließen?`, reported
      ? `Das Team meldet ihn als erledigt${pc != null ? ` (${pc} % abgesucht)` : ''}, die Rückmeldung ist da.`
      : `Der Auftrag gilt danach als abgeschlossen${pc != null ? ` (${pc} % abgesucht)` : ''}, das Team als frei. Der Schutz seiner Felder und Zeichnungen entfällt.`);
    dlgButton(box, '✅ Abschließen', 'primary', () => close(true));
    dlgButton(box, reported ? 'Noch offen lassen' : 'Abbrechen', '', () => close(false));
  });
  if (proj !== P || !P.sent.includes(x)) return;
  if (!ok) {
    if (reported) { declineClose(x, allMsgs()); changed(); }
    return;
  }
  closeSent(x, allMsgs());
  if (gapView && gapView.a === x.id) gapView = null;
  changed();
  redraw();
  renderSentList();
  toast(`✅ Auftrag ${x.team} abgeschlossen${x.pct != null ? ` (${x.pct} %)` : ''}`, 5000);
}
// Rückfrage, sobald Meldung „abgeschlossen“ und QR-Rückmeldung eines Auftrags da sind (egal in welcher Reihenfolge)
let closeBusy = false;
async function checkCloseAsk() {
  if (locked || closeBusy || db.mode !== 'el' || !P || P.closed) return;
  checkAutoClose(); // v128: abgeschlossen + 100 % -> ohne Rückfrage schließen
  const x = (P.sent || []).find((q) => closeAsk(q, allMsgs()));
  if (!x) return;
  if (!$('dlg').hidden) return setTimeout(checkCloseAsk, 4000); // ein anderes Fenster steht – gleich nochmal
  closeBusy = true;
  try { await askClose(x, true); } finally { closeBusy = false; }
  checkCloseAsk();
}
$('btn-teams').addEventListener('click', renderSentList);

// ---------- 📣 Status-Meldungen (v89) ----------
// Hundeführer (P.hf.ls = [Adresse, Schlüssel]) melden Status und Standorte über die Google-Tabelle; ohne Netz wartet
// alles in P.hf.outbox. Die Einsatzleitung holt die Meldungen ab (P.live) und zeigt sie auf der Karte und in der Übersicht.
const teamColorOf = (a) => {
  const s = (P.sent || []).find((x) => x.id === a);
  const t = s && P.marks.find((m) => m.id === s.teamId);
  return t ? t.color : '#455a64';
};
// Alle Status-Meldungen der Einsatzleitung: über den Status-Server und aus QR-Rückmeldungen
const allMsgsRaw = () => ownTeamMsgs(P, mergeStatus((P.live && P.live.msgs) || [], P.qmsgs || []).filter((m) => !EL_KINDS.includes(m.s)), (m) => forAllUa(m, isUrgent)); // v117: Rückkanal-Arten (q, el, qel) sind keine Teammeldungen
// v103: Korrekturen (s: 'kor') eingearbeitet; allMsgsK mit zurückgezogenen Fund/Hilfe (gone, nur Verlauf), allMsgs ohne sie
const allMsgsK = () => withoutDeleted(applyKor(allMsgsRaw()), P.msgDel); // gelöschte (P.msgDel) bleiben weg
const allMsgs = () => allMsgsK().filter((m) => !m.gone);
// v116: Meldungen für GPX, PDF und Abschlussbericht – EL alle, HF-Gerät die eigenen (ohne zurückgezogene/gelöschte)
const exportMsgs = () => (db.mode === 'hf' ? hfLog() : allMsgs());

// ---- Status-Plakette an jedem Gebiet mit gesendetem Auftrag (Einsatzleitung) ----
// Mitte: beim Senden gemerkt (ctr), bei älteren Aufträgen aus den Feldern des Teams bzw. dem Raster
function sentCenter(x) {
  if (x.ctr) return x.ctr;
  const b = sentBounds(x);
  return b && [(b[0][0] + b[1][0]) / 2, (b[0][1] + b[1][1]) / 2];
}
// Ausdehnung (Team-Felder bzw. Raster) als [[Süd, West], [Nord, Ost]]
function sentBounds(x) {
  const pts = [];
  for (const g of allGrids(P).filter((q) => (x.grids || []).includes(q.id))) {
    const gr = makeGrid(g.area, g.cellM);
    const keys = Object.keys(g.fills).filter((k) => g.fills[k] === x.teamId);
    if (!keys.length) { pts.push([g.area.north, g.area.west], [g.area.south, g.area.east]); continue; }
    for (const k of keys) { const [c, r] = k.split(',').map(Number); const b = cellBounds(gr, c, r); pts.push([b.north, b.west], [b.south, b.east]); }
  }
  return ptsBounds(pts);
}
function ptsBounds(pts) {
  if (!pts.length) return null;
  const la = pts.map((q) => q[0]);
  const lo = pts.map((q) => q[1]);
  return [[Math.min(...la), Math.min(...lo)], [Math.max(...la), Math.max(...lo)]];
}
// Felder des Auftrags (Team-Felder in seinen Rastern) und wie viele davon als „abgesucht“ zurückgemeldet sind
function sentFields(x) {
  const done = (P.marks.find((m) => m.kind === 'status' && m.label === 'abgesucht') || {}).id;
  let n = 0;
  let a = 0;
  for (const g of allGrids(P).filter((q) => (x.grids || []).includes(q.id))) {
    for (const k of Object.keys(g.fills)) if (g.fills[k] === x.teamId) { n++; if (done && g.status[k] === done) a++; }
  }
  return { n, a };
}
// Gebiete eines Auftrags mit Namen wie beim Hundeführer (Rastername bzw. Umrissname/„Umriss n“) -> Map Name -> Ausdehnung
function sentAreas(x) {
  const out = new Map();
  for (const g of allGrids(P).filter((q) => (x.grids || []).includes(q.id))) {
    out.set(gridLabel(P, g), sentBounds({ grids: [g.id], teamId: x.teamId }));
  }
  let n = 0;
  for (const id of x.items || []) {
    const it = P.items.find((q) => q.id === id);
    if (!it || it.kind !== 'track' || it.open || (it.pts || []).length < 3) continue;
    const name = it.name || `Umriss ${++n}`;
    out.set(name, ptsBounds(it.pts));
  }
  return out;
}
// Plakette je Gebiet des Auftrags (Umriss/Raster): welches Team dort ist, sein Status und Stand in diesem Gebiet
function sentBadges() {
  if (db.mode !== 'el' || db.msgOff || isFree()) return [];
  const msgs = allMsgs();
  const out = [];
  for (const x of teamOrder(P.sent || [], P.marks)) {
    const team = P.marks.find((m) => m.id === x.teamId);
    const name = `${team && !isDog(team) ? `${typeIcon(team)} ` : ''}${team ? team.label : x.team}`; // v128: Typ-Symbol (außer Hund)
    const color = team ? team.color : '#455a64';
    const acc = isAccepted(x);
    const fini = isDone(x);
    const own = msgs.filter((m) => m.a === x.id);
    const f = sentFields(x);
    let areas = sentAreas(x);
    if (!areas.size) { const c = sentCenter(x); if (!c) continue; areas = new Map([['', [c, c]]]); }
    for (const [area, bnd] of areas) {
      // Stand in diesem Gebiet: letzte Stand-Meldung mit Wert für das Gebiet (bzw. ohne Gebiete)
      let pc = null;
      for (const m of [...own].reverse()) {
        if (m.s !== 'fertig' && m.s !== 'zu') continue;
        const hit = Array.isArray(m.ar) && m.ar.length ? m.ar.find((q) => q[0] === area) : null;
        if (hit) { pc = hit[1]; break; }
        if (!(Array.isArray(m.ar) && m.ar.length)) { if (m.s === 'zu' && m.pc == null) continue; pc = m.pc ?? 100; break; }
      }
      // abgeschlossener Auftrag: grüne Plakette „✅ Team · 80 %“ (Stand beim Abschließen)
      if (fini) {
        if (pc == null) pc = x.pct ?? null;
        const l = `✅ ${area ? `${name} · ${area}` : name}${pc != null ? ` · ${pc} %` : ''}`;
        out.push({ x, bnd, color, lines: [l, `abgeschlossen ${hhmm(x.done)}`], fin: true, done: true, wait: false });
        continue;
      }
      // letzte sonstige Meldung, die dieses Gebiet betrifft (ohne Gebietsangabe = alle)
      const st = headMsg(own.filter((m) => m.s !== 'fertig' && !(Array.isArray(m.gb) && m.gb.length && !m.gb.includes(area))));
      const lines = [area ? `${name} · ${area}` : name];
      const info = [];
      if (!acc && !own.length) info.push('📲 wartet auf Übernahme');
      else if (st) info.push(`${msgLabel(st)} ${hhmm(st.t)}`);
      if (pc != null) info.push(pc >= 100 ? '✅ fertig' : `📊 ${pc} %`);
      if (f.a && (!area || allGrids(P).some((g) => gridLabel(P, g) === area))) info.push(`▦ ${f.a}/${f.n} Felder`);
      if (!info.length) info.push(`📲 seit ${hhmm(x.acc || x.at)}`);
      lines.push(info.join(' · '));
      out.push({ x, bnd, color, lines, fin: pc != null && pc >= 100, wait: !acc });
    }
  }
  return out;
}
let badgeBoxes = []; // zuletzt gezeichnete Plaketten (zum Antippen)
// Was eine Plakette nicht überdecken soll: Texte/Markierungen, Lage-Orte, B-Ort, Meldungen auf der Karte (Pixel-Kästen)
function badgeObstacles(c) {
  const out = [];
  const label = (x, y, r, text, px) => {
    c.font = `bold ${px}px sans-serif`;
    out.push(boxOf(x - r, y - Math.max(r, px / 2 + 3), 2 * r + 5 + (text ? c.measureText(text).width + 6 : 0), 2 * Math.max(r, px / 2 + 3)));
  };
  const d = labelDetail(map.getZoom());
  for (const it of P.items) {
    if (it.hidden || it.kind !== 'text') continue;
    const [x, y] = toPx(it.lat, it.lon);
    label(x, y, 7, d ? (d >= 3 || it.text.length <= 16 ? it.text : `${it.text.slice(0, 15)}…`) : '', 15);
  }
  const hide = P.hide || {};
  if (!hide.pois) for (const p of P.pois || []) { const [x, y] = toPx(p.lat, p.lon); label(x, y, 14, poiName(p), 13); }
  if (P.meet && !hide.meet) { const [x, y] = toPx(P.meet.lat, P.meet.lon); label(x, y, 13, P.meet.text, 14); }
  for (const s of statusMarks()) { const [x, y] = toPx(s.m.lat, s.m.lon); out.push(boxOf(x - 20, y - 20, 40, 40)); }
  // Name und Fläche der Umrisse/Wege (stehen über dem Startpunkt)
  c.font = 'bold 13px sans-serif';
  for (const it of P.items) {
    if (it.hidden || it.kind !== 'track' || !(it.pts || []).length) continue;
    const [x, y] = toPx(it.pts[0][0], it.pts[0][1]);
    const who = it.to ? assigneeName(P, it.to) || '' : '';
    const t = trackLabel(it, who, d);
    const ls = t ? t.split('\n') : [];
    if (ls.length) out.push(boxOf(x + 4, y - 8 - 16 * ls.length, Math.max(...ls.map((l) => c.measureText(l).width)) + 8, 16 * ls.length + 6));
    if (it.note && d >= 3) out.push(boxOf(x + 4, y - 4, Math.min(it.note.length, 60) * 6.5 + 8, 18));
  }
  return out;
}
// Knöpfe und Leisten, die über der Karte liegen (Pixel relativ zur Karte)
const BADGE_UI = '.topbar, #tm-btn, .leftbar > *, .sidebuttons > *, .toolbar, #hfbar, #hfinfo, #wx, #hint, #tm-banner, .leaflet-control-attribution';
function badgeUi() {
  const m = canvas.getBoundingClientRect();
  return [...document.querySelectorAll(BADGE_UI)].filter((e) => e.offsetParent || e.getClientRects().length)
    .map((e) => e.getBoundingClientRect()).filter((r) => r.width && r.height)
    .map((r) => ({ x0: r.left - m.left - 4, y0: r.top - m.top - 4, x1: r.right - m.left + 4, y1: r.bottom - m.top + 4 }));
}
function drawSentBadges(c) {
  badgeBoxes = [];
  const list = sentBadges();
  if (!isTablet()) return renderOrders(list); // Handy: Stand im Reiter „📋 Aufträge“ statt auf der Karte
  if (!list.length) return;
  const sizes = list.map((b) => ({
    w: Math.max(...b.lines.map((l, i) => { c.font = `${i ? '' : 'bold '}12px sans-serif`; return c.measureText(l).width; })) + 16,
    h: b.lines.length * 15 + 8,
  }));
  const areas = list.map((b) => {
    const [ax, ay] = toPx(b.bnd[1][0], b.bnd[0][1]); // Nord-West
    const [bx, by] = toPx(b.bnd[0][0], b.bnd[1][1]); // Süd-Ost
    return { x0: Math.min(ax, bx), y0: Math.min(ay, by), x1: Math.max(ax, bx), y1: Math.max(ay, by) };
  });
  const dpr = window.devicePixelRatio || 1;
  const pos = placeBadges(list.map((b, i) => ({ area: areas[i], ...sizes[i] })), badgeObstacles(c), { w: canvas.width / dpr, h: canvas.height / dpr }, badgeUi());
  c.textAlign = 'left';
  c.textBaseline = 'middle';
  list.forEach((b, i) => {
    const { w, h } = sizes[i];
    const { x0, y0, ax, ay } = pos[i];
    // Verbindungslinie zum Gebiet
    const mx = Math.min(Math.max(ax, x0), x0 + w);
    const my = Math.min(Math.max(ay, y0), y0 + h);
    if (Math.hypot(mx - ax, my - ay) > 3) {
      c.strokeStyle = b.color;
      c.lineWidth = 2;
      c.beginPath();
      c.moveTo(mx, my);
      c.lineTo(ax, ay);
      c.stroke();
      c.fillStyle = b.color;
      c.beginPath();
      c.arc(ax, ay, 3.5, 0, Math.PI * 2);
      c.fill();
    }
    c.fillStyle = b.fin ? '#e8f5e9' : 'rgba(255,255,255,0.93)';
    c.strokeStyle = b.done ? '#2e7d32' : b.color;
    c.lineWidth = 3;
    if (b.wait) c.setLineDash([6, 4]); // noch nicht übernommen: gestrichelt
    c.beginPath();
    if (c.roundRect) c.roundRect(x0, y0, w, h, 8); else c.rect(x0, y0, w, h);
    c.fill();
    c.stroke();
    c.setLineDash([]);
    c.fillStyle = '#111';
    b.lines.forEach((l, i) => { c.font = `${i ? '' : 'bold '}12px sans-serif`; c.fillText(l, x0 + 8, y0 + 11 + i * 15); });
    badgeBoxes.push({ b, x0, y0, w, h });
  });
}
function badgeAt(x, y) {
  for (let i = badgeBoxes.length - 1; i >= 0; i--) {
    const q = badgeBoxes[i];
    if (x >= q.x0 && x <= q.x0 + q.w && y >= q.y0 && y <= q.y0 + q.h) return q.b;
  }
  return null;
}

// Meldungen mit Standort für die Karte: Einsatzleitung alle Teams, Hundeführer nur die eigenen
function statusMarks() {
  let list;
  if (db.mode === 'hf') list = hfLog().map((m) => ({ m, color: hfColor() }));
  else if (!db.msgOff) list = allMsgs().map((m) => ({ m, color: teamColorOf(m.a) }));
  else return [];
  list = list.filter((x) => x.m.lat != null);
  // v130.10: Fund/Hinweis der EL (auch „Spur“, Gegenstand, Wärmequelle …) bleibt immer sichtbar – sonst verschwindet
  // ein frisch angetippter Punkt außerhalb des Rastergebiets, weil man dafür meist weiter herauszoomen muss.
  if (labelDetail(map.getZoom()) === 0) list = list.filter((x) => isUrgent(x.m) || isFind(x.m));
  const newest = new Map();
  for (const x of list) newest.set(x.m.a, x.m.id); // Liste ist nach Zeit sortiert
  for (const x of list) x.big = newest.get(x.m.a) === x.m.id;
  return list;
}
function drawStatusMarks(c) {
  c.textAlign = 'center';
  c.textBaseline = 'middle';
  for (const x of statusMarks()) {
    const [px, py] = toPx(x.m.lat, x.m.lon);
    const r = x.big ? 16 : 10;
    c.globalAlpha = x.big ? 1 : 0.65;
    c.beginPath();
    c.arc(px, py, r, 0, Math.PI * 2);
    c.fillStyle = isUrgent(x.m) ? '#ffcdd2' : '#fff';
    c.fill();
    c.lineWidth = x.big ? 4 : 3;
    c.strokeStyle = x.color;
    c.stroke();
    c.font = `${x.big ? 17 : 11}px sans-serif`;
    c.fillStyle = '#000';
    c.fillText(msgIcon(x.m), px, py + 1);
  }
  c.globalAlpha = 1;
}
function statusMarkAt(x, y) {
  let hit = null;
  for (const s of statusMarks()) {
    const [px, py] = toPx(s.m.lat, s.m.lon);
    if (Math.hypot(px - x, py - y) <= (s.big ? 20 : 14)) hit = s; // später = neuer
  }
  return hit;
}
// v127: Hundename zum Team einer Meldung (über den Auftrag), damit gleichnamige Teams unterscheidbar bleiben
function dogOfMsg(m) {
  const x = m && (P.sent || []).find((q) => q.id === m.a);
  const t = x && P.marks.find((q) => q.id === x.teamId);
  const dog = String((t && t.dog) || '').trim();
  return dog && !String(m.tm || '').includes(dog) ? dog : '';
}
function statusText({ m }) {
  return [`${m.tm || 'Team'}${dogOfMsg(m) ? ` (${dogOfMsg(m)})` : ''}: ${msgLabel(m)}`, hhmm(m.t) + (m.acc != null ? ` (± ${m.acc} m)` : ''), m.txt && `„${m.txt}“`, findStatusText(m), msgSource(m), m.ph && '📷 Foto', m.ed && `✏️ geändert ${hhmm(m.ed)}`,
    ].filter(Boolean).join(' · ');
}
// EL: Meldung antippen – Text und Löschen (nach Warnung); gelöscht wird nur auf diesem Gerät (und per Fortschritt bei den anderen EL-Geräten)
async function msgDialog(m, direct = false) {
  const del = direct || await openDlg((box, close) => {
    dlgHead(box, 'Meldung', `${statusText({ m })}${replyContext(m, elMsgsAll()) ? `\n${replyContext(m, elMsgsAll())}` : ''}`);
    dlgNavButton(box, close, false, `${m.tm || 'Team'}: ${msgLabel(m)}`, m.lat, m.lon); // v123
    if (isFind(m) && canEnter()) dlgButton(box, m.fs === 'g' ? '⏳ Wieder offen' : '✔ Als geprüft markieren', '', () => { close(false); findToggle(m); });
    dlgButton(box, '🗑 Löschen', 'urgent', () => close(true));
    dlgButton(box, 'Schließen', 'primary', () => close(false));
  });
  if (!del || isLocked()) return;
  const ok = await openDlg((box, close) => {
    dlgHead(box, '🗑 Meldung löschen?', `Meldung von ${m.tm || 'Team'} (${hhmm(m.t)}) wirklich löschen? Sie wird auf diesem Gerät nicht mehr angezeigt.`);
    dlgButton(box, 'Löschen', 'urgent', () => close(true));
    dlgButton(box, 'Abbrechen', 'primary', () => close(false));
  });
  if (!ok) return;
  P.msgDel = P.msgDel || {};
  P.msgDel[m.id] = Date.now();
  changed();
  redraw();
  renderSentList();
  renderStatusPanel();
  saveNow();
  toast('Meldung gelöscht');
}
function showStatusMark(m) {
  closePanels();
  map.setView([m.lat, m.lon], Math.max(map.getZoom(), 16));
  toast(statusText({ m }), 9000);
}

// ---- Lücken (Einsatzleitung): was der zurückgemeldete Weg nicht abdeckt ----
function drawGaps(c) {
  if (!gapView || !gapView.pts.length) return;
  if (!drawGaps.pat) {
    const pc = document.createElement('canvas');
    pc.width = pc.height = 8;
    const x = pc.getContext('2d');
    x.strokeStyle = 'rgba(230,81,0,0.85)';
    x.lineWidth = 1.5;
    x.beginPath();
    x.moveTo(0, 8); x.lineTo(8, 0); x.moveTo(-2, 2); x.lineTo(2, -2); x.moveTo(6, 10); x.lineTo(10, 6);
    x.stroke();
    drawGaps.pat = c.createPattern(pc, 'repeat');
  }
  const m0 = map.getCenter();
  const [x0, y0] = toPx(m0.lat, m0.lng);
  const [x1, y1] = toPx(m0.lat + gapView.step / 111320, m0.lng + gapView.step / (111320 * Math.cos((m0.lat * Math.PI) / 180)));
  const w = Math.abs(x1 - x0) + 0.5;
  const h = Math.abs(y1 - y0) + 0.5;
  const W = canvas.width / (window.devicePixelRatio || 1);
  const H = canvas.height / (window.devicePixelRatio || 1);
  c.fillStyle = drawGaps.pat;
  for (const [la, lo] of gapView.pts) {
    const [px, py] = toPx(la, lo);
    if (px < -w || py < -h || px > W + w || py > H + h) continue;
    c.fillRect(px - w / 2, py - h / 2, w, h);
  }
}
function toggleGaps(x) {
  if (gapView && gapView.a === x.id) { gapView = null; redraw(); return renderSentList(); }
  const track = P.items.filter((it) => it.resultKey && it.resultKey.startsWith(`${x.id}|t`)).map((it) => it.pts);
  const shapes = areaShapes(P, { gridIds: x.grids || [], teamId: x.teamId || '' });
  if (!shapes.length) return toast('Kein Gebiet zum Vergleichen (Raster oder Umriss fehlt)');
  const g = coverageGaps(track, shapes, db.coverR || 30);
  gapView = { a: x.id, ...g };
  closePanels();
  redraw();
  toast(g.pts.length ? `🕳 Schraffiert: nicht abgedeckt (Reichweite ${db.coverR || 30} m um den Weg)` : 'Keine Lücken – das Gebiet ist abgedeckt', 6000);
}

// ---- Hundeführer: melden ----
const hasLive = () => db.mode === 'hf' && !!P.hf; // ohne Status-Server (P.hf.ls) gehen Meldungen mit der QR-Rückmeldung
function renderStatusBtn() {
  renderElwBar(); // v124
  const b = $('hf-status');
  b.hidden = !hasLive();
  if (b.hidden) return;
  const h = P.hf;
  const n = (h.outbox || []).length;
  const ok = [...(h.log || [])].reverse().find((x) => x.ok);
  b.classList.toggle('pend', n > 0);
  b.querySelector('b').textContent = n ? `⏳ ${n}` : ok ? `✓ ${hhmm(ok.t)}` : 'Status';
}
// Eigene Meldungen mit Korrekturen (zurückgezogene fallen weg)
const hfLog = () => applyKor((P.hf && P.hf.log) || []).filter((m) => !m.gone);
// Korrektur an eine eigene Meldung: wie jede Meldung ins Log / in die Warteschlange, ohne Standortabfrage
async function sendKor(m, f) {
  const p = P;
  const h = p.hf;
  if (!h) return;
  const k = buildKor({ a: h.id, tm: h.team, ref: m.id, ...f });
  h.log = [...h.log, { ...k }].slice(-100);
  if (h.ls) h.outbox.push(k);
  p.updated = Date.now();
  saveNow();
  renderStatusBtn();
  redraw();
  const what = f.del ? 'Meldung gelöscht' : f.pos ? 'Meldung verlegt' : f.nopos ? 'Standort entfernt' : 'Meldung geändert';
  if (!h.ls) return toast(`${what} – geht mit der nächsten QR-Rückmeldung an die Einsatzleitung`, 6000);
  toast(`${what} – wird gesendet …`, 3000);
  await flushStatus();
  if ((h.log.find((x) => x.id === k.id) || {}).rej) return; // abgelehnt: flushStatus hat gewarnt
  toast(h.outbox.some((x) => x.id === k.id) ? `⏳ ${what}: wartet auf Netz – wird automatisch nachgesendet` : `✓ ${what} ${hhmm(Date.now())}`, 5000);
}
// Eigene Meldung antippen: Notiz ändern, verlegen, Standort entfernen, löschen
async function hfMsgDialog(m) {
  if (!hasLive()) return;
  const r = await openDlg((box, close) => {
    dlgHead(box, `${msgLabel(m)} ${hhmm(m.t)}`, m.ed ? `✏️ geändert ${hhmm(m.ed)}` : 'Notiz ändern, verlegen oder zurückziehen.');
    const inp = document.createElement('input');
    inp.type = 'text';
    inp.id = 'msg-edit';
    inp.value = m.txt || '';
    inp.defaultValue = m.txt || '';
    inp.placeholder = 'Notiz (optional)';
    inp.style.width = '100%';
    inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') close({ txt: inp.value.trim() }); });
    box.appendChild(inp);
    dlgButton(box, '💾 Speichern', 'primary', () => close({ txt: inp.value.trim() }));
    if (!NO_POS.includes(m.s)) dlgButton(box, '📍 Verlegen', '', () => close({ move: true }));
    if (m.lat != null) dlgButton(box, '📍 Standort entfernen', '', () => close({ nopos: true }));
    dlgButton(box, '🗑 Löschen', 'urgent', () => close({ del: true }));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!r) return;
  if (r.move) {
    pendingMove = { msg: m };
    setTool('hfmovept');
    return toast('Neuen Ort auf der Karte antippen', 6000);
  }
  if (r.nopos) return sendKor(m, { nopos: true });
  if (r.del) {
    const ok = await openDlg((box, close) => {
      dlgHead(box, '🗑 Meldung löschen?', isUrgent(m) ? 'Die Einsatzleitung sieht, dass die Meldung zurückgezogen wurde.' : `${msgLabel(m)} (${hhmm(m.t)}) wird bei der Einsatzleitung nicht mehr angezeigt.`);
      dlgButton(box, 'Löschen', 'urgent', () => close(true));
      dlgButton(box, 'Abbrechen', 'primary', () => close(false));
    });
    if (ok) sendKor(m, { del: true });
    return;
  }
  if (r.txt !== (m.txt || '')) sendKor(m, { txt: r.txt });
}
// 🗂 Meine Meldungen: alle eigenen, neueste oben
async function hfMyList() {
  const list = [...hfLog()].reverse();
  const seen = ackedIds(P.hf.inbox); // v117: von der Einsatzleitung gesehen
  const m = await openDlg((box, close) => {
    dlgHead(box, `🗂 Meine Meldungen (${list.length})`, 'Antippen zum Ändern, Verlegen oder Löschen.');
    if (!list.length) { const p = document.createElement('p'); p.className = 'small'; p.textContent = 'Noch nichts gemeldet.'; box.appendChild(p); }
    for (const x of list) dlgButton(box, `${msgLabel(x)} ${hhmm(x.t)}${x.lat != null ? ' 📍' : ''}${x.txt ? ` – ${esc(x.txt)}` : ''}${x.ed ? ' ✏️' : ''}${seen.has(x.id) ? ' ✓ gesehen' : ''}${x.rej ? ' ⚠️ nicht zugestellt' : ''}`, 'my-msg', () => close(x));
    dlgButton(box, 'Schließen', 'primary', () => close(null));
  });
  if (m) hfMsgDialog(m);
}
// Standort im Moment der Meldung: bis 10 s auf ≤ 30 m warten, sonst der beste Wert; ohne GPS null
function getFix(maxWait = 10000) {
  // läuft die Standortanzeige schon (z. B. seit dem Auftrag, v116) und der letzte Wert ist frisch und genau, gilt er sofort
  if (watchId !== null && lastFix && Date.now() - lastFix.t < 30000 && lastFix.acc <= 30) return Promise.resolve({ lat: lastFix.lat, lon: lastFix.lon, acc: lastFix.acc });
  return new Promise((res) => {
    let best = null;
    let done = false;
    let id = null;
    let timer = null;
    const fin = () => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      if (id !== null) navigator.geolocation.clearWatch(id);
      res(best || (lastPos ? { lat: lastPos[0], lon: lastPos[1] } : null));
    };
    if (!navigator.geolocation) return fin();
    id = navigator.geolocation.watchPosition((pos) => {
      const c = pos.coords;
      if (!best || c.accuracy < best.acc) best = { lat: c.latitude, lon: c.longitude, acc: c.accuracy };
      if (c.accuracy <= 30) fin();
    }, () => fin(), { enableHighAccuracy: true, maximumAge: 0, timeout: maxWait });
    timer = setTimeout(fin, maxWait);
  });
}
async function sendStatus(o) {
  const p = P;
  const h = p.hf;
  if (!h) return;
  let pos = NO_POS.includes(o.s) ? null : o.pos;
  if (pos === undefined) {
    toast('📍 Standort wird bestimmt … (bis 10 s)', 11000);
    pos = await getFix();
  }
  if (o.s === 'start') delete h.closed; // wieder losgegangen: nicht mehr „abgeschlossen“
  const m = buildMsg({ a: h.id, tm: h.team, s: o.s, cat: o.cat, txt: o.txt, pc: o.pc, ar: o.ar, gb: o.gb, ref: o.ref, ty: h.ty, pos });
  if (!h.ls) {
    h.log = [...h.log, { ...m }].slice(-100);
    p.updated = Date.now();
    const saved = saveNow();
    renderStatusBtn();
    redraw();
    if (o.quiet) return 'saved';
    return toast(saved ? `${msgLabel(m)} gespeichert – geht mit der nächsten QR-Rückmeldung an die Einsatzleitung` : `⚠️ ${msgLabel(m)} NICHT gespeichert – Speicher voll`, 6000);
  }
  h.outbox.push(m);
  h.log = [...h.log, { ...m }].slice(-100);
  p.updated = Date.now();
  saveNow();
  renderStatusBtn();
  redraw();
  if (!o.quiet) toast(`${msgLabel(m)} – wird gesendet${pos || NO_POS.includes(m.s) ? '' : ' (ohne Standort)'} …`, 4000);
  await flushStatus();
  const queued = h.outbox.some((x) => x.id === m.id);
  const rej = (h.log.find((x) => x.id === m.id) || {}).rej; // v118: vom Server abgelehnt (flushStatus hat schon gewarnt)
  if (rej) return o.quiet ? 'rejected' : undefined;
  if (o.quiet) return queued ? 'queued' : 'sent'; // der Aufrufer zeigt seinen eigenen Hinweis
  toast(queued ? `⏳ ${msgLabel(m)}: wartet auf Netz – wird automatisch nachgesendet` : `✓ ${msgLabel(m)} gesendet ${hhmm(Date.now())}`, 5000);
}
// Warteschlange aller Aufträge senden (sofort, bei „online“, alle 60 s, beim Start)
async function flushStatus() {
  if (locked) return;
  if (flushBusy) { flushAgain = true; return; }
  flushBusy = true;
  try {
    do {
      flushAgain = false;
      for (const p of Object.values(db.projects)) {
        const l = p.live;
        if (l && l.outbox && l.outbox.length) { // v117: Quittungen/Nachrichten der Einsatzleitung
          const r = await flushOutbox([l.url, l.key], l.outbox);
          if (r.sent.length || r.rejected.length) { l.outbox = r.left; saveNow(); } // v118: abgelehnte fliegen raus (nur ein Zusatz der EL, kein Protokolleintrag)
          for (const x of r.rejected) { const o = (l.out || []).find((q) => q.id === x.id); if (o) o.rej = x.reason; }
          if (r.rejected.length) toast(`⚠️ Meldung vom Server abgelehnt: ${r.rejected[0].reason}`, 7000);
        }
        const h = p.hf;
        if (!h || !h.ls || !h.outbox.length) continue;
        const r = await flushOutbox(h.ls, h.outbox);
        if (!r.sent.length && !r.rejected.length) continue;
        h.outbox = r.left;
        for (const id of r.sent) { const l = h.log.find((x) => x.id === id); if (l) l.ok = Date.now(); }
        // v118: vom Server dauerhaft abgelehnt: im Protokoll markieren, nicht endlos wiederholen
        for (const x of r.rejected) { const l = h.log.find((q) => q.id === x.id); if (l) l.rej = x.reason; }
        saveNow();
        if (r.rejected.length) toast(`⚠️ Meldung vom Server abgelehnt: ${r.rejected[0].reason}`, 7000);
      }
    } while (flushAgain);
  } catch { /* nächster Versuch */ } finally { flushBusy = false; }
  renderStatusBtn();
  if (!$('dlg').hidden && $('dlg-box').querySelector('.st-line')) updateStatusLine();
  if (db.mode === 'el' && P && !$('panel-status').hidden) renderStatusPanel();
}
// v130: Karte auf eine Punktmenge (Zusatz der EL) zoomen
function showPts(pts) {
  const ok = (pts || []).filter((q) => q && Number.isFinite(q[0]) && Number.isFinite(q[1]));
  if (!ok.length) return;
  closePanels();
  if (ok.length === 1) map.setView(ok[0], Math.max(map.getZoom(), 16));
  else map.fitBounds(ok, { padding: [60, 60], maxZoom: 17 });
}
// ---- v117: Hundeführer holt Quittungen und Nachrichten der Einsatzleitung ab ----
let hfPollBusy = false;
let elPrioOpen = false;
const hfElMsgs = () => (P && P.hf && P.hf.inbox ? P.hf.inbox.filter((m) => m.s === 'el') : []);
const hfElUnread = () => hfElMsgs().filter((m) => !(P.hf.elRead || {})[m.id]);
// Roter Punkt an ✉️ in der Auftragskarte und im Menü
function renderHfMsgBtn() {
  const on = db.mode === 'hf' && !!P && !!P.hf && !!P.hf.ls;
  const n = on ? hfElUnread().length : 0;
  for (const id of ['hfi-msg', 'hfm-msgs']) { $(id).hidden = !on; $(id).classList.toggle('dot', n > 0); }
  $('hfm-reply').hidden = !(db.mode === 'hf' && !!P && !!P.hf); // v125: schreiben geht auch ohne Status-Server (mit der QR-Rückmeldung)
  $('hfm-msgs').textContent = `✉️ Nachrichten der Einsatzleitung${hfElMsgs().length ? ` (${hfElMsgs().length})` : ''}`;
}
// Lesebestätigung an die Einsatzleitung: über die normale Warteschlange, aber nicht im eigenen Protokoll (und damit nicht in QR/GPX/Abschluss)
function sendReadAck(ids) {
  const h = P && P.hf;
  if (!h || !h.ls) return;
  const now = Date.now();
  for (const ref of ids) {
    if (h.elRead[ref]) continue;
    h.elRead[ref] = now;
    h.outbox.push(buildReadAck({ a: h.id, tm: h.team, ref }));
  }
  P.updated = now;
  saveNow();
  renderHfMsgBtn();
  renderStatusBtn();
  flushStatus();
}
async function pollHf() {
  const proj = P;
  const h = proj && proj.hf;
  if (locked || db.mode !== 'hf' || !h || !h.ls || hfPollBusy || document.hidden || !navigator.onLine) return;
  hfPollBusy = true;
  try {
    // erster Abruf: ab Auftragsübernahme minus 10 min, nicht der ganze Raum (7 Tage)
    const since = h.since || Math.max(0, (h.received || Date.now()) - 10 * 60e3);
    const r = await pollMessages({ url: h.ls[0], key: h.ls[1], since });
    const mine = forHf(r.msgs, h.id);
    const known = new Set(h.inbox.map((m) => m.id));
    const fresh = mine.filter((m) => !known.has(m.id));
    h.since = r.since;
    if (fresh.length) {
      h.inbox = mergeStatus(h.inbox, fresh).slice(-200);
      proj.updated = Date.now();
      // einmaliger Hinweis, wenn Fund/Hilfe gesehen wurde
      const urgentIds = new Set(hfLog().filter((m) => isUrgent(m)).map((m) => m.id));
      if (fresh.some((m) => m.s === 'q' && urgentIds.has(m.ref))) toast('✓ von der Einsatzleitung gesehen', 6000);
      const els = fresh.filter((m) => m.s === 'el');
      // v130: Zusätze (Punkte, Umrisse, Orte …) auf die Karte übernehmen
      const zs = els.filter(isZusatz);
      const zpts = [];
      for (const m of zs) { const r = applyZusatz(proj, m); if (r) zpts.push(...r.pts); }
      if (zs.length && proj === P) { redraw(); renderPois(); renderMeet(); }
      if (zs.length && proj === P) {
        const last = zs[zs.length - 1];
        toastAction(`📍 Einsatzleitung: ${last.txt || ''}`.replace('📍 Einsatzleitung: 📍 ', '📍 Einsatzleitung: '), '🗺️ Zeigen', () => showPts(zpts), 15000);
      } else if (els.length) {
        const last = els[els.length - 1];
        toast(`✉️ Einsatzleitung: ${last.txt || ''}`, 8000);
      }
    }
    saveNow();
    renderHfMsgBtn();
  } catch { /* kein Netz oder Server weg: nächster Versuch */ } finally { hfPollBusy = false; }
  showElPrio();
}
// Wichtige Nachricht: Ton, Vibration, Fenster bleibt bis „Verstanden“; erst danach geht die Lesebestätigung raus
async function showElPrio() {
  if (elPrioOpen || db.mode !== 'hf' || !P || !P.hf || !P.hf.ls) return;
  const todo = hfElUnread().filter((m) => m.prio);
  if (!todo.length) return;
  if (!$('dlg').hidden) return setTimeout(showElPrio, 4000);
  elPrioOpen = true;
  const proj = P;
  beep();
  const beeper = setInterval(beepShort, 15000);
  await openDlg((box, close) => {
    dlgHead(box, `✉️ Wichtig von der Einsatzleitung (${todo.length})`, 'Diese Nachricht bleibt, bis du sie als verstanden bestätigst.');
    for (const m of todo) {
      const d = document.createElement('div');
      d.className = 'st-urgent';
      d.textContent = `${hhmm(m.t)}${m.to === EL_ALL ? ' (an alle)' : ''}: ${m.txt || ''}`;
      box.appendChild(d);
    }
    dlgButton(box, '✓ Verstanden', 'primary', () => close(true));
  });
  clearInterval(beeper);
  elPrioOpen = false;
  if (proj === P) sendReadAck(todo.map((m) => m.id));
  showElPrio();
}
// ✉️: Liste der Nachrichten (neueste oben); ungelesene gewöhnliche gelten damit als gelesen
async function hfElList() {
  if (!P.hf || !P.hf.ls) return;
  const list = [...hfElMsgs()].reverse();
  const fresh = new Set(hfElUnread().map((m) => m.id));
  sendReadAck(hfElUnread().filter((m) => !m.prio).map((m) => m.id));
  const go = await openDlg((box, close) => {
    dlgHead(box, `✉️ Nachrichten der Einsatzleitung (${list.length})`, list.length ? '' : 'Noch keine Nachrichten.');
    for (const m of list) {
      const d = document.createElement('div');
      d.className = `hf-el${m.prio ? ' prio' : ''}${fresh.has(m.id) ? ' unread' : ''}`;
      d.innerHTML = '<b></b><span></span><small></small>';
      d.querySelector('b').textContent = `${hhmm(m.t)}${m.prio ? ' · ❗ wichtig' : ''}`;
      d.querySelector('span').textContent = m.txt || '';
      d.querySelector('small').textContent = m.to === EL_ALL ? 'an alle' : '';
      d.querySelector('small').hidden = m.to !== EL_ALL;
      // v125: direkt antworten
      const rb = document.createElement('button');
      rb.type = 'button';
      rb.className = 'mini';
      rb.textContent = '✍️ Antworten';
      rb.addEventListener('click', () => close({ reply: m.id }));
      d.appendChild(rb);
      if (isZusatz(m)) { // v130: Zusatz -> auf der Karte zeigen
        const zb = Object.assign(document.createElement('button'), { type: 'button', className: 'mini', textContent: '🗺️ Zeigen' });
        zb.addEventListener('click', () => close({ show: m.id }));
        d.appendChild(zb);
      }
      box.appendChild(d);
    }
    dlgButton(box, '✍️ Neue Nachricht an die EL', '', () => close({ reply: '' }));
    dlgButton(box, 'Schließen', 'primary', () => close(true));
  });
  if (go && go.reply !== undefined) return hfReply(go.reply || null);
  if (go && go.show) { const m = hfElMsgs().find((x) => x.id === go.show); const r = m && applyZusatz(P, m); if (r) { redraw(); renderPois(); renderMeet(); showPts(r.pts); } return; }
  if (go) showElPrio();
}
// v125: Hundeführer schreibt der Einsatzleitung (Freitext oder Schnellwahl), optional als Antwort auf eine EL-Nachricht (ref)
async function hfReply(ref = null) {
  if (!P.hf) return toast('Noch kein Auftrag – erst den QR-Code der Einsatzleitung scannen');
  const proj = P;
  const refMsg = ref ? hfElMsgs().find((m) => m.id === ref) : null;
  const txt = await openDlg((box, close) => {
    dlgHead(box, '✍️ Nachricht an die Einsatzleitung', refMsg ? `↩︎ Antwort auf: „${refMsg.txt || ''}“` : P.hf.ls ? 'Geht sofort an die Einsatzleitung (ohne Netz: sobald wieder Empfang ist).' : 'Dieser Auftrag hat keinen Status-Server: die Nachricht geht mit der nächsten QR-Rückmeldung mit.');
    const list = document.createElement('div');
    list.className = 'dlg-btns two';
    box.appendChild(list);
    for (const q of QUICK_REPLIES) dlgButton(list, esc(q), '', () => close(q));
    const inp = document.createElement('textarea');
    inp.id = 'hf-reply-txt';
    inp.rows = 3;
    inp.maxLength = 300;
    inp.placeholder = 'Text an die Einsatzleitung …';
    inp.style.cssText = 'width:100%;margin-top:8px';
    box.appendChild(inp);
    dlgButton(box, '📤 Senden', 'primary', () => (inp.value.trim() ? close(inp.value.trim()) : toast('Bitte einen Text eintragen oder eine Schnellwahl antippen')));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!txt || proj !== P) return;
  sendStatus({ s: 'msg', txt, ref: refMsg ? refMsg.id : undefined });
}
$('hfm-reply').addEventListener('click', () => { closePanels(); hfReply(null); });
$('hfi-msg').addEventListener('click', (e) => { e.stopPropagation(); hfElList(); });
$('hfm-msgs').addEventListener('click', () => { closePanels(); hfElList(); });

function statusLine() {
  const h = P.hf;
  if (!h.ls) return 'Kein Status-Server in diesem Auftrag: Meldungen gehen mit der nächsten QR-Rückmeldung mit.';
  const n = h.outbox.length;
  const ok = [...h.log].reverse().find((x) => x.ok);
  const rej = h.log.filter((x) => x.rej).length;
  return n ? `⏳ wartet auf Netz (${n})` : rej && h.log[h.log.length - 1].rej ? '⚠️ nicht zugestellt (vom Server abgelehnt)' : ok ? `✓ gesendet ${hhmm(ok.t)}` : 'Noch nichts gemeldet';
}
function updateStatusLine() { const l = $('dlg-box').querySelector('.st-line'); if (l) l.textContent = statusLine(); }
const confirmSend = (label) => openDlg((box, close) => {
  dlgHead(box, 'Wirklich senden?', `${label} geht sofort mit deinem Standort an die Einsatzleitung.`);
  dlgButton(box, 'Senden', 'primary', () => close(true));
  dlgButton(box, 'Abbrechen', '', () => close(false));
});
async function openStatusDialog() {
  if (!hasLive()) return;
  const code = await openDlg((box, close) => {
    dlgHead(box, '📣 Status melden', `${P.hf.team} – Suchstand ohne Standort; Anzeige, Fund, Hilfe unter „📍 Standort melden“`);
    const line = document.createElement('p');
    line.className = 'st-line';
    line.textContent = statusLine();
    box.appendChild(line);
    const list = document.createElement('div');
    list.className = 'dlg-btns two';
    box.appendChild(list);
    for (const s of STATUS_LIST) dlgButton(list, `${s.ico} ${s.label}`, '', () => close(s.code));
    dlgButton(list, `${RELIEF_STATUS.ico} ${RELIEF_STATUS.label}`, '', () => close(RELIEF_STATUS.code)); // v128: Ablösung
    dlgButton(box, `${CLOSE_STATUS.ico} Auftrag abschließen`, '', () => close('zu')); // getrennt vom Stand: auch bei 80 % beenden/abbrechen
    dlgButton(box, '📍 Standort melden', 'primary', () => close('ort'));
    dlgButton(box, `🗂 Meine Meldungen (${hfLog().length})`, '', () => close('mine'));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!code) return;
  if (code === 'mine') return hfMyList();
  if (code === 'ort') return spotDialog();
  if (code === 'fertig') return doneDialog();
  if (code === 'zu') return closeDialog();
  if (code === 'da') return parkDialog();
  if (isUrgent({ s: code }) && !(await confirmSend(statusLabel(code)))) return;
  // Suche begonnen/beendet: bei mehreren Gebieten wählen, für welche (eins, mehrere oder alle)
  let gb;
  if (['start', 'ende'].includes(code) && hfAreas().length > 1) {
    gb = await areaPick(statusLabel(code));
    if (!gb) return;
  }
  sendStatus({ s: code, gb });
}
const statusLabel = (code) => msgLabel({ s: code });
// Gebiete auswählen (Häkchen, alle vorausgewählt) -> Namen oder null
function areaPick(title) {
  const areas = hfAreas();
  return openDlg((box, close) => {
    dlgHead(box, title, 'Für welche Gebiete?');
    const checks = areas.map((name) => {
      const l = document.createElement('label');
      l.className = 'check';
      l.innerHTML = '<input type="checkbox" checked><span></span>';
      l.lastChild.textContent = name;
      box.appendChild(l);
      return l.firstChild;
    });
    dlgButton(box, '📣 Melden', 'primary', () => {
      const sel = areas.filter((_, i) => checks[i].checked);
      if (!sel.length) return toast('Bitte mindestens ein Gebiet ankreuzen');
      close(sel);
    });
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
}
async function spotDialog() {
  const r = await openDlg((box, close) => {
    dlgHead(box, '📍 Standort melden', 'Art wählen, dann Ort: hier oder auf der Karte.');
    let cat = null; // keine Vorauswahl: erst bewusst eine Art wählen
    const list = document.createElement('div');
    list.className = 'dlg-btns two';
    box.appendChild(list);
    const btns = SPOT_LIST.map((s) => dlgButton(list, esc(spotLabel(s.code, P.hf.ty)), '', () => { // v128: „Trupp zeigt an“ je Einheitentyp
      cat = s.code;
      btns.forEach((b, i) => b.classList.toggle('sel', SPOT_LIST[i].code === cat));
      [here, onMap].forEach((b) => b.classList.remove('off'));
    }));
    const txt = document.createElement('input');
    txt.type = 'text';
    txt.placeholder = 'Kurzer Text (optional)';
    txt.style.marginTop = '8px';
    box.appendChild(txt);
    // v127: Textvorschläge je Art (Fundstück: Jacke, Schuh, Mütze, Rucksack) als Knöpfe über dem Textfeld
    const hints = document.createElement('div');
    hints.className = 'dlg-btns two';
    hints.id = 'spot-hints';
    box.insertBefore(hints, txt);
    const showHints = () => {
      hints.innerHTML = '';
      for (const h of SPOT_HINTS[cat] || []) dlgButton(hints, h, '', () => { txt.value = h; });
    };
    list.addEventListener('click', showHints);
    const send = (here) => () => (cat ? close({ cat, txt: txt.value.trim(), here }) : toast('Bitte erst auswählen, was gemeldet wird'));
    const here = dlgButton(box, '📍 Hier melden', 'primary off', send(true));
    const onMap = dlgButton(box, '👆 Auf Karte tippen', 'off', send(false));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!r) return;
  if (URGENT.includes(r.cat) && !(await confirmSend(spotLabel(r.cat)))) return;
  if (!r.here) {
    pendingSpot = { cat: r.cat, txt: r.txt };
    setTool('hfspotpt');
    return toast('Auf die Karte tippen: dort wird der Standort gemeldet', 6000);
  }
  sendStatus({ s: 'ort', cat: r.cat, txt: r.txt });
}
// 🅿️ Parkplatz Auto: geht mit Ort – eigener Standort oder auf der Karte angetippt
async function parkDialog() {
  const here = await openDlg((box, close) => {
    dlgHead(box, '🅿️ Parkplatz Auto', 'Wo steht das Auto? Der Ort geht mit der Meldung an die Einsatzleitung.');
    dlgButton(box, '📍 Mein Standort (hier)', 'primary', () => close(true));
    dlgButton(box, '👆 Auf der Karte setzen', '', () => close(false));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (here == null) return;
  if (!here) {
    pendingSpot = { s: 'da' };
    setTool('hfspotpt');
    return toast('Auf die Karte tippen: dort steht das Auto', 6000);
  }
  sendStatus({ s: 'da' });
}
// Gebiete des Auftrags (Hundeführer): Rastergebiete und geschlossene Umrisse der Einsatzleitung
function hfAreas() {
  const out = allGrids(P).map((g) => gridLabel(P, g));
  let n = 0;
  for (const it of P.items) if (it.fromEl && !it.prev && it.kind === 'track' && !it.open && (it.pts || []).length > 2) out.push(it.name || `Umriss ${++n}`);
  return [...new Set(out)];
}
// Regler je Gebiet (bzw. ein Regler), vorausgefüllt mit dem letzten Stand (Stand- oder Abschluss-Meldung) -> [{ name, rng }]
function pctRows(box, areas, multi, dflt = 50) {
  const prev = [...hfLog()].reverse().find((m) => m.s === 'fertig' || m.s === 'zu');
  const was = (name) => { const x = prev && (prev.ar || []).find((q) => q[0] === name); return x ? x[1] : prev && !multi && prev.pc != null ? prev.pc : dflt; };
  return (multi ? areas : ['']).map((name) => {
    const big = document.createElement('div');
    big.className = 'st-pct';
    const rng = document.createElement('input');
    rng.type = 'range';
    rng.className = 'st-range';
    rng.min = 0; rng.max = 100; rng.step = 10;
    rng.value = Math.round(was(name) / 10) * 10;
    const show = () => { big.textContent = `${name ? `${name}: ` : ''}${Number(rng.value) >= 100 ? '100 % – ✅ fertig' : `${rng.value} % abgesucht`}`; };
    rng.addEventListener('input', show);
    show();
    box.append(big, rng);
    return { name, rng };
  });
}
// Reglerwerte als Meldungsfelder: { ar (nur bei mehreren Gebieten), pc (kleinster Wert) }
const pctResult = (rows, multi, txt) => ({
  ...(multi ? { ar: rows.map((x) => [x.name, Number(x.rng.value)]) } : {}),
  pc: Math.min(...rows.map((x) => Number(x.rng.value))), txt: txt.value.trim(),
});
// Stand melden: der Hundeführer schätzt selbst, wie viel abgesucht ist (100 % = fertig) – bei mehreren Gebieten je Gebiet
async function doneDialog() {
  const areas = hfAreas();
  const multi = areas.length > 1;
  const r = await openDlg((box, close) => {
    dlgHead(box, '📊 Stand melden', multi ? 'Wie viel ist je Gebiet abgesucht? 100 % = Gebiet fertig.' : 'Wie viel vom Gebiet hast du abgesucht? Erst 100 % meldet „Gebiet fertig“.');
    const rows = pctRows(box, areas, multi);
    const txt = document.createElement('input');
    txt.type = 'text';
    txt.placeholder = 'Grund / Hinweis (optional)';
    txt.style.marginTop = '8px';
    box.appendChild(txt);
    dlgButton(box, '📣 Melden', 'primary', () => close(pctResult(rows, multi, txt)));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!r) return;
  sendStatus({ s: 'fertig', pc: r.pc, ar: r.ar, txt: r.txt });
}
// ✅ Auftrag abschließen: Rückfrage mit Stand je Gebiet (auch unter 100 %) und optionalem Grund; danach gleich 📤 Zurückgeben
async function closeDialog() {
  const areas = hfAreas();
  const multi = areas.length > 1;
  const r = await openDlg((box, close) => {
    dlgHead(box, '✅ Auftrag abschließen?', `${multi ? 'Wie viel ist je Gebiet abgesucht?' : 'Wie viel vom Gebiet ist abgesucht?'} Der Auftrag darf auch bei weniger als 100 % beendet oder abgebrochen werden.`);
    const rows = pctRows(box, areas, multi, 100); // zuletzt gemeldeter Stand, ohne Stand 100 %
    const txt = document.createElement('input');
    txt.type = 'text';
    txt.placeholder = `Grund, z. B. ${P.hf.ty === 'drohne' ? 'Akku leer' : P.hf.ty && P.hf.ty !== 'hund' ? 'Erschöpfung' : 'Hund müde'}, Dunkelheit (optional)`;
    txt.style.marginTop = '8px';
    box.appendChild(txt);
    dlgButton(box, '✅ Abschließen', 'primary', () => close(pctResult(rows, multi, txt)));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!r) return;
  P.hf.closed = Date.now();
  sendStatus({ s: 'zu', pc: r.pc, ar: r.ar, txt: r.txt }); // Meldung wandert sofort in Log/Warteschlange, geht auch mit der QR-Rückmeldung mit
  renderHfInfo();
  await showBack();
}
$('hf-status').addEventListener('click', openStatusDialog);

// ---- v98: Team-Chips, Ungelesen, Erinnerung, Status-Verlauf (Einsatzleitung) ----
const isTablet = () => window.matchMedia('(min-width: 700px)').matches;
const teamKeyOf = (a) => { const x = (P.sent || []).find((q) => q.id === a); return x ? x.teamId || `n:${x.team || ''}` : ''; };
const areasText = (x) => [...sentAreas(x).keys()].join(' + ') || x.what || '';
const unreadNow = () => (db.mode === 'el' && P ? unreadMsgs(allMsgs(), P.msgSeen, P.msgRecv) : []);
function readMsgs(list) {
  const l = list || unreadNow();
  if (!l.length) return;
  markSeen(P.msgSeen, l);
  prune(P.msgSeen);
  ackSeen(l); // v117: Lesebestätigung an den Hundeführer
  saveNow();
}
let tbSig = '';
let lastChips = [];
let unreadOpen = false;
let lastBeepAt = null;
let popChip = null;
let stFilter = '';
let stFresh = new Set();

// Gebiet eines Auftrags als Punkte (Felder des Teams, Raster, Umrisse) – für „Karte springt dorthin“
function sentPoints(x) {
  const pts = [];
  for (const g of allGrids(P).filter((q) => (x.grids || []).includes(q.id))) {
    const gr = makeGrid(g.area, g.cellM);
    const keys = Object.keys(g.fills).filter((k) => g.fills[k] === x.teamId);
    if (!keys.length) { pts.push([g.area.north, g.area.west], [g.area.south, g.area.east]); continue; }
    for (const k of keys) { const [c, r] = k.split(',').map(Number); const b = cellBounds(gr, c, r); pts.push([b.north, b.west], [b.south, b.east]); }
  }
  for (const id of x.items || []) {
    const it = P.items.find((q) => q.id === id);
    if (it && it.pts) for (const q of it.pts) pts.push([q[0], q[1]]);
  }
  if (!pts.length && x.ctr) pts.push(x.ctr);
  return pts;
}
function jumpToChip(c) {
  const x = (P.sent || []).find((q) => q.id === c.a);
  const pts = x ? sentPoints(x) : [];
  if (!pts.length) return;
  const b = L.latLngBounds(pts);
  if (b.getNorth() - b.getSouth() < 1e-5 && b.getEast() - b.getWest() < 1e-5) map.setView(b.getCenter(), 17);
  else map.fitBounds(b, { maxZoom: 17, paddingTopLeft: [76, 70], paddingBottomRight: [84, 150] });
}

function chipEl(c, unread, blink) {
  const b = document.createElement('button');
  b.type = 'button';
  b.className = `tchip${c.wait ? ' wait' : ''}${c.urgent ? ' urgent' : ''}${unread ? ' unread' : ''}${blink ? ' blink' : ''}`;
  b.style.setProperty('--tc', c.color);
  b.dataset.team = c.key;
  b.innerHTML = '<i></i><span></span>';
  b.querySelector('span').textContent = `${c.ty && c.ty !== 'hund' ? `${c.ico} ` : ''}${chipText(c)}`; // v128: Typ-Symbol (außer Hund)
  b.title = chipText(c);
  b.addEventListener('click', () => chipTap(c));
  return b;
}
function chipTap(c) {
  readMsgs(unreadNow().filter((m) => teamKeyOf(m.a) === c.key));
  jumpToChip(c);
  popChip = c;
  tbSig = '';
  renderTeamBar();
  renderPop();
}
// Tablet: so viele Chips wie passen, Rest als „+n“
let chipsW = 0;
function paintChips() {
  const box = $('teamchips');
  box.innerHTML = '';
  if (!isTablet() || db.mode !== 'el' || !lastChips.length) { box.hidden = true; return; }
  box.hidden = false;
  const MORE = 56;
  // feste Team-Reihenfolge; passen nicht alle hin, rücken Teams mit ungequittiertem Fund/Hilfe nach vorn
  const fit = (list) => {
    const els = list.map((q) => chipEl(q.c, q.unread, q.blink));
    els.forEach((e) => box.appendChild(e));
    chipsW = box.clientWidth;
    const ws = els.map((e) => e.offsetWidth + 6);
    let k = els.length;
    const sum = (n) => ws.slice(0, n).reduce((a, b) => a + b, 0);
    while (k > 1 && sum(k) + (k < els.length ? MORE : 0) > chipsW) k--;
    return { els, k };
  };
  let shown = lastChips;
  let { els, k } = fit(shown);
  if (k < els.length && lastChips.some((q) => q.c.todo)) {
    box.innerHTML = '';
    const first = todoFirst(lastChips.map((q) => q.c));
    shown = first.map((c) => lastChips.find((q) => q.c === c));
    ({ els, k } = fit(shown));
  }
  if (k < els.length) {
    const hidden = shown.slice(k);
    els.slice(k).forEach((e) => e.remove());
    const more = document.createElement('button');
    more.type = 'button';
    more.className = `tchip more${hidden.some((q) => q.unread) ? ' unread' : ''}`;
    more.textContent = `+${hidden.length}`;
    more.title = hidden.map((q) => chipText(q.c)).join('\n');
    more.addEventListener('click', () => openStatusPanel(''));
    box.appendChild(more);
  }
}
new ResizeObserver(() => { if ($('teamchips').clientWidth !== chipsW && lastChips.length) paintChips(); }).observe($('teamchips'));

function unreadRows(box, ur) {
  const h = document.createElement('h3');
  h.textContent = `📣 Ungelesene Meldungen (${ur.length})`;
  box.appendChild(h);
  for (const m of [...ur].reverse()) {
    const d = document.createElement('div');
    d.className = 'tm-ur';
    d.style.setProperty('--tc', teamColorOf(m.a));
    d.innerHTML = '<b></b><span></span><time></time>';
    d.querySelector('b').textContent = m.tm || 'Team';
    d.querySelector('span').textContent = `${msgLabel(m)}${m.txt ? ` – ${m.txt}` : ''}`;
    d.querySelector('time').textContent = hhmm(m.t);
    box.appendChild(d);
  }
  const n = document.createElement('p');
  n.className = 'tm-note';
  n.textContent = 'Tipp irgendwohin = gelesen';
  box.appendChild(n);
}
function renderTeamBar() {
  const el = db.mode === 'el' && !!P;
  const now = Date.now();
  const chips = el ? teamChips(P.sent, allMsgs(), P.marks, P.items, areasText, (P.live && P.live.ack) || []) : [];
  const ur = unreadNow();
  const cnt = $('st-count');
  cnt.hidden = !ur.length;
  cnt.textContent = ur.length;
  if (el && ur.length >= 2 && !unreadOpen && !(P.msgSnooze > now)) openUnread(); // mehrere ungelesene: Liste klappt auf
  if (!ur.length && unreadOpen) unreadOpen = false;
  const tab = isTablet();
  const urKeys = new Set(ur.map((m) => teamKeyOf(m.a)));
  const newKeys = new Set(ur.filter((m) => now - (P.msgRecv[m.id] || 0) < 30e3).map((m) => teamKeyOf(m.a)));
  const hasSent = el && (P.sent || []).length > 0;
  const sig = JSON.stringify([el, tab, db.teamsOpen, unreadOpen, hasSent, ur.map((m) => m.id),
    chips.map((c) => [c.key, c.status, c.areas, c.urgent, c.todo, c.wait, c.color, c.team, c.dog, c.ty, urKeys.has(c.key), newKeys.has(c.key)])]);
  if (sig === tbSig) return;
  tbSig = sig;
  lastChips = chips.map((c) => ({ c, unread: urKeys.has(c.key), blink: newKeys.has(c.key) }));
  paintChips();
  // Handy: Knopf „📣 Teams“ + aufklappbare Liste
  const btn = $('tm-btn');
  btn.hidden = !hasSent;
  btn.classList.toggle('open', !!db.teamsOpen);
  const bn = $('tm-btn-n');
  bn.hidden = !ur.length;
  bn.textContent = ur.length;
  btn.classList.remove('blink');
  if (ur.length && !db.teamsOpen && !unreadOpen) { void btn.offsetWidth; btn.classList.add('blink'); }
  const list = $('tm-list');
  list.innerHTML = '';
  list.hidden = !(el && !tab && db.teamsOpen && !unreadOpen);
  if (!list.hidden) {
    if (!chips.length) { const p = document.createElement('p'); p.className = 'tm-note'; p.textContent = 'Keine laufenden Aufträge.'; list.appendChild(p); }
    for (const q of lastChips) list.appendChild(chipEl(q.c, q.unread, q.blink));
  }
  const box = $('tm-unread');
  box.innerHTML = '';
  box.hidden = !(el && unreadOpen);
  if (!box.hidden) unreadRows(box, ur);
  renderBanner(ur, now);
  if (popChip) { popChip = chips.find((q) => q.key === popChip.key) || popChip; renderPop(); }
}
// Liste der ungelesenen: ein Tipp irgendwohin schließt sie und markiert alles als gelesen
// (der zentrale Tipp-Listener „Tipp ins Leere“ weiter unten ruft closeUnread auf)
function openUnread() {
  if (unreadOpen) return;
  unreadOpen = true;
  tbSig = '';
}
function closeUnread() {
  if (!unreadOpen) return;
  unreadOpen = false;
  readMsgs();
  $('tm-unread').hidden = true;
  // Neuaufbau der Chips erst nach dem Tipp, sonst geht der Klick auf einen Chip verloren
  setTimeout(() => { tbSig = ''; renderTeamBar(); checkUnread(); }, 350);
}
// Handy: Reiter „📋 Aufträge“ neben „📣 Teams“ – Stand je Gebiet als aufklappbare Liste, Antippen zeigt das Gebiet
let ordOpen = false;
let ordSig = '';
function renderOrders(list) {
  const btn = $('ord-btn');
  const tb = $('tm-btn');
  btn.hidden = !list.length || tb.hidden;
  if (!btn.hidden) { const r = tb.getBoundingClientRect(); btn.style.left = `${r.right + 8}px`; btn.style.top = `${r.top}px`; }
  if (btn.hidden) ordOpen = false;
  btn.classList.toggle('open', ordOpen);
  const box = $('ord-list');
  const sig = JSON.stringify([ordOpen, list.map((b) => [b.lines, b.color, b.fin, b.done, b.wait])]);
  if (sig === ordSig) return;
  ordSig = sig;
  box.innerHTML = '';
  box.hidden = !ordOpen;
  if (!ordOpen) return;
  const run = list.filter((b) => !b.done);
  const fin = list.filter((b) => b.done);
  for (const b of [...run, ...fin]) {
    const r = document.createElement('button');
    r.type = 'button';
    r.className = `ord-row${b.done ? ' done' : ''}${b.wait ? ' wait' : ''}`;
    r.style.setProperty('--tc', b.done ? '#2e7d32' : b.color);
    const t = document.createElement('b');
    t.textContent = b.lines[0];
    const s = document.createElement('small');
    s.textContent = b.lines.slice(1).join(' · ');
    r.append(t, s);
    r.addEventListener('click', () => {
      ordOpen = false;
      ordSig = '';
      const [[s1, w1], [n1, e1]] = b.bnd;
      if (n1 === s1 && e1 === w1) map.setView([s1, w1], Math.max(map.getZoom(), 15));
      else map.fitBounds([[s1, w1], [n1, e1]], { padding: [60, 60], maxZoom: 17 });
      redraw();
    });
    box.appendChild(r);
  }
}
$('ord-btn').addEventListener('click', () => {
  ordOpen = !ordOpen;
  if (ordOpen && db.teamsOpen) { db.teamsOpen = false; saveNow(); tbSig = ''; renderTeamBar(); }
  ordSig = '';
  redraw();
});
$('tm-btn').addEventListener('click', () => {
  db.teamsOpen = !db.teamsOpen;
  if (db.teamsOpen && ordOpen) { ordOpen = false; ordSig = ''; redraw(); }
  saveNow();
  tbSig = '';
  renderTeamBar();
});
map.on('click', () => {
  closePop();
  if (!isTablet() && db.teamsOpen) { db.teamsOpen = false; saveNow(); tbSig = ''; renderTeamBar(); }
});

// Infofenster eines Chips: letzte 3 Meldungen des Teams
function closePop() { popChip = null; $('tm-pop').hidden = true; }
function renderPop() {
  const box = $('tm-pop');
  const c = popChip;
  if (!c || db.mode !== 'el') { box.hidden = true; return; }
  box.hidden = false;
  box.innerHTML = '';
  box.style.setProperty('--tc', c.color);
  const h = document.createElement('h3');
  const t = document.createElement('span');
  t.textContent = `${c.ty && c.ty !== 'hund' ? `${c.ico} ` : ''}${c.team}${c.dog ? ` (${c.dog})` : ''}${c.areas ? ` · ${c.areas}` : ''}`;
  const x = document.createElement('button');
  x.type = 'button';
  x.textContent = '✕';
  x.setAttribute('aria-label', 'Schließen');
  x.addEventListener('click', closePop);
  h.append(t, x);
  box.appendChild(h);
  const ids = new Set(c.teamId ? teamAssignments(P.sent, c.teamId) : [c.a]);
  const ms = allMsgs().filter((m) => ids.has(m.a)).slice(-3).reverse();
  if (!ms.length) { const p = document.createElement('div'); p.className = 'ln'; p.textContent = c.wait ? '📲 wartet auf Übernahme' : 'Noch keine Meldungen.'; box.appendChild(p); }
  for (const m of ms) {
    const d = document.createElement('div');
    d.className = `ln${isUrgent(m) ? ' urgent' : ''}`;
    d.textContent = `${hhmm(m.t)} · ${msgLabel(m)}${m.lat != null ? ' · 📍' : ''}${m.txt ? ` – ${m.txt}` : ''}${replyContext(m, elMsgsAll()) ? ` · ${replyContext(m, elMsgsAll())}` : ''}`;
    box.appendChild(d);
  }
  if (canEnter() && c.a) {
    const fb = document.createElement('button');
    fb.type = 'button';
    fb.className = 'all funk-btn';
    fb.textContent = '✍️ Meldung eintragen';
    fb.addEventListener('click', () => { closePop(); funkDialog(c.a); });
    box.appendChild(fb);
  }
  const all = document.createElement('button');
  all.type = 'button';
  all.className = 'all';
  all.textContent = 'Alle Meldungen';
  all.addEventListener('click', () => { closePop(); openStatusPanel(c.teamId || ''); });
  box.appendChild(all);
  // v117: Nachricht an dieses Team (Status-Panel mit vorgewähltem Empfänger)
  const tg = canElSend() ? elTargets(P.sent, P.marks).find((q) => (c.teamId ? q.teamId === c.teamId : q.a === c.a)) : null;
  if (tg) {
    const msg = document.createElement('button');
    msg.type = 'button';
    msg.className = 'all el-msg';
    msg.textContent = '✉️ Nachricht';
    msg.addEventListener('click', () => { closePop(); elPreTo = tg.a; openStatusPanel(c.teamId || ''); setTimeout(() => $('el-txt').focus(), 100); });
    box.appendChild(msg);
  }
}

// ---- Erinnerung: Banner, Piepton, Schlummern ----
async function snoozeDialog() {
  const min = await openDlg((box, close) => {
    dlgHead(box, '💤 Erinnerung schlummern', 'Banner und Piepton ruhen. Fund und Hilfe kommen weiter sofort. Neue Meldungen blinken trotzdem am Chip.');
    const inp = document.createElement('input');
    inp.type = 'text';
    inp.inputMode = 'numeric';
    inp.id = 'snooze-min';
    inp.className = 'dlg-snz';
    inp.placeholder = 'Minuten';
    inp.value = '10';
    inp.autocomplete = 'off';
    box.appendChild(inp);
    const row = document.createElement('div');
    row.className = 'dlg-btns two';
    for (const n of SNOOZE_PICKS) {
      const b = document.createElement('button');
      b.textContent = `${n} min`;
      b.addEventListener('click', () => close(n));
      row.appendChild(b);
    }
    box.appendChild(row);
    dlgButton(box, '💤 Schlummern', 'primary', () => {
      const n = parseSnooze(inp.value);
      if (n == null) { inp.style.borderColor = '#d50000'; toast('Bitte Minuten als Zahl eingeben (1 – 720)'); return; }
      close(n);
    });
    dlgButton(box, 'Abbrechen', '', () => close(0));
  });
  if (!min) return;
  P.msgSnooze = snoozeUntilFrom(Date.now(), min);
  saveNow();
  toast(`${snoozeText(P.msgSnooze)} – Erinnerung ruht`);
  checkUnread();
  renderStatusPanel();
}
function unsnooze() {
  P.msgSnooze = 0;
  saveNow();
  checkUnread();
  renderStatusPanel();
}
let bannerSig = '';
function renderBanner(ur, now) {
  const b = $('tm-banner');
  const snoozed = !!P && P.msgSnooze > now;
  const al = unreadAlert(ur, P ? P.msgRecv : {}, now, P ? P.msgSnooze : 0, lastBeepAt);
  if (!(db.mode === 'el' && !unreadOpen && ur.length && (snoozed || al !== 'none'))) { b.hidden = true; bannerSig = ''; return al; }
  const text = snoozed ? `${snoozeText(P.msgSnooze)} · ${ur.length} ungelesen` : bannerText(ur.length, unreadAge(ur, P.msgRecv, now));
  const sig = `${snoozed}|${text}`;
  b.hidden = false;
  if (sig === bannerSig) return al;
  bannerSig = sig;
  b.classList.toggle('calm', snoozed);
  b.innerHTML = '<span></span><button type="button"></button>';
  b.querySelector('span').textContent = text;
  const btn = b.querySelector('button');
  btn.textContent = snoozed ? 'Aufheben' : '💤 Schlummern';
  btn.addEventListener('click', (e) => { e.stopPropagation(); if (snoozed) unsnooze(); else snoozeDialog(); });
  return al;
}
$('tm-banner').addEventListener('click', () => { openUnread(); renderTeamBar(); });
// Alle 15 s (und nach jedem Abholen): Banner / Piepton nach Regel
function checkUnread() {
  if (locked) return;
  if (db.mode !== 'el' || !P) { $('tm-banner').hidden = true; return; }
  const now = Date.now();
  if (P.msgSnooze && P.msgSnooze <= now) P.msgSnooze = 0;
  const ur = unreadNow();
  if (!ur.length) lastBeepAt = null;
  const al = renderBanner(ur, now);
  if (al === 'beep') { lastBeepAt = now; beepShort(); }
}

// ---- Verlauf: Kachel „📣 Status“ ----
function renderStatusPanel() {
  if (!P) return;
  const sel = $('st-filter');
  const teams = historyTeams(P.sent, P.marks);
  if (stFilter && !teams.some((t) => t.id === stFilter)) stFilter = '';
  sel.innerHTML = '';
  for (const [v, l] of [['', 'Alle Teams'], ...teams.map((t) => [t.id, t.label])]) {
    const o = document.createElement('option');
    o.value = v;
    o.textContent = l;
    sel.appendChild(o);
  }
  sel.value = stFilter;
  const sz = $('st-snz');
  const now = Date.now();
  sz.hidden = !(P.msgSnooze > now);
  if (!sz.hidden) {
    sz.innerHTML = '<span></span><button type="button">Aufheben</button>';
    sz.querySelector('span').textContent = `${snoozeText(P.msgSnooze)} – Erinnerung ruht (Fund/Hilfe nicht)`;
    sz.querySelector('button').addEventListener('click', unsnooze);
  }
  renderElCompose();
  renderUaOverview(); // v128
  $('st-tools').hidden = !(db.mode === 'el' && !P.closed);
  const box = $('st-list');
  box.innerHTML = '';
  // v117: Nachrichten der Einsatzleitung (st-el) laufen in der Zeitleiste mit; mit Teamfilter nur die an dieses Team oder an alle
  const ids = stFilter ? new Set(teamAssignments(P.sent, stFilter)) : null;
  const els = P.live ? (liveInit(P.live).out).filter((m) => m.s === 'el' && (!ids || m.to === EL_ALL || ids.has(m.to))) : [];
  const elAll = elMsgsAll(); // v125: für „↩︎ Antwort auf …“
  const list = [...historyFilter(allMsgsK(), P.sent, stFilter), ...els].sort((a, b) => b.t - a.t);
  if (!list.length) { const p = document.createElement('p'); p.className = 'small'; p.textContent = 'Noch keine Meldungen.'; box.appendChild(p); }
  for (const m of list.slice(0, 300)) {
    if (m.s === 'el') { box.appendChild(elRow(m)); continue; }
    const x = (P.sent || []).find((q) => q.id === m.a);
    const team = x && P.marks.find((q) => q.id === x.teamId);
    const d = document.createElement('div');
    d.className = `st-row${isUrgent(m) && !m.gone ? ' urgent' : ''}${m.lat != null && !m.gone ? ' loc' : ''}${m.gone ? ' gone' : ''}${stFresh.has(m.id) ? ' unread' : ''}`;
    d.style.setProperty('--tc', team ? team.color : '#455a64');
    d.innerHTML = '<div class="tx"><b></b><span></span><br><small></small></div><button type="button" class="del" aria-label="Meldung löschen">🗑</button>';
    d.querySelector('b').textContent = `${team ? team.label : m.tm || 'Team'}${team && team.dog ? ` (${team.dog})` : ''}`;
    d.querySelector('span').textContent = `${msgLabel(m)}${m.lat != null ? ' 📍' : ''}${m.txt ? ` – ${m.txt}` : ''}`;
    const rc = replyContext(m, elAll); // v125
    d.querySelector('small').textContent = `${rc ? `${rc} · ` : ''}${[findStatusText(m), msgSource(m)].filter(Boolean).map((q) => `${q} · `).join('')}${hhmm(m.t)} (vor ${sinceText(m.t, now)})${m.gone ? ` · ↩ vom Team zurückgezogen ${hhmm(m.gone)}` : m.ed ? ` · ✏️ geändert ${hhmm(m.ed)}` : ''}`;
    if (m.gone) d.querySelector('span').style.textDecoration = 'line-through';
    if (m.lat != null && !m.gone) d.addEventListener('click', () => showStatusMark(m));
    d.querySelector('.del').addEventListener('click', (e) => { e.stopPropagation(); msgDialog(m, true); });
    if (isFind(m) && canEnter() && !m.gone) { // v128: Fund offen <-> geprüft
      const ft = document.createElement('button');
      ft.type = 'button';
      ft.className = 'del find-toggle';
      ft.textContent = m.fs === 'g' ? '⏳' : '✔';
      ft.title = m.fs === 'g' ? 'Wieder offen' : 'Als geprüft markieren';
      ft.addEventListener('click', (e) => { e.stopPropagation(); findToggle(m); });
      d.appendChild(ft);
      if (m.lat != null) { // v130.11: Prüfauftrag auch nachträglich an ein/mehrere Teams senden
        const sb = document.createElement('button');
        sb.type = 'button';
        sb.className = 'del find-send';
        sb.textContent = '📤';
        sb.title = 'An Team(s) senden';
        sb.addEventListener('click', (e) => { e.stopPropagation(); findSendDialog(m); });
        d.appendChild(sb);
      }
    }
    box.appendChild(d);
  }
}
// v125: alle Nachrichten der Einsatzleitung (eigene und von anderen EL-Geräten) für den Bezug einer Antwort
const elMsgsAll = () => (P.live ? [...liveInit(P.live).out, ...(P.live.msgs || []).filter((m) => m.s === 'el')] : []);
// v117: Zeile für eine Nachricht der Einsatzleitung: an wen, Text, wer sie gelesen hat
function teamNameOf(a) {
  const x = (P.sent || []).find((q) => q.id === a);
  const t = x && P.marks.find((q) => q.id === x.teamId);
  return t ? t.label : (x && x.team) || 'Team';
}
function elRow(m) {
  const targets = elTargets(P.sent, P.marks);
  const rs = readSummary(m, P.live.reads, targets);
  const wait = P.live.outbox.some((q) => q.id === m.id);
  const d = document.createElement('div');
  d.className = `st-row st-el${m.prio ? ' prio' : ''}`;
  d.innerHTML = '<div class="tx"><b></b><span></span><br><small></small></div>';
  d.querySelector('b').textContent = `✉️ An ${m.to === EL_ALL ? 'alle Teams' : teamNameOf(m.to)}${m.prio ? ' · ❗ wichtig' : ''}`;
  d.querySelector('span').textContent = m.txt || '';
  d.querySelector('small').textContent = [hhmm(m.t),
    m.rej ? '⚠️ nicht zugestellt' : wait ? '⏳ wartet auf Netz' : rs.read.length ? `👁 gelesen: ${rs.read.map(teamNameOf).join(', ')}${rs.open.length ? ` · offen: ${rs.open.map(teamNameOf).join(', ')}` : ''}` : 'noch ungelesen'].join(' · ');
  return d;
}
// Eingabefeld „Nachricht an …“ im Statuspanel: Empfänger nur Teams mit Live-Kanal; sonst Hinweis. Auswahl bleibt beim Neuzeichnen erhalten.
function renderElCompose() {
  const box = $('st-send');
  const el = db.mode === 'el' && P && P.live && !P.closed;
  const targets = el ? elTargets(P.sent, P.marks) : [];
  box.hidden = !targets.length;
  const noLive = el ? (P.sent || []).filter((x) => !x.live && !(Number(x.done) > 0)) : [];
  $('el-hint').hidden = !noLive.length || !targets.length;
  $('el-hint').textContent = `Kein Live-Kanal (nur QR-Rückmeldung): ${[...new Set(noLive.map((x) => teamNameOf(x.id)))].join(', ')}`;
  if (!targets.length) return;
  const sel = $('el-to');
  const sig = targets.map((q) => q.a).join('|');
  if (sel.dataset.sig !== sig) {
    const keep = sel.value || elPreTo;
    sel.innerHTML = '';
    for (const [v, l] of [[EL_ALL, 'Alle Teams'], ...targets.map((q) => [q.a, q.label])]) {
      const o = document.createElement('option');
      o.value = v;
      o.textContent = l;
      sel.appendChild(o);
    }
    sel.dataset.sig = sig;
    sel.value = [...sel.options].some((o) => o.value === keep) ? keep : EL_ALL;
  }
  if (elPreTo && [...sel.options].some((o) => o.value === elPreTo)) { sel.value = elPreTo; }
  elPreTo = '';
}
let elPreTo = '';
function openStatusPanel(teamId = stFilter) {
  stFilter = teamId || '';
  stFresh = new Set(unreadNow().map((m) => m.id));
  renderStatusPanel();
  openPanel('panel-status');
  closePop();
  if (unreadOpen) unreadOpen = false;
  readMsgs();
  tbSig = '';
  renderTeamBar();
}
$('btn-status').addEventListener('click', () => openStatusPanel(''));
$('st-filter').addEventListener('change', () => { stFilter = $('st-filter').value; renderStatusPanel(); });

// ---- v128: Funkmeldung für ein Team eintragen, Fund/Hinweis der Einsatzleitung, UA-Übersicht, Auto-Abschluss ----
// Alles geht am Handy/Tablet ohne ELW-Laptop: Fenster (openDlg) und Kartenpunkt per Tippen.
let pendingPick = null; // Tippen auf die Karte: Funktion({ lat, lon })
const canEnter = () => db.mode === 'el' && !!P && !P.closed && !isLocked();
const hmNow = () => { const d = new Date(); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
const lastPctOf = (x) => { const own = allMsgs().filter((m) => m.a === x.id && (m.s === 'fertig' || m.s === 'zu') && msgPct(m) != null); return own.length ? msgPct(own[own.length - 1]) : null; };
// Zeile mit Beschriftung im Fenster
function dlgField(box, label, el) {
  const l = document.createElement('label');
  l.textContent = label;
  l.appendChild(el);
  box.appendChild(l);
  return el;
}
// Karte antippen lassen: Fenster ist zu, Tipp ruft fn auf
function pickOnMap(msg, fn) {
  closePanels();
  pendingPick = fn;
  setTool('ptpick');
  toast(msg, 7000);
}
async function funkDialog(preA = '') {
  if (!canEnter()) return;
  const tg = funkTargets(P);
  if (!tg.length) return toast('Kein laufender Auftrag – erst unter „Teams“ einen Auftrag erstellen', 6000);
  const r = await openDlg((box, close) => {
    dlgHead(box, '✍️ Meldung für Team eintragen', 'Funkmeldung eines Teams ohne App (Kette, Drohne, Feuerwehr …). Sie zählt wie eine Meldung aus der App und geht an alle EL-Geräte.');
    const sel = dlgField(box, 'Team', document.createElement('select'));
    sel.id = 'funk-team';
    for (const { x, team } of tg) sel.add(new Option(`${team ? typeIcon(team) : '🐕'} ${team ? team.label : x.team}`, x.id));
    if (preA && tg.some((t) => t.x.id === preA)) sel.value = preA;
    const cur = () => tg.find((t) => t.x.id === sel.value);
    let kind = null;
    const list = document.createElement('div');
    list.className = 'dlg-btns two';
    list.id = 'funk-kinds';
    box.appendChild(list);
    const pctBox = document.createElement('div');
    pctBox.hidden = true;
    const big = document.createElement('div');
    big.className = 'st-pct';
    const rng = document.createElement('input');
    rng.type = 'range'; rng.className = 'st-range'; rng.id = 'funk-pct'; rng.min = 0; rng.max = 100; rng.step = 10;
    pctBox.append(big, rng);
    box.appendChild(pctBox);
    const showPct = () => { big.textContent = Number(rng.value) >= 100 ? '100 % – ✅ fertig' : `${rng.value} % abgesucht`; };
    rng.addEventListener('input', showPct);
    const txt = dlgField(box, 'Hinweis (optional)', Object.assign(document.createElement('input'), { type: 'text', id: 'funk-txt', maxLength: 300, placeholder: 'z. B. Böschung, Bach, Grund' }));
    const tm = dlgField(box, 'Uhrzeit (Standard: jetzt)', Object.assign(document.createElement('input'), { type: 'time', id: 'funk-time', value: hmNow() }));
    const btns = FUNK_KINDS.map((k) => dlgButton(list, '', '', () => {
      kind = k;
      btns.forEach((b, i) => b.classList.toggle('sel', FUNK_KINDS[i] === k));
      pctBox.hidden = !k.pct;
      if (k.pct) { const c = cur(); const l = lastPctOf(c.x); rng.value = k.code === 'zu' ? 100 : Math.round((l == null ? 50 : l) / 10) * 10; showPct(); }
      go.innerHTML = k.pos ? '👆 Ort auf der Karte antippen' : '✍️ Eintragen';
    }));
    const label = () => FUNK_KINDS.forEach((k, i) => { btns[i].innerHTML = esc(`${k.ico} ${funkLabel(k, cur().team ? unitType(cur().team) : 'hund')}`); });
    const go = dlgButton(box, '✍️ Eintragen', 'primary', () => {
      if (!kind) return toast('Bitte erst wählen, was gemeldet wird');
      const t = timeOfDay(tm.value, Date.now());
      if (t == null) return toast('Uhrzeit nicht lesbar (z. B. 20:05)');
      const c = cur();
      close({ x: c.x, team: c.team, kind: kind.code, pc: kind.pct ? Number(rng.value) : undefined, txt: txt.value.trim(), t });
    });
    sel.addEventListener('change', label);
    label();
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!r) return;
  const k = funkKind(r.kind);
  if (k.pos) return pickOnMap('Auf die Karte tippen: dort liegt der Ort der Meldung', (pos) => funkCommit({ ...r, pos }));
  funkCommit(r);
}
function funkCommit(o) {
  if (!canEnter()) return;
  const m = buildFunkMsg({ ...o, by: devBy() });
  if (!m) return toast('Meldung nicht möglich');
  if (!P.live) ensureLive(P, liveUrlNow());
  addFunkMsg(P, m);
  if (P.live && isUrgent(m)) P.live.ack.push(m.id); // die Meldung stammt von diesem Gerät: kein Dringend-Fenster hier
  P.updated = Date.now();
  if (P.live) elSend(m).catch(() => {});
  changed();
  redraw();
  renderSentList();
  if ($('panel-status').hidden === false) renderStatusPanel();
  checkCloseAsk();
  toast(`✍️ ${m.tm}: ${msgLabel(m)}${m.pc != null && m.s !== 'fertig' && m.s !== 'zu' ? '' : ''} eingetragen (${hhmm(m.t)}, Funk)`, 5000);
}

// Fund/Hinweis eintragen (Kleidungsstück, Gegenstand, Spur, Wärmequelle …) – optional mit Foto und Prüfauftrag
async function findDialog() {
  if (!canEnter()) return;
  const targets = P.live ? elTargets(P.sent, P.marks) : [];
  const r = await openDlg((box, close) => {
    dlgHead(box, '🔎 Fund/Hinweis eintragen', 'Der Fund steht danach mit Ort in der Meldungsliste, im Bericht, im GPX/PDF und bei allen Unterabschnitten.');
    let art = null;
    const list = document.createElement('div');
    list.className = 'dlg-btns two';
    list.id = 'find-kinds';
    box.appendChild(list);
    const hints = document.createElement('div');
    hints.className = 'dlg-btns two';
    box.appendChild(hints);
    const txt = dlgField(box, 'Beschreibung', Object.assign(document.createElement('input'), { type: 'text', id: 'find-txt', maxLength: 300, placeholder: 'z. B. blaue Damenjacke, Größe M' }));
    const row = document.createElement('div');
    row.className = 'pair-row';
    box.appendChild(row);
    const tmW = document.createElement('div');
    const tm = dlgField(tmW, 'Uhrzeit', Object.assign(document.createElement('input'), { type: 'time', id: 'find-time', value: hmNow() }));
    const fiW = document.createElement('div');
    const finder = dlgField(fiW, 'Finder (Team/Einheit/Person)', Object.assign(document.createElement('input'), { type: 'text', id: 'find-finder', maxLength: 60, placeholder: 'z. B. FF-Trupp 3' }));
    finder.setAttribute('list', 'find-finder-list');
    const dl = document.createElement('datalist');
    dl.id = 'find-finder-list';
    for (const t of P.marks.filter((m) => m.kind === 'team' && m.id !== NO_TEAM)) { const o = document.createElement('option'); o.value = t.label; dl.appendChild(o); }
    fiW.appendChild(dl);
    row.append(tmW, fiW);
    // Foto
    const file = Object.assign(document.createElement('input'), { type: 'file', accept: 'image/*', id: 'find-photo' });
    file.setAttribute('capture', 'environment');
    file.hidden = true;
    const photoBtn = dlgButton(box, '📷 Foto aufnehmen / wählen', '', () => file.click());
    file.addEventListener('change', () => { photoBtn.textContent = file.files[0] ? `📷 Foto: ${file.files[0].name.slice(0, 30)}` : '📷 Foto aufnehmen / wählen'; });
    box.appendChild(file);
    // Status, Dringend, Prüfauftrag
    const st = dlgField(box, 'Status', document.createElement('select'));
    st.id = 'find-status';
    st.add(new Option('⏳ offen (noch zu prüfen)', 'o'));
    st.add(new Option('✔ geprüft', 'g'));
    const dr = document.createElement('label');
    dr.className = 'check';
    dr.innerHTML = '<input type="checkbox" id="find-urgent"><span>❗ Dringend melden (Fenster bei allen EL-Geräten)</span>';
    box.appendChild(dr);
    // v130.11: Prüfauftrag an ein oder mehrere Teams (nicht mehr nur eins)
    const checkIds = new Set();
    if (targets.length) {
      const h = document.createElement('p');
      h.className = 'small';
      h.textContent = 'Prüfauftrag an Team(s) (optional):';
      box.appendChild(h);
      for (const q of targets) {
        const l = document.createElement('label');
        l.className = 'check';
        const c = Object.assign(document.createElement('input'), { type: 'checkbox' });
        c.addEventListener('change', () => { if (c.checked) checkIds.add(q.a); else checkIds.delete(q.a); });
        const sp = document.createElement('span');
        sp.textContent = q.label;
        l.append(c, sp);
        box.appendChild(l);
      }
    }
    const btns = FIND_KINDS.map((k) => dlgButton(list, esc(`${k.ico} ${k.label}`), '', () => {
      art = k;
      btns.forEach((b, i) => b.classList.toggle('sel', FIND_KINDS[i] === k));
      dr.querySelector('input').checked = !!k.urgent;
      hints.innerHTML = '';
      for (const h of k.hints) dlgButton(hints, esc(h), '', () => { txt.value = h; });
    }));
    const need = () => { if (!art) { toast('Bitte erst die Art wählen'); return null; } const t = timeOfDay(tm.value, Date.now()); if (t == null) { toast('Uhrzeit nicht lesbar (z. B. 20:05)'); return null; } return t; };
    const out = (t) => ({ art: art.code, txt: txt.value.trim(), t, finder: finder.value.trim(), geprueft: st.value === 'g', dringend: dr.querySelector('input').checked, file: file.files[0] || null, check: [...checkIds] });
    dlgButton(box, '👆 Ort auf der Karte antippen', 'primary', () => { const t = need(); if (t != null) close({ ...out(t), where: 'map' }); });
    dlgButton(box, '📍 Ort = mein Standort', '', () => { const t = need(); if (t != null) close({ ...out(t), where: 'gps' }); });
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!r) return;
  if (r.where === 'gps') {
    toast('📍 Standort wird bestimmt … (bis 10 s)', 11000);
    const pos = await getFix();
    if (!pos) return toast('Kein Standort – bitte „Ort auf der Karte antippen“ nehmen', 6000);
    return findCommit(r, pos);
  }
  pickOnMap('Auf die Karte tippen: dort wurde es gefunden', (pos) => findCommit(r, pos));
}
async function findCommit(r, pos) {
  if (!canEnter()) return;
  const m = buildFindMsg({ art: r.art, txt: r.txt, pos, finder: r.finder, geprueft: r.geprueft, dringend: r.dringend, foto: !!r.file, t: r.t, by: devBy() });
  if (!m) return toast('Fund nicht möglich');
  if (r.file) {
    try { M().photos.push({ t: r.t, src: await shrinkPhoto(r.file), cap: `Fund ${findLabel(r.art).replace(/^\S+\s/, '')} ${hhmm(r.t)}${r.txt ? `: ${r.txt}` : ''}`, mid: m.id }); } catch { toast('Foto konnte nicht gelesen werden – Fund ohne Foto', 5000); delete m.ph; }
  }
  if (!P.live) ensureLive(P, liveUrlNow());
  addFunkMsg(P, m);
  if (P.live && isUrgent(m)) P.live.ack.push(m.id);
  P.updated = Date.now();
  if (P.live) elSend(m).catch(() => {});
  let pa = '';
  if (r.check && r.check.length) {
    const labels = sendFindCheck(m, r.check);
    if (labels.length) pa = ` · Prüfauftrag an ${labels.join(', ')}`;
  }
  changed();
  redraw();
  renderSentList();
  if ($('panel-status').hidden === false) renderStatusPanel();
  toast(`🔎 ${msgLabel(m)} eingetragen (${hhmm(m.t)})${m.ph ? ' mit Foto' : ''}${pa}`, 6000);
}
// Prüfauftrag zu einem Fund an ein oder mehrere Teams senden (bei der Eingabe oder nachträglich aus der Meldungsliste)
// -> Namen der Teams, an die es tatsächlich ging (ohne Live-Kanal geht nichts)
function sendFindCheck(m, teamIds) {
  if (!P.live || m.lat == null) return [];
  const where = formatMgrs(m.lat, m.lon);
  const labels = [];
  for (const a of teamIds) {
    const tg = elTargets(P.sent, P.marks).find((q) => q.a === a);
    if (!tg) continue;
    // v130: der Ort kommt als Punkt auf die Karte des Teams (ältere Apps sehen weiter den Text mit Koordinate)
    const z = buildZusatz(P, { to: tg.a, points: [{ lat: m.lat, lon: m.lon, name: `${findLabel(m.fa) || 'Fund'}${m.txt ? `: ${m.txt}` : ''}`.slice(0, 60), task: 'Bitte prüfen' }], prio: true });
    const pm = buildElMsg({ to: tg.a, txt: checkText(m, where), prio: 1 });
    if (z) pm.z = z.msg.z;
    elSend(pm).catch(() => {});
    labels.push(tg.label);
  }
  return labels;
}
// v130.11: Prüfauftrag nachträglich aus der Meldungsliste senden (nicht nur bei der Eingabe)
async function findSendDialog(m) {
  if (!P.live) return toast('Kein laufender Auftrag mit Status-Server – erst unter „Teams“ einen Auftrag per QR-Code vergeben', 7000);
  const targets = elTargets(P.sent, P.marks);
  if (!targets.length) return toast('Kein Team mit laufendem Auftrag', 5000);
  const picked = new Set();
  const ids = await openDlg((box, close) => {
    dlgHead(box, '📤 Prüfauftrag senden', `${msgLabel(m)}${m.txt ? `: ${m.txt}` : ''} – an ein oder mehrere Teams.`);
    for (const q of targets) {
      const l = document.createElement('label');
      l.className = 'check';
      const c = Object.assign(document.createElement('input'), { type: 'checkbox' });
      c.addEventListener('change', () => { if (c.checked) picked.add(q.a); else picked.delete(q.a); });
      const sp = document.createElement('span');
      sp.textContent = q.label;
      l.append(c, sp);
      box.appendChild(l);
    }
    dlgButton(box, '📤 Senden', 'primary', () => close([...picked]));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!ids || !ids.length) return;
  const labels = sendFindCheck(m, ids);
  toast(labels.length ? `📤 Prüfauftrag an ${labels.join(', ')} gesendet` : 'Nicht gesendet – kein Team erreichbar', 6000);
}
// Fund als geprüft (oder wieder offen) markieren: Korrektur-Meldung, geht an alle EL-Geräte
function findToggle(m) {
  if (!canEnter() || !isFind(m)) return;
  const kor = buildKor({ a: m.a, tm: m.tm, ref: m.id, fs: m.fs === 'g' ? 'o' : 'g' });
  if (!P.live) ensureLive(P, liveUrlNow());
  addFunkMsg(P, kor);
  if (P.live) elSend(kor).catch(() => {});
  changed();
  redraw();
  renderSentList();
  renderStatusPanel();
  toast(kor.fs === 'g' ? '✔ Fund als geprüft markiert' : '⏳ Fund wieder offen');
}
$('st-funk').addEventListener('click', () => funkDialog());
$('st-find').addEventListener('click', () => findDialog());
$('st-zusatz').addEventListener('click', () => zusatzDialog());
$('teams-zusatz').addEventListener('click', () => zusatzDialog()); // v130.9: zweiter Einstieg direkt bei „Teams“ – leichter zu finden als nur unter „Status“

// ---- v130: Zusatz zum laufenden Auftrag – Punkte, Umrisse, Zeichnungen, Lage-Orte, Raster, B-Ort an ein Team ----
// Geht über den Status-Server wie eine Nachricht (Warteschlange ohne Netz, Lesebestätigung, „wichtig“); kein neuer QR-Code.
// pre: { itemIdx: [], poiIds: [], gridIds: [], meet, points: [{ lat, lon, name, task }], to, task }
async function zusatzDialog(pre = {}) {
  if (!canEnter()) return;
  if (!P.live) ensureLive(P, liveUrlNow());
  const tg = elTargets(P.sent, P.marks);
  if (!P.live || !tg.length) return toast('Kein laufender Auftrag mit Status-Server – erst unter „Teams“ einen Auftrag per QR-Code vergeben', 7000);
  const st = {
    to: pre.to || (tg.length === 1 ? tg[0].a : ''), task: pre.task || '', prio: !!pre.prio,
    items: new Set(pre.itemIdx || []), pois: new Set(pre.poiIds || []), grids: new Set(pre.gridIds || []), meet: !!pre.meet,
    points: (pre.points || []).map((x) => ({ ...x })),
  };
  // Meldungen mit Ort (Funde, Hinweise …) lassen sich als Punkt mitschicken
  const spots = (P.live.msgs || []).filter((m) => Number.isFinite(m.lat) && Number.isFinite(m.lon) && !m.gone).slice(-30).reverse();
  for (;;) {
    const r = await openDlg((box, close) => {
      dlgHead(box, '📍 Ort/Gebiet an Team senden', 'Kommt zusätzlich zum laufenden Auftrag auf die Karte des Hundeführers – über den Status-Server, ohne neuen QR-Code.');
      const sel = dlgField(box, 'An', document.createElement('select'));
      sel.id = 'zus-to';
      sel.add(new Option('– Team wählen –', ''));
      for (const t of tg) sel.add(new Option(t.label, t.a));
      sel.add(new Option('📢 Alle Teams', EL_ALL));
      sel.value = st.to;
      sel.addEventListener('change', () => { st.to = sel.value; });
      const task = dlgField(box, 'Was soll dort geschehen?', Object.assign(document.createElement('textarea'), { id: 'zus-task', rows: 2, maxLength: 200, value: st.task, placeholder: 'z. B. Bitte Böschung mit Hund prüfen und Stand melden' }));
      task.addEventListener('input', () => { st.task = task.value; });
      const group = (title) => { const h = document.createElement('h3'); h.className = 'zus-h'; h.textContent = title; box.appendChild(h); };
      const check = (label, on, fn) => {
        const l = document.createElement('label');
        l.className = 'check';
        const c = Object.assign(document.createElement('input'), { type: 'checkbox', checked: on });
        c.addEventListener('change', () => fn(c.checked));
        const sp = document.createElement('span');
        sp.textContent = label;
        l.append(c, sp);
        box.appendChild(l);
        return c;
      };
      // neue Punkte (auf der Karte gesetzt) mit Name und eigener Aufgabe
      group('📍 Neue Punkte');
      st.points.forEach((pt, i) => {
        const row = document.createElement('div');
        row.className = 'zus-pt';
        const n = Object.assign(document.createElement('input'), { type: 'text', value: pt.name || '', maxLength: 60, placeholder: 'Name, z. B. Wärmequelle' });
        n.className = 'zus-pt-name';
        n.addEventListener('input', () => { pt.name = n.value; });
        const tk = Object.assign(document.createElement('input'), { type: 'text', value: pt.task || '', maxLength: 200, placeholder: 'Eigene Aufgabe (sonst die oben)' });
        tk.className = 'zus-pt-task';
        tk.addEventListener('input', () => { pt.task = tk.value; });
        const del = Object.assign(document.createElement('button'), { type: 'button', className: 'mini', textContent: '✕' });
        del.addEventListener('click', () => close({ delPoint: i }));
        row.append(n, tk, del);
        box.appendChild(row);
      });
      dlgButton(box, '👆 Punkt auf der Karte setzen', '', () => close({ pick: true }));
      if (spots.length) {
        group('🔎 Meldungen mit Ort');
        for (const m of spots) {
          const key = `m:${m.id}`;
          const name = `${hhmm(m.t)} ${m.tm || ''}: ${msgLabel(m)}${m.txt ? ` – ${m.txt}` : ''}`.slice(0, 80);
          check(name, st.points.some((x) => x.key === key), (on) => {
            st.points = st.points.filter((x) => x.key !== key);
            if (on) st.points.push({ key, lat: m.lat, lon: m.lon, name: `${msgLabel(m)}${m.txt ? `: ${m.txt}` : ''}`.slice(0, 60), fromMsg: true });
          });
        }
      }
      const its = P.items.map((it, i) => ({ it, i })).filter(({ it }) => (it.kind === 'track' || it.kind === 'stroke' || it.kind === 'text') && !it.rec);
      const seenGroup = new Set();
      const named = its.filter(({ it }) => { if (!it.group) return true; if (seenGroup.has(it.group)) return false; seenGroup.add(it.group); return true; });
      if (named.length) {
        group('📐 Umrisse, Zeichnungen, Texte');
        for (const { it, i } of named) {
          const word = it.kind === 'track' ? 'Umriss' : it.kind === 'text' ? 'Text' : 'Zeichnung';
          const label = `${word}: ${(it.kind === 'text' ? it.text : it.name) || '(ohne Name)'}`;
          const idx = it.group ? P.items.map((x, k) => (x.group === it.group ? k : -1)).filter((k) => k >= 0) : [i];
          check(label, idx.every((k) => st.items.has(k)), (on) => idx.forEach((k) => (on ? st.items.add(k) : st.items.delete(k))));
        }
      }
      if ((P.pois || []).length || P.meet) {
        group('🚐 Lage-Orte');
        if (P.meet) check(`B-Ort${P.meet.text ? `: ${P.meet.text}` : ''}`, st.meet, (on) => { st.meet = on; });
        for (const x of P.pois || []) check(poiName(x), st.pois.has(x.id), (on) => (on ? st.pois.add(x.id) : st.pois.delete(x.id)));
      }
      const gs = allGrids(P).filter((g) => g.area);
      if (gs.length) {
        group('# Raster');
        for (const g of gs) check(gridLabel(P, g), st.grids.has(g.id), (on) => (on ? st.grids.add(g.id) : st.grids.delete(g.id)));
      }
      const pr = document.createElement('label');
      pr.className = 'check';
      pr.innerHTML = '<input type="checkbox" id="zus-prio"><span>❗ Wichtig (Ton und Fenster beim Hundeführer, bis „Verstanden“)</span>';
      pr.querySelector('input').checked = st.prio;
      pr.querySelector('input').addEventListener('change', (e) => { st.prio = e.target.checked; });
      box.appendChild(pr);
      dlgButton(box, '📤 Senden', 'primary', () => close({ send: true }));
      dlgButton(box, 'Abbrechen', '', () => close(null));
    });
    if (!r) return;
    if (r.delPoint != null) { st.points.splice(r.delPoint, 1); continue; }
    if (r.pick) {
      const pos = await new Promise((res) => pickOnMap('Auf die Karte tippen: dort liegt der Punkt', (p) => res(p)));
      $('toast').hidden = true; // „Auf die Karte tippen …“ nicht über dem Fenster stehen lassen
      if (pos) st.points.push({ lat: pos.lat, lon: pos.lon, name: '', task: '' });
      continue;
    }
    if (!st.to) { toast('Bitte erst wählen, an welches Team'); continue; }
    const t = tg.find((x) => x.a === st.to);
    const out = buildZusatz(P, {
      to: st.to, teamId: t ? t.teamId : '', itemIdx: [...st.items], poiIds: [...st.pois], gridIds: [...st.grids], meet: st.meet,
      points: st.points.map((x) => ({ ...x, name: (x.name || '').trim() || 'Punkt' })), task: st.task, prio: st.prio,
    });
    if (!out) { toast('Bitte mindestens einen Punkt, ein Gebiet oder einen Ort auswählen'); continue; }
    if (out.size > ZUSATZ_MAX) { toast('Zu viel auf einmal für den Status-Server – bitte weniger oder einfachere Zeichnungen auswählen', 7000); continue; }
    // v130.13: an ein bestimmtes Team gesendete Umrisse/Zeichnungen auch beim EL diesem Team zuordnen (Farbe/Zuteilung) –
    // nicht bei „Alle Teams“, da dort keine einzelne Zuteilung Sinn ergibt
    const team = t && t.teamId ? P.marks.find((m) => m.id === t.teamId) : null;
    // neue Punkte bleiben auch auf der Karte der Einsatzleitung (als Textpunkt mit Aufgabe)
    const fresh = st.points.filter((x) => !x.fromMsg);
    if (fresh.length || (team && st.items.size)) {
      snapshot();
      for (const x of fresh) P.items.push({ kind: 'text', color: '#c62828', text: (x.name || '').trim() || 'Punkt', lat: x.lat, lon: x.lon, ...((x.task || st.task).trim() ? { note: (x.task || st.task).trim().slice(0, 200) } : {}), t: Date.now(), marker: true }); // v130.2: immer sichtbar
      if (team) {
        for (const i of st.items) {
          const it = P.items[i];
          if (!it) continue;
          if (it.kind === 'track') { it.to = team.id; it.color = team.color; }
          else if (it.kind === 'stroke') {
            for (const x of it.group ? P.items.filter((y) => y.group === it.group) : [it]) {
              if (!x.teams) x.teams = [];
              if (!x.teams.includes(team.id)) x.teams.push(team.id);
            }
          }
        }
      }
      changed();
      redraw();
      if (!$('panel-teams').hidden) renderMarks();
    }
    const ok = await elSend(out.msg);
    if ($('panel-status').hidden === false) renderStatusPanel();
    const who = st.to === EL_ALL ? 'alle Teams' : t ? t.label : 'das Team';
    toast(ok ? `📤 An ${who} gesendet: ${out.parts.join(', ')}` : `📤 Wartet auf Netz – geht automatisch an ${who}`, 6000);
    return;
  }
}

// Auto-Abschluss: Team meldet „abgeschlossen“ mit 100 % -> Auftrag ohne Rückfrage geschlossen, Toast mit Rückgängig
function checkAutoClose() {
  if (locked || db.mode !== 'el' || !P || P.closed) return;
  const msgs = allMsgs();
  const done = [];
  for (const x of P.sent || []) {
    if (!autoCloseDue(x, msgs)) continue;
    closeSent(x, msgs);
    if (gapView && gapView.a === x.id) gapView = null;
    done.push(x);
  }
  if (!done.length) return;
  changed();
  redraw();
  renderSentList();
  const names = done.map((x) => teamNameOf(x.id)).join(', ');
  toastAction(`✅ ${names}: abgeschlossen, 100 % – Auftrag geschlossen`, '↩ Rückgängig', () => {
    for (const x of done) reopenSent(x, allMsgs());
    changed();
    redraw();
    renderSentList();
    toast(`↩ Auftrag ${names} ist wieder offen`);
  }, 12000);
}

// UA-Übersicht und „wer ist noch draußen?“ im Status-Fenster (jedes EL-Gerät des Grund-Einsatzes)
function renderUaOverview() {
  const det = $('st-ua');
  const rows = db.mode === 'el' && P && !P.parentEid ? uaOverview(P, allMsgs()) : [];
  const show = rows.length && hasUas(P);
  det.hidden = !show;
  const body = $('st-ua-body');
  body.innerHTML = '';
  if (show) {
    const now = Date.now();
    for (const u of rows) {
      const d = document.createElement('div');
      d.className = `ua-row ${u.level}`;
      d.innerHTML = '<div class="ua-h"><b></b><span></span></div><div class="ua-t"></div>';
      d.querySelector('b').textContent = `${levelIcon(u.level)} ${u.ua === BASE_UA ? 'Grund-Einsatz (ohne UA)' : `UA ${u.ua}`}`;
      d.querySelector('.ua-h span').textContent = [u.pct != null ? `${u.pct} %` : '', `${u.open} offen`, u.last ? agoText(u.last, now) : 'noch keine Meldung'].filter(Boolean).join(' · ');
      for (const t of u.teams) {
        const l = document.createElement('div');
        l.className = 'ua-team';
        l.textContent = `${t.ico} ${t.label}: ${[t.pct != null ? `${t.pct} %` : 'Stand offen', t.lastText ? `${t.lastText} (${agoText(t.last, now)})` : 'keine Meldung', t.open ? `${t.open} Auftrag offen` : t.orders ? 'alle abgeschlossen' : 'kein Auftrag'].join(' · ')}`;
        d.appendChild(l);
      }
      if (u.level === 'stale') { const w = document.createElement('div'); w.className = 'ua-warn'; w.textContent = '⚠️ Seit über 60 Minuten keine Rückmeldung – nachfragen?'; d.appendChild(w); }
      body.appendChild(d);
    }
  }
  // wer ist noch draußen?
  const out = $('st-out');
  const tt = db.mode === 'el' && P ? teamTimes(P.sent, allMsgs(), P.marks) : [];
  const ob = $('st-out-body');
  ob.innerHTML = '';
  const outside = outsideTeams(tt);
  out.hidden = !tt.some((r) => r.msgs);
  if (!out.hidden) {
    $('st-out-sum').textContent = `🚶 Wer ist noch draußen? (${outside.length})`;
    for (const r of tt.filter((q) => q.msgs)) {
      const d = document.createElement('div');
      d.className = `ua-team${r.outside ? ' out' : ''}`;
      d.textContent = `${r.outside ? '🔶' : '✅'} ${r.mark ? typeIcon(r.mark) : '🐕'} ${r.label}: ${stateText(r)}${r.start ? ` (seit ${hhmm(r.start)})` : ''}`;
      ob.appendChild(d);
    }
  }
}
// Berichts-Zusätze (Kräfte aus Teams, Einheiten, Einsatzzeiten)
function reportExtras() {
  if (db.mode !== 'el') return {};
  const teams = P.marks.filter((m) => m.kind === 'team' && m.id !== NO_TEAM && !m.hidden);
  const tt = teamTimes(P.sent, exportMsgs(), P.marks);
  const rows = timeRows(tt);
  return {
    forcesAuto: teams.length ? forcesText(forcesFromTeams(P.marks)) : [],
    unitRows: teams.map((m) => ({ team: m.label, text: unitLine(m) })),
    timeRows: rows,
    timeTotal: rows.length ? `Gesamt: ${totalPersonHours(tt).toLocaleString('de-DE')} Personenstunden` : '',
  };
}

// ---- Suchfeld (Tablet): eingeklappt als 🔍, Antippen klappt es auf ----
const searchForm = $('search-form');
function collapseSearch() {
  if (!searchForm.classList.contains('open')) return;
  searchForm.classList.remove('open');
  $('search-input').blur();
}
// Suchfeld öffnen und Cursor hinein (auf dem Tablet ist es sonst eingeklappt und unsichtbar)
function openSearch() {
  if (isTablet() && db.mode === 'el') searchForm.classList.add('open');
  $('search-input').focus();
}
$('search-form').querySelector('.searchbtn').addEventListener('click', (e) => {
  if (!isTablet() || db.mode !== 'el' || searchForm.classList.contains('open')) return;
  e.preventDefault();
  openSearch();
});
$('search-input').addEventListener('blur', () => {
  setTimeout(() => { if (!$('search-input').value.trim() && document.activeElement !== $('search-input')) collapseSearch(); }, 200);
});
window.matchMedia('(min-width: 700px)').addEventListener('change', () => { tbSig = ''; renderTeamBar(); });

// ---- Einsatzleitung: Meldungen abholen ----
// v127: Meldungen abholen, wenn es einen Auftrag mit Live-Kanal gibt – oder der Einsatz mit anderen EL-Geräten verbunden ist
// (Übergabe/Fortschritt/Unterabschnitt): dann sieht auch ein Gerät ohne eigene Aufträge (z. B. EL-Handy/Tablet) Fund und Hilfe
const wantsLive = (proj) => (proj.sent || []).some((x) => x.live) || (proj.peers || []).length > 0 || !!proj.handedOver || !!proj.parentEid;
async function pollLive() {
  const proj = P;
  const l = proj && proj.live;
  if (locked || db.mode !== 'el' || !l || proj.closed || liveBusy || document.hidden || !navigator.onLine) return;
  if (!wantsLive(proj)) return;
  liveBusy = true;
  try {
    const r = await pollMessages(l);
    const sp = splitIncoming(r.msgs); // v117: Teammeldungen / Rückkanal (EL-Nachrichten, Quittungen) / Lesebestätigungen trennen
    const known = new Set(l.msgs.map((m) => m.id));
    const fresh = sp.team.filter((m) => !known.has(m.id) && !(proj.msgDel && proj.msgDel[m.id]));
    liveInit(l);
    const knownOut = new Set(l.out.map((m) => m.id));
    const freshEl = sp.el.filter((m) => !knownOut.has(m.id) && !ELW_KINDS.includes(m.s)); // auch von anderen EL-Geräten (v124: ELW-Aufträge nicht)
    takeElw(proj, sp.el); // v124: Aufträge an den ELW
    let readsNew = false;
    for (const [k, v] of Object.entries(sp.reads)) {
      const o = l.reads[k] || {};
      if (Object.keys(v).some((a) => !o[a])) { l.reads[k] = { ...v, ...o }; readsNew = true; }
    }
    if (freshEl.length) {
      l.out = mergeStatus(l.out, freshEl).slice(-200);
      for (const m of freshEl) if (m.s === 'q' && m.ref && !l.qSent[m.ref]) l.qSent[m.ref] = m.t; // ein anderes EL-Gerät hat schon quittiert
    }
    if (freshEl.length || readsNew) { prune(l.qSent); if (proj === P && $('panel-status').hidden === false) renderStatusPanel(); }
    if (r.since !== l.since || fresh.length || freshEl.length || readsNew) {
      l.since = r.since;
      if (fresh.length) {
        l.msgs = mergeStatus(l.msgs, fresh).slice(-500);
        markAccepted(proj, fresh); // erste Meldung (z. B. 📲 Quittung) = Auftrag übernommen
        proj.updated = Date.now();
        prune(noteReceived(proj.msgRecv, fresh.filter((m) => m.s !== 'kor'))); // v98: Eingang auf diesem Gerät -> ungelesen (Korrekturen nicht)
        if (proj === P) korToast(fresh);
        if (proj === P) {
          renderSentList(); // aktualisiert auch die Team-Chips
          redraw();
          checkUnread();
          checkCloseAsk();
          if ($('panel-status').hidden === false) renderStatusPanel();
        }
      }
      saveNow();
    }
  } catch { /* kein Netz oder Server weg: nächster Versuch */ } finally { liveBusy = false; }
  showUrgent();
}
// ---- v117: Rückkanal Einsatzleitung -> Hundeführer ----
// Quittungen („✓ Gesehen“) und Nachrichten schreibt die EL selbst in den Raum des Einsatzes (derselbe Schlüssel wie im Auftrag, ls);
// was nicht rausgeht, wartet in P.live.outbox und geht mit flushStatus nach (online, Sichtbarkeit, alle 60 s).
function liveInit(l) {
  for (const k of ['out', 'outbox']) if (!Array.isArray(l[k])) l[k] = [];
  for (const k of ['reads', 'qSent']) if (!l[k] || typeof l[k] !== 'object') l[k] = {};
  return l;
}
const canElSend = () => db.mode === 'el' && !!P && !!P.live && !P.closed && elTargets(P.sent, P.marks).length > 0;
async function elSend(m) {
  const l = P && P.live;
  if (db.mode !== 'el' || !l || P.closed) return false;
  liveInit(l);
  l.outbox.push(m);
  if (m.s === 'el') l.out = mergeStatus(l.out, [m]).slice(-200);
  saveNow();
  await flushStatus();
  return !l.outbox.some((x) => x.id === m.id);
}
// Meldungen der Teams als gesehen quittieren (einmal je Meldung, nur bei Aufträgen mit Status-Server)
function ackSeen(list) {
  const l = P && P.live;
  if (db.mode !== 'el' || !l || P.closed) return;
  liveInit(l);
  for (const m of list || []) {
    if (!needsAck(m) || m.gone || l.qSent[m.id]) continue;
    const x = (P.sent || []).find((q) => q.id === m.a);
    if (!x || !x.live) continue;
    l.qSent[m.id] = Date.now();
    elSend(buildAck({ ref: m.id, to: m.a }));
  }
}
// Nachricht aus dem Statuspanel senden
async function sendElText() {
  const txt = $('el-txt').value.trim();
  if (!txt) return toast('Bitte einen Text eingeben');
  if (!canElSend()) return toast('Kein Auftrag mit Live-Kanal – Nachricht nicht möglich');
  const m = buildElMsg({ to: $('el-to').value, txt, prio: $('el-prio').checked });
  $('el-txt').value = '';
  $('el-prio').checked = false;
  renderStatusPanel();
  const ok = await elSend(m);
  const rej = P.live && (P.live.out.find((x) => x.id === m.id) || {}).rej; // v118: abgelehnt (flushStatus hat schon gewarnt)
  if (!rej) toast(ok ? `✉️ Nachricht gesendet ${hhmm(Date.now())}` : '⏳ Nachricht wartet auf Netz – wird automatisch nachgesendet', 4000);
  renderStatusPanel();
}
$('el-go').addEventListener('click', sendElText);
$('el-txt').addEventListener('keydown', (e) => { if (e.key === 'Enter') sendElText(); });

// ---- v124: Zeichnung mit Auftrag an den ELW (elw.js) ----
// Ein EL-Gerät schickt Umrisse/Striche mit Auftragstext über den Live-Raum (verschlüsselt wie Statusmeldungen) an ein anderes
// EL-Gerät. Der ELW zeigt nur an; Einfügen und BaseCamp-Datei löst der Mensch aus. Voraussetzung: P.live (Schlüssel + Server),
// den auch die QR-Übergabe (buildHandover kopiert den ganzen Einsatz) und „Fortschritt senden“ (lv) mitbringen.
const ELW_NAMES = ['ELW', 'PC EL'];
const elwOpen = () => (P && P.elwIn ? P.elwIn.filter((o) => !o.done) : []);
function elwClearPreview() {
  if (elwLayer) { elwLayer.remove(); elwLayer = null; }
  elwShown = '';
  renderElwBar();
}
function elwPreview(o) {
  elwClearPreview();
  elwShown = o.id;
  elwLayer = L.layerGroup().addTo(map);
  for (const it of o.items) {
    if (it.kind === 'text') L.circleMarker([it.lat, it.lon], { radius: 6, color: '#6a1b9a', weight: 3, fillOpacity: 0.4 }).bindTooltip(it.text || '', { permanent: true }).addTo(elwLayer);
    else if (it.pts) (it.kind === 'track' && !it.open ? L.polygon : L.polyline)(it.pts, { color: '#6a1b9a', weight: 4, dashArray: '10 8', fillOpacity: 0.08 }).addTo(elwLayer);
  }
  renderElwBar();
}
// Plakette „📥 Aufträge (n)“ (nur EL, nur mit offenen Aufträgen) und „✕ Vorschau“
function renderElwBar() {
  const bar = $('elw-bar');
  const n = db.mode === 'el' && P ? elwOpen().length : 0;
  bar.hidden = !n && !elwShown;
  $('elw-list').hidden = !n;
  $('elw-list').textContent = `📥 Aufträge (${n})`;
  $('elw-off').hidden = !elwShown;
}
$('elw-list').addEventListener('click', () => elwList());
$('elw-off').addEventListener('click', elwClearPreview);
$('more-elw-in').addEventListener('click', () => { closePanels(); elwList(true); });
$('more-elw').addEventListener('click', () => { closePanels(); sendElw(); });

// Empfangen: alle Raum-Meldungen durchsehen, Teile sammeln, neue Aufträge für dieses Gerät speichern und melden
function takeElw(proj, msgs) {
  const raw = (msgs || []).filter((m) => ELW_KINDS.includes(m.s));
  const l = proj.live;
  if (!l || !raw.length) return;
  liveInit(l);
  const parts = mergeStatus(l.eParts || [], raw.filter((m) => m.s === 'elwp'));
  const full = joinElwParts([...raw.filter((m) => m.s === 'elw'), ...parts]);
  const gone = new Set(full.map((o) => o.id));
  l.eParts = parts.filter((m) => !gone.has(m.oid)).slice(-200);
  proj.elwIn = proj.elwIn || [];
  const r = addElwIn(proj.elwIn, elwInbox(full, devBy()));
  if (!r.fresh.length) return;
  proj.elwIn = r.list;
  proj.updated = Date.now();
  saveNow();
  if (proj !== P) return;
  renderElwBar();
  const neu = r.fresh.filter((o) => o.t > Date.now() - 30 * 60e3); // alte Aufträge beim ersten Abruf: leise
  if (!neu.length) return;
  beepShort();
  const o = neu[0];
  const msg = `📥 Auftrag von ${o.from || 'EL'}: ${o.txt || elwCounts(o.items)} – hier tippen`;
  toast(msg, 9000);
  const tb = $('toast');
  tb.onclick = () => { if (tb.textContent === msg) { tb.hidden = true; elwOpenOrder(o); } };
}
async function pollElw() {
  const proj = P;
  const l = proj && proj.live;
  if (locked || db.mode !== 'el' || !l || proj.closed || elwPollBusy || document.hidden || !navigator.onLine) return;
  if (wantsLive(proj)) return; // pollLive holt dann alles in einem Abruf
  elwPollBusy = true;
  try {
    const r = await pollMessages({ url: l.url, key: l.key, since: l.eSince || 0 });
    takeElw(proj, r.msgs);
    if (r.since !== l.eSince) { l.eSince = r.since; saveNow(); }
  } catch { /* kein Netz: nächster Versuch */ } finally { elwPollBusy = false; }
}

// Senden
async function sendElw() {
  if (isFree()) return lockedToast();
  if (db.mode !== 'el') return toast('Aufträge an den ELW gibt es nur in der Einsatzleitung');
  if (!P.live) {
    // v127: kein Umweg über einen Dummy-Auftrag – Live-Kanal einfach hier anlegen
    const ok = await openDlg((box, close) => {
      dlgHead(box, '📤 Kein Live-Kanal', 'Für „An ELW senden“ braucht der Einsatz einen Live-Kanal (verschlüsselter Schlüssel für den Status-Server). Er wird mit jeder Übergabe und jedem Fortschritt an die anderen Geräte weitergegeben.');
      dlgButton(box, 'Live-Kanal jetzt anlegen', 'primary', () => close(true));
      dlgButton(box, 'Abbrechen', '', () => close(false));
    });
    if (!ok) return;
    ensureLive(P, liveUrlNow());
    changed();
    saveNow();
    toast('📡 Live-Kanal angelegt – beim Übergeben/Fortschritt wandert er mit zu den anderen Geräten', 6000);
  }
  if (!db.deviceName) await askDeviceName(false);
  stamp();
  const proj = P;
  // wählbar: Umrisse (je einer) und Stift-Zeichnungen (je Gruppe)
  const rows = [];
  const byGroup = new Map();
  for (const it of proj.items) {
    if (it.kind === 'track' && (it.pts || []).length > 1) rows.push({ key: it.id, label: `${it.open ? 'Weg' : 'Umriss'}: ${it.name || 'ohne Namen'}`, items: [it], t: it.t || 0 });
    else if (it.kind === 'stroke') {
      const k = it.group || it.id;
      if (!byGroup.has(k)) { const r = { key: k, label: `Zeichnung: ${it.name || 'Stift'}`, items: [], t: 0 }; byGroup.set(k, r); rows.push(r); }
      const r = byGroup.get(k);
      r.items.push(it);
      r.t = Math.max(r.t, it.t || 0);
    }
  }
  if (!rows.length) return toast('Keine Umrisse oder Stift-Zeichnungen vorhanden');
  const since = proj.elwSent || 0;
  const newer = since ? rows.filter((r) => r.t > since) : [];
  const pre = new Set((newer.length ? newer : rows).map((r) => r.key)); // neu/geändert seit dem letzten Senden, sonst alles
  const names = [...new Set([...proj.peers.map((x) => x.name), ...ELW_NAMES])].filter((n) => n !== devBy());
  const res = await openDlg((box, close) => {
    dlgHead(box, '📤 An ELW senden', `Von „${devBy()}“. Der Empfänger bekommt die Zeichnungen und den Auftrag angezeigt; nichts wird automatisch geteilt oder zugewiesen.${since ? ` Zuletzt gesendet ${hhmm(since)}.` : ''}`);
    const list = document.createElement('div');
    list.className = 'st-list';
    for (const r of rows) {
      const lb = document.createElement('label');
      lb.className = 'check';
      const cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.className = 'elw-pick';
      cb.value = r.key;
      cb.checked = pre.has(r.key);
      lb.append(cb, ` ${r.label}`);
      list.appendChild(lb);
    }
    box.appendChild(list);
    // v126: Beschriftungen „An“ / „Auftrag“ – zwei Textfelder ohne Titel wurden verwechselt
    const lab = (t) => { const l = document.createElement('p'); l.className = 'small elw-lab'; l.textContent = t; box.appendChild(l); };
    lab('An (Empfänger-Gerät):');
    const to = document.createElement('select');
    to.id = 'elw-to';
    to.add(new Option('an alle EL-Geräte', ''));
    for (const n of names) to.add(new Option(n, n));
    box.appendChild(to);
    const nn = document.createElement('input');
    nn.type = 'text';
    nn.id = 'elw-to-new';
    nn.placeholder = 'oder anderes Gerät: Name';
    box.appendChild(nn);
    lab('Auftrag an den Empfänger:');
    const txt = document.createElement('input');
    txt.type = 'text';
    txt.id = 'elw-txt';
    txt.maxLength = 300;
    txt.placeholder = 'Auftrag (z. B. In 2 Gebiete aufteilen)';
    box.appendChild(txt);
    const q = document.createElement('div');
    q.className = 'elw-tpl';
    for (const t of elwTemplates) dlgButton(q, esc(t), 'mini', () => { txt.value = t; });
    box.appendChild(q);
    dlgButton(box, '📤 Senden', 'primary', () => {
      const keys = [...box.querySelectorAll('.elw-pick:checked')].map((c) => c.value);
      if (!keys.length) return toast('Bitte mindestens eine Zeichnung wählen');
      close({ keys, to: nn.value.trim() || to.value, txt: txt.value.trim() });
    });
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!res) return;
  if (proj !== P || !P.live) return;
  const items = rows.filter((r) => res.keys.includes(r.key)).flatMap((r) => r.items);
  const order = buildElwOrder({ from: devBy(), to: res.to, txt: res.txt, items, marks: proj.marks });
  const parts = splitElwOrder(order);
  const ok = await Promise.all(parts.map((m) => elSend(m)));
  const ids = new Set(parts.map((m) => m.id));
  const waiting = proj.live.outbox.some((m) => ids.has(m.id));
  if (!waiting && !ok.every(Boolean)) return; // abgelehnt: flushStatus hat schon gewarnt
  proj.elwSent = Date.now();
  saveNow();
  const wohin = res.to || 'alle EL-Geräte';
  toast(waiting ? `⏳ Auftrag an ${wohin} wartet auf Netz – wird automatisch nachgesendet` : `✓ Auftrag an ${wohin} gesendet ${hhmm(Date.now())}${parts.length > 1 ? ` (${parts.length} Teile)` : ''}`, 5000);
}

// Anzeigen
async function elwList(all) {
  const list = all ? P.elwIn : elwOpen();
  if (!list.length) return toast('Keine Aufträge');
  const o = await openDlg((box, close) => {
    dlgHead(box, `📥 Aufträge (${list.length})`, 'Antippen zum Öffnen. Erledigte bleiben grau in der Liste.');
    for (const x of list) {
      const b = dlgButton(box, `${esc(x.from || 'EL')} ${hhmm(x.t)}${x.done ? ' ✓' : ''}<small>${esc(x.txt || '–')} · ${esc(elwCounts(x.items))}</small>`, x.done ? '' : 'primary', () => close(x));
      if (x.done) b.style.opacity = '0.55';
    }
    dlgButton(box, 'Schließen', '', () => close(null));
  });
  if (o) await elwOpenOrder(o);
}
async function elwOpenOrder(o) {
  const proj = P;
  elwPreview(o);
  const had = proj.items.filter((i) => i.elw === o.id).length;
  const r = await openDlg((box, close) => {
    dlgHead(box, `📥 Auftrag von ${o.from || 'EL'} · ${hhmm(o.t)}${o.done ? ' · erledigt' : ''}`, `${elwCounts(o.items)} – auf der Karte gestrichelt (lila).`);
    const t = document.createElement('div');
    t.className = 'elw-txt';
    t.textContent = o.txt || '(ohne Text)';
    box.appendChild(t);
    dlgButton(box, `➕ In laufenden Einsatz einfügen${had ? ` <small>schon ${had} eingefügt – ergänzt nur Fehlendes</small>` : ''}`, 'primary', () => close('insert'));
    if (!bridge) dlgButton(box, '🗺️ In BaseCamp öffnen', '', () => close('bc'));
    dlgButton(box, '👁 Zeigen', '', () => close('show'));
    dlgButton(box, '🖨️ Karten-PDF <small>nach dem Einfügen: Karten-PDF-Dialog</small>', '', () => close('pdf'));
    if (!o.done) dlgButton(box, '✓ Erledigt', '', () => close('done'));
    dlgButton(box, 'Schließen', '', () => close(null));
  });
  const pts = elwPoints(o.items);
  if (r === 'insert') {
    if (isClosed()) { elwClearPreview(); return lockedToast(); }
    snapshot(); // ein Rückgängig-Schritt
    const m = mergeElwItems(proj, o.items, o.id, { by: devBy() });
    changed();
    toast(m.added.length ? `➕ ${m.added.length} neu, ${m.skipped} schon vorhanden` : 'Schon eingefügt – nichts Neues', 4000);
  } else if (r === 'bc') {
    const gpx = selectionGpx({ items: o.items }, `Auftrag von ${o.from || 'EL'}`);
    download(new Blob([gpx], { type: 'application/gpx+xml' }), safeName(`Auftrag ${o.from || 'EL'}`, '.gpx'));
    toast('GPX geladen – unten im Browser anklicken, öffnet BaseCamp (wenn .gpx mit BaseCamp verknüpft ist)', 8000);
  } else if (r === 'done') {
    o.done = Date.now();
    proj.updated = Date.now();
    saveNow();
  } else if (r === 'pdf') {
    openExport();
  }
  if (r === 'show' || r === 'insert' || r === 'pdf') {
    if (pts.length) map.fitBounds(pts, { padding: [40, 40], maxZoom: 18 });
  }
  if (r !== 'show') elwClearPreview(); else renderElwBar();
}

function beepShort() {
  try { if (navigator.vibrate) navigator.vibrate([200, 100, 200]); } catch { /* egal */ }
  try {
    const ac = new (window.AudioContext || window.webkitAudioContext)();
    const o = ac.createOscillator();
    const g = ac.createGain();
    o.type = 'square';
    o.frequency.value = 660;
    o.connect(g);
    g.connect(ac.destination);
    g.gain.setValueAtTime(0.1, ac.currentTime);
    g.gain.setValueAtTime(0, ac.currentTime + 0.3);
    o.start();
    o.stop(ac.currentTime + 0.35);
    setTimeout(() => ac.close().catch(() => {}), 1200);
  } catch { /* Ton nur nach Tipp auf die Seite erlaubt */ }
}
function beep() {
  try { if (navigator.vibrate) navigator.vibrate([300, 150, 300, 150, 600]); } catch { /* egal */ }
  try {
    const ac = new (window.AudioContext || window.webkitAudioContext)();
    [0, 0.4, 0.8].forEach((d) => {
      const o = ac.createOscillator();
      const g = ac.createGain();
      o.type = 'square';
      o.frequency.value = 880;
      o.connect(g);
      g.connect(ac.destination);
      g.gain.setValueAtTime(0.15, ac.currentTime + d);
      g.gain.setValueAtTime(0, ac.currentTime + d + 0.25);
      o.start(ac.currentTime + d);
      o.stop(ac.currentTime + d + 0.3);
    });
    setTimeout(() => ac.close().catch(() => {}), 2000);
  } catch { /* Ton nur nach Tipp auf die Seite erlaubt */ }
}
// Offene Dringend-Meldungen (zurückgezogene nicht)
const urgentTodo = (proj) => applyKor(proj.live.msgs).filter((m) => isUrgent(m) && !m.gone && !proj.live.ack.includes(m.id) && !(proj.msgDel && proj.msgDel[m.id]));
let urgentClose = null;
// Neue Korrekturen: Hinweis; steht ein Dringend-Fenster, dessen Meldungen alle zurückgezogen sind, schließt es sich
function korToast(fresh) {
  const ks = fresh.filter((m) => m.s === 'kor');
  const k = ks[ks.length - 1];
  if (k) {
    const x = (P.sent || []).find((q) => q.id === k.a);
    const team = x && P.marks.find((q) => q.id === x.teamId);
    toast(`${team ? team.label : k.tm || 'Team'}: Meldung ${k.del ? 'zurückgezogen' : 'geändert'}`, 5000);
  }
  if (urgentClose && urgentOpen && !urgentTodo(P).length) urgentClose(false);
}
// Dringende Meldungen (Fund, Hilfe): Ton, Vibration, Dialog bleibt bis „Gesehen“
async function showUrgent() {
  const proj = P;
  const l = proj && proj.live;
  if (locked || urgentOpen || db.mode !== 'el' || !l) return;
  const todo = urgentTodo(proj);
  if (!todo.length) return;
  if (!$('dlg').hidden) return setTimeout(showUrgent, 4000); // ein anderes Fenster steht – gleich nochmal
  urgentOpen = true;
  beep();
  const beeper = setInterval(beep, 12000);
  const r = await openDlg((box, close) => {
    urgentClose = close;
    dlgHead(box, `🆘 Dringend (${todo.length})`, 'Diese Meldung bleibt, bis du sie als gesehen bestätigst.');
    for (const m of todo) {
      const d = document.createElement('div');
      d.className = 'st-urgent';
      d.textContent = statusText({ m });
      box.appendChild(d);
      if (m.lat != null) dlgButton(box, '📍 Auf Karte zeigen', '', () => close(m));
    }
    dlgButton(box, '✓ Gesehen', 'primary', () => close(true));
  });
  clearInterval(beeper);
  urgentOpen = false;
  urgentClose = null;
  l.ack.push(...todo.map((m) => m.id));
  if (proj === P) ackSeen(todo); // v117: der Hundeführer sieht „✓ gesehen“
  saveNow();
  if (r && r.lat != null && proj === P) showStatusMark(r);
  showUrgent();
}
function startStatus() {
  renderStatusBtn();
  flushStatus();
  pollLive();
  pollElw();
  showUrgent();
  setInterval(() => { if (navigator.onLine) flushStatus(); }, 60e3);
  setInterval(pollElw, 15e3); // v124: Aufträge an den ELW (auch ohne laufende Aufträge)
  setInterval(pollLive, 15e3); // Einsatzleitung: alle 15 s neue Status-Meldungen holen
  pollHf();
  setInterval(pollHf, 20e3); // v117: Hundeführer: Quittungen und Nachrichten der Einsatzleitung holen
  renderTeamBar();
  checkUnread();
  setInterval(checkUnread, 15e3); // Erinnerung bei ungelesenen Meldungen
  // v130.4: Auftrags-/Pausenzeit der Teams laufen mit – Anzeige auffrischen, solange das Fenster offen ist
  setInterval(() => { if (db.mode === 'el' && !$('panel-teams').hidden) renderSentList(); }, 30e3);
  checkCloseAsk();
  setInterval(checkCloseAsk, 15e3);
  window.addEventListener('online', () => { flushStatus(); pollLive(); pollElw(); pollHf(); });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) { flushStatus(); pollLive(); pollElw(); pollHf(); } });
}

// ---- Einsatzleitung: Rückmeldung übernehmen (Kamera oder eingefügter Link) ----
async function handleShared(text) {
  try { await handleShared1(text); } catch { toast('Link/Code konnte nicht gelesen werden'); }
}
async function handleShared1(text) {
  const sh = parseShared(text);
  if (!sh) return toast('Kein Code dieser App erkannt (Auftrag, Rückmeldung, Übergabe, Lage-Infos oder Fortschritt)');
  if (sh.kind === 'm') return toast('Teil eines mehrteiligen QR-Codes – bitte in der App über „Einsätze → 📷 Einsatz übernehmen“ scannen', 8000);
  let data;
  try { data = await unpack(sh.data); } catch { return toast('Code beschädigt oder unvollständig'); }
  if (data.k === 'a') return takeAssignment(data);
  if (data.k === 'e') return takeHandover(data);
  if (data.k === 'i') return takeInfos(data);
  if (data.k === 'f') return takeProgress(data);
  if (data.k !== 'r') return toast('Unbekannter Inhalt');
  // Rückmeldungen gehören zur Einsatzleitung: Modus umschalten (vom Hundeführer-Modus nur mit PIN)
  if (db.mode === 'hf' && !(await toElMode())) return;
  if (db.mode !== 'el') { db.mode = 'el'; applyMode(); }
  // Suchgebiet finden, an das der Auftrag ging
  const target = Object.values(db.projects).find((p) => (p.sent || []).some((x) => x.id === data.a));
  if (!target && !Object.values(db.projects).some((p) => (p.sent || []).length)) {
    // dieser Browser bzw. diese App kennt keinen Einsatz mit Aufträgen (z. B. Einsatz läuft in der Android-App)
    const go = await openDlg((box, close) => {
      dlgHead(box, '📥 Rückmeldung', 'Hier ist kein Einsatz bekannt, zu dem diese Rückmeldung gehört. Läuft der Einsatz in der Android-App oder in einem anderen Browser, den Link dort öffnen oder dort über „Rückmeldung einfügen“ übernehmen.');
      dlgButton(box, 'Trotzdem hier übernehmen', '', () => close(true));
      dlgButton(box, 'Abbrechen', 'primary', () => close(false));
    });
    if (!go) return;
  }
  if (target && target !== P) switchProject(target.id);
  if (isClosed() && !(await reopenClosed())) return;
  if (isFree()) createProject(wizTitle());
  const res = applyResult(P, data);
  const sent = (P.sent || []).find((x) => x.id === data.a);
  if (sent) {
    sent.last = Date.now();
    if (!isAccepted(sent)) sent.acc = sent.last; // Rückmeldung = Auftrag übernommen
    sent.n = (sent.n || 0) + 1;
    const km = (P.items.filter((it) => it.resultKey && it.resultKey.startsWith(`${data.a}|t`)).reduce((a, it) => a + pathLen(it.pts), 0) / 1000);
    sent.lastSum = [km && `${km.toLocaleString('de-DE', { maximumFractionDigits: 1 })} km gelaufen`, res.fields && `${res.fields} Feld${res.fields === 1 ? '' : 'er'} gemeldet`].filter(Boolean).join(', ');
  }
  markAccepted(P, allMsgsRaw());
  changed();
  renderSentList();
  checkCloseAsk(); // Team meldet „abgeschlossen“ und die Rückmeldung ist da: Rückfrage
  toast(`📥 Rückmeldung ${res.who}: ${res.ways} Weg${res.ways === 1 ? '' : 'e'}, ${res.marks} Markierung${res.marks === 1 ? '' : 'en'}, ${res.fields} Feld${res.fields === 1 ? '' : 'er'}${res.winds ? `, ${res.winds} Wind-Messung${res.winds === 1 ? '' : 'en'}` : ''}${res.msgs ? `, ${res.msgs} Status-Meldung${res.msgs === 1 ? '' : 'en'}` : ''}${res.known ? '' : ' (Auftrag hier unbekannt – ins aktuelle Suchgebiet übernommen)'}${res.ways + res.marks + res.fields + res.winds + res.msgs ? '' : ' – nichts Neues'}`, 9000);
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
    // Hundeführer mit laufendem (nicht abgeschlossenen) Auftrag: neuen Auftrag erst nach Rückfrage übernehmen (unlesbare Aufträge scheitern vorher)
    if (db.mode === 'hf' && P && P.hf && !P.hf.closed) {
      const ok = await openDlg((box, close) => {
        dlgHead(box, '📲 Neuer Auftrag', `Neuer Auftrag für ${a.tm ? a.tm.l : a.t} – laufenden Auftrag ${P.hf.team}/${P.title.replace(/ – [^–]*$/, '')} ersetzen? (Er bleibt unter „Frühere Aufträge“.)`);
        dlgButton(box, 'Neuen übernehmen', 'primary', () => close(true));
        dlgButton(box, 'Abbrechen', '', () => close(false));
      });
      if (!ok) return;
    }
    if (devLayer()) p.layerId = devLayer();
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
  // v116: Standortanzeige startet mit dem Auftrag (falls aus); Ablehnung bleibt ohne Nachfrage
  if (!known && watchId === null) startGps(false, true);
  // Übernahme-Quittung an die Einsatzleitung (ohne GPS-Warten); ohne Status-Server geht sie mit der QR-Rückmeldung mit
  if (!known) sendStatus({ s: 'ok', pos: null });
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
// v125: Hauptkamera statt Ultraweitwinkel. Erst die Freigabe über facingMode (damit die Kameras Namen haben), dann die
// beste Rückkamera nach Namen mit deviceId, 1920x1080 und Dauerfokus; die Wahl (auch „🔄 Kamera wechseln“) wird gemerkt.
let scanCams = [];
// v130.13: Name der Kamera mitspeichern – falls die deviceId sich (Browser-Neustart, Datenschutz-Salt) ändert,
// findet pickCamera() die gemerkte Kamera trotzdem über ihren Namen wieder, statt auf die „beste automatische“
// Wahl zurückzufallen (die auf manchen Geräten das Weitwinkel-Objektiv statt der normalen Kamera trifft).
const camSaved = () => { try { return JSON.parse(localStorage.getItem(CAM_KEY) || 'null') || ''; } catch { return ''; } };
const camSave = (id, label) => { try { localStorage.setItem(CAM_KEY, JSON.stringify({ deviceId: id, label: label || '' })); } catch { /* ohne Speicher: gilt nur jetzt */ } };
async function focusTrack(stream) {
  try {
    const tr = stream.getVideoTracks()[0];
    const caps = tr && tr.getCapabilities ? tr.getCapabilities() : null;
    if (wantsContinuousFocus(caps)) await tr.applyConstraints({ advanced: [{ focusMode: 'continuous' }] });
  } catch { /* Kamera kennt keinen Dauerfokus */ }
}
async function openScanCamera(forceId = '') {
  const md = navigator.mediaDevices;
  let stream = await md.getUserMedia({ video: { facingMode: 'environment' }, audio: false });
  try {
    const cur = (stream.getVideoTracks()[0].getSettings() || {}).deviceId || '';
    scanCams = backCameras(await md.enumerateDevices());
    const want = forceId ? scanCams.find((d) => d.deviceId === forceId) : pickCamera(scanCams, camSaved());
    if (want && want.deviceId && want.deviceId !== cur) {
      try {
        const s2 = await md.getUserMedia(cameraConstraints(want.deviceId));
        stream.getTracks().forEach((t) => t.stop());
        stream = s2;
      } catch { /* diese Kamera lässt sich nicht öffnen: bei der ersten bleiben */ }
    } else {
      try { await stream.getVideoTracks()[0].applyConstraints({ width: { ideal: 1920 }, height: { ideal: 1080 } }); } catch { /* egal */ }
    }
    const id = (stream.getVideoTracks()[0].getSettings() || {}).deviceId || '';
    scanCams.curId = id;
  } catch { /* ohne Kameraliste bleibt es bei facingMode */ }
  $('scan-switch').hidden = scanCams.length < 2;
  await focusTrack(stream);
  return stream;
}
async function switchScanCamera() {
  const next = nextCamera(scanCams, scanCams.curId);
  if (!next) return;
  const old = scanStream;
  try {
    $('scan-text').textContent = 'Kamera wird gewechselt …';
    if (old) old.getTracks().forEach((t) => t.stop()); // zwei Kameras gleichzeitig öffnet Android oft nicht
    const stream = await openScanCamera(next.deviceId);
    scanStream = stream;
    $('scan-video').srcObject = stream;
    await $('scan-video').play().catch(() => {});
    camSave(scanCams.curId || next.deviceId, next.label);
    $('scan-text').textContent = `Kamera: ${next.label || 'Kamera'} – auf den QR-Code richten.`;
  } catch { $('scan-text').textContent = 'Kamera lässt sich nicht wechseln.'; }
}
$('scan-switch').addEventListener('click', switchScanCamera);
let scanParts = {};
async function startScan() {
  scanParts = {};
  $('scanbox').hidden = false;
  $('scan-text').textContent = 'Kamera wird gestartet …';
  try {
    scanStream = await openScanCamera();
  } catch (e) {
    $('scan-text').textContent = 'Keine Kamera verfügbar oder nicht erlaubt. ' + (db.mode === 'hf' ? 'Alternativ: Den Link aus WhatsApp/SMS direkt antippen.' : 'Alternativ: Link per WhatsApp schicken lassen und „Rückmeldung einfügen“.');
    return;
  }
  const v = $('scan-video');
  v.srcObject = scanStream;
  await v.play().catch(() => {});
  $('scan-text').textContent = 'Kamera auf den QR-Code richten – Auftrag, Rückmeldung, Einsatz-Übergabe, Unterabschnitt, Lage-Infos oder Fortschritt …';
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
      const sh = text && parseShared(text);
      if (sh && sh.kind === 'm') {
        // mehrteiliger Code: Teile sammeln, bis alle da sind
        const r = addPart(scanParts, sh.data);
        if (r.done) { stopScan(); handleShared(shareLink('e', r.done)); return; }
        // v130.13: zeigt, welche Teile konkret noch fehlen – hilft beim Zurückspulen auf dem anderen Gerät
        if (r.n) $('scan-text').textContent = `Mehrteiliger Code: ${r.have} von ${r.n} Teilen gelesen – noch fehlt Teil ${r.missing.join(', ')}. Kamera ruhig halten …`;
      } else if (text) { stopScan(); handleShared(text); return; }
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
// ein Knopf für alles: was gescannt wurde, erkennt handleShared selbst
$('btn-scan').addEventListener('click', () => { closePanels(); startScan(); });
$('scan-close').addEventListener('click', stopScan);
$('hfm-scan').addEventListener('click', () => { closePanels(); startScan(); });

// ---- Einsatz an ein weiteres Gerät der Einsatzleitung übergeben (Handy -> Tablet/PC) ----
const PART_MAX = 16; // mehr Teile dauern beim Scannen zu lange
// Abgeschlossener Einsatz: nur ansehen und exportieren, Ändern erst nach „Wieder öffnen“
// Freie Karte (kein Einsatz offen): nur ansehen, Einzeichnen erst nach „+ Neuer Einsatz“
function isClosed() { return !!(P && P.closed) && db.mode === 'el'; }
function isFree() { return !!P && db.mode === 'el' && !P.closed && isBlankProject(P); }
function isLocked() { return isClosed() || isFree(); }
function applyClosed() {
  const closed = isClosed();
  const free = isFree();
  document.body.classList.toggle('closed', closed || free);
  $('closed-bar').hidden = !(closed || free);
  $('closed-bar').classList.toggle('free-bar', free);
  if (closed) $('closed-bar').textContent = `✅ „${P.title || 'Suchgebiet'}“ ist abgeschlossen – nur ansehen`;
  if (free) $('closed-bar').textContent = '🗺️ Kein Einsatz offen – hier tippen: + Neuer Einsatz';
}
function lockedToast() {
  if (isFree()) toast('Kein Einsatz offen – erst „+ Neuer Einsatz“ anlegen (Leiste oben antippen).', 5000);
  else toast('✅ Einsatz ist abgeschlossen – zum Ändern unter „Einsatz → Einsatzende“ wieder öffnen.', 5000);
}
// Sperren im Unterabschnitt: true = gesperrt (mit Hinweis)
function blocked(el, act = 'edit') {
  const m = denied(P, el, act);
  if (m) toast(m, 4000);
  return !!m;
}
function blockedGrid(gid, act = 'edit') {
  const m = deniedGrid(P, gid, act);
  if (m) toast(m, 4000);
  return !!m;
}
// Schutz übernommener Aufträge (nur EL): x = schützender Auftrag oder null. true = Aktion abbrechen;
// der Dialog bietet „Ändern freigeben“ (5 Minuten), danach geht die Aktion beim nächsten Versuch durch.
let guardOwnDlg = false; // der Dialog „Übernommener Auftrag“ selbst ist offen (Wisch-Strich fragt nicht für jedes Feld neu)
function guardAssigned(x) {
  if (!x || db.mode !== 'el') return false;
  if (!guardApplies(x, allMsgsRaw())) return false; // v127: vom Team schon abgeschlossen -> kein Schutz mehr
  if (!$('dlg').hidden) {
    if (guardOwnDlg) return true;
    // v127: ein anderer Dialog (z. B. Umriss) ist offen: nicht still abbrechen – Hinweis, und die Frage kommt nach dem Schließen
    toast(`🔒 Gehört zum übernommenen Auftrag ${x.team} – „Ändern freigeben“ kommt nach dem Schließen`, 5000);
    const proj0 = P;
    const iv = setInterval(() => {
      if ($('dlg').hidden) { clearInterval(iv); if (proj0 === P) guardAssigned(x); }
    }, 250);
    setTimeout(() => clearInterval(iv), 120000);
    return true;
  }
  const proj = P;
  guardOwnDlg = true;
  openDlg((box, close) => {
    dlgHead(box, '🔒 Übernommener Auftrag', `Gehört zum übernommenen Auftrag ${x.team} (seit ${hhmm(x.acc)}). Wirklich ändern?`);
    dlgButton(box, 'Ändern freigeben', 'urgent', () => close(true));
    dlgButton(box, 'Abbrechen', 'primary', () => close(false));
  }).then((ok) => {
    guardOwnDlg = false;
    if (!ok || proj !== P) return;
    x.unlock = unlockUntil();
    changed();
    toast('Freigegeben für 5 Minuten – bitte nochmal ausführen', 5000);
  });
  return true;
}
async function reopenClosed() {
  const ok = await openDlg((box, close) => {
    dlgHead(box, '✅ Abgeschlossener Einsatz', `„${P.title || 'Suchgebiet'}“ ist abgeschlossen und lässt sich nur ansehen und exportieren. Zum Ändern wieder öffnen.`);
    dlgButton(box, '↩️ Wieder öffnen', '', () => close(true));
    dlgButton(box, 'Nur ansehen', 'primary', () => close(false));
  });
  if (!ok) return false;
  delete P.closed;
  changed();
  saveNow();
  if (!$('panel-mission').hidden) renderClosed();
  toast('Einsatz wieder geöffnet');
  return true;
}
// Tastatur (Tablet/PC): gesperrte Felder nicht bearbeitbar
document.addEventListener('focusin', (e) => {
  if (!isLocked()) return;
  const t = e.target;
  if (!t.matches || !t.matches('input, textarea, select')) return;
  if (t.closest('#panel-mission, #panel-grid, #panel-teams, #panel-notes, #panel-send, #panel-wizard, #pc-list') && !t.classList.contains('keep')) {
    t.blur();
    lockedToast();
  }
});

function renderHanded() {
  const h = P && P.handedOver;
  $('handed').hidden = !h || db.mode !== 'el';
  if (h) $('handed').textContent = `📲 an weiteres Gerät übergeben (${new Date(h).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}) – dort weiterarbeiten`;
}
$('closed-bar').addEventListener('click', () => (isFree() ? $('proj-new').click() : reopenClosed()));
$('handed').addEventListener('click', async () => {
  const ok = await openDlg((box, close) => {
    dlgHead(box, '📲 Übergeben', `Dieser Einsatz wurde um ${hhmm(P.handedOver)} an ein weiteres Gerät übergeben. Dort laufen jetzt die Rückmeldungen ein. Hier geht alles weiter, wird aber nicht mehr abgeglichen.`);
    dlgButton(box, 'Hinweis ausblenden', '', () => close(true));
    dlgButton(box, 'OK', 'primary', () => close(false));
  });
  if (ok) { delete P.handedOver; changed(); }
});
$('ho-send').addEventListener('click', () => handoverQr(P, true));
// Einsatz (ganz oder Unterabschnitt aus „Weitergeben“) per QR-Code an ein Gerät der Einsatzleitung
async function handoverQr(proj, whole) {
  stamp();
  saveNow();
  // erst ein QR-Code mit wenig Vereinfachung, sonst mehrere im Wechsel
  let link = '';
  let parts = null;
  let e = null;
  const from = devBy();
  for (const opt of [{ tol: 1, from }, { tol: 3, from }, { tol: 6, from }]) {
    e = buildHandover(proj, { ...opt, fromId: devId(), liveUrl: liveUrlNow() });
    link = shareLink('e', await pack(e), PUBLIC_URL);
    if (link.length <= QR_MAX) break;
  }
  if (link.length > QR_MAX) {
    for (const opt of [{ tol: 1 }, { tol: 3 }, { tol: 6 }, { tol: 6, pages: false }, { tol: 15, pages: false }]) {
      e = buildHandover(proj, { ...opt, from, fromId: devId(), liveUrl: liveUrlNow() });
      const data = await pack(e);
      link = shareLink('e', data, PUBLIC_URL);
      parts = splitParts(data, 800).map((x) => shareLink('m', x, PUBLIC_URL));
      if (parts.length <= PART_MAX) break;
    }
  }
  const miss = [e.np && `${e.np} Foto${e.np === 1 ? '' : 's'}`, e.nn && `Notizblock (${e.nn} Seite${e.nn === 1 ? '' : 'n'})`].filter(Boolean);
  const how = parts
    ? `${parts.length} QR-Codes wechseln sich ab. Auf dem anderen Gerät „Einsätze → 📷 Einsatz übernehmen“ antippen und die Kamera ruhig auf diesen Bildschirm halten, bis alle Teile gelesen sind (die Handy-Kamera-App reicht dafür nicht).`
    : 'Auf dem anderen Gerät „Einsätze → 📷 Einsatz übernehmen“ antippen oder den Code mit der Kamera scannen.';
  const pc = ' Zum PC: „Teilen“ oder „Link kopieren“ (z. B. WhatsApp Web, Mail).';
  const lost = miss.length ? ` Nicht dabei: ${miss.join(', ')} – dafür „Suchgebiet als Datei senden“.` : '';
  // das neue Gerät gleich als Empfänger für „Fortschritt senden“ merken (Name lässt sich dort ändern bzw. neu eintragen)
  const now = Date.now();
  setPeer(P, `Gerät ${hhmm(now)}${whole ? '' : ' (UA)'}`, now);
  touch();
  if (whole) qrDone.push(() => { P.handedOver = Date.now(); changed(); saveNow(); });
  showQr(link, `📲 ${whole ? 'Einsatz' : 'Unterabschnitt'} „${proj.title || 'Suchgebiet'}“ übergeben`, how + pc + lost, parts);
}
$('ho-scan').addEventListener('click', () => { closePanels(); startScan(); });

async function takeHandover(e) {
  if (db.mode === 'hf' && !(await toElMode())) return;
  if (db.mode !== 'el') { db.mode = 'el'; applyMode(); }
  let inc;
  try { inc = projectFromHandover(e); } catch { return toast('Einsatz konnte nicht gelesen werden'); }
  const old = Object.values(db.projects).find((p) => p.eid === inc.eid);
  let how = 'new';
  if (old) {
    how = await openDlg((box, close) => {
      dlgHead(box, '📥 Einsatz übernehmen', `„${old.title || 'Suchgebiet'}“ ist hier schon vorhanden (zuletzt geändert ${hhmm(old.updated)}, übergeben wurde der Stand von ${hhmm(e.at)}).`);
      dlgButton(box, 'Zusammenführen<small>ergänzt nur, überschreibt und löscht nichts</small>', 'primary', () => close('merge'));
      dlgButton(box, 'Ersetzen', '', () => close('replace'));
      dlgButton(box, 'Als Kopie', '', () => close('copy'));
      dlgButton(box, 'Abbrechen', '', () => close(null));
    });
    if (!how) return;
  }
  if (how === 'merge') {
    if (old !== P) switchProject(old.id);
    if (isClosed() && !(await reopenClosed())) return;
    snapshot();
    const r = mergeProgress(P, buildProgress(inc, { from: e.from || '', fromId: e.fi || '', since: 0, full: true }));
    if (!r) return toast('Einsatz konnte nicht zusammengeführt werden');
    if (e.from && !peerOf(P, e.from)) setPeer(P, e.from, Date.now(), false);
    setPeerId(P, e.from, e.fi); // v125
    progBase.set(P, snapshotBase(P));
    syncGrid();
    changed();
    renderPois();
    saveNow();
    const sum = progressSummary(r);
    return toast(`📥 Einsatz zusammengeführt${e.from ? ` (Stand von ${e.from})` : ''}: ${sum || 'nichts Neues'}`, 8000);
  }
  let p = inc;
  if (how === 'replace') p = replaceWithHandover(old, inc, e);
  if (how === 'copy') { p.eid = p.id; p.title = `${p.title || 'Suchgebiet'} (Kopie)`; }
  // leeres Start-Suchgebiet eines frischen Geräts nicht stehen lassen
  const empty = P && !P.area && !P.items.length && !(P.otherGrids || []).length && !P.title && P.id !== p.id;
  if (empty) delete db.projects[P.id];
  if (devLayer()) p.layerId = devLayer();
  p.updated = Date.now();
  db.projects[p.id] = p;
  switchProject(p.id);
  saveNow();
  renderProjects();
  applyMode();
  await askDeviceName(true);
  setPeer(P, e.from || (P.parentEid ? 'Einsatzleitung' : 'Gerät'), Date.now(), false); // Absender als Empfänger für „Fortschritt senden“
  setPeerId(P, e.from || (P.parentEid ? 'Einsatzleitung' : 'Gerät'), e.fi); // v125: Geräte-ID des Absenders
  touch();
  toast(`📥 ${p.parentEid ? 'Unterabschnitt' : 'Einsatz'} „${p.title || 'Suchgebiet'}“ übernommen – Rückmeldungen jetzt hier scannen${e.np ? ` (ohne ${e.np} Foto${e.np === 1 ? '' : 's'})` : ''}`, 8000);
}

// ---- Lage-Infos (Lage-Orte, optional Kontakte) zwischen Geräten der Einsatzleitung abgleichen ----
async function sendInfos() {
  if (isFree()) return lockedToast();
  if (!P.pois.length && !P.contacts.length) return toast('Noch keine Lage-Orte – erst unter „Einsatz → Stammdaten“ oder mit 📍 anlegen');
  if (!db.deviceName) await askDeviceName(false);
  const how = await openDlg((box, close) => {
    dlgHead(box, '📍 Lage-Infos an EL senden', `${P.pois.length} Lage-Ort${P.pois.length === 1 ? '' : 'e'} von „${db.deviceName || 'diesem Gerät'}“. Beim Einsatzleiter wird nur ergänzt: Neues kommt dazu, eigene Änderungen werden übernommen, gelöscht wird dort nichts. Mehrfach scannen schadet nicht.`);
    let ct = null;
    if (P.contacts.length) {
      const l = document.createElement('label');
      l.className = 'check';
      l.innerHTML = `<input type="checkbox"> Kontakte mitsenden (${P.contacts.length})`;
      ct = l.querySelector('input');
      box.appendChild(l);
    }
    const go = (w) => () => close({ w, ct: !!(ct && ct.checked) });
    dlgButton(box, '📲 QR-Code', 'primary', go('qr'));
    dlgButton(box, '📤 Link teilen (WhatsApp, Mail …)', '', go('share'));
    dlgButton(box, '📋 Link kopieren', '', go('copy'));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!how) return;
  const data = await pack(buildInfos(P, { from: db.deviceName || '', contacts: how.ct }));
  const link = shareLink('i', data, PUBLIC_URL);
  const title = `📍 Lage-Infos von ${db.deviceName || 'Einsatzleitung'}`;
  if (how.w === 'copy') return copyText(link);
  if (how.w === 'share') return shareLinkText(link, 'Lage-Infos', `Lage-Infos (${P.title || 'Einsatz'}) von ${db.deviceName || 'Einsatzleitung'} – Link in der App „RHS Einsatz“ öffnen:`);
  const parts = link.length > QR_MAX ? splitParts(data, 800).map((x) => shareLink('m', x, PUBLIC_URL)) : null;
  showQr(link, title, `Auf dem anderen Gerät der Einsatzleitung mit „📷 Einsatz übernehmen“ oder „📷 Rückmeldung scannen“ einlesen${parts ? ' (mehrere Codes wechseln sich ab, Kamera ruhig halten)' : ''}.`, parts);
}
$('share-info').addEventListener('click', sendInfos);

async function takeInfos(inf) {
  if (db.mode === 'hf' && !(await toElMode())) return;
  if (db.mode !== 'el') { db.mode = 'el'; applyMode(); }
  const from = inf.from || 'Einsatzleitung';
  let target = infoTarget(db.projects, inf);
  if (!target) {
    if (isFree()) return toast(`Der Einsatz „${inf.ti || '?'}“ ist auf diesem Gerät nicht vorhanden – erst den Einsatz übernehmen oder anlegen`, 8000);
    const ok = await openDlg((box, close) => {
      dlgHead(box, `📥 Lage-Infos von ${from}`, `Sie gehören zum Einsatz „${inf.ti || '?'}“, der hier nicht bekannt ist. In den offenen Einsatz „${P.title || 'Suchgebiet'}“ übernehmen?`);
      dlgButton(box, 'Übernehmen', 'primary', () => close(true));
      dlgButton(box, 'Abbrechen', '', () => close(false));
    });
    if (!ok) return;
    target = P;
  }
  if (target !== P) switchProject(target.id);
  if (isClosed() && !(await reopenClosed())) return;
  snapshot();
  const r = mergeInfos(P, inf);
  changed();
  renderPois();
  saveNow();
  const sum = infoSummary(r);
  toast(sum ? `📥 Infos von ${from}: ${sum}` : `📥 Infos von ${from}: nichts Neues`, 6000);
}

// ---- Fortschritt (nur das Neue) zwischen Geräten der Einsatzleitung: nur QR-Code/Link, nie über den Status-Server ----
async function sendProgress() {
  if (isFree()) return lockedToast();
  if (db.mode !== 'el') return toast('Fortschritt senden gibt es nur in der Einsatzleitung');
  if (!db.deviceName) await askDeviceName(false);
  stamp();
  const from = devBy();
  const proj = P;
  // 1. An wen?
  const to = await openDlg((box, close) => {
    dlgHead(box, '🔄 Fortschritt senden', `Von „${from}“ an ein anderes Gerät der Einsatzleitung (EL, Unterabschnitt, ELW). Es geht nur das Neue seit dem letzten Senden an dieses Gerät. Dort wird nur ergänzt – nichts gelöscht.`);
    for (const x of proj.peers) dlgButton(box, `${esc(x.name)}<small>${x.sent ? `zuletzt gesendet ${hhmm(x.sent)}` : 'noch nie gesendet'}</small>`, 'primary', () => close(x.name));
    const inp = document.createElement('input');
    inp.type = 'text';
    inp.id = 'prog-new';
    inp.placeholder = proj.peers.length ? 'oder neues Gerät: Name' : 'Name des Empfänger-Geräts (z. B. Tablet EL, ELW)';
    box.appendChild(inp);
    dlgButton(box, 'Weiter', proj.peers.length ? '' : 'primary', () => (inp.value.trim() ? close(inp.value.trim()) : toast('Bitte einen Namen eintragen')));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!to) return;
  let all = false;
  for (;;) {
    // 2. Was ist neu?
    const peer = peerOf(proj, to);
    const since = all ? 0 : (peer ? peer.lastSent : 0);
    const f = buildProgress(proj, { from, fromId: devId(), to, toId: peer && peer.id || '', since });
    const how = await openDlg((box, close) => {
      if (!f) {
        dlgHead(box, `🔄 An ${to}`, `Nichts Neues seit ${since ? hhmm(since) : 'Beginn'}.`);
        dlgButton(box, 'Alles seit Beginn erneut senden', '', () => close('all'));
        dlgButton(box, 'OK', 'primary', () => close(null));
        return;
      }
      dlgHead(box, `🔄 An ${to}`, `${since ? `Neu seit ${hhmm(since)}` : 'Alles seit Beginn'}: ${progressPreview(f) || `${f.n} Einträge`}.`);
      dlgButton(box, '📲 QR-Code', 'primary', () => close('qr'));
      dlgButton(box, '📤 Link teilen (WhatsApp, Mail …)', '', () => close('share'));
      dlgButton(box, '📋 Link kopieren', '', () => close('copy'));
      if (since) dlgButton(box, 'Alles seit Beginn erneut senden', '', () => close('all'));
      dlgButton(box, 'Abbrechen', '', () => close(null));
    });
    if (how === 'all') { all = true; continue; }
    if (!how || !f) return;
    const data = await pack(f);
    const link = shareLink('f', data, PUBLIC_URL);
    setPeer(proj, to, f.at); // ab jetzt zählt nur noch, was danach neu ist
    touch();
    saveNow();
    if (how === 'copy') return copyText(link);
    if (how === 'share') return shareLinkText(link, 'Fortschritt', `Fortschritt (${proj.title || 'Einsatz'}) von ${from} – Link in der App „RHS Einsatz“ öffnen:`);
    const parts = link.length > QR_MAX ? splitParts(data, 800).map((x) => shareLink('m', x, PUBLIC_URL)) : null;
    return showQr(link, `🔄 Fortschritt von ${from} an ${to}`, `Auf dem anderen Gerät der Einsatzleitung mit „📷 Einsatz übernehmen“ einlesen${parts ? ` (${parts.length} Codes wechseln sich ab, Kamera ruhig halten)` : ''}. Mehrfach einlesen schadet nicht.`, parts);
  }
}
$('share-progress').addEventListener('click', sendProgress);

async function takeProgress(f) {
  if (db.mode === 'hf' && !(await toElMode())) return;
  if (db.mode !== 'el') { db.mode = 'el'; applyMode(); }
  const from = f.from || 'Einsatzleitung';
  const target = progressTarget(db.projects, f);
  if (!target) return toast(`🔄 Fortschritt von ${from} gehört zum Einsatz „${f.ti || '?'}“, der hier nicht vorhanden ist – erst den Einsatz übernehmen (Übergabe per QR-Code)`, 9000);
  if (target !== P) switchProject(target.id);
  if (isClosed() && !(await reopenClosed())) return;
  snapshot();
  const r = mergeProgress(P, f);
  if (!r) return toast('🔄 Fortschritt passt nicht zu diesem Einsatz');
  // Absender als Empfänger merken; ein beim Übergeben angelegter Platzhalter („Gerät 14:03“) bekommt seinen Namen
  if (!peerOf(P, from)) {
    const ph = P.peers.find((x) => /^Gerät \d/.test(x.name) && x.name.endsWith('(UA)') === !!f.pe);
    if (ph) ph.name = String(from).slice(0, 60); else setPeer(P, from, 0, false);
  }
  setPeerId(P, from, f.fi); // v125: Geräte-ID des Absenders merken (Herkunft statt Name vergleichen)
  progBase.set(P, snapshotBase(P));
  markAccepted(P, allMsgsRaw());
  syncGrid();
  changed();
  redraw();
  renderPois();
  if (!$('panel-teams').hidden) renderMarks();
  saveNow();
  const sum = progressSummary(r);
  const msg = sum ? `🔄 Fortschritt von ${from}: ${sum}` : `🔄 Fortschritt von ${from}: nichts Neues`;
  // v127: dieses Gerät reicht Neues weiter, wenn es noch andere Empfänger kennt (UA -> ELW -> EL)
  const others = sum ? P.peers.filter((x) => x.name !== from) : [];
  if (others.length) toastAction(`${msg} – weiterleiten?`, 'Weiterleiten', () => sendProgress(), 15000);
  else toast(msg, 8000);
}

// Name dieses Geräts (z. B. „ELW 11-1“, „Tablet EL“) – wird beim Übernehmen eines Einsatzes abgefragt
function renderDeviceName() {
  $('dev-name').textContent = db.deviceName || '–';
  const sel = $('dev-layer');
  if (!sel.options.length) {
    sel.add(new Option('wie zuletzt benutzt', ''));
    for (const l of LAYERS) sel.add(new Option(l.name, l.id));
  }
  sel.value = devLayer() || '';
  $('dev-status-url').value = db.statusUrl || '';
  // v125: Kürzel für neue Teams im Unterabschnitt
  $('ua-set').hidden = !P.parentEid;
  if (P.parentEid) { $('ua-name').value = uaName(P.title); $('ua-key').value = P.uaKey || ''; $('ua-key').placeholder = uaPrefix({ ...P, uaKey: '' }); $('ua-key-ex').textContent = uaPrefix(P); }
}
$('ua-name').addEventListener('change', () => { // v128: UA umbenennen (Titel „<Einsatz> – UA <Name>“, nie „UA UA …“)
  const t = renameUa(P.title, $('ua-name').value);
  if (t === P.title) { $('ua-name').value = uaName(P.title); return; }
  P.title = t;
  $('ua-name').value = uaName(t);
  changed();
  renderProjects();
  $('ua-key').placeholder = uaPrefix({ ...P, uaKey: '' });
  $('ua-key-ex').textContent = uaPrefix(P);
  toast(`Unterabschnitt heißt jetzt „${t}“`);
});
$('ua-key').addEventListener('change', () => {
  P.uaKey = $('ua-key').value.trim().slice(0, 4);
  $('ua-key-ex').textContent = uaPrefix(P);
  changed();
  toast(`Neue Teams heißen jetzt „${uaPrefix(P)}-Team …“`);
});
$('dev-status-url').addEventListener('change', () => {
  const v = $('dev-status-url').value.trim();
  if (v && !/^https:\/\/script\.google\.com\/\S+$/.test(v)) {
    $('dev-status-url').value = db.statusUrl || '';
    return toast('Die Adresse muss mit https://script.google.com/ beginnen (siehe Anleitung im Ordner „apps-script“)', 6000);
  }
  db.statusUrl = v || null;
  if (!saveNow()) return;
  toast(v ? '📣 Eigener Status-Server gespeichert – gilt für neue Einsätze' : '📣 Standard-Status-Server wird benutzt');
});
// Standard-Kartenart dieses Geräts (oder null): gilt für neue, übernommene und geladene Einsätze
function devLayer() {
  return db.defaultLayer && LAYERS.some((l) => l.id === db.defaultLayer) ? db.defaultLayer : null;
}
$('dev-layer').addEventListener('change', () => {
  db.defaultLayer = $('dev-layer').value || null;
  if (db.defaultLayer) setLayer(db.defaultLayer);
  saveNow();
  toast(db.defaultLayer ? `Standard-Kartenart: ${layerById(db.defaultLayer).name.replace(/ \(.*/, '')} – gilt ab jetzt für neue und übernommene Einsätze` : 'Keine Standard-Kartenart – neue Einsätze nehmen die zuletzt benutzte');
});
async function askDeviceName(joined) {
  const name = await openDlg((box, close) => {
    dlgHead(box, '📛 Name dieses Geräts', joined
      ? 'Dieses Gerät ist jetzt im Einsatz dabei. Wie soll es heißen? Der Name hilft, Geräte und ihre Meldungen auseinanderzuhalten.'
      : 'Der Name hilft, Geräte und ihre Meldungen auseinanderzuhalten.');
    const inp = document.createElement('input');
    inp.type = 'text';
    inp.placeholder = 'z. B. ELW 11-1, Tablet EL';
    inp.value = db.deviceName || '';
    inp.setAttribute('list', 'dev-sugg');
    const dl = document.createElement('datalist');
    dl.id = 'dev-sugg';
    for (const v of ['ELW', 'Tablet EL', 'Handy EL', 'PC EL']) { const o = document.createElement('option'); o.value = v; dl.appendChild(o); }
    box.append(inp, dl);
    inp.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') close(inp.value); });
    dlgButton(box, 'Speichern', 'primary', () => close(inp.value));
    dlgButton(box, joined ? 'Später' : 'Abbrechen', '', () => close(null));
    setTimeout(() => inp.focus(), 50);
  });
  if (name === null) return;
  db.deviceName = name.trim();
  saveNow();
  renderDeviceName();
}
$('dev-edit').addEventListener('click', () => askDeviceName(false));

// Link mit Auftrag/Rückmeldung (Kamera-App, WhatsApp …) – beim Start und wenn er sich ändert
async function handleHash() {
  const sh = parseShared(location.hash);
  if (!sh) return;
  const h = location.hash;
  if (await openInApp(h)) return;
  history.replaceState(null, '', location.pathname + location.search);
  // Rückmeldung: ist die App schon in einem anderen Fenster/Tab offen, dort übernehmen (sonst überschreiben sich die Fenster)
  if (['r', 'e', 'i', 'f'].includes(sh.kind) && await handOff(h)) return;
  await handleShared(h);
}

// Android-Browser: Link an die installierte App weitergeben (falls Android ihn nicht schon selbst
// an die App gibt). Der Inhalt geht als ?h=… mit, weil ein intent:-Link keinen #-Teil tragen kann.
const ANDROID_PKG = 'de.klaas.suchgebiet';
const NO_APP_KEY = 'suchgebiet-no-app';
async function openInApp(h) {
  if (bridge || !/Android/i.test(navigator.userAgent) || /[?&]web=1/.test(location.search)) return false;
  try { if (localStorage.getItem(NO_APP_KEY)) return false; } catch { /* privater Modus */ }
  const go = await openDlg((box, close) => {
    dlgHead(box, '📲 In der App öffnen?', 'Ist die Android-App „RHS Einsatz“ installiert, dort öffnen – dann landet alles im laufenden Einsatz der App.');
    dlgButton(box, '📲 In der App öffnen', 'primary', () => close('app'));
    dlgButton(box, '🌐 Hier im Browser weiter', '', () => close('web'));
    dlgButton(box, 'Im Browser weiter und nicht mehr fragen', '', () => close('never'));
  });
  if (go === 'never') { try { localStorage.setItem(NO_APP_KEY, '1'); } catch { /* egal */ } }
  if (go !== 'app') return false;
  location.href = appIntentUrl(location.href, ANDROID_PKG);
  return true;
}

// ---------- Mehrere Fenster/Tabs ----------
// Alle Tabs teilen sich den Speicher. Ein neu geöffneter Rückmelde-Link gibt die Daten an einen schon
// offenen Tab ab; schreibt ein anderer Tab, liest dieser Tab den Stand neu ein (statt ihn später zu überschreiben).
const tabs = 'BroadcastChannel' in window ? new BroadcastChannel('suchgebiet-tabs') : null;
const tabId = uid();
if (tabs) {
  tabs.onmessage = async (e) => {
    const m = e.data || {};
    if (m.to && m.to !== tabId) return;
    if (locked || !gateReady) return; // v118: ein gesperrtes Fenster nimmt nichts entgegen
    if (m.t === 'ping') tabs.postMessage({ t: 'pong', to: m.from, from: tabId, el: db.mode === 'el', visible: !document.hidden });
    if (m.t === 'take') {
      reloadFromStorage();
      tabs.postMessage({ t: 'took', to: m.from, from: tabId });
      try { window.focus(); } catch { /* egal */ }
      await handleShared(m.hash);
    }
  };
}
function askTabs(msg, answer, ms) {
  return new Promise((resolve) => {
    const got = [];
    const prev = tabs.onmessage;
    const timer = setTimeout(() => { tabs.onmessage = prev; resolve(got); }, ms);
    tabs.onmessage = (e) => {
      const m = e.data || {};
      if (m.to === tabId && m.t === answer) {
        got.push(m);
        if (msg.t === 'take') { clearTimeout(timer); tabs.onmessage = prev; resolve(got); }
      } else prev(e);
    };
    tabs.postMessage({ ...msg, from: tabId });
  });
}
async function handOff(hash) {
  if (!tabs) return false;
  const others = await askTabs({ t: 'ping' }, 'pong', 400);
  if (!others.length) return false;
  // bevorzugt ein Tab der Einsatzleitung, der gerade sichtbar ist
  others.sort((a, b) => (b.el - a.el) || (b.visible - a.visible));
  handedOff = true; // ab jetzt nichts mehr speichern – der andere Tab schreibt
  const ok = await askTabs({ t: 'take', to: others[0].from, hash }, 'took', 2000);
  if (!ok.length) { handedOff = false; return false; }
  openDlg((box) => {
    dlgHead(box, '📥 Rückmeldung übergeben', 'Die Rückmeldung wurde in dem Fenster übernommen, in dem der Einsatz schon offen ist. Dieses Fenster kann geschlossen werden.');
    dlgButton(box, 'Fenster schließen', 'primary', () => { window.close(); });
  });
  setTimeout(() => { try { window.close(); } catch { /* nur möglich, wenn per Link geöffnet */ } }, 1500);
  return true;
}
function reloadFromStorage(raw) {
  try {
    const s = JSON.parse(raw || localStorage.getItem(STORE_KEY) || 'null');
    if (!s || !s.projects) return;
    const cur = db.currentId;
    db = { ...db, ...s, currentId: s.projects[cur] ? cur : s.currentId };
  } catch { return; }
  db.projects = loadProjects(db.projects).projects; // v118: ein defekter Einsatz stoppt das Neulesen nicht
  if (!Object.keys(db.projects).length) { const np = normalizeProject(newProject('')); db.projects[np.id] = np; db.currentId = np.id; }
  mergeTrackBackups(db.projects);
  P = db.projects[db.currentId] || Object.values(db.projects)[0];
  syncGrid();
  restoreDrafts();
  fillProjectForm();
  updateGridInfo();
  renderPalette();
  if (!$('panel-teams').hidden) renderMarks();
  renderSentList();
  applyMode();
  redraw();
  updateStatus();
}
window.addEventListener('storage', (e) => {
  if (e.key === STORE_KEY && e.newValue && !handedOff && !gateOn) reloadFromStorage(e.newValue); // Rückfall, nur ohne Fenstersperre
});
// ---------- v118: Nur ein Fenster arbeitet ----------
// Das erste Fenster hält die Sperre „sgk-main“ (Web Locks; sonst Ping über BroadcastChannel „sgk-tabs“) und ist allein für den Speicher
// und alle Sendungen zuständig. Ein zweites Fenster zeigt nur einen Hinweis mit „Hier weiterarbeiten“: das erste speichert sofort, sperrt
// sich selbst und gibt die Sperre frei, das zweite liest den Speicher neu und arbeitet weiter. Die App der Android-App (ein Fenster) braucht das nicht.
const GATE_LOCK = 'sgk-main';
const hasLocks = !!(navigator.locks && navigator.locks.request);
const gateCh = 'BroadcastChannel' in window ? new BroadcastChannel('sgk-tabs') : null;
const gateOn = !bridge && (hasLocks || !!gateCh);
let gateReady = !gateOn; // die Entscheidung „erstes / zweites Fenster“ ist gefallen
let gateRelease = null;
let statusStarted = false;
const holdLock = (lk, res) => { res(true); return new Promise((done) => { gateRelease = done; }); };
function gateTry() {
  if (hasLocks) { // beim Neuladen gibt das alte Dokument die Sperre manchmal erst einen Moment später frei: kurz nochmal versuchen
    const once = () => new Promise((res) => { navigator.locks.request(GATE_LOCK, { ifAvailable: true }, (lk) => (lk ? holdLock(lk, res) : res(false))).catch(() => res(true)); });
    return (async () => { for (let i = 0; i < 8; i++) { if (await once()) return true; await new Promise((r) => setTimeout(r, 150)); } return false; })();
  }
  return new Promise((res) => { // ohne Web Locks: wer in 300 ms antwortet, ist das erste Fenster
    const t = setTimeout(() => { gateCh.removeEventListener('message', on); res(true); }, 300);
    const on = (e) => { if ((e.data || {}).t === 'here') { clearTimeout(t); gateCh.removeEventListener('message', on); res(false); } };
    gateCh.addEventListener('message', on);
    gateCh.postMessage({ t: 'hello' });
  });
}
// dieses (erste) Fenster gibt ab: erst speichern, dann sperren; die Aufzeichnung hört hier nur auf (recOn bleibt, das andere Fenster macht weiter)
function gateYield() {
  saveNow();
  locked = true;
  if (recWatch !== null) { navigator.geolocation.clearWatch(recWatch); recWatch = null; }
  if (recLock) recLock.release().catch(() => {});
  recLock = null;
  clearInterval(recTimer);
  recSeg = null;
  if (gateRelease) { gateRelease(); gateRelease = null; }
  showTabLock();
}
if (gateCh) {
  gateCh.onmessage = (e) => {
    const m = e.data || {};
    if (locked || !gateReady) return;
    if (m.t === 'hello') gateCh.postMessage({ t: 'here' });
    if (m.t === 'take') { gateYield(); gateCh.postMessage({ t: 'took' }); }
  };
}
function claimGate() {
  if (hasLocks) {
    if (gateCh) gateCh.postMessage({ t: 'take' });
    const ac = new AbortController();
    const to = setTimeout(() => ac.abort(), 4000);
    return new Promise((res) => {
      navigator.locks.request(GATE_LOCK, { signal: ac.signal }, (lk) => { clearTimeout(to); return holdLock(lk, res); }).catch(() => res(false));
    });
  }
  return new Promise((res) => { // ohne Web Locks: keine Antwort „took“ = niemand hält es mehr
    const t = setTimeout(() => { gateCh.removeEventListener('message', on); res(true); }, 1500);
    const on = (e) => { if ((e.data || {}).t === 'took') { clearTimeout(t); gateCh.removeEventListener('message', on); res(true); } };
    gateCh.addEventListener('message', on);
    gateCh.postMessage({ t: 'take' });
  });
}
function showTabLock() { $('tab-lock-msg').hidden = true; $('tab-lock').hidden = false; }
$('tab-lock-go').addEventListener('click', async () => {
  const b = $('tab-lock-go');
  b.disabled = true;
  const ok = await claimGate();
  b.disabled = false;
  if (!ok) { $('tab-lock-msg').textContent = 'Das andere Fenster antwortet nicht. Bitte dort weiterarbeiten oder es schließen.'; $('tab-lock-msg').hidden = false; return; }
  handedOff = false;
  locked = false;
  gateReady = true;
  reloadFromStorage();
  if (trackKeysDone.length) { if (saveNow()) for (const k of trackKeysDone) { try { localStorage.removeItem(k); } catch { /* egal */ } } trackKeysDone = []; }
  $('tab-lock').hidden = true;
  bootApp();
});
// Start: erstes Fenster -> los; zweites -> Hinweis (ein Rückmelde-Link wird wie bisher an das erste Fenster abgegeben)
async function gateStart() {
  if (!gateOn) return bootApp();
  const got = await gateTry();
  gateReady = true;
  if (got) return bootApp();
  locked = true;
  const sh = parseShared(location.hash);
  if (sh && ['r', 'e', 'i', 'f'].includes(sh.kind) && await handOff(location.hash)) return;
  showTabLock();
}
window.addEventListener('hashchange', () => !locked && handleHash().catch(() => toast('Link/Code konnte nicht gelesen werden')));

// Erster Start: Modus wählen (vorhandene Daten -> Einsatzleitung)
async function chooseModeIfNeeded() {
  if (db.mode) return;
  if (parseShared(location.hash)) return; // Auftrag-Link legt den Modus fest
  if (Object.values(db.projects).some((p) => p.area || p.items.length)) { db.mode = 'el'; saveNow(); return; }
  const m = await openDlg((box, close) => {
    dlgHead(box, 'Wie nutzt du die App?', 'Lässt sich später unter „⚙️ Mehr“ ändern.');
    const list = document.createElement('div');
    list.className = 'dlg-btns';
    box.appendChild(list);
    dlgButton(list, '🧭 Einsatzleitung<small>Alles: Raster, Teams, Aufträge, Berichte</small>', 'primary', () => close('el'));
    dlgButton(list, '🐕 Hundeführer<small>Vereinfacht: Auftrag, Weg, Markieren, Zurückgeben</small>', '', () => close('hf'));
    dlgButton(list, '📷 Einsatz übernehmen<small>Weiteres Gerät der Einsatzleitung: QR-Code vom anderen Gerät scannen</small>', '', () => close('scan'));
  });
  if (m === 'hf') await toHfMode(); else { db.mode = 'el'; saveNow(); }
  if (m === 'scan') startScan();
  // frisches Gerät der Einsatzleitung: gleich mit dem Assistenten beginnen
  if (m === 'el' && !P.title && !P.area) { P.title = wizTitle(); $('title').value = P.title; applyClosed(); openWizard(0); }
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
    const info = contactInfo(c, true);
    const edit = document.createElement('button');
    edit.textContent = '✏️';
    edit.title = 'Bearbeiten';
    edit.addEventListener('click', () => openContactForm(c.id));
    row.append(info, edit);
    box.appendChild(row);
  }
}

// Name, Funktion, Funkrufname und Nummern (antippen = anrufen); full: auch Organisation, E-Mail, Notiz
function contactInfo(c, full) {
  const info = document.createElement('div');
  info.className = 'ctinfo';
  const b = document.createElement('b');
  b.textContent = c.name || c.phone;
  info.appendChild(b);
  const sub = [c.role, full && c.org, c.call && `📻 ${c.call}`].filter(Boolean).join(' · ');
  if (sub) { const sm = document.createElement('small'); sm.textContent = sub; info.appendChild(sm); }
  const link = (href, text) => { const a = document.createElement('a'); a.href = href; a.textContent = text; info.appendChild(a); };
  if (c.phone) link(telHref(c.phone), `📞 ${c.phone}`);
  if (c.phone2) link(telHref(c.phone2), `📞 ${c.phone2}`);
  if (full && c.email) link(`mailto:${c.email}`, `✉️ ${c.email}`);
  if (full && c.note) { const sm = document.createElement('small'); sm.textContent = c.note; info.appendChild(sm); }
  return info;
}

// ---------- Kontakte dieses Einsatzes (P.contacts) ----------
// Die Einsatzleitung (P.lead) steht immer als erster Kontakt dabei, wird aber nicht doppelt gespeichert
function leadContact() {
  const l = P.lead || {};
  if (!(l.name || P.leader || l.phone)) return null;
  return normalizeContact({ id: 'lead', name: l.name || P.leader, role: 'Einsatzleitung', call: l.call, phone: l.phone });
}
function renderProjectContacts() {
  if (!$('panel-wizard').hidden && P.wiz != null && WIZ_STEPS[P.wiz][0] === 'contacts') renderWizard();
  const box = $('pc-list');
  box.innerHTML = '';
  const lead = leadContact();
  if (lead) { const row = document.createElement('div'); row.className = 'ctrow'; row.appendChild(contactInfo(lead)); box.appendChild(row); }
  for (const c of P.contacts) {
    const row = document.createElement('div');
    row.className = 'ctrow';
    const del = document.createElement('button');
    del.textContent = '✕';
    del.title = 'Aus dem Einsatz entfernen (bleibt im Adressbuch)';
    del.addEventListener('click', () => { P.contacts = P.contacts.filter((x) => x !== c); touch(); renderProjectContacts(); });
    row.append(contactInfo(c), del);
    box.appendChild(row);
  }
  if (!lead && !P.contacts.length) box.innerHTML = '<p class="small">Noch keine – Name/Handy der Einsatzleitung eintragen oder Kontakte hinzufügen.</p>';
}
$('pc-add').addEventListener('click', () => openDlg((box, close) => {
  dlgHead(box, '📇 Kontakte für diesen Einsatz', 'Aus dem Adressbuch anhaken.');
  const q = document.createElement('input');
  q.type = 'search';
  q.placeholder = 'Suchen …';
  const list = document.createElement('div');
  list.className = 'checklist';
  list.style.maxHeight = '50vh';
  list.style.overflow = 'auto';
  const have = new Set(P.contacts.map((c) => `${c.name}|${c.phone}`));
  const picked = new Set();
  const draw = () => {
    list.innerHTML = '';
    const found = sortContacts(db.contacts).filter((c) => ctMatches(c, q.value) && !have.has(`${c.name}|${c.phone}`));
    if (!db.contacts.length) list.innerHTML = '<p class="small">Das Adressbuch ist leer.</p>';
    for (const c of found) {
      const l = document.createElement('label');
      l.className = 'check';
      l.innerHTML = '<input type="checkbox"><span></span>';
      l.firstChild.checked = picked.has(c.id);
      l.firstChild.addEventListener('change', (e) => { if (e.target.checked) picked.add(c.id); else picked.delete(c.id); });
      l.lastChild.textContent = [c.name, c.role, c.phone].filter(Boolean).join(' · ');
      list.appendChild(l);
    }
  };
  q.addEventListener('input', draw);
  box.append(q, list);
  draw();
  dlgButton(box, 'Übernehmen', 'primary', () => {
    for (const c of db.contacts) if (picked.has(c.id)) P.contacts.push(normalizeContact({ ...c, id: uid() }));
    touch();
    renderProjectContacts();
    close(true);
  });
  dlgButton(box, 'Abbrechen', '', () => close(false));
}));
$('pc-new').addEventListener('click', () => openDlg((box, close) => {
  dlgHead(box, '📇 Neuer Kontakt für diesen Einsatz', '');
  const f = {};
  for (const [k, label] of [['name', 'Name'], ['role', 'Funktion'], ['call', 'Funkrufname'], ['phone', 'Telefon']]) {
    const l = document.createElement('label');
    l.textContent = label;
    f[k] = document.createElement('input');
    if (k === 'phone') { f[k].type = 'tel'; f[k].inputMode = 'tel'; }
    l.appendChild(f[k]);
    box.appendChild(l);
  }
  const keep = document.createElement('p');
  keep.className = 'small';
  keep.textContent = 'Wird auch im Adressbuch („Kontakte“) gespeichert.';
  box.appendChild(keep);
  dlgButton(box, 'Speichern', 'primary', () => {
    const c = normalizeContact(Object.fromEntries(Object.entries(f).map(([k, inp]) => [k, inp.value])));
    if (!c.name && !c.phone) return toast('Bitte Name oder Telefon eintragen');
    P.contacts.push(c);
    // auch ins Adressbuch (ohne Doppelte)
    db.contacts = mergeContacts(db.contacts, [c]).list;
    renderContacts();
    touch();
    renderProjectContacts();
    close(true);
  });
  dlgButton(box, 'Abbrechen', '', () => close(false));
  setTimeout(() => f.name.focus(), 50);
}));

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
    const saved = saveNow();
    closeContactForm();
    if (saved) toast(`Kontakt „${n.name}“ gespeichert`);
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
  renderProjectContacts();
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
  shareFile(contactsFile(), fileName('Kontakte', '', '.vcf'), 'Kontakte', 'Adressbuch (vCard) – in RHS Einsatz unter Kontakte → Importieren öffnen.');
});
$('ct-save').addEventListener('click', () => {
  if (!db.contacts.length) return toast('Noch keine Kontakte');
  saveFile(contactsFile(), fileName('Kontakte', '', '.vcf'));
});

// ---------- Kartenart ----------
function renderLayerList() {
  const box = $('layer-list');
  box.innerHTML = '';
  for (const l of LAYERS) {
    const b = document.createElement('button');
    b.textContent = l.name;
    b.classList.toggle('active', l.id === P.layerId);
    b.addEventListener('click', () => setLayer(l.id, true));
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
let lastFix = null; // letzter Wert der Standortanzeige mit Genauigkeit und Zeit: { lat, lon, acc, t }
const FOLLOW_PAUSE = 15000; // ms ohne Mitführen, nachdem die Karte von Hand verschoben wurde

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

// Zum Standort springt die Karte nur auf Tipp auf „GPS“; mitgeführt wird sie nur im
// Hundeführer-Modus, solange ein Weg aufgezeichnet wird.
let gpsJump = false;
const gpsFollow = () => db.mode === 'hf' && recWatch !== null;
function stopGps() {
  if (watchId !== null) navigator.geolocation.clearWatch(watchId);
  watchId = null;
  lastPos = null;
  lastFix = null;
  if (gpsMarker) { map.removeLayer(gpsMarker); map.removeLayer(gpsCircle); gpsMarker = null; }
  $('btn-gps').classList.remove('on');
  updateStatus();
}
$('btn-gps').addEventListener('click', () => {
  if (watchId !== null) {
    // schon an: Standort außerhalb der Mitte -> hinspringen, sonst ausschalten
    if (lastPos) {
      const c = map.latLngToContainerPoint(lastPos);
      const m = map.getSize();
      if (Math.hypot(c.x - m.x / 2, c.y - m.y / 2) > 40) { map.setView(lastPos, Math.max(map.getZoom(), 16)); return; }
    }
    return stopGps();
  }
  startGps(true);
});
// quiet: automatischer Start (z. B. beim Auftrag) – eine Ablehnung der Berechtigung schaltet still wieder aus, ohne Meldung
function startGps(jump, quiet = false) {
  if (!navigator.geolocation) return quiet ? undefined : toast('Standort wird nicht unterstützt');
  if (watchId !== null) return;
  gpsJump = jump;
  $('btn-gps').classList.add('on');
  watchId = navigator.geolocation.watchPosition((pos) => {
    const ll = [pos.coords.latitude, pos.coords.longitude];
    lastPos = ll;
    lastFix = { lat: ll[0], lon: ll[1], acc: pos.coords.accuracy, t: Date.now() };
    if (!gpsMarker) {
      gpsCircle = L.circle(ll, { radius: pos.coords.accuracy, weight: 1, color: '#1e88e5', fillOpacity: 0.1 }).addTo(map);
      gpsMarker = L.marker(ll, { icon: L.divIcon({ className: '', html: '<div class="gps-dot"></div>', iconSize: [22, 22] }) }).addTo(map);
    } else {
      gpsMarker.setLatLng(ll);
      gpsCircle.setLatLng(ll).setRadius(pos.coords.accuracy);
    }
    // nach dem Tipp auf „GPS“ einmal hinspringen; beim Weg-Aufzeichnen (HF) in der Mitte halten –
    // außer kurz nachdem man die Karte selbst verschoben hat
    if (gpsJump) { map.setView(ll, Math.max(map.getZoom(), 16)); gpsJump = false; }
    else if (gpsFollow() && Date.now() - userMovedAt > FOLLOW_PAUSE) map.panTo(ll, { animate: true, duration: 0.5 });
    updateStatus();
  }, (err) => {
    if (quiet && err.code === 1) { stopGps(); return; } // abgelehnt: nicht weiter nachfragen
    toast('Standort nicht verfügbar: ' + (err.message || 'kein GPS-Empfang'));
  }, { enableHighAccuracy: true, maximumAge: 5000 });
}

// ---------- Suchgebiete (Projekte) ----------
function switchProject(id) {
  if (recWatch !== null) stopRec(); // Aufzeichnung gehört zum alten Einsatz
  endGridFit();
  endVertex();
  saveNow();
  db.currentId = id;
  P = db.projects[id];
  ensureLiveOpen();
  gapView = null;
  syncGrid();
  restoreDrafts();
  setTool('pan');
  undoStack = [];
  // Suchnadel (z. B. Adresse des alten B-Orts) gehört nicht zum neuen Einsatz
  if (searchPin) { map.removeLayer(searchPin); searchPin = null; }
  if (P.view) map.setView([P.view.lat, P.view.lon], P.view.z);
  else if (grid) map.fitBounds([[P.area.south, P.area.west], [P.area.north, P.area.east]]);
  setLayer(P.layerId);
  fillProjectForm();
  changed();
  updateStatus();
}

function fillProjectForm() {
  $('title').value = P.title;
  $('leader').value = P.leader || P.lead.name || '';
  $('lead-phone').value = P.lead.phone || '';
  $('lead-call').value = P.lead.call || '';
  $('lead-elw').value = P.lead.elw || '';
  renderProjectContacts();
  renderWizBtn();
  renderMeet();
  renderPois();
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
      + (g ? ` · ${g.cols}×${g.rows} Felder à ${formatMeters(g.cellM)}` : ' · kein Raster')
      + (p.closed ? ' · ✅ abgeschlossen' : '');
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
      c.eid = c.id;
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

// v127: bestehender Einsatz ohne Live-Kanal bekommt beim Öffnen einen (nicht für leere Karten, abgeschlossene, Hundeführer)
function ensureLiveOpen() {
  if (!P || db.mode !== 'el' || P.closed || isBlankProject(P)) return;
  ensureLive(P, liveUrlNow());
}
// v127: Adresse des Status-Servers für neue Live-Kanäle (eigene Einstellung, sonst Standard)
function liveUrlNow() { return db.statusUrl || STATUS_URL; }
function createProject(title) {
  const p = createProject0(title);
  if (db.mode === 'el' && ensureLive(p, (p.live && p.live.url) || liveUrlNow())) saveNow(); // v127: Live-Kanal gleich beim Anlegen
  return p;
}
function createProject0(title) {
  // eine leere freie Karte wird weiterverwendet statt eine zweite anzulegen
  if (isBlankProject(P)) {
    P.title = title;
    fillProjectForm();
    renderProjects();
    changed();
    save();
    return P;
  }
  const p = normalizeProject(newProject(title)); // v127: normalisieren -> Einsatz-ID (eid) gleich da, sonst findet ein Fortschritt aus dem UA den Einsatz nicht
  p.layerId = devLayer() || P.layerId;
  p.cellM = P.cellM;
  const c = map.getCenter();
  p.view = { lat: c.lat, lon: c.lng, z: map.getZoom() };
  db.projects[p.id] = p;
  switchProject(p.id);
  renderProjects();
  return p;
}
$('proj-new').addEventListener('click', async () => {
  const how = await openDlg((box, close) => {
    dlgHead(box, '+ Neuer Einsatz', 'Der Assistent fragt Einsatzleitung, Funk, B-Ort, Wetter, Person, Zeiten und Kontakte ab. Jeder Schritt lässt sich überspringen.');
    dlgButton(box, '🧭 Mit Assistent', 'primary', () => close('wiz'));
    dlgButton(box, 'Ohne Assistent (nur Name)', '', () => close('plain'));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!how) return;
  if (how === 'plain') {
    const t = prompt('Name des neuen Suchgebiets:', '');
    if (t !== null) createProject(t.trim() || wizTitle());
    return;
  }
  const p = createProject(wizTitle());
  p.wiz = 0;
  openWizard(0);
});

// ---------- Assistent „Neuen Einsatz anlegen“ ----------
// Eingaben landen sofort im Einsatz; P.wiz = offener Schritt (fehlt, wenn fertig)
let wizMeet = false; // B-Ort wird gerade auf der Karte gesetzt
let wizRevisit = false; // Assistent für einen schon fertigen Einsatz geöffnet: Schließen lässt ihn fertig
function openWizard(step = P.wiz ?? 0) {
  if ($('panel-wizard').hidden && !wizMeet) wizRevisit = P.wiz == null;
  P.wiz = Math.max(0, Math.min(WIZ_STEPS.length - 1, step));
  save();
  renderWizard();
  openPanel('panel-wizard');
  $('panel-wizard').scrollTop = 0;
}
function wizGo(step) {
  if (step >= WIZ_STEPS.length) return wizFinish();
  openWizard(step);
}
function wizFinish() {
  delete P.wiz;
  touch();
  closePanels();
  renderWizBtn();
  toast(`„${P.title || 'Einsatz'}“ angelegt`);
}
function renderWizBtn() {
  $('wiz-open').textContent = P.wiz != null ? `🧭 Assistent fortsetzen (${WIZ_STEPS[P.wiz][1]})` : '🧭 Einsatz-Assistent';
  $('wiz-open').classList.toggle('primary', P.wiz != null);
  const n = P.radio.filter((r) => r.call || r.who).length;
  $('radio-edit').textContent = `📻 Weitere Funkrufnamen${n ? ` (${n})` : ''}`;
}
$('wiz-open').addEventListener('click', () => openWizard(P.wiz ?? 0));
$('radio-edit').addEventListener('click', () => openWizard(1));
$('wz-back').addEventListener('click', () => wizGo(P.wiz - 1));
$('wz-skip').addEventListener('click', () => wizGo(P.wiz + 1));
$('wz-next').addEventListener('click', () => wizGo(P.wiz + 1));
$('wz-exit').addEventListener('click', () => {
  if (wizRevisit) { delete P.wiz; touch(); } else toast('Assistent unter „Einsatz → Stammdaten“ fortsetzen');
  closePanels();
  renderWizBtn();
});

// Uhrzeit-Feld ohne den Android-Uhrzeit-Dialog (dort fehlte teils „Festlegen“): Ziffern tippen, z. B. 1430
function timeField(inp, value, onSet) {
  inp.type = 'text';
  inp.inputMode = 'numeric';
  inp.placeholder = 'hh:mm';
  inp.maxLength = 5;
  inp.autocomplete = 'off';
  inp.className = 'tfield';
  inp.value = value || '';
  inp.addEventListener('input', () => {
    const d = inp.value.replace(/\D/g, '').slice(0, 4);
    if (!inp.value.includes(':') && d.length === 4) inp.value = `${d.slice(0, 2)}:${d.slice(2)}`;
    const v = normTime(inp.value);
    if (v && inp.value.length >= 4) onSet(v);
  });
  const fin = () => {
    const v = normTime(inp.value);
    if (v === null) { toast('Uhrzeit bitte als hh:mm eingeben, z. B. 14:30'); inp.value = value || ''; return; }
    inp.value = v;
    if (v !== value) { value = v; onSet(v); }
  };
  inp.addEventListener('change', fin);
  inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); inp.blur(); } });
  return inp;
}
function wizField(box, label, value, onInput, type = 'text', extra = {}) {
  const l = document.createElement('label');
  l.textContent = label;
  const inp = document.createElement(type === 'textarea' ? 'textarea' : 'input');
  if (type !== 'textarea') inp.type = type;
  else inp.rows = 3;
  if (type === 'tel') inp.inputMode = 'tel';
  Object.assign(inp, extra);
  inp.value = value || '';
  inp.addEventListener('input', () => { onInput(inp.value); touch(); });
  l.appendChild(inp);
  box.appendChild(l);
  return inp;
}
function wizText(box, text, cls = 'small') {
  const p = document.createElement('p');
  p.className = cls;
  p.textContent = text;
  box.appendChild(p);
  return p;
}
function wizBtn(box, label, fn, cls = '') {
  const b = document.createElement('button');
  b.innerHTML = label;
  if (cls) b.className = cls;
  b.addEventListener('click', fn);
  box.appendChild(b);
  return b;
}

function renderWizard() {
  const i = P.wiz ?? 0;
  const [key, name] = WIZ_STEPS[i];
  $('wz-title').textContent = `🧭 ${i + 1}/${WIZ_STEPS.length} · ${name}`;
  $('wz-dots').innerHTML = WIZ_STEPS.map((_, k) => `<i class="${k < i ? 'done' : k === i ? 'cur' : ''}"></i>`).join('');
  $('wz-back').disabled = i === 0;
  $('wz-skip').hidden = key === 'done' || key === 'name';
  $('wz-next').textContent = key === 'done' ? 'Fertig ✓' : 'Weiter ›';
  const box = $('wz-body');
  box.innerHTML = '';
  WIZ[key](box);
}
const WIZ = {
  name(box) {
    const inp = wizField(box, 'Name des Einsatzes (Überschrift im PDF)', P.title, (v) => { P.title = v; $('title').value = v; });
    setTimeout(() => { inp.focus(); inp.select(); }, 50);
  },
  lead(box) {
    const setLead = (k) => (v) => { P.lead[k] = v; if (k === 'name') P.leader = v; };
    const last = lastLead(db.projects, P.id);
    if (last && !P.lead.name && !P.lead.phone) {
      wizBtn(box, `↺ wie letzter Einsatz: ${esc([last.lead.name, last.lead.call].filter(Boolean).join(' · ') || 'Einsatzleitung')}`, () => {
        P.lead = { ...P.lead, ...last.lead };
        P.leader = P.lead.name;
        if (!P.radio.length) P.radio = last.radio;
        touch();
        renderWizard();
      });
    }
    wizField(box, 'Name Einsatzleitung', P.lead.name || P.leader, setLead('name'));
    wizField(box, 'Handy Einsatzleitung', P.lead.phone, setLead('phone'), 'tel', { placeholder: '0170 …' });
    const r2 = document.createElement('div');
    r2.className = 'row2';
    box.appendChild(r2);
    wizField(r2, 'Funkrufname EL', P.lead.call, setLead('call'), 'text', { placeholder: 'z. B. Rettungshund 1' });
    wizField(r2, 'Funkrufname ELW', P.lead.elw, setLead('elw'), 'text', { placeholder: 'z. B. Rotkreuz 11-1' });
    const h = document.createElement('label');
    h.textContent = '📻 Weitere Funkrufnamen';
    box.appendChild(h);
    wizText(box, 'Stehen auf der Einsatzinfo-Seite im PDF.');
    P.radio.forEach((r, k) => {
      const row = document.createElement('div');
      row.className = 'wz-radio';
      for (const [f, ph] of [['call', 'Funkrufname'], ['who', 'wer (z. B. Zugführer, Polizei)']]) {
        const inp = document.createElement('input');
        inp.type = 'text';
        inp.placeholder = ph;
        inp.value = r[f] || '';
        inp.addEventListener('input', () => { r[f] = inp.value; touch(); });
        row.appendChild(inp);
      }
      wizBtn(row, '✕', () => { P.radio.splice(k, 1); touch(); renderWizard(); });
      box.appendChild(row);
    });
    wizBtn(box, '+ Funkrufname', () => {
      P.radio.push({ call: '', who: '' });
      touch();
      renderWizard();
      const rows = box.querySelectorAll('.wz-radio input');
      if (rows.length) rows[rows.length - 2].focus();
    });
  },
  meet(box) {
    const m = P.meet;
    wizText(box, m ? `✅ ${m.text || 'B-Ort'}: ${m.lat.toFixed(5)}, ${m.lon.toFixed(5)}${P.showUtm ? ` · ${formatMgrs(m.lat, m.lon)}` : ''}` : 'Noch kein B-Ort gesetzt.', 'info');
    const big = document.createElement('div');
    big.className = 'wz-big';
    box.appendChild(big);
    wizBtn(big, '📍 Mein Standort (GPS)', wizMeetGps);
    wizBtn(big, '🔎 Adresse oder Kreuzung suchen', () => {
      wizMeet = true;
      closePanels();
      setTool('meet');
      openSearch();
      toast('Adresse oder Kreuzung oben eingeben, dann auf den genauen B-Ort tippen', 7000);
    });
    wizBtn(big, '🗺️ Auf der Karte antippen', () => {
      wizMeet = true;
      closePanels();
      setTool('meet');
    });
  },
  wx(box) {
    const pt = P.meet || (() => { const c = map.getCenter(); return { lat: c.lat, lon: c.lng }; })();
    wizText(box, P.meet ? 'DWD-Wetter am B-Ort:' : 'Kein B-Ort – DWD-Wetter an der Kartenmitte:');
    const out = wizText(box, 'Wird geladen …', 'wz-wx');
    fetchWeather(pt.lat, pt.lon).then((wx) => {
      db.wxLast = wx;
      const c = wx.current || {};
      const lines = [];
      if (c.from != null) lines.push(`🧭 Wind aus ${dirName(c.from)} (${Math.round(c.from)}°), ${Math.round(c.kmh ?? 0)} km/h${c.gust ? `, Böen ${Math.round(c.gust)} km/h` : ''} · ${beaufort(c.kmh ?? 0)} Bft`);
      if (c.temp != null) lines.push(`🌡️ ${Math.round(c.temp)} °C${c.cond ? ` · ${CONDITIONS[c.cond] || c.cond}` : ''}`);
      if (c.station) lines.push(`Station ${c.station}${c.km != null ? ` (${c.km.toFixed(0)} km)` : ''}, ${hhmm(c.t)}`);
      out.textContent = lines.join('\n') || 'Keine Wetterdaten.';
      out.style.whiteSpace = 'pre-line';
      // Startwert ins Windprotokoll des Einsatzes
      if (c.from != null && c.kmh != null && !(M().wind || []).some((w) => w.src === 'DWD' && w.t === c.t)) {
        M().wind.push({ t: c.t, from: c.from, kmh: c.kmh, gust: c.gust, station: c.station, src: 'DWD' });
        M().wind.sort((a, b) => a.t - b.t);
        touch();
      }
    }).catch(() => { out.textContent = 'Wetter nicht abrufbar (kein Netz?). Später über „Wetter“ links nachholen.'; });
    const on = wizBtn(box, db.wxOn ? '✅ Wetter wird auf der Karte angezeigt' : '🌦️ Wetter auf der Karte anzeigen', () => {
      db.wxOn = true;
      saveNow();
      renderWx();
      loadWeather(false);
      on.textContent = '✅ Wetter wird auf der Karte angezeigt';
    });
  },
  person(box) {
    const inp = wizField(box, 'Vermisste Person', M().person, (v) => { M().person = v; }, 'textarea', { placeholder: 'Name, Alter, Kleidung, Erkrankungen, Besonderheiten …' });
    setTimeout(() => inp.focus(), 50);
  },
  times(box) {
    const t = M().times;
    const row = (k, label) => {
      const l = document.createElement('label');
      l.textContent = label;
      const r = document.createElement('div');
      r.className = 'wz-radio';
      const inp = document.createElement('input');
      timeField(inp, t[k], (v) => { if (v) t[k] = v; else delete t[k]; if (k === 'alarm' && v && !t.alarmDate) { t.alarmDate = isoDate(new Date()); const di = inp.closest('.wz-body, #ms-times, #panel-wizard')?.querySelector('input[type=date]'); if (di) di.value = t.alarmDate; } touch(); });
      r.appendChild(inp);
      wizBtn(r, 'Jetzt', () => {
        const d = new Date();
        t[k] = hhmmOf(d);
        if (k === 'alarm') t.alarmDate = isoDate(d);
        touch();
        renderWizard();
      });
      l.appendChild(r);
      box.appendChild(l);
    };
    row('alarm', 'Alarmierung');
    wizField(box, 'Datum der Alarmierung', t.alarmDate || '', (v) => { t.alarmDate = v; }, 'date');
    row('arrive', 'Eintreffen Einsatzstelle (optional)');
    wizText(box, 'Weitere Zeiten und Kräfte im Fenster „Einsatz“, Suchhelfer je Team unter „Teams“.');
  },
  contacts(box) {
    wizText(box, 'Gehen auf Wunsch mit dem Auftrag an die Hundeführer. Die Einsatzleitung ist immer dabei.');
    const list = document.createElement('div');
    list.className = 'ctlist';
    box.appendChild(list);
    const lead = P.lead.name || P.lead.phone ? [`👤 ${[P.lead.name, P.lead.phone].filter(Boolean).join(' · ')} (Einsatzleitung)`] : [];
    for (const line of [...lead, ...P.contacts.map((c) => `📇 ${[c.name, c.role, c.phone].filter(Boolean).join(' · ')}`)]) wizText(list, line, 'info');
    if (!lead.length && !P.contacts.length) wizText(list, 'Noch keine Kontakte.');
    const r = document.createElement('div');
    r.className = 'row';
    box.appendChild(r);
    wizBtn(r, '+ aus Adressbuch', () => $('pc-add').click());
    wizBtn(r, '+ neuer Kontakt', () => $('pc-new').click());
  },
  done(box) {
    wizText(box, `„${P.title || 'Einsatz'}“ ist angelegt. Alles lässt sich später unter „Einsatz“ ändern.`);
    const big = document.createElement('div');
    big.className = 'wz-big';
    box.appendChild(big);
    wizBtn(big, '# Raster aufziehen', () => { wizFinish(); setTool('grid'); });
    wizBtn(big, '📐 Umriss zeichnen', () => { wizFinish(); setTool('track'); });
    wizBtn(big, '📲 An Tablet/PC übergeben', () => { wizFinish(); $('ho-send').click(); });
  },
};

// B-Ort per GPS: frischer Standort der GPS-Anzeige, sonst einmal abfragen
function wizMeetGps() {
  const setAt = (lat, lon, acc) => {
    if (P.meet && blocked(P.meet)) return;
    P.meet = { lat, lon, text: (P.meet && P.meet.text) || 'B-Ort', ...(P.meet && P.meet.lock ? { lock: P.meet.lock } : {}) };
    map.setView([lat, lon], Math.max(map.getZoom(), 15));
    changed();
    renderMeet();
    toast(`B-Ort am Standort gesetzt${acc ? ` (± ${Math.round(acc)} m)` : ''}`);
    wizGo(P.wiz + 1);
  };
  if (lastPos) return setAt(lastPos[0], lastPos[1], null);
  if (!navigator.geolocation) return toast('Standort wird nicht unterstützt');
  toast('Standort wird gesucht …', 20000);
  navigator.geolocation.getCurrentPosition(
    (pos) => setAt(pos.coords.latitude, pos.coords.longitude, pos.coords.accuracy),
    (err) => toast(`Standort nicht verfügbar: ${err.message || 'kein GPS-Empfang'}`),
    { enableHighAccuracy: true, timeout: 20000, maximumAge: 10000 },
  );
}

$('leader').addEventListener('input', () => { P.leader = $('leader').value; P.lead.name = P.leader; P.updated = Date.now(); save(); renderProjectContacts(); });
for (const [id, k] of [['lead-phone', 'phone'], ['lead-call', 'call'], ['lead-elw', 'elw']]) {
  $(id).addEventListener('input', () => { P.lead[k] = $(id).value; P.updated = Date.now(); save(); renderProjectContacts(); });
}
$('pdf-caption').addEventListener('input', () => { P.caption = $('pdf-caption').value; P.updated = Date.now(); save(); });
$('meet-set').addEventListener('click', () => { closePanels(); setTool('meet'); });

// ---------- Lage-Orte ----------
let poiDraft = null; // { cat } bzw. { move: Lage-Ort } – wartet auf den Kartentipp
function poiAt(x, y) {
  if ((P.hide || {}).pois) return -1;
  let best = -1;
  let bd = 18;
  P.pois.forEach((p, i) => {
    const [px, py] = toPx(p.lat, p.lon);
    const d = Math.hypot(px - x, py - y);
    if (d <= bd) { bd = d; best = i; }
  });
  return best;
}
function renderPois() {
  const box = $('poi-list');
  box.innerHTML = '';
  if (!P.pois.length) { box.innerHTML = '<p class="small">Noch keine Lage-Orte.</p>'; return; }
  for (const p of sortPois(P.pois)) {
    const row = document.createElement('div');
    row.className = 'ct';
    row.innerHTML = '<div class="ctmain"><b></b><span class="small"></span></div><button title="Auf der Karte zeigen">🎯</button><button title="Bearbeiten">✏️</button>';
    row.querySelector('b').textContent = poiLabel(p);
    row.querySelector('span').textContent = p.desc || '';
    const [go, ed] = row.querySelectorAll('button');
    go.classList.add('keep');
    go.addEventListener('click', () => { closePanels(); map.setView([p.lat, p.lon], Math.max(map.getZoom(), 16)); });
    ed.addEventListener('click', () => editPoi(p));
    box.appendChild(row);
  }
}
function pickPoiCat(current) {
  return openDlg((box, close) => {
    dlgHead(box, '📍 Lage-Ort', 'Was ist dort?');
    const grid = document.createElement('div');
    grid.className = 'poi-cats';
    for (const c of POI_CATS) {
      const b = document.createElement('button');
      b.innerHTML = `<span>${c.icon}</span>${c.label}`;
      if (c.id === current) b.className = 'primary';
      b.addEventListener('click', () => close(c.id));
      grid.appendChild(b);
    }
    box.appendChild(grid);
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
}
// Name und Hinweis; Rückgabe null = abgebrochen, 'cat' / 'move' / 'delete' = andere Aktion
function poiTextDlg(p, isNew) {
  return openDlg((box, close) => {
    const c = poiCat(p.cat);
    dlgHead(box, `${c.icon} ${c.label}`, isNew ? 'Name und Hinweis sind freiwillig.' : (p.by ? `Zuletzt geändert von ${p.by}` : ''));
    const name = document.createElement('input');
    name.type = 'text';
    name.placeholder = `Name (z. B. „${c.id === 'elw' ? 'ELW 11-1' : `${c.label} Nord`}“)`;
    name.value = p.name || '';
    const desc = document.createElement('textarea');
    desc.rows = 3;
    desc.placeholder = 'Hinweis (z. B. Zufahrt über Waldweg, Ansprechpartner …)';
    desc.value = p.desc || '';
    box.append(name, desc);
    dlgButton(box, isNew ? 'Speichern' : 'Übernehmen', 'primary', () => close({ name: name.value.trim(), desc: desc.value.trim() }));
    if (!isNew) {
      dlgNavButton(box, close, null, poiName(p), p.lat, p.lon); // v123
      if (db.mode === 'el' && P.live && elTargets(P.sent, P.marks).length) dlgButton(box, '📤 An Team senden', '', () => close('zus')); // v130
      dlgButton(box, '🔁 Art ändern', '', () => close('cat'));
      dlgButton(box, '📍 Verschieben', '', () => close('move'));
      dlgButton(box, '🗑️ Löschen', '', () => close('delete'));
    }
    dlgButton(box, 'Abbrechen', '', () => close(null));
    setTimeout(() => name.focus(), 50);
  });
}
async function addPoi() {
  if (isLocked()) return lockedToast();
  const cat = await pickPoiCat();
  if (!cat) return;
  const c = poiCat(cat);
  const where = await openDlg((box, close) => {
    dlgHead(box, `${c.icon} ${c.label}`, 'Wo ist der Ort? Für eine Adresse erst oben suchen, dann „Auf der Karte tippen“.');
    dlgButton(box, '📍 Mein Standort (GPS)', 'primary', () => close('gps'));
    dlgButton(box, '🗺️ Auf der Karte tippen', '', () => close('map'));
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
  if (!where) return;
  poiDraft = { cat };
  closePanels(); // danach zeigt die Karte den neuen Ort
  if (where === 'map') {
    setTool('poi');
    return;
  }
  if (lastPos) return placePoi(lastPos[0], lastPos[1]);
  if (!navigator.geolocation) { poiDraft = null; return toast('Standort wird nicht unterstützt'); }
  toast('Standort wird gesucht …', 20000);
  navigator.geolocation.getCurrentPosition(
    (pos) => placePoi(pos.coords.latitude, pos.coords.longitude, pos.coords.accuracy),
    (err) => { poiDraft = null; toast(`Standort nicht verfügbar: ${err.message || 'kein GPS-Empfang'}`); },
    { enableHighAccuracy: true, timeout: 20000, maximumAge: 10000 },
  );
}
async function placePoi(lat, lon, acc = null) {
  const d = poiDraft;
  poiDraft = null;
  if (!d) return;
  if (d.move) {
    snapshot();
    d.move.lat = Math.round(lat * 1e6) / 1e6;
    d.move.lon = Math.round(lon * 1e6) / 1e6;
    d.move.t = Date.now();
    d.move.by = devBy();
    d.move.bi = devId(); // v125
    changed();
    renderPois();
    return toast(`${poiLabel(d.move)} verschoben`);
  }
  const p = newPoi({ cat: d.cat, lat, lon, by: devBy() });
  p.bi = devId(); // v125
  const r = await poiTextDlg(p, true);
  if (!r) return;
  p.name = r.name;
  p.desc = r.desc;
  snapshot();
  P.pois.push(p);
  map.setView([lat, lon], Math.max(map.getZoom(), 15));
  changed();
  renderPois();
  toast(`${poiLabel(p)} gesetzt${acc ? ` (± ${Math.round(acc)} m)` : ''}`);
}
async function editPoi(p) {
  if (isLocked()) return lockedToast();
  if (blocked(p)) return;
  const r = await poiTextDlg(p, false);
  if (!r) return;
  if (r === 'zus') return zusatzDialog({ poiIds: [p.id] }); // v130
  if (r === 'move') {
    poiDraft = { move: p };
    closePanels();
    setTool('poi');
    return;
  }
  if (r === 'delete') {
    if (blocked(p, 'delete')) return;
    if (!confirm(`„${poiName(p)}“ löschen?`)) return;
    snapshot();
    deletePoi(P, p);
  } else if (r === 'cat') {
    const cat = await pickPoiCat(p.cat);
    if (!cat) return;
    snapshot();
    p.cat = cat;
  } else {
    snapshot();
    p.name = r.name;
    p.desc = r.desc;
  }
  p.t = Date.now();
  p.by = devBy();
  p.bi = devId(); // v125
  changed();
  renderPois();
}
$('poi-add').addEventListener('click', addPoi);
$('meet-remove').addEventListener('click', () => {
  if (!P.meet || blocked(P.meet, 'delete')) return;
  snapshot();
  P.meet = null;
  changed();
  renderMeet();
});

// withTime=false: nur Datum (kürzer, z. B. als Listenname in BaseCamp)
// Dateiname im einheitlichen Schema (files.js): Einsatz_Datum_Uhrzeit_Inhalt.ext
function safeName(what, ext) {
  return fileName(P.title, what, ext);
}

$('proj-share').addEventListener('click', async () => {
  saveNow();
  const text = exportProject(P);
  const title = P.title || 'Suchgebiet';
  const msg = `Suchgebiet „${title}“ – in der App RHS Einsatz unter „Einsätze → Datei öffnen“ laden.`;
  const json = new Blob([text], { type: 'application/json' });
  await shareFile(json, safeName('Einsatzdatei', '.suchgebiet.json'), title, msg, null, true);
});

$('proj-import').addEventListener('click', () => $('import-file').click());
$('import-file').addEventListener('change', async () => {
  const f = $('import-file').files[0];
  $('import-file').value = '';
  if (!f) return;
  await importFile(f.name, await f.arrayBuffer());
});

// Datei aus „Datei öffnen“, „Teilen“ (WhatsApp …) oder „Öffnen mit“ (Android-App).
// GPX/KML: in den laufenden Einsatz (shared: vorher nachfragen); Suchgebiet/PDF der App: als Einsatz laden.
async function importFile(name, buf, shared = false) {
  try {
    const text = new TextDecoder('latin1').decode(buf);
    const head = text.slice(0, 4000);
    const gpx = /\.gpx$/i.test(name) || /^\s*(<\?xml[^>]*>\s*)?<gpx\b/i.test(head);
    const kml = !gpx && (/\.kml$/i.test(name) || /<kml\b/i.test(head));
    if (gpx || kml) {
      const xml = new TextDecoder().decode(buf);
      const g = gpx ? parseGpx(xml) : parseKml(xml);
      if (shared) {
        const n = g.tracks.length + g.waypoints.length;
        if (!n) return toast(`„${name}“: keine Wege oder Punkte gefunden`);
        const ok = await openDlg((box, close) => {
          dlgHead(box, '📥 Datei übernehmen', isFree()
            ? `„${name}“ (${countText(g)}) übernehmen? Dafür wird ein neuer Einsatz angelegt.`
            : `„${name}“ (${countText(g)}) in den Einsatz „${P.title || 'Suchgebiet'}“ übernehmen?`);
          dlgButton(box, isFree() ? 'Neuer Einsatz' : 'In diesen Einsatz', 'primary', () => close(true));
          dlgButton(box, 'Abbrechen', '', () => close(false));
        });
        if (!ok) return;
      }
      importGeo(g, name);
      return;
    }
    if (/\.xml$/i.test(name) || /^\s*<\?xml/i.test(head)) throw new Error('XML-Datei ist weder GPX noch KML');
    // JSON-Dateien sind UTF-8, PDFs werden nur nach dem eingebetteten Block durchsucht
    const p = importProject(text.trimStart().startsWith('{') ? new TextDecoder().decode(buf) : text);
    if (devLayer()) p.layerId = devLayer();
    p.updated = Date.now();
    db.projects[p.id] = p;
    switchProject(p.id);
    renderProjects();
    toast(`„${p.title || 'Suchgebiet'}“ geladen`);
  } catch (err) {
    toast(`„${name}“ konnte nicht geladen werden: ${err.message}`);
  }
}
function countText(g) {
  const parts = [];
  if (g.tracks.length) parts.push(`${g.tracks.length} Weg${g.tracks.length > 1 ? 'e' : ''}/Umriss${g.tracks.length > 1 ? 'e' : ''}`);
  if (g.waypoints.length) parts.push(`${g.waypoints.length} Wegpunkt${g.waypoints.length > 1 ? 'e' : ''}`);
  return parts.join(', ');
}
// Android-App: per „Teilen“/„Öffnen mit“ empfangene Datei abholen (auch beim Start der App)
window.onSharedFile = async () => {
  if (!bridge || !bridge.takeSharedFile) return;
  const raw = bridge.takeSharedFile();
  if (!raw) return;
  const { name, data } = JSON.parse(raw);
  const bin = atob(data);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  await importFile(name, buf.buffer, true);
};

const g0Tracks = (pick) => pick.all;
// v128: Auswahlliste der Tracks -> { tracks, all, choices: [{ i, teamId, kind }] } oder null (abgebrochen)
function trackPickDialog(tracks, base) {
  const rows = listTracks(tracks);
  const teams = P.marks.filter((m) => m.kind === 'team' && m.id !== NO_TEAM);
  return openDlg((box, close) => {
    dlgHead(box, '📥 Tracks übernehmen', `${rows.length} Track${rows.length === 1 ? '' : 's'} in der Datei. Abgewählt sind Aufzeichnungen („ACTIVE LOG“) und Tracks, die älter als 24 Stunden sind. Mit Team/Auftrag zählt der Weg wie eine Rückmeldung (km, Zeit).`);
    const list = document.createElement('div');
    list.id = 'trk-list';
    box.appendChild(list);
    const ctl = [];
    for (const r of rows) {
      const d = document.createElement('div');
      d.className = `trk-row${r.pre ? '' : ' off'}`;
      d.innerHTML = '<label class="trk-h"><input type="checkbox"><span></span></label><div class="trk-sel"><select class="trk-team"></select><select class="trk-kind"></select></div>';
      const cb = d.querySelector('input');
      cb.checked = r.pre;
      d.querySelector('.trk-h span').textContent = `${r.name || base} – ${trackInfo(r)}${r.why ? ` (${r.why})` : ''}`;
      const ts = d.querySelector('.trk-team');
      ts.add(new Option('– kein Team –', ''));
      for (const t of teams) ts.add(new Option(`${typeIcon(t)} ${t.label}`, t.id));
      const ks = d.querySelector('.trk-kind');
      for (const k of TRACK_KINDS) ks.add(new Option(`${k.ico} ${k.label}`, k.code));
      ks.value = guessKind(r.name, null);
      let touched = false;
      ks.addEventListener('change', () => { touched = true; });
      ts.addEventListener('change', () => { if (!touched) ks.value = guessKind(r.name, teams.find((t) => t.id === ts.value)); });
      cb.addEventListener('change', () => { d.classList.toggle('off', !cb.checked); upd(); });
      list.appendChild(d);
      ctl.push({ r, cb, ts, ks });
    }
    const go = dlgButton(box, '', 'primary', () => {
      const on = ctl.filter((c) => c.cb.checked);
      if (!on.length) return toast('Kein Track angehakt');
      close({ all: tracks, tracks: on.map((c) => tracks[c.r.i]), choices: on.map((c) => ({ i: c.r.i, teamId: c.ts.value, kind: c.ks.value })) });
    });
    const upd = () => { go.textContent = `📥 ${ctl.filter((c) => c.cb.checked).length} importieren`; };
    upd();
    dlgButton(box, 'Alle / keine', '', () => { const all = ctl.some((c) => !c.cb.checked); ctl.forEach((c) => { c.cb.checked = all; c.cb.dispatchEvent(new Event('change')); }); });
    dlgButton(box, 'Abbrechen', '', () => close(null));
  });
}

// GPX (z. B. aus BaseCamp) bzw. KML ins aktuelle Suchgebiet: Tracks/Routen als Umrisse, Wegpunkte als Text
async function importGeo(g0, fileName) {
  if (isClosed()) return lockedToast();
  if (isFree()) createProject(wizTitle()); // Datei ohne offenen Einsatz: dafür einen neuen anlegen
  const base = fileName.replace(/\.(gpx|kml|xml)$/i, '');
  const g = { ...g0, ...dedupeImport(P.items, g0, base, { meet: P.meet, pois: P.pois, msgs: msgWaypoints(exportMsgs()) }) }; // schon vorhandene (gleicher Name, gleiche Punkte) überspringen
  const added = [];
  let orders = [];
  // v128: Auswahlliste vor dem Import (Name, Länge, Zeit, Häkchen, Team/Auftrag, Hund/Mensch/Drohne)
  if (g.tracks.length) {
    const pick = await trackPickDialog(g.tracks, base);
    if (!pick) return;
    g.tracks = pick.tracks;
    const r = importItems(P, g0Tracks(pick), pick.choices, { base, color: db.color });
    // geschlossene Umrisse (Fläche) bleiben wie bisher Umrisse; importItems macht daraus offene Wege nur, wenn Anfang und Ende auseinanderliegen
    added.push(...r.items);
    orders = r.orders;
  }
  for (const w of g.waypoints) added.push({ kind: 'text', color: db.color, lat: w.lat, lon: w.lon, text: w.name });
  // Karte springt auf den Import – auch wenn alles schon da war (dann auf die Datei selbst)
  const zoomTo = (list) => {
    const pts = list.flatMap((it) => (it.pts ? it.pts : [[it.lat, it.lon]]));
    if (pts.length) map.fitBounds(pts, { padding: [40, 40], maxZoom: 17 });
  };
  if (!added.length) {
    if (g.dup) {
      closePanels();
      zoomTo([...g0.tracks, ...g0.waypoints.map((w) => ({ lat: w.lat, lon: w.lon }))]);
      toast(`Nichts übernommen – ${g.dup} schon vorhanden`);
    } else toast(g0.skipped ? 'Nur Raster/Feldnamen in der Datei – nichts übernommen' : 'Keine Tracks oder Wegpunkte in der Datei');
    return;
  }
  P.items.push(...added);
  for (const x of orders) noteImport(P, x); // zählt in der Auftrags-Übersicht (km, Zeit) wie eine HF-Rückmeldung
  if (orders.length) { P.updated = Date.now(); changed(); renderSentList(); }
  save();
  redraw();
  closePanels();
  zoomTo(added);
  const parts = [];
  if (g.tracks.length) parts.push(`${g.tracks.length} Track${g.tracks.length > 1 ? 's' : ''}`);
  if (g.waypoints.length) parts.push(`${g.waypoints.length} Wegpunkt${g.waypoints.length > 1 ? 'e' : ''}`);
  toast(`${g.dup ? `${added.length} übernommen, ${g.dup} schon vorhanden` : `${parts.join(' und ')} übernommen`}${g0.skipped ? ` (${g0.skipped} Raster-Einträge übersprungen)` : ''}`);
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
  repLog.add(`Fenster ${id}`);
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

// ---------- v103: Tipp ins Leere schließt, was offen ist ----------
// Ein zentraler pointerdown-Listener (Capture-Phase): Ist ein Fenster der Randleiste, das HF-Menü, die Team-Liste bzw.
// das Infofenster oder die Suchergebnisse offen, schließt ein Tipp auf die Karte/leere Fläche es – und macht sonst nichts.
// Dialoge: Tipp auf den dunklen Hintergrund = Abbrechen/Schließen (Ausnahmen siehe tapclose.js).
// Die Ungelesen-Liste (v98) schließt hier ebenfalls („Tipp irgendwohin = gelesen“), der Tipp geht weiter wie bisher.
let tapSwallow = null; // {id, until}: Rest der verschluckten Tipp-Geste (pointerup, click) ebenfalls verschlucken
function tapIsEmpty(t) {
  if (!t || t === document.body || t === document.documentElement || t === canvas) return true;
  return !!(t.closest && t.closest('#map') && !t.closest('.leaflet-control, .leaflet-popup, .gfit-h, .vtx-h, .vtx-mid, button, a'));
}
function anyOpenThing() {
  return [...document.querySelectorAll('.panel')].some((p) => !p.hidden)
    || !$('searchbar').hidden
    || !$('tm-pop').hidden
    || (!isTablet() && !!db.teamsOpen && !$('tm-list').hidden)
    || (!isTablet() && ordOpen);
}
function closeOpenThings() {
  closePanels();
  closeSearch();
  closePop();
  if (db.teamsOpen && !isTablet()) { db.teamsOpen = false; saveNow(); tbSig = ''; renderTeamBar(); }
  if (ordOpen) { ordOpen = false; ordSig = ''; redraw(); }
}
function dlgBackdropTap() {
  const box = $('dlg-box');
  const btns = [...box.querySelectorAll('button')];
  const typed = [...box.querySelectorAll('textarea, input:not([type=checkbox]):not([type=radio]):not([type=button])')].some((i) => (i.value || '').trim() !== '' && i.value !== i.defaultValue); // vorbelegt und unverändert zählt nicht
  const i = backdropAction({
    keep: !!box.dataset.keep, typed, head: (box.querySelector('h2') || {}).textContent || '',
    labels: btns.map((b) => b.textContent),
  });
  if (i >= 0) btns[i].click();
}
document.addEventListener('pointerdown', (e) => {
  if (!e.isPrimary) return;
  tapSwallow = null;
  if (unreadOpen) closeUnread();
  const dlgOpen = !$('dlg').hidden;
  const v = tapVerdict({
    dlgOpen,
    target: dlgOpen ? (e.target === $('dlg') ? 'backdrop' : 'ui') : (tapIsEmpty(e.target) ? 'empty' : 'ui'),
    anyOpen: !dlgOpen && anyOpenThing(),
  });
  if (v === 'none') return;
  e.preventDefault();
  e.stopImmediatePropagation();
  if (v === 'dlg-backdrop') dlgBackdropTap();
  else closeOpenThings();
  tapSwallow = { id: e.pointerId, until: Date.now() + 800 }; // erst nach dem Schließen, sonst frisst es dessen Knopf-Klick
}, true);
for (const ev of ['pointerup', 'pointercancel', 'click']) {
  document.addEventListener(ev, (e) => {
    if (!tapSwallow) return;
    if (Date.now() > tapSwallow.until) { tapSwallow = null; return; }
    if (ev === 'pointerup' || ev === 'pointercancel') { if (e.pointerId === tapSwallow.id) e.stopImmediatePropagation(); return; }
    e.stopImmediatePropagation();
    e.preventDefault();
    tapSwallow = null;
  }, true);
}
// Freie Karte: Einsatz-Fenster erst nach „+ Neuer Einsatz“
for (const btn of ['btn-mission', 'btn-notes', 'btn-grid', 'btn-teams']) {
  $(btn).addEventListener('click', async (e) => {
    if (!isFree()) return;
    e.stopImmediatePropagation();
    const ok = await openDlg((box, close) => {
      dlgHead(box, '🗺️ Kein Einsatz offen', 'Raster, Teams, Notizen und Einsatzdaten gehören zu einem Einsatz. Erst einen neuen anlegen – oder unter „📁 Einsätze“ einen bestehenden öffnen.');
      dlgButton(box, '+ Neuer Einsatz', 'primary', () => close(true));
      dlgButton(box, 'Abbrechen', '', () => close(false));
    });
    if (ok) $('proj-new').click();
  }, { capture: true });
}
// Seitenknopf nochmal antippen, während sein Fenster offen ist: Fenster schließen
const SIDE_PANELS = {
  'btn-projects': 'panel-projects', 'btn-grid': 'panel-grid', 'btn-teams': 'panel-teams',
  'btn-status': 'panel-status', 'btn-layers': 'panel-layers', 'btn-contacts': 'panel-contacts', 'btn-more': 'panel-more', 'btn-hfmenu': 'panel-hfmenu', 'btn-pdf': 'panel-share', 'btn-mission': 'panel-mission', 'btn-notes': 'panel-notes',
};
for (const [btn, panel] of Object.entries(SIDE_PANELS)) {
  $(btn).addEventListener('click', (e) => {
    if ($(panel).hidden) return;
    e.stopImmediatePropagation();
    closePanels();
  }, { capture: true });
}
$('btn-projects').addEventListener('click', () => { fillProjectForm(); renderProjects(); openPanel('panel-projects'); });
$('btn-grid').addEventListener('click', () => { updateGridInfo(); renderAlpha(); openPanel('panel-grid'); });
$('btn-teams').addEventListener('click', () => { renderMarks(); openPanel('panel-teams'); });
$('btn-layers').addEventListener('click', () => {
  $('msg-show-row').hidden = !(P.live && db.mode === 'el');
  $('msg-show').checked = !db.msgOff;
  openPanel('panel-layers');
});
$('msg-show').addEventListener('change', () => { db.msgOff = !$('msg-show').checked; saveNow(); redraw(); });
$('layers-offline').addEventListener('click', () => { renderOfflineForm(); openPanel('panel-offline'); });
$('btn-more').addEventListener('click', () => { renderDeviceName(); openPanel('panel-more'); });
$('app-version').textContent = `Version ${APP_VERSION}`;
$('btn-pdf').addEventListener('click', () => openShare());
$('share-more').addEventListener('click', () => openExport());
function openExport() {
  $('pdf-caption').value = P.caption || '';
  renderExportGrids();
  updatePdfPlan();
  updateKmzPlan();
  $('pdf-msg').textContent = '';
  $('kmz-msg').textContent = '';
  openPanel('panel-pdf');
}

// ---------- Teilen: „An wen?“ (Empfänger), „Was?“ (Umfang) und „Wie?“ (Weg) ----------
const SHARE_TO = ['ua', 'el', 'other'];
const SHARE_HINT = {
  ua: 'Unterabschnitt: bearbeitbar ist nur das ausgewählte Gebiet, der Rest ist nur zum Ansehen (QR-Code an ein Gerät mit dieser App).',
  el: 'Weiteres EL-Tablet / Einsatzleitwagen: bekommt den ganzen Einsatz, Rückmeldungen laufen dann dort ein (QR-Code).',
  other: 'Stellen ohne die App (Polizei, Feuerwehr, Druck, Garmin, Mail …): Datei oder PDF, kein QR-Code.',
};
let shareScope = 'all';
let shareSel = null;
let shareName = '';
let shareTo = null; // 'ua' | 'el' | 'other' – zuletzt gewählter Empfänger (pro Gerät in db.shareTo)
let shareInit = false;
function shareLabel() {
  if (shareScope === 'all') return 'Einsatz';
  return shareName || 'Auswahl';
}
function openShare() {
  if (!shareInit) { // erstes Öffnen: zuletzt gewählter Empfänger dieses Geräts
    shareInit = true;
    if (SHARE_TO.includes(db.shareTo)) applyShareTo(db.shareTo);
  }
  // Rückkehr von der Kartenauswahl ohne passenden Empfänger -> „Sonstige“ (alle Wege außer QR)
  if (!shareTo && (shareScope === 'pick' || shareScope === 'area' || shareScope === 'areas') && shareSel) shareTo = 'other';
  if (shareTo === 'el' || shareScope === 'all') { if (shareTo) shareSel = selectAll(P); }
  renderShare();
  openPanel('panel-share');
}
// Empfänger setzen und den Umfang dazu sinnvoll vorbelegen
function applyShareTo(to) {
  shareTo = to;
  if (to === 'el') { shareScope = 'all'; shareSel = selectAll(P); }
  else if (to === 'ua') {
    if (shareScope === 'all' || !shareSel) { shareScope = 'pick'; shareName = 'Auswahl'; shareSel = emptySel(); }
  } else if (!shareSel) { shareScope = 'all'; shareSel = selectAll(P); }
}
function renderShare() {
  const to = shareTo;
  const app = to === 'ua' || to === 'el'; // nur QR-Übergabe
  document.querySelectorAll('#share-to button').forEach((b) => b.classList.toggle('active', b.dataset.to === to));
  document.querySelectorAll('#share-scopes button').forEach((b) => b.classList.toggle('active', b.dataset.scope === shareScope));
  document.querySelector('#share-scopes [data-scope=all]').hidden = to === 'ua';
  $('share-tohint').textContent = to ? SHARE_HINT[to] : 'Zuerst wählen, an wen es geht – dann kommen die passenden Wege.';
  $('share-what').hidden = !to || to === 'el';
  $('share-how').hidden = !to;
  const sum = shareSel ? selSummary(P, shareSel) : '';
  $('share-summary').textContent = `${shareScope === 'all' ? 'Ganzer Einsatz' : shareLabel()}: ${sum || 'nichts ausgewählt'}`;
  $('share-edit').hidden = shareScope === 'all';
  $('share-gridlines').parentElement.hidden = app || !allGrids(P).length;
  $('share-qr').hidden = to === 'other';
  for (const id of ['share-garmin', 'share-mail', 'share-save', 'share-pdf']) $(id).hidden = app;
  $('share-file').hidden = app || shareScope !== 'all';
  $('share-msg').textContent = '';
}
document.querySelectorAll('#share-to button').forEach((b) => b.addEventListener('click', () => {
  applyShareTo(b.dataset.to);
  db.shareTo = shareTo;
  saveNow();
  renderShare();
}));
document.querySelectorAll('#share-scopes button').forEach((b) => b.addEventListener('click', () => {
  const s = b.dataset.scope;
  if (s === 'all') { shareScope = 'all'; shareSel = selectAll(P); return renderShare(); }
  if (s === 'areas') { // v128: mehrere Raster/Umrisse antippen -> ein UA
    if (!allGrids(P).length && !P.items.some((it) => it.kind === 'track' && hasArea(it))) return toast('Kein Raster und kein Umriss vorhanden');
    shareScope = 'areas';
    closePanels();
    areaPicks = [];
    gpxSel = emptySel();
    selMode = 'areas';
    setTool('gpxsel');
    updateGpxSelBar();
    return redraw();
  }
  if (s === 'area') {
    if (!allGrids(P).length && !P.items.some((it) => it.kind === 'track' && hasArea(it))) return toast('Kein Raster und kein Umriss vorhanden');
    shareScope = 'area';
    closePanels();
    gpxSel = emptySel();
    selMode = 'area';
    setTool('gpxsel');
    updateGpxSelBar();
    return redraw();
  }
  // eigene Auswahl: auf der Karte antippen
  shareScope = 'pick';
  shareName = 'Auswahl';
  editShareSel(emptySel());
}));
function editShareSel(start) {
  closePanels();
  gpxSel = start;
  selMode = 'share';
  setTool('gpxsel');
  updateGpxSelBar();
  redraw();
}
$('share-edit').addEventListener('click', () => {
  // ändern: die bisherige Auswahl auf der Karte weiter bearbeiten (wird zur eigenen Auswahl)
  if (shareScope !== 'pick') shareName = shareLabel();
  shareScope = 'pick';
  editShareSel(shareSel || emptySel());
});
function shareReady() {
  if (shareSel && selCount(shareSel)) return true;
  toast('Nichts ausgewählt – oben unter „2. Was?“ wählen');
  return false;
}
const shareGpx = () => gpxSelFile(shareSel, $('share-gridlines').checked, shareScope === 'all' ? 'Einsatz' : shareLabel());
async function shareRun(fn) {
  if (!shareReady()) return;
  try { await fn(); } catch (err) { console.error(err); toast('Fehler: ' + err.message); }
}
$('share-garmin').addEventListener('click', () => shareRun(async () => { const f = shareGpx(); await shareFile(f.blob, f.name, f.title, f.text, f); }));
$('share-mail').addEventListener('click', () => shareRun(async () => { const f = shareGpx(); await mailFile(f); }));
$('share-save').addEventListener('click', () => shareRun(async () => { const f = shareGpx(); await saveFile(f.blob, f.name); }));
$('share-file').addEventListener('click', () => $('proj-share').click());
$('share-qr').addEventListener('click', () => shareRun(async () => {
  stamp(); // feste IDs vor dem Ausschneiden eines Unterabschnitts
  if (shareTo === 'el') return handoverQr(P, true);
  if (shareTo === 'ua') ensureLive(P, liveUrlNow()); // v127: der UA bekommt den Live-Kanal des Grund-Einsatzes mit
  if (shareTo === 'ua') return handoverQr(subsetProject(P, shareSel, uaTitle(P.title, shareLabel()), { base: true }), false); // v128: nie „UA UA …“
}));
$('share-pdf').addEventListener('click', () => shareRun(async () => {
  if (shareScope === 'all') return openExport();
  // Teil: eine Karte genau um das Ausgewählte
  const q = subsetProject(P, shareSel, `${P.title || 'Einsatz'} – ${shareLabel()}`);
  const qg = q.area ? makeGrid(q.area, q.cellM) : null;
  $('share-msg').textContent = 'PDF wird erstellt …';
  const res = await buildPdf(q, qg, { ...pdfOpts(), views: null, fitContent: true, info: false, title: q.title, rescue: rescueForExport() },
    layerStack(P.layerId, activeOverlays()), viewBounds(), (i, n) => { $('share-msg').textContent = `Karte ${i} von ${n} …`; });
  $('share-msg').textContent = '';
  await shareFile(res.blob, safeName(shareLabel(), '.pdf'), q.title, mailText(q.title));
}));
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
    msgs: msgWaypoints(exportMsgs()), // v116: Meldungen mit Ort auf der Karte
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
    + '\nDas PDF lässt sich in der App RHS Einsatz öffnen, um weiterzuarbeiten.';
}

async function buildPdfFile(progress) {
  const opts = { ...pdfOpts(), views: exportViews() };
  const res = await buildPdf(P, grid, { ...opts, rescue: rescueForExport() }, layerStack(P.layerId, activeOverlays()), viewBounds(), (i, n) => progress(`Seite ${i} von ${n} …`));
  $('pdf-msg').textContent = `✔ ${res.pages} Seite${res.pages > 1 ? 'n' : ''} (${Math.round(res.blob.size / 1024)} KB)`
    + (res.missing ? ` – ${res.missing} Kartenkacheln fehlen (keine Verbindung oder Karte nicht exportierbar)` : '');
  return {
    blob: res.blob,
    name: safeName('Karte', '.pdf'),
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
    msgs: $('gpx-points').checked ? msgWaypoints(exportMsgs()) : [], // v116: Meldungen mit Ort als Wegpunkte
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
      name: safeName(part, '.gpx'),
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
// v124: „In BaseCamp öffnen“: beide GPX-Dateien direkt laden (Desktop/Web); in der Android-App ausgeblendet (dort Teilen/Speichern)
$('gpx-bc-row').hidden = $('gpx-bc-hint').hidden = !!bridge;
$('gpx-bc').addEventListener('click', async () => {
  const btn = $('gpx-bc');
  btn.disabled = true;
  try {
    const files = [];
    for (const build of [gridGpx(), markGpx()]) {
      const f = await build();
      if (f) files.push(f);
    }
    if (!files.length) return;
    for (const f of files) {
      download(f.blob, f.name);
      await new Promise((r) => setTimeout(r, 400)); // Browser blockieren sonst den zweiten Download
    }
    toast('GPX geladen – unten im Browser anklicken, öffnet BaseCamp (wenn .gpx mit BaseCamp verknüpft ist)', 8000);
  } catch (err) {
    console.error(err);
    toast('Fehler: ' + err.message);
  } finally { btn.disabled = false; }
});

$('gpx-grid-share').addEventListener('click', () => runExport('gpx-grid', $('gpx-grid-share'), exportKey(gpxGridOpts()), gridGpx(), 'share'));
$('gpx-grid-save').addEventListener('click', () => runExport('gpx-grid', $('gpx-grid-save'), exportKey(gpxGridOpts()), gridGpx(), 'save'));
$('gpx-share').addEventListener('click', () => runExport('gpx', $('gpx-share'), exportKey(gpxMarkOpts()), markGpx(), 'share'));
$('gpx-save').addEventListener('click', () => runExport('gpx', $('gpx-save'), exportKey(gpxMarkOpts()), markGpx(), 'save'));

// ---------- GPX-Auswahl: einzelne Dinge an die Garmin-App ----------
// Felder je Rastergebiet ("c,r"), dazu Umrisse/Striche/Texte, Lage-Orte, B-Ort und Rasterränder
function gridGeoms() { return allGrids(P).map((g) => ({ g, gr: g.active ? grid : makeGrid(g.area, g.cellM) })).filter((x) => x.gr); }
const cellCenter = (gr, c, r) => [gr.originLat - (r + 0.5) * gr.dLat, gr.originLon + (c + 0.5) * gr.dLon];
const gridCorner = (gr) => ([c, r]) => [gr.originLat - r * gr.dLat, gr.originLon + c * gr.dLon];
function itemPoints(it) { return it.kind === 'text' ? [[it.lat, it.lon]] : (it.pts || []); }
function cellSet(id) {
  if (!gpxSel.cells.has(id)) gpxSel.cells.set(id, new Set());
  return gpxSel.cells.get(id);
}
const gpxSelCount = () => selCount(gpxSel);
function updateGpxSelBar() {
  if (!gpxSel) return;
  const n = gpxSelCount();
  const area = selMode === 'area' || selMode === 'areas';
  $('gpxsel-info').textContent = selMode === 'areas' ? (areaPicks.length ? `${areaPicks.length} Gebiet${areaPicks.length === 1 ? '' : 'e'}: ${joinUaNames(areaPicks.map((a) => a.name))} – weitere antippen (nochmal = abwählen)` : 'Raster oder Umriss antippen (mehrere möglich)') : area ? 'Raster oder Umriss antippen' : n ? `${n} ausgewählt` : 'Antippen zum Auswählen';
  $('gpxsel-share').hidden = selMode !== 'export';
  $('gpxsel-save').hidden = selMode !== 'export';
  $('gpxsel-share').disabled = !n;
  $('gpxsel-save').disabled = !n;
  $('gpxsel-grid').hidden = area;
  $('gpxsel-grid').disabled = !allGrids(P).length;
  $('gpxsel-done').textContent = selMode === 'share' || selMode === 'areas' ? '✓ Übernehmen' : area ? 'Abbrechen' : 'Fertig';
}
// Alles innerhalb einer Fläche (Umriss oder Rasterrand) dazunehmen; Rückgabe: Anzahl neu
function selectInside(inside, except = null) {
  let n = 0;
  for (const it of P.items) {
    if (it === except || it.hidden || gpxSel.items.has(it)) continue;
    if (itemPoints(it).some(inside)) { gpxSel.items.add(it); n++; }
  }
  for (const p of P.pois) if (!gpxSel.pois.has(p) && inside([p.lat, p.lon])) { gpxSel.pois.add(p); n++; }
  if (P.meet && !gpxSel.meet && inside([P.meet.lat, P.meet.lon])) { gpxSel.meet = true; n++; }
  // eingefärbte Felder (Teams, Status), deren Mitte in der Fläche liegt
  for (const { g, gr } of gridGeoms()) {
    const set = cellSet(g.id);
    for (const k of new Set([...Object.keys(g.fills || {}), ...Object.keys(g.status || {})])) {
      const [c, r] = k.split(',').map(Number);
      if (!set.has(k) && inside(cellCenter(gr, c, r))) { set.add(k); n++; }
    }
  }
  return n;
}
function gpxTap(x, y, ll) {
  if (selMode === 'area' || selMode === 'areas') return areaTap(x, y, ll);
  const pi = poiAt(x, y);
  if (pi >= 0) {
    const p = P.pois[pi];
    if (gpxSel.pois.has(p)) gpxSel.pois.delete(p); else gpxSel.pois.add(p);
  } else if (P.meet && Math.hypot(toPx(P.meet.lat, P.meet.lon)[0] - x, toPx(P.meet.lat, P.meet.lon)[1] - y) <= 16) {
    gpxSel.meet = !gpxSel.meet;
  } else {
    const i = hitItem(P.items, toPx, x, y, 12);
    const h = i < 0 && hitGrid(ll.lat, ll.lng);
    if (i >= 0) {
      const it = P.items[i];
      if (gpxSel.items.has(it)) gpxSel.items.delete(it);
      else {
        gpxSel.items.add(it);
        // Umriss: alles darin gleich mit
        if (it.kind === 'track' && hasArea(it)) {
          const n = selectInside((pt) => pointInPolygon(pt, it.pts), it);
          if (n) toast(`Umriss und ${n} Ding${n === 1 ? '' : 'e'} darin ausgewählt`);
        }
      }
    } else if (h) {
      gpxSelGrid = h.g.id;
      const set = cellSet(h.g.id);
      const k = `${h.c},${h.r}`;
      if (set.has(k)) set.delete(k); else set.add(k);
    }
  }
  updateGpxSelBar();
  redraw();
}
// Ganzes Rastergebiet: Rand und alles darin; Rückgabe: Anzahl neu
function selectGrid({ g, gr }) {
  const north = gr.originLat;
  const west = gr.originLon;
  const south = north - gr.rows * gr.dLat;
  const east = west + gr.cols * gr.dLon;
  const n = selectInside(([la, lo]) => la <= north && la >= south && lo >= west && lo <= east);
  gpxSel.edges.add(g.id);
  return n;
}
$('gpxsel-grid').addEventListener('click', () => {
  const list = gridGeoms();
  const c = map.getCenter();
  const at = hitGrid(c.lat, c.lng);
  const hit = list.find((x) => x.g.id === gpxSelGrid) || (at && list.find((x) => x.g.id === at.g.id)) || list[0];
  if (!hit) return;
  const n = selectGrid(hit);
  updateGpxSelBar();
  redraw();
  toast(`${gridLabel(P, hit.g)}: Rand${n ? ` und ${n} Ding${n === 1 ? '' : 'e'}` : ''} ausgewählt`);
});
// „Ein Gebiet“: Umriss oder Raster antippen -> alles darin, dazu B-Ort und Lage-Orte
function areaTap(x, y, ll) {
  const multi = selMode === 'areas';
  const i = hitItem(P.items, toPx, x, y, 12);
  const it = i >= 0 ? P.items[i] : null;
  let name = '';
  let key = '';
  let hit = null;
  if (it && it.kind === 'track' && hasArea(it)) {
    name = it.name || 'Umriss';
    key = `i:${i}`;
  } else {
    const h = hitGrid(ll.lat, ll.lng);
    hit = h && gridGeoms().find((x2) => x2.g.id === h.g.id);
    if (!hit) return toast('Bitte einen geschlossenen Umriss oder ein Raster antippen');
    name = gridLabel(P, hit.g);
    key = `g:${hit.g.id}`;
  }
  // v128: bei „Mehrere Gebiete“ jedes Gebiet einzeln sammeln (nochmal tippen = wieder abwählen), erst „Übernehmen“ geht weiter
  const prevSel = gpxSel;
  if (multi && areaPicks.some((a) => a.key === key)) {
    areaPicks = areaPicks.filter((a) => a.key !== key);
    gpxSel = unionSel(areaPicks.map((a) => a.sel));
    updateGpxSelBar();
    return redraw();
  }
  if (multi) gpxSel = emptySel();
  if (it && it.kind === 'track' && hasArea(it)) {
    gpxSel.items.add(it);
    selectInside((pt) => pointInPolygon(pt, it.pts), it);
  } else selectGrid(hit);
  for (const p of P.pois) gpxSel.pois.add(p);
  gpxSel.meet = !!P.meet;
  if (multi) {
    areaPicks.push({ key, name, sel: gpxSel });
    gpxSel = unionSel(areaPicks.map((a) => a.sel));
    updateGpxSelBar();
    toast(`${name} gewählt – weiteres Gebiet antippen oder „Übernehmen“`, 4000);
    void prevSel;
    return redraw();
  }
  shareSel = gpxSel;
  shareName = name;
  setTool('pan');
  redraw();
  openShare();
}
// GPX aus einer Auswahl; withLines: Rasterlinien und Feldnamen der ausgewählten Gebiete mit
function gpxSelFile(src = gpxSel, withLines = false, label = 'Auswahl') {
  const title = P.title || 'Suchgebiet';
  const multi = allGrids(P).length > 1;
  const sel = { items: P.items.filter((it) => src.items.has(it)), pois: P.pois.filter((p) => src.pois.has(p)), meet: src.meet ? P.meet : null, areas: [], lines: [], msgs: msgWaypoints(exportMsgs()) }; // v127: Meldungen mit Ort immer mit
  for (const { g, gr } of gridGeoms()) {
    const prefix = multi ? `${gridLabel(P, g)} ` : '';
    const corner = gridCorner(gr);
    const inScope = src.edges.has(g.id) || (src.cells.get(g.id) || new Set()).size > 0;
    if (withLines && inScope) {
      const both = gridWithLabels(gr);
      const desc = `${formatMeters(gr.cellM)} Felder mit Feldnamen, A1 = Nordwest-Ecke`;
      if (both) sel.lines.push({ name: `Raster ${prefix}${title}`.trim(), color: '#d50000', pts: both, desc });
      else {
        // großes Raster: Linien und Feldnamen getrennt (Garmin: höchstens ca. 10 000 Punkte je Track)
        sel.lines.push({ name: `Rasterlinien ${prefix}${title}`.trim(), color: '#d50000', pts: gridPath(gr), desc });
        const parts = labelTracks(gr);
        parts.forEach((t, i) => sel.lines.push({ name: `Feldnamen ${prefix}${title}${parts.length > 1 ? ` (${i + 1})` : ''}`.trim(), color: '#d50000', pts: t.pts }));
      }
    } else if (src.edges.has(g.id)) {
      sel.lines.push({ name: `Rand ${prefix}${title}`.trim(), color: '#d50000', pts: [[0, 0], [gr.cols, 0], [gr.cols, gr.rows], [0, gr.rows], [0, 0]].map(corner), desc: `${gr.cols} × ${gr.rows} Felder à ${formatMeters(gr.cellM)}` });
    }
    // Felder nach Team/Status zusammenfassen, sonst „Felder“
    const v = gridView(P, g);
    const groups = new Map();
    for (const k of src.cells.get(g.id) || []) {
      const [c, r] = k.split(',').map(Number);
      const m = cellOwner(v, c, r) || cellStatus(v, c, r) || (v.fills[k] === NO_TEAM ? NO_TEAM_MARK : null);
      const id = m ? m.id : '';
      if (!groups.has(id)) groups.set(id, { m, keys: [] });
      groups.get(id).keys.push(k);
    }
    for (const { m, keys } of groups.values()) {
      for (const part of cellComponents(keys)) {
        sel.areas.push({ name: `${m ? markLabel(m) : 'Felder'}: ${prefix}${cellsText(part)}`, color: m ? m.color : '#ff6f00', loops: cellOutlines(part).map((loop) => loop.map(corner)) });
      }
    }
  }
  const gpx = selectionGpx(sel, `${title} – ${label}`);
  return {
    blob: new Blob([gpx], { type: 'application/gpx+xml' }),
    name: safeName(label, '.gpx'),
    title: `${title} – ${label}`,
    text: 'GPX für Garmin: in der Garmin-App (z. B. Garmin Explore) öffnen und an das Gerät senden – oder in BaseCamp importieren.',
  };
}
async function gpxSelExport(action) {
  if (!gpxSel || !gpxSelCount()) return toast('Erst etwas auf der Karte antippen');
  try {
    const f = gpxSelFile();
    if (action === 'save') await saveFile(f.blob, f.name);
    else await shareFile(f.blob, f.name, f.title, f.text, f);
  } catch (err) {
    console.error(err);
    toast('Fehler: ' + err.message);
  }
}
$('gpxsel-share').addEventListener('click', () => gpxSelExport('share'));
$('gpxsel-save').addEventListener('click', () => gpxSelExport('save'));
$('gpxsel-done').addEventListener('click', () => {
  const mode = selMode;
  if (mode === 'share') { shareSel = gpxSel; shareScope = 'pick'; }
  if (mode === 'areas') {
    if (areaPicks.length) { shareSel = gpxSel; shareName = joinUaNames(areaPicks.map((a) => a.name)); shareScope = 'areas'; } else shareScope = 'all';
  }
  setTool('pan');
  redraw();
  if (mode === 'share' || mode === 'area' || mode === 'areas') openShare();
});
$('gpxsel-open').addEventListener('click', () => { closePanels(); gpxSelGrid = null; gpxSel = emptySel(); selMode = 'export'; setTool('gpxsel'); updateGpxSelBar(); redraw(); });
// Hervorhebung der Auswahl (gelb)
function drawGpxSel() {
  if (!gpxSel) return;
  ctx.save();
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  for (const { g, gr } of gridGeoms()) {
    ctx.fillStyle = 'rgba(255, 214, 0, 0.45)';
    for (const k of gpxSel.cells.get(g.id) || []) {
      const [c, r] = k.split(',').map(Number);
      const [x0, y0] = toPx(gr.originLat - r * gr.dLat, gr.originLon + c * gr.dLon);
      const [x1, y1] = toPx(gr.originLat - (r + 1) * gr.dLat, gr.originLon + (c + 1) * gr.dLon);
      ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
    }
    if (gpxSel.edges.has(g.id)) {
      const [x0, y0] = toPx(gr.originLat, gr.originLon);
      const [x1, y1] = toPx(gr.originLat - gr.rows * gr.dLat, gr.originLon + gr.cols * gr.dLon);
      ctx.strokeStyle = 'rgba(255, 214, 0, 0.9)';
      ctx.lineWidth = 8;
      ctx.strokeRect(x0, y0, x1 - x0, y1 - y0);
    }
  }
  ctx.strokeStyle = 'rgba(255, 214, 0, 0.75)';
  for (const it of gpxSel.items) {
    const pts = itemPoints(it).map(([la, lo]) => toPx(la, lo));
    ctx.lineWidth = 10;
    ctx.beginPath();
    if (pts.length === 1) ctx.arc(pts[0][0], pts[0][1], 14, 0, 2 * Math.PI);
    else {
      pts.forEach(([px, py], i) => (i ? ctx.lineTo(px, py) : ctx.moveTo(px, py)));
      if (it.kind === 'track' && hasArea(it)) ctx.closePath();
    }
    ctx.stroke();
  }
  ctx.lineWidth = 5;
  const ring = (la, lo) => { const [px, py] = toPx(la, lo); ctx.beginPath(); ctx.arc(px, py, 19, 0, 2 * Math.PI); ctx.stroke(); };
  for (const p of gpxSel.pois) ring(p.lat, p.lon);
  if (gpxSel.meet && P.meet) ring(P.meet.lat, P.meet.lon);
  ctx.restore();
}

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
    name: safeName('Garmin-Karte', '.kmz'),
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
    row.innerHTML = '<span></span><input><button class="now">Jetzt</button><button class="clr" title="Löschen">✕</button>';
    row.querySelector('span').textContent = label;
    const inp = row.querySelector('input');
    timeField(inp, t[k], (v) => { if (v) t[k] = v; else delete t[k]; if (k === 'alarm' && v && !t.alarmDate) { t.alarmDate = isoDate(new Date()); const di = inp.closest('.wz-body, #ms-times, #panel-wizard')?.querySelector('input[type=date]'); if (di) di.value = t.alarmDate; } touch(); });
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
  // v128: Kräfte aus den Teams automatisch summiert (Anzeige), Knopf übernimmt sie in die Tabelle
  const fa = forcesText(forcesFromTeams(P.marks));
  $('ms-forces-auto').textContent = fa.length ? `Aus den Teams: ${fa.join(' · ')}` : '';
  $('ms-force-teams').hidden = !fa.length;
}
$('ms-force-teams').addEventListener('click', () => {
  M().forces = M().forces.filter((f) => !f.auto);
  for (const f of forcesFromTeams(P.marks)) M().forces.push({ org: f.org, lead: String(f.lead), helpers: String(f.helpers), dogs: String(f.dogs), vehicles: String(f.vehicles), auto: true });
  touch();
  renderForces();
});
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
  const boxes = [$('nt-thumbs')];
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

// Foto vom Papier: direkt mit der Kamera oder ein vorhandenes Bild
const addPhoto = async (e) => {
  const f = e.target.files[0];
  e.target.value = '';
  if (!f) return;
  try {
    M().photos.push({ t: Date.now(), src: await shrinkPhoto(f) });
    touch();
    const saved = saveNow();
    renderThumbs();
    toast(saved ? 'Foto gespeichert' : '⚠️ Foto NICHT gespeichert – Speicher voll', saved ? 3500 : 8000);
  } catch (err) {
    toast('Foto: ' + err.message);
  }
};
$('ms-photo-file').addEventListener('change', addPhoto);
$('ms-cam-file').addEventListener('change', addPhoto);

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
  $('tab-stamm').hidden = t !== 'stamm';
  $('tab-lage').hidden = t !== 'lage';
  $('tab-ende').hidden = t !== 'ende';
  db.missionTab = t;
  if (t === 'ende') { renderViewer(); renderLegend(); }
}
document.querySelectorAll('#panel-mission .tabs button').forEach((b) => b.addEventListener('click', () => showTab(b.dataset.tab)));

function renderMission() {
  fillProjectForm();
  $('ms-person').value = M().person;
  $('ms-summary').value = M().summary;
  if (!M().author && P.leader) M().author = P.leader;
  $('ms-author').value = M().author;
  renderMailTo();
  $('ms-msg').textContent = '';
  renderTimes();
  renderForces();
  renderThumbs();
  renderClosed();
  showTab(db.missionTab || 'stamm');
}

// Einsatz abschließen: Einsatzende eintragen (falls leer) und als abgeschlossen markieren
function renderClosed() {
  $('ms-closed').textContent = P.closed
    ? `✅ Abgeschlossen am ${new Date(P.closed).toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' })}.`
    : 'Trägt das Einsatzende ein (falls noch leer) und markiert den Einsatz in der Liste als abgeschlossen. Alles bleibt bearbeitbar.';
  $('ms-close').textContent = P.closed ? '↩️ Wieder öffnen' : '✅ Einsatz abschließen';
  $('ms-close').className = P.closed ? 'keep' : 'primary keep';
}
$('ms-close').addEventListener('click', async () => {
  if (P.closed) {
    delete P.closed;
    changed();
    saveNow();
    renderClosed();
    return toast('Einsatz wieder geöffnet');
  }
  const t = M().times;
  const now = new Date();
  const hm = now.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
  // v116: offene Aufträge, unquittierte Funde/Hilfe und fehlende Rückgaben zuerst zeigen
  const open = openPoints(P, allMsgs());
  const ok = open.count ? await openDlg((box, close) => {
    // v128: je offenem Auftrag „Als erledigt markieren“, dazu „Alle als erledigt“ und „wer ist noch draußen?“
    const draw = () => {
      box.innerHTML = '';
      const o = openPoints(P, allMsgs());
      if (!o.count) { dlgHead(box, '✅ Alles erledigt', `„${P.title || 'Suchgebiet'}“ hat keine offenen Punkte mehr.`); } else dlgHead(box, '⚠️ Noch offen', `„${P.title || 'Suchgebiet'}“ hat noch offene Punkte. Trotzdem abschließen?`);
      const line = (cls, text) => { const d = document.createElement('div'); d.className = cls; d.textContent = text; box.appendChild(d); };
      for (const q of o.unacked) line('st-urgent close-open', `${q.team}: ${q.label} ${hhmm(q.t)} – noch nicht als gesehen bestätigt`);
      for (const q of o.open) {
        line('close-open', `📋 ${q.team}: Auftrag offen${q.what ? ` (${q.what})` : ''}${q.returned ? '' : ' – Rückgabe fehlt'}`);
        const b = dlgButton(box, '✓ Als erledigt markieren', 'mark-done', () => { const x = (P.sent || []).find((y) => y.id === q.id); if (x) { closeSent(x, allMsgs()); changed(); renderSentList(); } draw(); });
        b.dataset.order = q.id;
      }
      if (o.open.length > 1) dlgButton(box, '✓ Alle als erledigt markieren', 'mark-all-done', () => { for (const q of o.open) { const x = (P.sent || []).find((y) => y.id === q.id); if (x) closeSent(x, allMsgs()); } changed(); renderSentList(); draw(); });
      for (const q of o.noReturn) line('close-open', `📲 ${q.team}: keine Rückgabe eingelesen`);
      const out = outsideTeams(teamTimes(P.sent, allMsgs(), P.marks));
      if (out.length) line('close-open', `🚶 Noch draußen: ${out.map((r) => r.label).join(', ')}`);
      dlgButton(box, 'Trotzdem abschließen', 'close-anyway', () => close(true));
      dlgButton(box, 'Zurück', '', () => close(false));
    };
    draw();
  }) : await openDlg((box, close) => {
    dlgHead(box, '✅ Einsatz abschließen', t.end
      ? `„${P.title || 'Suchgebiet'}“ abschließen? Einsatzende bleibt ${t.end}.`
      : `„${P.title || 'Suchgebiet'}“ abschließen? Als Einsatzende wird ${hm} eingetragen.`);
    dlgButton(box, 'Abschließen', 'primary', () => close(true));
    dlgButton(box, 'Abbrechen', '', () => close(false));
  });
  if (!ok) return;
  if (!t.end) t.end = hm;
  P.closed = now.getTime();
  changed();
  saveNow();
  renderTimes();
  renderClosed();
  renderProjects();
  const next = await openDlg((box, close) => {
    dlgHead(box, '✅ Einsatz abgeschlossen', `„${P.title || 'Suchgebiet'}“ bleibt unter „📁 Einsätze“ gespeichert. Die Karte wird jetzt geleert.`);
    dlgButton(box, '📤 Vorher Abschlussbericht teilen', '', () => close('share'));
    dlgButton(box, '🗺️ Freie Karte', 'primary', () => close('free'));
    dlgButton(box, '+ Neuer Einsatz', '', () => close('new'));
  });
  if (next === 'share') await runExport('report', $('ms-share'), reportKey(), buildReportFile, 'share');
  freeMap();
  if (next === 'new') $('proj-new').click();
});
// Abgeschlossenen Einsatz vom Bildschirm nehmen: leere Karte am selben Ort (Einsatz bleibt gespeichert)
function freeMap() {
  closePanels();
  const blank = Object.values(db.projects).find((p) => p.id !== P.id && isBlankProject(p));
  if (blank) {
    const c = map.getCenter();
    blank.view = { lat: c.lat, lon: c.lng, z: map.getZoom() };
    blank.layerId = devLayer() || P.layerId;
    switchProject(blank.id);
    renderProjects();
  } else createProject('');
  toast('🗺️ Freie Karte – der abgeschlossene Einsatz liegt unter „📁 Einsätze“.', 5000);
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
  P.updated = Date.now();
  save();
});
$('nt-pad').addEventListener('click', () => openPad());
$('nt-photo').addEventListener('click', () => $('ms-photo-file').click());
$('nt-cam').addEventListener('click', () => $('ms-cam-file').click());
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
  if (isLocked()) return lockedToast();
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
  const parts = { ...sec, legend: withMap, msgRows: msgRows(exportMsgs(), null, (la, lo) => formatMgrs(la, lo)), ...reportExtras() };
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
  return { blob: res.blob, name: safeName(hasReportText(parts) ? 'Abschlussbericht' : hasPad || hasPhotos ? 'Notizen' : 'Karte', '.pdf'), title: opts.title, pages: res.pages };
}

async function buildReportFile(progress) {
  const f = await reportPdf({}, progress);
  $('ms-msg').textContent = `✔ Abschlussbericht mit ${f.pages} Seite${f.pages > 1 ? 'n' : ''} (${Math.round(f.blob.size / 1024)} KB)`;
  return { ...f, text: missionText(P, grid, 'Abschlussbericht im Anhang (PDF).', null, reportExtras()) };
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
    name: safeName('JUH-Einsatzbericht', '.pdf'),
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
    const text = missionText(P, grid, `Im Anhang: ${names}`, row, reportExtras());
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

function showSearchPin(lat, lon, label) {
  if (searchPin) map.removeLayer(searchPin);
  searchPin = L.marker([lat, lon], {
    icon: L.divIcon({ className: 'search-pin', html: '📍', iconSize: [30, 30], iconAnchor: [15, 28] }),
  }).addTo(map).bindTooltip(label, { direction: 'top', offset: [0, -24] }).openTooltip();
  searchPin.on('click', () => { map.removeLayer(searchPin); searchPin = null; });
}

function closeSearch() {
  $('searchbar').hidden = true;
  collapseSearch();
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
function showResults(list, credit, title = 'Suchergebnisse') {
  shownResults = title === 'Suchergebnisse' ? list : []; // Gebietsliste nicht beim Fokus ins Suchfeld wieder öffnen
  $('search-title').textContent = title;
  $('searchbar').dataset.kind = title === 'Suchergebnisse' ? 'search' : 'areas';
  const box = $('search-results');
  box.innerHTML = '';
  // v120: erst beim Loslassen wählen, und nur ohne Wischen – sonst lässt sich die Liste mit dem Finger nicht scrollen.
  // pointerdown mit preventDefault hält die Handy-Tastatur offen, bis gewählt ist (sonst verrutscht die Liste unter dem Finger)
  // v123: als eigene Funktion, damit der 🧭-Knopf je Zeile dieselbe Wisch-Erkennung bekommt
  const tapOnly = (b, fn) => {
    let down = null;
    b.addEventListener('pointerdown', (e) => { if (e.pointerType !== 'mouse' || e.button === 0) { e.preventDefault(); down = { x: e.clientX, y: e.clientY, top: $('searchbar').scrollTop }; } });
    b.addEventListener('pointercancel', () => { down = null; }); // Browser übernimmt das Scrollen
    b.addEventListener('pointerup', (e) => {
      const d = down;
      down = null;
      if (!d || Math.hypot(e.clientX - d.x, e.clientY - d.y) > 10 || Math.abs($('searchbar').scrollTop - d.top) > 4) return;
      $('search-input').blur();
      fn();
    });
    b.addEventListener('click', (e) => { if (e.detail === 0) fn(); }); // Tastatur (Enter/Leertaste)
  };
  for (const r of list) {
    const b = document.createElement('button');
    b.innerHTML = '<b></b><small></small>';
    b.querySelector('b').textContent = r.name;
    b.querySelector('small').textContent = r.sub || '';
    tapOnly(b, r.go);
    if (!r.nav) { box.appendChild(b); continue; }
    // v123: Zeile mit eigenem 🧭-Knopf (Route zur Mitte); wählt das Gebiet nicht aus
    const row = document.createElement('div');
    row.className = 'sr-row';
    const nb = document.createElement('button');
    nb.className = 'sr-nav';
    nb.type = 'button';
    nb.textContent = '🧭';
    nb.title = 'Navigieren';
    nb.setAttribute('aria-label', `Navigieren zu ${r.name}`);
    tapOnly(nb, () => navChooser(r.navName || r.name, r.nav[0], r.nav[1]));
    row.append(b, nb);
    box.appendChild(row);
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

// v112: Gebiete (Umrisse und Raster) für die Liste am Knopf „Gebiete“; Antippen zentriert die Karte darauf
function areaResults(text = '') {
  const t = text.trim().toLowerCase();
  const fit = (s, n, w, e) => { map.fitBounds([[s, w], [n, e]], { padding: [50, 50], maxZoom: 18 }); closeSearch(); };
  const out = [];
  for (const it of P.items) {
    if (it.kind !== 'track' || it.open || !it.pts || it.pts.length < 3) continue;
    const name = it.name || 'Umriss';
    const who = it.to ? assigneeName(P, it.to) || '' : 'ohne Team';
    if (t && !`${name} ${who}`.toLowerCase().includes(t)) continue;
    const la = it.pts.map((p) => p[0]), lo = it.pts.map((p) => p[1]);
    out.push({
      name: `📐 ${name}`,
      sub: [who, hasArea(it) ? formatArea(polygonArea(it.pts)) : ''].filter(Boolean).join(' · '),
      go: () => fit(Math.min(...la), Math.max(...la), Math.min(...lo), Math.max(...lo)),
      nav: boxCenter(it.pts), // v123: 🧭 Route zur Gebietsmitte
      navName: name,
    });
  }
  for (const g of allGrids(P)) {
    const name = gridLabel(P, g);
    const who = gridTeams(P, g).map((m) => markLabel(m) || 'Team').join(', ') || 'ohne Team'; // v120: zugeteilte Teams zeigen
    if (t && !`${name} ${who}`.toLowerCase().includes(t)) continue;
    const gg = makeGrid(g.area, g.cellM);
    const b = gridBounds(gg);
    out.push({
      name: `# ${name}`, sub: `${who} · Raster · ${gg.cols} × ${gg.rows} Felder`, go: () => fit(b.south, b.north, b.west, b.east),
      nav: [(b.north + b.south) / 2, (b.west + b.east) / 2], navName: name, // v123
    });
  }
  return out;
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
    if (signal.aborted) return;
    const msg = err.message.startsWith('Kreuzungssuche') ? err.message : `Kreuzungssuche fehlgeschlagen: ${err.message}`;
    showResults([], navigator.onLine === false ? 'Keine Internetverbindung – Kreuzungssuche nicht möglich.' : msg);
  }
}

async function updateSuggestions(immediate = false) {
  clearTimeout(suggestTimer);
  if (suggestAbort) suggestAbort.abort();
  const text = $('search-input').value.trim();
  const q = parseQuery(text);
  // Nur die Trefferliste schließen – das Suchfeld bleibt offen (Tablet: sonst klappt es beim ersten Buchstaben zu)
  if (!q) { $('searchbar').hidden = true; return; }
  const local = localResult(q);
  if (local) {
    // v123: bei einem Feldnamen („C4“) zusätzlich „🧭 Navigieren zu C4“
    const ctr = q.type === 'cell' && grid ? navCellCenter(grid, cellLabel(q.c, q.r)) : null;
    const lbl = ctr ? cellLabel(q.c, q.r) : '';
    showResults(ctr ? [local, { name: `🧭 Navigieren zu ${lbl}`, sub: 'Route in Google Maps (Auto oder zu Fuß)', go: () => { closeSearch(); navChooser(`Feld ${lbl}`, ctr[0], ctr[1]); } }] : [local]);
    return;
  }
  if (q.type === 'corner') {
    if (immediate) await findCorner(q);
    else showResults([cornerEntry(q)]);
    return;
  }
  if (q.type !== 'address' || text.length < 3) { $('searchbar').hidden = true; return; }
  const run = async () => {
    const ac = suggestAbort = new AbortController();
    const c = map.getCenter();
    try {
      const list = await suggestPlaces(text, { lat: c.lat, lon: c.lng }, ac.signal);
      if ($('search-input').value.trim() !== text) return; // inzwischen weitergetippt
      if (list.length) showResults(list.map(asResult), 'Vorschläge: © OpenStreetMap-Mitwirkende (Photon)');
      else showResults([], 'Nichts gefunden. Tipp: Ort mit angeben, z. B. „Waldweg 5, Musterstadt“.');
    } catch (err) {
      if (ac.signal.aborted) return; // neu getippt; ein Zeitlimit geht weiter zum Ersatz
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
// v112: Knopf „Gebiete“ neben dem Suchfeld – Liste aller Umrisse und Raster, Antippen zentriert die Karte darauf
$('area-btn').addEventListener('click', () => {
  if (!$('searchbar').hidden && $('searchbar').dataset.kind === 'areas') return closeSearch();
  const list = areaResults();
  if (!list.length) return toast('Noch keine Gebiete – erst einen Umriss oder ein Raster anlegen');
  collapseSearch();
  showResults(list, '', '📍 Gebiete');
});
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
  if (local) { $('search-input').blur(); local.go(); collapseSearch(); return; }
  if (q.type === 'cell' && grid) { toast('Dieses Feld gibt es im Raster nicht.'); return; }
  // Enter: ersten Vorschlag nehmen, sonst sofort suchen
  if (shownResults.length && !$('searchbar').hidden) {
    $('search-input').blur();
    shownResults[0].go();
    collapseSearch();
    return;
  }
  showResults([], 'Suche läuft …');
  await updateSuggestions(true);
});

// ---------- Fehler melden (Android-App) ----------
function reportPage() {
  const open = [...document.querySelectorAll('.panel')].find((x) => !x.hidden);
  return [open ? `Fenster ${open.id}` : 'Karte', `Werkzeug ${tool}`, !$('dlg').hidden ? 'Dialog offen' : ''].filter(Boolean).join(', ');
}
function sendReport(r) {
  try { return bridge.reportError(JSON.stringify({ ...r, url: reportUrl() })); } catch { return 'none'; }
}
// Status-Server, über den der Bericht läuft (eingestellte Adresse, sonst der eingebaute); die App nimmt nur script.google.com an
function reportUrl() { return validReportUrl(db.statusUrl) ? db.statusUrl : STATUS_URL; }
function autoReport(error, stack) {
  if (!canReport) return;
  const r = buildReport({ kind: 'Auto-Fehler', error, stack, version: APP_VERSION, mode: db.mode, page: reportPage(), log: repLog.text() });
  if (!repDedup(r.fingerprint)) return;
  repLog.add(`Fehler gemeldet ${r.fingerprint}`);
  if (sendReport(r) === 'sent') toast('⚠️ Ein Fehler ist aufgetreten und wurde automatisch gemeldet.');
}
if (canReport) {
  window.addEventListener('error', (e) => autoReport(e.message || String(e.error), (e.error && e.error.stack) || `${e.filename}:${e.lineno}`));
  window.addEventListener('unhandledrejection', (e) => {
    const r = e.reason;
    autoReport(r && r.message ? r.message : String(r), (r && r.stack) || '');
  });
  // Bedienprotokoll: nur Kennungen der angetippten Knöpfe
  document.addEventListener('click', (e) => { const d = describeTarget(e.target); if (d) repLog.add(`Tippen ${d}`); }, true);
  document.querySelectorAll('.report-only').forEach((el) => { el.hidden = false; });
}
async function openReport() {
  const desc = await openDlg((box, close) => {
    dlgHead(box, '🐛 Fehler melden', 'Was ist passiert, was hast du erwartet? Mitgeschickt werden nur Version, Gerät, geöffnetes Fenster und die letzten Bedienschritte – keine Einsatzdaten.');
    const ta = document.createElement('textarea');
    ta.rows = 5;
    ta.placeholder = 'z. B. „Beim Antippen von PDF speichern passiert nichts“';
    box.appendChild(ta);
    dlgButton(box, 'Senden', 'primary', () => close(ta.value.trim()));
    dlgButton(box, 'Abbrechen', '', () => close(null));
    setTimeout(() => ta.focus(), 50);
  });
  if (desc === null) return;
  if (!desc) return toast('Bitte kurz beschreiben, was nicht geklappt hat.');
  const res = sendReport(buildReport({ kind: 'Manuelle Meldung', desc, version: APP_VERSION, mode: db.mode, page: reportPage(), log: repLog.text() }));
  toast(res === 'sent' ? '🐛 Danke – Meldung wird gesendet.' : res === 'mail' ? 'Mail-App geöffnet – bitte dort absenden.' : 'Meldung konnte nicht gesendet werden.');
}
$('report-open').addEventListener('click', () => { closePanels(); openReport(); });
$('hfm-report').addEventListener('click', () => { closePanels(); openReport(); });

// ---------- Sonstiges ----------
let toastTimer = null;
// v127: Hinweis mit einem Knopf (z. B. „An EL weiterleiten?“)
function toastAction(msg, label, fn, ms = 12000) {
  toast(msg, ms);
  const t = $('toast');
  const b = document.createElement('button');
  b.type = 'button';
  b.id = 'toast-act';
  b.textContent = label;
  b.style.cssText = 'margin-left:10px;padding:4px 10px;';
  b.addEventListener('click', () => { t.hidden = true; fn(); });
  t.appendChild(b);
}
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

// ---------- v103: Selbst-Update der Android-App ----------
// Die Hülle (Updater.kt) prüft im Release, ob eine neuere APK da ist, lädt sie und startet den Android-Installer.
// Der Hinweis erscheint nie mitten im Einsatz: erst wenn kein Einsatz offen ist (siehe update.js).
const updBridge = bridge && bridge.updateCheck && bridge.appVersion ? bridge : null;
let updInstalled = null; // {code, name, enabled}
let updAvail = null; // {code, name}: neuere Version, noch nicht installiert
let updLater = false; // „Später“: bis zum nächsten App-Start nicht wieder fragen
let updBusy = false; // Hinweis oder Download läuft
let updManual = false; // Suche per Knopf in „Mehr“
let updDl = null; // Fortschrittsdialog {close, text}
let updWaitInstall = false; // wartet auf die Erlaubnis „Unbekannte Apps installieren“
let updTimer = null;
// v126: HF – offen ist nur ein Auftrag, der noch nicht abgeschlossen ist
const updEinsatzOffen = () => einsatzOffen({ mode: db.mode, free: isFree(), closed: isClosed(), hfAssigned: !!(P && P.hf && !P.hf.closed) });
let updHf = false; // v126: Suche kam aus dem HF-Menü (dort gibt es kein „Mehr“-Panel) -> Meldungen als Toast
function updMsg(text) {
  if (updHf && text) toast(text, 5000);
  const m = $('upd-msg');
  m.textContent = text || '';
  m.hidden = !text;
}
function updTryOffer() {
  if (!updAvail || updBusy || !$('dlg').hidden) return;
  if (!shouldOfferUpdate({ installed: updInstalled.code, latest: updAvail.code, einsatzOffen: updEinsatzOffen(), later: updLater })) return;
  updOffer(false);
}
async function updOffer(manual) {
  if (updBusy || !updAvail) return;
  updBusy = true;
  const warn = manual && updEinsatzOffen();
  const go = await openDlg((box, close) => {
    const hf = db.mode === 'hf'; // v126: HF – Warnung nennt den offenen Auftrag
    dlgHead(box, warn ? (hf ? '⚠️ Auftrag noch offen – trotzdem aktualisieren?' : '⚠️ Einsatz läuft – trotzdem aktualisieren?') : '⬇️ Update verfügbar',
      `${updateText(updInstalled.name, updAvail.name)}${warn ? `\n\nWährend des Updates ist die App kurz nicht benutzbar.${hf ? ' Der Auftrag, der gelaufene Weg und noch nicht gesendete Meldungen bleiben gespeichert.' : ''}` : ''}`);
    dlgButton(box, 'Jetzt aktualisieren', 'primary', () => close(true));
    dlgButton(box, 'Später', '', () => close(false));
  });
  if (!go) { if (!manual) updLater = true; updBusy = false; return; }
  updProgress(0);
  updBridge.updateDownload();
}
function updProgress(pct) {
  if (!updDl) {
    openDlg((box, close) => {
      dlgHead(box, '⬇️ Update wird geladen');
      const p = document.createElement('p');
      p.className = 'small';
      box.appendChild(p);
      updDl = { close, text: p };
    }, { keep: true });
  }
  updDl.text.textContent = `Lädt … ${pct} %`;
}
function updCloseProgress() {
  if (updDl) { const d = updDl; updDl = null; d.close(); }
}
async function updInstallNow() {
  if (!updBridge.updateCanInstall || updBridge.updateCanInstall()) {
    updWaitInstall = false;
    updBridge.updateInstall();
    updBusy = false;
    updLater = true; // Installer läuft: bricht man ihn ab, nicht gleich wieder fragen (Knopf in „Mehr“ geht weiter)
    return;
  }
  updWaitInstall = true;
  const ok = await openDlg((box, close) => {
    dlgHead(box, '⬇️ Update bereit', PERMISSION_HINT);
    dlgButton(box, 'Weiter', 'primary', () => close(true));
    dlgButton(box, 'Abbrechen', '', () => close(false));
  });
  if (!ok) { updWaitInstall = false; updBusy = false; return; }
  updBridge.updateInstall(); // öffnet die Einstellung; zurück in der App geht es weiter (visibilitychange)
}
window.sgkUpdate = (s) => {
  if (!s || !updInstalled) return;
  if (s.state === 'available') {
    updAvail = { code: s.code, name: s.name || `1.0.${s.code}` };
    if (updManual) { updManual = false; updMsg(''); updOffer(true); return; }
    updTryOffer();
    if (!updTimer) updTimer = setInterval(updTryOffer, 3000); // Einsatz offen: später nochmal versuchen
  } else if (s.state === 'none') {
    if (updManual) { updManual = false; updMsg(`✓ Du hast die neueste Version (${updInstalled.name}).`); }
  } else if (s.state === 'progress') {
    updProgress(s.pct || 0);
  } else if (s.state === 'ready') {
    updCloseProgress();
    updInstallNow();
  } else if (s.state === 'error') {
    updCloseProgress();
    updBusy = false;
    toast(`Update fehlgeschlagen: ${s.msg || 'unbekannter Fehler'}. Die APK gibt es auch unter ⚙️ Mehr → „Neueste APK herunterladen“.`, 8000);
  }
};
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState !== 'visible' || !updWaitInstall || !updBridge) return;
  if (!updBridge.updateCanInstall || updBridge.updateCanInstall()) { updWaitInstall = false; updBridge.updateInstall(); updBusy = false; updLater = true; }
});
if (updBridge) {
  try { updInstalled = JSON.parse(updBridge.appVersion()); } catch { updInstalled = null; }
}
if (updInstalled) {
  $('upd-ver').textContent = `Installierte App-Version: ${updInstalled.name}`;
  $('upd-box').hidden = false;
  const updSearch = (hf) => {
    updHf = hf;
    if (!updInstalled.enabled) return updMsg('Diese Testversion der App hat keine Update-Suche.');
    if (updBusy) return;
    updManual = true;
    updMsg('Suche läuft …');
    updBridge.updateCheck();
  };
  $('upd-check').addEventListener('click', () => updSearch(false));
  // v126: HF aktualisiert ohne PIN der Einsatzleitung; bei offenem Auftrag warnt updOffer vorher (sonst keine Warnung)
  $('hfm-update').hidden = false;
  $('hfm-update').addEventListener('click', () => { closePanels(); updSearch(true); });
  // bei jedem App-Start prüfen (kurz nach dem Laden)
  if (updInstalled.enabled) setTimeout(() => updBridge.updateCheck(), 4000);
}

// Startmeldung (der Emulator-Test der Android-App wartet darauf)
console.info(`RHS Einsatz bereit (${bridge ? 'Android-App' : 'Browser'})`);

// Für Tests
window.__app = {
  get P() { return P; }, reportExtras, funkDialog, findDialog, checkAutoClose, get grid() { return grid; }, get db() { return db; }, get fallback() { return !!fallbackFor; }, probeBkg, map, setArea, setTool, saveNow, changed, renderTeamBar, checkUnread, sentBadges, renderSentList,
};

// ---------- Freigabe (v113): Sperrbildschirm, Prüfung beim Status-Server ----------
// Eine neue Sperre wirkt erst beim nächsten Start; die Prüfung blockiert den Start nie.
let lic = null;
function licSave() { try { localStorage.setItem(LIC_KEY, JSON.stringify(lic)); } catch { /* Speicher gesperrt: läuft im Speicher weiter */ } }
function licLoad() {
  const now = Date.now();
  let s = null;
  try { s = normalizeLicence(JSON.parse(localStorage.getItem(LIC_KEY)), now); } catch { s = null; }
  lic = s || newLicence(uid() + uid(), now);
  if (!s) licSave();
}
// Läuft ein Einsatz (EL: offen, HF: Auftrag da), sperrt die App nie – nur ein Hinweis (siehe 'deferred').
// Solange noch kein Modus gewählt ist, gibt es keinen Einsatz.
const licBusy = () => (db.mode === 'el' || db.mode === 'hf') && updEinsatzOffen();
const licNow = () => licenceState({ now: Date.now(), lastOk: lic.lastOk, firstStart: lic.firstStart, blocked: lic.blocked, inactive: lic.inactive, busy: licBusy(), until: lic.until });
function licShow() {
  const st = licNow();
  const box = $('lic-lock');
  const hint = $('lic-hint');
  hint.hidden = st !== 'deferred';
  if (st === 'deferred') hint.textContent = DEFERRED_TEXT;
  if (st === 'ok' || st === 'deferred') { box.hidden = true; return false; }
  const kontakt = lic.kontakt || LIC_CONTACT;
  $('lic-title').textContent = lockTitle(st);
  $('lic-text').textContent = lockText(st);
  $('lic-mail').textContent = kontakt;
  $('lic-mail').href = mailtoHref(kontakt, lic.id);
  $('lic-id').textContent = lic.id;
  $('lic-code-row').hidden = true;
  box.hidden = false;
  return true;
}
async function licCheck() {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), LIC_TIMEOUT);
  try {
    const url = checkUrl(STATUS_URL, { id: lic.id, mode: db.mode, version: APP_VERSION, platform: window.AndroidBridge ? 'apk' : 'web', name: db.deviceName, ua: navigator.userAgent });
    const res = await fetch(url, { signal: ctl.signal, cache: 'no-store' });
    lic = applyLicenceReply(lic, await res.json(), Date.now());
    licSave();
    return true;
  } catch { return false; } finally { clearTimeout(timer); }
}
// Hintergrundprüfung: nur speichern; ein offener Sperrbildschirm schließt, wenn die Prüfung wieder „ok“ ergibt
async function licBackground() {
  if (!navigator.onLine) return;
  await licCheck();
  // ein offener Sperrbildschirm schließt bei „ok“; ein Hinweis (Einsatz lief) wird zur Sperre, sobald kein Einsatz mehr offen ist
  if (!$('lic-lock').hidden || !$('lic-hint').hidden) licShow();
}
licLoad();
licShow();
$('lic-id-more').textContent = lic.id;
$('lic-copy').addEventListener('click', async () => {
  try { await navigator.clipboard.writeText(lic.id); $('lic-msg').textContent = 'ID kopiert.'; } catch { $('lic-msg').textContent = 'Kopieren nicht möglich – ID bitte markieren und von Hand kopieren.'; }
  $('lic-msg').hidden = false;
});
$('lic-retry').addEventListener('click', async () => {
  const b = $('lic-retry');
  b.disabled = true;
  const got = await licCheck();
  b.disabled = false;
  if (licShow()) {
    $('lic-msg').textContent = got ? 'Die Freigabe ist weiterhin nicht erteilt.' : 'Keine Verbindung zum Server – bitte Internet prüfen.';
    $('lic-msg').hidden = false;
  }
});
// Notfallcode: richtiger Code entsperrt 24 Stunden, auch ohne Netz (Hash kommt bei jeder Prüfung vom Server)
$('lic-emergency').addEventListener('click', () => {
  const msg = $('lic-msg');
  if (!lic.notfall) {
    msg.textContent = `Kein Notfallcode hinterlegt – Kontakt: ${lic.kontakt || LIC_CONTACT}`;
    msg.hidden = false;
    return;
  }
  $('lic-code-row').hidden = false;
  msg.hidden = true;
  $('lic-code').focus();
});
async function licEmergencyOk() {
  const next = await applyEmergencyCode(lic, $('lic-code').value, Date.now());
  if (!next) { $('lic-msg').textContent = 'Falscher Code'; $('lic-msg').hidden = false; return; }
  lic = next;
  licSave();
  $('lic-code').value = '';
  $('lic-msg').hidden = true;
  licShow();
  toast('🔑 Notfallcode angenommen – 24 Stunden entsperrt');
}
$('lic-code-ok').addEventListener('click', licEmergencyOk);
$('lic-code').addEventListener('keydown', (e) => { if (e.key === 'Enter') licEmergencyOk(); });
setTimeout(licBackground, 500);
setInterval(licBackground, LIC_CHECK_MS);
window.addEventListener('online', () => { if (!$('lic-lock').hidden) licBackground(); });

// Modus anwenden, beim ersten Start fragen, Auftrag/Rückmeldung aus dem Link übernehmen
applyMode();
// ein fehlerhafter Link oder eine kaputte Datei darf den Start (Status-Abgleich, Aufzeichnung) nicht verhindern
function bootApp() {
  if (startNotice) { toast(startNotice, 9000); startNotice = ''; } // gleich zeigen, nicht erst nach der Moduswahl
  chooseModeIfNeeded().then(handleHash).then(() => window.onSharedFile()).catch(() => toast('Link/Code konnte nicht gelesen werden')).then(async () => {
    // Weg-Sicherungen sind eingearbeitet: erst speichern, dann die kleinen Schlüssel löschen
    if (trackKeysDone.length) { if (saveNow()) for (const k of trackKeysDone) { try { localStorage.removeItem(k); } catch { /* egal */ } } trackKeysDone = []; }
    // App wurde während der Weg-Aufzeichnung geschlossen: weiter aufzeichnen
    if (db.mode === 'hf' && P.hf && P.hf.recOn && recWatch === null) startRec(true);
    if (statusStarted) { flushStatus(); pollLive(); pollHf(); return; }
    statusStarted = true;
    startStatus();
  });
}
gateStart();
