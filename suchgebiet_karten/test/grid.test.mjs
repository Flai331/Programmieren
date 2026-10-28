import test from 'node:test';
import assert from 'node:assert/strict';
import {
  colName, colIndex, cellLabel, parseCell, makeGrid, remapCells, cellAt, cellBounds, gridBounds,
  blocks, rangeBounds, fitBox, mercX, mercY, mercLat, mercLon, niceScale, niceLength,
} from '../web/grid.js';
import { planSheets, pageSize, mapArea, resolveOrient } from '../web/pdf.js';

const AREA = { north: 50.12, south: 50.1, west: 8.6, east: 8.64 };

test('Spaltennamen', () => {
  assert.equal(colName(0), 'A');
  assert.equal(colName(25), 'Z');
  assert.equal(colName(26), 'AA');
  assert.equal(colName(27), 'AB');
  assert.equal(colName(701), 'ZZ');
  for (const i of [0, 5, 25, 26, 100, 701]) assert.equal(colIndex(colName(i)), i);
});

test('Feld parsen', () => {
  assert.deepEqual(parseCell('c4'), { c: 2, r: 3 });
  assert.deepEqual(parseCell(' AA 10 '), { c: 26, r: 9 });
  assert.equal(parseCell('4C'), null);
  assert.equal(parseCell('A0'), null);
  assert.equal(cellLabel(2, 3), 'C4');
});

test('Raster hat echte Meter-Felder und deckt das Gebiet ab', () => {
  const g = makeGrid(AREA, 100);
  assert.ok(Math.abs(g.dLat * 111320 - 100) < 1e-6);
  const gb = gridBounds(g);
  assert.ok(gb.south <= AREA.south && gb.east >= AREA.east);
  assert.equal(gb.north, AREA.north);
  assert.equal(gb.west, AREA.west);
  assert.equal(g.rows, Math.ceil((0.02 * 111320) / 100));
});

test('Aufziehrichtung egal', () => {
  const a = makeGrid(AREA, 100);
  const b = makeGrid({ north: AREA.south, south: AREA.north, west: AREA.east, east: AREA.west }, 100);
  assert.deepEqual(a, b);
});

test('cellAt und cellBounds passen zusammen', () => {
  const g = makeGrid(AREA, 250);
  for (let c = 0; c < g.cols; c++) {
    for (let r = 0; r < g.rows; r++) {
      const b = cellBounds(g, c, r);
      assert.deepEqual(cellAt(g, (b.north + b.south) / 2, (b.west + b.east) / 2), { c, r });
    }
  }
  assert.equal(cellAt(g, AREA.north + 0.001, AREA.west + 0.001), null);
});

test('Detailblätter decken alle Felder genau einmal ab', () => {
  const g = makeGrid(AREA, 100);
  const seen = new Set();
  for (const b of blocks(g, 3)) {
    for (let c = b.c0; c <= b.c1; c++) for (let r = b.r0; r <= b.r1; r++) {
      const k = `${c},${r}`;
      assert.ok(!seen.has(k));
      seen.add(k);
    }
  }
  assert.equal(seen.size, g.cols * g.rows);
});

test('A1 im Detailblatt = A1 in der Übersicht (gleiche Koordinaten)', () => {
  const g = makeGrid(AREA, 100);
  const first = blocks(g, 3)[0];
  const rb = rangeBounds(g, first.c0, first.r0, first.c1, first.r1);
  const a1 = cellBounds(g, 0, 0);
  assert.equal(rb.north, a1.north);
  assert.equal(rb.west, a1.west);
});

test('Mercator hin und zurück', () => {
  for (const [lat, lon] of [[50.1, 8.6], [-33.9, 151.2], [0, 0]]) {
    assert.ok(Math.abs(mercLat(mercY(lat)) - lat) < 1e-9);
    assert.ok(Math.abs(mercLon(mercX(lon)) - lon) < 1e-9);
  }
});

