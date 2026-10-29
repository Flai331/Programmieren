import test from 'node:test';
import assert from 'node:assert/strict';
import { POI_CATS, newPoi, normalizePois, poiCat, poiLabel, poiName, sortPois } from '../web/pois.js';
import { newProject, normalizeProject } from '../web/store.js';
import { buildGpx } from '../web/gpx.js';
import { makeGrid } from '../web/grid.js';

test('newPoi: feste ID, gerundete Koordinaten, Kategorie geprüft', () => {
  const a = newPoi({ cat: 'elw', lat: 52.6123456789, lon: 10.0712345678, name: ' ELW 11-1 ', by: 'Tablet' }, 1700000000000);
  const b = newPoi({ cat: 'elw', lat: 52.6, lon: 10.07 }, 1700000000000);
  assert.notEqual(a.id, b.id);
  assert.equal(a.lat, 52.612346);
  assert.equal(a.name, 'ELW 11-1');
  assert.equal(a.t, 1700000000000);
  assert.equal(a.by, 'Tablet');
  assert.equal(newPoi({ cat: 'quatsch', lat: 1, lon: 1 }).cat, 'other');
});

test('Namen und Sortierung', () => {
  const p = newPoi({ cat: 'wc', lat: 1, lon: 1 });
  assert.equal(poiName(p), 'Toilette');
  assert.equal(poiLabel(p), '🚻 Toilette');
  const list = sortPois([newPoi({ cat: 'san', lat: 1, lon: 1 }), newPoi({ cat: 'elw', lat: 1, lon: 1 }), newPoi({ cat: 'park', lat: 1, lon: 1, name: 'B' }), newPoi({ cat: 'park', lat: 1, lon: 1, name: 'A' })]);
  assert.deepEqual(list.map(poiName), ['ELW', 'A', 'B', 'Sanität']);
  assert.equal(POI_CATS.length, 9);
  assert.equal(poiCat('lkl').label, 'Letzter bekannter Ort');
});

test('normalizeProject: kaputte Lage-Orte fliegen raus', () => {
  const p = normalizeProject({ ...newProject('x'), pois: [{ id: 'a', cat: 'elw', lat: 1, lon: 2 }, { id: 'b', lat: 'x', lon: 1 }, null, { cat: 'elw', lat: 1, lon: 1 }] });
  assert.equal(p.pois.length, 1);
  assert.equal(p.pois[0].name, '');
  assert.deepEqual(normalizePois(undefined), []);
});

test('GPX: Lage-Orte als Wegpunkte mit Symbol', () => {
  const p = newProject('Übung');
  p.pois.push(newPoi({ cat: 'san', lat: 52.62, lon: 10.07, name: 'RTW', desc: 'am Waldparkplatz' }));
  const grid = makeGrid({ north: 52.63, south: 52.61, west: 10.06, east: 10.09 }, 100);
  const gpx = buildGpx(p, grid, { points: true, tracks: false, drawings: false, teams: false, grid: 'none', cells: 'none' });
  assert.match(gpx, /<name>RTW<\/name>/);
  assert.match(gpx, /<desc>Sanität – am Waldparkplatz<\/desc>/);
  assert.match(gpx, /<sym>Medical Facility<\/sym>/);
});
