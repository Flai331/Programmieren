import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeGrid, fitGridArea } from '../web/grid.js';

const area = { north: 50.01, south: 50, west: 8, east: 8.015 };
const g = makeGrid(area, 100);
const re = (k, ll) => makeGrid(fitGridArea(g, k, ll), 100);

test('Ost-Rand nach außen: mehr Spalten, Höhe gleich', () => {
  const n = re('e', { lat: 50.005, lng: 8.015 + 2.4 * g.dLon });
  assert.equal(n.cols, g.cols + 2); assert.equal(n.rows, g.rows);
  assert.equal(n.originLat, g.originLat); assert.equal(n.originLon, g.originLon);
});
test('Süd-Rand nach innen: weniger Zeilen', () => {
  const s = g.originLat - g.rows * g.dLat;
  const n = re('s', { lat: s + 1.6 * g.dLat, lng: 8 });
  assert.equal(n.rows, g.rows - 2); assert.equal(n.cols, g.cols);
});
test('Nordwest-Ecke: Ursprung wandert, Gegenseite fest', () => {
  const n = re('nw', { lat: g.originLat + g.dLat, lng: g.originLon - 3 * g.dLon });
  assert.equal(n.rows, g.rows + 1); assert.equal(n.cols, g.cols + 3);
  assert.ok(Math.abs(n.originLon + n.cols * n.dLon - (g.originLon + g.cols * g.dLon)) < 1e-9);
});
test('mindestens ein Feld', () => {
  assert.equal(re('e', { lat: 50, lng: 7 }).cols, 1);
  assert.equal(re('n', { lat: 49, lng: 8 }).rows, 1);
});
