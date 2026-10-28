// Zeichnet Raster, eingefärbte Felder und Zeichnungen auf ein Canvas.
// Wird für die Bildschirmanzeige UND für das PDF benutzt – so sehen beide
// gleich aus. toPx(lat, lon) -> [x, y] rechnet in Canvas-Pixel um.

import { colName, cellLabel, cellBounds, gridBounds } from './grid.js';
import { toUtm, fromUtm, utmZone } from './utm.js';
import { cellComponents, cellOutlines, formatArea, hasArea, polygonArea } from './gpx.js';
import { cellsText } from './store.js';

const GRID_COLOR = 'rgba(200, 0, 0, 0.85)';

function halo(ctx, text, x, y, color, s) {
  ctx.lineJoin = 'round';
  ctx.lineWidth = 3.5 * s;
  ctx.strokeStyle = 'rgba(255,255,255,0.95)';
  ctx.strokeText(text, x, y);
  ctx.fillStyle = color;
  ctx.fillText(text, x, y);
}

function pill(ctx, text, cx, cy, s) {
  const w = ctx.measureText(text).width + 8 * s;
  const h = 16 * s;
  ctx.fillStyle = 'rgba(255,255,255,0.9)';
  ctx.strokeStyle = GRID_COLOR;
  ctx.lineWidth = 1 * s;
  ctx.beginPath();
  ctx.rect(cx - w / 2, cy - h / 2, w, h);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#a00000';
  ctx.fillText(text, cx, cy + 0.5 * s);
}

// opt: { s: Skalierung für Linien/Schrift, width, height, view: Bounds für Culling,
//        allEdges: Randbeschriftung auch unten/rechts, sheets: Blattumrisse,
//        focus: Bereich des Detailblatts (Rest wird aufgehellt), utm: UTM-Gitter zeigen }
// state: { grid, fills: "c,r" -> Teamfarbe, status: "c,r" -> Statusfarbe (schraffiert),
//          fillLabels: "c,r" -> Text, items, meet }
// state.others: weitere Rastergebiete [{ grid, name, fills, status, fillLabels, statusLabels }],
// state.gridName: Name des Hauptrasters (steht nur da, wenn es mehrere Gebiete gibt)
export function drawOverlay(ctx, toPx, state, opt) {
  const s = opt.s || 1;
  const grid = state.grid;
  if (opt.focus) dimOutside(ctx, toPx, opt.focus, opt.width, opt.height);
  if (opt.utm && opt.view) drawUtm(ctx, toPx, opt, s);
  const layers = [...(state.others || []), { ...state, name: state.gridName }].filter((g) => g.grid);
  let areas = [];
  for (const g of layers) {
    const st = { ...state, ...g };
    if (opt.noGrid) {
      const a = drawAreas(ctx, toPx, st, g.grid, { ...opt, areaPrefix: layers.length > 1 && g.name ? `${g.name}: ` : '' }, s);
      if (a) areas.push(...a);
    } else drawGrid(ctx, toPx, st, g.grid, opt, s);
  }
  drawItems(ctx, toPx, state.items || [], s);
  if (state.meet) drawMeet(ctx, toPx, state.meet, s);
  for (const g of layers) {
    if (!opt.noGrid && !opt.noEdge) drawEdgeLabels(ctx, toPx, g.grid, opt, s);
    if (layers.length > 1 && g.name && !(opt.noGrid && opt.noEdge)) drawGridName(ctx, toPx, g.grid, g.name, s);
  }
  if (!layers.length) areas = null;
  else areas.forEach((a, i) => { a.n = i + 1; });
  if (areas && opt.areaLabels === 'edge' && areas.length) drawAreaList(ctx, areas, opt, s);
  return areas;
}

// Name eines Rastergebiets als Schild über der linken oberen Ecke
function drawGridName(ctx, toPx, grid, name, s) {
  const [x, y] = toPx(grid.originLat, grid.originLon);
  ctx.font = `bold ${13 * s}px sans-serif`;
  const w = ctx.measureText(name).width + 12 * s;
  const h = 19 * s;
  ctx.fillStyle = GRID_COLOR;
  // über der Spaltenbeschriftung (A, B …), damit beide lesbar bleiben
  const top = y - h - 26 * s;
  ctx.fillRect(x, top, w, h);
  ctx.fillStyle = '#fff';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText(name, x + 6 * s, top + h / 2);
}

