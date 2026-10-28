// PDF-Erstellung: Kartenkacheln + Raster + Zeichnungen werden pro Blatt auf ein
// Canvas gerendert und als Bild ins PDF gesetzt. Übersicht und Detailblätter
// nutzen dasselbe Raster, daher stimmt "A1" überall überein.

import { addReportPages, forceLine, lineLegend, totalLine } from './mission.js';
import {
  blocks, gridBounds, rangeBounds, rangeLabel, fitBox,
  mercLat, mercLon, mercX, mercY, metersPerUnit, niceScale, niceLength, formatMeters,
} from './grid.js';
import { drawOverlay, hatchRect } from './render.js';
import { tileUrl } from './layers.js';
import { formatMgrs, formatUtm, utmZone } from './utm.js';
import {
  assignments, embedMarker, markLabel, resolveFills, teamStatus,
} from './store.js';

export const PAGES = { A4: [297, 210], A3: [420, 297] };
const MARGIN = 8;
const HEADER = 15;
const FOOTER = 14;
const MAX_TILES = 300;

// „Automatisch“: hoch oder quer, je nachdem, wie die erste Karte geformt ist
export function resolveOrient(orient, sheets) {
  if (orient !== 'auto') return orient;
  const first = sheets.find((sh) => !sh.info);
  if (!first) return 'landscape';
  const b = first.bounds;
  const w = mercX(b.east) - mercX(b.west);
  const h = mercY(b.south) - mercY(b.north);
  // Kartenfläche A4/A3: quer ca. 1,69 : 1, hoch ca. 0,77 : 1. Ab ca. 1,17 : 1
  // wird die Karte im Querformat größer als im Hochformat.
  return w / h >= 1.17 ? 'landscape' : 'portrait';
}

export function pageSize(format, orient) {
  const [a, b] = PAGES[format] || PAGES.A4;
  return orient === 'portrait' ? [b, a] : [a, b];
}

export function mapArea(format, orient) {
  const [W, H] = pageSize(format, orient);
  return { x: MARGIN, y: MARGIN + HEADER, w: W - 2 * MARGIN, h: H - 2 * MARGIN - HEADER - FOOTER };
}

