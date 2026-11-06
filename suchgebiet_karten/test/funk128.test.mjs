// v128: Funkmeldung für ein Team, Fund der EL, Einsatzzeiten, UA-Übersicht, Auto-Abschluss, Bericht
import test from 'node:test';
import assert from 'node:assert/strict';
import { FUNK_KINDS, funkKind, funkLabel, timeOfDay, funkTargets, buildFunkMsg, addFunkMsg, buildFindMsg, msgSource } from '../web/funk.js';
import { FIND_KINDS, isFind, findLabel, forAllUa, FIND_A, checkText, findStatusText } from '../web/finds.js';
import { isUrgent, msgLabel, buildKor, applyKor, mergeStatus, msgIcon } from '../web/status.js';
import { ownTeamMsgs, isAccepted } from '../web/locks.js';
import { msgWaypoints, msgRows, buildGpx } from '../web/gpx.js';
import { timesOf, teamTimes, timeLine, timeRows, outsideTeams, personHours, totalPersonHours } from '../web/times.js';
import { uaOverview, BASE_UA, hasUas, agoText, levelIcon } from '../web/uaover.js';
import { autoCloseDue, closeSent, reopenSent, closeMsg } from '../web/closeout.js';
import { missionText, newMission } from '../web/mission.js';
import { newProject, normalizeProject } from '../web/store.js';

const T = (h, m = 0) => new Date(2026, 10, 5, h, m).getTime();
const NOW = T(22, 0);
const marks = () => [
  { id: 'K', kind: 'team', label: 'Kette FF', color: '#1565c0', ty: 'kette', org: 'FF', pers: 6 },
  { id: 'H', kind: 'team', label: 'Team 1', color: '#2e7d32', dog: 'Rex' },
];
const sent = () => [{ id: 'AK', teamId: 'K', team: 'Kette FF', at: T(17, 30), acc: 0 }, { id: 'AH', teamId: 'H', team: 'Team 1', at: T(17, 40), acc: T(17, 45) }];

test('timeOfDay: HH:MM von heute, in der Zukunft = gestern, ungültig null', () => {
  assert.equal(timeOfDay('20:05', NOW), T(20, 5));
  assert.equal(timeOfDay('2005', NOW), T(20, 5));
  assert.equal(timeOfDay('23:30', NOW), T(23, 30) - 24 * 3600e3);
  assert.equal(timeOfDay('', NOW), NOW);
  assert.equal(timeOfDay('25:99', NOW), null);
});

test('Funkmeldung: wie HF-Meldung, Quelle Funk + Gerät, Auftrag gilt als übernommen', () => {
  const p = normalizeProject(newProject('E'));
  p.marks = marks(); p.sent = sent();
  const tg = funkTargets(p);
  assert.equal(tg.length, 2);
  const m = buildFunkMsg({ x: p.sent[0], team: p.marks[0], kind: 'start', t: T(18, 5), by: 'ELW' });
  assert.equal(m.a, 'AK'); assert.equal(m.tm, 'Kette FF'); assert.equal(m.s, 'start'); assert.equal(m.src, 'f'); assert.equal(m.by, 'ELW'); assert.equal(m.ty, 'kette'); assert.equal(m.t, T(18, 5));
  assert.equal(msgSource(m), '📻 Funk (ELW)');
  assert.equal(isAccepted(p.sent[0]), false);
  p.live = { url: 'https://script.google.com/macros/s/x/exec', key: 'k', since: 0, ack: [], msgs: [], out: [], outbox: [], reads: {}, qSent: {} };
  assert.equal(addFunkMsg(p, m), true);
  assert.equal(addFunkMsg(p, m), false); // nicht doppelt
  assert.equal(p.live.msgs.length, 1);
  assert.equal(isAccepted(p.sent[0]), true);
  assert.equal(p.sent[0].acc, T(18, 5));
  const f = buildFunkMsg({ x: p.sent[0], team: p.marks[0], kind: 'fertig', pc: 40 });
  assert.equal(f.pc, 40);
  assert.equal(msgLabel(f), '📊 40 % abgesucht');
  const o = buildFunkMsg({ x: p.sent[0], team: p.marks[0], kind: 'anzeige', pos: { lat: 52.6, lon: 10.07 }, txt: 'Böschung' });
  assert.equal(o.lat, 52.6); assert.equal(msgLabel(o), '🐕 Trupp zeigt an');
  assert.equal(funkLabel(funkKind('anzeige'), 'kette'), 'Trupp zeigt an');
  assert.equal(buildFunkMsg({ x: p.sent[0], kind: 'start' }).tm, 'Kette FF');
  assert.equal(buildFunkMsg({ x: null, kind: 'start' }), null);
  assert.ok(FUNK_KINDS.some((k) => k.code === 'pause') && FUNK_KINDS.some((k) => k.code === 'abloes'));
});