// Zusammenhängende Felder gleicher Markierung (gleiche Farbe und Name) -> Flächen
function areaGroups(map, labels) {
  const groups = new Map();
  for (const [key, color] of Object.entries(map || {})) {
    const label = (labels && labels[key]) || '';
    const g = `${color}|${label}`;
    if (!groups.has(g)) groups.set(g, { color, label, keys: [] });
    groups.get(g).keys.push(key);
  }
  const out = [];
  for (const g of groups.values()) {
    for (const part of cellComponents(g.keys)) out.push({ color: g.color, label: g.label, keys: part });
  }
  return out;
}

// Feld der Fläche, das dem Schwerpunkt am nächsten liegt (dort steht die Beschriftung)
function labelCell(keys) {
  const cells = keys.map((k) => k.split(',').map(Number));
  const mc = cells.reduce((a, c) => a + c[0], 0) / cells.length;
  const mr = cells.reduce((a, c) => a + c[1], 0) / cells.length;
  return cells.reduce((best, c) => (Math.hypot(c[0] - mc, c[1] - mr) < Math.hypot(best[0] - mc, best[1] - mr) ? c : best));
}

// Karte ohne Raster (Abschlussbericht): Flächen mit einem Umriss statt Feldkästchen,
// eine Beschriftung je Fläche – auf der Fläche (areaLabels 'on') oder als Schild mit Namen plus Liste ('edge')
function drawAreas(ctx, toPx, state, grid, opt, s) {
  const corner = ([c, r]) => toPx(gridLat(grid, r), gridLon(grid, c));
  const rect = (key) => {
    const [c, r] = key.split(',').map(Number);
    const b = cellBounds(grid, c, r);
    const [x0, y0] = toPx(b.north, b.west);
    const [x1, y1] = toPx(b.south, b.east);
    return [x0, y0, x1 - x0, y1 - y0];
  };
  // Umriss einer Fläche als Pfad
  const areaPath = (keys) => {
    ctx.beginPath();
    for (const loop of cellOutlines(keys)) {
      loop.forEach((pt, i) => { const [x, y] = corner(pt); if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y); });
      ctx.closePath();
    }
  };
  // Rand nur innen bzw. nur außen an der Fläche: Team außen, Status innen –
  // so bleiben beide sichtbar, auch wenn sie dieselbe Grenze haben
  const band = (keys, color, width, inside) => {
    ctx.save();
    if (inside) {
      areaPath(keys);
      ctx.clip();
    } else {
      areaPath(keys);
      ctx.rect(opt.width * 2, -opt.height, -opt.width * 4, opt.height * 3);
      ctx.clip('evenodd');
    }
    areaPath(keys);
    ctx.lineJoin = 'miter';
    ctx.lineWidth = 2 * (width + 1.5 * s);
    ctx.strokeStyle = 'rgba(255,255,255,0.95)';
    ctx.stroke();
    ctx.lineWidth = 2 * width;
    ctx.strokeStyle = color;
    ctx.stroke();
    ctx.restore();
  };
  const a = state.markAlpha ?? 0.4;
  const teams = areaGroups(state.fills, state.fillLabels);
  const stats = areaGroups(state.status, state.statusLabels);
  for (const t of teams) {
    ctx.globalAlpha = Math.max(0.3, 0.5 * a);
    ctx.fillStyle = t.color;
    for (const k of t.keys) ctx.fillRect(...rect(k));
    ctx.globalAlpha = 1;
  }
  for (const st of stats) {
    // Schraffur über die ganze Fläche (ohne Kästchen-Ränder)
    ctx.save();
    ctx.beginPath();
    for (const k of st.keys) ctx.rect(...rect(k));
    ctx.clip();
    const xs = st.keys.map(rect);
    const minX = Math.min(...xs.map((r) => r[0]));
    const minY = Math.min(...xs.map((r) => r[1]));
    const maxX = Math.max(...xs.map((r) => r[0] + r[2]));
    const maxY = Math.max(...xs.map((r) => r[1] + r[3]));
    // kräftiger als auf dem Bildschirm: im Druck auf Luftbildern sonst kaum zu sehen
    const step = Math.max(6, 13 * s);
    ctx.beginPath();
    for (let d = minX - (maxY - minY); d < maxX; d += step) { ctx.moveTo(d, maxY); ctx.lineTo(d + (maxY - minY), minY); }
    ctx.globalAlpha = 0.9;
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 4.4 * s;
    ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.strokeStyle = st.color;
    ctx.lineWidth = 2.4 * s;
    ctx.stroke();
    ctx.restore();
  }
  for (const t of teams) band(t.keys, t.color, 4 * s, false);
  for (const st of stats) band(st.keys, st.color, 4 * s, true);

  // Beschriftung: eine je Fläche
  const areas = [];
  let n = 0;
  const label = (g, dy) => {
    if (!g.label) return;
    const [c, r] = labelCell(g.keys);
    const b = cellBounds(grid, c, r);
    const [x0, y0] = toPx(b.north, b.west);
    const [x1, y1] = toPx(b.south, b.east);
    const x = (x0 + x1) / 2;
    const y = (y0 + y1) / 2 + dy * (y1 - y0);
    n++;
    areas.push({ n, label: g.label, color: g.color, cells: (opt.areaPrefix || '') + cellsText(g.keys) });
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    if (opt.areaLabels === 'edge') {
      // Name auf weißem Schild mit Rand in der Farbe der Markierung (auf Luftbildern lesbar);
      // die Liste am Rand nennt zusätzlich die Felder
      ctx.font = `bold ${12 * s}px sans-serif`;
      const w = ctx.measureText(g.label).width + 12 * s;
      const h = 19 * s;
      ctx.beginPath();
      if (ctx.roundRect) ctx.roundRect(x - w / 2, y - h / 2, w, h, 5 * s);
      else ctx.rect(x - w / 2, y - h / 2, w, h);
      ctx.fillStyle = 'rgba(255,255,255,0.95)';
      ctx.fill();
      ctx.lineWidth = 2.5 * s;
      ctx.strokeStyle = g.color;
      ctx.stroke();
      ctx.fillStyle = '#111';
      ctx.fillText(g.label, x, y + 0.5 * s);
    } else {
      ctx.font = `bold ${14 * s}px sans-serif`;
      halo(ctx, g.label, x, y, '#111', s);
    }
  };
  for (const t of teams) label(t, 0);
  for (const st of stats) label(st, teams.some((t) => t.keys.some((k) => st.keys.includes(k))) ? 0.32 : 0);
  return areas;
}

