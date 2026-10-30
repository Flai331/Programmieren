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

test('Quadrate: Schlüssel, Grenzen, Schätzung über mehrere Quadrate', async () => {
  const { squareKey, squareBounds, unionBounds, areasOf, estimate: est, nativeJob } = await import('../web/offline.js');
  const k = squareKey(52.2, 8.05);
  const sb = squareBounds(k);
  assert.ok(sb.south <= 52.2 && sb.north > 52.2 && sb.west <= 8.05 && sb.east > 8.05);
  const k2 = squareKey(52.2, 8.15);
  const areas = [sb, squareBounds(k2)];
  const one = est([dop], [sb], 15, 18);
  const two = est([dop], areas, 15, 18);
  assert.ok(two.tiles > one.tiles * 1.8);
  // ~5,5 km Quadrat, Stufe 15–18 Luftbild: grob 100–300 MB
  assert.ok(one.mb > 60 && one.mb < 400, String(one.mb));
  const u = unionBounds(areas);
  assert.equal(u.west, sb.west);
  assert.equal(areasOf({ bounds: u }).length, 1);
  assert.equal(nativeJob({ id: 'a', bounds: u, areas, zMin: 15, zMax: 18 }, [dop]).areas.length, 2);
});

test('missionBounds: alles vom Einsatz mit Rand, null ohne Inhalt', async () => {
  const { missionBounds } = await import('../web/offline.js');
  assert.equal(missionBounds({ items: [], pois: [] }), null);
  const p = {
    area: { north: 52.2, south: 52.19, west: 8.19, east: 8.2 },
    otherGrids: [], items: [{ kind: 'track', pts: [[52.21, 8.18], [52.205, 8.185]] }, { kind: 'text', lat: 52.18, lon: 8.21 }],
    meet: { lat: 52.185, lon: 8.205 }, pois: [{ lat: 52.215, lon: 8.2 }],
  };
  const m = missionBounds(p, 0);
  assert.deepEqual(m, { north: 52.215, south: 52.18, west: 8.18, east: 8.21 });
  const r = missionBounds(p, 500);
  assert.ok(Math.abs(r.north - 52.215 - 0.00449) < 0.0001);
  assert.ok(r.west < 8.18 - 0.007);
});

test('packageZooms: so scharf wie das Budget erlaubt', async () => {
  const { packageZooms } = await import('../web/offline.js');
  const big = packageZooms([topo], b, { budgetMB: 1e6 });
  assert.equal(big.zMax, Math.min(17, topo.maxNative || 18));
  const small = packageZooms([topo], b, { budgetMB: 0.001 });
  assert.equal(small.zMax, 14);
  const mid = packageZooms([topo], b, { budgetMB: estimate([topo], b, 12, 15).mb + 0.01 });
  assert.equal(mid.zMax, 15);
});
