import test from 'node:test';
import assert from 'node:assert/strict';
import { tileRange, countTiles, tileUrls, estimate, STATES } from '../web/offline.js';
import { LAYERS } from '../web/layers.js';

const topo = LAYERS.find((l) => l.id === 'topplus');
const dop = LAYERS.find((l) => l.id === 'dop-ni');
const b = { north: 52.21, south: 52.19, west: 8.18, east: 8.22 };

test('countTiles/tileUrls stimmen überein, Adressen wie in der Karte', () => {
  const n = countTiles(topo, b, 10, 15);
  const urls = [...tileUrls(topo, b, 10, 15)];
  assert.equal(urls.length, n);
  assert.ok(urls.every((u) => /\/1[0-5]\/\d+\/\d+\.png$/.test(u)));
  // Zoom 15 deckt ~2,7 km × 2,2 km mit ~1,2-km-Kacheln ab: wenige Kacheln
  const r = tileRange(topo, b, 15);
  assert.ok(r.x1 - r.x0 >= 1 && r.x1 - r.x0 <= 4);
});

test('512er-Luftbild (WMS) liegt eine Adress-Zoomstufe tiefer, nicht über maxNative', () => {
  assert.equal(tileRange(dop, b, 16).zu, 15);
  assert.equal(countTiles(dop, b, 19, 22), countTiles(dop, b, 19, 19));
  const u = [...tileUrls(dop, b, 16, 16)][0];
  assert.match(u, /WIDTH=512&HEIGHT=512/);
});

test('estimate: ganzes Niedersachsen wächst je Stufe etwa ×4', () => {
  const e14 = estimate([dop], STATES.ni.bounds, 6, 14);
  const e16 = estimate([dop], STATES.ni.bounds, 6, 16);
  assert.ok(e16.tiles > e14.tiles * 12 && e16.tiles < e14.tiles * 25);
  assert.ok(e16.mb > 1000);
});

test('nativeJob: Vorlagen für die Android-App ergeben dieselben Adressen', async () => {
  const { nativeJob } = await import('../web/offline.js');
  const job = nativeJob({ id: 'x', name: 'n', bounds: b, zMin: 6, zMax: 16 }, [topo, dop], true);
  assert.equal(job.wifiOnly, true);
  const [lt, ld] = job.layers;
  assert.equal(lt.zoomOffset, 0);
  assert.equal(ld.zoomOffset, 1);
  assert.equal(ld.maxZoom, 19);
  assert.ok(lt.template.includes('{z}/{y}/{x}'));
  assert.ok(ld.wmsPrefix.endsWith('BBOX='));
  for (const s of ld.samples) assert.ok(s.url.startsWith(ld.wmsPrefix));
  // Nachbau der Kotlin-Formel (BBOX mit 2 Nachkommastellen)
  const HALF = 20037508.342789244;
  for (const s of ld.samples) {
    const size = (2 * HALF) / 2 ** s.z;
    const minx = -HALF + s.x * size;
    const maxy = HALF - s.y * size;
    assert.equal(s.url, ld.wmsPrefix + [minx, maxy - size, minx + size, maxy].map((v) => v.toFixed(2)).join(','));
  }
});
