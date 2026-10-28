// Einsatzprotokoll (Eckdaten, kein ETB): vermisste Person, Kräfte je Organisation,
// handschriftlicher Notizblock, Fotos vom Papier, Zusammenfassung am Einsatzende,
// Kartenlegende, Verfasser und Mail-Empfänger. Gehört zum jeweiligen Suchgebiet.

export const FORCE_KEYS = [
  ['lead', 'Führung'],
  ['helpers', 'Helfer'],
  ['dogs', 'Hunde'],
  ['vehicles', 'Fahrz.'],
];

export function newMission() {
  return {
    person: '', // vermisste Person
    forces: [], // [{org, lead, helpers, dogs, vehicles, own}]
    times: {}, // Eckzeiten, siehe TIME_KEYS
    pages: [], // Notizblock: [{t, strokes: [{color, w, pts: [[x, y]]}]}], x/y in Seitenbreiten
    photos: [], // [{t, src (JPEG data URL)}]
    summary: '',
    author: '',
    recipients: '', // alt (ein Feld für alle) – wird zu mailTo umgezogen
    mailTo: [], // [{to: 'a@b.de, c@d.de', report, map, notes, gpx}] – was an wen geht
    legend: {}, // Farbe -> Bedeutung (z. B. "#d50000": "Spur Mantrailer")
  };
}

export function normalizeMission(m) {
  const base = newMission();
  const out = { ...base, ...(m && typeof m === 'object' ? m : {}) };
  for (const k of ['forces', 'pages', 'photos']) if (!Array.isArray(out[k])) out[k] = [];
  if (!out.legend || typeof out.legend !== 'object') out.legend = {};
  if (!out.times || typeof out.times !== 'object') out.times = {};
  if (!Array.isArray(out.mailTo)) out.mailTo = [];
  // Zeilen älterer Versionen (Bericht/Karte/„Notizblock + Fotos“) auf die heutigen Häkchen bringen
  out.mailTo = out.mailTo.map((r) => {
    if (!('report' in r) && !('map' in r)) return { ...newMailTo(), ...r };
    const rep = !!r.report;
    return { ...newMailTo(), to: r.to || '', person: rep, forces: rep, summary: rep, notes: rep, pad: !!r.notes, photos: !!r.notes, juh: !!r.juh, gpx: !!r.gpx };
  });
  if (!out.mailTo.length && out.recipients.trim()) {
    out.mailTo.push({ ...newMailTo(), to: out.recipients.trim() });
    out.recipients = '';
  }
  return out;
}

// Ein Empfänger (oder mehrere Adressen mit Komma) und was er bekommt
// Je Empfänger ankreuzbar: Inhalte des Abschlussberichts der App (ohne Karte)
// und zusätzliche Anhänge
export const REPORT_SECTIONS = [
  ['times', 'Zeiten'],
  ['person', 'Vermisste Person'],
  ['forces', 'Kräfte'],
  ['summary', 'Zusammenfassung'],
  ['notes', 'Notizen'],
  ['pad', 'Notizblock'],
  ['photos', 'Fotos'],
  ['map', 'Karte'],
];
// Was die Karte zeigt (nur wenn „Karte“ angekreuzt ist)
export const MAP_PARTS = [
  ['mapTeams', 'Teams'],
  ['mapStatus', 'abgesucht / teilweise / nicht begehbar'],
];
export const EXTRA_PARTS = [
  ['juh', 'JUH-Formular'],
  ['gpx', 'GPX für BaseCamp'],
];
export const MAIL_PARTS = [...REPORT_SECTIONS, ...MAP_PARTS, ...EXTRA_PARTS];
const TEXT_KEYS = ['times', 'person', 'forces', 'summary', 'notes'];
export function newMailTo() {
  return { to: '', times: true, person: true, forces: true, summary: true, notes: true, pad: true, photos: true, map: false, mapTeams: true, mapStatus: true, juh: true, gpx: false };
}
// sec: Häkchen einer Zeile (ohne Angabe: alles)
const want = (sec, k) => !sec || sec[k] !== false;
export const hasReportText = (sec) => TEXT_KEYS.some((k) => want(sec, k));
export function mailAddresses(row) {
  return String(row.to || '').split(/[,;\s]+/).map((x) => x.trim()).filter((x) => x.includes('@'));
}

