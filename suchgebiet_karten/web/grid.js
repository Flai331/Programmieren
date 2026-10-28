// Raster-Logik: Das Raster ist fest an geografische Koordinaten gebunden
// (Ursprung = Nordwest-Ecke des Suchgebiets). Dadurch liegt Feld "A1" auf
// jeder Karte und in jedem Maßstab an genau derselben Stelle.

export const M_PER_DEG_LAT = 111320;
export const MAX_CELLS = 4000;

// Spaltenname: 0 -> A, 25 -> Z, 26 -> AA, ...
export function colName(i) {
  let s = '';
  let n = i + 1;
  while (n > 0) {
    const r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = Math.floor((n - 1) / 26);
  }
  return s;
}

export function colIndex(name) {
  let n = 0;
  for (const ch of name.toUpperCase()) {
    const v = ch.charCodeAt(0) - 64;
    if (v < 1 || v > 26) return -1;
    n = n * 26 + v;
  }
  return n - 1;
}

export function cellLabel(c, r) {
  return colName(c) + (r + 1);
}

// "c4", " C 4 " -> {c: 2, r: 3}
export function parseCell(text) {
  const m = /^\s*([a-zA-Z]+)\s*(\d+)\s*$/.exec(text || '');
  if (!m) return null;
  const c = colIndex(m[1]);
  const r = parseInt(m[2], 10) - 1;
  if (c < 0 || r < 0) return null;
  return { c, r };
}

// area: {north, south, west, east} in Grad, cellM: Feldgröße in Metern.
// Das Raster wird nach Osten/Süden auf ganze Felder aufgerundet.
export function makeGrid(area, cellM) {
  const north = Math.max(area.north, area.south);
  const south = Math.min(area.north, area.south);
  const west = Math.min(area.west, area.east);
  const east = Math.max(area.west, area.east);
  const dLat = cellM / M_PER_DEG_LAT;
  const dLon = cellM / (M_PER_DEG_LAT * Math.cos((north * Math.PI) / 180));
  const cols = Math.max(1, Math.ceil((east - west) / dLon - 1e-9));
  const rows = Math.max(1, Math.ceil((north - south) / dLat - 1e-9));
  return { originLat: north, originLon: west, dLat, dLon, cols, rows, cellM };
}

export function cellCount(grid) {
  return grid.cols * grid.rows;
}

export function gridBounds(grid) {
  return {
    north: grid.originLat,
    south: grid.originLat - grid.rows * grid.dLat,
    west: grid.originLon,
    east: grid.originLon + grid.cols * grid.dLon,
  };
}

export function cellBounds(grid, c, r) {
  return {
    north: grid.originLat - r * grid.dLat,
    south: grid.originLat - (r + 1) * grid.dLat,
    west: grid.originLon + c * grid.dLon,
    east: grid.originLon + (c + 1) * grid.dLon,
  };
}

// Bereich mehrerer Felder (inklusive), z. B. für Detailblätter
export function rangeBounds(grid, c0, r0, c1, r1) {
  const a = cellBounds(grid, c0, r0);
  const b = cellBounds(grid, c1, r1);
  return { north: a.north, west: a.west, south: b.south, east: b.east };
}

export function cellAt(grid, lat, lon) {
  const c = Math.floor((lon - grid.originLon) / grid.dLon);
  const r = Math.floor((grid.originLat - lat) / grid.dLat);
  if (c < 0 || r < 0 || c >= grid.cols || r >= grid.rows) return null;
  return { c, r };
}

export function rangeLabel(c0, r0, c1, r1) {
  const a = cellLabel(c0, r0);
  const b = cellLabel(c1, r1);
  return a === b ? a : `${a}–${b}`;
}

// Teilt das Raster in Blöcke von k×k Feldern (für Detailblätter im PDF).
export function blocks(grid, k) {
  const out = [];
  for (let r0 = 0; r0 < grid.rows; r0 += k) {
    for (let c0 = 0; c0 < grid.cols; c0 += k) {
      const c1 = Math.min(grid.cols - 1, c0 + k - 1);
      const r1 = Math.min(grid.rows - 1, r0 + k - 1);
      out.push({ c0, r0, c1, r1, label: rangeLabel(c0, r0, c1, r1) });
    }
  }
  return out;
}

// --- Web-Mercator (wie bei allen Online-Karten), Zoomstufe 0 = 256 px Welt ---

