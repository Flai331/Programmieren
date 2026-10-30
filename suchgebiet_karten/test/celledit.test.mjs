import test from 'node:test';
import assert from 'node:assert/strict';
import { cellEditable, cellLayers, canPaint } from '../web/celledit.js';

const vis = { id: 'a', kind: 'team', hidden: false };
const hid = { id: 'b', kind: 'team', hidden: true };
const sVis = { id: 's', kind: 'status', hidden: false };
const sHid = { id: 't', kind: 'status', hidden: true };

test('Raster ausgeblendet: nichts veränderbar', () => {
  assert.equal(cellEditable({ hideGrid: true, fillMark: null, statusMark: null }), false);
  assert.deepEqual(cellLayers({ hideGrid: true, fillMark: vis, statusMark: sVis }), { team: false, status: false });
});
test('leeres oder sichtbar belegtes Feld ist veränderbar', () => {
  assert.equal(cellEditable({ hideGrid: false, fillMark: null, statusMark: null }), true);
  assert.equal(cellEditable({ hideGrid: false, fillMark: vis, statusMark: sVis }), true);
});
test('nur über ausgeblendete Markierungen belegt: nicht veränderbar', () => {
  assert.equal(cellEditable({ hideGrid: false, fillMark: hid, statusMark: null }), false);
  assert.equal(cellEditable({ hideGrid: false, fillMark: null, statusMark: sHid }), false);
  assert.equal(cellEditable({ hideGrid: false, fillMark: hid, statusMark: sHid }), false);
});
test('gemischt: nur die sichtbare Ebene ist veränderbar', () => {
  assert.deepEqual(cellLayers({ hideGrid: false, fillMark: hid, statusMark: sVis }), { team: false, status: true });
  assert.deepEqual(cellLayers({ hideGrid: false, fillMark: vis, statusMark: sHid }), { team: true, status: false });
  assert.equal(cellEditable({ hideGrid: false, fillMark: hid, statusMark: sVis }), true);
});
test('Malen: ausgeblendete aktive Markierung tut nichts, versteckte Ebene wird nicht überschrieben', () => {
  assert.equal(canPaint({ hideGrid: false, mark: hid, fillMark: null, statusMark: null }), false);
  assert.equal(canPaint({ hideGrid: true, mark: vis, fillMark: null, statusMark: null }), false);
  assert.equal(canPaint({ hideGrid: false, mark: vis, fillMark: hid, statusMark: null }), false);
  assert.equal(canPaint({ hideGrid: false, mark: sVis, fillMark: hid, statusMark: null }), false);
  assert.equal(canPaint({ hideGrid: false, mark: vis, fillMark: null, statusMark: sHid }), false);
  assert.equal(canPaint({ hideGrid: false, mark: vis, fillMark: null, statusMark: sVis }), true);
  assert.equal(canPaint({ hideGrid: false, mark: vis, fillMark: hid, statusMark: sVis }), false);
  assert.equal(canPaint({ hideGrid: false, mark: sVis, fillMark: hid, statusMark: sVis }), true);
  assert.equal(canPaint({ hideGrid: false, mark: null }), false);
});
