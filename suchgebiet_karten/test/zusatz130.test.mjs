// v130: Zusatz zum laufenden Auftrag (Punkte, Umrisse, Lage-Orte, Raster, B-Ort über den Status-Server)
import test from 'node:test';
import assert from 'node:assert/strict';
import { buildZusatz, applyZusatz, isZusatz, zusatzText, ZUSATZ_MAX } from '../web/zusatz.js';
import { forHf, EL_ALL } from '../web/status.js';
import { newProject, normalizeProject } from '../web/store.js';
import { buildResult } from '../web/share.js';

function elProject() {
  const p = normalizeProject(newProject('Test'));
  p.items.push({ kind: 'track', color: '#ff0000', name: 'Bahndamm Ost', w: 4, pts: [[52.67, 10.10], [52.671, 10.101], [52.669, 10.102]] });
  p.items.push({ kind: 'text', color: '#000', text: 'Hütte', lat: 52.672, lon: 10.103 });
  p.pois = [{ id: 'poi1', cat: 'park', lat: 52.66, lon: 10.09, name: 'Parkplatz Süd', desc: 'Zufahrt Waldweg' }];
  p.meet = { lat: 52.674, lon: 10.083, text: 'Ortsrand' };
  Object.assign(p, { gridId: 'g1', gridName: 'Raster 1', area: { north: 52.68, south: 52.66, west: 10.09, east: 10.12 }, cellM: 100, fills: { '0,0': 'team-a', '1,0': 'team-b' }, status: {} });
  return p;
}
function hfProject() {
  const p = normalizeProject(newProject('HF'));
  p.hf = { id: 'auftrag-1', team: 'Mia', received: Date.now() - 1000, grids: [], track: [], outbox: [], log: [], inbox: [] };
  return p;
}

test('Zusatz: nichts gewählt -> null', () => {
  assert.equal(buildZusatz(elProject(), { to: 'auftrag-1' }), null);
});

test('Zusatz: Umriss, neuer Punkt mit eigener Aufgabe, Lage-Ort und B-Ort; Aufgabe hängt an allem', () => {
  const p = elProject();
  const r = buildZusatz(p, {
    to: 'auftrag-1', itemIdx: [0], poiIds: ['poi1'], meet: true, task: 'Bitte absuchen und melden',
    points: [{ lat: 52.6701, lon: 10.1012, name: 'Wärmequelle', task: 'Mit Hund prüfen, Vorsicht Böschung' }], prio: true,
  });
  assert.ok(r);
  const m = r.msg;
  assert.equal(m.s, 'el');
  assert.equal(m.to, 'auftrag-1');
  assert.equal(m.prio, 1);
  assert.ok(isZusatz(m));
  assert.match(m.txt, /^📍 Neu auf deiner Karte: Umriss „Bahndamm Ost“, Punkt „Wärmequelle“ \(Mit Hund prüfen, Vorsicht Böschung\), Ort „Parkplatz Süd“ und 1 weitere\. Auftrag: Bitte absuchen und melden$/);
  assert.equal(m.z.i.length, 2);
  assert.equal(m.z.i[0].d, 'Bitte absuchen und melden'); // Aufgabe am Umriss
  assert.equal(m.z.i[1].d, 'Mit Hund prüfen, Vorsicht Böschung'); // eigene Aufgabe am Punkt
  assert.equal(m.z.po[0][5], 'Bitte absuchen und melden · Zufahrt Waldweg');
  assert.deepEqual(m.z.mp, [52.674, 10.083, 'Ortsrand']);
  assert.ok(r.size < ZUSATZ_MAX);
});

test('Zusatz geht wie eine Nachricht an den richtigen Auftrag (auch „an alle“)', () => {
  const p = elProject();
  const a = buildZusatz(p, { to: 'auftrag-1', itemIdx: [1] }).msg;
  const all = buildZusatz(p, { to: EL_ALL, itemIdx: [1] }).msg;
  const other = buildZusatz(p, { to: 'auftrag-2', itemIdx: [1] }).msg;
  assert.deepEqual(forHf([a, all, other], 'auftrag-1').map((m) => m.id), [a.id, all.id]);
});

test('Raster: Felder des Ziel-Teams werden hervorgehoben', () => {
  const p = elProject();
  const r = buildZusatz(p, { to: 'auftrag-1', teamId: 'team-a', gridIds: ['g1'] });
  assert.deepEqual(r.msg.z.g[0].f, ['0,0']);
  const hf = hfProject();
  applyZusatz(hf, r.msg);
  assert.equal(hf.area.north, 52.68);
  assert.deepEqual(hf.fills, { '0,0': 'team' });
});

test('HF übernimmt den Zusatz einmal, schreibgeschützt, mit Aufgabe; Lage-Ort wird bei erneutem Senden aktualisiert', () => {
  const el = elProject();
  const m = buildZusatz(el, { to: 'auftrag-1', itemIdx: [0], poiIds: ['poi1'], points: [{ lat: 52.67, lon: 10.1, name: 'Punkt A' }], task: 'Absuchen' }).msg;
  const hf = hfProject();
  const r1 = applyZusatz(hf, m);
  assert.equal(r1.added, 3);
  assert.ok(r1.pts.length >= 4);
  applyZusatz(hf, m); // doppelt schadet nicht
  assert.equal(hf.items.length, 2);
  assert.ok(hf.items.every((it) => it.fromEl && it.zid === m.id));
  assert.ok(hf.items.every((it) => it.marker)); // v130.2: bleibt bei jeder Zoomstufe sichtbar
  const pt = hf.items.find((it) => it.kind === 'text');
  assert.equal(pt.text, 'Punkt A');
  assert.equal(pt.note, 'Absuchen');
  assert.equal(hf.items.find((it) => it.kind === 'track').note, 'Absuchen');
  // Treffpunkt verschoben und erneut gesendet -> derselbe Lage-Ort, neue Lage
  el.pois[0].lat = 52.661;
  const m2 = buildZusatz(el, { to: 'auftrag-1', poiIds: ['poi1'] }).msg;
  applyZusatz(hf, m2);
  assert.equal(hf.pois.length, 1);
  assert.equal(hf.pois[0].lat, 52.661);
});

test('Zusatz geht nicht mit der Rückmeldung des HF zurück', () => {
  const el = elProject();
  const hf = hfProject();
  applyZusatz(hf, buildZusatz(el, { to: 'auftrag-1', itemIdx: [0, 1] }).msg);
  assert.equal(buildResult(hf).i.length, 0);
});

test('normale Nachricht ist kein Zusatz; Text wird gekürzt', () => {
  assert.equal(applyZusatz(hfProject(), { s: 'el', id: 'x', t: 1, txt: 'Hallo' }), null);
  const t = zusatzText(['A', 'B', 'C', 'D', 'E'], 'x'.repeat(400));
  assert.ok(t.length <= 300);
  assert.match(t, /und 2 weitere/);
});