const num = (v) => Math.max(0, Math.round(Number(v) || 0));

export function forceTotals(forces) {
  const t = { lead: 0, helpers: 0, dogs: 0, vehicles: 0 };
  for (const f of forces) for (const [k] of FORCE_KEYS) t[k] += num(f[k]);
  t.people = t.lead + t.helpers;
  return t;
}

// „DRK RHS Celle: 1 Führung, 6 Helfer, 4 Hunde, 2 Fahrz.“
// Stärke nur als Zahlen: Führung/Helfer//Gesamt + Hunde (+ Fahrzeuge)
export const STRENGTH_HINT = 'Führung/Helfer//Gesamt';
function strength(t) {
  let s = `${t.lead}/${t.helpers}//${t.lead + t.helpers}`;
  if (t.dogs) s += ` + ${t.dogs} Hunde`;
  if (t.vehicles) s += ` + ${t.vehicles} Fz.`;
  return s;
}
// „DRK RHS Celle: 1/6//7 + 4 Hunde“
export function forceLine(f) {
  return `${f.org || 'Organisation'}: ${strength(Object.fromEntries(FORCE_KEYS.map(([k]) => [k, num(f[k])])))}`;
}

export function totalLine(forces) {
  return `Gesamt: ${strength(forceTotals(forces))}`;
}

// Eckzeiten: Uhrzeit „HH:MM“ (Alarmierung zusätzlich mit Datum „JJJJ-MM-TT“)
export const TIME_KEYS = [
  ['alarm', 'Alarmierung'],
  ['depart', 'Abfahrt Wache'],
  ['arrive', 'Eintreffen Einsatzstelle'],
  ['start', 'Einsatzbeginn'],
  ['end', 'Einsatzende'],
  ['back', 'Rückkehr Unterkunft'],
];
export function timeLines(m) {
  const t = m.times || {};
  return TIME_KEYS.filter(([k]) => t[k]).map(([k, l]) => {
    const d = k === 'alarm' && t.alarmDate ? `${t.alarmDate.split('-').reverse().join('.')} ` : '';
    return `${l}: ${d}${t[k]} Uhr`;
  });
}
// Dauer in Stunden (Alarmierung bis Rückkehr, sonst bis Einsatzende); über Mitternacht +24 h
export function missionHours(m) {
  const t = m.times || {};
  const to = t.back || t.end;
  if (!t.alarm || !to) return 0;
  const min = (x) => { const [h, mm] = x.split(':').map(Number); return h * 60 + mm; };
  let d = min(to) - min(t.alarm);
  if (d < 0) d += 24 * 60;
  return d / 60;
}

// Farben der Zeichnungen und Tracks, die auf der Karte vorkommen (für die Legende)
export function usedColors(project) {
  const seen = [];
  for (const it of project.items) {
    if ((it.kind === 'stroke' || it.kind === 'track') && it.color && !seen.includes(it.color)) seen.push(it.color);
  }
  return seen;
}

// Legende für die Karte: nur Farben, die vorkommen und eine Bedeutung haben
export function lineLegend(project) {
  const lg = (project.mission && project.mission.legend) || {};
  return usedColors(project).filter((c) => (lg[c] || '').trim()).map((c) => ({ color: c, label: lg[c].trim(), line: true }));
}

const fmtDate = (t) => new Date(t).toLocaleString('de-DE', { dateStyle: 'medium', timeStyle: 'short' });

// Text für die Mail (die Zusammenfassung mit Verfasser, Kräften und Legende)
export function missionText(project, grid, attach = 'Abschlussbericht im Anhang (PDF).', sec = null) {
  const m = project.mission;
  const out = [`Einsatz: ${project.title || 'Suchgebiet'}`];
  if (project.leader) out.push(`Einsatzleitung: ${project.leader}`);
  if (m.author) out.push(`Verfasser: ${m.author}`);
  out.push(`Stand: ${fmtDate(Date.now())}`);
  if (want(sec, 'times') && timeLines(m).length) out.push('', 'Zeiten:', ...timeLines(m));
  if (want(sec, 'person') && m.person.trim()) out.push('', 'Vermisste Person:', m.person.trim());
  if (want(sec, 'forces') && m.forces.length) out.push('', `Kräfte (${STRENGTH_HINT}):`, ...m.forces.map(forceLine), totalLine(m.forces));
  if (want(sec, 'summary') && m.summary.trim()) out.push('', 'Zusammenfassung:', m.summary.trim());
  if (grid) out.push('', `Raster: ${grid.cellM} m Felder, A1 = Nordwest-Ecke.`);
  if (attach) out.push('', attach);
  return out.join('\n');
}

