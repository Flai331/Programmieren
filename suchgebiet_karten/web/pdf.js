// PDF-Erstellung: Kartenkacheln + Raster + Zeichnungen werden pro Blatt auf ein
// Canvas gerendert und als Bild ins PDF gesetzt. Übersicht und Detailblätter
// nutzen dasselbe Raster, daher stimmt "A1" überall überein.

import {
  blocks, gridBounds, rangeBounds, rangeLabel, fitBox,
  mercLat, mercLon, mercX, mercY, metersPerUnit, niceScale, niceLength, formatMeters,
} from './grid.js';
import { drawOverlay } from './render.js';
import { tileUrl } from './layers.js';

export const PAGES = { A4: [297, 210], A3: [420, 297] };
const MARGIN = 8;
const HEADER = 15;
const FOOTER = 11;
const MAX_TILES = 300;

export function pageSize(format, orient) {
  const [a, b] = PAGES[format] || PAGES.A4;
  return orient === 'portrait' ? [b, a] : [a, b];
}

export function mapArea(format, orient) {
  const [W, H] = pageSize(format, orient);
  return { x: MARGIN, y: MARGIN + HEADER, w: W - 2 * MARGIN, h: H - 2 * MARGIN - HEADER - FOOTER };
}

// Welche Blätter kommen ins PDF?
// opts: { overview, view, details, k }
export function planSheets(state, opts, viewBounds) {
  const sheets = [];
  const grid = state.grid;
  const detail = grid && opts.details ? blocks(grid, opts.k || 3) : [];
  let page = 1;
  if (grid && opts.overview) {
    const gb = gridBounds(grid);
    sheets.push({
      title: `Übersicht – Felder ${rangeLabel(0, 0, grid.cols - 1, grid.rows - 1)}`,
      bounds: gb,
      pad: 0.04,
      outlines: detail.length > 1 ? detail.map((d, i) => ({ ...d, page: page + 1 + i })) : null,
    });
    page++;
  }
  if (detail.length > 1 || (detail.length === 1 && !opts.overview)) {
    for (const d of detail) {
      sheets.push({
        title: `Blatt ${page} – Felder ${d.label}`,
        bounds: rangeBounds(grid, d.c0, d.r0, d.c1, d.r1),
        pad: 0.06,
        focus: true,
      });
      page++;
    }
  }
  if (opts.view && viewBounds) {
    sheets.push({ title: 'Kartenausschnitt', bounds: viewBounds, pad: 0 });
  }
  return sheets;
}

function loadImage(url) {
  return new Promise((resolve) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    const timer = setTimeout(() => resolve(null), 20000);
    img.onload = () => { clearTimeout(timer); resolve(img); };
    img.onerror = () => { clearTimeout(timer); resolve(null); };
    img.src = url;
  });
}

async function loadAll(urls, limit) {
  const out = new Array(urls.length);
  let next = 0;
  async function worker() {
    while (next < urls.length) {
      const i = next++;
      out[i] = await loadImage(urls[i]);
    }
  }
  await Promise.all(Array.from({ length: limit }, worker));
  return out;
}

// Rendert ein Kartenblatt; Wpx/Hpx = Canvasgröße, mmW = Breite auf Papier
export async function renderSheet(state, sheet, layer, Wpx, Hpx, mmW) {
  const box = fitBox(sheet.bounds, Wpx / Hpx, sheet.pad);
  const w0 = box.x1 - box.x0;
  let z = Math.max(0, Math.min(layer.maxNative, Math.ceil(Math.log2(Wpx / w0))));
  const tileRange = (zz) => {
    const n = 2 ** zz / 256;
    return {
      tx0: Math.floor(box.x0 * n), tx1: Math.floor(box.x1 * n),
      ty0: Math.max(0, Math.floor(box.y0 * n)), ty1: Math.min(2 ** zz - 1, Math.floor(box.y1 * n)),
    };
  };
  let tr = tileRange(z);
  while (z > 0 && (tr.tx1 - tr.tx0 + 1) * (tr.ty1 - tr.ty0 + 1) > MAX_TILES) tr = tileRange(--z);

  const canvas = document.createElement('canvas');
  canvas.width = Wpx;
  canvas.height = Hpx;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#eee';
  ctx.fillRect(0, 0, Wpx, Hpx);

  const k = Wpx / (w0 * 2 ** z); // Canvas-px pro Kachel-px
  const list = [];
  for (let ty = tr.ty0; ty <= tr.ty1; ty++) {
    for (let tx = tr.tx0; tx <= tr.tx1; tx++) list.push({ tx, ty, url: tileUrl(layer, z, tx, ty) });
  }
  const imgs = await loadAll(list.map((t) => t.url), 8);
  let missing = 0;
  list.forEach((t, i) => {
    const img = imgs[i];
    const x = (t.tx * 256 - box.x0 * 2 ** z) * k;
    const y = (t.ty * 256 - box.y0 * 2 ** z) * k;
    if (img) ctx.drawImage(img, Math.floor(x), Math.floor(y), Math.ceil(256 * k) + 1, Math.ceil(256 * k) + 1);
    else missing++;
  });

  const sx = Wpx / w0;
  const sy = Hpx / (box.y1 - box.y0);
  const toPx = (lat, lon) => [(mercX(lon) - box.x0) * sx, (mercY(lat) - box.y0) * sy];
  const pxPerMm = Wpx / mmW;
  const s = pxPerMm * 0.3;
  const view = { north: mercLat(box.y0), south: mercLat(box.y1), west: mercLon(box.x0), east: mercLon(box.x1) };
  drawOverlay(ctx, toPx, state, { s, width: Wpx, height: Hpx, view, allEdges: true, sheets: sheet.outlines, focus: sheet.focus ? sheet.bounds : null });

  // Maßstab
  const midLat = (view.north + view.south) / 2;
  const mPerPx = (metersPerUnit(midLat) * w0) / Wpx;
  const scale = niceScale((mPerPx * pxPerMm) * 1000);
  const barM = niceLength(mPerPx * Wpx * 0.2);
  const barPx = barM / mPerPx;
  drawScaleBar(ctx, barPx, formatMeters(barM), s, Hpx);
  drawNorth(ctx, Wpx, s);
  return { canvas, scale, missing, tiles: list.length };
}