test('Funkmeldung ohne Status-Server geht in die QR-Meldungen', () => {
  const p = normalizeProject(newProject('E'));
  p.marks = marks(); p.sent = sent();
  assert.equal(addFunkMsg(p, buildFunkMsg({ x: p.sent[0], team: p.marks[0], kind: 'pause' })), true);
  assert.equal(p.qmsgs.length, 1);
});

test('Fund der EL: Meldung mit Ort, Art, Status, Finder, Foto; Dringend; für alle UAs; Bericht/GPX', () => {
  assert.equal(FIND_KINDS.map((k) => k.code).join(), 'kleid,gegen,spur,waerme,sonst');
  const m = buildFindMsg({ art: 'kleid', txt: 'blaue Jacke', pos: { lat: 52.6, lon: 10.07 }, finder: 'FF-Trupp 3', foto: true, dringend: true, t: T(20, 5), by: 'EL-Handy' });
  assert.equal(m.a, FIND_A); assert.notEqual(m.a, 'EL');
  assert.equal(m.s, 'ort'); assert.equal(m.cat, 'gegenstand'); assert.equal(m.fa, 'kleid'); assert.equal(m.fs, 'o'); assert.equal(m.fb, 'FF-Trupp 3'); assert.equal(m.ph, 1); assert.equal(m.dr, 1);
  assert.ok(isFind(m)); assert.ok(isUrgent(m));
  assert.equal(msgLabel(m), '👕 Kleidungsstück'); assert.equal(msgIcon(m), '👕');
  assert.equal(findLabel('waerme'), '🔥 Wärmequelle');
  assert.equal(findStatusText(m), '⏳ offen');
  assert.equal(buildFindMsg({ art: 'x', pos: { lat: 1, lon: 1 } }), null);
  assert.equal(buildFindMsg({ art: 'spur' }), null); // ohne Ort keine Meldung
  const quiet = buildFindMsg({ art: 'spur', pos: { lat: 52.6, lon: 10.07 }, t: T(20, 6) });
  assert.ok(!isUrgent(quiet));
  assert.equal(quiet.dr, undefined);
  // geprüft per Korrektur
  const kor = buildKor({ a: m.a, tm: m.tm, ref: m.id, fs: 'g', t: T(20, 30) });
  const out = applyKor(mergeStatus([m], [kor]));
  assert.equal(out.length, 1); assert.equal(out[0].fs, 'g'); assert.equal(findStatusText(out[0]), '✔ geprüft');
  // UA sieht Fund/Hinweis aller – auch ohne Auftrag
  const ua = normalizeProject(newProject('UA'));
  ua.parentEid = 'E1'; ua.marks = [marks()[1]]; ua.sent = [sent()[1]];
  const other = { id: 'z', a: 'FREMD', tm: 'Team X', t: T(20), s: 'start' };
  const keep = ownTeamMsgs(ua, [m, quiet, other], (x) => forAllUa(x, isUrgent));
  assert.deepEqual(keep.map((x) => x.id), [m.id, quiet.id]);
  // Bericht und GPX
  const wp = msgWaypoints([out[0]]);
  assert.equal(wp.length, 1);
  assert.match(wp[0].name, /^Fund Kleidungsstück FF-Trupp 3 20:05$/);
  assert.match(wp[0].desc, /Kleidungsstück – blaue Jacke – geprüft, Funk \(EL-Handy\)/);
  const rows = msgRows([out[0]], null, () => 'MGRS');
  assert.match(rows[0].art, /Kleidungsstück \[geprüft, Funk \(EL-Handy\)\]/);
  assert.match(rows[0].txt, /blaue Jacke/);
  assert.equal(checkText(m, 'Waldweg').startsWith('Bitte prüfen: Kleidungsstück „blaue Jacke“ bei Waldweg'), true);
});

