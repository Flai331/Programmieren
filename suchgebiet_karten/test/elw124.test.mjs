// v124: Zeichnung mit Auftrag an den ELW
import test from 'node:test';
import assert from 'node:assert/strict';
import { buildElwOrder, splitElwOrder, joinElwParts, elwInbox, mergeElwItems, addElwIn, elwTemplates, elwCounts, ELW_MAX_CHARS } from '../web/elw.js';
import { EL_KINDS, forHf, needsAck, encryptMsg, newLiveKey } from '../web/status.js';
import { normalizeProject, newProject } from '../web/store.js';

const track = (n = 4, extra = {}) => ({ kind: 'track', id: 'x1', t: 5, by: 'EL', lock: 'base', color: '#d50000', w: 4, name: 'Nord', pts: Array.from({ length: n }, (_, i) => [52.123456789 + i * 0.001, 8.987654321 + (i % 2) * 0.001]), ...extra });
const stroke = (g) => ({ kind: 'stroke', id: 's1', color: '#000', w: 5, group: g, name: 'Weg', pts: [[52.1, 8.1], [52.2, 8.2]] });

test('buildElwOrder: Form, Rundung, keine internen Felder', () => {
  const m = buildElwOrder({ from: 'Handy EL', to: '*', txt: '2× DRK, 1× JUH', items: [track(), stroke('g'), { kind: 'text', lat: 52.5, lon: 8.5, text: 'Hier', id: 'q' }, { kind: 'foo' }], t: 7, id: 'O1' });
  assert.equal(m.s, 'elw'); assert.equal(m.a, 'EL'); assert.equal(m.id, 'O1'); assert.equal(m.to, ''); assert.equal(m.items.length, 3);
  const t = m.items[0];
  assert.equal(t.pts[0][0], 52.123457);
  for (const k of ['id', 't', 'by', 'lock']) assert.ok(!(k in t));
  assert.equal(elwCounts(m.items), '1 Umriss, 1 Zeichnung, 1 Text');
});
test('buildElwOrder: Team nur als Name', () => {
  const m = buildElwOrder({ from: 'A', items: [track(3, { to: 'T9' })], marks: [{ id: 'T9', label: 'DRK 1' }] });
  assert.equal(m.items[0].toName, 'DRK 1'); assert.ok(!('to' in m.items[0]));
});
test('split/join: klein bleibt ganz, groß wird Teile, fehlender Teil -> nichts', () => {
  const small = buildElwOrder({ from: 'A', items: [track()], id: 'S' });
  assert.deepEqual(splitElwOrder(small), [small]);
  const big = buildElwOrder({ from: 'A', txt: 'äöü € 😀', items: Array.from({ length: 6 }, () => track(900)), id: 'BIG' });
  const parts = splitElwOrder(big);
  assert.ok(parts.length > 1);
  for (const p of parts) { assert.equal(p.s, 'elwp'); assert.ok(p.id.length <= 40); assert.ok((await0(p)).length < 20000); }
  const j = joinElwParts(parts);
  assert.equal(j.length, 1); assert.deepEqual(j[0], big);
  assert.deepEqual(joinElwParts(parts.slice(1)), []);
  assert.equal(joinElwParts([...parts, ...parts, small]).length, 2);
});
function await0(p) { return JSON.stringify(p); }
test('Teile bleiben verschlüsselt unter 20000 Zeichen (Server-Grenze)', async () => {
  const key = newLiveKey();
  const big = buildElwOrder({ from: 'A', txt: '€€€', items: [{ ...track(2500), name: '"""' }], id: 'B2' });
  for (const p of splitElwOrder(big, ELW_MAX_CHARS)) assert.ok((await encryptMsg(key, p)).length < 20000);
});
test('elwInbox: eigene und fremd adressierte weg, alle sichtbar, neueste zuerst, ohne Doppelte', () => {
  const mk = (id, from, to, t) => ({ ...buildElwOrder({ from, to, items: [track()], id, t }) });
  const l = elwInbox([mk('a', 'Handy EL', '', 1), mk('b', 'ELW', '', 2), mk('c', 'Handy EL', 'ELW', 3), mk('d', 'Handy EL', 'PC EL', 4), mk('e', 'X', 'alle', 5), mk('a', 'Handy EL', '', 1), { s: 'el', id: 'z', t: 1 }], 'ELW');
  assert.deepEqual(l.map((m) => m.id), ['e', 'c', 'a']);
});
test('mergeElwItems: nur ergänzen, zweimal = keine Duplikate, Gruppen und Teams', () => {
  const p = normalizeProject(newProject('E'));
  p.marks.push({ id: 'T1', kind: 'team', label: 'DRK 1', color: '#000' });
  p.items.push({ kind: 'text', color: '#000', lat: 1, lon: 1, text: 'alt' });
  const m = buildElwOrder({ from: 'A', items: [track(3, { to: 'Q' }), stroke('g'), stroke('g')], marks: [{ id: 'Q', label: 'DRK 1' }], id: 'O' });
  const r1 = mergeElwItems(p, m.items, 'O', { by: 'ELW' });
  assert.equal(r1.added.length, 3); assert.equal(p.items.length, 4);
  assert.equal(p.items[1].to, 'T1'); assert.equal(p.items[2].group, p.items[3].group); assert.notEqual(p.items[2].group, 'g');
  assert.ok(new Set(p.items.map((i) => i.id)).size === 4);
  const r2 = mergeElwItems(p, m.items, 'O');
  assert.equal(r2.added.length, 0); assert.equal(p.items.length, 4);
  assert.equal(mergeElwItems(p, m.items, 'O2').added.length, 3);
});
test('addElwIn: Duplikate weg, max. 50', () => {
  const o = (i) => ({ id: `o${i}`, t: i, items: [] });
  let l = addElwIn([], Array.from({ length: 60 }, (_, i) => o(i))).list;
  assert.equal(l.length, 50); assert.equal(l[0].id, 'o59');
  assert.equal(addElwIn(l, [o(59)]).fresh.length, 0);
});
test('HF sehen nichts davon, nichts wird quittiert, Vorlagen', () => {
  const m = buildElwOrder({ from: 'A', items: [] });
  assert.deepEqual(forHf([m], 'A1'), []);
  assert.ok(EL_KINDS.includes('elw') && EL_KINDS.includes('elwp'));
  assert.equal(needsAck({ a: 'A1', s: 'elw' }), false);
  assert.ok(elwTemplates.includes('2× DRK, 1× JUH'));
});
test('normalizeProject behält elwIn', () => {
  const p = normalizeProject({ ...newProject('E'), elwIn: [{ id: 'a', t: 1, items: [] }, { x: 1 }], elwSent: 5 });
  assert.equal(p.elwIn.length, 1); assert.equal(p.elwSent, 5);
});
