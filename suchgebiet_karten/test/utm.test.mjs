import test from 'node:test';
import assert from 'node:assert/strict';
import { toUtm, fromUtm, formatMgrs, formatUtm } from '../web/utm.js';

// Referenzwerte aus pyproj (EPSG:326xx/327xx) und der mgrs-Bibliothek
const REF = [
  [50.11861, 8.61259, 32, 472303.86, 5551890.29, '32U MA 7230 5189'],
  [52.516275, 13.377704, 33, 389918.04, 5819699.13, '33U UU 8991 1969'],
  [51.0, 6.5, 32, 324587.53, 5652799.8, '32U LB 2458 5279'],
  [53.55, 9.99, 32, 565590.94, 5933912.17, '32U NE 6559 3391'],
  [47.42, 10.98, 32, 649344.5, 5253739.37, '32T PT 4934 5373'],
  [-33.86, 151.21, 56, 334416.39, 6251925.36, '56H LH 3441 5192'],
];

test('UTM stimmt mit pyproj überein (< 5 cm)', () => {
  for (const [lat, lon, zone, e, n] of REF) {
    const u = toUtm(lat, lon);
    assert.equal(u.zone, zone);
    assert.ok(Math.abs(u.easting - e) < 0.05, `${lat},${lon} E ${u.easting} vs ${e}`);
    assert.ok(Math.abs(u.northing - n) < 0.05, `${lat},${lon} N ${u.northing} vs ${n}`);
  }
});

test('UTM hin und zurück', () => {
  for (const [lat, lon] of REF) {
    const u = toUtm(lat, lon);
    const p = fromUtm(u.zone, u.easting, u.northing, u.south);
    assert.ok(Math.abs(p.lat - lat) < 1e-7 && Math.abs(p.lon - lon) < 1e-7);
  }
});

test('UTMREF/MGRS', () => {
  for (const [lat, lon, , , , m] of REF) assert.equal(formatMgrs(lat, lon), m);
  assert.equal(formatUtm(50.11861, 8.61259), '32U 472304 5551890');
});
