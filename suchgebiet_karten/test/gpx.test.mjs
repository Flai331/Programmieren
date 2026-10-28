import test from 'node:test';
import assert from 'node:assert/strict';
import { cellOutlines, buildGpx, garminColor, trackLength } from '../web/gpx.js';
import { makeZip, crc32 } from '../web/zip.js';
import { planCustomMap, TILE, MAX_TILES } from '../web/kmz.js';
import { makeGrid } from '../web/grid.js';
import { newProject } from '../web/store.js';

test('Umriss eines L-förmigen Team-Bereichs', () => {
  // A1, B1, A2 -> ein geschlossener Umriss mit 6 Ecken
  const loops = cellOutlines(['0,0', '1,0', '0,1']);
  assert.equal(loops.length, 1);
  assert.deepEqual(loops[0][0], loops[0][loops[0].length - 1]);
  assert.equal(loops[0].length, 7);
});

test('Getrennte Bereiche ergeben getrennte Umrisse, Loch ergibt eigenen Ring', () => {
  assert.equal(cellOutlines(['0,0', '5,5']).length, 2);
  const ring = [];
  for (let c = 0; c < 3; c++) for (let r = 0; r < 3; r++) if (!(c === 1 && r === 1)) ring.push(`${c},${r}`);
  assert.equal(cellOutlines(ring).length, 2);
});

test('Garmin-Farben', () => {
  assert.equal(garminColor('#d50000'), 'Red');
  assert.equal(garminColor('#1565c0'), 'Blue');
  assert.equal(garminColor('#0000a0'), 'DarkBlue');
  assert.equal(garminColor('#000000'), 'Black');
});

test('Tracklänge', () => {
  const m = trackLength([[50, 8], [50.001, 8]]);
  assert.ok(Math.abs(m - 111.2) < 0.5);
});

test('GPX enthält Track, Team-Umriss, Raster und Wegpunkte', () => {
  const p = newProject('Übung <Wald> & Feld');
  const g = makeGrid({ north: 50.12, south: 50.11, west: 8.6, east: 8.62 }, 200);
  p.marks.push({ id: 't', kind: 'team', label: 'Team 1', dog: 'Bello', color: '#d50000' });
  p.fills = { '0,0': 't', '1,0': 't' };
  p.meet = { lat: 50.115, lon: 8.61, text: 'TP' };
  p.items.push({ kind: 'track', name: 'Suchweg', color: '#1565c0', w: 4, pts: [[50.115, 8.605], [50.116, 8.61]] });
  const gpx = buildGpx(p, g, { tracks: true, teams: true, grid: true, points: true, cells: true });
  assert.match(gpx, /<name>Suchweg<\/name>/);
  assert.match(gpx, /<name>Team 1 \(Bello\)<\/name>/);
  assert.match(gpx, /<gpxx:DisplayColor>Red<\/gpxx:DisplayColor>/);
  assert.match(gpx, /<name>Raster Übung &lt;Wald&gt; &amp; Feld<\/name>/);
  assert.match(gpx, /<sym>Flag, Blue<\/sym>/);
  assert.equal((gpx.match(/<wpt /g) || []).length, 1 + g.cols * g.rows);
  assert.ok(gpx.startsWith('<?xml'));
  // Nur Umrandung: ein Ring mit 5 Punkten, keine Rasterlinien
  const outline = buildGpx(p, g, { grid: 'outline' });
  assert.match(outline, /<name>Suchgebiet Übung/);
  assert.equal((outline.match(/<trkpt /g) || []).length, 5);
  assert.equal(buildGpx(p, g, { grid: 'none' }).includes('<trk>'), false);
});

test('ZIP: Kopf, CRC und Verzeichnis', () => {
  assert.equal(crc32(new TextEncoder().encode('123456789')), 0xcbf43926);
  const z = makeZip([{ name: 'doc.kml', data: new TextEncoder().encode('<kml/>') }]);
  const v = new DataView(z.buffer);
  assert.equal(v.getUint32(0, true), 0x04034b50);
  assert.equal(v.getUint32(z.length - 22, true), 0x06054b50);
});

test('Garmin-Karte hält die Kachelgrenze ein', () => {
  const small = planCustomMap({ north: 50.12, south: 50.1, west: 8.6, east: 8.63 }, 2);
  assert.equal(small.mPerPx, 2);
  assert.ok(small.W > 1000 && small.W < 1200);
  const huge = planCustomMap({ north: 50.5, south: 50, west: 8, east: 9 }, 1);
  assert.ok(huge.tiles <= MAX_TILES && huge.W <= 6144 && huge.mPerPx > 1);
  assert.equal(TILE, 1024);
});

test('WMS-Kacheln mit 512 px decken dieselbe Fläche ab', async () => {
  const { tileUrl, layerById } = await import('../web/layers.js');
  const ni = layerById('dop-ni');
  const u = tileUrl(ni, 1, 0, 0);
  assert.match(u, /WIDTH=512&HEIGHT=512/);
  assert.match(u, /BBOX=-20037508\.34,0\.00,0\.00,20037508\.34/);
});
