import test from 'node:test';
import assert from 'node:assert/strict';
import { areaBounds, areaPoints, navTargets, navUrl } from '../web/hfnav.js';
import { newProject } from '../web/store.js';

const base = () => {
  const p = newProject('Auftrag');
  p.area = { north: 52.52, south: 52.5, west: 9.7, east: 9.72 };
  p.cellM = 100;
  p.fills = {};
  return p;
};

test('navUrl: Google-Maps-Route zum Ziel', () => {
  assert.equal(navUrl(52.5, 9.7), 'https://www.google.com/maps/dir/?api=1&destination=52.500000,9.700000');
});

test('areaBounds: ganzes Raster, wenn das Team keine Felder hat; sonst nur die Felder des Teams', () => {
  const p = base();
  assert.deepEqual(areaBounds(p), [[52.5, 9.7], [52.52, 9.72]]);
  p.fills = { '0,0': 'team', '1,0': 'team', '5,5': 'others' };
  const b = areaBounds(p);
  assert.ok(b[0][0] > 52.5 && b[1][0] <= 52.52 + 1e-9 && b[1][1] < 9.72);
  assert.equal(areaPoints(p).length, 4);
});

test('areaBounds: Umrisse der Einsatzleitung zählen, vorheriges Team und offene Wege nicht; kein Gebiet -> null', () => {
  const p = newProject('x');
  assert.equal(areaBounds(p), null);
  p.items = [
    { kind: 'track', fromEl: true, pts: [[52.6, 9.8], [52.6, 9.9], [52.7, 9.85]] },
    { kind: 'track', fromEl: true, prev: 'Team 1', pts: [[10, 10], [10, 11], [11, 10]] },
    { kind: 'track', fromEl: true, open: true, pts: [[20, 20], [20, 21], [21, 20]] },
    { kind: 'track', pts: [[30, 30], [30, 31], [31, 30]] },
  ];
  assert.deepEqual(areaBounds(p), [[52.6, 9.8], [52.7, 9.9]]);
});

test('navTargets: nur Ziele, die es im Auftrag gibt', () => {
  const p = newProject('x');
  assert.deepEqual(navTargets(p), []);
  p.meet = { lat: 52.5, lon: 9.7, text: 'Feuerwehrhaus' };
  assert.deepEqual(navTargets(p).map((t) => t.key), ['meet']);
  assert.equal(navTargets(p)[0].label, 'B-Ort (Feuerwehrhaus)');
  p.pois = [{ id: 'p1', cat: 'park', name: '', lat: 52.51, lon: 9.71 }, { id: 'p2', cat: 'elw', lat: 1, lon: 1 }];
  p.items = [{ kind: 'track', fromEl: true, pts: [[52.6, 9.8], [52.6, 9.9], [52.7, 9.85]] }];
  const t = navTargets(p);
  assert.deepEqual(t.map((x) => x.key), ['poi-p1', 'meet', 'area']);
  assert.equal(t[0].label, 'Parkplatz');
  assert.equal(t[2].url, navUrl(52.65, 9.85));
  assert.ok(t.every((x) => x.url.startsWith('https://www.google.com/maps/dir/?api=1&destination=')));
});
