import test from 'node:test';
import assert from 'node:assert/strict';
import { cleanPart, fileName } from '../web/files.js';

const d = new Date(2026, 9, 30, 14, 5);

test('fileName: Einsatz_Datum_Uhrzeit_Inhalt.ext', () => {
  assert.equal(fileName('Übung Nordhang', 'Karte', '.pdf', d), 'Uebung_Nordhang_2026-10-30_1405_Karte.pdf');
  assert.equal(fileName('Übung', 'Team 1 – Süd', '.gpx', d), 'Uebung_2026-10-30_1405_Team_1_Sued.gpx');
  assert.equal(fileName('', 'Einsatzdatei', '.suchgebiet.json', d), 'Suchgebiet_2026-10-30_1405_Einsatzdatei.suchgebiet.json');
  assert.equal(fileName('Kontakte', '', '.vcf', d), 'Kontakte_2026-10-30_1405.vcf');
});

test('cleanPart: nur sichere Zeichen, keine doppelten oder Rand-Unterstriche', () => {
  assert.equal(cleanPart('  a / b: c?  '), 'a_b_c');
  assert.equal(cleanPart('Straße'), 'Strasse');
  assert.equal(cleanPart('x'.repeat(60)).length, 40);
  assert.equal(cleanPart('***'), '');
});
