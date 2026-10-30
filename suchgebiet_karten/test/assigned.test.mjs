import test from 'node:test';
import assert from 'node:assert/strict';
import { assignedOf, assignedCell, assignedGrid, markAccepted, isAccepted, unlockUntil, UNLOCK_MS } from '../web/locks.js';
import { msgLabel, msgIcon, buildMsg, withoutDeleted, mergeStatus } from '../web/status.js';
import { buildProgress, mergeProgress } from '../web/progress.js';
import { newProject, normalizeProject } from '../web/store.js';

const NOW = 1_000_000;
function proj() {
  const p = normalizeProject(newProject('Einsatz'));
  p.eid = 'E1';
  p.items = [{ id: 'i1', kind: 'track', pts: [] }, { id: 'i2', kind: 'track', pts: [] }];
  p.sent = [{ id: 'A1', team: 'Team 1', teamId: 'T1', grids: ['G1'], at: 500, acc: 0, items: ['i1'], cells: { G1: ['1,1', '2,2'] } }];
  return p;
}

test('nicht übernommener Auftrag schützt nichts', () => {
  const p = proj();
  assert.equal(isAccepted(p.sent[0]), false);
  assert.equal(assignedOf(p, p.items[0], NOW), null);
  assert.equal(assignedCell(p, 'G1', '1,1', NOW), null);
  assert.equal(assignedGrid(p, 'G1', NOW), null);
});

test('übernommener Auftrag schützt seine Items und Felder, andere bleiben frei', () => {
  const p = proj();
  p.sent[0].acc = 700;
  assert.equal(assignedOf(p, p.items[0], NOW), p.sent[0]);
  assert.equal(assignedOf(p, p.items[1], NOW), null);
  assert.equal(assignedOf(p, { kind: 'text' }, NOW), null); // ohne id
  assert.equal(assignedCell(p, 'G1', '2,2', NOW), p.sent[0]);
  assert.equal(assignedCell(p, 'G1', '3,3', NOW), null);
  assert.equal(assignedCell(p, 'G2', '1,1', NOW), null);
  assert.equal(assignedGrid(p, 'G1', NOW), p.sent[0]);
  assert.equal(assignedGrid(p, 'G2', NOW), null);
});

test('Freigabe gilt 5 Minuten und läuft ab', () => {
  const p = proj();
  p.sent[0].acc = 700;
  p.sent[0].unlock = unlockUntil(NOW);
  assert.equal(UNLOCK_MS, 300000);
  assert.equal(assignedOf(p, p.items[0], NOW + UNLOCK_MS - 1), null);
  assert.equal(assignedCell(p, 'G1', '1,1', NOW + 1000), null);
  assert.equal(assignedOf(p, p.items[0], NOW + UNLOCK_MS), p.sent[0]);
  assert.equal(assignedCell(p, 'G1', '1,1', NOW + UNLOCK_MS + 5), p.sent[0]);
});

test('erste Meldung setzt die Übernahme (frühste Zeit), spätere ändern sie nicht', () => {
  const p = proj();
  p.sent.push({ id: 'A2', team: 'Team 2', at: 600, acc: 0 });
  const msgs = [buildMsg({ a: 'A1', tm: 'Team 1', s: 'ok', t: 900, id: 'm2' }), buildMsg({ a: 'A1', tm: 'Team 1', s: 'start', t: 800, id: 'm1' })];
  assert.equal(markAccepted(p, msgs, NOW), 1);
  assert.equal(p.sent[0].acc, 800);
  assert.equal(p.sent[1].acc, 0);
  assert.equal(markAccepted(p, msgs, NOW), 0);
  assert.equal(p.sent[0].acc, 800);
  assert.equal(markAccepted(p, [], NOW), 0);
});

test('Quittung ok: Text, Symbol, ohne Standort', () => {
  const m = buildMsg({ a: 'A1', tm: 'Team 1', s: 'ok', pos: null, t: 1 });
  assert.equal(m.s, 'ok');
  assert.equal(m.lat, undefined);
  assert.equal(msgLabel(m), '📲 Auftrag übernommen');
  assert.equal(msgIcon(m), '📲');
});