test('Einsatzzeiten: Start, Pause, Ablösung, Ende, Zurück; Personenstunden', () => {
  const msgs = [
    { id: 1, a: 'AK', s: 'ok', t: T(17, 45) },
    { id: 2, a: 'AK', s: 'start', t: T(18, 0) },
    { id: 3, a: 'AK', s: 'pause', t: T(18, 40) },
    { id: 4, a: 'AK', s: 'start', t: T(18, 55) },
    { id: 5, a: 'AK', s: 'ende', t: T(20, 0) },
    { id: 6, a: 'AK', s: 'zurueck', t: T(20, 20) },
  ];
  const r = timesOf(msgs, NOW);
  assert.equal(r.start, T(18, 0)); assert.equal(r.back, T(20, 20)); assert.equal(r.state, 'zurueck'); assert.equal(r.outside, false);
  assert.deepEqual(r.pauses, [[T(18, 40), T(18, 55)]]);
  assert.equal(r.activeMs, (40 + 65) * 60000);
  const rows = teamTimes(sent(), msgs.map((m) => ({ ...m, tm: 'x' })), marks(), NOW);
  const k = rows.find((x) => x.teamId === 'K');
  assert.equal(k.persons, 6);
  assert.equal(personHours(k.personMs), 10.5);
  const l = timeLine(k, NOW);
  assert.match(l.text, /Start 18:00 · Pause 18:40–18:55 · Ende 20:00 · zurück 20:20 · Einsatzzeit 1 h 45 min · 10,5 Personenstd\. \(6 Pers\.\)/);
  assert.equal(timeRows(rows, NOW).length, 1); // Team 1 hat keine Meldung
  assert.equal(totalPersonHours(rows), 10.5);
});

test('Ablösung beendet die Einsatzzeit; wer noch draußen ist', () => {
  const msgs = [
    { id: 1, a: 'AH', s: 'start', t: T(18, 0) }, { id: 2, a: 'AH', s: 'abloes', t: T(19, 0) },
    { id: 3, a: 'AK', s: 'da', t: T(18, 30) }, { id: 4, a: 'AK', s: 'start', t: T(19, 0) },
  ];
  const rows = teamTimes(sent(), msgs, marks(), T(21, 0));
  const h = rows.find((x) => x.teamId === 'H');
  const k = rows.find((x) => x.teamId === 'K');
  assert.equal(h.state, 'abgeloest'); assert.equal(h.activeMs, 60 * 60000); assert.equal(h.outside, false);
  assert.equal(k.state, 'aktiv'); assert.equal(k.activeMs, 120 * 60000); assert.equal(k.outside, true);
  assert.deepEqual(outsideTeams(rows).map((x) => x.label), ['Kette FF']);
  assert.match(timeLine(k, T(21, 0)).text, /noch draußen/);
  assert.match(timeLine(h, T(21, 0)).text, /Ablösung 19:00/);
  assert.equal(timesOf([], NOW).state, 'none');
});

