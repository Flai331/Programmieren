// GPX-Export für Garmin-Geräte und BaseCamp: Tracks, Team-Bereiche, Raster, Wegpunkte.
// Farben über die Garmin-Erweiterung (gpxx:DisplayColor), die BaseCamp und die Geräte anzeigen.

import { poiCat, poiName } from './pois.js';
import { cellLabel, gridBounds } from './grid.js';
import { markLabel, mapFor, cellsText } from './store.js';
import { CAP, textPath } from './font.js';
import { bearing, distance } from './rescue.js';
import { msgLabel, msgIcon, isUrgent } from './status.js';

const GARMIN_COLORS = {
  Black: [0, 0, 0], DarkRed: [139, 0, 0], DarkGreen: [0, 100, 0], DarkYellow: [139, 139, 0],
  DarkBlue: [0, 0, 139], DarkMagenta: [139, 0, 139], DarkCyan: [0, 139, 139], DarkGray: [100, 100, 100],
  Red: [255, 0, 0], Green: [0, 200, 0], Yellow: [255, 255, 0], Blue: [0, 0, 255],
  Magenta: [255, 0, 255], Cyan: [0, 255, 255],
};

// Feste Zuordnung für die Farben der App, sonst nächstliegende Garmin-Farbe
const KNOWN = {
  '#d50000': 'Red', '#1565c0': 'Blue', '#2e7d32': 'Green', '#ef6c00': 'DarkYellow', '#6a1b9a': 'DarkMagenta',
  '#000000': 'Black', '#fdd835': 'Yellow', '#00838f': 'DarkCyan', '#ad1457': 'Magenta', '#f06292': 'Magenta', '#4e342e': 'DarkRed',
  '#558b2f': 'DarkGreen', '#616161': 'DarkGray', '#00c853': 'Green',
};

const COLOR_DE = {
  Red: 'rot', Blue: 'blau', Green: 'grün', DarkGreen: 'grün', DarkYellow: 'orange', DarkMagenta: 'lila', Black: 'schwarz',
  Yellow: 'gelb', DarkCyan: 'türkis', Magenta: 'pink', DarkRed: 'braun', DarkGray: 'grau', DarkBlue: 'blau',
};