test('gelöschte Meldungen werden herausgefiltert', () => {
  const a = buildMsg({ a: 'A1', tm: 'T', s: 'start', t: 1, id: 'a' });
  const b = buildMsg({ a: 'A1', tm: 'T', s: 'pause', t: 2, id: 'b' });
  assert.deepEqual(withoutDeleted([a, b], { a: 5 }).map((m) => m.id), ['b']);
  assert.deepEqual(withoutDeleted([a, b], {}).length, 2);
  assert.deepEqual(withoutDeleted([a, b], undefined).length, 2);
  assert.deepEqual(withoutDeleted(mergeStatus([a], [a, b]), { a: 1, b: 1 }), []);
});

test('normalizeProject: Altaufträge gelten als übernommen, neue (acc 0) nicht', () => {
  const p = normalizeProject({ ...newProject('X'), sent: [{ id: 'old', at: 123 }, { id: 'new', at: 456, acc: 0, items: ['x'], cells: { G: ['1,1'] } }, { at: 1 }] });
  assert.equal(p.sent.length, 2);
  assert.equal(p.sent[0].acc, 123);
  assert.equal(p.sent[1].acc, 0);
  assert.deepEqual(p.sent[1].items, ['x']);
  assert.deepEqual(p.msgDel, {});
  assert.equal(normalizeProject({ ...newProject('X'), msgDel: [] }).msgDel instanceof Array, false);
});

test('Fortschritt: acc, items, cells gehen mit, früheste Übernahme gewinnt, unlock bleibt lokal', () => {
  const el = proj();
  el.sent[0].acc = 800;
  el.sent[0].unlock = 99999999;
  el.sent[0].last = 900;
  const f = buildProgress(el, { from: 'EL', now: 5000, full: true });
  assert.equal(f.se[0].acc, 800);
  assert.deepEqual(f.se[0].items, ['i1']);
  assert.deepEqual(f.se[0].cells, { G1: ['1,1', '2,2'] });
  assert.equal(f.se[0].unlock, undefined);
  // anderes Gerät: kennt den Auftrag noch nicht übernommen
  const elw = proj();
  elw.sent[0].items = undefined;
  delete elw.sent[0].items;
  delete elw.sent[0].cells;
  mergeProgress(elw, f);
  assert.equal(elw.sent[0].acc, 800);
  assert.deepEqual(elw.sent[0].items, ['i1']);
  // späterer Wert überschreibt eine frühere Übernahme nicht
  const f2 = JSON.parse(JSON.stringify(f));
  f2.se[0].acc = 950;
  mergeProgress(elw, f2);
  assert.equal(elw.sent[0].acc, 800);
  const f3 = JSON.parse(JSON.stringify(f));
  f3.se[0].acc = 700;
  mergeProgress(elw, f3);
  assert.equal(elw.sent[0].acc, 700);
});

test('Fortschritt: nur Übernahme ist schon eine Änderung', () => {
  const el = proj();
  el.sent[0].acc = 2000;
  el.updated = 10;
  const f = buildProgress(el, { from: 'EL', since: 1500, now: 5000 });
  assert.ok(f && f.se.length === 1);
});

test('Fortschritt: Löschvermerke von Meldungen (md) filtern ms und kommen beim Empfänger an', () => {
  const el = proj();
  const m1 = buildMsg({ a: 'A1', tm: 'T', s: 'start', t: 100, id: 'm1' });
  const m2 = buildMsg({ a: 'A1', tm: 'T', s: 'pause', t: 200, id: 'm2' });
  el.live = { url: 'https://script.google.com/x', key: 'k', since: 0, ack: [], msgs: [m1, m2] };
  el.msgDel = { m1: 300 };
  const f = buildProgress(el, { from: 'EL', now: 5000, full: true });
  assert.deepEqual(f.ms.map((m) => m.id), ['m2']);
  assert.deepEqual(f.md, { m1: 300 });
  const other = proj();
  other.live = { url: 'https://script.google.com/x', key: 'k', since: 0, ack: [], msgs: [m1] };
  mergeProgress(other, f);
  assert.deepEqual(other.msgDel, { m1: 300 });
  assert.deepEqual(withoutDeleted(other.live.msgs, other.msgDel), [m2].filter((m) => other.live.msgs.includes(m)));
});
