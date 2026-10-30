import test from 'node:test';
import assert from 'node:assert/strict';
import {
  isDone, msgPct, closeMsg, sentPct, closeAsk, declineClose, closeSent, reopenSent, predecessorGroups, predecessorText,
} from '../web/closeout.js';
import { msgLabel, msgIcon, statusLabel, NO_POS, STATUS_LIST, buildMsg } from '../web/status.js';
import { teamChips } from '../web/statusbar.js';
import { assignedOf, assignedCell, canEdit, canDelete, denied } from '../web/locks.js';
import { buildAssignment, projectFromAssignment, assignmentSummary } from '../web/share.js';
import { newProject, normalizeProject } from '../web/store.js';

const T0 = new Date('2026-10-30T12:00:00').getTime();
const min = (n) => n * 60e3;
const msg = (id, a, s, dt, extra = {}) => ({ id, a, tm: 'Team 1', t: T0 + min(dt), s, ...extra });

test('Meldung zu: Text, Icon, Prozent, ohne Standort', () => {
  assert.equal(statusLabel('zu'), '✅ Auftrag abgeschlossen');
  assert.equal(msgLabel({ s: 'zu', pc: 80 }), '✅ Auftrag abgeschlossen (80 %)');
  assert.equal(msgLabel({ s: 'zu' }), '✅ Auftrag abgeschlossen');
  assert.equal(msgLabel({ s: 'zu', pc: 40, ar: [['Nord', 40], ['Süd', 100]] }), '✅ Auftrag abgeschlossen (Nord 40 % · Süd ✅)');
  assert.equal(msgIcon({ s: 'zu' }), '✅');
  assert.ok(NO_POS.includes('zu'));
  assert.ok(!STATUS_LIST.some((s) => s.code === 'zu')); // eigener Knopf, nicht in der Stand-Liste
  const m = buildMsg({ a: 'A1', tm: 'T', s: 'zu', pc: 80, txt: 'Hund müde', pos: null });
  assert.equal(m.pc, 80);
  assert.equal(m.txt, 'Hund müde');
  assert.equal(m.lat, undefined);
});

test('msgPct / sentPct', () => {
  assert.equal(msgPct({ pc: 80 }), 80);
  assert.equal(msgPct({ pc: 90, ar: [['A', 70], ['B', 100]] }), 70);
  assert.equal(msgPct({ s: 'ok' }), null);
  const x = { id: 'A1' };
  assert.equal(sentPct(x, []), null);
  assert.equal(sentPct(x, [msg('1', 'A1', 'fertig', 5, { pc: 50 }), msg('2', 'A1', 'zu', 9, { pc: 80 })]), 80);
  assert.equal(sentPct({ id: 'A1', pct: 60 }, [msg('2', 'A1', 'zu', 9, { pc: 80 })]), 60);
});

test('closeAsk: Meldung + Rückmeldung in beiden Reihenfolgen', () => {
  const zu = msg('z1', 'A1', 'zu', 30, { pc: 80 });
  // nur Meldung
  assert.equal(closeAsk({ id: 'A1', acc: 1 }, [zu]), null);
  // nur Rückmeldung
  assert.equal(closeAsk({ id: 'A1', acc: 1, last: T0, n: 1 }, []), null);
  // beides (egal ob die Rückmeldung zuerst kam: x.last ist gesetzt, die Meldung kommt später)
  assert.equal(closeAsk({ id: 'A1', acc: 1, last: T0, n: 1 }, [zu]), zu);
  // Meldung eines anderen Auftrags zählt nicht
  assert.equal(closeAsk({ id: 'A2', acc: 1, last: T0, n: 1 }, [zu]), null);
  // schon abgeschlossen
  assert.equal(closeAsk({ id: 'A1', acc: 1, last: T0, n: 1, done: T0 }, [zu]), null);
});
test('closeAsk: nach „Noch offen lassen“ nicht doppelt für dieselbe Rückmeldung', () => {
  const zu = msg('z1', 'A1', 'zu', 30, { pc: 80 });
  const x = { id: 'A1', acc: 1, last: T0, n: 1 };
  declineClose(x, [zu]);
  assert.equal(closeAsk(x, [zu]), null);
  x.n = 2; // neue Rückmeldung
  assert.equal(closeAsk(x, [zu]), zu);
  declineClose(x, [zu]);
  const zu2 = msg('z2', 'A1', 'zu', 50, { pc: 90 }); // neue Abschluss-Meldung
  assert.equal(closeAsk(x, [zu, zu2]), zu2);
});
test('closeSent / reopenSent', () => {
  const zu = msg('z1', 'A1', 'zu', 30, { pc: 80 });
  const x = { id: 'A1', acc: 1, last: T0, n: 1, unlock: T0 + 1 };
  closeSent(x, [zu], T0 + min(40));
  assert.ok(isDone(x));
  assert.equal(x.pct, 80);
  assert.equal(x.unlock, undefined);
  reopenSent(x, [zu]);
  assert.ok(!isDone(x));
  assert.equal(closeAsk(x, [zu]), null); // nach „Wieder öffnen“ keine sofortige Rückfrage
  assert.equal(closeMsg([zu], 'A1'), zu);
});