test('fitBox hält Seitenverhältnis und enthält das Gebiet', () => {
  const box = fitBox(AREA, 281 / 166, 0.05);
  assert.ok(Math.abs((box.x1 - box.x0) / (box.y1 - box.y0) - 281 / 166) < 1e-9);
  assert.ok(box.x0 < mercX(AREA.west) && box.x1 > mercX(AREA.east));
  assert.ok(box.y0 < mercY(AREA.north) && box.y1 > mercY(AREA.south));
});

test('Maßstab und Maßstabsleiste runden sinnvoll', () => {
  assert.equal(niceScale(4870), 5000);
  assert.equal(niceScale(12400), 12500);
  assert.equal(niceLength(730), 500);
  assert.equal(niceLength(2400), 2000);
});

test('PDF-Blattplanung', () => {
  const g = makeGrid(AREA, 100);
  const n = blocks(g, 3).length;
  const sheets = planSheets(g, { overview: true, details: true, k: 3, view: true, info: true }, AREA);
  assert.equal(sheets.length, 1 + 1 + n + 1);
  assert.match(sheets[0].title, /^Übersicht – Felder A1–/);
  assert.ok(sheets[1].info);
  assert.equal(sheets[0].outlines.length, n);
  assert.equal(sheets[0].outlines[0].page, 3);
  assert.match(sheets[2].title, /^Blatt 3 – Felder A1–C3$/);
  // Seitenzahl im Übersichts-Umriss = tatsächliche Seite des Blatts
  sheets[0].outlines.forEach((o) => assert.match(sheets[o.page - 1].title, new RegExp(`^Blatt ${o.page} – Felder ${o.label}$`)));
  assert.equal(planSheets(null, { overview: true, details: true, view: false, info: true }, AREA).length, 0);
  assert.equal(planSheets(g, { overview: false, details: true, k: 3 }, AREA)[0].title, 'Blatt 1 – Felder A1–C3');
  assert.deepEqual(pageSize('A4', 'portrait'), [210, 297]);
  assert.ok(mapArea('A3', 'landscape').w > mapArea('A4', 'landscape').w);
});

test('Standard-PDF: ganzes Suchgebiet auf genau einer Seite, passende Ausrichtung', () => {
  const g = makeGrid(AREA, 100); // ca. 2,9 km breit, 2,2 km hoch
  const sheets = planSheets(g, { overview: true, details: false, info: false, view: false }, AREA);
  assert.equal(sheets.length, 1);
  assert.equal(resolveOrient('auto', sheets), 'landscape');
  const tall = makeGrid({ north: 50.2, south: 50.1, west: 8.6, east: 8.65 }, 250);
  assert.equal(resolveOrient('auto', planSheets(tall, { overview: true }, AREA)), 'portrait');
  assert.equal(resolveOrient('portrait', sheets), 'portrait');
});

const area = { north: 51.01, south: 51.0, west: 7.0, east: 7.02 };

test('remapCells: 200 m -> 100 m, jedes große Feld wird zu 2×2 kleinen', () => {
  const big = makeGrid(area, 200);
  const small = makeGrid(area, 100);
  const out = remapCells(big, small, { '0,0': 't1', '2,1': 's' });
  assert.deepEqual(Object.keys(out).filter((k) => out[k] === 't1').sort(), ['0,0', '0,1', '1,0', '1,1']);
  assert.deepEqual(Object.keys(out).filter((k) => out[k] === 's').sort(), ['4,2', '4,3', '5,2', '5,3']);
});

test('remapCells: 100 m -> 200 m, Mehrheit entscheidet', () => {
  const small = makeGrid(area, 100);
  const big = makeGrid(area, 200);
  const out = remapCells(small, big, { '0,0': 'a', '1,0': 'a', '0,1': 'a', '2,0': 'b' });
  assert.equal(out['0,0'], 'a');
  assert.equal(out['1,0'], undefined); // nur ein Viertel markiert
});

test('remapCells: verschobenes Gebiet behält die Lage', () => {
  const g1 = makeGrid(area, 100);
  const g2 = makeGrid({ ...area, west: 7.0 - g1.dLon * 3 }, 100);
  const out = remapCells(g1, g2, { '0,0': 'x' });
  assert.deepEqual(out, { '3,0': 'x' });
});
