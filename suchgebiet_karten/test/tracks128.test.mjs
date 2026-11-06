// v128: Track-Import – Liste, Vorauswahl, Kennzeichen, Zuordnung zu Team/Auftrag, Summen
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseGpx } from '../web/gpx.js';
import { listTracks, guessKind, importItems, importTotals, noteImport, importTag, durText, timeText, orderFor, isActiveLog } from '../web/tracks.js';

const NOW = Date.parse('2026-11-05T20:00:00Z');
const pt = (la, lo, t) => `<trkpt lat="${la}" lon="${lo}"><ele>40</ele><time>${new Date(t).toISOString()}</time></trkpt>`;
const trk = (name, t0, n = 20) => `<trk><name>${name}</name><trkseg>${Array.from({ length: n }, (_, i) => pt(52.6 + i * 0.001, 10.07, t0 + i * 60000)).join('')}</trkseg></trk>`;
const GPX = `<?xml version="1.0"?><gpx version="1.1" creator="Garmin">${trk('Rex Hund', NOW - 3600e3)}${trk('Hundeführer', NOW - 3600e3)}${trk('ACTIVE LOG 001', NOW - 2 * 3600e3)}${trk('Gestern', NOW - 30 * 3600e3)}</gpx>`;

test('parseGpx liest die Zeit der Punkte (t0/t1)', () => {
  const g = parseGpx(GPX);
  assert.equal(g.tracks.length, 4);
  assert.equal(g.tracks[0].t0, NOW - 3600e3);
  assert.equal(g.tracks[0].t1, NOW - 3600e3 + 19 * 60000);
  const ohne = parseGpx('<gpx><trk><name>x</name><trkseg><trkpt lat="1" lon="1"/><trkpt lat="1.1" lon="1"/></trkseg></trk></gpx>');
  assert.equal('t0' in ohne.tracks[0], false);
});

test('listTracks: ACTIVE LOG und ältere als 24 h sind vorab abgewählt', () => {
  const rows = listTracks(parseGpx(GPX).tracks, NOW);
  assert.deepEqual(rows.map((r) => r.pre), [true, true, false, false]);
  assert.match(rows[2].why, /ACTIVE LOG/);
  assert.match(rows[3].why, /24/);
  assert.ok(rows[0].len > 1500);
  assert.match(rows[0].time, /\(19 min\)/);
  assert.ok(isActiveLog('ACTIVE LOG 002') && !isActiveLog('Rex'));
});

test('Kennzeichen: Name vor Team-Typ', () => {
  assert.equal(guessKind('Hundeführer Kira'), 'm');
  assert.equal(guessKind('Rex Halsband'), 'h');
  assert.equal(guessKind('DJI Mavic Flug 3'), 'd');
  assert.equal(guessKind('Track 1', { ty: 'kette' }), 'm');
  assert.equal(guessKind('Track 1', { ty: 'drohne' }), 'd');
  assert.equal(guessKind('Track 1', { id: 'x' }), 'h');
});

function proj() {
  return {
    marks: [{ id: 'T1', kind: 'team', label: 'Team 1', color: '#1565c0' }, { id: 'T2', kind: 'team', label: 'Kette', color: '#2e7d32', ty: 'kette' }],
    sent: [{ id: 'A1', teamId: 'T1', at: 10, acc: 0 }, { id: 'A0', teamId: 'T1', at: 5, done: 99 }],
    items: [],
  };
}

test('importItems: Team, Kennzeichen, Zeit, resultKey nur mit Auftrag', () => {
  const p = proj();
  const g = parseGpx(GPX);
  const r = importItems(p, g.tracks, [{ i: 0, teamId: 'T1', kind: 'h' }, { i: 1, teamId: 'T2' }, { i: 3 }], { base: 'Kira_Garmin' });
  assert.equal(r.items.length, 3);
  const [a, b, c] = r.items;
  assert.equal(a.to, 'T1'); assert.equal(a.tk, 'h'); assert.equal(a.color, '#1565c0'); assert.ok(a.open && a.imp);
  assert.equal(a.t0, g.tracks[0].t0);
  assert.match(a.resultKey, /^A1\|timp/);
  assert.equal(b.to, 'T2'); assert.equal(b.tk, 'm'); assert.equal(b.resultKey, undefined); // Kette ohne Auftrag
  assert.equal(c.to, undefined); assert.equal(c.resultKey, undefined);
  assert.deepEqual(r.orders.map((x) => x.id), ['A1']);
  assert.equal(orderFor(p, 'T1').id, 'A1'); // der laufende, nicht der abgeschlossene
});

test('importTotals/noteImport: zählt wie eine Rückmeldung (km, Zeit, übernommen)', () => {
  const p = proj();
  const g = parseGpx(GPX);
  const r = importItems(p, g.tracks, [{ i: 0, teamId: 'T1' }, { i: 1, teamId: 'T1', kind: 'm' }]);
  p.items.push(...r.items);
  const x = p.sent[0];
  const tot = noteImport(p, x, 12345);
  assert.equal(tot.n, 2);
  assert.ok(tot.len > 3000);
  assert.equal(tot.ms, 2 * 19 * 60000);
  assert.equal(x.acc, 12345); assert.equal(x.last, 12345); assert.equal(x.n, 1);
  assert.match(x.lastSum, /km gelaufen, 38 min, Import/);
  assert.equal(importTotals(p, p.sent[1]).n, 0);
});

test('Texte', () => {
  assert.equal(durText(75 * 60000), '1 h 15 min');
  assert.equal(durText(9 * 60000), '9 min');
  assert.equal(timeText(NaN, NaN), '');
  assert.match(importTag({ imp: 1, tk: 'd', t0: NOW - 600000, t1: NOW }, NOW), /^🚁 Drohne · .*–.*\(10 min\)$/);
  assert.equal(importTag({ kind: 'track' }), '');
});
