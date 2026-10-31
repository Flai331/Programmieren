// v117: Rückkanal Einsatzleitung -> Hundeführer (Quittung, Nachricht, Lesebestätigung)
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  newLiveKey, buildMsg, buildAck, buildElMsg, buildReadAck, needsAck, forHf, ackedIds, readBy, mergeReads, splitIncoming, elTargets, readSummary,
  statusLabel, msgLabel, msgIcon, headMsg, latestFor, mergeStatus, flushOutbox, pollMessages, EL_ALL,
} from '../web/status.js';
import { openPoints } from '../web/closeout.js';
import { msgWaypoints, msgRows } from '../web/gpx.js';
import { normalizeProject, newProject } from '../web/store.js';
import { buildAssignment, projectFromAssignment } from '../web/share.js';

test('buildAck / buildElMsg / buildReadAck: Format', () => {
  const q = buildAck({ ref: 'm1', to: 'A1', t: 5, id: 'q1' });
  assert.deepEqual(q, { v: 1, id: 'q1', a: 'EL', tm: 'Einsatzleitung', t: 5, s: 'q', ref: 'm1', to: 'A1' });
  const e = buildElMsg({ to: 'A1', txt: ' Bitte melden ', t: 6, id: 'e1' });
  assert.deepEqual(e, { v: 1, id: 'e1', a: 'EL', tm: 'Einsatzleitung', t: 6, s: 'el', txt: 'Bitte melden', to: 'A1' });
  assert.equal(buildElMsg({ txt: 'x' }).to, EL_ALL); // ohne Ziel: alle
  assert.equal(buildElMsg({ to: '*', txt: 'x', prio: 1 }).prio, 1);
  assert.equal(buildElMsg({ to: '*', txt: 'x' }).prio, undefined);
  assert.equal(buildElMsg({ to: '*', txt: 'y'.repeat(400) }).txt.length, 300);
  assert.notEqual(buildAck({ ref: 'a', to: 'b' }).id, buildAck({ ref: 'a', to: 'b' }).id);
  const r = buildReadAck({ a: 'A1', tm: 'Alpha', ref: 'e1', t: 7, id: 'r1' });
  assert.deepEqual(r, { v: 1, id: 'r1', a: 'A1', tm: 'Alpha', t: 7, s: 'qel', ref: 'e1' });
});

test('Beschriftungen und Symbole der neuen Arten', () => {
  assert.equal(statusLabel('q'), '✓ Gesehen');
  assert.equal(msgLabel({ s: 'el' }), '✉️ Nachricht der Einsatzleitung');
  assert.equal(msgLabel({ s: 'qel' }), '👁 gelesen');
  assert.equal(msgIcon({ s: 'q' }), '✓');
  assert.equal(msgIcon({ s: 'el' }), '✉️');
  assert.equal(msgIcon({ s: 'qel' }), '👁');
  assert.equal(statusLabel('irgendwas'), 'irgendwas'); // unbekannt: kein Absturz
});

test('needsAck: nur echte Teammeldungen', () => {
  assert.ok(needsAck({ a: 'A1', s: 'fund' }) && needsAck({ a: 'A1', s: 'pause' }) && needsAck({ a: 'A1', s: 'ort', cat: 'hinweis' }));
  assert.ok(!needsAck({ a: 'A1', s: 'ok' }) && !needsAck({ a: 'A1', s: 'kor' }) && !needsAck({ a: 'A1', s: 'qel' }));
  assert.ok(!needsAck({ a: 'EL', s: 'el' }) && !needsAck(null));
});

test('forHf: eigenes Team, alle; fremdes Team und HF-Meldungen ignoriert', () => {
  const msgs = [
    buildAck({ ref: 'm1', to: 'A1', id: 'q1' }), buildAck({ ref: 'm2', to: 'B2', id: 'q2' }),
    buildElMsg({ to: 'A1', txt: 'an A', id: 'e1' }), buildElMsg({ to: 'B2', txt: 'an B', id: 'e2' }), buildElMsg({ to: '*', txt: 'alle', id: 'e3' }),
    buildMsg({ a: 'A1', tm: 'Alpha', s: 'fund', id: 'h1' }), buildReadAck({ a: 'B2', tm: 'Bravo', ref: 'e3', id: 'r1' }),
    { v: 1, id: 'fake', a: 'A1', t: 1, s: 'el', to: 'A1', txt: 'gefälscht von HF' }, // ein HF kann keine EL-Nachricht vortäuschen
    null,
  ];
  assert.deepEqual(forHf(msgs, 'A1').map((m) => m.id), ['q1', 'e1', 'e3']);
  assert.deepEqual(forHf(msgs, 'B2').map((m) => m.id), ['q2', 'e2', 'e3']);
  assert.deepEqual(forHf(msgs, 'C3').map((m) => m.id), ['e3']);
  assert.deepEqual(forHf(null, 'A1'), []);
});