test('abgeschlossener Auftrag: kein 🔒-Schutz mehr, kein Chip', () => {
  const p = { sent: [{ id: 'A1', acc: T0, items: ['i1'], cells: { G1: ['1,1'] } }] };
  assert.ok(assignedOf(p, { id: 'i1' }, T0 + 1));
  assert.ok(assignedCell(p, 'G1', '1,1', T0 + 1));
  p.sent[0].done = T0 + 5;
  assert.equal(assignedOf(p, { id: 'i1' }, T0 + 6), null);
  assert.equal(assignedCell(p, 'G1', '1,1', T0 + 6), null);
  const marks = [{ id: 'T1', kind: 'team', label: 'Team 1', color: '#000' }];
  const sent = [{ id: 'A1', teamId: 'T1', team: 'Team 1', at: T0, acc: T0, last: T0 + min(20), n: 1 }];
  const zu = msg('z1', 'A1', 'zu', 10, { pc: 80 });
  // Rückmeldung da, Team meldet abgeschlossen: Chip bleibt bis zum Abschließen
  let c = teamChips(sent, [zu], marks, []);
  assert.equal(c.length, 1);
  assert.match(c[0].status, /^✅ meldet abgeschlossen \d\d:\d\d \(80 %\)$/);
  sent[0].done = T0 + min(25);
  assert.equal(teamChips(sent, [zu], marks, []).length, 0);
});

