import test from 'node:test';
import assert from 'node:assert/strict';
import { removeVertex, insertVertex, moveVertex, edgeMids, vertexCount, dupEnd, minPoints } from '../web/vertex.js';

const sq = () => [[0, 0], [0, 2], [2, 2], [2, 0]];

test('Punkt löschen: Mindestzahl 3 (Umriss) bzw. 2 (Linie)', () => {
  const p = sq();
  assert.equal(removeVertex(p, 1, false), true);
  assert.equal(p.length, 3);
  assert.equal(removeVertex(p, 0, false), false);
  assert.equal(p.length, 3);
  const l = [[0, 0], [1, 1], [2, 2]];
  assert.equal(removeVertex(l, 1, true), true);
  assert.equal(removeVertex(l, 0, true), false);
  assert.deepEqual(l, [[0, 0], [2, 2]]);
  assert.equal(minPoints(true), 2);
  assert.equal(minPoints(false), 3);
});

test('Punkt einfügen hinter Kante', () => {
  const p = sq();
  assert.equal(insertVertex(p, 3, 1, 0), 4);
  assert.deepEqual(p[4], [1, 0]);
  assert.equal(insertVertex(p, 0, 0, 1), 1);
  assert.deepEqual(p.slice(0, 3), [[0, 0], [0, 1], [0, 2]]);
});

test('Kanten-Mitten: Umriss hat n, offene Linie n-1', () => {
  const m = edgeMids(sq(), false);
  assert.equal(m.length, 4);
  assert.deepEqual(m[3], { i: 3, lat: 1, lon: 0 }); // letzter -> erster
  assert.equal(edgeMids(sq(), true).length, 3);
});

test('doppelter Schlusspunkt: zählt nicht, zieht mit, keine Extra-Kante', () => {
  const p = [[0, 0], [0, 2], [2, 2], [2, 0], [0, 0]];
  assert.equal(dupEnd(p, false), true);
  assert.equal(dupEnd(p, true), false);
  assert.equal(vertexCount(p, false), 4);
  assert.equal(edgeMids(p, false).length, 4);
  moveVertex(p, 0, 5, 5, false);
  assert.deepEqual(p[4], [5, 5]);
  assert.equal(removeVertex(p, 0, false), true);
  assert.deepEqual(p[p.length - 1], p[0]);
  assert.equal(vertexCount(p, false), 3);
  assert.equal(removeVertex(p, 0, false), false);
});
