import test from 'node:test';
import assert from 'node:assert/strict';
import { einsatzOffen, shouldOfferUpdate, updateText } from '../web/update.js';
import { cancelIndex, backdropAction, tapVerdict, isProtectedHead } from '../web/tapclose.js';

const base = { installed: 99, latest: 100, einsatzOffen: false, later: false };

test('shouldOfferUpdate: neuere Version, kein Einsatz, nicht „Später“', () => {
  assert.equal(shouldOfferUpdate(base), true);
  assert.equal(shouldOfferUpdate({ ...base, latest: 99 }), false);
  assert.equal(shouldOfferUpdate({ ...base, latest: 98 }), false);
  assert.equal(shouldOfferUpdate({ ...base, einsatzOffen: true }), false);
  assert.equal(shouldOfferUpdate({ ...base, later: true }), false);
  assert.equal(shouldOfferUpdate({ ...base, latest: undefined }), false);
  assert.equal(shouldOfferUpdate({ ...base, installed: 'x' }), false);
  assert.equal(shouldOfferUpdate({ ...base, installed: '99', latest: '100' }), true);
});

test('einsatzOffen: EL frei/abgeschlossen = nicht offen, HF nur mit Auftrag', () => {
  assert.equal(einsatzOffen({ mode: 'el', free: true, closed: false }), false);
  assert.equal(einsatzOffen({ mode: 'el', free: false, closed: true }), false);
  assert.equal(einsatzOffen({ mode: 'el', free: false, closed: false }), true);
  assert.equal(einsatzOffen({ mode: 'hf', hfAssigned: false }), false);
  assert.equal(einsatzOffen({ mode: 'hf', hfAssigned: true }), true);
});

test('updateText nennt beide Versionen', () => {
  const t = updateText('1.0.99', '1.0.100');
  assert.match(t, /1\.0\.100/);
  assert.match(t, /1\.0\.99/);
  assert.match(t, /Daten bleiben erhalten/);
});

test('cancelIndex: letzter Abbrechen/Schließen-Knopf', () => {
  assert.equal(cancelIndex(['OK', 'Abbrechen']), 1);
  assert.equal(cancelIndex(['Schließen']), 0);
  assert.equal(cancelIndex(['Jetzt aktualisieren', 'Später']), 1);
  assert.equal(cancelIndex(['OK', 'Weiter']), -1);
  assert.equal(cancelIndex(['Abbrechen und Geladenes löschen', 'Weiter']), -1);
  assert.equal(cancelIndex([]), -1);
});

test('backdropAction: Ausnahmen bleiben offen', () => {
  const labels = ['Senden', 'Abbrechen'];
  assert.equal(backdropAction({ labels, head: '📣 Status melden' }), 1);
  assert.equal(backdropAction({ labels, head: '📣 Status melden', typed: true }), -1);
  assert.equal(backdropAction({ labels, head: 'x', keep: true }), -1);
  assert.equal(backdropAction({ labels, head: '🆘 Dringend (1)' }), -1);
  assert.equal(backdropAction({ labels, head: '🔒 Übernommener Auftrag' }), -1);
  assert.equal(backdropAction({ labels, head: '🗑 Meldung löschen?' }), -1);
  assert.equal(backdropAction({ labels, head: '🗑 Übernommenen Auftrag entfernen?' }), -1);
  assert.equal(backdropAction({ labels: ['OK'], head: 'Info' }), -1);
  assert.equal(isProtectedHead('📋 Rückmeldung'), false);
});

test('tapVerdict', () => {
  assert.equal(tapVerdict({ dlgOpen: true, target: 'backdrop', anyOpen: false }), 'dlg-backdrop');
  assert.equal(tapVerdict({ dlgOpen: true, target: 'empty', anyOpen: true }), 'none');
  assert.equal(tapVerdict({ dlgOpen: false, target: 'empty', anyOpen: true }), 'close');
  assert.equal(tapVerdict({ dlgOpen: false, target: 'empty', anyOpen: false }), 'none');
  assert.equal(tapVerdict({ dlgOpen: false, target: 'ui', anyOpen: true }), 'none');
});
