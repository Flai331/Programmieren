import { test } from 'node:test';
import assert from 'node:assert/strict';
import { reorderMarks } from '../web/store.js';

const M = [
  { id: 's1', kind: 'status' }, { id: 't1', kind: 'team' }, { id: 's2', kind: 'status' }, { id: 't2', kind: 'team' }, { id: 't3', kind: 'team' },
];
const ids = (l) => l.map((m) => m.id).join(',');

test('Teams umsortieren, Markierungen bleiben auf ihren Plätzen', () => {
  assert.equal(ids(reorderMarks(M, 'team', ['t3', 't1', 't2'])), 's1,t3,s2,t1,t2');
});
test('Markierungen umsortieren, Teams bleiben', () => {
  assert.equal(ids(reorderMarks(M, 'status', ['s2', 's1'])), 's2,t1,s1,t2,t3');
});
test('fehlende und unbekannte ids: Rest in alter Reihenfolge hinten an, nichts geht verloren', () => {
  const r = reorderMarks(M, 'team', ['t2', 'x', 't2']);
  assert.equal(ids(r), 's1,t2,s2,t1,t3');
  assert.equal(r.length, M.length);
});
test('Original unverändert', () => {
  reorderMarks(M, 'team', ['t3']);
  assert.equal(ids(M), 's1,t1,s2,t2,t3');
});
