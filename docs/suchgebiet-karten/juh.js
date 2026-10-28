// JUH-Vorlage „Einsatzbericht Rettungshundestaffel“ (ausfüllbares PDF): vorhandene Daten
// werden eingetragen, alle Felder bleiben beschreibbar (nichts wird „flachgeklopft“).
// Feldnamen der Vorlage sind nur nummeriert – Zuordnung nach ihrer Lage im Formular.

import { forceTotals, forceLine, missionHours } from './mission.js';

export const JUH_TEMPLATE = 'vorlagen/juh-einsatzbericht-rhs.pdf';

// Mehrzeilige Bereiche: Folge einzelner Zeilenfelder
const LINES = {
  lage: Array.from({ length: 10 }, (_, i) => `Textfeld 35.${i}`),
  staffeln: Array.from({ length: 9 }, (_, i) => `Textfeld 40.${i}`),
  verlauf: Array.from({ length: 11 }, (_, i) => `Textfeld 51.${i}`),
  besonderheiten: Array.from({ length: 20 }, (_, i) => `Textfeld 75.${i}`),
};

const isRhs = (o) => /RHS|Rettungshund|Hundestaffel|BRH|Staffel/i.test(o);
const isJuh = (o) => /JUH|Johanniter/i.test(o);
const isFfw = (o) => /Feuerwehr|FFW|\bFF\b|\bFW\b/i.test(o);

// Eigene Organisation: angehakt, sonst die erste Zeile
export function splitForces(forces) {
  const own = forces.filter((f) => f.own);
  if (!own.length && forces.length) own.push(forces[0]);
  return { own, other: forces.filter((f) => !own.includes(f)) };
}

// -> { fields: {Feldname: Text}, blocks: {lage|staffeln|verlauf|besonderheiten: Text} }
export function juhValues(project, now = new Date()) {
  const m = project.mission;
  const { own, other } = splitForces(m.forces);
  const ownT = forceTotals(own);
  const otherT = forceTotals(other);
  const n = (v) => (v ? String(v) : '');
  const t = m.times || {};
  const hours = missionHours(m);
  const ownNames = own.map((f) => f.org).filter(Boolean).join(', ');
  const fields = {
    'Textfeld 77': String(now.getFullYear() % 100).padStart(2, '0'),
    'Textfeld 6': own.map((f) => (f.org || '').replace(/^(JUH|Johanniter)?\s*RHS\s*/i, '')).filter(Boolean).join(', '),
    'Textfeld 39': [project.leader, ownNames && `(${ownNames})`].filter(Boolean).join(' '),
    // Kräfte: Fü / GF / Helfer // Gesamt
    'Textfeld 41': n(ownT.lead),
    'Textfeld 43.0': n(ownT.helpers),
    'Textfeld 43.1': n(ownT.people),
    'Textfeld 46': n(otherT.lead),
    'Textfeld 44.0': n(otherT.helpers),
    'Textfeld 44.1': n(otherT.people),
    // RH-Teams Fläche (Hunde)
    'Textfeld 47': n(ownT.dogs),
    'Textfeld 50': n(forceTotals(other.filter((f) => isRhs(f.org || ''))).dogs),
    // Zeiten: Alarmierung am/um, Wache abgerückt, Einsatzstelle an, Einsatzende, Unterkunft
    'Textfeld 29': t.alarmDate ? t.alarmDate.split('-').reverse().join('.') : '',
    'Textfeld 30': t.alarm || '',
    'Textfeld 36': t.depart || '',
    'Textfeld 37': t.arrive || '',
    'Textfeld 52': t.end || '',
    'Textfeld 54': t.back || '',
    // Einsatzstunden = Helfer × Dauer, gerundet
    'Textfeld 55': hours ? String(Math.round(ownT.people * hours)) : '',
    'Textfeld 56': hours ? String(Math.round((ownT.people + otherT.people) * hours)) : '',
    'Textfeld 57': now.toLocaleDateString('de-DE'),
    'Textfeld 58': m.author || project.leader || '',
  };
  const group = (test) => other.filter((f) => test(f.org || '')).map(forceLine).join('\n');
  const used = (f) => isJuh(f.org || '') || isFfw(f.org || '') || isRhs(f.org || '');
  fields['Textfeld 78.0.0'] = own.concat(other).filter((f) => isJuh(f.org || '')).map(forceLine).join('\n');
  fields['Textfeld 78.0.1'] = group(isFfw);
  fields['Textfeld 78.1.1'] = other.filter((f) => !used(f)).map(forceLine).join('\n');
  fields['Textfeld 78.1.0'] = own.concat(other).filter((f) => isRhs(f.org || '') && !isJuh(f.org || '')).map(forceLine).join('\n');

  const blocks = {
    lage: m.person.trim() ? `Vermisste Person: ${m.person.trim()}` : '',
    staffeln: other.filter((f) => isRhs(f.org || '')).map(forceLine).join('\n'),
    verlauf: m.summary.trim(),
    besonderheiten: (project.notes || '').trim(),
  };
  // Kästen auf Seite 3: unter der Überschrift beginnen
  for (const k of ['Textfeld 78.0.0', 'Textfeld 78.0.1', 'Textfeld 78.1.1', 'Textfeld 78.1.0']) {
    if (fields[k]) fields[k] = `\n${fields[k]}`;
  }
  for (const k of Object.keys(fields)) if (!fields[k]) delete fields[k];
  return { fields, blocks };
}

