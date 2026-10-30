import test from 'node:test';
import assert from 'node:assert/strict';
import { emptySel, selectAll, selectTeam, selSummary, selCount, subsetProject } from '../web/scope.js';
import { newProject } from '../web/store.js';

function demo() {
  const p = newProject('Übung');
  p.area = { north: 52.63, south: 52.61, west: 10.06, east: 10.09 };
  p.gridId = 'g1';
  p.marks.push({ id: 'T1', kind: 'team', label: 'Team 1', color: '#1565c0' }, { id: 'T2', kind: 'team', label: 'Team 2', color: '#d50000' });
  p.fills = { '1,1': 'T1', '2,1': 'T1', '5,5': 'T2' };
  p.otherGrids = [{ id: 'g2', name: 'Süd', area: { north: 52.6, south: 52.59, west: 10.06, east: 10.07 }, cellM: 100, fills: { '0,0': 'T2' }, status: {} }];
  p.items.push({ kind: 'track', name: 'U1', to: 'T1', color: '#000', pts: [[52.62, 10.07], [52.62, 10.08], [52.61, 10.08]] });
  p.items.push({ kind: 'track', name: 'U2', to: 'T2', color: '#000', pts: [[52.62, 10.07], [52.62, 10.08], [52.61, 10.08]] });
  p.items.push({ kind: 'text', lat: 52.62, lon: 10.07, text: 'Fund', color: '#000' });
  p.pois = [{ id: 'a', cat: 'food', name: '', desc: '', lat: 52.6, lon: 10.06, t: 1, by: '' }];
  p.meet = { lat: 52.6, lon: 10.05, text: 'B-Ort' };
  p.notes = 'geheim';
  p.mission.person = 'Max';
  return p;
}

test('selectTeam: Felder, zugeteilte Umrisse, B-Ort, Lage-Orte', () => {
  const p = demo();
  const s = selectTeam(p, 'T1');
  assert.deepEqual([...s.items].map((i) => i.name), ['U1']);
  assert.deepEqual([...s.cells.get('g1')].sort(), ['1,1', '2,1']);
  assert.ok(!s.cells.has('g2'));
  assert.deepEqual([...s.edges], ['g1']);
  assert.equal(s.meet, true);
  assert.equal(s.pois.size, 1);
  assert.equal(selSummary(p, s), '1 Rastergebiet · 2 Felder · 1 Umriss · B-Ort · 1 Lage-Ort');
});

test('selectAll und selCount', () => {
  const p = demo();
  const s = selectAll(p);
  assert.equal(s.items.size, 3);
  assert.equal(s.edges.size, 2);
  assert.equal(selCount(s), 3 + 1 + 1 + 2 + 4);
  assert.equal(selCount(emptySel()), 0);
});

test('subsetProject: nur das Ausgewählte, eigene Einsatz-ID, keine Notizen', () => {
  const p = demo();
  const q = subsetProject(p, selectTeam(p, 'T1'), 'Übung – Team 1');
  assert.notEqual(q.id, p.id);
  assert.equal(q.eid, q.id);
  assert.equal(q.title, 'Übung – Team 1');
  assert.deepEqual(q.fills, { '1,1': 'T1', '2,1': 'T1' });
  assert.equal(q.otherGrids.length, 0);
  assert.deepEqual(q.items.map((i) => i.name), ['U1']);
  assert.equal(q.pois.length, 1);
  assert.equal(q.notes, '');
  assert.equal(q.mission.person, 'Max');
  assert.equal(p.items.length, 3); // Original unverändert
  // nur ein Feld im zweiten Gebiet: das wird zum Hauptraster
  const s = emptySel();
  s.cells.set('g2', new Set(['0,0']));
  const q2 = subsetProject(p, s, 'x');
  assert.equal(q2.gridId, 'g2');
  assert.deepEqual(q2.fills, { '0,0': 'T2' });
  assert.equal(q2.meet, null);
});

test('Auftrag: Lage-Orte gehen mit und kommen beim Hundeführer an', async () => {
  const { buildAssignment, projectFromAssignment } = await import('../web/share.js');
  const p = demo();
  const a = buildAssignment(p, { teamId: 'T1', gridIds: ['g1'], fields: 'team', itemIdx: [0], meet: true, poiIds: ['a'] });
  assert.deepEqual(a.po, [['a', 'food', 52.6, 10.06, '', '']]);
  const h = projectFromAssignment(a);
  assert.equal(h.pois.length, 1);
  assert.equal(h.pois[0].cat, 'food');
});

test('Unterabschnitt: nur das Gebiet, aber alle übrigen Daten des Grund-Einsatzes', async () => {
  const { buildInfos, infoTarget } = await import('../web/infos.js');
  const p = demo();
  p.eid = 'E1';
  const s = emptySel();
  s.items.add(p.items[0]);
  const q = subsetProject(p, s, 'Übung – UA U1', { base: true });
  assert.notEqual(q.eid, 'E1');
  assert.equal(q.parentEid, 'E1');
  assert.equal(q.parentTitle, 'Übung');
  // ganzer Grund-Einsatz geht mit (v90), das Ausgewählte als 'ua', der Rest als 'base' gesperrt
  assert.deepEqual(q.items.map((i) => [i.name || i.text, i.lock]), [['U1', 'ua'], ['U2', 'base'], ['Fund', 'base']]);
  assert.equal(q.otherGrids.length + (q.area ? 1 : 0), 2);
  assert.deepEqual(Object.values(q.glock), ['base', 'base']);
  assert.equal(q.pois.length, 1);
  assert.equal(q.meet.text, 'B-Ort');
  assert.equal(q.notes, 'geheim');
  assert.equal(q.mission.person, 'Max');
  q.mission.person = 'x';
  assert.equal(p.mission.person, 'Max'); // Kopie
  // Infos aus dem Unterabschnitt finden den Grund-Einsatz und umgekehrt
  const projects = { a: p, b: { ...q, eid: 'other-device' } };
  assert.equal(infoTarget({ a: p }, buildInfos(q)), p);
  assert.equal(infoTarget({ b: q }, buildInfos(p)), q);
  assert.equal(infoTarget(projects, { eid: 'nix' }), null);
});
