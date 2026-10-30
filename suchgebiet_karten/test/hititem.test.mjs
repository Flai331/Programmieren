import test from 'node:test';
import assert from 'node:assert/strict';
import { hitItem } from '../web/render.js';

const toPx = (lat, lon) => [lon, lat]; // Testkoordinaten = Pixel
const items = [{ kind: 'text', lat: 100, lon: 100, text: 'Fundstelle', color: '#000' }];

test('Text: Punkt und Schrift sind antippbar', () => {
  assert.equal(hitItem(items, toPx, 102, 101, 12), 0);
  assert.equal(hitItem(items, toPx, 160, 104, 12), 0); // mitten in der Schrift
});

test('Text: daneben nicht', () => {
  assert.equal(hitItem(items, toPx, 300, 100, 12), -1);
  assert.equal(hitItem(items, toPx, 150, 140, 12), -1);
  assert.equal(hitItem(items, toPx, 60, 100, 12), -1);
});

import { labelDetail, trackLabel } from '../web/render.js';

test('Beschriftung je Zoomstufe: weit weg nichts, nah alles', () => {
  assert.equal(labelDetail(12), 0);
  assert.equal(labelDetail(14), 0);
  assert.equal(labelDetail(14.4), 0);
  assert.equal(labelDetail(15), 1);
  assert.equal(labelDetail(16), 2);
  assert.equal(labelDetail(16.4), 2);
  assert.equal(labelDetail(17), 3);
  assert.equal(labelDetail(undefined), 3); // PDF: immer alles
  const it = { kind: 'track', name: 'Ost 1', open: false, pts: [[52, 10], [52, 10.001], [51.999, 10.001]] };
  assert.equal(trackLabel(it, 'Team 1', 0), '');
  assert.equal(trackLabel(it, 'Team 1', 1), 'Ost 1');
  assert.equal(trackLabel(it, 'Team 1', 2), 'Ost 1\n→ Team 1');
  assert.match(trackLabel(it, 'Team 1', 3), /^Ost 1\n→ Team 1 · .+ha$/);
  assert.equal(trackLabel({ ...it, name: '' }, 'Team 1', 2), '→ Team 1');
});

test('weit herausgezoomt: Texte nicht antippbar, Umrisse schon', () => {
  const tr = { kind: 'track', w: 4, pts: [[200, 100], [200, 300]] };
  assert.equal(hitItem(items, toPx, 102, 101, 12, 0), -1);
  assert.equal(hitItem([...items, tr], toPx, 200, 202, 12, 0), 1);
});