export function mercX(lon) {
  return ((lon + 180) / 360) * 256;
}

export function mercY(lat) {
  const s = Math.sin((Math.max(-85.0511, Math.min(85.0511, lat)) * Math.PI) / 180);
  return (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * 256;
}

export function mercLat(y) {
  const n = Math.PI - (2 * Math.PI * y) / 256;
  return (180 / Math.PI) * Math.atan(Math.sinh(n));
}

export function mercLon(x) {
  return (x / 256) * 360 - 180;
}

// Meter pro Mercator-Einheit (Zoomstufe 0) auf Breite lat
export function metersPerUnit(lat) {
  return (40075016.686 * Math.cos((lat * Math.PI) / 180)) / 256;
}

// Ausschnitt (in Mercator-Einheiten) so erweitern, dass er das Seitenverhältnis
// aspect = Breite/Höhe hat; pad = Rand als Anteil.
export function fitBox(bounds, aspect, pad = 0) {
  let x0 = mercX(bounds.west);
  let x1 = mercX(bounds.east);
  let y0 = mercY(bounds.north);
  let y1 = mercY(bounds.south);
  const pw = (x1 - x0) * pad;
  const ph = (y1 - y0) * pad;
  x0 -= pw; x1 += pw; y0 -= ph; y1 += ph;
  const w = x1 - x0;
  const h = y1 - y0;
  const cx = (x0 + x1) / 2;
  const cy = (y0 + y1) / 2;
  let nw = w;
  let nh = h;
  if (w / h > aspect) nh = w / aspect;
  else nw = h * aspect;
  return { x0: cx - nw / 2, x1: cx + nw / 2, y0: cy - nh / 2, y1: cy + nh / 2 };
}

// Gerundeter Maßstab, z. B. 4870 -> 5000
export function niceScale(denominator) {
  const steps = [1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 6, 7.5, 10];
  const p = Math.pow(10, Math.floor(Math.log10(denominator)));
  let best = steps[0] * p;
  for (const s of steps) {
    if (Math.abs(s * p - denominator) < Math.abs(best - denominator)) best = s * p;
  }
  return best;
}

// Länge für die Maßstabsleiste: "schöne" Meterzahl <= maxM
export function niceLength(maxM) {
  const steps = [1, 2, 5];
  let best = 1;
  for (let p = 1; p <= 1e6; p *= 10) {
    for (const s of steps) if (s * p <= maxM) best = s * p;
  }
  return best;
}

export function formatMeters(m) {
  return m >= 1000 ? `${(m / 1000).toLocaleString('de-DE')} km` : `${m} m`;
}

// Feldzuteilungen {"c,r": id} von einem Raster auf ein anderes übertragen (neue Feldgröße
// oder neues Gebiet). Gezählt wird beides: die Mitte jedes alten Feldes (fällt in ein neues
// Feld) und die Mitte jedes neuen Feldes (liegt in einem alten). Ein neues Feld bekommt die
// häufigste Markierung – auch wenn nur ein Teil markiert war, damit beim Vergrößern nichts
// verloren geht. Kleinere Felder erben die Markierung des großen Feldes.
export function remapCells(oldGrid, newGrid, cells) {
  const out = {};
  if (!oldGrid || !newGrid || !Object.keys(cells).length) return out;
  const counts = {};
  const add = (key, id) => {
    const c = counts[key] || (counts[key] = {});
    c[id] = (c[id] || 0) + 1;
  };
  const center = (g, c, r) => [g.originLat - (r + 0.5) * g.dLat, g.originLon + (c + 0.5) * g.dLon];
  for (const [key, id] of Object.entries(cells)) {
    const [c, r] = key.split(',').map(Number);
    const n = cellAt(newGrid, ...center(oldGrid, c, r));
    if (n) add(`${n.c},${n.r}`, id);
  }
  for (let r = 0; r < newGrid.rows; r++) {
    for (let c = 0; c < newGrid.cols; c++) {
      const o = cellAt(oldGrid, ...center(newGrid, c, r));
      const id = o && cells[`${o.c},${o.r}`];
      if (id) add(`${c},${r}`, id);
    }
  }
  for (const [key, c] of Object.entries(counts)) {
    out[key] = Object.keys(c).reduce((a, b) => (c[b] > c[a] ? b : a));
  }
  return out;
}