// Text auf Zeilen bestimmter Breite umbrechen (measure(text) -> Breite in pt)
export function wrapText(text, width, measure) {
  const out = [];
  for (const para of String(text).split('\n')) {
    let line = '';
    for (const word of para.split(/\s+/).filter(Boolean)) {
      const next = line ? `${line} ${word}` : word;
      if (measure(next) <= width || !line) line = next;
      else { out.push(line); line = word; }
    }
    out.push(line);
  }
  return out;
}

// Vorlage füllen -> PDF-Bytes. Überlauf eines Bereichs kommt nach „Besonderheiten“.
export async function fillJuh(templateBytes, project, now = new Date()) {
  const { PDFDocument, StandardFonts } = await import('./lib/pdf-lib.esm.min.js');
  const pdf = await PDFDocument.load(templateBytes);
  const form = pdf.getForm();
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const size = 10;
  const { fields, blocks } = juhValues(project, now);
  const set = (name, text) => {
    const f = form.getTextField(name);
    f.setText(text);
  };
  for (const [name, text] of Object.entries(fields)) {
    const f = form.getTextField(name);
    if (f.isMultiline()) f.setFontSize(9); else f.setFontSize(size);
    set(name, text);
  }
  const overflow = [];
  const fill = (key, title) => {
    const names = LINES[key];
    if (!blocks[key]) return;
    const w = form.getTextField(names[0]).acroField.getWidgets()[0].getRectangle().width - 6;
    const lines = wrapText(blocks[key], w, (t) => font.widthOfTextAtSize(t, size));
    names.forEach((nm, i) => { if (lines[i]) { form.getTextField(nm).setFontSize(size); set(nm, lines[i]); } });
    if (lines.length > names.length) overflow.push(`${title} (Fortsetzung): ${lines.slice(names.length).join(' ')}`);
  };
  fill('lage', 'Lage');
  fill('staffeln', 'Weitere Staffeln');
  fill('verlauf', 'Einsatzverlauf');
  if (overflow.length) blocks.besonderheiten = [blocks.besonderheiten, ...overflow].filter(Boolean).join('\n');
  fill('besonderheiten', 'Besonderheiten');
  // Darstellung mit Helvetica erzeugen; die Felder bleiben ausfüllbar
  form.updateFieldAppearances(font);
  return pdf.save();
}
