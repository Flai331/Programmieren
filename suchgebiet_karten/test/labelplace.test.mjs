import test from 'node:test';
import assert from 'node:assert/strict';
import { pickLabelPos } from '../web/render.js';

const hits = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;

test('pickLabelPos: frei -> rechts neben der Plakette', () => {
  const p = pickLabelPos(100, 100, 10, 60, 12, []);
  assert.equal(p.align, 'left');
  assert.equal(p.x, 114);
  assert.equal(p.y, 100);
});

test('pickLabelPos: rechts belegt (Lage-Ort-Name) -> weicht aus, ohne zu überlappen', () => {
  const taken = [{ x: 105, y: 90, w: 120, h: 20 }];
  const p = pickLabelPos(100, 100, 10, 60, 12, taken);
  assert.notEqual(p.align, 'left');
  assert.ok(!taken.some((b) => hits(p.box, b)));
});

test('pickLabelPos: alles belegt -> rechts als Rückfall', () => {
  const taken = [{ x: -1000, y: -1000, w: 3000, h: 3000 }];
  const p = pickLabelPos(100, 100, 10, 60, 12, taken);
  assert.equal(p.align, 'left');
  assert.equal(p.x, 114);
});

test('pickLabelPos: zwei Meldungen nebeneinander bekommen getrennte Plätze', () => {
  const taken = [];
  const a = pickLabelPos(100, 100, 10, 80, 12, taken);
  taken.push(a.box);
  const b = pickLabelPos(100, 108, 10, 80, 12, taken);
  assert.ok(!hits(a.box, b.box));
});

test('pickLabelPos: rechts frei, aber über den Bildrand -> innerhalb bleiben', () => {
  const p = pickLabelPos(380, 100, 10, 60, 12, [], 4, { w: 400, h: 300 });
  assert.equal(p.align, 'right');
  assert.ok(p.box.x >= 0 && p.box.x + p.box.w <= 400);
});
