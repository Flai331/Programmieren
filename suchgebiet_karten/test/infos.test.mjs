import test from 'node:test';
import assert from 'node:assert/strict';
import { buildInfos, deletePoi, infoSummary, mergeInfos } from '../web/infos.js';
import { newPoi } from '../web/pois.js';
import { newProject, normalizeProject } from '../web/store.js';
import { pack, unpack } from '../web/share.js';

const proj = () => normalizeProject(newProject('Einsatz'));

test('Infos: neu, geändert, gelöscht – und mehrfach scannen schadet nicht', async () => {
  const a = proj();
  const b = normalizeProject({ ...JSON.parse(JSON.stringify(a)), id: 'other' });
  const elw = newPoi({ cat: 'elw', lat: 52.1, lon: 10.1, name: 'ELW 11-1', by: 'ELW' }, 1000);
  const wc = newPoi({ cat: 'wc', lat: 52.2, lon: 10.2 }, 1000);
  const park = newPoi({ cat: 'park', lat: 52.3, lon: 10.3 }, 1000);
  a.pois.push(elw, wc, park);
  b.pois.push(JSON.parse(JSON.stringify(park)), JSON.parse(JSON.stringify(wc)));
  wc.name = 'Dixi';
  wc.t = 2000;
  deletePoi(a, park, 3000);
  assert.deepEqual(a.poiDel, { [park.id]: 3000 });
  const inf = await unpack(await pack(buildInfos(a, { from: 'ELW 11-1' }, 4000)));
  assert.equal(inf.k, 'i');
  assert.equal(inf.from, 'ELW 11-1');
  const r = mergeInfos(b, inf);
  assert.deepEqual(r, { added: 1, changed: 1, removed: 1, contacts: 0 });
  assert.equal(infoSummary(r), '1 neu, 1 geändert, 1 gelöscht');
  assert.deepEqual(b.pois.map((x) => x.name).sort(), ['Dixi', 'ELW 11-1']);
  assert.equal(b.pois.find((x) => x.id === elw.id).by, 'ELW');
  // zweites Mal: nichts Neues
  assert.equal(infoSummary(mergeInfos(b, inf)), '');
  assert.equal(b.pois.length, 2);
});

test('Infos: Neueres gewinnt, gelöschte kommen nicht zurück', () => {
  const a = proj();
  const b = proj();
  const x = newPoi({ cat: 'food', lat: 1, lon: 2, name: 'Alt' }, 1000);
  a.pois.push({ ...x });
  b.pois.push({ ...x, name: 'Neu', t: 5000 });
  assert.equal(mergeInfos(b, buildInfos(a)).changed, 0);
  assert.equal(b.pois[0].name, 'Neu');
  // b hat gelöscht, a schickt den alten Stand: bleibt gelöscht
  deletePoi(b, b.pois[0], 6000);
  assert.equal(mergeInfos(b, buildInfos(a)).added, 0);
  assert.equal(b.pois.length, 0);
  // a ändert danach (neuer als das Löschen): kommt wieder
  a.pois[0].t = 7000;
  assert.equal(mergeInfos(b, buildInfos(a)).added, 1);
  // Löschen auf a, das älter ist als eine Änderung auf b: Lage-Ort bleibt
  const c = proj();
  c.pois.push({ ...x, t: 9000 });
  deletePoi(a, a.pois[0], 8000);
  assert.equal(mergeInfos(c, buildInfos(a)).removed, 0);
  assert.equal(c.pois.length, 1);
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
  assert.deepEqual(mergeInfos(b, { k: 'i', po: [null, ['x', 'elw', 'a', 1]], dl: [[1, 2], ['y', 'z']] }), { added: 0, changed: 0, removed: 0, contacts: 0 });
  assert.deepEqual(normalizeProject({ ...b, poiDel: [1] }).poiDel, {});
});
