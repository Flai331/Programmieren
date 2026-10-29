import test from 'node:test';
import assert from 'node:assert/strict';
import { contentBounds } from '../web/pdf.js';
import { cellBounds, makeGrid } from '../web/grid.js';

const grid = makeGrid({ north: 51.01, south: 51.0, west: 7.0, east: 7.02 }, 100);

test('contentBounds: nichts eingezeichnet -> null', () => {
  assert.equal(contentBounds({ grid, fills: {}, status: {}, items: [] }), null);
});

test('contentBounds: umfasst markierte Felder, Zeichnungen und B-Ort', () => {
  const state = {
    grid,
    fills: { '2,3': '#f00' },
    status: { '10,1': '#0f0' },
    items: [{ kind: 'stroke', pts: [[51.0005, 7.019]], color: '#00f', w: 3 }],
    meet: { lat: 51.009, lon: 7.001 },
  };
  const b = contentBounds(state);
  const a = cellBounds(grid, 2, 3);
  const c = cellBounds(grid, 10, 1);
  const e = 1e-9;
  assert.ok(b.west <= 7.001 + e && b.east >= 7.019 - e);
  assert.ok(b.north >= 51.009 - e && b.south <= 51.0005 + e);
  assert.ok(b.north >= Math.max(a.north, c.north) - e && b.west <= a.west + e && b.east >= c.east - e);
  // nicht das ganze Raster
  assert.ok(b.south > 50.999 && b.east < 7.0201);
});

test('contentBounds: Platz für Beschriftung rechts vom Text', () => {
  const state = {
    grid, fills: {}, status: {}, items: [
      { kind: 'text', lat: 51.005, lon: 7.0, text: 'A', color: '#000' },
      { kind: 'text', lat: 51.005, lon: 7.02, text: 'Hochsitz am Waldrand', color: '#000' },
    ],
  };
  const plain = contentBounds(state);
  const withLabel = contentBounds(state, 1.5, 280);
  assert.ok(withLabel.east > plain.east);
  assert.ok(Math.abs(withLabel.west - plain.west) < 1e-9);
});