test('ackedIds, readBy, mergeReads', () => {
  const inbox = [buildAck({ ref: 'm1', to: 'A1' }), buildAck({ ref: 'm3', to: 'A1' }), buildElMsg({ to: '*', txt: 'x' })];
  assert.deepEqual([...ackedIds(inbox)].sort(), ['m1', 'm3']);
  assert.equal(ackedIds([]).size, 0);
  const qels = [buildReadAck({ a: 'A1', tm: 'Alpha', ref: 'e1', t: 10 }), buildReadAck({ a: 'B2', tm: 'Bravo', ref: 'e1', t: 20 }),
    buildReadAck({ a: 'A1', tm: 'Alpha', ref: 'e1', t: 30 }), buildReadAck({ a: 'A1', tm: 'Alpha', ref: 'e2', t: 40 })];
  assert.deepEqual(readBy(qels, 'e1').sort(), ['A1', 'B2']);
  assert.deepEqual(readBy(qels, 'e2'), ['A1']);
  assert.deepEqual(readBy(qels, 'zz'), []);
  const base = { e1: { A1: 5 } };
  const m = mergeReads(base, qels);
  assert.deepEqual(m, { e1: { A1: 5, B2: 20 }, e2: { A1: 40 } }); // frühere Zeit bleibt
  assert.deepEqual(base, { e1: { A1: 5 } }); // Eingabe unverändert
});

test('splitIncoming: Team / EL / Lesebestätigungen getrennt', () => {
  const fresh = [
    buildMsg({ a: 'A1', tm: 'Alpha', s: 'start', id: 'h1' }), buildAck({ ref: 'h1', to: 'A1', id: 'q1' }), buildElMsg({ to: '*', txt: 'x', id: 'e1' }),
    buildReadAck({ a: 'A1', tm: 'Alpha', ref: 'e1', t: 9, id: 'r1' }), buildMsg({ a: 'B2', tm: 'Bravo', s: 'kor', id: 'k1' }), null,
  ];
  const r = splitIncoming(fresh);
  assert.deepEqual(r.team.map((m) => m.id), ['h1', 'k1']);
  assert.deepEqual(r.el.map((m) => m.id), ['q1', 'e1']);
  assert.deepEqual(r.reads, { e1: { A1: 9 } });
  assert.deepEqual(splitIncoming(null), { team: [], el: [], reads: {} });
});

test('elTargets: je Team der neueste laufende Auftrag mit Live-Kanal', () => {
  const sent = [
    { id: 'A1', teamId: 'T1', team: 'Alpha', at: 1, live: true }, { id: 'A2', teamId: 'T1', team: 'Alpha', at: 5, live: true },
    { id: 'B1', teamId: 'T2', team: 'Bravo', at: 2, live: true, done: 99 }, { id: 'C1', teamId: 'T3', team: 'Charlie', at: 3 },
    { id: 'D1', team: 'Delta', at: 4, live: true },
  ];
  const marks = [{ id: 'T1', label: 'Team Alpha' }];
  assert.deepEqual(elTargets(sent, marks), [{ a: 'A2', teamId: 'T1', label: 'Team Alpha' }, { a: 'D1', teamId: '', label: 'Delta' }]);
  assert.deepEqual(elTargets([], []), []);
});

test('readSummary: gelesen / offen, bei „alle“ über alle Ziele', () => {
  const targets = [{ a: 'A1' }, { a: 'B2' }, { a: 'C3' }];
  const reads = { e1: { A1: 1, B2: 2 }, e2: { A1: 3 } };
  assert.deepEqual(readSummary({ id: 'e1', to: '*' }, reads, targets), { read: ['A1', 'B2'], open: ['C3'] });
  assert.deepEqual(readSummary({ id: 'e2', to: 'B2' }, reads, targets), { read: [], open: ['B2'] });
  assert.deepEqual(readSummary({ id: 'e2', to: 'A1' }, reads, targets), { read: ['A1'], open: [] });
  assert.deepEqual(readSummary({ id: 'e9', to: '*' }, undefined, []), { read: [], open: [] });
});

test('Rückkanal-Arten verändern headMsg / latestFor / openPoints / Wegpunkte nicht', () => {
  const base = [
    buildMsg({ a: 'A1', tm: 'Alpha', s: 'fund', pos: { lat: 52.1, lon: 8.1 }, t: 100, id: 'f1' }),
    buildMsg({ a: 'A1', tm: 'Alpha', s: 'pause', t: 200, id: 'p1' }),
  ];
  const extra = [...base, buildAck({ ref: 'f1', to: 'A1', t: 300 }), buildElMsg({ to: 'A1', txt: 'hallo', t: 310 }), buildReadAck({ a: 'A1', tm: 'Alpha', ref: 'x', t: 320 })];
  // Teamfilter: EL-Meldungen haben a === 'EL', also nie bei einem Auftrag
  assert.deepEqual(latestFor(extra.filter((m) => m.a === 'A1' && m.s !== 'qel'), 'A1'), latestFor(base, 'A1'));
  assert.equal(headMsg(base).id, 'f1');
  assert.equal(headMsg(extra.filter((m) => m.a === 'A1' && m.s !== 'qel')).id, 'f1');
  const p = { sent: [{ id: 'A1', teamId: 'T1' }], marks: [{ id: 'T1', label: 'Alpha' }], live: { ack: [] } };
  const op = openPoints(p, base);
  const op2 = openPoints(p, extra.filter((m) => m.a !== 'EL'));
  assert.equal(op2.count, op.count);
  assert.deepEqual(openPoints(p, extra.filter((m) => m.a === 'EL')).unacked, []);
  assert.equal(msgWaypoints(extra).length, 1); // nur der Fund hat einen Ort
  assert.equal(msgRows(extra).length, 1);
});