// Welche Blätter kommen ins PDF?
// opts: { overview, view, details, k, info }
export function planSheets(grid, opts, viewBounds) {
  const sheets = [];
  const detail = grid && opts.details ? blocks(grid, opts.k || 3) : [];
  const useDetail = detail.length > 1 || (detail.length === 1 && !opts.overview);
  let page = 1;
  const overview = grid && opts.overview;
  // Seitenzahlen der Detailblätter vorab berechnen (Übersicht zeigt sie an)
  const firstDetail = 1 + (overview ? 1 : 0) + (opts.info ? 1 : 0);
  if (overview) {
    sheets.push({
      title: `Übersicht – Felder ${rangeLabel(0, 0, grid.cols - 1, grid.rows - 1)}`,
      bounds: gridBounds(grid),
      pad: 0.04,
      outlines: useDetail && detail.length > 1 ? detail.map((d, i) => ({ ...d, page: firstDetail + i })) : null,
    });
    page++;
  }
  if (opts.info) {
    sheets.push({ info: true, title: 'Einsatzinformationen' });
    page++;
  }
  if (useDetail) {
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
  return sheets.some((sh) => !sh.info) ? sheets : sheets.filter((sh) => !sh.info);
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

// Zeichnet die Kacheln eines Dienstes in den Ausschnitt box (Mercator-Einheiten).
// Gibt die Zahl fehlender Kacheln zurück.
async function drawLayerTiles(ctx, def, box, Wpx, zWanted, maxTiles) {
  const w0 = box.x1 - box.x0;
  // Große Kacheln (512 px) decken dieselbe Fläche ab wie 256er eine Stufe höher
  const off = Math.log2((def.tileSize || 256) / 256);
  let z = Math.max(0, Math.min(def.maxNative, zWanted) - off);
  const tileRange = (zz) => {
    const n = 2 ** zz / 256;
    return {
      tx0: Math.floor(box.x0 * n), tx1: Math.floor(box.x1 * n),
      ty0: Math.max(0, Math.floor(box.y0 * n)), ty1: Math.min(2 ** zz - 1, Math.floor(box.y1 * n)),
    };
  };
  let tr = tileRange(z);
  while (z > 0 && (tr.tx1 - tr.tx0 + 1) * (tr.ty1 - tr.ty0 + 1) > maxTiles) tr = tileRange(--z);

  const k = Wpx / (w0 * 2 ** z); // Canvas-px pro Kachel-px
  const list = [];
  for (let ty = tr.ty0; ty <= tr.ty1; ty++) {
    for (let tx = tr.tx0; tx <= tr.tx1; tx++) list.push({ tx, ty, url: tileUrl(def, z, tx, ty) });
  }
  const imgs = await loadAll(list.map((t) => t.url), 8);
  let missing = 0;
  // Ebenen wie „Wege über Luftbild“ werden multipliziert (Weiß wird durchsichtig)
  ctx.save();
  ctx.globalAlpha = def.opacity ?? 1;
  ctx.globalCompositeOperation = def.blend || 'source-over';
  list.forEach((t, i) => {
    const img = imgs[i];
    const x = (t.tx * 256 - box.x0 * 2 ** z) * k;
    const y = (t.ty * 256 - box.y0 * 2 ** z) * k;
    if (img) ctx.drawImage(img, Math.floor(x), Math.floor(y), Math.ceil(256 * k) + 1, Math.ceil(256 * k) + 1);
    else missing++;
  });
  ctx.restore();
  return { missing, tiles: list.length };
}

// Rendert ein Kartenblatt; Wpx/Hpx = Canvasgröße, mmW = Breite auf Papier.
// layer.overlays (z. B. Straßen, Wanderwege) werden über die Grundkarte gelegt.
export async function renderSheet(state, sheet, layer, Wpx, Hpx, mmW, extra = {}) {
  const box = fitBox(sheet.bounds, Wpx / Hpx, sheet.pad);
  const w0 = box.x1 - box.x0;
  const zWanted = Math.ceil(Math.log2(Wpx / w0));
  const maxTiles = extra.maxTiles || MAX_TILES;

  const canvas = document.createElement('canvas');
  canvas.width = Wpx;
  canvas.height = Hpx;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#eee';
  ctx.fillRect(0, 0, Wpx, Hpx);

  const base = await drawLayerTiles(ctx, layer, box, Wpx, zWanted, maxTiles);
  const { missing } = base;
  for (const ov of layer.overlays || []) {
    // fehlende Overlay-Kacheln (z. B. keine Wanderwege) sind normal und zählen nicht
    await drawLayerTiles(ctx, ov, box, Wpx, zWanted, maxTiles);
  }

  const sx = Wpx / w0;
  const sy = Hpx / (box.y1 - box.y0);
  const toPx = (lat, lon) => [(mercX(lon) - box.x0) * sx, (mercY(lat) - box.y0) * sy];
  const pxPerMm = Wpx / mmW;
  const s = pxPerMm * 0.3;
  const view = { north: mercLat(box.y0), south: mercLat(box.y1), west: mercLon(box.x0), east: mercLon(box.x1) };
  drawOverlay(ctx, toPx, state, {
    s, width: Wpx, height: Hpx, view, allEdges: true, sheets: sheet.outlines, focus: sheet.focus ? sheet.bounds : null, utm: extra.utm,
  });

  // Maßstab
  const midLat = (view.north + view.south) / 2;
  const mPerPx = (metersPerUnit(midLat) * w0) / Wpx;
  const scale = niceScale((mPerPx * pxPerMm) * 1000);
  const barM = niceLength(mPerPx * Wpx * 0.2);
  const barPx = barM / mPerPx;
  if (!extra.bare) {
    drawScaleBar(ctx, barPx, formatMeters(barM), s, Hpx);
    drawNorth(ctx, Wpx, s);
    if (extra.legend && extra.legend.length) drawLegend(ctx, extra.legend, s, Wpx, Hpx, extra.utm);
  }
  return { canvas, scale, missing, tiles: base.tiles, box };
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

function drawLegend(ctx, entries, s, W, H, utm) {
  ctx.font = `${11 * s}px sans-serif`;
  const lineH = 17 * s;
  const w = Math.max(...entries.map((e) => ctx.measureText(e.label).width)) + 34 * s;
  const h = entries.length * lineH + 10 * s;
  const x = W - w - (utm ? 48 : 10) * s;
  const y = H - h - (utm ? 22 : 10) * s;
  ctx.fillStyle = 'rgba(255,255,255,0.9)';
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = '#555';
  ctx.lineWidth = 1 * s;
  ctx.strokeRect(x, y, w, h);
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  entries.forEach((e, i) => {
    const cy = y + 5 * s + lineH * (i + 0.5);
    if (e.line) {
      // Zeichnungsfarbe: Linie statt Kästchen
      ctx.strokeStyle = e.color;
      ctx.lineWidth = 4 * s;
      ctx.beginPath();
      ctx.moveTo(x + 7 * s, cy);
      ctx.lineTo(x + 23 * s, cy);
      ctx.stroke();
      ctx.fillStyle = '#111';
      ctx.fillText(e.label, x + 28 * s, cy);
      return;
    }
    if (e.hatch) {
      hatchRect(ctx, x + 7 * s, cy - 6 * s, 16 * s, 12 * s, e.color, s * 0.5, true, 0.8);
    } else {
      ctx.globalAlpha = 0.6;
      ctx.fillStyle = e.color;
      ctx.fillRect(x + 7 * s, cy - 6 * s, 16 * s, 12 * s);
      ctx.globalAlpha = 1;
    }
    ctx.strokeStyle = '#555';
    ctx.lineWidth = 1 * s;
    ctx.strokeRect(x + 7 * s, cy - 6 * s, 16 * s, 12 * s);
    ctx.fillStyle = '#111';
    ctx.fillText(e.label, x + 28 * s, cy);
  });
}

function hexRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function coordText(lat, lon, utm) {
  const dec = `${lat.toFixed(5)}° N, ${lon.toFixed(5)}° E`;
  return utm ? `UTMREF ${formatMgrs(lat, lon, 5)} · UTM ${formatUtm(lat, lon)} · ${dec}` : dec;
}

// Seite mit Einsatzinformationen: Teams, Legende, Treffpunkt, Notizen
function infoPage(doc, project, grid, W, H, top) {
  let y = top;
  const x = MARGIN;
  const maxW = W - 2 * MARGIN;
  const need = (h) => {
    if (y + h > H - MARGIN) { doc.addPage(); y = MARGIN + 8; }
  };
  const heading = (t) => {
    need(12);
    y += 4;
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.text(t, x, y);
    y += 6;
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(10);
  };
  const row = (label, value) => {
    const lines = doc.splitTextToSize(value, maxW - 45);
    need(lines.length * 4.6 + 1);
    doc.setFont('helvetica', 'bold');
    doc.text(label, x, y);
    doc.setFont('helvetica', 'normal');
    doc.text(lines, x + 45, y);
    y += lines.length * 4.6 + 1;
  };
  doc.setFontSize(10);
  heading('Einsatz');
  row('Bezeichnung:', project.title || '–');
  row('Einsatzleitung/Ersteller:', project.leader || '–');
  row('Erstellt am:', new Date().toLocaleString('de-DE', { dateStyle: 'full', timeStyle: 'short' }));
  if (project.meet) {
    row('Treffpunkt:', project.meet.text || 'Treffpunkt');
    row('Koordinaten:', coordText(project.meet.lat, project.meet.lon, project.showUtm));
  }
  if (grid) {
    row('Raster:', `${grid.cols} × ${grid.rows} Felder à ${formatMeters(grid.cellM)}, A1 bis ${rangeLabel(grid.cols - 1, grid.rows - 1, grid.cols - 1, grid.rows - 1)}`);
    row('A1 (NW-Ecke):', coordText(grid.originLat, grid.originLon, project.showUtm));
  }

  const ms = project.mission;
  if (ms && ms.person.trim()) row('Vermisste Person:', ms.person.trim());
  if (ms && ms.forces.length) row('Kräfte:', [...ms.forces.map(forceLine), totalLine(ms.forces)].join('\n'));

  const as = assignments(project);
  const table = (title, list, team) => {
    if (!list.length) return;
    heading(title);
    for (const a of list) {
      const name = team ? markLabel(a.mark) : a.mark.label;
      let cells = a.count ? `${a.text}  (${a.count} Feld${a.count > 1 ? 'er' : ''})` : 'keine Felder zugeteilt';
      if (team) {
        for (const st of teamStatus(project, a.mark)) cells += `\n${st.mark.label}: ${st.text} (${st.count} von ${a.count})`;
      }
      const lines = doc.splitTextToSize(cells, maxW - 75);
      need(lines.length * 4.6 + 2);
      doc.setFillColor(...hexRgb(a.mark.color));
      doc.rect(x, y - 3.4, 5, 4, 'F');
      doc.setFont('helvetica', 'bold');
      doc.text(doc.splitTextToSize(name, 62)[0], x + 8, y);
      doc.setFont('helvetica', 'normal');
      doc.text(lines, x + 75, y);
      y += lines.length * 4.6 + 2;
    }
  };
  table('Teams', as.filter((a) => a.mark.kind === 'team'), true);
  table('Legende', as.filter((a) => a.mark.kind !== 'team' && a.count), false);

  if (project.notes && project.notes.trim()) {
    heading('Notizen');
    for (const line of doc.splitTextToSize(project.notes.trim(), maxW)) {
      need(5);
      doc.text(line, x, y);
      y += 4.6;
    }
  }
}

// Was auf die Karte gezeichnet wird (für PDF und Garmin-Karte)
export function renderState(project, grid) {
  const label = (map) => {
    const out = {};
    for (const [k, id] of Object.entries(map)) {
      const m = project.marks.find((mm) => mm.id === id);
      if (m && m.label) out[k] = m.label;
    }
    return out;
  };
  return {
    grid,
    fills: resolveFills(project),
    status: resolveFills(project, 'status'),
    markAlpha: project.markAlpha ?? 0.4,
    fillLabels: label(project.fills),
    statusLabels: label(project.status),
    items: project.items,
    meet: project.meet,
  };
}

// opts: { format, orient, overview, view, details, k, info, title, dpi }
export async function buildPdf(project, grid, opts, layer, viewBounds, onProgress) {
  const { jsPDF } = window.jspdf;
  const sheets = planSheets(grid, opts, viewBounds);
  if (!sheets.length) throw new Error('Keine Blätter ausgewählt.');
  const orient = resolveOrient(opts.orient, sheets);
  const [W, H] = pageSize(opts.format, orient);
  const doc = new jsPDF({ orientation: orient, unit: 'mm', format: opts.format.toLowerCase() });

  // Beschriftung unter der Überschrift; die Karte rückt dafür nach unten
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10);
  const caption = (project.caption || '').trim();
  const captionLines = caption ? doc.splitTextToSize(caption, W - 2 * MARGIN).slice(0, 4) : [];
  const captionH = captionLines.length ? captionLines.length * 4.3 + 2 : 0;
  const area = mapArea(opts.format, orient);
  area.y += captionH;
  area.h -= captionH;
  const dpi = opts.dpi || 150;
  const Wpx = Math.round((area.w / 25.4) * dpi);
  const Hpx = Math.round((area.h / 25.4) * dpi);

  const rstate = renderState(project, grid);
  const legend = [...assignments(project).filter((a) => a.count)
    .map((a) => ({ color: a.mark.color, label: markLabel(a.mark), hatch: a.mark.kind !== 'team' })), ...lineLegend(project)];

  // Abschlussbericht: Berichtsseiten vor der Karte
  const reportPages = opts.report ? await addReportPages(doc, project, grid, W, H, MARGIN) : 0;
  const total = reportPages + sheets.length;

  const date = new Date().toLocaleString('de-DE', { dateStyle: 'medium', timeStyle: 'short' });
  const right1 = project.leader ? `${project.leader} · ${date}` : date;
  let missing = 0;

  for (let i = 0; i < sheets.length; i++) {
    onProgress && onProgress(i + 1, sheets.length);
    const sh = sheets[i];
    if (i || reportPages) doc.addPage();

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(15);
    doc.text(opts.title || 'Suchgebiet', MARGIN, MARGIN + 6);
    doc.setFontSize(11);
    doc.text(sh.title, MARGIN, MARGIN + 12);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.text(right1, W - MARGIN, MARGIN + 6, { align: 'right' });
    doc.text(`Seite ${reportPages + i + 1} von ${total}`, W - MARGIN, MARGIN + 12, { align: 'right' });

    if (sh.info) {
      infoPage(doc, project, grid, W, H, MARGIN + HEADER + 4);
      continue;
    }

    const r = await renderSheet(rstate, sh, layer, Wpx, Hpx, area.w, { utm: project.showUtm, legend });
    missing += r.missing;
    if (captionLines.length) {
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(10);
      doc.text(captionLines, MARGIN, MARGIN + HEADER + 1.5);
    }
    doc.addImage(r.canvas.toDataURL('image/jpeg', 0.85), 'JPEG', area.x, area.y, area.w, area.h);
    doc.setDrawColor(0);
    doc.setLineWidth(0.3);
    doc.rect(area.x, area.y, area.w, area.h);

    const info = [`Maßstab ca. 1:${r.scale.toLocaleString('de-DE')} (bei Druck ${opts.format})`];
    if (grid) info.push(`Raster ${formatMeters(grid.cellM)}, A1 = NW-Ecke`);
    if (project.meet) {
      const m = project.meet;
      info.push(`TP ${m.text ? m.text + ': ' : ''}${project.showUtm ? formatMgrs(m.lat, m.lon) : `${m.lat.toFixed(5)}, ${m.lon.toFixed(5)}`}`);
    }
    if (project.showUtm) info.push(`UTM-Gitter blau, Zone ${utmZone((sh.bounds.north + sh.bounds.south) / 2, (sh.bounds.west + sh.bounds.east) / 2)}`);
    doc.setFontSize(8.5);
    // Hochformat: Fußzeile bei Bedarf zweizeilig statt abgeschnitten
    const infoLines = doc.splitTextToSize(info.join('   ·   '), W - 2 * MARGIN).slice(0, 2);
    doc.text(infoLines, MARGIN, H - MARGIN - 5 - (infoLines.length - 1) * 3.6);
    doc.setFontSize(7.5);
    doc.setTextColor(90);
    doc.text(`Kartengrundlage: ${layer.attribution}`, MARGIN, H - MARGIN - 1);
    doc.setTextColor(0);
  }
  // Suchgebiet ins PDF einbetten -> PDF kann in der App wieder geöffnet werden
  doc.addMetadata(embedMarker(project), 'https://flai331.github.io/suchgebiet-karten/');
  doc.setProperties({ title: opts.title || 'Suchgebiet', subject: 'Suchgebiet-Karte', creator: 'Suchgebiet-Karten' });
  return { blob: doc.output('blob'), pages: doc.getNumberOfPages(), missing };
}
