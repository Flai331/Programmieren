// Zeichnet Raster, eingefärbte Felder und Zeichnungen auf ein Canvas.
// Wird für die Bildschirmanzeige UND für das PDF benutzt – so sehen beide
// gleich aus. toPx(lat, lon) -> [x, y] rechnet in Canvas-Pixel um.

import { colName, cellLabel, cellBounds, gridBounds } from './grid.js';

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
//        focus: Bereich des Detailblatts (Rest wird aufgehellt) }
export function drawOverlay(ctx, toPx, state, opt) {
  const s = opt.s || 1;
  const grid = state.grid;
  if (opt.focus) dimOutside(ctx, toPx, opt.focus, opt.width, opt.height);
  if (grid) drawGrid(ctx, toPx, state, grid, opt, s);
  drawItems(ctx, toPx, state.items || [], s);
  if (grid) drawEdgeLabels(ctx, toPx, grid, opt, s);
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
    ctx.globalAlpha = 0.35;
    ctx.fillStyle = color;
    ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
    ctx.globalAlpha = 1;
  }

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
    if (it.kind === 'text') {
      const [px, py] = toPx(it.lat, it.lon);
      if (Math.hypot(px - x, py - y) <= tol + 6) return i;
    } else if (it.kind === 'stroke') {
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
