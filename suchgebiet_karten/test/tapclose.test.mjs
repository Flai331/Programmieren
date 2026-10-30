import test from 'node:test';
import assert from 'node:assert/strict';
import { tapVerdict, backdropAction, cancelIndex, isProtectedHead } from '../web/tapclose.js';

test('Tipp auf leere Karte schließt nur, wenn etwas offen ist', () => {
  assert.equal(tapVerdict({ dlgOpen: false, target: 'empty', anyOpen: true }), 'close');
  assert.equal(tapVerdict({ dlgOpen: false, target: 'empty', anyOpen: false }), 'none');
  assert.equal(tapVerdict({ dlgOpen: false, target: 'ui', anyOpen: true }), 'none');
});

test('Dialog: nur der dunkle Hintergrund zählt', () => {
  assert.equal(tapVerdict({ dlgOpen: true, target: 'backdrop', anyOpen: true }), 'dlg-backdrop');
  assert.equal(tapVerdict({ dlgOpen: true, target: 'ui', anyOpen: true }), 'none');
});

test('Hintergrund-Tipp löst „Abbrechen“ aus, außer bei Eingaben und geschützten Dialogen', () => {
  const labels = ['💾 Speichern', '🗑 Löschen', 'Abbrechen'];
  assert.equal(cancelIndex(labels), 2);
  assert.equal(backdropAction({ head: '📍 Text', labels }), 2);
  assert.equal(backdropAction({ head: '📍 Text', labels, typed: true }), -1);
  assert.equal(backdropAction({ head: '📍 Text', labels, keep: true }), -1);
  assert.equal(backdropAction({ head: '🔒 Übernommener Auftrag', labels }), -1);
  assert.equal(backdropAction({ head: 'Info', labels: ['OK'] }), -1);
  assert.ok(isProtectedHead('Raster entfernen?'));
});
