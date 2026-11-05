// v127: Fehler aus dem Einsatz-Durchlauf (F4 Teamnamen, F6 Wegnamen, S6 HF-Fundstück, F7 Schnellexport)
import test from 'node:test';
import assert from 'node:assert/strict';
import { sameTeamName, nextTeamLabel, uniqueName } from '../web/uateam.js';
import { applyResult, buildAssignment } from '../web/share.js';
import { buildProgress, mergeProgress } from '../web/progress.js';
import { emptySel, subsetProject } from '../web/scope.js';
import { newProject, normalizeProject } from '../web/store.js';
import { pack, unpack } from '../web/share.js';

test('F4: doppelte Teamnamen werden erkannt, neue Teams bekommen die nächste freie Nummer', () => {
  const p = normalizeProject(newProject('E'));
  p.marks = [{ id: 'a', kind: 'team', label: 'Team 1' }, { id: 'b', kind: 'team', label: 'Team 3' }, { id: 's', kind: 'status', label: 'Team 2' }];
  assert.equal(sameTeamName(p.marks, ' team 1 ').id, 'a');
  assert.equal(sameTeamName(p.marks, 'Team 1', 'a'), null); // das Team selbst zählt nicht
  assert.equal(sameTeamName(p.marks, 'Team 2'), null); // nur Teams, keine Status-Marken
  assert.equal(sameTeamName(p.marks, ''), null);
  assert.equal(nextTeamLabel(p), 'Team 4'); // Team 1 und Team 3 vergeben (zwei Teams -> naive Zählung ergäbe 3)
});
test('F4: nextTeamLabel überspringt vergebene Nummern (auch nach Löschen/Umbenennen)', () => {
  const p = { marks: [{ kind: 'team', label: 'Team 2' }, { kind: 'team', label: 'Team 1' }] };
  assert.equal(nextTeamLabel(p), 'Team 3');
  assert.equal(nextTeamLabel({ marks: [{ kind: 'team', label: 'Team 2' }] }), 'Team 3');
  assert.equal(nextTeamLabel({ marks: [{ kind: 'team', label: 'Team 2' }, { kind: 'team', label: 'Anna' }, { kind: 'team', label: 'Team 3' }] }), 'Team 4');
});

function resultFor(p, teamId) {
  const sent = { id: 'A1', teamId, grids: [] };
  p.sent = [sent];
  return { a: 'A1', tm: 'Team 1', tr: [{ t: Date.UTC(2026, 10, 5, 18, 47), p: 'AAAAAAAA' }], i: [], d: [], w: [] };
}
test('F6: Wegname enthält den Hundenamen', async () => {
  const { encodePts } = await import('../web/share.js');
  const p = normalizeProject(newProject('E'));
  p.marks.push({ id: 'T1', kind: 'team', label: 'Team 1', dog: 'Rex', color: '#d50000' });
  p.marks.push({ id: 'T2', kind: 'team', label: 'Team 2 (Luna)', dog: 'Luna', color: '#1565c0' });
  p.sent = [{ id: 'A1', teamId: 'T1', grids: [] }, { id: 'A2', teamId: 'T2', grids: [] }];
  const tr = (a) => [{ t: Date.UTC(2026, 10, 5, 18, 47), p: encodePts([[52.1, 8.1], [52.101, 8.101], [52.102, 8.1]]) }].map((x) => ({ ...x, a }));
  applyResult(p, { a: 'A1', tm: 'Team 1', tr: tr('A1'), i: [], d: [], w: [] });
  applyResult(p, { a: 'A2', tm: 'Team 2', tr: tr('A2'), i: [], d: [], w: [] });
  const names = p.items.filter((i) => i.resultKey).map((i) => i.name);
  assert.match(names[0], /^Weg Team 1 \(Rex\) ab \d\d:\d\d$/);
  assert.match(names[1], /^Weg Team 2 \(Luna\) ab \d\d:\d\d$/); // Hund steht schon im Teamnamen: nicht doppelt
});
test('F6: gleichnamige Wege aus zwei UAs bekommen beim Zusammenführen den UA-Zusatz', async () => {
  const el = normalizeProject(newProject('Einsatz'));
  el.eid = 'E1';
  el.marks.push({ id: 'T1', kind: 'team', label: 'Team 1', color: '#d50000' });
  const way = (id) => ({ id, t: 5000, by: 'UA', kind: 'track', open: true, color: '#d50000', name: 'Weg Team 1 (Rex) ab 19:47', resultKey: `A|t${id}`, pts: [[52.1, 8.1], [52.101, 8.101]] });
  const mk = async (title, id) => {
    const ua = normalizeProject({ ...newProject(title), parentEid: 'E1', eid: `U${id}`, items: [way(id)] });
    ua.marks = el.marks.map((m) => ({ ...m }));
    return unpack(await pack(buildProgress(ua, { from: title, since: 0 })));
  };
  mergeProgress(el, await mk('Einsatz – UA Nord', 'w1'));
  mergeProgress(el, await mk('Einsatz – UA Süd', 'w2'));
  const names = el.items.map((i) => i.name);
  assert.equal(new Set(names).size, 2, names.join(' | '));
  assert.ok(names.some((n) => /\(UA Süd\)$/.test(n)));
  // erneutes Zusammenführen ändert die Namen nicht
  mergeProgress(el, await mk('Einsatz – UA Süd', 'w2'));
  assert.deepEqual(el.items.map((i) => i.name), names);
  assert.equal(uniqueName(['a'], 'b', 'UA X'), 'b');
});

