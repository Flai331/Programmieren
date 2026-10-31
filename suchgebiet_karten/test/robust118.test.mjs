// v118: Robustheit – abgelehnte Meldungen, defekte Einsätze, Schlüssel im PDF, Weg-Sicherung
import test from 'node:test';
import assert from 'node:assert/strict';
import { buildMsg, newLiveKey, flushOutbox, postMsg, roomOf } from '../web/status.js';
import { newProject, normalizeProject, loadProjects, stripSecrets, embedMarker, importProject, mergeTrackBackup } from '../web/store.js';

const URL_ = 'https://script.google.com/macros/s/X/exec';
const out3 = () => [1, 2, 3].map((n) => buildMsg({ a: 'A', tm: 'T', s: 'start', t: n, id: `m${n}` }));
// Server, der je Meldungs-ID eine Antwort liefert
const srvWith = (answer) => async (url, init) => {
  const b = JSON.parse(init.body);
  const a = answer(b.id);
  if (a === 'netz') throw new Error('offline');
  return { ok: a.http !== 500, json: async () => (a.http ? { ok: true } : a) };
};

test('abgelehnte Meldung blockiert nicht: 1 und 3 gesendet, 2 in rejected', async () => {
  const f = srvWith((id) => (id === 'm2' ? { ok: false, fehler: 'Daten' } : { ok: true }));
  const r = await flushOutbox([URL_, newLiveKey()], out3(), f);
  assert.deepEqual(r.sent, ['m1', 'm3']);
  assert.deepEqual(r.rejected, [{ id: 'm2', reason: 'Daten' }]);
  assert.equal(r.left.length, 0);
});

test('Netzfehler bei 2 bricht ab: 2 und 3 bleiben', async () => {
  const f = srvWith((id) => (id === 'm2' ? 'netz' : { ok: true }));
  const r = await flushOutbox([URL_, newLiveKey()], out3(), f);
  assert.deepEqual(r.sent, ['m1']);
  assert.deepEqual(r.left.map((m) => m.id), ['m2', 'm3']);
  assert.deepEqual(r.rejected, []);
});

test('vorübergehende Serverfehler (Schloss-Timeout), HTTP-Fehler und kein JSON zählen als Netzfehler', async () => {
  for (const f of [
    srvWith(() => ({ ok: false, fehler: 'Exception: Lock timeout' })),
    srvWith(() => ({ http: 500 })),
    async () => ({ ok: true, json: async () => { throw new Error('html'); } }),
  ]) {
    const r = await flushOutbox([URL_, newLiveKey()], out3(), f);
    assert.equal(r.sent.length, 0);
    assert.equal(r.left.length, 3);
    assert.equal(r.rejected.length, 0);
  }
  await assert.rejects(postMsg(URL_, await roomOf('k'), 'x', 'd', srvWith(() => ({ ok: false, fehler: 'Raum' }))), (e) => e.rejected === true && e.reason === 'Raum');
});

test('normalizeProject: null-Einträge in Listen werfen nicht', () => {
  const p = normalizeProject({ ...newProject('x'), marks: [null, { id: 'a', kind: 'team', label: 'A', color: '#d50000' }, 5], items: [null, { kind: 'track', pts: [] }], contacts: [null], pois: [null], sent: [null] });
  assert.equal(p.marks.length, 1);
  assert.equal(p.items.length, 1);
  assert.deepEqual(p.contacts, []);
  assert.throws(() => normalizeProject(null));
});

test('loadProjects: defekter Einsatz wird ausgesondert, die anderen bleiben', () => {
  const good = newProject('gut');
  const bad = { ...newProject('kaputt'), mission: 5 };
  Object.defineProperty(bad, 'sent', { get() { throw new Error('boom'); }, enumerable: true });
  const r = loadProjects({ [good.id]: good, b: bad, n: null });
  assert.deepEqual(Object.keys(r.projects), [good.id]);
  assert.deepEqual(r.broken.map((x) => x.id).sort(), ['b', 'n']);
  assert.deepEqual(loadProjects(undefined), { projects: {}, broken: [] });
});