const NAMES = {
  '#d50000': 'rot', '#1565c0': 'blau', '#2e7d32': 'grün', '#ef6c00': 'orange', '#6a1b9a': 'lila', '#000000': 'schwarz', '#fdd835': 'gelb',
};
export const colorName = (c) => NAMES[String(c).toLowerCase()] || c;

// Eine Notizblock-Seite auf ein Canvas zeichnen (Bildschirm, Vorschau, PDF)
export const PAGE_RATIO = Math.SQRT2; // Höhe / Breite wie A4
export function drawNotePage(ctx, page, w, lines = true) {
  const h = w * PAGE_RATIO;
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, w, h);
  if (lines) {
    ctx.strokeStyle = '#dbe6f3';
    ctx.lineWidth = Math.max(1, w / 600);
    for (let y = w * 0.08; y < h; y += w * 0.06) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }
  }
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  for (const s of page.strokes) {
    ctx.strokeStyle = s.color;
    ctx.lineWidth = s.w * w;
    ctx.beginPath();
    s.pts.forEach(([x, y], i) => (i ? ctx.lineTo(x * w, y * w) : ctx.moveTo(x * w, y * w)));
    if (s.pts.length === 1) ctx.lineTo(s.pts[0][0] * w + 0.1, s.pts[0][1] * w);
    ctx.stroke();
  }
}

export function notePageImage(page, w = 1000) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = Math.round(w * PAGE_RATIO);
  drawNotePage(c.getContext('2d'), page, w);
  return c.toDataURL('image/jpeg', 0.8);
}

function imageSize(src) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve([img.naturalWidth, img.naturalHeight]);
    img.onerror = () => resolve([4, 3]);
    img.src = src;
  });
}

