import test from 'node:test';
import assert from 'node:assert/strict';
import { newProject, normalizeProject, gridTeams, startNewGrid, gridLabel } from '../web/store.js';

const area = { north: 50.01, south: 50, west: 8, east: 8.01 };

test('v120: Raster heißen „Raster N“, alte Auto-Namen „Gebiet N“ werden umbenannt', () => {
  const p = normalizeProject({ ...newProject(), area, gridName: 'Gebiet 1', otherGrids: [{ id: 'b', name: 'Gebiet 2', area }, { id: 'c', name: 'Gebiet Nord', area }] });
  assert.equal(p.gridName, 'Raster 1');
  assert.deepEqual(p.otherGrids.map((g) => g.name), ['Raster 2', 'Gebiet Nord']);
  startNewGrid(p);
  assert.equal(p.gridName, 'Raster 3');
  assert.equal(gridLabel(p, { name: '' }), 'Raster 1');
});

test('v120: gridTeams liefert die Teams mit Feldern, ohne „ohne Team“', () => {
  const base = newProject();
  base.marks.push({ id: 'ta', kind: 'team', label: 'Rot', color: '#f00' }, { id: 'tb', kind: 'team', label: 'Blau', color: '#00f' });
  const p = normalizeProject(base);
  const [a, b] = p.marks.filter((m) => m.kind === 'team');
  const g = { fills: { '0,0': b.id, '1,0': b.id, '2,0': '-' } };
  assert.deepEqual(gridTeams(p, g).map((m) => m.id), [b.id]);
  g.fills['3,0'] = a.id;
  assert.deepEqual(gridTeams(p, g).map((m) => m.id), [a.id, b.id]);
  assert.deepEqual(gridTeams(p, { fills: { '0,0': '-' } }), []);
});
