import test from 'node:test';
import assert from 'node:assert/strict';
import {
  teamChips, chipText, teamMsgs, unreadMsgs, noteReceived, markSeen, prune, unreadAlert, bannerText, parseSnooze,
  historyFilter, historyTeams, isReturned, BANNER_MS, BEEP_MS, BEEP_EVERY_MS,
} from '../web/statusbar.js';
import { normalizeProject, newProject } from '../web/store.js';

const T0 = new Date('2026-10-30T12:00:00').getTime();
const min = (n) => n * 60e3;
const marks = [
  { id: 'T1', kind: 'team', label: 'Juh 1', color: '#1565c0', dog: 'Kira' },
  { id: 'T2', kind: 'team', label: 'Juh 2', color: '#2e7d32', dog: '' },
];
const sent = [
  { id: 'A1', teamId: 'T1', team: 'Juh 1', at: T0, acc: T0 + min(10), items: ['i1'], what: 'Raster A' },
  { id: 'A2', teamId: 'T2', team: 'Juh 2', at: T0 + min(5), acc: 0, items: [] },
];
const items = [{ id: 'i1', kind: 'track', pts: [[1, 1], [1, 2], [2, 2]], name: '' }];
const msg = (id, a, s, dt, extra = {}) => ({ id, a, tm: 'x', t: T0 + min(dt), s, ...extra });

test('teamChips: Inhalt – wartet, übernommen, letzte Meldung', () => {
  let c = teamChips(sent, [], marks, items);
  assert.equal(c.length, 2);
  const c2 = c.find((x) => x.teamId === 'T2');
  assert.equal(c2.status, '📲 wartet');
  assert.ok(c2.wait);
  const c1 = c.find((x) => x.teamId === 'T1');
  assert.match(c1.status, /^📲 übernommen \d\d:\d\d$/);
  assert.equal(c1.areas, 'Umriss 1');
  assert.equal(c1.dog, 'Kira');
  c = teamChips(sent, [msg('m1', 'A1', 'pause', 20)], marks, items);
  const t = c.find((x) => x.teamId === 'T1');
  assert.match(t.status, /^⏸ Pause \d\d:\d\d$/);
  assert.match(chipText(t), /^Juh 1 \(Kira\) · Umriss 1 · ⏸ Pause/);
  assert.equal(t.urgent, false);
});
test('teamChips: Quittung ok gilt als übernommen, Fund/Hilfe dringend', () => {
  const c = teamChips(sent, [msg('m0', 'A2', 'ok', 6)], marks, items);
  const t = c.find((x) => x.teamId === 'T2');
  assert.match(t.status, /^📲 übernommen/);
  assert.equal(t.wait, false);
  const u = teamChips(sent, [msg('m1', 'A1', 'ort', 30, { cat: 'fund' })], marks, items).find((x) => x.teamId === 'T1');
  assert.equal(u.urgent, true);
});
test('teamChips: Sortierung neueste Aktivität zuerst', () => {
  const c = teamChips(sent, [msg('m1', 'A1', 'pause', 20), msg('m2', 'A2', 'start', 30)], marks, items);
  assert.deepEqual(c.map((x) => x.teamId), ['T2', 'T1']);
});
test('teamChips: nach QR-Rückmeldung weg, neuere Meldung holt ihn zurück', () => {
  const s = [{ ...sent[0], last: T0 + min(40) }, sent[1]];
  const old = [msg('m1', 'A1', 'ende', 35)];
  assert.deepEqual(teamChips(s, old, marks, items).map((x) => x.teamId), ['T2']);
  assert.equal(isReturned(s[0], old), true);
  const neu = [...old, msg('m2', 'A1', 'ort', 50, { cat: 'hinweis' })];
  assert.deepEqual(teamChips(s, neu, marks, items).map((x) => x.teamId).sort(), ['T1', 'T2']);
  assert.equal(isReturned(s[0], neu), false);
});
test('teamChips: mehrere Aufträge – der neueste nicht zurückgemeldete', () => {
  const s = [
    { id: 'B1', teamId: 'T1', team: 'Juh 1', at: T0, acc: T0, what: 'alt' },
    { id: 'B2', teamId: 'T1', team: 'Juh 1', at: T0 + min(60), acc: 0, what: 'neu' },
    { id: 'B3', teamId: 'T1', team: 'Juh 1', at: T0 + min(120), acc: T0, last: T0 + min(130), what: 'zurück' },
  ];
  const c = teamChips(s, [], marks, []);
  assert.equal(c.length, 1);
  assert.equal(c[0].a, 'B2');
  assert.equal(c[0].areas, 'neu');
  assert.equal(teamChips(s, [], marks, [], () => 'X')[0].areas, 'X');
});
test('teamMsgs: letzte 3 des Teams, neueste zuerst', () => {
  const ms = [msg('1', 'A1', 'start', 1), msg('2', 'A1', 'pause', 2), msg('3', 'A2', 'start', 3), msg('4', 'A1', 'ende', 4), msg('5', 'A1', 'fertig', 5, { pc: 40 })];
  assert.deepEqual(teamMsgs(sent, ms, 'T1').map((m) => m.id), ['5', '4', '2']);
});

