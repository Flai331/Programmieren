import test from 'node:test';
import assert from 'node:assert/strict';
import {
  pack, unpack, parseShared, shareLink, encodePts, decodePts, simplify, buildAssignment, projectFromAssignment, buildResult, applyResult,
} from '../web/share.js';
import { newProject, normalizeProject, startNewGrid } from '../web/store.js';

function elProject() {
  const p = normalizeProject(newProject('Vermisst Musterwald'));
  p.area = { north: 52.30, south: 52.28, west: 8.00, east: 8.04 };
  p.cellM = 100;
  const team = { id: 'T2', kind: 'team', label: 'Team 2', color: '#1565c0', dog: 'Kira' };
  p.marks.push(team);
  p.fills = { '1,1': 'T2', '2,1': 'T2', '5,5': 'X' };
  const done = p.marks.find((m) => m.label === 'abgesucht');
  p.status = { '1,1': done.id };
  p.items = [{ kind: 'track', color: '#000', name: 'Waldstück', pts: [[52.29, 8.01], [52.295, 8.02], [52.29, 8.03]] }];
  p.meet = { lat: 52.281, lon: 8.001, text: 'Parkplatz' };
  p.mission.person = 'Herr M., 82 J., Demenz';
  return p;
}

test('packen/entpacken, Link erkennen', async () => {
  const o = { a: 1, b: 'Grüße', c: [1, 2, 3] };
  const s = await pack(o);
  assert.match(s, /^[A-Za-z0-9_-]+$/);
  assert.deepEqual(await unpack(s), o);
  const link = shareLink('a', s);
  assert.deepEqual(parseShared(`Hallo, hier dein Auftrag: ${link} !`), { kind: 'a', data: s });
  assert.equal(parseShared('kein Link'), null);
});

test('Punkte kompakt und vereinfacht', () => {
  const pts = [[52.12345, 8.54321], [52.12346, 8.54325], [52.2, 8.6]];
  assert.deepEqual(decodePts(encodePts(pts)), pts);
  const line = Array.from({ length: 100 }, (_, i) => [52 + i * 1e-5, 8 + (i % 2) * 1e-6]);
  assert.ok(simplify(line, 5).length <= 3);
});

test('Auftrag: nur gewählte Teile, Datenschutz, passt in einen QR-Code', async () => {
  const p = elProject();
  const a = buildAssignment(p, { teamId: 'T2', gridIds: [p.gridId], fields: 'team', itemIdx: [0], meet: true, hint: 'Bahnlinie im Osten!', person: false, rescue: [{ n: 'OS-1', lat: 52.285, lon: 8.02 }] });
  assert.deepEqual(a.g[0].f.sort(), ['1,1', '2,1']);
  assert.equal(a.vp, undefined);
  assert.equal(a.tm.l, 'Team 2');
  const s = await pack(a);
  assert.ok(shareLink('a', s).length < 1200, String(s.length));
  const hf = projectFromAssignment(await unpack(s));
  assert.equal(hf.title, 'Vermisst Musterwald – Team 2');
  assert.deepEqual(hf.area, p.area);
  assert.equal(Object.keys(hf.fills).length, 2);
  assert.equal(hf.marks.find((m) => m.id === hf.status['1,1']).label, 'abgesucht');
  assert.equal(hf.items[0].fromEl, true);
  assert.equal(hf.meet.text, 'Parkplatz');
  assert.equal(hf.hf.hint, 'Bahnlinie im Osten!');
  assert.equal(hf.hfRescue[0].n, 'OS-1');
  const withPerson = buildAssignment(p, { teamId: 'T2', gridIds: [p.gridId], fields: 'all', person: true });
  assert.match(withPerson.vp, /Demenz/);
  // ganzes Gebiet: andere Teams grau dabei
  assert.deepEqual(withPerson.g[0].o, ['5,5']);
  const hf2 = projectFromAssignment(withPerson);
  assert.equal(hf2.fills['5,5'], 'others');
  assert.equal(hf2.fills['1,1'], 'team');
});

test('Rückmeldung: Weg, Markierung, Feldstatus kommen beim richtigen Team an, doppelt scannen schadet nicht', async () => {
  const el = elProject();
  startNewGrid(el); // zweites Gebiet anlegen, damit Zuordnung über Gebiets-IDs geprüft wird
  const firstId = el.otherGrids[0].id;
  const a = buildAssignment(el, { teamId: 'T2', gridIds: [firstId], fields: 'team' });
  el.sent = [{ id: a.id, teamId: 'T2', grids: a.g.map((g) => g.i) }];
  const hf = projectFromAssignment(await unpack(await pack(a)));
  hf.hf.track.push({ t0: 1000, pts: Array.from({ length: 50 }, (_, i) => [52.29 + i * 1e-4, 8.01 + (i % 5) * 1e-4]) });
  hf.items.push({ kind: 'text', color: '#1565c0', lat: 52.291, lon: 8.011, text: '⚠️ Anzeige 14:32', t: 5 });
  const partly = hf.marks.find((m) => m.label === 'teilweise abgesucht');
  hf.status['2,1'] = partly.id;
  hf.mission.wind.push({ t: Date.now(), from: 270, strength: 'medium', src: 'gemessen', lat: 52.29, lon: 8.01 });
  const r = await unpack(await pack(buildResult(hf)));
  const sum = applyResult(el, r);
  assert.equal(sum.winds, 1);
  assert.equal(el.mission.wind[0].by, 'Team 2');
  assert.equal(el.mission.wind[0].from, 270);
  assert.equal(sum.known, true);
  assert.equal(sum.ways, 1);
  assert.equal(sum.marks, 1);
  assert.equal(sum.fields, 1);
  const g = el.otherGrids.find((x) => x.id === firstId) || el;
  assert.equal(el.marks.find((m) => m.id === g.status['2,1']).label, 'teilweise abgesucht');
  const way = el.items.find((it) => it.kind === 'track' && it.name.startsWith('Weg Team 2'));
  assert.equal(way.color, '#1565c0');
  // gleiche Rückmeldung nochmal: nichts doppelt
  const again = applyResult(el, r);
  assert.equal(again.ways + again.marks + again.fields, 0);
  // später längerer Weg: ersetzt den alten
  hf.hf.track[0].pts.push([52.3, 8.02]);
  applyResult(el, await unpack(await pack(buildResult(hf))));
  assert.equal(el.items.filter((it) => it.kind === 'track' && it.name.startsWith('Weg Team 2')).length, 1);
});