// Liste der Flächen mit Feldern unten links im Kartenbild
function drawAreaList(ctx, areas, opt, s) {
  ctx.font = `${11 * s}px sans-serif`;
  const lineH = 16 * s;
  const texts = areas.map((a) => `${a.label} (${a.cells})`);
  const cols = Math.max(1, Math.min(3, Math.floor((opt.width * 0.62) / (Math.max(...texts.map((t) => ctx.measureText(t).width)) + 40 * s))));
  const rows = Math.ceil(texts.length / cols);
  const colW = Math.max(...texts.map((t) => ctx.measureText(t).width)) + 32 * s;
  const w = cols * colW + 10 * s;
  const h = rows * lineH + 10 * s;
  const x = 10 * s;
  const y = opt.height - h - 44 * s; // über der Maßstabsleiste
  ctx.fillStyle = 'rgba(255,255,255,0.92)';
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = '#555';
  ctx.lineWidth = 1 * s;
  ctx.strokeRect(x, y, w, h);
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  areas.forEach((a, i) => {
    const cx = x + 5 * s + Math.floor(i / rows) * colW;
    const cy = y + 5 * s + lineH * ((i % rows) + 0.5);
    // Farbkästchen wie auf der Karte
    ctx.fillStyle = a.color;
    ctx.globalAlpha = 0.45;
    ctx.fillRect(cx + 2 * s, cy - 6 * s, 13 * s, 12 * s);
    ctx.globalAlpha = 1;
    ctx.lineWidth = 2 * s;
    ctx.strokeStyle = a.color;
    ctx.strokeRect(cx + 2 * s, cy - 6 * s, 13 * s, 12 * s);
    ctx.fillStyle = '#111';
    ctx.textAlign = 'left';
    ctx.font = `${11 * s}px sans-serif`;
    ctx.fillText(`${a.label} (${a.cells})`, cx + 20 * s, cy);
  });
}

