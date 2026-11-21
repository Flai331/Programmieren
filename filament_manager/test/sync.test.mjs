import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from './gas-mock.mjs';
import * as S from '../web/sync.js';
import * as L from '../web/logic.js';

function device(server) {
  const state = L.emptyState();
  const meta = S.emptyMeta();
  const store = new Map();
  let clock = 1000;
  const blobs = {
    get: async (id) => store.get(id) || null,
    put: async (id, b) => { store.set(id, b); },
    toB64: async (b) => Buffer.from(await b.arrayBuffer()).toString('base64'),
    fromB64: (b64, type) => new Blob([Buffer.from(b64, 'base64')], { type }),
  };
  const call = async (body) => server.post({ ...body, key: server.key });
  return {
    state, meta, store,
    save(now) { S.stamp(state, meta, now ?? (clock += 1000)); },
    sync() { return S.runSync(state, meta, call, blobs); },
  };
}

const spool = (id, o = {}) => ({ id, brand: 'Bambu', material: 'PLA', colorName: 'Weiß', colorHex: '#FFFFFF', netWeight: 1000, emptyWeight: 250, price: 20, location: { kind: 'box', box: 1, slot: 1 }, weighings: [], ...o });

test('Server: falscher Schlüssel wird abgelehnt, doGet antwortet', () => {
  const srv = createServer();
  assert.equal(srv.post({ a: 'ping', key: 'falsch' }).fehler, 'schluessel');
  assert.equal(srv.post({ a: 'ping', key: srv.key }).ok, true);
  assert.match(srv.doGet(), /läuft/);
});

test('Zwei Geräte gleichen Daten, Einstellungen und Fotos ab', async () => {
  const srv = createServer();
  const pc = device(srv);
  pc.state.settings.boxCount = 9;
  pc.state.spools.push(spool('s1'), spool('s2', { colorName: 'Schwarz', colorHex: '#000000', location: { kind: 'box', box: 1, slot: 2 } }));
  pc.state.prints.push({ id: 'p1', name: 'Halter', date: '2026-11-20T10:00:00Z', thumbId: 'thumb_p1', filaments: [{ spoolId: 's1', grams: 50 }], pieces: 2, orderId: 'o1' });
  pc.state.orders.push({ id: 'o1', title: 'Gartenhalter', customer: '=HYPERLINK("x")', quantity: 4, status: 'druck', deadline: '2026-11-30', photos: [{ id: 'ph1', type: 'image/jpeg', name: 'a.jpg' }] });
  pc.store.set('ph1', new Blob(['FOTO'], { type: 'image/jpeg' }));
  pc.store.set('thumb_p1', new Blob(['PNG'], { type: 'image/png' }));
  pc.save();
  const r1 = await pc.sync();
  assert.equal(r1.uploaded, 2);
  assert.equal(srv.files.length, 2);

  // Tabelle ist lesbar und ohne Formel
  const rollen = srv.sheets.get('Rollen').data;
  assert.equal(rollen.length, 3); // Kopf + 2
  assert.equal(rollen[1][6], 'Bambu');
  assert.equal(rollen[1][11], 950); // Rest (g)
  const auftrag = srv.sheets.get('Auftraege').data[1];
  assert.equal(auftrag[7], '=HYPERLINK("x")'); // als Text gespeichert (mit ' davor)

  // Handy: frische Standard-Einstellungen dürfen die echten nicht überschreiben
  const phone = device(srv);
  phone.save();
  const r2 = await phone.sync();
  assert.equal(phone.state.settings.boxCount, 9);
  assert.equal(phone.state.spools.length, 2);
  assert.equal(phone.state.orders[0].customer, '=HYPERLINK("x")');
  assert.equal(r2.downloaded, 2);
  assert.equal(await (await phone.store.get('ph1')).text(), 'FOTO');

  // Keine Endlosschleife: weitere Abgleiche laden nichts mehr hoch
  for (const d of [pc, phone, pc, phone]) {
    const r = await d.sync();
    assert.equal(r.pushed, 0, 'unnötiger Upload');
    assert.equal(r.changed, 0);
  }

  // Handy lagert Rolle um, PC löscht Auftrag samt Foto
  phone.state.spools.find((s) => s.id === 's2').location = { kind: 'ams', unit: 1, slot: 3 };
  phone.save(50_000);
  pc.state.orders = [];
  pc.state.prints[0].orderId = '';
  pc.save(51_000);
  await phone.sync();
  await pc.sync();
  await phone.sync();
  assert.deepEqual(pc.state.spools.find((s) => s.id === 's2').location, { kind: 'ams', unit: 1, slot: 3 });
  assert.equal(phone.state.orders.length, 0);
  assert.equal(phone.state.prints[0].orderId, '');
  assert.equal(srv.files.find((f) => f.name === 'ph1').trashed, true);
  assert.equal(srv.files.find((f) => f.name === 'thumb_p1').trashed, false);
  assert.equal(srv.sheets.get('Auftraege').data[1][2], 1); // Grabstein

  // Konflikt: beide ändern dieselbe Rolle – die spätere Änderung gewinnt
  pc.state.spools[0].colorName = 'PC-Name';
  pc.save(60_000);
  phone.state.spools[0].colorName = 'Handy-Name';
  phone.save(61_000);
  await pc.sync();
  await phone.sync();
  await pc.sync();
  assert.equal(pc.state.spools[0].colorName, 'Handy-Name');
  assert.equal(phone.state.spools[0].colorName, 'Handy-Name');

  // Umgekehrte Reihenfolge: ältere Änderung wird vom Server abgelehnt
  phone.state.spools[0].colorName = 'alt';
  phone.save(70_000);
  pc.state.spools[0].colorName = 'neu';
  pc.save(71_000);
  await pc.sync();
  await phone.sync();
  assert.equal(phone.state.spools[0].colorName, 'neu');

  // zwei Runden zum Beruhigen (Übersichtszeilen nachziehen), danach darf nichts mehr hochgeladen werden
  await pc.sync();
  await phone.sync();
  await pc.sync();
  await phone.sync();
  for (const d of [pc, phone, pc, phone]) assert.equal((await d.sync()).pushed, 0);
});

test('Rest-Spalte in der Tabelle folgt neuen Drucken', async () => {
  const srv = createServer();
  const pc = device(srv);
  pc.state.spools.push(spool('s1'));
  pc.save();
  await pc.sync();
  pc.state.prints.push({ id: 'p9', name: 'x', date: '2026-11-21T10:00:00Z', filaments: [{ spoolId: 's1', grams: 100 }] });
  pc.save();
  await pc.sync();
  assert.equal(srv.sheets.get('Rollen').data[1][11], 900);
});

test('Offener Dialog behält seine Referenz, wenn ein Abgleich die Rolle ändert', async () => {
  const srv = createServer();
  const a = device(srv);
  a.state.spools.push(spool('s1'));
  a.save();
  await a.sync();
  const b = device(srv);
  b.save();
  await b.sync();
  const ref = b.state.spools[0];
  a.state.spools[0].colorName = 'Neu';
  a.save(90_000);
  await a.sync();
  await b.sync();
  assert.equal(ref.colorName, 'Neu');
  assert.equal(b.state.spools[0], ref);
});