function drawScaleBar(ctx, barPx, label, s, H) {
  const x = 14 * s;
  const y = H - 16 * s;
  ctx.fillStyle = 'rgba(255,255,255,0.85)';
  ctx.fillRect(x - 6 * s, y - 22 * s, barPx + 12 * s, 32 * s);
  ctx.fillStyle = '#000';
  ctx.fillRect(x, y, barPx / 2, 5 * s);
  ctx.strokeStyle = '#000';
  ctx.lineWidth = 1.2 * s;
  ctx.strokeRect(x, y, barPx, 5 * s);
  ctx.font = `bold ${11 * s}px sans-serif`;
  ctx.textAlign = 'left';
  ctx.textBaseline = 'bottom';
  ctx.fillText('0', x, y - 3 * s);
  ctx.textAlign = 'right';
  ctx.fillText(label, x + barPx, y - 3 * s);
}

function drawNorth(ctx, W, s) {
  const x = W - 50 * s;
  const y = 50 * s;
  ctx.fillStyle = 'rgba(255,255,255,0.85)';
  ctx.beginPath();
  ctx.arc(x, y, 20 * s, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#000';
  ctx.beginPath();
  ctx.moveTo(x, y - 15 * s);
  ctx.lineTo(x + 7 * s, y + 9 * s);
  ctx.lineTo(x, y + 4 * s);
  ctx.lineTo(x - 7 * s, y + 9 * s);
  ctx.closePath();
  ctx.fill();
  ctx.font = `bold ${10 * s}px sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  ctx.fillText('N', x, y + 9 * s);
}

// opts: { format, orient, overview, view, details, k, title, dpi }
export async function buildPdf(state, opts, layer, viewBounds, onProgress) {
  const { jsPDF } = window.jspdf;
  const [W, H] = pageSize(opts.format, opts.orient);
  const area = mapArea(opts.format, opts.orient);
  const dpi = opts.dpi || 150;
  const Wpx = Math.round((area.w / 25.4) * dpi);
  const Hpx = Math.round((area.h / 25.4) * dpi);
  const sheets = planSheets(state, opts, viewBounds);
  if (!sheets.length) throw new Error('Keine Blätter ausgewählt.');

  const doc = new jsPDF({ orientation: opts.orient, unit: 'mm', format: opts.format.toLowerCase() });
  const date = new Date().toLocaleString('de-DE', { dateStyle: 'medium', timeStyle: 'short' });
  const grid = state.grid;
  let missing = 0;

  for (let i = 0; i < sheets.length; i++) {
    onProgress && onProgress(i + 1, sheets.length);
    const sh = sheets[i];
    const r = await renderSheet(state, sh, layer, Wpx, Hpx, area.w);
    missing += r.missing;
    if (i) doc.addPage();

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(15);
    doc.text(opts.title || 'Suchgebiet', MARGIN, MARGIN + 6);
    doc.setFontSize(11);
    doc.text(sh.title, MARGIN, MARGIN + 12);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.text(date, W - MARGIN, MARGIN + 6, { align: 'right' });
    doc.text(`Seite ${i + 1} von ${sheets.length}`, W - MARGIN, MARGIN + 12, { align: 'right' });

    doc.addImage(r.canvas.toDataURL('image/jpeg', 0.85), 'JPEG', area.x, area.y, area.w, area.h);
    doc.setDrawColor(0);
    doc.setLineWidth(0.3);
    doc.rect(area.x, area.y, area.w, area.h);

    const info = [`Maßstab ca. 1:${r.scale.toLocaleString('de-DE')} (bei Druck ${opts.format})`];
    if (grid) info.push(`Raster ${formatMeters(grid.cellM)} × ${formatMeters(grid.cellM)}, Ursprung A1 = NW-Ecke (${grid.originLat.toFixed(5)}, ${grid.originLon.toFixed(5)})`);
    doc.setFontSize(8.5);
    doc.text(info.join('   ·   '), MARGIN, H - MARGIN - 5);
    doc.setFontSize(7.5);
    doc.setTextColor(90);
    doc.text(`Kartengrundlage: ${layer.attribution}`, MARGIN, H - MARGIN - 1);
    doc.setTextColor(0);
  }
  return { blob: doc.output('blob'), pages: sheets.length, missing };
}

