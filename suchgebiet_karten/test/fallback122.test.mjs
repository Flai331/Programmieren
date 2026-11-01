import test from 'node:test';
import assert from 'node:assert/strict';
import { LAYERS, OVERLAYS, FALLBACK, isBkg, tileUrl } from '../web/layers.js';

test('v122: BKG-Karten erkannt, Luftbilder und Ersatzkarte nicht', () => {
  assert.deepEqual(LAYERS.filter(isBkg).map((l) => l.id), ['topplus', 'basemapde', 'basemapde-grau']);
  assert.equal(isBkg(OVERLAYS[0]), true);
  assert.equal(isBkg(FALLBACK), false);
  assert.equal(isBkg({ url: 'https://evil.example/geodatenzentrum.de/x' }), false);
  assert.equal(isBkg(null), false);
});

test('v122: Ersatzkarte liefert OSM-Kachel-URLs und ist nicht wählbar', () => {
  assert.equal(tileUrl(FALLBACK, 10, 536, 335), 'https://tile.openstreetmap.org/10/536/335.png');
  assert.ok(!LAYERS.includes(FALLBACK));
});
