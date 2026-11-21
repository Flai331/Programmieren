import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from './gas-mock.mjs';
import * as L from '../web/logic.js';

const HOUR = 3600 * 1000;
const task = (id, o = {}) => ({
  id, designTitle: 'Teil ' + id, status: 2, weight: 12.5, costTime: 1800,
  startTime: new Date(Date.now() - 2 * HOUR).toISOString(), endTime: new Date(Date.now() - HOUR).toISOString(),
  amsDetailMapping: [{ ams: 1, sourceColor: 'FFFFFFFF', filamentType: 'PLA', weight: 12.5, extra: 'x' }],
  cover: 'https://cover/' + id + '.png', ...o,
});

test('setup legt Zeitauslöser genau einmal an', () => {
  const srv = createServer();
  assert.deepEqual(srv.triggers, ['bambuAbrufen']);
  srv.ctx.setup();
  assert.deepEqual(srv.triggers, ['bambuAbrufen']);
});

test('Anmeldung mit E-Mail-Code, Abruf in den Eingang, Bestätigen', () => {
  const srv = createServer();
  const post = (b) => srv.post({ ...b, key: srv.key });
  assert.equal(post({ a: 'bambuLogin', email: 'a@b.de', password: 'falsch' }).ok, false);
  const r1 = post({ a: 'bambuLogin', email: 'a@b.de', password: 'pw', ab: Date.now() - 10 * 24 * HOUR });
  assert.deepEqual([r1.ok, r1.code], [true, true]);
  assert.equal(srv.bambu.codeSent, 1);
  assert.equal(post({ a: 'bambuCode', code: '000000' }).ok, false);
  assert.equal(post({ a: 'bambuCode', code: '123456' }).angemeldet, true);
  assert.equal(srv.props.get('bambuToken'), 'tok1');
  assert.equal(srv.props.has('bambuEmail'), false);
  for (const v of srv.props.values()) assert.ok(!String(v).includes('pw'), 'Passwort gespeichert!');

  srv.bambu.tasks = [
    task(1),
    task(2, { status: 3 }),
    task(3, { status: 1, endTime: null, startTime: new Date().toISOString() }), // läuft
    task(4, { status: 7, startTime: new Date(Date.now() - 30 * HOUR).toISOString() }), // unklar, alt → übernehmen
    task(5, { endTime: new Date(Date.now() - 20 * 24 * HOUR).toISOString(), startTime: new Date(Date.now() - 20 * 24 * HOUR).toISOString() }), // vor "ab"
  ];
  srv.ctx.bambuAbrufen();
  let inbox = post({ a: 'inbox' });
  assert.deepEqual(inbox.items.map((t) => t.id), [1, 2, 4]);
  assert.equal(inbox.items[0].amsDetailMapping[0].extra, undefined);
  assert.equal(inbox.bambu.angemeldet, true);
  assert.ok(inbox.bambu.zuletzt > 0);
  // Vorschaubild liegt in Drive und ist über "get" abrufbar
  const g = post({ a: 'get', id: 'cthumb_1' });
  assert.equal(Buffer.from(g.b64, 'base64').toString(), 'JPEGDATA');

  // App wertet aus
  const drafts = L.parseCloudTasks({ hits: inbox.items });
  assert.equal(drafts.length, 3);
  assert.equal(drafts[0].thumbId, 'cthumb_1');
  assert.equal(drafts[1].status, 'failed');
  assert.equal(drafts[2].statusUnsure, true);

  // erneuter Abruf: keine Doppelten; Druck 3 ist jetzt fertig
  srv.bambu.tasks[2] = task(3);
  post({ a: 'bambuNow' });
  inbox = post({ a: 'inbox' });
  assert.deepEqual(inbox.items.map((t) => t.id), [1, 2, 4, 3]);

  post({ a: 'inboxDone', ids: ['1', '2', '4'] });
  inbox = post({ a: 'inbox' });
  assert.deepEqual(inbox.items.map((t) => t.id), [3]);
  assert.equal(srv.sheets.get('Eingang').data.length, 5);
});

test('Abgelaufenes Token wird mit Refresh-Token erneuert, sonst klare Meldung', () => {
  const srv = createServer();
  const post = (b) => srv.post({ ...b, key: srv.key });
  post({ a: 'bambuLogin', email: 'a@b.de', password: 'pw' });
  post({ a: 'bambuCode', code: '123456' });
  srv.bambu.validTokens.delete('tok1');
  srv.bambu.tasks = [task(9)];
  assert.equal(post({ a: 'bambuNow' }).ok, true);
  assert.equal(srv.props.get('bambuToken'), 'tok2');

  srv.bambu.validTokens.clear();
  const r = post({ a: 'bambuNow' });
  assert.equal(r.fehler, 'anmeldung');
  assert.match(post({ a: 'inbox' }).bambu.fehler, /neu anmelden/);

  post({ a: 'bambuLogout' });
  assert.equal(post({ a: 'inbox' }).bambu.angemeldet, false);
  srv.ctx.bambuAbrufen(); // ohne Anmeldung: nichts tun, kein Fehler
});

test('Laptop-Rückfall: inboxAdd legt Drucke in den Eingang', () => {
  const srv = createServer();
  const post = (b) => srv.post({ ...b, key: srv.key });
  assert.equal(post({ a: 'inboxAdd', tasks: [task(20), task(21)] }).neu, 2);
  assert.equal(post({ a: 'inboxAdd', tasks: [task(20)] }).neu, 0);
  assert.equal(post({ a: 'inbox' }).items.length, 2);
});
