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