test('UA-Übersicht: UA -> Teams -> Stand / letzte Meldung / offen, Ampel nach 60 min', () => {
  const p = normalizeProject(newProject('E'));
  p.marks = [{ id: 'A', kind: 'team', label: 'N-Team 1', color: '#1565c0', ua: 'Nord' }, { id: 'B', kind: 'team', label: 'S-Team 1', color: '#2e7d32', ua: 'Süd', ty: 'kette' }, { id: 'C', kind: 'team', label: 'Team 9', color: '#d50000' }];
  p.sent = [
    { id: 'a1', teamId: 'A', at: T(18), acc: T(18, 5) }, { id: 'b1', teamId: 'B', at: T(18), acc: T(18, 5) }, { id: 'c1', teamId: 'C', at: T(17), acc: T(17), done: T(19), pct: 100 },
  ];
  const msgs = [
    { id: 1, a: 'a1', s: 'fertig', pc: 60, t: T(21, 30), tm: 'N-Team 1' },
    { id: 2, a: 'b1', s: 'start', t: T(19, 0), tm: 'S-Team 1' },
  ];
  const rows = uaOverview(p, msgs, NOW);
  assert.deepEqual(rows.map((r) => r.ua), [BASE_UA, 'Nord', 'Süd']);
  const nord = rows.find((r) => r.ua === 'Nord');
  assert.equal(nord.level, 'ok'); assert.equal(nord.pct, 60); assert.equal(nord.open, 1); assert.equal(nord.teams[0].lastText, '📊 60 % abgesucht');
  const sued = rows.find((r) => r.ua === 'Süd');
  assert.equal(sued.level, 'stale'); // seit 3 h keine Meldung
  assert.equal(sued.teams[0].ico, '🚶');
  assert.equal(rows[0].level, 'idle'); assert.equal(rows[0].teams[0].pct, 100);
  assert.equal(levelIcon('stale'), '🔴');
  assert.ok(hasUas(p));
  assert.equal(agoText(T(21, 30), NOW), 'vor 30 min'); assert.equal(agoText(0, NOW), 'noch keine Meldung');
  // UA ohne jede Meldung, aber seit > 60 min übernommen: rot
  const rows2 = uaOverview(p, [], NOW);
  assert.equal(rows2.find((r) => r.ua === 'Nord').level, 'stale');
});

test('Auto-Abschluss: abgeschlossen + 100 % ohne Rückfrage; Rückgängig verhindert erneuten Auto-Abschluss', () => {
  const x = { id: 'A1', teamId: 'T', acc: 1 };
  const zu80 = { id: 'm1', a: 'A1', s: 'zu', pc: 80, t: 10 };
  const zu100 = { id: 'm2', a: 'A1', s: 'zu', pc: 100, t: 20 };
  assert.equal(autoCloseDue(x, [zu80]), null);
  assert.equal(autoCloseDue(x, [{ id: 'm3', a: 'A1', s: 'fertig', pc: 100, t: 5 }]), null); // nur Stand, nicht abgeschlossen
  assert.equal(autoCloseDue(x, [zu80, zu100]).id, 'm2');
  assert.equal(autoCloseDue(x, [{ id: 'm4', a: 'A1', s: 'zu', ar: [['Nord', 100], ['Süd', 100]], t: 30 }]).id, 'm4');
  assert.equal(autoCloseDue(x, [{ id: 'm5', a: 'A1', s: 'zu', ar: [['Nord', 100], ['Süd', 90]], t: 30 }]), null);
  closeSent(x, [zu100], 99);
  assert.equal(x.done, 99); assert.equal(x.pct, 100);
  assert.equal(autoCloseDue(x, [zu100]), null); // schon zu
  reopenSent(x, [zu100]);
  assert.equal(x.done, undefined);
  assert.equal(autoCloseDue(x, [zu100]), null); // Rückgängig: nicht nochmal für diese Meldung
  assert.equal(autoCloseDue(x, [zu100, { id: 'm9', a: 'A1', s: 'zu', pc: 100, t: 40 }]).id, 'm9'); // neue Abschlussmeldung: wieder
  assert.ok(closeMsg([zu100], 'A1'));
});

