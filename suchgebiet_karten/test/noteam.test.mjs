import test from 'node:test';
import assert from 'node:assert/strict';
import {
  newProject, normalizeProject, resolveFills, assignments, cellOwner, assigneeName, mapFor,
  NO_TEAM, NO_TEAM_COLOR, MARK_COLORS, TEAM_COLORS, uid,
} from '../web/store.js';
import { outlineColor, isNoTeamOutline } from '../web/render.js';
import { assignedCell } from '../web/locks.js';
import { usedColors } from '../web/mission.js';

test('Grau gibt es nicht mehr als Team-/Markierungsfarbe', () => {
  assert.ok(!MARK_COLORS.includes(NO_TEAM_COLOR));
  assert.ok(!TEAM_COLORS.includes(NO_TEAM_COLOR));
  assert.equal(NO_TEAM_COLOR, '#616161');
});

test('altes Team in Grau bekommt die erste freie Teamfarbe, sein Umriss zieht mit', () => {
  const p = newProject('x');
  const t1 = { id: 't1', kind: 'team', label: 'Grau', dog: '', color: '#616161' };
  const t2 = { id: 't2', kind: 'team', label: 'Rot', dog: '', color: TEAM_COLORS[0] };
  p.marks.push(t1, t2);
  p.items = [{ kind: 'track', color: '#616161', to: 't1', pts: [] }, { kind: 'track', color: '#123456', pts: [] }];
  p.fills = { '0,0': 't1' };
  const n = normalizeProject(p);
  const m = n.marks.find((x) => x.id === 't1');
  assert.equal(m.color, TEAM_COLORS[1]); // Rot ist belegt
  assert.equal(n.items[0].color, TEAM_COLORS[1]);
  assert.equal(n.items[1].color, '#123456');
  assert.equal(n.fills['0,0'], 't1');
  // die Status-Markierung „nicht begehbar“ (Grau) bleibt unberührt
  assert.ok(n.marks.some((x) => x.kind === 'status' && x.color === '#616161'));
});

test('NO_TEAM in fills überlebt normalizeProject (auch in weiteren Rastern) und wird grau aufgelöst', () => {
  const p = newProject('x');
  p.fills = { '0,0': NO_TEAM, '1,0': 'gibtsnicht' };
  p.otherGrids = [{ id: 'g2', name: 'B', area: { north: 1, south: 0, west: 0, east: 1 }, cellM: 100, fills: { '2,2': NO_TEAM }, status: {} }];
  const n = normalizeProject(p);
  assert.deepEqual(n.fills, { '0,0': NO_TEAM });
  assert.deepEqual(n.otherGrids[0].fills, { '2,2': NO_TEAM });
  assert.deepEqual(resolveFills(n), { '0,0': NO_TEAM_COLOR });
  assert.equal(cellOwner(n, 0, 0), null);
});

test('NO_TEAM zählt bei keinem Team und ist nicht zugeteilt', () => {
  const p = normalizeProject({ ...newProject('x'), fills: { '0,0': NO_TEAM } });
  p.marks.push({ id: 't1', kind: 'team', label: 'T', dog: '', color: TEAM_COLORS[0] });
  const a = assignments(p).find((x) => x.mark.id === 't1');
  assert.equal(a.count, 0);
  assert.equal(assigneeName(p, NO_TEAM), '');
  assert.equal(mapFor(p, { id: NO_TEAM, kind: 'team' }), p.fills);
  p.sent = [{ id: 'A', teamId: 't1', grids: [p.gridId], at: 1, acc: 1, cells: { [p.gridId]: ['5,5'] } }];
  assert.equal(assignedCell(p, p.gridId, '0,0', 2), null);
});

test('outlineColor: geschlossener Umriss ohne Team ist grau, sonst bleibt die Farbe', () => {
  const closed = { kind: 'track', color: '#d50000', pts: [] };
  assert.equal(outlineColor(closed), NO_TEAM_COLOR);
  assert.ok(isNoTeamOutline(closed));
  assert.equal(outlineColor({ ...closed, to: 't1' }), '#d50000');
  assert.equal(outlineColor({ ...closed, to: 'u:Feuerwehr' }), '#d50000');
  assert.equal(outlineColor({ ...closed, open: true }), '#d50000');
  assert.equal(outlineColor({ ...closed, fromEl: true }), '#d50000');
  assert.equal(outlineColor({ ...closed, prev: 'x' }), '#d50000');
  assert.equal(outlineColor({ kind: 'stroke', color: '#d50000' }), '#d50000');
  assert.equal(outlineColor(closed, false), '#d50000'); // Hundeführer-Gerät
  assert.equal(outlineColor({ ...closed, color: '#9e9e9e' }), '#9e9e9e'); // gedämpft (Grund-Einsatz)
});

test('Legende der Zeichnungsfarben nutzt die gezeichnete Farbe', () => {
  const p = newProject('x');
  p.items = [{ kind: 'track', color: '#d50000', pts: [] }, { kind: 'track', color: '#1565c0', to: 't', pts: [] }];
  assert.deepEqual(usedColors(p), [NO_TEAM_COLOR, '#1565c0']);
  assert.ok(uid());
});