test('Ende-zu-Ende: EL schickt Nachricht, HF liest, EL sieht „gelesen“ (gemeinsamer Raum)', async () => {
  const rows = [];
  let clock = 1000;
  const f = async (url, opt = {}) => {
    const u = new URL(url);
    if (opt.method === 'POST') { const b = JSON.parse(opt.body); if (!rows.some((r) => r[1] === b.r && r[2] === b.id)) rows.push([clock++, b.r, b.id, b.d]); return { json: async () => ({ ok: true }) }; }
    const since = Number(u.searchParams.get('since')) || 0;
    return { json: async () => ({ ok: true, now: clock, rows: rows.filter((r) => r[1] === u.searchParams.get('r') && r[0] > since).map((r) => [r[0], r[2], r[3]]) }) };
  };
  const url = 'https://script.google.com/macros/s/X/exec';
  // Schlüssel geht mit dem Auftrag mit: HF-ls[1] === EL-live.key
  const el = newProject('Einsatz');
  const g = el.gridId;
  const a = buildAssignment(el, { teamId: 'team', gridIds: [g], fields: 'all', liveUrl: url });
  assert.equal(a.ls[1], el.live.key);
  const hf = projectFromAssignment(a);
  assert.equal(hf.hf.ls[1], el.live.key);
  assert.deepEqual([hf.hf.inbox, hf.hf.elRead], [[], {}]);
  assert.deepEqual([el.live.out, el.live.outbox], [[], []]);
  const key = el.live.key;
  const fund = buildMsg({ a: 'A1', tm: 'Alpha', s: 'fund', t: 1, id: 'f1' });
  await flushOutbox([url, key], [fund], f);
  const e1 = buildElMsg({ to: '*', txt: 'Alle zurück', prio: 1, t: 2, id: 'e1' });
  const e2 = buildElMsg({ to: 'B2', txt: 'nur Bravo', t: 3, id: 'e2' });
  await flushOutbox([url, key], [buildAck({ ref: 'f1', to: 'A1', t: 2, id: 'q1' }), e1, e2], f);
  const poll = await pollMessages({ url, key, since: 0 }, f);
  const mine = forHf(poll.msgs, 'A1');
  assert.deepEqual(mine.map((m) => m.id), ['q1', 'e1']);
  assert.ok(ackedIds(mine).has('f1'));
  await flushOutbox([url, key], [buildReadAck({ a: 'A1', tm: 'Alpha', ref: 'e1', t: 4, id: 'r1' })], f);
  const back = splitIncoming((await pollMessages({ url, key, since: 0 }, f)).msgs);
  assert.deepEqual(back.team.map((m) => m.id), ['f1']);
  assert.deepEqual(back.reads, { e1: { A1: 4 } });
});

test('Laden alter Projekte: Rückkanal-Felder bekommen Standardwerte', () => {
  const url = 'https://script.google.com/macros/s/X/exec';
  const base = newProject('Alt');
  const old = normalizeProject({ ...base, live: { url, key: 'k', since: 3, ack: [], msgs: [] }, hf: { id: 'A1', team: 'T', ls: [url, 'k'], outbox: [], log: [] } });
  assert.deepEqual([old.live.out, old.live.outbox, old.live.reads, old.live.qSent], [[], [], {}, {}]);
  assert.deepEqual([old.hf.inbox, old.hf.since, old.hf.elRead], [[], 0, {}]);
  const kept = normalizeProject({ ...base, live: { url, key: 'k', out: [{ id: 'e1' }, 5], reads: { e1: { A1: 1 } }, qSent: { m1: 2 } }, hf: { id: 'A1', ls: [url, 'k'], inbox: [{ id: 'q1' }], since: 77, elRead: { e1: 9 } } });
  assert.equal(kept.live.out.length, 1);
  assert.deepEqual(kept.live.reads, { e1: { A1: 1 } });
  assert.equal(kept.hf.since, 77);
  assert.deepEqual(kept.hf.elRead, { e1: 9 });
  assert.equal(mergeStatus(kept.live.out, []).length, 0); // ohne t kein gültiges Element: unkritisch
});
