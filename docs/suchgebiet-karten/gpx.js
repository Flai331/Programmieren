// GPX-Export für Garmin-Geräte und BaseCamp: Tracks, Team-Bereiche, Raster, Wegpunkte.
// Farben über die Garmin-Erweiterung (gpxx:DisplayColor), die BaseCamp und die Geräte anzeigen.

import { cellLabel, colName, gridBounds } from './grid.js';
import { markLabel, mapFor, cellsText } from './store.js';

const GARMIN_COLORS = {
  Black: [0, 0, 0], DarkRed: [139, 0, 0], DarkGreen: [0, 100, 0], DarkYellow: [139, 139, 0],
  DarkBlue: [0, 0, 139], DarkMagenta: [139, 0, 139], DarkCyan: [0, 139, 139], DarkGray: [100, 100, 100],
  Red: [255, 0, 0], Green: [0, 200, 0], Yellow: [255, 255, 0], Blue: [0, 0, 255],
  Magenta: [255, 0, 255], Cyan: [0, 255, 255],
};

// Feste Zuordnung für die Farben der App, sonst nächstliegende Garmin-Farbe
const KNOWN = {
  '#d50000': 'Red', '#1565c0': 'Blue', '#2e7d32': 'Green', '#ef6c00': 'DarkYellow', '#6a1b9a': 'DarkMagenta',
  '#000000': 'Black', '#fdd835': 'Yellow', '#00838f': 'DarkCyan', '#ad1457': 'Magenta', '#4e342e': 'DarkRed',
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

function wpt(lat, lon, name, sym, desc = '') {
  return ` <wpt lat="${f6(lat)}" lon="${f6(lon)}">\n  <name>${esc(name)}</name>\n`
    + `${desc ? `  <desc>${esc(desc)}</desc>\n` : ''}  <sym>${sym}</sym>\n </wpt>\n`;
}

// opts: { tracks, drawings, teams, grid: 'outline'|'all'|'none', cells, points }
export function buildGpx(project, grid, opts, part = '') {
  const title = project.title || 'Suchgebiet';
  const docName = part ? `${title} – ${part}` : title;
  let wpts = '';
  let trks = '';
  const corner = ([c, r]) => [grid.originLat - r * grid.dLat, grid.originLon + c * grid.dLon];

  if (opts.points) {
    if (project.meet) wpts += wpt(project.meet.lat, project.meet.lon, project.meet.text || 'Treffpunkt', 'Flag, Blue', 'Treffpunkt');
    for (const it of project.items) {
      if (it.kind === 'text') wpts += wpt(it.lat, it.lon, it.text, 'Pin, Red');
    }
  }
  // opts.cells: 'edge' = Buchstaben oben, Zahlen links (wenige Punkte, wie am Kartenrand),
  // 'all' (oder true) = ein Wegpunkt je Feld, sonst keine
  if (opts.cells === 'edge' && grid) {
    const above = grid.originLat + grid.dLat * 0.3;
    const left = grid.originLon - grid.dLon * 0.3;
    for (let c = 0; c < grid.cols; c++) {
      wpts += wpt(above, grid.originLon + (c + 0.5) * grid.dLon, colName(c), 'Navaid, Red', `Rasterspalte ${colName(c)}`);
    }
    for (let r = 0; r < grid.rows; r++) {
      wpts += wpt(grid.originLat - (r + 0.5) * grid.dLat, left, String(r + 1), 'Navaid, Red', `Rasterzeile ${r + 1}`);
    }
  } else if (opts.cells && opts.cells !== 'none' && grid) {
    for (let r = 0; r < grid.rows; r++) {
      for (let c = 0; c < grid.cols; c++) {
        wpts += wpt(grid.originLat - (r + 0.5) * grid.dLat, grid.originLon + (c + 0.5) * grid.dLon, cellLabel(c, r), 'Waypoint', `Feld ${cellLabel(c, r)}`);
      }
    }
  }
  if (opts.tracks) {
    for (const it of project.items) {
      if (it.kind === 'track') trks += trk(it.name || 'Track', it.color, [it.pts], formatLength(trackLength(it.pts)));
    }
  }
  if (opts.drawings) {
    let n = 1;
    for (const it of project.items) {
      if (it.kind !== 'stroke' || it.pts.length < 2) continue;
      const color = COLOR_DE[garminColor(it.color)] || '';
      trks += trk(`Stift ${n++}${color ? ` (${color})` : ''}`, it.color, [it.pts], formatLength(trackLength(it.pts)));
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
        const name = `${markLabel(m)}: ${cellsText(part)}`;
        cellOutlines(part).forEach((loop, i) => {
          trks += trk(i ? `${name} (Innenrand)` : name, m.color, [loop.map(corner)]);
        });
      }
    }
  }
  // opts.grid: 'outline' = nur Umrandung, 'all' (oder true) = mit allen Rasterlinien
  if (opts.grid && opts.grid !== 'none' && grid) {
    const gb = gridBounds(grid);
    const desc = `${grid.cellM} m Felder, A1 = Nordwest-Ecke`;
    if (opts.grid === 'outline') {
      const ring = [[gb.north, gb.west], [gb.north, gb.east], [gb.south, gb.east], [gb.south, gb.west], [gb.north, gb.west]];
      trks += trk(`Suchgebiet ${title}`, '#d50000', [ring], desc);
    } else {
      trks += trk(`Raster ${title}`, '#d50000', [gridPath(grid)], desc);
    }
  }

  return '<?xml version="1.0" encoding="UTF-8"?>\n'
    + '<gpx version="1.1" creator="Suchgebiet-Karten" xmlns="http://www.topografix.com/GPX/1/1"'
    + ' xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3"'
    + ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
    + ' xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd'
    + ' http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd">\n'
    + ` <metadata>\n  <name>${esc(docName)}</name>\n  <time>${new Date().toISOString()}</time>\n </metadata>\n`
    + wpts + trks + '</gpx>\n';
}
