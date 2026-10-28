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

test('Photon-Treffer werden lesbar aufbereitet', async () => {
  const { photonPlace } = await import('../web/search.js');
  const r = photonPlace({
    geometry: { coordinates: [8.53, 52.02] },
    properties: { name: 'Wanderparkplatz Hünenburg', osm_value: 'parking', postcode: '33619', city: 'Bielefeld', state: 'Nordrhein-Westfalen', country: 'Deutschland', extent: [8.52, 52.03, 8.54, 52.01] },
  });
  assert.equal(r.name, 'Wanderparkplatz Hünenburg');
  assert.equal(r.sub, 'Parkplatz · 33619 Bielefeld, Nordrhein-Westfalen');
  assert.deepEqual(r.bounds, [52.01, 52.03, 8.52, 8.54]);
  const a = photonPlace({ geometry: { coordinates: [8, 50] }, properties: { street: 'Waldweg', housenumber: '5', city: 'Musterstadt' } });
  assert.equal(a.name, 'Waldweg 5');
});
