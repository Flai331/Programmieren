import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { juhValues, wrapText, fillJuh, splitForces } from '../web/juh.js';
import { newProject } from '../web/store.js';

function project() {
  const p = newProject('Suche Laer');
  p.leader = 'K. Otte';
  p.notes = 'Funkkanal 3';
  Object.assign(p.mission, {
    person: 'Herr M., 82 J.',
    summary: '15:05 Person gefunden',
    author: 'Anna',
    forces: [
      { org: 'Feuerwehr Laer', lead: 2, helpers: 18, dogs: 0 },
      { org: 'JUH RHS Osnabrück', lead: 1, helpers: 7, dogs: 5, own: true },
      { org: 'BRH RHS Münster', lead: 1, helpers: 4, dogs: 3 },
    ],
  });
  return p;
}

test('JUH: eigene und fremde Kräfte, Gruppen, Texte', () => {
  const { own, other } = splitForces(project().mission.forces);
  assert.deepEqual(own.map((f) => f.org), ['JUH RHS Osnabrück']);
  assert.equal(other.length, 2);
  assert.equal(splitForces([{ org: 'A' }, { org: 'B' }]).own[0].org, 'A'); // ohne Haken: erste Zeile
  const { fields, blocks } = juhValues(project(), new Date('2026-10-28T12:00:00'));
  assert.equal(fields['Textfeld 77'], '26');
  assert.equal(fields['Textfeld 6'], 'Osnabrück');
  assert.equal(fields['Textfeld 39'], 'K. Otte (JUH RHS Osnabrück)');
  assert.deepEqual([fields['Textfeld 41'], fields['Textfeld 43.0'], fields['Textfeld 43.1']], ['1', '7', '8']);
  assert.deepEqual([fields['Textfeld 46'], fields['Textfeld 44.0'], fields['Textfeld 44.1']], ['3', '22', '25']);
  assert.equal(fields['Textfeld 47'], '5');
  assert.equal(fields['Textfeld 50'], '3'); // nur Hunde fremder Staffeln
  assert.match(fields['Textfeld 78.0.1'], /Feuerwehr Laer/);
  assert.match(fields['Textfeld 78.1.0'], /BRH RHS Münster/);
  assert.equal(fields['Textfeld 58'], 'Anna');
  const p2 = project();
  p2.mission.times = { alarm: '13:20', alarmDate: '2026-10-28', depart: '13:35', arrive: '14:05', end: '15:40', back: '16:20' };
  const v2 = juhValues(p2).fields;
  assert.deepEqual(['29', '30', '36', '37', '52', '54'].map((n) => v2[`Textfeld ${n}`]), ['28.10.2026', '13:20', '13:35', '14:05', '15:40', '16:20']);
  assert.equal(v2['Textfeld 55'], '24'); // 8 eigene Helfer × 3 h
  assert.equal(v2['Textfeld 56'], '99'); // 33 × 3 h
  assert.equal(blocks.lage, 'Vermisste Person: Herr M., 82 J.');
  assert.match(blocks.staffeln, /BRH RHS Münster/);
});

test('Zeilenumbruch nach Breite', () => {
  assert.deepEqual(wrapText('aa bb cc\ndd', 5, (t) => t.length), ['aa bb', 'cc', 'dd']);
});

test('Vorlage füllen: Werte drin, alle Felder bleiben ausfüllbar', async () => {
  const bytes = readFileSync(new URL('../web/vorlagen/juh-einsatzbericht-rhs.pdf', import.meta.url));
  const p = project();
  p.mission.summary = 'Sehr langer Verlauf. '.repeat(80);
  const out = await fillJuh(bytes, p, new Date('2026-10-28T12:00:00'));
  const { PDFDocument } = await import('../web/lib/pdf-lib.esm.min.js');
  const doc = await PDFDocument.load(out);
  const form = doc.getForm();
  const orig = (await PDFDocument.load(bytes)).getForm().getFields().length;
  assert.equal(form.getFields().length, orig); // alle Formularfelder noch da
  assert.ok(form.getFields().every((f) => !f.isReadOnly()));
  assert.equal(form.getTextField('Textfeld 41').getText(), '1');
  assert.ok(form.getTextField('Textfeld 51.10').getText()); // Verlauf füllt alle Zeilen
  assert.match(form.getTextField('Textfeld 75.1').getText(), /Einsatzverlauf \(Fortsetzung\)/); // Rest unter Besonderheiten
  assert.equal(form.getTextField('Textfeld 28').getText(), undefined); // leer, aber beschreibbar
});
