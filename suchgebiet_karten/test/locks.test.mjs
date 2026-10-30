import test from 'node:test';
import assert from 'node:assert/strict';
import { canEdit, canDelete, canEditCell, canEditGrid, canDeleteGrid, cellLock, denied, deniedCell, deniedGrid, MSG_VIEW, MSG_DELETE, isUA } from '../web/locks.js';
import { emptySel, subsetProject } from '../web/scope.js';
import { newProject, normalizeProject } from '../web/store.js';
import { newPoi } from '../web/pois.js';

function base() {
  const p = normalizeProject(newProject('Einsatz'));
  p.eid = 'E1';
  p.marks.push({ id: 'T1', kind: 'team', label: 'Team 1', color: '#1565c0', dog: '' });
  p.area = { north: 52.30, south: 52.28, west: 8.00, east: 8.04 };
  p.gridId = 'G1';
  p.fills = { '1,1': 'T1' };
  p.otherGrids = [{ id: 'G2', name: 'Süd', area: { north: 52.27, south: 52.25, west: 8.00, east: 8.04 }, cellM: 100, fills: { '0,0': 'T1' }, status: {} }];
  p.items = [
    { kind: 'track', color: '#000', name: 'Nord', pts: [[52.29, 8.01], [52.295, 8.02], [52.29, 8.03]] },
    { kind: 'track', color: '#000', name: 'Süd', pts: [[52.26, 8.01], [52.265, 8.02], [52.26, 8.03]] },
  ];
  p.pois.push(newPoi({ cat: 'elw', lat: 52.2, lon: 8, by: 'EL' }), newPoi({ cat: 'park', lat: 52.21, lon: 8, by: 'EL' }));
  p.meet = { lat: 52.29, lon: 8.0, text: 'B-Ort' };
  return normalizeProject(p);
}
function ua(p) {
  const s = emptySel();
  s.items.add(p.items[0]);
  s.edges.add('G1');
  s.pois.add(p.pois[0]);
  return subsetProject(p, s, 'UA Nord', { base: true });
}

test('Grund-Einsatz hat keine Sperren', () => {
  const p = base();
  assert.equal(isUA(p), false);
  assert.equal(canEdit(p, { lock: 'base' }), true);
  assert.equal(canDelete(p, { lock: 'ua' }), true);
  assert.equal(denied(p, { lock: 'base' }, 'delete'), '');
  assert.equal(canEditCell(p, 'G1', '1,1'), true);
});

test('UA: Elemente des Grund-Einsatzes nur ansehen, übergebene nicht löschbar, neue frei', () => {
  const q = ua(base());
  assert.equal(isUA(q), true);
  const [nord, sued] = q.items;
  assert.equal(nord.lock, 'ua');
  assert.equal(sued.lock, 'base');
  assert.equal(canEdit(q, sued), false);
  assert.equal(canDelete(q, sued), false);
  assert.equal(denied(q, sued, 'edit'), MSG_VIEW);
  assert.equal(denied(q, sued, 'delete'), MSG_VIEW);
  assert.equal(canEdit(q, nord), true);
  assert.equal(canDelete(q, nord), false);
  assert.equal(denied(q, nord, 'edit'), '');
  assert.equal(denied(q, nord, 'delete'), MSG_DELETE);
  const neu = { kind: 'text', text: 'x' }; // im UA angelegt
  assert.equal(canEdit(q, neu), true);
  assert.equal(canDelete(q, neu), true);
  assert.equal(denied(q, neu, 'delete'), '');
});

test('UA: Lage-Orte und B-Ort tragen Sperren', () => {
  const q = ua(base());
  assert.deepEqual(q.pois.map((x) => x.lock).sort(), ['base', 'ua']);
  assert.equal(q.meet.lock, 'base');
  assert.equal(canEdit(q, q.meet), false);
  assert.equal(canDelete(q, q.pois.find((x) => x.lock === 'ua')), false);
});

test('UA: ganzer Grund-Einsatz geht mit, Raster außerhalb der Auswahl gesperrt', () => {
  const q = ua(base());
  assert.equal(q.items.length, 2);
  assert.deepEqual(q.glock, { G1: 'ua', G2: 'base' });
  assert.equal(canEditGrid(q, 'G2'), false);
  assert.equal(canEditGrid(q, 'G1'), true);
  assert.equal(canDeleteGrid(q, 'G1'), false);
  assert.equal(deniedGrid(q, 'G2', 'edit'), MSG_VIEW);
  assert.equal(deniedGrid(q, 'G1', 'delete'), MSG_DELETE);
  assert.equal(deniedGrid(q, 'G1', 'edit'), '');
  assert.equal(canEditCell(q, 'G2', '0,0'), false);
  assert.equal(deniedCell(q, 'G2', '0,0'), MSG_VIEW);
  assert.equal(canEditCell(q, 'G1', '1,1'), true);
  assert.equal(canEditCell(q, 'NEU', '0,0'), true); // im UA angelegtes Raster ist frei
  // alle Felder beider Raster sind mitgekommen
  assert.equal(Object.keys(q.fills).length + q.otherGrids.reduce((a, g) => a + Object.keys(g.fills).length, 0), 2);
});

test('UA: nur einzelne Felder eines Rasters -> übrige Felder gesperrt', () => {
  const p = base();
  const s = emptySel();
  s.cells.set('G1', new Set(['1,1']));
  const q = subsetProject(p, s, 'UA', { base: true });
  assert.equal(cellLock(q, 'G1', '1,1'), 'ua');
  assert.equal(cellLock(q, 'G1', '2,2'), 'base');
  assert.equal(canEditCell(q, 'G1', '2,2'), false);
  assert.equal(canEditCell(q, 'G1', '1,1'), true);
});

test('Sperren überstehen normalizeProject und JSON; unbekannte Werte fallen weg', () => {
  const q = normalizeProject(JSON.parse(JSON.stringify(ua(base()))));
  assert.equal(q.items[1].lock, 'base');
  const r = normalizeProject({ ...q, items: [{ kind: 'text', lock: 'quatsch', text: 'a', lat: 1, lon: 1 }] });
  assert.equal(r.items[0].lock, undefined);
  assert.ok(r.items[0].id && r.items[0].t > 0);
});

test('Ohne Auswahl und Grund-Einsatz: alles gesperrt, Neues frei', () => {
  const q = subsetProject(base(), emptySel(), 'leer', { base: true });
  assert.ok(q.items.every((it) => it.lock === 'base'));
  assert.equal(canEdit(q, q.items[0]), false);
  assert.equal(canDelete(q, { kind: 'stroke' }), true);
});