// ---------- Vorgänger-Rückmeldungen ----------
function proj() {
  const p = normalizeProject(newProject('Einsatz'));
  p.marks.push({ id: 'T1', kind: 'team', label: 'Team 1', color: '#1565c0', dog: '' }, { id: 'T2', kind: 'team', label: 'Team 2', color: '#2e7d32', dog: '' });
  p.area = { north: 52.30, south: 52.29, west: 8.00, east: 8.01 };
  p.gridId = 'G1';
  p.cellM = 100;
  p.fills = { '0,0': 'T1', '1,0': 'T1' };
  p.otherGrids = [{ id: 'G2', name: 'Süd', area: { north: 52.20, south: 52.19, west: 8.00, east: 8.01 }, cellM: 100, fills: {}, status: {} }];
  p.sent = [{ id: 'A1', teamId: 'T1', team: 'Team 1', at: T0, acc: T0, last: T0 + min(20), n: 1, done: T0 + min(30), pct: 80, grids: ['G1'] }];
  p.items = [
    { kind: 'track', open: true, color: '#1565c0', name: 'Weg Team 1', pts: [[52.2995, 8.0005], [52.2990, 8.0020]], resultKey: 'A1|t1' }, // im Gebiet
    { kind: 'text', color: '#1565c0', text: 'Fund', lat: 52.2992, lon: 8.0010, resultKey: 'A1|i2' },
    { kind: 'track', open: true, color: '#1565c0', name: 'Weg weit weg', pts: [[52.2500, 8.1], [52.2510, 8.1]], resultKey: 'A1|t3' }, // außerhalb
    { kind: 'track', open: true, color: '#555', name: 'Weg im Süd-Raster', pts: [[52.1950, 8.005], [52.1951, 8.006]], resultKey: 'A9|t1' },
    { kind: 'text', color: '#000', text: 'eigener Text', lat: 52.2992, lon: 8.0010 }, // keine Rückmeldung
  ];
  return normalizeProject(p);
}
test('predecessorGroups: Rückmeldungen nach Gebiet', () => {
  const p = proj();
  const g = predecessorGroups(p, { teamId: 'T2', gridIds: ['G1'], fields: 'all' }, []);
  assert.equal(g.length, 1);
  assert.equal(g[0].a, 'A1');
  assert.equal(g[0].team, 'Team 1');
  assert.equal(g[0].pct, 80);
  assert.equal(g[0].label, 'Team 1, 80 %');
  assert.deepEqual(g[0].items.map((it) => it.resultKey), ['A1|t1', 'A1|i2']);
  assert.equal(predecessorText(g[0]), 'Vom vorherigen Team (Team 1, 80 %) – 1 Weg, 1 Markierung');
  // anderes Raster: nur dessen Rückmeldung (Auftrag unbekannt)
  const g2 = predecessorGroups(p, { teamId: 'T2', gridIds: ['G2'], fields: 'all' }, []);
  assert.deepEqual(g2.map((x) => x.a), ['A9']);
  assert.equal(g2[0].team, 'früheres Team');
  // kein Gebiet gewählt
  assert.deepEqual(predecessorGroups(p, { teamId: 'T2', gridIds: [], fields: 'all' }, []), []);
});
test('predecessorGroups: nur Felder des Teams bzw. angetippte Felder', () => {
  const p = proj();
  // Team 2 hat Feld 5,5 (leer in den Daten): Spuren in 0,0/1,0 gehören nicht dazu
  p.fills['5,5'] = 'T2';
  assert.deepEqual(predecessorGroups(p, { teamId: 'T2', gridIds: ['G1'], fields: 'team' }, []), []);
  // Team 1 hat die Felder mit den Spuren; sein Auftrag ist abgeschlossen -> Spuren gehen mit (Neuvergabe an dasselbe Team)
  assert.equal(predecessorGroups(p, { teamId: 'T1', gridIds: ['G1'], fields: 'team' }, []).length, 1);
  // laufender Auftrag desselben Teams: eigene Spuren bleiben draußen
  delete p.sent[0].done;
  assert.deepEqual(predecessorGroups(p, { teamId: 'T1', gridIds: ['G1'], fields: 'team' }, []), []);
  // angetippte Felder
  const sel = { teamId: 'T2', gridIds: ['G1'], fields: 'pick', picked: { G1: ['0,0'] } };
  assert.equal(predecessorGroups(p, sel, []).length, 1);
  assert.deepEqual(predecessorGroups(p, { ...sel, picked: { G1: ['3,3'] } }, []), []);
});
test('predecessorGroups: gewählter Umriss', () => {
  const p = proj();
  p.otherGrids = [];
  const area = { kind: 'track', pts: [[52.2999, 8.0], [52.2999, 8.003], [52.2985, 8.003], [52.2985, 8.0]] };
  const g = predecessorGroups(p, { teamId: 'T2', gridIds: [], fields: 'team', areaItems: [area] }, []);
  assert.deepEqual(g[0].items.map((it) => it.resultKey), ['A1|t1', 'A1|i2']);
});

test('Auftrag mit Vorgänger-Spuren: pv, Text, beim HF grau-gesperrt und nicht zurückgeschickt', async () => {
  const p = proj();
  const sel = { teamId: 'T2', gridIds: ['G1'], fields: 'all', itemIdx: [4], prev: [{ team: 'Team 1', pct: 80, itemIdx: [0, 1] }] };
  const a = buildAssignment(p, sel);
  assert.equal(a.i.length, 3);
  assert.equal(a.i.filter((x) => x.pv === 'Team 1').length, 2);
  assert.equal(a.pr, '80 % von Team 1 abgesucht');
  assert.match(assignmentSummary(a), /Vorher: 80 % von Team 1 abgesucht/);
  const hf = projectFromAssignment(a);
  const prev = hf.items.filter((it) => it.prev);
  assert.equal(prev.length, 2);
  assert.ok(prev.every((it) => it.fromEl && it.prev === 'Team 1'));
  assert.equal(hf.hf.prev, '80 % von Team 1 abgesucht');
  assert.ok(!canEdit(hf, prev[0]) && !canDelete(hf, prev[0]));
  assert.match(denied(hf, prev[0], 'delete'), /vorherigen Team \(Team 1\)/);
  const { buildResult } = await import('../web/share.js');
  const r = buildResult(hf, 5);
  assert.equal(r.i.length, 0); // nichts doppelt zurück
  // ohne Vorgänger: kein pr
  assert.equal(buildAssignment(p, { ...sel, prev: [] }).pr, undefined);
});