test('S6: „Standort melden“ hat die Kategorie Fundstück mit Textvorschlägen; Label, Symbol, GPX-Name', async () => {
  const { SPOT_LIST, SPOT_HINTS, spotLabel, msgIcon, isUrgent, buildMsg } = await import('../web/status.js');
  const { msgWaypoints } = await import('../web/gpx.js');
  assert.ok(SPOT_LIST.some((s) => s.code === 'gegenstand' && s.ico === '🎒'));
  assert.deepEqual(SPOT_HINTS.gegenstand, ['Jacke', 'Schuh', 'Mütze', 'Rucksack']);
  assert.match(spotLabel('gegenstand'), /Fundstück/);
  const m = { ...buildMsg({ a: 'A', tm: 'Team 1', s: 'ort', cat: 'gegenstand', txt: 'Jacke', pos: { lat: 52.1, lon: 8.1 } }) };
  assert.equal(msgIcon(m), '🎒');
  assert.equal(isUrgent(m), false);
  assert.match(msgWaypoints([m])[0].name, /^Fundstück Team 1/);
});

test('UA sieht nur Meldungen seiner eigenen Teams; Fund/Hilfe aller Teams bleiben; Grund-Einsatz sieht alles', async () => {
  const { ownTeamMsgs } = await import('../web/locks.js');
  const { isUrgent } = await import('../web/status.js');
  const marks = [{ id: 'T1', kind: 'team', label: 'Team 1' }, { id: 'N1', kind: 'team', label: 'N-Team 1' }, { id: 's', kind: 'status', label: 'S-Team 1' }];
  const ua = { parentEid: 'E', marks, sent: [{ id: 'A1', teamId: 'N1' }, { id: 'A9', teamId: 'GONE' }] };
  const base = { marks, sent: [] };
  const msgs = [
    { id: '1', a: 'A1', tm: 'N-Team 1', s: 'start', t: 1 },
    { id: '2', a: 'B1', tm: 'S-Team 1', s: 'start', t: 2 }, // Team aus fremdem UA
    { id: '3', a: 'B1', tm: 'S-Team 1', s: 'ort', cat: 'fund', t: 3 }, // Fund: überall
    { id: '4', a: 'B2', tm: 'S-Team 1', s: 'ort', cat: 'hilfe', t: 4 },
    { id: '5', a: 'A9', tm: 'X', s: 'start', t: 5 }, // Auftrag eines nicht (mehr) vorhandenen Teams
    { id: '6', a: 'Z', tm: 'Team 1', s: 'pause', t: 6 }, // fremder Auftrag trotz gleichem Teamnamen (zwei UAs mit „Team 1“)
    { id: '8', tm: 'Team 1', s: 'msg', t: 8 }, // ohne Auftrag: Teamname zählt
    { id: '7', a: 'B1', tm: 'S-Team 1', s: 'ort', cat: 'hinweis', t: 7 },
  ];
  assert.deepEqual(ownTeamMsgs(ua, msgs, isUrgent).map((m) => m.id), ['1', '3', '4', '8']);
  assert.equal(ownTeamMsgs(base, msgs, isUrgent).length, 8);
});