test('ungelesen: nur eingegangene, nicht gesehene, ohne Fund/Hilfe', () => {
  const ms = [msg('a', 'A1', 'start', 1), msg('b', 'A1', 'pause', 2), msg('c', 'A1', 'ort', 3, { cat: 'fund' }), msg('d', 'A1', 'ende', 4)];
  const recv = {}; const seen = {};
  assert.equal(unreadMsgs(ms, seen, recv).length, 0); // alte Meldungen ohne Eingang: nie ungelesen
  noteReceived(recv, ms.slice(0, 3), T0);
  assert.deepEqual(unreadMsgs(ms, seen, recv).map((m) => m.id), ['a', 'b']);
  markSeen(seen, ['a']);
  assert.deepEqual(unreadMsgs(ms, seen, recv).map((m) => m.id), ['b']);
  markSeen(seen, unreadMsgs(ms, seen, recv));
  assert.equal(unreadMsgs(ms, seen, recv).length, 0);
  noteReceived(recv, ms, T0 + 5);
  assert.equal(recv.a, T0); // erste Zeit bleibt
  assert.deepEqual(unreadMsgs(ms, seen, recv).map((m) => m.id), ['d']);
});
test('prune hält die neuesten', () => {
  const o = { a: 1, b: 2, c: 3, d: 4 };
  prune(o, 2);
  assert.deepEqual(Object.keys(o).sort(), ['c', 'd']);
});

test('unreadAlert: Banner nach 5, Piepton nach 7 min, dann alle 2 min', () => {
  const u = [{ id: 'a' }, { id: 'b' }];
  const recv = { a: T0, b: T0 + min(3) };
  assert.equal(unreadAlert([], recv, T0 + min(99)), 'none');
  assert.equal(unreadAlert(u, recv, T0 + BANNER_MS - 1), 'none');
  assert.equal(unreadAlert(u, recv, T0 + BANNER_MS), 'banner');
  assert.equal(unreadAlert(u, recv, T0 + BEEP_MS - 1), 'banner');
  assert.equal(unreadAlert(u, recv, T0 + BEEP_MS), 'beep');
  assert.equal(unreadAlert(u, recv, T0 + BEEP_MS + 30e3, 0, T0 + BEEP_MS), 'banner');
  assert.equal(unreadAlert(u, recv, T0 + BEEP_MS + BEEP_EVERY_MS, 0, T0 + BEEP_MS), 'beep');
  // zählt ab der ältesten ungelesenen
  assert.equal(unreadAlert([{ id: 'b' }], recv, T0 + min(7)), 'none');
});
test('unreadAlert: Schlummern ruht, läuft ab, Banner sofort danach', () => {
  const u = [{ id: 'a' }];
  const recv = { a: T0 };
  const snooze = T0 + min(20);
  assert.equal(unreadAlert(u, recv, T0 + min(8), snooze), 'none');
  assert.equal(unreadAlert(u, recv, snooze - 1, snooze, T0 + min(7)), 'none');
  assert.equal(unreadAlert(u, recv, snooze, snooze, T0 + min(19)), 'banner'); // Piepen erst nach Regel (2 min)
  assert.equal(unreadAlert(u, recv, snooze, snooze, T0 + min(7)), 'beep');
  // neue Meldung während Schlummern: ungelesen, aber kein Alarm
  assert.equal(unreadAlert([{ id: 'n' }], { n: T0 + min(10) }, T0 + min(30), snooze + min(60)), 'none');
});
test('Fund/Hilfe bleiben von Schlummern unberührt (nie in der Ungelesen-Liste)', () => {
  const urgent = msg('u', 'A1', 'hilfe', 1);
  const recv = noteReceived({}, [urgent], T0);
  assert.equal(unreadMsgs([urgent], {}, recv).length, 0);
  assert.equal(unreadAlert(unreadMsgs([urgent], {}, recv), recv, T0 + min(30), T0 + min(60)), 'none');
});
test('bannerText und parseSnooze', () => {
  assert.equal(bannerText(3, min(5) + 5e3), '📣 3 ungelesene Meldungen seit 5 min – antippen');
  assert.equal(bannerText(1, min(9)), '📣 1 ungelesene Meldung seit 9 min – antippen');
  assert.equal(parseSnooze('10'), 10);
  assert.equal(parseSnooze(' 7,4 '), 7);
  assert.equal(parseSnooze('0'), null);
  assert.equal(parseSnooze('abc'), null);
  assert.equal(parseSnooze(''), null);
  assert.equal(parseSnooze('-5'), null);
  assert.equal(parseSnooze('99999'), null);
});

test('historyFilter: neueste oben, Filter je Team', () => {
  const ms = [msg('1', 'A1', 'start', 1), msg('2', 'A2', 'start', 2), msg('3', 'A1', 'pause', 3)];
  assert.deepEqual(historyFilter(ms, sent).map((m) => m.id), ['3', '2', '1']);
  assert.deepEqual(historyFilter(ms, sent, 'T1').map((m) => m.id), ['3', '1']);
  assert.deepEqual(historyFilter(ms, sent, 'T2').map((m) => m.id), ['2']);
  assert.deepEqual(historyTeams(sent, marks).map((t) => t.label), ['Juh 1', 'Juh 2']);
});

test('Store: neue Felder werden normalisiert', () => {
  const p = normalizeProject({ ...newProject('x'), msgSeen: [1], msgRecv: { a: '5', b: 'x' }, msgSnooze: 'q' });
  assert.deepEqual(p.msgSeen, {});
  assert.deepEqual(p.msgRecv, { a: 5 });
  assert.equal(p.msgSnooze, 0);
  const q = normalizeProject({ title: 'alt' });
  assert.deepEqual([q.msgSeen, q.msgRecv, q.msgSnooze], [{}, {}, 0]);
});
