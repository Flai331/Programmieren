import test from 'node:test';
import assert from 'node:assert/strict';
import {
  newProject, migrateV1, cellRects, cellsText, assignments, resolveFills, exportProject, importProject,
  embedMarker, normalizeProject,
} from '../web/store.js';

test('Felder werden zu Rechtecken zusammengefasst', () => {
  const keys = [];
  for (let c = 0; c < 3; c++) for (let r = 0; r < 3; r++) keys.push(`${c},${r}`);
  keys.push('5,5');
  assert.equal(cellsText(keys), 'A1–C3, F6');
  assert.equal(cellsText(['0,0', '1,0', '0,1']), 'A1–B1, A2');
  assert.equal(cellRects([]).length, 0);
});

test('Teams: Zuteilung und Farben', () => {
  const p = newProject('Test');
  const team = { id: 't1', kind: 'team', label: 'Team 1', dog: 'Bello', color: '#d50000' };
  p.marks.push(team);
  p.fills = { '0,0': 't1', '1,0': 't1' };
  p.status = { '2,2': p.marks[0].id };
  const a = assignments(p).find((x) => x.mark.id === 't1');
  assert.equal(a.count, 2);
  assert.equal(a.text, 'A1–B1');
  assert.equal(resolveFills(p)['0,0'], '#d50000');
});

test('Alte Version (Farben) wird übernommen', () => {
  const p = migrateV1({ title: 'Alt', cellM: 200, area: { north: 1, south: 0, west: 0, east: 1 }, fills: { '0,0': '#d50000', '1,1': '#d50000', '2,2': '#1565c0' }, items: [] });
  assert.equal(p.title, 'Alt');
  assert.equal(p.cellM, 200);
  assert.equal(new Set(Object.values(p.status)).size, 2);
  assert.equal(resolveFills(p, 'status')['1,1'], '#d50000');
});

test('Export/Import als Datei und eingebettet im PDF', () => {
  const p = newProject('Übung Wald – Süd');
  p.notes = 'Funkkanal 3 🐕';
  p.status = { '0,0': p.marks[0].id };
  const a = importProject(exportProject(p));
  assert.equal(a.title, p.title);
  assert.equal(a.notes, p.notes);
  assert.notEqual(a.id, p.id);
  const fakePdf = `%PDF-1.3\n<x:xmpmeta>${embedMarker(p)}</x:xmpmeta>\n%%EOF`;
  const b = importProject(fakePdf);
  assert.equal(b.notes, p.notes);
  assert.deepEqual(Object.keys(b.status), ['0,0']);
  assert.throws(() => importProject('%PDF-1.3 nichts'), /Keine Suchgebiet-Daten/);
});

test('Ungültige Feldzuteilungen werden entfernt', () => {
  const p = newProject();
  p.fills = { '0,0': 'gibtsnicht' };
  assert.deepEqual(normalizeProject(p).fills, {});
});

test('Team bleibt, wenn das Feld zusätzlich als abgesucht markiert wird', () => {
  const p = newProject('T');
  const done = p.marks[0]; // abgesucht
  p.marks.push({ id: 't', kind: 'team', label: 'Team 1', color: '#d50000' });
  p.fills = { '0,0': 't', '1,0': 't' };
  p.status = { '0,0': done.id };
  const n = normalizeProject(p);
  assert.equal(n.fills['0,0'], 't');
  assert.equal(n.status['0,0'], done.id);
  const as = Object.fromEntries(assignments(n).map((a) => [a.mark.id, a.text]));
  assert.equal(as.t, 'A1–B1');
  assert.equal(as[done.id], 'A1');
  assert.equal(resolveFills(n, 'status')['0,0'], done.color);
});

test('Alter Stand: Status in den Teamfeldern wird umgezogen', () => {
  const p = newProject('T');
  const done = p.marks[0];
  p.fills = { '2,2': done.id };
  const n = normalizeProject(p);
  assert.deepEqual(n.fills, {});
  assert.equal(n.status['2,2'], done.id);
});