export function garminColor(hex) {
  if (KNOWN[String(hex).toLowerCase()]) return KNOWN[String(hex).toLowerCase()];
  const n = parseInt(String(hex || '#000000').slice(1), 16);
  const rgb = [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  let best = 'Black';
  let bestD = Infinity;
  for (const [name, c] of Object.entries(GARMIN_COLORS)) {
    const d = (c[0] - rgb[0]) ** 2 + (c[1] - rgb[1]) ** 2 + (c[2] - rgb[2]) ** 2;
    if (d < bestD) { bestD = d; best = name; }
  }
  return best;
}

// Länge einer Punktliste [[lat, lon], ...] in Metern
export function trackLength(pts) {
  let m = 0;
  for (let i = 1; i < pts.length; i++) {
    const [la1, lo1] = pts[i - 1];
    const [la2, lo2] = pts[i];
    const r = Math.PI / 180;
    const a = Math.sin(((la2 - la1) * r) / 2) ** 2
      + Math.cos(la1 * r) * Math.cos(la2 * r) * Math.sin(((lo2 - lo1) * r) / 2) ** 2;
    m += 2 * 6371008.8 * Math.asin(Math.sqrt(a));
  }
  return m;
}

// Fläche des Umrisses in m² (als geschlossen betrachtet: letzter Punkt zurück zum ersten)
export function polygonArea(pts) {
  if (pts.length < 3) return 0;
  const lat0 = pts.reduce((a, p) => a + p[0], 0) / pts.length;
  const ky = 6371008.8 * Math.PI / 180;
  const kx = ky * Math.cos(lat0 * Math.PI / 180);
  let a = 0;
  for (let i = 0; i < pts.length; i++) {
    const [la1, lo1] = pts[i];
    const [la2, lo2] = pts[(i + 1) % pts.length];
    a += lo1 * kx * la2 * ky - lo2 * kx * la1 * ky;
  }
  return Math.abs(a) / 2;
}

// 12345 m² -> "1,23 ha"
export function formatArea(m2) {
  const ha = m2 / 10000;
  return `${ha.toLocaleString('de-DE', { maximumFractionDigits: ha < 10 ? 2 : 1 })} ha`;
}

// Fläche nur bei Umrissen ab 3 Punkten; importierte offene Tracks (Wege) haben keine
export function hasArea(it) {
  return it.kind === 'track' && it.pts.length > 2 && !it.open;
}

// Beschreibung eines Umrisses: Länge, ggf. auch die Fläche
// Name für einen neuen Umriss: Himmelsrichtung vom B-Ort zur Mitte des Umrisses und
// fortlaufende Nummer über alle Umrisse („Nord 1“, „Nordwest 2“, „Nord 3“).
// Ohne B-Ort (oder Umriss direkt am B-Ort): „Umriss 3“.
const DIR8 = ['Nord', 'Nordost', 'Ost', 'Südost', 'Süd', 'Südwest', 'West', 'Nordwest'];
export function outlineName(items, meet, pts) {
  const tracks = items.filter((it) => it.kind === 'track');
  const nums = tracks.map((it) => Number((String(it.name || '').match(/(\d+)\s*$/) || [])[1]) || 0);
  const n = Math.max(tracks.length, ...nums) + 1;
  if (!meet || !pts.length) return `Umriss ${n}`;
  const la = pts.map((q) => q[0]);
  const lo = pts.map((q) => q[1]);
  const lat = (Math.max(...la) + Math.min(...la)) / 2;
  const lon = (Math.max(...lo) + Math.min(...lo)) / 2;
  if (distance(meet.lat, meet.lon, lat, lon) < 30) return `Umriss ${n}`;
  return `${DIR8[Math.round(bearing(meet.lat, meet.lon, lat, lon) / 45) % 8]} ${n}`;
}

export function trackDesc(pts, open = false) {
  const len = formatLength(trackLength(pts));
  return pts.length > 2 && !open ? `${len} · ${formatArea(polygonArea(pts))}` : len;
}

export function formatLength(m) {
  return m >= 1000 ? `${(m / 1000).toLocaleString('de-DE', { maximumFractionDigits: 2 })} km` : `${Math.round(m)} m`;
}

// Zusammenhängende Feldgruppen (Nachbarn über Kanten), sortiert von oben links
export function cellComponents(keys) {
  const rest = new Set(keys);
  const parts = [];
  const sorted = [...rest].sort((a, b) => {
    const [ac, ar] = a.split(',').map(Number);
    const [bc, br] = b.split(',').map(Number);
    return ar - br || ac - bc;
  });
  for (const start of sorted) {
    if (!rest.has(start)) continue;
    const part = [];
    const stack = [start];
    rest.delete(start);
    while (stack.length) {
      const k = stack.pop();
      part.push(k);
      const [c, r] = k.split(',').map(Number);
      for (const n of [`${c + 1},${r}`, `${c - 1},${r}`, `${c},${r + 1}`, `${c},${r - 1}`]) {
        if (rest.has(n)) { rest.delete(n); stack.push(n); }
      }
    }
    parts.push(part);
  }
  return parts;
}

// Umriss einer Feldmenge ("c,r") als geschlossene Linienzüge in Rasterecken [c, r]
export function cellOutlines(keys) {
  const set = new Set(keys);
  const has = (c, r) => set.has(`${c},${r}`);
  const edges = new Map(); // Startecke -> Liste von Endecken (im Uhrzeigersinn)
  const add = (a, b) => {
    const k = a.join(',');
    if (!edges.has(k)) edges.set(k, []);
    edges.get(k).push(b);
  };
  for (const key of set) {
    const [c, r] = key.split(',').map(Number);
    if (!has(c, r - 1)) add([c, r], [c + 1, r]);
    if (!has(c + 1, r)) add([c + 1, r], [c + 1, r + 1]);
    if (!has(c, r + 1)) add([c + 1, r + 1], [c, r + 1]);
    if (!has(c - 1, r)) add([c, r + 1], [c, r]);
  }
  const loops = [];
  for (const startKey of [...edges.keys()].sort()) {
    while (edges.get(startKey) && edges.get(startKey).length) {
      const start = startKey.split(',').map(Number);
      const loop = [start];
      let cur = start;
      for (;;) {
        const list = edges.get(cur.join(','));
        if (!list || !list.length) break;
        const next = list.shift();
        if (next[0] === start[0] && next[1] === start[1]) break;
        loop.push(next);
        cur = next;
      }
      loops.push(simplify([...loop, start]));
    }
  }
  return loops;
}

// Punkte auf geraden Strecken weglassen
function simplify(pts) {
  const out = [pts[0]];
  for (let i = 1; i < pts.length - 1; i++) {
    const [a, b, c] = [out[out.length - 1], pts[i], pts[i + 1]];
    if ((b[0] - a[0]) * (c[1] - b[1]) !== (b[1] - a[1]) * (c[0] - b[0])) out.push(b);
  }
  out.push(pts[pts.length - 1]);
  return out;
}

// Alle Rasterlinien als EINE durchgehende Linie (Zickzack): erst die waagerechten
// Linien hin und her, dann die senkrechten. Verbindungsstücke liegen auf dem Rand.
export function gridPath(grid) {
  const lat = (r) => grid.originLat - r * grid.dLat;
  const lon = (c) => grid.originLon + c * grid.dLon;
  const pts = [];
  for (let r = 0; r <= grid.rows; r++) {
    const [a, b] = r % 2 ? [grid.cols, 0] : [0, grid.cols];
    pts.push([lat(r), lon(a)], [lat(r), lon(b)]);
  }
  // Ende unten links (gerade Zeilenzahl) oder unten rechts
  const fromWest = grid.rows % 2 === 1;
  const cols = [...Array(grid.cols + 1).keys()];
  if (!fromWest) cols.reverse();
  cols.forEach((c, i) => {
    const [a, b] = i % 2 ? [0, grid.rows] : [grid.rows, 0];
    pts.push([lat(a), lon(c)], [lat(b), lon(c)]);
  });
  return pts;
}

// Feldnamen als Linienschrift: unten links in jedem Feld, auf der unteren Rasterlinie stehend.
// Zeile für Zeile im Zickzack; alle Wege zwischen den Namen laufen auf Rasterlinien, darum
// reicht ein Track für alle Felder. Höchstens maxPts Punkte je Track (viele Garmin-Geräte
// nehmen 10 000 Punkte pro Track), bei sehr großen Rastern mehrere Tracks nach Zeilen.
export function labelTracks(grid, maxPts = 9000) {
  const texts = [];
  let maxW = 0;
  for (let r = 0; r < grid.rows; r++) {
    texts.push([]);
    for (let c = 0; c < grid.cols; c++) {
      const t = textPath(cellLabel(c, r));
      texts[r].push(t);
      maxW = Math.max(maxW, t.width);
    }
  }
  // Schrifthöhe 1/4 Feld, lange Namen kleiner (höchstens 80 % der Feldbreite)
  const u = Math.min(0.25 / CAP, 0.8 / maxW);
  const ll = ([x, y]) => [grid.originLat - y * grid.dLat, grid.originLon + x * grid.dLon];
  const tracks = [];
  let cur = null;
  for (let r = 0; r < grid.rows; r++) {
    const y = r + 1; // untere Rasterlinie der Zeile (in Feldern von oben)
    const row = [[0, y]];
    texts[r].forEach((t, c) => {
      for (const [gx, gy] of t.pts) row.push([c + 0.12 + gx * u, y - gy * u]);
    });
    row.push([grid.cols, y]);
    if (!cur || (cur.pts.length && cur.pts.length + row.length > maxPts)) {
      cur = { rows: [r, r], pts: [] };
      tracks.push(cur);
    }
    // jede zweite Zeile rückwärts: Übergang am Rand entlang
    if ((r - cur.rows[0]) % 2) row.reverse();
    cur.pts.push(...row.map(ll));
    cur.rows[1] = r;
  }
  return tracks;
}

// Raster UND Feldnamen als EIN Linienzug: oberer Rand, dann die Feldnamen Zeile für Zeile
// (zeichnen dabei alle waagerechten Linien), dann die senkrechten Linien im Zickzack.
// Alle Verbindungen liegen auf Rasterlinien. null, wenn es mehr als maxPts Punkte würden.
export function gridWithLabels(grid, maxPts = 9000) {
  const labels = labelTracks(grid, Infinity)[0].pts;
  const lat = (r) => grid.originLat - r * grid.dLat;
  const lon = (c) => grid.originLon + c * grid.dLon;
  const pts = [[lat(0), lon(grid.cols)], [lat(0), lon(0)], ...labels];
  // letzte Zeile endet links (rückwärts gezeichnet) oder rechts
  const endLeft = (grid.rows - 1) % 2 === 1;
  const cols = [...Array(grid.cols + 1).keys()];
  if (!endLeft) cols.reverse();
  cols.forEach((c, i) => {
    const [a, b] = i % 2 ? [0, grid.rows] : [grid.rows, 0];
    pts.push([lat(a), lon(c)], [lat(b), lon(c)]);
  });
  return pts.length <= maxPts ? pts : null;
}

function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

const f6 = (v) => v.toFixed(7);

function trk(name, color, segments, desc = '') {
  const segs = segments.filter((s) => s.length > 1).map((s) => `   <trkseg>\n${
    s.map(([lat, lon]) => `    <trkpt lat="${f6(lat)}" lon="${f6(lon)}"/>`).join('\n')}\n   </trkseg>`).join('\n');
  if (!segs) return '';
  return ` <trk>\n  <name>${esc(name)}</name>\n${desc ? `  <desc>${esc(desc)}</desc>\n` : ''}`
    + `  <extensions><gpxx:TrackExtension><gpxx:DisplayColor>${garminColor(color)}</gpxx:DisplayColor></gpxx:TrackExtension></extensions>\n`
    + `${segs}\n </trk>\n`;
}

function wpt(lat, lon, name, sym, desc = '', time = '') {
  return ` <wpt lat="${f6(lat)}" lon="${f6(lon)}">\n${time ? `  <time>${time}</time>\n` : ''}  <name>${esc(name)}</name>\n`
    + `${desc ? `  <desc>${esc(desc)}</desc>\n` : ''}  <sym>${sym}</sym>\n </wpt>\n`;
}

// ---------- v116: Meldungen mit Ort (Fund, Anzeige, Hilfe, Hinweis, Gefahr, Parkplatz …) ----------
const MSG_NAME = { fund: 'Fund', anzeige: 'Anzeige', hilfe: 'Hilfe', hinweis: 'Hinweis', gefahr: 'Gefahr', sonst: 'Meldung', da: 'Parkplatz' };
// Garmin-Symbol je Art: Fund rote Flagge, Anzeige blaue Flagge, Hilfe Sanitätsstation, sonst grüne Flagge
const MSG_SYM = { fund: 'Flag, Red', anzeige: 'Flag, Blue', hilfe: 'Medical Facility' };
const hhmmOf = (t) => { const d = new Date(t); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
// Meldungen mit Ort -> Wegpunkte [{ lat, lon, name, time, t, desc, sym, kind, team, urgent, icon }] (nach Zeit sortiert).
// Zurückgezogene (gone), gelöschte und Korrektur-Meldungen (kor) sowie Meldungen ohne Ort fehlen.
// teamsById: optional { Auftrags-ID: Teamname }, sonst der Name in der Meldung (tm)
export function msgWaypoints(msgs, teamsById = {}) {
  const out = [];
  for (const m of msgs || []) {
    if (!m || m.s === 'kor' || m.gone || !Number.isFinite(m.lat) || !Number.isFinite(m.lon) || !Number.isFinite(m.t)) continue;
    const kind = m.s === 'ort' ? m.cat : m.s;
    const team = (teamsById && teamsById[m.a]) || m.tm || 'Team';
    const label = msgLabel(m).replace(/^\S+\s/, ''); // ohne Symbol: „Person gefunden“
    out.push({
      lat: m.lat, lon: m.lon, t: m.t, kind, team, label, txt: m.txt || '',
      name: `${MSG_NAME[kind] || 'Meldung'} ${team} ${hhmmOf(m.t)}`,
      time: new Date(m.t).toISOString(),
      desc: [label, m.txt].filter(Boolean).join(' – '),
      sym: MSG_SYM[kind] || 'Flag, Green',
      urgent: isUrgent(m),
      icon: msgIcon(m),
    });
  }
  return out.sort((a, b) => a.t - b.t);
}

// Zeilen für den Abschlussbericht: [{ time: 'HH:MM', team, art, txt, coord }]; coord = fmt(lat, lon), z. B. UTMREF
export const msgRows = (msgs, teamsById, fmt) => msgWaypoints(msgs, teamsById).map((w) => ({
  time: hhmmOf(w.t), team: w.team, art: w.label, txt: w.txt, coord: fmt ? fmt(w.lat, w.lon) : `${w.lat.toFixed(5)}, ${w.lon.toFixed(5)}`,
}));

// opts: { tracks, drawings, teams, grid: 'outline'|'all'|'none', cells: 'lines'|'all'|'none', points,
//         msgs: Meldungen mit Ort (msgWaypoints, zusammen mit points),
//         prefix: vor den Feldern in Team-Tracknamen, z. B. „Nord “ bei mehreren Rastergebieten }
export function buildGpx(project, grid, opts, part = '') {
  const title = project.title || 'Suchgebiet';
  const docName = part ? `${title} – ${part}` : title;
  let wpts = '';
  let trks = '';
  const corner = ([c, r]) => [grid.originLat - r * grid.dLat, grid.originLon + c * grid.dLon];

  if (opts.points) {
    if (project.meet) wpts += wpt(project.meet.lat, project.meet.lon, project.meet.text || 'B-Ort', 'Flag, Blue', 'B-Ort');
    for (const p of project.pois || []) {
      const c = poiCat(p.cat);
      wpts += wpt(p.lat, p.lon, poiName(p), c.gpx, [c.label, p.desc].filter(Boolean).join(' – '));
    }
    for (const it of project.items) {
      if (it.kind === 'text') wpts += wpt(it.lat, it.lon, it.text, 'Pin, Red');
    }
    // v116: Meldungen mit Ort (opts.msgs aus msgWaypoints), je ein Wegpunkt mit Zeit
    for (const w of opts.msgs || []) wpts += wpt(w.lat, w.lon, w.name, w.sym, w.desc, w.time);
  }
  // opts.cells: 'lines' = Feldnamen als Linienschrift (ein Track, siehe unten),
  // 'all' (oder true) = ein Wegpunkt je Feld, sonst keine
  if (opts.cells && opts.cells !== 'none' && opts.cells !== 'lines' && grid) {
    for (let r = 0; r < grid.rows; r++) {
      for (let c = 0; c < grid.cols; c++) {
        wpts += wpt(grid.originLat - (r + 0.5) * grid.dLat, grid.originLon + (c + 0.5) * grid.dLon, cellLabel(c, r), 'Waypoint', `Feld ${cellLabel(c, r)}`);
      }
    }
  }
  if (opts.tracks) {
    for (const it of project.items) {
      // geschlossener Umriss: zurück zum ersten Punkt, damit BaseCamp/Garmin ihn rundum zeigen
      if (it.kind === 'track') trks += trk(it.name || 'Umriss', it.color, [hasArea(it) ? [...it.pts, it.pts[0]] : it.pts], [it.note, trackDesc(it.pts, it.open)].filter(Boolean).join(' · '));
    }
  }
  if (opts.drawings) {
    // Name der Zeichnung, sonst „Stift 3 (rot)“ – Nummer nach Reihenfolge aller Zeichnungen.
    // Zeichnung aus mehreren Strichen (gleiche group): je Strich ein Track, ab dem zweiten „(Teil 2)“ …
    // (Striche in einem Track würden BaseCamp/Garmin miteinander verbinden)
    let n = 0;
    const groups = {};
    for (const it of project.items) {
      if (it.kind !== 'stroke') continue;
      let part = 1;
      if (it.group && groups[it.group]) {
        part = ++groups[it.group].parts;
      } else {
        n++;
        if (it.group) groups[it.group] = { n, parts: 1 };
      }
      if (it.pts.length < 2) continue;
      const num = it.group ? groups[it.group].n : n;
      const color = String(it.color).toLowerCase() === '#f06292' ? 'rosa' : COLOR_DE[garminColor(it.color)] || '';
      const name = it.name || `Stift ${num}${color ? ` (${color})` : ''}`;
      trks += trk(part > 1 ? `${name} (Teil ${part})` : name, it.color, [it.pts], formatLength(trackLength(it.pts)));
    }
  }
  if (opts.teams && grid) {
    for (const m of project.marks) {
      const map = mapFor(project, m);
      const keys = Object.keys(map).filter((k) => map[k] === m.id);
      if (!keys.length) continue;
      // Ein Track pro zusammenhängendem Bereich: Teilstücke in EINEM Track verbinden
      // BaseCamp und Garmin-Geräte mit (schrägen) Linien. Name mit Feldern, z. B. „abgesucht: D3–E4“.
      for (const part of cellComponents(keys)) {
        const name = `${markLabel(m)}: ${opts.prefix || ''}${cellsText(part)}`;
        cellOutlines(part).forEach((loop, i) => {
          trks += trk(i ? `${name} (Innenrand)` : name, m.color, [loop.map(corner)]);
        });
      }
    }
  }
  // Rasterlinien + Linienschrift: wenn möglich ein einziger Track (ein Eintrag in BaseCamp)
  const both = grid && opts.cells === 'lines' && opts.grid && opts.grid !== 'none' && opts.grid !== 'outline'
    ? gridWithLabels(grid) : null;
  if (both) {
    trks += trk(`Raster ${title}`, '#d50000', [both], `${grid.cellM} m Felder mit Feldnamen, A1 = Nordwest-Ecke`);
  }
  // opts.grid: 'outline' = nur Umrandung, 'all' (oder true) = mit allen Rasterlinien
  if (!both && opts.grid && opts.grid !== 'none' && grid) {
    const gb = gridBounds(grid);
    const desc = `${grid.cellM} m Felder, A1 = Nordwest-Ecke`;
    if (opts.grid === 'outline') {
      const ring = [[gb.north, gb.west], [gb.north, gb.east], [gb.south, gb.east], [gb.south, gb.west], [gb.north, gb.west]];
      trks += trk(`Suchgebiet ${title}`, '#d50000', [ring], desc);
    } else {
      trks += trk(`Raster ${title}`, '#d50000', [gridPath(grid)], desc);
    }
  }
  if (!both && opts.cells === 'lines' && grid) {
    const parts = labelTracks(grid);
    for (const t of parts) {
      const rows = parts.length > 1 ? ` (Zeilen ${t.rows[0] + 1}–${t.rows[1] + 1})` : '';
      trks += trk(`Feldnamen ${title}${rows}`, '#d50000', [t.pts], 'Feldnamen A1, B1 … als Linienschrift, unten links in jedem Feld');
    }
  }

  return gpxDoc(docName, wpts, trks);
}

function gpxDoc(docName, wpts, trks) {
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
    + '<gpx version="1.1" creator="Suchgebiet-Karten" xmlns="http://www.topografix.com/GPX/1/1"'
    + ' xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3"'
    + ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
    + ' xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd'
    + ' http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd">\n'
    + ` <metadata>\n  <name>${esc(docName)}</name>\n  <time>${new Date().toISOString()}</time>\n </metadata>\n`
    + wpts + trks + '</gpx>\n';
}

// Punkt [lat, lon] in einem geschlossenen Umriss? (Strahlverfahren, für kleine Gebiete genau genug)
export function pointInPolygon([lat, lon], poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [ai, bi] = poly[i];
    const [aj, bj] = poly[j];
    if ((bi > lon) !== (bj > lon) && lat < ((aj - ai) * (lon - bi)) / (bj - bi) + ai) inside = !inside;
  }
  return inside;
}

// Ausgewählte Dinge als eine GPX-Datei (z. B. für die Garmin-App an das Handgerät).
// sel: { items: Umrisse/Striche/Texte, pois, meet, areas: [{ name, color, loops: [[lat, lon] …] }],
//        lines: [{ name, color, pts }] } – Felder und Rasterlinien kommen schon als Koordinaten
export function selectionGpx(sel, docName) {
  let wpts = '';
  let trks = '';
  if (sel.meet) wpts += wpt(sel.meet.lat, sel.meet.lon, sel.meet.text || 'B-Ort', 'Flag, Blue', 'B-Ort');
  for (const p of sel.pois || []) {
    const c = poiCat(p.cat);
    wpts += wpt(p.lat, p.lon, poiName(p), c.gpx, [c.label, p.desc].filter(Boolean).join(' – '));
  }
  let n = 0;
  for (const it of sel.items || []) {
    if (it.kind === 'text') wpts += wpt(it.lat, it.lon, it.text, 'Pin, Red');
    else if (it.kind === 'track') trks += trk(it.name || 'Umriss', it.color, [hasArea(it) ? [...it.pts, it.pts[0]] : it.pts], [it.note, trackDesc(it.pts, it.open)].filter(Boolean).join(' · '));
    else if (it.kind === 'stroke' && it.pts && it.pts.length > 1) {
      n++;
      const color = COLOR_DE[garminColor(it.color)] || '';
      trks += trk(it.name || `Stift ${n}${color ? ` (${color})` : ''}`, it.color, [it.pts], formatLength(trackLength(it.pts)));
    }
  }
  for (const a of sel.areas || []) {
    a.loops.forEach((loop, i) => { trks += trk(i ? `${a.name} (Innenrand)` : a.name, a.color, [loop]); });
  }
  for (const l of sel.lines || []) trks += trk(l.name, l.color, [l.pts], l.desc || '');
  return gpxDoc(docName, wpts, trks);
}

// ---------- Import (z. B. aus BaseCamp) ----------
const COLOR_HEX = {
  Red: '#d50000', Blue: '#1565c0', Green: '#2e7d32', DarkYellow: '#ef6c00', DarkMagenta: '#6a1b9a', Black: '#000000',
  Yellow: '#fdd835', DarkCyan: '#00838f', Magenta: '#ad1457', DarkRed: '#4e342e', DarkGreen: '#558b2f', DarkGray: '#616161',
  DarkBlue: '#1565c0', Cyan: '#00838f', LightGray: '#616161', White: '#616161', Transparent: '#616161',
};

function unesc(s) {
  return String(s).replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&amp;/g, '&').trim();
}
const tag = (xml, name) => { const m = xml.match(new RegExp(`<(?:\\w+:)?${name}\\b[^>]*>([\\s\\S]*?)</(?:\\w+:)?${name}>`)); return m ? unesc(m[1]) : ''; };
const blocks = (xml, name) => xml.match(new RegExp(`<${name}\\b[\\s\\S]*?</${name}>|<${name}\\b[^>]*/>`, 'g')) || [];
function point(el) {
  const lat = parseFloat((el.match(/\blat\s*=\s*["']([^"']+)/) || [])[1]);
  const lon = parseFloat((el.match(/\blon\s*=\s*["']([^"']+)/) || [])[1]);
  return Number.isFinite(lat) && Number.isFinite(lon) ? [lat, lon] : null;
}

// Liest Tracks, Routen und Wegpunkte. Raster und Feldnamen aus unserem eigenen Export
// („Raster …“, Wegpunkte „A1“, „B12“ …) werden übersprungen.
// -> { tracks: [{name, color, pts}], waypoints: [{name, lat, lon}], skipped }
export function parseGpx(xml) {
  if (!/<gpx\b/i.test(xml)) throw new Error('keine GPX-Datei');
  xml = xml.replace(/<!--[\s\S]*?-->/g, '');
  const tracks = [];
  const waypoints = [];
  let skipped = 0;
  const add = (el, segTag, ptTag) => {
    const name = tag(el.replace(new RegExp(`<${segTag || ptTag}\\b[\\s\\S]*`), ''), 'name');
    if (/^Raster\b/.test(name)) { skipped++; return; }
    const c = tag(el, 'DisplayColor');
    const color = COLOR_HEX[c] || null;
    const segs = segTag ? blocks(el, segTag) : [el];
    segs.forEach((seg, i) => {
      const pts = blocks(seg, ptTag).map(point).filter(Boolean);
      // letzter Punkt = erster (so schreiben wir geschlossene Umrisse): wieder als Umriss ohne Doppelpunkt
      const z = pts[pts.length - 1];
      const closed = pts.length > 3 && z[0] === pts[0][0] && z[1] === pts[0][1];
      if (closed) pts.pop();
      if (pts.length > 1) tracks.push({ name: segs.length > 1 && i ? `${name} (${i + 1})` : name, color, pts, ...(closed ? { closed } : {}) });
    });
  };
  for (const t of blocks(xml, 'trk')) add(t, 'trkseg', 'trkpt');
  for (const r of blocks(xml, 'rte')) add(r, '', 'rtept');
  for (const w of blocks(xml, 'wpt')) {
    const p = point(w);
    if (!p) continue;
    const name = tag(w, 'name') || tag(w, 'desc') || 'Wegpunkt';
    if (/^[A-Z]{1,3}\d{1,4}$/.test(name)) { skipped++; continue; }
    waypoints.push({ name, lat: p[0], lon: p[1] });
  }
  return { tracks, waypoints, skipped };
}

// Import ohne Duplikate: Tracks/Routen mit gleichem Namen und gleichen Punkten bzw. Wegpunkte mit gleichem Namen und Ort,
// die es in items (Umrisse/Wege kind 'track', Texte kind 'text') schon gibt – auch doppelt in der Datei selbst – werden übersprungen.
// base: Dateiname ohne Endung (Name für Tracks ohne Namen, wie beim Import). -> { tracks, waypoints, dup } (dup = Anzahl übersprungen)
const r6 = (v) => Math.round(v * 1e6) / 1e6;
const trackKey = (name, pts) => `t|${name}|${pts.map((q) => `${r6(q[0])},${r6(q[1])}`).join(';')}`;
const pointKey = (name, lat, lon) => `w|${name}|${r6(lat)},${r6(lon)}`;
export function dedupeImport(items, g, base = '') {
  const have = new Set();
  for (const it of items || []) {
    if (it.kind === 'track' && it.pts) have.add(trackKey(it.name || '', it.pts));
    else if (it.kind === 'text') have.add(pointKey(it.text, it.lat, it.lon));
  }
  let dup = 0;
  const tracks = [];
  for (const t of g.tracks) {
    const k = trackKey(t.name || base, t.pts);
    if (have.has(k)) { dup++; continue; }
    have.add(k);
    tracks.push(t);
  }
  const waypoints = [];
  for (const w of g.waypoints) {
    const k = pointKey(w.name, w.lat, w.lon);
    if (have.has(k)) { dup++; continue; }
    have.add(k);
    waypoints.push(w);
  }
  return { tracks, waypoints, dup };
}

// KML (Google Earth, Behörden): Punkte als Wegpunkte, Linien als Wege, Flächen als Umrisse – gleiche Form wie parseGpx
export function parseKml(xml) {
  if (!/<kml\b|<Placemark\b/i.test(xml)) throw new Error('keine KML-Datei');
  xml = xml.replace(/<!--[\s\S]*?-->/g, '');
  const tracks = [];
  const waypoints = [];
  const coords = (c) => c.trim().split(/\s+/).map((t) => {
    const [lon, lat] = t.split(',').map(Number);
    return Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180 ? [lat, lon] : null;
  }).filter(Boolean);
  for (const pm of blocks(xml, 'Placemark')) {
    const name = tag(pm.replace(/<(Point|LineString|Polygon|MultiGeometry)\b[\s\S]*/, ''), 'name') || tag(pm, 'name');
    for (const pt of blocks(pm, 'Point')) {
      const [p] = coords(tag(pt, 'coordinates'));
      if (p) waypoints.push({ name: name || 'Wegpunkt', lat: p[0], lon: p[1] });
    }
    const lines = blocks(pm, 'LineString');
    lines.forEach((ls, i) => {
      const pts = coords(tag(ls, 'coordinates'));
      if (pts.length > 1) tracks.push({ name: lines.length > 1 && i ? `${name} (${i + 1})` : name, color: null, pts });
    });
    const polys = blocks(pm, 'Polygon');
    polys.forEach((pg, i) => {
      const outer = blocks(pg, 'outerBoundaryIs')[0] || pg;
      const pts = coords(tag(outer, 'coordinates'));
      const z = pts[pts.length - 1];
      if (pts.length > 3 && z[0] === pts[0][0] && z[1] === pts[0][1]) pts.pop();
      if (pts.length > 2) tracks.push({ name: polys.length > 1 && i ? `${name} (${i + 1})` : name, color: null, pts, closed: true });
    });
  }
  return { tracks, waypoints, skipped: 0 };
}

// Mehrere GPX-Texte (je Rastergebiet) zu einer Datei: Kopf der ersten, alle Wegpunkte, dann alle Tracks
// docName: Name der Datei/Liste (ersetzt den ersten <name> im Kopf)
export function mergeGpx(list, docName = '') {
  if (list.length < 2) return list[0] || '';
  let head = list[0].slice(0, list[0].search(/ <wpt\b| <trk>|<\/gpx>/));
  if (docName) head = head.replace(/<name>[^<]*<\/name>/, `<name>${esc(docName)}</name>`);
  const all = (re) => list.flatMap((x) => x.match(re) || []).join('');
  return `${head}${all(/ <wpt\b[\s\S]*?<\/wpt>\n/g)}${all(/ <trk>[\s\S]*?<\/trk>\n/g)}</gpx>\n`;
}
