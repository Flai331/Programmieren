import test from 'node:test';
import assert from 'node:assert/strict';
import { parseQuery } from '../web/search.js';

test('Suche erkennt Feld, Koordinaten und Adresse', () => {
  assert.deepEqual(parseQuery('c4'), { type: 'cell', c: 2, r: 3 });
  assert.deepEqual(parseQuery('50.12, 8.61'), { type: 'coords', lat: 50.12, lon: 8.61 });
  assert.deepEqual(parseQuery('50,12 8,61'), { type: 'coords', lat: 50.12, lon: 8.61 });
  assert.deepEqual(parseQuery('50.12;8.61'), { type: 'coords', lat: 50.12, lon: 8.61 });
  assert.deepEqual(parseQuery('Hauptstraße 5, Bielefeld'), { type: 'address', q: 'Hauptstraße 5, Bielefeld' });
  assert.equal(parseQuery('   '), null);
  assert.equal(parseQuery('95.1, 8.6').type, 'address');
});
