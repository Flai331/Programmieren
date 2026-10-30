import { test } from 'node:test';
import assert from 'node:assert/strict';
import { placeBadges, boxOf } from '../web/badgeplace.js';

const view = { w: 1000, h: 800 };
const ov = (a, b) => Math.max(0, Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0)) * Math.max(0, Math.min(a.y1, b.y1) - Math.max(a.y0, b.y0));
const rect = (p, w, h) => boxOf(p.x0, p.y0, w, h);

test('Plakette steht außerhalb des Gebiets (oben)', () => {
  const area = { x0: 400, y0: 300, x1: 600, y1: 500 };
  const [p] = placeBadges([{ area, w: 120, h: 38 }], [], view);
  assert.equal(ov(rect(p, 120, 38), area), 0);
  assert.ok(p.y0 + 38 <= area.y0, 'über dem Gebiet');
  assert.equal(p.ay, area.y0); // Linie endet am Rand
});

test('weicht einer Markierung aus', () => {
  const area = { x0: 400, y0: 300, x1: 600, y1: 500 };
  const mark = { x0: 420, y0: 240, x1: 580, y1: 295 }; // genau über dem Gebiet
  const [p] = placeBadges([{ area, w: 120, h: 38 }], [mark], view);
  const r = rect(p, 120, 38);
  assert.equal(ov(r, area), 0);
  assert.equal(ov(r, mark), 0);
});

test('zwei Plaketten überdecken sich nicht', () => {
  const a = { x0: 400, y0: 300, x1: 500, y1: 400 };
  const b = { x0: 505, y0: 300, x1: 605, y1: 400 };
  const [p, q] = placeBadges([{ area: a, w: 160, h: 38 }, { area: b, w: 160, h: 38 }], [], view);
  assert.equal(ov(rect(p, 160, 38), rect(q, 160, 38)), 0);
  assert.equal(ov(rect(p, 160, 38), a), 0);
  assert.equal(ov(rect(q, 160, 38), b), 0);
});

test('Gebiet am oberen Rand: Plakette bleibt sichtbar und außerhalb', () => {
  const area = { x0: 300, y0: 2, x1: 500, y1: 200 };
  const [p] = placeBadges([{ area, w: 120, h: 38 }], [], view);
  const r = rect(p, 120, 38);
  assert.ok(r.y0 >= 0 && r.x0 >= 0 && r.x1 <= view.w && r.y1 <= view.h);
  assert.equal(ov(r, area), 0);
});

test('Gebiet größer als der Bildschirm: Plakette bleibt am Gebiet (nicht ins Bild geschoben)', () => {
  const area = { x0: -500, y0: -500, x1: 1500, y1: 1500 };
  const [p] = placeBadges([{ area, w: 120, h: 38 }], [], view);
  const r = rect(p, 120, 38);
  assert.equal(ov(r, area), 0);
  assert.ok(r.x1 <= 0 || r.y1 <= 0 || r.x0 >= view.w || r.y0 >= view.h, 'außerhalb des Bildes');
});

test('Gebiet außerhalb des Bildes: Plakette auch', () => {
  const area = { x0: 2000, y0: 300, x1: 2200, y1: 500 };
  const [p] = placeBadges([{ area, w: 120, h: 38 }], [], view);
  assert.ok(p.x0 + 120 > 1500, 'nahe am Gebiet');
});

test('Gebiet am rechten Rand: Plakette auf der sichtbaren Seite', () => {
  const area = { x0: view.w - 150, y0: 300, x1: view.w + 300, y1: 500 };
  const [p] = placeBadges([{ area, w: 120, h: 38 }], [], view);
  const r = rect(p, 120, 38);
  assert.ok(r.x0 >= 0 && r.x1 <= view.w && r.y0 >= 0 && r.y1 <= view.h);
  assert.equal(ov(r, area), 0);
});

test('nicht unter Knöpfen am Rand', () => {
  const area = { x0: 20, y0: 300, x1: 220, y1: 500 };
  const ui = [{ x0: 0, y0: 0, x1: 70, y1: 800 }, { x0: 0, y0: 0, x1: 1000, y1: 60 }];
  const [p] = placeBadges([{ area, w: 160, h: 38 }], [], view, ui);
  const r = rect(p, 160, 38);
  assert.equal(ov(r, ui[0]) + ov(r, ui[1]), 0);
  assert.equal(ov(r, area), 0);
});