test('Bericht: Kräfte aus Teams, Einheiten, Einsatzzeiten im Mailtext', () => {
  const p = normalizeProject(newProject('E'));
  p.mission = newMission();
  const t = missionText(p, null, '', null, {
    forcesAuto: ['FF: 1 Einheit, 6 Pers.'], unitRows: [{ team: 'Kette FF', text: 'Kette · FF' }],
    timeRows: [{ team: 'Kette FF', text: 'Start 18:00 · Einsatzzeit 1 h 45 min' }], timeTotal: 'Gesamt: 10,5 Personenstunden',
  });
  assert.match(t, /Kräfte \(aus den Teams\):\nFF: 1 Einheit, 6 Pers\./);
  assert.match(t, /Einheiten:\nKette FF: Kette · FF/);
  assert.match(t, /Einsatzzeiten der Teams:\nKette FF: Start 18:00 · Einsatzzeit 1 h 45 min\nGesamt: 10,5 Personenstunden/);
  // von Hand eingetragene Kräfte gehen vor
  p.mission.forces = [{ org: 'DRK', lead: 1, helpers: 2, dogs: 1, vehicles: 0 }];
  assert.doesNotMatch(missionText(p, null, '', null, { forcesAuto: ['FF: x'] }), /aus den Teams/);
});

import { stripUa, joinUaNames, uaTitle, renameUa, uaName } from '../web/uateam.js';
import { unionSel, emptySel, selSummary, selCount } from '../web/scope.js';

test('UA-Name: kein „UA UA …“, mehrere Gebiete, umbenennen', () => {
  assert.equal(stripUa('UA Nord'), 'Nord');
  assert.equal(stripUa('UA UA Nord'), 'Nord');
  assert.equal(stripUa('Nordwald'), 'Nordwald');
  assert.equal(uaTitle('Suche Wald', 'UA Nord'), 'Suche Wald – UA Nord');
  assert.equal(uaTitle('Suche Wald', joinUaNames(['Nord 1', 'UA Süd', 'Nord 1'])), 'Suche Wald – UA Nord 1 + Süd');
  assert.equal(uaName(uaTitle('Suche Wald', 'Nord')), 'Nord');
  assert.equal(renameUa('Suche Wald – UA Nord', 'Ost'), 'Suche Wald – UA Ost');
  assert.equal(renameUa('Suche Wald – UA Nord', 'UA Ost'), 'Suche Wald – UA Ost');
  assert.equal(renameUa('Ohne Zusatz', 'West'), 'Ohne Zusatz – UA West');
  assert.equal(renameUa('Suche – UA Nord', '  '), 'Suche – UA Nord');
});

test('unionSel: Auswahlen aus mehreren Gebieten vereinen', () => {
  const a = emptySel(); const b = emptySel();
  const i1 = { kind: 'track', id: 'i1' }; const i2 = { kind: 'track', id: 'i2' };
  a.items.add(i1); a.edges.add('G1'); a.cells.set('G1', new Set(['1,1'])); a.meet = true;
  b.items.add(i2); b.edges.add('G2'); b.cells.set('G1', new Set(['2,2'])); b.pois.add({ id: 'p' });
  const u = unionSel([a, b]);
  assert.equal(u.items.size, 2); assert.equal(u.edges.size, 2); assert.equal(u.meet, true);
  assert.deepEqual([...u.cells.get('G1')].sort(), ['1,1', '2,2']);
  assert.equal(selCount(u), 2 + 1 + 1 + 2 + 2);
  assert.equal(unionSel([]).items.size, 0);
  assert.match(selSummary({ meet: null }, u), /2 Rastergebiete/);
});