// Hellt alles außerhalb des Blattbereichs auf, damit klar ist, was zum Blatt gehört
function dimOutside(ctx, toPx, b, W, H) {
  const [x0, y0] = toPx(b.north, b.west);
  const [x1, y1] = toPx(b.south, b.east);
  ctx.fillStyle = 'rgba(255,255,255,0.45)';
  ctx.beginPath();
  ctx.rect(0, 0, W, H);
  ctx.rect(x0, y0, x1 - x0, y1 - y0);
  ctx.fill('evenodd');
}

// Rand innen im Feld, mit weißer Kontur (auf Luftbildern gut sichtbar)
export function outlineRect(ctx, x, y, w, h, color, s, width = 3, extraInset = 0) {
  const inset = (width / 2 + 1.5 + extraInset) * s;
  ctx.lineWidth = (width + 2.5) * s;
  ctx.strokeStyle = 'rgba(255,255,255,0.9)';
  ctx.strokeRect(x + inset, y + inset, w - 2 * inset, h - 2 * inset);
  ctx.lineWidth = width * s;
  ctx.strokeStyle = color;
  ctx.strokeRect(x + inset, y + inset, w - 2 * inset, h - 2 * inset);
}

// Schraffur (diagonal) mit weißer Kontur und Rand; ohne Team zusätzlich leicht flächig gefüllt
// a = Deckkraft 0..1 (Regler „Deckkraft der Markierungen“); der Rand bleibt immer kräftig
export function hatchRect(ctx, x, y, w, h, color, s, tint, a = 0.4) {
  ctx.save();
  ctx.beginPath();
  ctx.rect(x, y, w, h);
  ctx.clip();
  if (tint) {
    ctx.globalAlpha = 0.25 * a;
    ctx.fillStyle = color;
    ctx.fillRect(x, y, w, h);
  }
  const step = Math.max(6, 16 * s);
  const lines = () => {
    ctx.beginPath();
    for (let d = -h; d < w; d += step) {
      ctx.moveTo(x + d, y + h);
      ctx.lineTo(x + d + h, y);
    }
    ctx.stroke();
  };
  ctx.globalAlpha = Math.min(1, 0.2 + 0.6 * a);
  ctx.strokeStyle = '#fff';
  ctx.lineWidth = 3.2 * s;
  lines();
  ctx.globalAlpha = Math.min(1, 0.3 + a);
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.8 * s;
  lines();
  ctx.globalAlpha = 1;
  // innerhalb des Teamrands, damit beide Ränder sichtbar bleiben
  outlineRect(ctx, x, y, w, h, color, s, 3, tint ? 0 : 4.5);
  ctx.restore();
}

function visibleRange(grid, view) {
  if (!view) return { c0: 0, c1: grid.cols - 1, r0: 0, r1: grid.rows - 1 };
  return {
    c0: Math.max(0, Math.floor((view.west - grid.originLon) / grid.dLon)),
    c1: Math.min(grid.cols - 1, Math.floor((view.east - grid.originLon) / grid.dLon)),
    r0: Math.max(0, Math.floor((grid.originLat - view.north) / grid.dLat)),
    r1: Math.min(grid.rows - 1, Math.floor((grid.originLat - view.south) / grid.dLat)),
  };
}

