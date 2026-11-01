// v123: Navigation über Google Maps – Link, Ziele der Einsatzleitung, Feldmitte
import test from 'node:test';
import assert from 'node:assert/strict';
import { navUrl, navTargetsAll, navTargets, cellCenter, boxCenter } from '../web/hfnav.js';
import { newProject } from '../web/store.js';
import { makeGrid } from '../web/grid.js';

test('navUrl: Auto, zu Fuß, ungültiger Modus -> Auto', () => {
  const base = 'https://www.google.com/maps/dir/?api=1&destination=52.500000,9.700000';
  assert.equal(navUrl(52.5, 9.7), `${base}&travelmode=driving`);
  assert.equal(navUrl(52.5, 9.7, 'driving'), `${base}&travelmode=driving`);
  assert.equal(navUrl(52.5, 9.7, 'walking'), `${base}&travelmode=walking`);
  assert.equal(navUrl(52.5, 9.7, 'bicycling'), `${base}&travelmode=driving`);
  assert.equal(navUrl(52.5, 9.7, '&evil=1'), `${base}&travelmode=driving`);
});

test('navTargets (HF) liefert weiter Links, jetzt mit Modus Auto', () => {
  const p = newProject('x');
  p.meet = { lat: 52.5, lon: 9.7, text: 'B-Ort' };
  const t = navTargets(p);
  assert.equal(t.length, 1);
  assert.ok(t[0].url.endsWith('travelmode=driving'));
});

test('cellCenter: Mitte von C4, außerhalb und Unsinn -> null', () => {
  const g = makeGrid({ north: 52.52, south: 52.5, west: 9.7, east: 9.72 }, 100);
  const c = cellCenter(g, 'C4');
  assert.ok(c[0] < 52.52 && c[0] > 52.5 && c[1] > 9.7 && c[1] < 9.72);
  const a1 = cellCenter(g, 'a1');
  assert.ok(c[0] < a1[0] && c[1] > a1[1]); // C4 liegt südlich und östlich von A1
  assert.equal(cellCenter(g, 'ZZ99'), null);
  assert.equal(cellCenter(g, 'Hallo'), null);
  assert.equal(cellCenter(null, 'C4'), null);
});

test('boxCenter: Rechteckmitte, leer -> null', () => {
  assert.deepEqual(boxCenter([[1, 2], [3, 8], [2, 4]]), [2, 5]);
  assert.equal(boxCenter([]), null);
});

test('navTargetsAll: leeres Projekt -> []', () => {
  assert.deepEqual(navTargetsAll(newProject('leer')), []);
});

test('navTargetsAll: B-Ort, Lage-Orte, geschlossener Umriss (offener nicht), Raster, Meldung', () => {
  const p = newProject('Einsatz');
  p.meet = { lat: 52.51, lon: 9.71, text: 'B-Ort' };
  p.pois = [
    { id: 'a', cat: 'park', name: 'P Nord', lat: 52.515, lon: 9.705 },
    { id: 'b', cat: 'elw', name: '', lat: 52.505, lon: 9.715 },
  ];
  p.marks = [{ id: 't1', kind: 'team', label: 'Team 1', color: '#f00' }];
  p.items = [
    { kind: 'track', name: 'Nordwald', pts: [[52.50, 9.70], [52.52, 9.70], [52.52, 9.72], [52.50, 9.72]], to: 't1' },
    { kind: 'track', name: 'Weg', open: true, pts: [[52.50, 9.70], [52.52, 9.72], [52.51, 9.71]] },
  ];
  p.area = { north: 52.52, south: 52.5, west: 9.7, east: 9.72 };
  p.cellM = 100;
  p.fills = {};
  p.gridName = 'Raster 1';
  p.otherGrids = [{ id: 'g2', name: 'Raster 2', area: { north: 52.6, south: 52.58, west: 9.8, east: 9.82 }, cellM: 100, fills: {}, status: {} }];
  p.live = { msgs: [
    { v: 1, id: 'm1', a: 'x', tm: 'Team 1', t: Date.UTC(2026, 0, 1, 10, 30), s: 'fund', lat: 52.512, lon: 9.712 },
    { v: 1, id: 'm2', a: 'x', tm: 'Team 1', t: Date.UTC(2026, 0, 1, 10, 31), s: 'start' }, // ohne Ort
  ] };
  const t = navTargetsAll(p);
  const by = (pre) => t.filter((x) => x.key.startsWith(pre));
  assert.equal(by('meet').length, 1);
  assert.equal(by('poi-').length, 2);
  assert.equal(by('poi-')[1].label, 'ELW'); // ohne Namen: Kategorie
  assert.equal(by('outline').length, 1);
  assert.equal(by('outline')[0].label, 'Nordwald');
  assert.equal(by('outline')[0].sub, 'Team 1');
  assert.ok(Math.abs(by('outline')[0].lat - 52.51) < 1e-9 && Math.abs(by('outline')[0].lon - 9.71) < 1e-9);
  assert.equal(by('grid').length, 2);
  assert.deepEqual(by('grid').map((x) => x.label).sort(), ['Raster 1', 'Raster 2']);
  const g1 = by('grid').find((x) => x.label === 'Raster 1');
  assert.ok(g1.lat > 52.5 && g1.lat < 52.52 && g1.lon > 9.7 && g1.lon < 9.72);
  assert.equal(by('msg').length, 1);
  assert.match(by('msg')[0].label, /^Team 1: /);
  assert.equal(by('msg')[0].lat, 52.512);
  assert.equal(t.length, 7);
  for (const x of t) assert.ok(Number.isFinite(x.lat) && Number.isFinite(x.lon) && x.icon && x.label);
});

test('navTargetsAll: gelöschte Meldungen fehlen', () => {
  const p = newProject('x');
  p.live = { msgs: [{ v: 1, id: 'm1', a: 'x', tm: 'T', t: 1000, s: 'hilfe', lat: 52, lon: 9 }] };
  assert.equal(navTargetsAll(p).length, 1);
  p.msgDel = { m1: 5 };
  assert.equal(navTargetsAll(p).length, 0);
});
