import test from 'node:test';
import assert from 'node:assert/strict';
import { buildInfos, deletePoi, infoSummary, mergeInfos } from '../web/infos.js';
import { newPoi } from '../web/pois.js';
import { newProject, normalizeProject } from '../web/store.js';
import { pack, unpack } from '../web/share.js';

const proj = () => normalizeProject(newProject('Einsatz'));

test('Infos ergänzen nur: neu dazu, nichts gelöscht, mehrfach scannen schadet nicht', async () => {
  const a = proj();
  const b = proj();
  const elw = newPoi({ cat: 'elw', lat: 52.1, lon: 10.1, name: 'ELW 11-1', by: 'ELW' }, 1000);
  const park = newPoi({ cat: 'park', lat: 52.3, lon: 10.3, by: 'EL' }, 1000);
  a.pois.push(elw);
  b.pois.push(park); // nur beim Einsatzleiter – darf nicht verschwinden
  const inf = await unpack(await pack(buildInfos(a, { from: 'ELW' }, 4000)));
  assert.equal(inf.k, 'i');
  assert.equal(inf.dl, undefined);
  const r = mergeInfos(b, inf);
  assert.deepEqual(r, { added: 1, changed: 0, contacts: 0 });
  assert.equal(infoSummary(r), '1 neu');
  assert.deepEqual(b.pois.map((x) => x.id).sort(), [elw.id, park.id].sort());
  assert.equal(infoSummary(mergeInfos(b, inf)), '');
  assert.equal(b.pois.length, 2);
  // Absender löscht bei sich: beim Einsatzleiter bleibt es
  deletePoi(a, a.pois[0], 5000);
  mergeInfos(b, buildInfos(a, { from: 'ELW' }));
  assert.equal(b.pois.length, 2);
});

test('Infos: nur eigene Einträge des Absenders werden aktualisiert, Gelöschtes kommt nicht wieder', () => {
  const a = proj();
  const b = proj();
  const own = newPoi({ cat: 'elw', lat: 1, lon: 2, name: 'ELW', by: 'ELW' }, 1000);
  const els = newPoi({ cat: 'food', lat: 1, lon: 2, name: 'Küche', by: 'EL' }, 1000);
  b.pois.push({ ...own }, { ...els });
  a.pois.push({ ...own, lat: 1.5, t: 2000 }, { ...els, name: 'Kantine', by: 'ELW', t: 2000 });
  const r = mergeInfos(b, buildInfos(a, { from: 'ELW' }));
  assert.deepEqual(r, { added: 0, changed: 1, contacts: 0 });
  assert.equal(b.pois.find((x) => x.id === own.id).lat, 1.5);
  assert.equal(b.pois.find((x) => x.id === els.id).name, 'Küche');
  // Einsatzleiter löscht: kommt mit späteren Infos nicht wieder
  deletePoi(b, b.pois.find((x) => x.id === own.id), 3000);
  a.pois[0].t = 9000;
  assert.equal(mergeInfos(b, buildInfos(a, { from: 'ELW' })).added, 0);
  assert.equal(b.pois.length, 1);
});

test('Infos: Kontakte nur ergänzen, ohne Duplikate', () => {
  const a = proj();
  const b = proj();
  a.contacts = [{ id: '1', name: 'Anna', phone: '0171 123' }, { id: '2', name: 'Bert', phone: '0172' }].map((c) => normalizeProject({ ...a, contacts: [c] }).contacts[0]);
  b.contacts = [normalizeProject({ ...b, contacts: [{ name: 'anna', phone: '0171123' }] }).contacts[0]];
  assert.equal(buildInfos(a).ct, undefined);
  const r = mergeInfos(b, buildInfos(a, { contacts: true }));
  assert.equal(r.contacts, 1);
  assert.deepEqual(b.contacts.map((c) => c.name), ['anna', 'Bert']);
  assert.equal(infoSummary(r), '1 Kontakt');
});

test('Infos: kaputte Einträge werden ignoriert, poiDel wird normalisiert', () => {
  const b = proj();
  assert.deepEqual(mergeInfos(b, { k: 'i', po: [null, ['x', 'elw', 'a', 1]], dl: [[1, 2], ['y', 'z']] }), { added: 0, changed: 0, contacts: 0 });
  assert.deepEqual(normalizeProject({ ...b, poiDel: [1] }).poiDel, {});
});