function drawGrid(ctx, toPx, state, grid, opt, s) {
  const v = visibleRange(grid, opt.view);
  if (v.c0 > v.c1 || v.r0 > v.r1) return;
  const gb = gridBounds(grid);

  // Eingefärbte Felder
  for (const [key, color] of Object.entries(state.fills || {})) {
    const [c, r] = key.split(',').map(Number);
    if (c < v.c0 || c > v.c1 || r < v.r0 || r > v.r1) continue;
    const b = cellBounds(grid, c, r);
    const [x0, y0] = toPx(b.north, b.west);
    const [x1, y1] = toPx(b.south, b.east);
    ctx.globalAlpha = 0.5 * (state.markAlpha ?? 0.4);
    ctx.fillStyle = color;
    ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
    ctx.globalAlpha = 1;
    // kräftiger Rand mit weißer Kontur, damit das Feld auch auf Luftbildern auffällt
    outlineRect(ctx, x0, y0, x1 - x0, y1 - y0, color, s, 2.5);
  }

  // Status (abgesucht …) schraffiert darüber – die Teamfarbe bleibt sichtbar
  for (const [key, color] of Object.entries(state.status || {})) {
    const [c, r] = key.split(',').map(Number);
    if (c < v.c0 || c > v.c1 || r < v.r0 || r > v.r1) continue;
    const b = cellBounds(grid, c, r);
    const [x0, y0] = toPx(b.north, b.west);
    const [x1, y1] = toPx(b.south, b.east);
    hatchRect(ctx, x0, y0, x1 - x0, y1 - y0, color, s, !(state.fills && state.fills[key]), state.markAlpha ?? 0.4);
  }

  // Team-Name in der Feldmitte, Status darunter – wenn genug Platz
  const [ax] = toPx(grid.originLat, gridLon(grid, 0));
  const [bx] = toPx(grid.originLat, gridLon(grid, 1));
  const cw = Math.abs(bx - ax);
  const cellLabels = (labels, dy, bold, colorOf) => {
    if (!labels || cw < 60 * s) return;
    ctx.font = `${bold ? 'bold ' : ''}${Math.min(14, cw / (7 * s)) * s}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const [key, text] of Object.entries(labels)) {
      const [c, r] = key.split(',').map(Number);
      if (c < v.c0 || c > v.c1 || r < v.r0 || r > v.r1) continue;
      const b = cellBounds(grid, c, r);
      const [x0, y0] = toPx(b.north, b.west);
      const [x1, y1] = toPx(b.south, b.east);
      let t = text;
      while (t.length > 3 && ctx.measureText(t).width > cw - 8 * s) t = t.slice(0, -2) + '…';
      halo(ctx, t, (x0 + x1) / 2, (y0 + y1) / 2 + dy * (y1 - y0), colorOf(key), s);
    }
  };
  cellLabels(state.fillLabels, 0.04, true, () => '#111');
  cellLabels(state.statusLabels, 0.3, true, (key) => state.status[key] || '#111');

  // Linien
  const top = gridLat(grid, v.r0);
  const bottom = gridLat(grid, v.r1 + 1);
  const left = gridLon(grid, v.c0);
  const right = gridLon(grid, v.c1 + 1);
  ctx.strokeStyle = GRID_COLOR;
  ctx.lineWidth = 1.2 * s;
  ctx.beginPath();
  for (let c = v.c0; c <= v.c1 + 1; c++) {
    const [x, y0] = toPx(top, gridLon(grid, c));
    const [, y1] = toPx(bottom, gridLon(grid, c));
    ctx.moveTo(x, y0);
    ctx.lineTo(x, y1);
  }
  for (let r = v.r0; r <= v.r1 + 1; r++) {
    const [x0, y] = toPx(gridLat(grid, r), left);
    const [x1] = toPx(gridLat(grid, r), right);
    ctx.moveTo(x0, y);
    ctx.lineTo(x1, y);
  }
  ctx.stroke();

  // Außenrahmen kräftiger
  const [ox0, oy0] = toPx(gb.north, gb.west);
  const [ox1, oy1] = toPx(gb.south, gb.east);
  ctx.lineWidth = 3 * s;
  ctx.strokeRect(ox0, oy0, ox1 - ox0, oy1 - oy0);

  // Blattumrisse (nur Übersicht im PDF)
  if (opt.sheets) {
    ctx.setLineDash([8 * s, 5 * s]);
    ctx.strokeStyle = 'rgba(0, 0, 160, 0.9)';
    ctx.lineWidth = 2.5 * s;
    ctx.font = `bold ${13 * s}px sans-serif`;
    ctx.textAlign = 'right';
    ctx.textBaseline = 'bottom';
    for (const sh of opt.sheets) {
      const a = cellBounds(grid, sh.c0, sh.r0);
      const b = cellBounds(grid, sh.c1, sh.r1);
      const [x0, y0] = toPx(a.north, a.west);
      const [x1, y1] = toPx(b.south, b.east);
      ctx.strokeRect(x0, y0, x1 - x0, y1 - y0);
      ctx.setLineDash([]);
      halo(ctx, `Blatt ${sh.page}`, x1 - 4 * s, y1 - 3 * s, '#00008c', s);
      ctx.setLineDash([8 * s, 5 * s]);
    }
    ctx.setLineDash([]);
  }

  // Feldbeschriftung in jeder Zelle (oben links), wenn genug Platz
  const [cx0] = toPx(top, gridLon(grid, 0));
  const [cx1] = toPx(top, gridLon(grid, 1));
  const cellPx = Math.abs(cx1 - cx0);
  if (cellPx >= 30 * s) {
    const fs = Math.min(15, Math.max(10, cellPx / (6 * s))) * s;
    ctx.font = `bold ${fs}px sans-serif`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    for (let r = v.r0; r <= v.r1; r++) {
      for (let c = v.c0; c <= v.c1; c++) {
        const [x, y] = toPx(gridLat(grid, r), gridLon(grid, c));
        halo(ctx, cellLabel(c, r), x + 3 * s, y + 3 * s, '#a00000', s);
      }
    }
  }
}

// Spaltenbuchstaben und Zeilennummern am Rand des sichtbaren Bereichs
function drawEdgeLabels(ctx, toPx, grid, opt, s) {
  const v = visibleRange(grid, opt.view);
  if (v.c0 > v.c1 || v.r0 > v.r1) return;
  const gb = gridBounds(grid);
  const [gx0, gy0] = toPx(gb.north, gb.west);
  const [gx1, gy1] = toPx(gb.south, gb.east);
  const W = opt.width;
  const H = opt.height;
  const pad = 10 * s;
  ctx.font = `bold ${11 * s}px sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  const [ax] = toPx(gb.north, gridLon(grid, 0));
  const [bx] = toPx(gb.north, gridLon(grid, 1));
  const colPx = Math.abs(bx - ax);
  const [, ay] = toPx(gridLat(grid, 0), gb.west);
  const [, by] = toPx(gridLat(grid, 1), gb.west);
  const rowPx = Math.abs(by - ay);

  // Außerhalb des Rasterrahmens, wenn dort Platz ist – sonst am Bildrand
  const out = 12 * s;
  const yTop = gy0 - out > 0 ? gy0 - out : Math.max(gy0, 0) + pad;
  const yBot = gy1 + out < H ? gy1 + out : Math.min(gy1, H) - pad;
  const xLeft = gx0 - out - 4 * s > 0 ? gx0 - out - 4 * s : Math.max(gx0, 0) + pad + 4 * s;
  const xRight = gx1 + out + 4 * s < W ? gx1 + out + 4 * s : Math.min(gx1, W) - pad - 4 * s;
  const everyC = Math.max(1, Math.ceil((24 * s) / colPx));
  const everyR = Math.max(1, Math.ceil((20 * s) / rowPx));

  for (let c = v.c0; c <= v.c1; c++) {
    if (c % everyC) continue;
    const [x0] = toPx(gb.north, gridLon(grid, c));
    const [x1] = toPx(gb.north, gridLon(grid, c + 1));
    const cx = (x0 + x1) / 2;
    if (cx < 0 || cx > W) continue;
    pill(ctx, colName(c), cx, yTop, s);
    if (opt.allEdges) pill(ctx, colName(c), cx, yBot, s);
  }
  for (let r = v.r0; r <= v.r1; r++) {
    if (r % everyR) continue;
    const [, y0] = toPx(gridLat(grid, r), gb.west);
    const [, y1] = toPx(gridLat(grid, r + 1), gb.west);
    const cy = (y0 + y1) / 2;
    if (cy < 0 || cy > H) continue;
    pill(ctx, String(r + 1), xLeft, cy, s);
    if (opt.allEdges) pill(ctx, String(r + 1), xRight, cy, s);
  }
}

function gridLat(grid, r) {
  return grid.originLat - r * grid.dLat;
}

function gridLon(grid, c) {
  return grid.originLon + c * grid.dLon;
}

function drawItems(ctx, toPx, items, s) {
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  const named = new Set(); // Zeichnung aus mehreren Strichen: Name nur am ersten
  for (const it of items) {
    if (it.kind === 'stroke' && it.pts.length) {
      ctx.strokeStyle = it.color;
      ctx.lineWidth = it.w * s;
      ctx.beginPath();
      it.pts.forEach(([lat, lon], i) => {
        const [x, y] = toPx(lat, lon);
        if (i) ctx.lineTo(x, y);
        else ctx.moveTo(x, y);
      });
      if (it.pts.length === 1) {
        const [x, y] = toPx(it.pts[0][0], it.pts[0][1]);
        ctx.lineTo(x + 0.1, y);
      }
      ctx.stroke();
      if (it.name && !(it.group && named.has(it.group))) {
        if (it.group) named.add(it.group);
        // Name am Anfang der Zeichnung, wie bei Tracks
        const [x, y] = toPx(it.pts[0][0], it.pts[0][1]);
        ctx.font = `bold ${13 * s}px sans-serif`;
        ctx.textAlign = 'left';
        ctx.textBaseline = 'bottom';
        halo(ctx, it.name, x + (it.w / 2 + 5) * s, y - (it.w / 2 + 3) * s, it.color, s);
      }
    } else if (it.kind === 'track' && it.pts.length) {
      drawTrack(ctx, toPx, it, s);
    } else if (it.kind === 'text') {
      const [x, y] = toPx(it.lat, it.lon);
      ctx.fillStyle = it.color;
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 2 * s;
      ctx.beginPath();
      ctx.arc(x, y, 5 * s, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.font = `bold ${15 * s}px sans-serif`;
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      halo(ctx, it.text, x + 9 * s, y, it.color, s);
    }
  }
}

// Track (Punkt für Punkt gesetzt): Linie mit weißem Rand, Knotenpunkte, Name am Start
function drawTrack(ctx, toPx, it, s) {
  const pts = it.pts.map(([lat, lon]) => toPx(lat, lon));
  const line = (w, color) => {
    ctx.strokeStyle = color;
    ctx.lineWidth = w;
    ctx.beginPath();
    pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
    ctx.stroke();
  };
  line((it.w + 3) * s, 'rgba(255,255,255,0.9)');
  line(it.w * s, it.color);
  // ab 3 Punkten gestrichelt zurück zum Start: so wird die Fläche berechnet
  const [a, z] = [pts[0], pts[pts.length - 1]];
  if (hasArea(it) && Math.hypot(a[0] - z[0], a[1] - z[1]) > 1) {
    ctx.save();
    ctx.setLineDash([6 * s, 5 * s]);
    ctx.strokeStyle = it.color;
    ctx.lineWidth = Math.max(1.5, it.w * 0.6) * s;
    ctx.beginPath();
    ctx.moveTo(z[0], z[1]);
    ctx.lineTo(a[0], a[1]);
    ctx.stroke();
    ctx.restore();
  }
  ctx.fillStyle = '#fff';
  ctx.strokeStyle = it.color;
  ctx.lineWidth = 2 * s;
  // aufgezeichnete Wege (viele Punkte): nur Anfang und Ende markieren
  const many = pts.length > 150;
  pts.forEach(([x, y], i) => {
    const end = i === 0 || i === pts.length - 1;
    if (many && !end) return;
    ctx.beginPath();
    ctx.arc(x, y, (end ? 5 : 3) * s, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  });
  // Name und Fläche (ab 3 Punkten) am Startpunkt
  const label = [it.name, hasArea(it) ? formatArea(polygonArea(it.pts)) : ''].filter(Boolean).join(' · ');
  if (label) {
    ctx.font = `bold ${13 * s}px sans-serif`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'bottom';
    halo(ctx, label, pts[0][0] + 7 * s, pts[0][1] - 5 * s, it.color, s);
  }
}

// Abstand Punkt–Strecke in Pixeln (für den Radierer)
export function distToSegment(px, py, ax, ay, bx, by) {
  const dx = bx - ax;
  const dy = by - ay;
  const len = dx * dx + dy * dy;
  let t = len ? ((px - ax) * dx + (py - ay) * dy) / len : 0;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

export function hitItem(items, toPx, x, y, tol) {
  for (let i = items.length - 1; i >= 0; i--) {
    const it = items[i];
    if (it.hidden) continue; // ausgeblendet: nicht radieren/benennen
    if (it.kind === 'text') {
      const [px, py] = toPx(it.lat, it.lon);
      if (Math.hypot(px - x, py - y) <= tol + 6) return i;
    } else if (it.kind === 'stroke' || it.kind === 'track') {
      const pts = it.pts.map(([lat, lon]) => toPx(lat, lon));
      for (let k = 0; k < pts.length; k++) {
        const a = pts[k];
        const b = pts[Math.min(k + 1, pts.length - 1)];
        if (distToSegment(x, y, a[0], a[1], b[0], b[1]) <= tol + it.w / 2) return i;
      }
    }
  }
  return -1;
}

function drawMeet(ctx, toPx, m, s) {
  const [x, y] = toPx(m.lat, m.lon);
  const r = 11 * s;
  ctx.fillStyle = '#0d47a1';
  ctx.strokeStyle = '#fff';
  ctx.lineWidth = 2.5 * s;
  ctx.beginPath();
  ctx.rect(x - r, y - r, 2 * r, 2 * r);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#fff';
  ctx.font = `bold ${10 * s}px sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('TP', x, y + 0.5 * s);
  if (m.text) {
    ctx.font = `bold ${14 * s}px sans-serif`;
    ctx.textAlign = 'left';
    halo(ctx, m.text, x + r + 5 * s, y, '#0d47a1', s);
  }
}

const UTM_COLOR = 'rgba(13, 71, 161, 0.75)';
const UTM_STEPS = [100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000];

function utmText(v, step) {
  // Kilometerwert, bei Abständen < 1 km mit einer Nachkommastelle
  const km = v / 1000;
  return step < 1000 ? km.toLocaleString('de-DE', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) : String(Math.round(km));
}

// UTM-Gitter (Zone der Kartenmitte) mit Beschriftung unten und rechts
function drawUtm(ctx, toPx, opt, s) {
  const v = opt.view;
  const W = opt.width;
  const H = opt.height;
  const midLat = (v.north + v.south) / 2;
  const midLon = (v.west + v.east) / 2;
  const zone = utmZone(midLat, midLon);
  const corners = [[v.north, v.west], [v.north, v.east], [v.south, v.west], [v.south, v.east], [v.north, midLon], [v.south, midLon]]
    .map(([la, lo]) => toUtm(la, lo, zone));
  const south = midLat < 0;
  const minE = Math.min(...corners.map((u) => u.easting));
  const maxE = Math.max(...corners.map((u) => u.easting));
  const minN = Math.min(...corners.map((u) => u.northing));
  const maxN = Math.max(...corners.map((u) => u.northing));
  const pxPerM = W / Math.max(1, maxE - minE);
  const step = UTM_STEPS.find((st) => st * pxPerM >= 70 * s) || UTM_STEPS[UTM_STEPS.length - 1];
  const px = (e, n) => {
    const p = fromUtm(zone, e, n, south);
    return toPx(p.lat, p.lon);
  };
  const SEG = 8;
  ctx.strokeStyle = UTM_COLOR;
  ctx.lineWidth = 1 * s;
  ctx.setLineDash([6 * s, 4 * s]);
  ctx.beginPath();
  const e0 = Math.ceil(minE / step) * step;
  const n0 = Math.ceil(minN / step) * step;
  for (let e = e0; e <= maxE; e += step) {
    for (let i = 0; i <= SEG; i++) {
      const [x, y] = px(e, minN + ((maxN - minN) * i) / SEG);
      if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y);
    }
  }
  for (let n = n0; n <= maxN; n += step) {
    for (let i = 0; i <= SEG; i++) {
      const [x, y] = px(minE + ((maxE - minE) * i) / SEG, n);
      if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y);
    }
  }
  ctx.stroke();
  ctx.setLineDash([]);

  ctx.font = `bold ${10 * s}px sans-serif`;
  ctx.textBaseline = 'bottom';
  const lbl = (t, x, y, align) => {
    ctx.textAlign = align;
    halo(ctx, t, x, y, '#0d47a1', s);
  };
  const bottomY = H - 3 * s;
  const southCenterN = toUtm(v.south, midLon, zone).northing;
  for (let e = e0; e <= maxE; e += step) {
    const [x] = px(e, southCenterN);
    if (x > 30 * s && x < W - 30 * s) lbl(utmText(e, step), x + 2 * s, bottomY, 'left');
  }
  const eastCenterE = toUtm(midLat, v.east, zone).easting;
  for (let n = n0; n <= maxN; n += step) {
    const [, y] = px(eastCenterE, n);
    if (y > 20 * s && y < H - 20 * s) lbl(utmText(n, step), W - 4 * s, y - 2 * s, 'right');
  }
}
