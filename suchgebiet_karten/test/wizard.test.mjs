import test from 'node:test';
import assert from 'node:assert/strict';
import { WIZ_STEPS, wizTitle, lastLead, hhmmOf, isoDate } from '../web/wizard.js';
import { markLabel } from '../web/store.js';

test('Assistent: Schritte, Vorschlag für den Namen, Zeiten', () => {
  assert.equal(WIZ_STEPS[0][0], 'name');
  assert.equal(WIZ_STEPS.at(-1)[0], 'done');
  assert.ok(WIZ_STEPS.some(([k]) => k === 'wx'));
  const d = new Date(2026, 9, 3, 7, 5);
  assert.equal(wizTitle(d), 'Einsatz 03.10.2026');
  assert.equal(hhmmOf(d), '07:05');
  assert.equal(isoDate(d), '2026-10-03');
});

test('„wie letzter Einsatz“: jüngster anderer Einsatz mit Einsatzleitung', () => {
  const projects = {
    a: { id: 'a', updated: 1, lead: { name: 'Alt', phone: '', call: '', elw: '' }, radio: [] },
    b: { id: 'b', updated: 3, lead: { name: '', phone: '', call: '', elw: '' }, radio: [] },
    c: { id: 'c', updated: 2, lead: { name: 'Klaas', phone: '0170', call: 'RH 1', elw: '11-1' }, radio: [{ call: 'RH 2', who: 'ZF' }] },
    d: { id: 'd', updated: 9, lead: { name: 'Ich', phone: '', call: '', elw: '' }, radio: [] },
  };
  const l = lastLead(projects, 'd');
  assert.equal(l.lead.name, 'Klaas');
  assert.deepEqual(l.radio, [{ call: 'RH 2', who: 'ZF' }]);
  l.radio[0].call = 'x';
  assert.equal(projects.c.radio[0].call, 'RH 2', 'Kopie');
  assert.equal(lastLead({ d: projects.d }, 'd'), null);
});

test('Team mit Suchhelfern', () => {
  assert.equal(markLabel({ kind: 'team', label: 'Team 2', dog: 'Kira', helpers: 2 }), 'Team 2 (Kira) + 2 Suchhelfer');
  assert.equal(markLabel({ kind: 'team', label: 'Team 3', dog: '' }), 'Team 3');
  assert.equal(markLabel({ kind: 'status', label: 'abgesucht' }), 'abgesucht');
});