// Bericht-Seiten für das Abschluss-PDF (vor der Karte). Gibt die Zahl der Seiten zurück.
// Die erste Seite ist schon angelegt (doc aktuell auf Seite 1).
// parts: Häkchen (person, forces, summary, notes, pad, photos, legend) – fehlend = drin
export async function addReportPages(doc, project, grid, W, H, margin, parts = {}) {
  const m = project.mission;
  const x = margin;
  const maxW = W - 2 * margin;
  const withText = hasReportText(parts);
  const withImages = want(parts, 'pad') || want(parts, 'photos');
  let pages = withText ? 1 : 0;
  let y = margin + 6;
  // Seite 1 ist schon da: die erste Seite nicht neu anlegen
  const newPage = () => { if (pages) doc.addPage(); pages++; y = margin + 6; };
  const need = (h) => { if (y + h > H - margin) newPage(); };
  const text = (t, size = 10, bold = false, indent = 0) => {
    doc.setFont('helvetica', bold ? 'bold' : 'normal');
    doc.setFontSize(size);
    for (const line of doc.splitTextToSize(t, maxW - indent)) {
      need(size * 0.45);
      doc.text(line, x + indent, y);
      y += size * 0.45;
    }
  };
  const heading = (t) => { y += 3; need(14); text(t, 12, true); y += 1; };

  if (withText) {
    text(`Einsatzbericht: ${project.title || 'Suchgebiet'}`, 16, true);
    y += 1;
    const meta = [`Stand: ${fmtDate(Date.now())}`];
    if (project.leader) meta.push(`Einsatzleitung: ${project.leader}`);
    if (m.author) meta.push(`Verfasser: ${m.author}`);
    text(meta.join('   ·   '), 9.5);

    if (want(parts, 'times') && timeLines(m).length) { heading('Zeiten'); for (const l of timeLines(m)) text(l); }
    if (want(parts, 'person') && m.person.trim()) { heading('Vermisste Person'); text(m.person.trim()); }

    if (want(parts, 'forces') && m.forces.length) {
      heading('Kräfte');
      const cols = [['Organisation', 0], ...FORCE_KEYS.map(([, l], i) => [l, 0.5 + i * 0.125])];
      const row = (vals, bold) => {
        need(6);
        doc.setFont('helvetica', bold ? 'bold' : 'normal');
        doc.setFontSize(10);
        vals.forEach((v, i) => {
          const cx = x + cols[i][1] * maxW;
          if (i) doc.text(String(v), cx + 18, y, { align: 'right' });
          else doc.text(doc.splitTextToSize(String(v), maxW * 0.48)[0], cx, y);
        });
        y += 5.2;
      };
      row(cols.map((c) => c[0]), true);
      doc.setLineWidth(0.2);
      doc.line(x, y - 3.8, x + maxW, y - 3.8);
      for (const f of m.forces) row([f.org || '–', ...FORCE_KEYS.map(([k]) => num(f[k]))], false);
      const t = forceTotals(m.forces);
      doc.line(x, y - 3.8, x + maxW, y - 3.8);
      row(['Gesamt', t.lead, t.helpers, t.dogs, t.vehicles], true);
      text(`${t.people} Einsatzkräfte`, 9.5);
    }

    if (want(parts, 'summary') && m.summary.trim()) { heading('Zusammenfassung'); text(m.summary.trim()); }
    if (want(parts, 'notes') && (project.notes || '').trim()) { heading('Notizen'); text(project.notes.trim()); }

    const lg = want(parts, 'legend') ? lineLegend(project) : [];
    if (lg.length) {
      heading('Legende Karte');
      for (const e of lg) {
        need(6);
        const n = parseInt(e.color.slice(1), 16);
        doc.setDrawColor((n >> 16) & 255, (n >> 8) & 255, n & 255);
        doc.setLineWidth(1.2);
        doc.line(x, y - 1.3, x + 10, y - 1.3);
        doc.setDrawColor(0);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(10);
        doc.text(e.label, x + 14, y);
        y += 5.5;
      }
    }

  }

  // Handschrift und Fotos: eins pro Seite (Hochformat), zwei nebeneinander (Querformat)
  if (!withImages) return pages;
  const imgs = [
    ...(want(parts, 'pad') ? m.pages : []).filter((p) => p.strokes.length).map((p, i) => ({ title: `Notizblock Seite ${i + 1} (${fmtDate(p.t)})`, src: notePageImage(p), ratio: PAGE_RATIO })),
    ...(want(parts, 'photos') ? m.photos : []).map((p, i) => ({ title: `Foto ${i + 1} (${fmtDate(p.t)})`, src: p.src })),
  ];
  for (const im of imgs) {
    if (!im.ratio) {
      const [iw, ih] = await imageSize(im.src);
      im.ratio = ih / iw;
    }
  }
  const perRow = W > H ? 2 : 1;
  for (let i = 0; i < imgs.length; i += perRow) {
    newPage();
    const group = imgs.slice(i, i + perRow);
    const cellW = (maxW - (perRow - 1) * 6) / perRow;
    group.forEach((im, k) => {
      const cx = x + k * (cellW + 6);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(10);
      doc.text(im.title, cx, y);
      const availH = H - margin - y - 4;
      let w = cellW;
      let h = w * im.ratio;
      if (h > availH) { h = availH; w = h / im.ratio; }
      doc.addImage(im.src, 'JPEG', cx, y + 3, w, h);
      doc.setLineWidth(0.2);
      doc.rect(cx, y + 3, w, h);
    });
  }
  return pages;
}

// Foto verkleinern (Speicherplatz): längste Seite max. px, JPEG
export function shrinkPhoto(file, px = 1400, q = 0.65) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const k = Math.min(1, px / Math.max(img.naturalWidth, img.naturalHeight));
      const c = document.createElement('canvas');
      c.width = Math.round(img.naturalWidth * k);
      c.height = Math.round(img.naturalHeight * k);
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      resolve(c.toDataURL('image/jpeg', q));
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('Bild konnte nicht gelesen werden')); };
    img.src = url;
  });
}