test('stripSecrets: kein Schlüssel im Ergebnis, Raster bleibt', () => {
  const TEAM = 'tm1';
  const p = normalizeProject({
    ...newProject('Einsatz'),
    marks: [{ id: 'tm1', kind: 'team', label: 'A', color: '#d50000' }],
    area: { north: 52.1, south: 52, west: 8, east: 8.1 }, cellM: 100, fills: { '1,1': TEAM },
    live: { url: URL_, key: 'GEHEIMLIVEKEY', since: 3, msgs: [{ id: 'a', t: 1, s: 'start', a: 'x' }] },
    hf: { id: 'h', team: 'T', ls: [URL_, 'GEHEIMHFKEY'], outbox: [{ id: 'o', key: 'GEHEIMOUT' }], inbox: [{ id: 'i', t: 1, s: 'el', a: 'EL' }], log: [], track: [] },
    sent: [{ id: 's1', live: true, ls: [URL_, 'GEHEIMSENT'], team: 'A' }],
  });
  const s = stripSecrets(p);
  const text = JSON.stringify(s);
  assert.ok(!/GEHEIM/.test(text));
  assert.ok(!('live' in s));
  assert.ok(!('ls' in s.hf) && !('outbox' in s.hf) && !('inbox' in s.hf));
  assert.deepEqual(s.area, p.area);
  assert.deepEqual(s.fills, { '1,1': TEAM });
  assert.equal(s.sent[0].team, 'A');
  assert.ok(p.live && p.hf.ls, 'Original bleibt unverändert');
  // PDF-Marker: importierbar, ohne Schlüssel
  const emb = embedMarker(p);
  const back = importProject(emb);
  assert.deepEqual(back.area, p.area);
  assert.ok(!back.live);
  assert.ok(!Buffer.from(emb.split(':')[1] || '', 'base64').toString().includes('GEHEIM'));
});

test('mergeTrackBackup: längere Sicherung ersetzt das letzte Wegstück, sonst unverändert', () => {
  const seg = { t0: 5, pts: [[52, 8], [52.0001, 8]] };
  const longer = { t0: 5, pts: [[52, 8], [52.0001, 8], [52.0002, 8]] };
  const r = mergeTrackBackup([seg], longer);
  assert.equal(r.merged, true);
  assert.equal(r.track.length, 1);
  assert.equal(r.track[0].pts.length, 3);
  assert.equal(r.track[0].t0, 5);
  assert.equal(seg.pts.length, 2, 'Original unverändert');
  // beim Start gespeichertes, noch leeres Segment (gleiche Startzeit) wird ersetzt, nicht ergänzt
  const e = mergeTrackBackup([{ t0: 7, pts: [] }], { t0: 7, pts: [[52, 8], [52.0001, 8]] });
  assert.equal(e.track.length, 1);
  assert.equal(e.track[0].pts.length, 2);
  // gleich lang / kürzer: nichts
  assert.equal(mergeTrackBackup([longer], seg).merged, false);
  assert.equal(mergeTrackBackup([seg], seg).merged, false);
  // Wegstück fehlt ganz: wird angehängt
  const n = mergeTrackBackup([{ t0: 1, pts: [[51, 7], [51.1, 7]] }], longer);
  assert.equal(n.merged, true);
  assert.equal(n.track.length, 2);
  assert.equal(mergeTrackBackup([], longer).track.length, 1);
  // leer / kaputt
  assert.equal(mergeTrackBackup([seg], { pts: [] }).merged, false);
  assert.equal(mergeTrackBackup([seg], null).merged, false);
  assert.equal(mergeTrackBackup(undefined, { pts: [['x', 1]] }).merged, false);
});
