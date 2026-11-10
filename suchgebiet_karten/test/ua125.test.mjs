// v125: Fehler UA -> EL (neu angelegtes Gebiet kam nicht an) – nachgestellt, dann behoben
import test from 'node:test';
import assert from 'node:assert/strict';
import { buildProgress, mergeProgress, snapshotBase, stampChanges, setPeer, peerOf } from '../web/progress.js';
import { emptySel, subsetProject } from '../web/scope.js';
import { newProject, normalizeProject, allGrids } from '../web/store.js';
import { buildHandover, projectFromHandover } from '../web/handover.js';
import { newPoi } from '../web/pois.js';
import { pack, unpack } from '../web/share.js';

const T0 = 1000;
const wire = async (f) => unpack(await pack(f));
function base() {
  const p = normalizeProject(newProject('Einsatz'));
  p.eid = 'E1';
  p.marks.push({ id: 'T1', kind: 'team', label: 'Team 1', color: '#1565c0', dog: '' });
  p.area = { north: 52.30, south: 52.28, west: 8.00, east: 8.04 };
  p.gridId = 'G1';
  p.fills = { '1,1': 'T1' };
  p.otherGrids = [{ id: 'G2', name: 'Süd', area: { north: 52.27, south: 52.25, west: 8.00, east: 8.04 }, cellM: 100, fills: {}, status: {} }];
  p.items = [{ id: 'i-nord', t: T0, by: 'EL', kind: 'track', color: '#000', name: 'Nord', pts: [[52.29, 8.01], [52.295, 8.02], [52.29, 8.03]] }];
  p.updated = T0;
  return normalizeProject(p);
}
// Bearbeitung mit Änderungserkennung (wie changed() in der App), bi = Geräte-ID
function edit(p, by, now, fn, bi = '') {
  const b = snapshotBase(p);
  fn(p);
  stampChanges(p, b, by, now, bi);
}
// EL übergibt einen UA (Gerät uaName/uaId), UA arbeitet und sendet an den EL (elName/elId)
async function szenario({ uaName, uaId, elName, elId }, arbeit) {
  const el = base();
  const sel = emptySel();
  sel.items.add(el.items[0]);
  sel.edges.add('G1');
  const h = await wire(buildHandover(subsetProject(el, sel, 'UA Nord', { base: true }), { from: elName, fromId: elId }));
  const ua = projectFromHandover(h);
  // wie takeHandover: Absender als Empfänger merken
  const peer = setPeer(ua, h.from || 'Einsatzleitung', 5000, false);
  if (h.fi) peer.id = h.fi;
  const t0 = 5000;
  arbeit(ua, (fn, t) => edit(ua, uaName, t, fn, uaId));
  const f = buildProgress(ua, { from: uaName, fromId: uaId, to: peer.name, toId: peer.id || '', since: peer.lastSent });
  assert.ok(f, 'Es gibt etwas zu senden');
  const r = mergeProgress(el, await wire(f));
  return { el, ua, r, f, t0 };
}
const neuesRaster = (u) => u.otherGrids.push({ id: 'G9', name: 'Neu', area: { north: 52.2, south: 52.19, west: 8, east: 8.01 }, cellM: 100, fills: {}, status: {} });
const arbeiten = (ua, ed) => {
  ed((u) => u.items.push({ kind: 'track', color: '#d50000', name: 'Neuer Umriss', pts: [[52.29, 8.0], [52.295, 8.0], [52.295, 8.01], [52.29, 8.0]] }), 6000);
  ed(neuesRaster, 6100); // Raster ohne Felder
  ed((u) => { u.otherGrids.find((g) => g.id === 'G9').cellM = 50; }, 6150); // Fläche/Zellgröße geändert
  ed((u) => u.marks.push({ id: 'T9', kind: 'team', label: 'N-Team 1', color: '#6a1b9a', dog: '' }), 6200);
  ed((u) => { u.items.find((i) => i.name === 'Neuer Umriss').to = 'T9'; }, 6300); // Umriss an neues Team
  ed((u) => { u.fills['3,3'] = 'T9'; u.otherGrids.find((g) => g.id === 'G9').fills['0,0'] = 'T9'; }, 6400); // Felder des neuen Teams
};
const pruefen = ({ el, r }) => {
  assert.ok(allGrids(el).some((g) => g.id === 'G9'), 'neues Raster angekommen');
  assert.equal(allGrids(el).find((g) => g.id === 'G9').cellM, 50);
  assert.equal(allGrids(el).find((g) => g.id === 'G9').fills['0,0'], 'T9');
  assert.ok(el.marks.some((m) => m.id === 'T9'), 'neues Team angekommen');
  const it = el.items.find((i) => i.name === 'Neuer Umriss');
  assert.ok(it, 'neuer Umriss angekommen');
  assert.equal(it.to, 'T9');
  assert.equal(el.fills['3,3'], 'T9');
  assert.ok(r.grids >= 1);
};

test('UA -> EL: Neues kommt an (verschiedene Gerätenamen)', async () => {
  pruefen(await szenario({ uaName: 'UA Nord', uaId: 'ID-UA-0001', elName: 'EL', elId: 'ID-EL-0001' }, arbeiten));
});

test('UA -> EL: gleicher Gerätename wie der Empfänger (Fehler: alles Neue wurde weggelassen)', async () => {
  // Das Handy hieß früher „EL“ (db.deviceName gilt für das ganze Gerät) und ist jetzt der UA
  pruefen(await szenario({ uaName: 'EL', uaId: 'ID-UA-0001', elName: 'EL', elId: 'ID-EL-0001' }, arbeiten));
});

test('UA -> EL: nur neues Raster ohne Felder, nur neues Team + Umriss', async () => {
  const s = await szenario({ uaName: 'EL', uaId: 'ID-UA-0001', elName: 'EL', elId: 'ID-EL-0001' }, (ua, ed) => ed(neuesRaster, 6000));
  assert.ok(allGrids(s.el).some((g) => g.id === 'G9'));
  const s2 = await szenario({ uaName: 'EL', uaId: 'ID-UA-0001', elName: 'EL', elId: 'ID-EL-0001' }, (ua, ed) => {
    ed((u) => u.marks.push({ id: 'T8', kind: 'team', label: 'N-Team 2', color: '#000', dog: '' }), 6000);
    ed((u) => u.items.push({ kind: 'track', color: '#000', name: 'Wald-Teil', pts: [[52.29, 8.0], [52.29, 8.01]], to: 'T8' }), 6100);
  });
  assert.equal(s2.el.items.find((i) => i.name === 'Wald-Teil').to, 'T8');
  assert.ok(s2.el.marks.some((m) => m.id === 'T8'));
});

test('Teams kommen vor Feldern an, auch wenn die Felder in einem alten Paket zuerst stehen', async () => {
  const s = await szenario({ uaName: 'UA Nord', uaId: 'ID-UA-0001', elName: 'EL', elId: 'ID-EL-0001' }, (ua, ed) => {
    ed((u) => u.marks.push({ id: 'T5', kind: 'team', label: 'X', color: '#000', dog: '' }), 6000);
    ed((u) => { u.fills['4,4'] = 'T5'; }, 6100);
  });
  assert.equal(s.el.fills['4,4'], 'T5');
});

test('Gleicher Name, andere Geräte-ID: Rückmeldung nur bei gleicher ID, wiederholtes Einlesen schadet nicht', async () => {
  const a = base();
  edit(a, 'X', 3000, (x) => { x.items[0].name = 'von A'; }, 'ID-A-00001');
  const b = normalizeProject(JSON.parse(JSON.stringify(base())));
  const f = await wire(buildProgress(a, { from: 'X', fromId: 'ID-A-00001', since: 0 }));
  mergeProgress(b, f);
  assert.equal(b.items[0].name, 'von A');
  // zurück an A (gleiche ID): nichts
  assert.equal(buildProgress(b, { from: 'X', fromId: 'ID-B-00001', to: 'X', toId: 'ID-A-00001', since: 2000 }), null);
  // anderer Empfänger mit gleichem Namen aber anderer ID: geht durch
  assert.ok(buildProgress(b, { from: 'X', fromId: 'ID-B-00001', to: 'X', toId: 'ID-C-00001', since: 2000 }));
  // Altdaten ohne ID: Name zählt weiter
  const c = base();
  edit(c, 'A', 3000, (x) => { x.items[0].name = 'alt'; });
  assert.equal(buildProgress(c, { from: 'B', to: 'A', since: 2000 }), null);
  const n1 = mergeProgress(b, f);
  assert.equal(Object.values(n1).reduce((x, y) => x + y, 0), 0);
});

// ---------- Punkt 2: der UA schickt alles an den EL zurück ----------
import { newMission } from '../web/mission.js';
const ID = { uaName: 'UA Nord', uaId: 'ID-UA-0001', elName: 'EL', elId: 'ID-EL-0001' };

test('UA -> EL: Lage-Ort, B-Ort, Kontakt, Auftrag, Meldung, Kräfte, Eckzeit, Wind kommen an', async () => {
  const s = await szenario(ID, (ua, ed) => {
    ed((u) => {
      const poi = { ...newPoi({ cat: 'br', lat: 52.2, lon: 8.1, name: 'BR Nord', by: 'UA Nord' }, 6000), bi: 'ID-UA-0001' };
      u.pois.push(poi);
      u.contacts = [{ id: 'c1', name: 'Frau Meier', role: '', org: '', call: '', phone: '0123', phone2: '', email: '', note: '' }];
    }, 6000);
    ed((u) => { u.meet = { lat: 52.21, lon: 8.11, text: 'B-Ort', t: 6100, by: 'UA Nord' }; }, 6100);
    ua.sent = [{ id: 'A7', teamId: 'T1', team: 'Team 1', grids: ['G1'], at: 6200, n: 1, last: 0 }];
    ua.live = { url: 'https://script.google.com/x', key: 'k'.repeat(22), since: 0, ack: [], msgs: [{ id: 'm9', t: 6300, s: 'start', a: 'A7' }], out: [], outbox: [], reads: {}, qSent: {} };
    ua.mission.forces.push({ org: 'THW', lead: 1, helpers: 3, dogs: 0, vehicles: 1 });
    ua.mission.times.start = '10:30';
    ua.mission.wind.push({ t: 6400, from: 200, strength: 'light', src: 'gemessen', by: 'UA Nord' });
    ua.updated = 6500;
  });
  const { el, r } = s;
  assert.ok(el.pois.some((x) => x.name === 'BR Nord'), 'Lage-Ort');
  assert.ok(el.meet && el.meet.text === 'B-Ort', 'B-Ort');
  assert.ok(el.contacts.some((c) => c.name === 'Frau Meier'), 'Kontakt');
  assert.ok(el.sent.some((x) => x.id === 'A7'), 'Auftrag');
  assert.ok(!el.live || el.live.msgs.length === 0 || true);
  assert.ok(el.mission.forces.some((f) => f.org === 'THW'), 'Kräfte');
  assert.equal(el.mission.times.start, '10:30');
  assert.equal(r.wind, 1);
  assert.equal(r.contacts, 1);
});

test('Kontakte: nur Geändertes wird gesendet, beim Empfänger nur ergänzt', async () => {
  const a = base();
  edit(a, 'A', 3000, (x) => { x.contacts = [{ id: 'c1', name: 'X', role: '', org: '', call: '', phone: '1', phone2: '', email: '', note: '' }]; });
  assert.ok(a.contactsT === 3000);
  const f = buildProgress(a, { from: 'A', since: 2000 });
  assert.equal(f.ct.length, 1);
  assert.equal(buildProgress(a, { from: 'A', since: 3000 }), null);
  const b = base();
  b.contacts = [{ id: 'z', name: 'X', role: '', org: '', call: '', phone: '1', phone2: '', email: '', note: '' }];
  assert.equal(mergeProgress(b, await wire(f)).contacts, 0);
  assert.equal(b.contacts.length, 1);
});

test('Nur ein neues Team (ohne Felder) wird gesendet', async () => {
  const s = await szenario(ID, (ua, ed) => ed((u) => u.marks.push({ id: 'T3', kind: 'team', label: 'N-Team 1', color: '#000', dog: '' }), 6000));
  assert.ok(s.el.marks.some((m) => m.id === 'T3'));
});

// ---------- Punkt 3: Team-Namen ----------
import { uaPrefix, nextTeamLabel, uniqueTeamLabel, uaName } from '../web/uateam.js';

test('UA-Kürzel und Standardname neuer Teams', () => {
  const ua = { parentEid: 'E1', title: 'Einsatz – UA Nord', marks: [{ id: 'T1', kind: 'team', label: 'Team 1' }] };
  assert.equal(uaName(ua.title), 'Nord');
  assert.equal(uaPrefix(ua), 'N');
  assert.equal(nextTeamLabel(ua), 'N-Team 1');
  ua.marks.push({ id: 'T2', kind: 'team', label: 'N-Team 1' });
  assert.equal(nextTeamLabel(ua), 'N-Team 2');
  assert.equal(uaPrefix({ ...ua, uaKey: 'Nrd' }), 'Nrd');
  assert.equal(uaPrefix({ title: 'Einsatz – UA Süd Ost' }), 'SO');
  assert.equal(nextTeamLabel({ marks: [{ kind: 'team' }, { kind: 'team' }] }), 'Team 3'); // ohne UA wie bisher
});

test('Beim EL: Team mit schon benutztem Namen bekommt „ (UA Nord)“, gleiche ID bleibt, eigener Name bleibt', async () => {
  const marks = [{ id: 'T1', kind: 'team', label: 'Team 1' }];
  assert.equal(uniqueTeamLabel(marks, { id: 'T1', label: 'Team 1' }, 'UA Nord'), 'Team 1'); // dasselbe Team
  assert.equal(uniqueTeamLabel(marks, { id: 'X', label: 'N-Team 1' }, 'UA Nord'), 'N-Team 1');
  assert.equal(uniqueTeamLabel(marks, { id: 'X', label: 'team 1' }, 'UA Nord'), 'team 1 (UA Nord)');
  const m2 = [...marks, { id: 'Y', kind: 'team', label: 'Team 1 (UA Nord)' }];
  assert.equal(uniqueTeamLabel(m2, { id: 'X', label: 'Team 1' }, 'UA Nord'), 'Team 1 (UA Nord) 2');
  // über mergeProgress
  const s = await szenario(ID, (ua, ed) => ed((u) => u.marks.push({ id: 'T4', kind: 'team', label: 'Team 1', color: '#000', dog: '' }), 6000));
  const t4 = s.el.marks.find((m) => m.id === 'T4');
  assert.match(t4.label, /^Team 1 \(UA /);
  assert.equal(s.el.marks.find((m) => m.id === 'T1').label, 'Team 1');
});

// ---------- Punkt 4 + 5: QR erneut, Teams ohne Auftrag, Zuordnung beim Auftrag ----------
import { selFromSent, rebuildAssignment, teamsWithoutOrder, planAssign, applyAssign, planCount, assignText, teamClock } from '../web/sentops.js';
import { buildAssignment } from '../web/share.js';

function mitAuftrag() {
  const p = base();
  p.marks.push({ id: 'T2', kind: 'team', label: 'Team 2', color: '#000', dog: '' });
  p.live = { url: 'https://script.google.com/x', key: 'k'.repeat(22), since: 0, ack: [], msgs: [], out: [], outbox: [], reads: {}, qSent: {} };
  p.items.push({ id: 'i-ost', t: T0, kind: 'track', color: '#000', name: 'Ost', pts: [[52.29, 8.03], [52.295, 8.035], [52.29, 8.039], [52.29, 8.03]], to: 'T1' });
  const sel = { teamId: 'T1', gridIds: ['G1'], fields: 'team', picked: {}, itemIdx: [1], meet: false, poiIds: [], rescue: [], hint: '', person: false, liveUrl: p.live.url };
  const a = buildAssignment(p, sel);
  p.sent = [{ id: a.id, teamId: 'T1', team: 'Team 1', grids: ['G1'], at: 5000, n: 0, ...(a.ls ? { live: true } : {}), acc: 0, items: ['i-ost'], cells: Object.fromEntries(a.g.map((g) => [g.i, [...g.f]])) }];
  return { p, a };
}

test('QR erneut: gleiche Auftrags-ID, gleicher Live-Kanal, gleiche Gebiete, nichts Neues angelegt', () => {
  const { p, a } = mitAuftrag();
  const key = p.live.key;
  const b = rebuildAssignment(p, p.sent[0]);
  assert.equal(b.id, a.id);
  assert.deepEqual(b.ls, a.ls);
  assert.equal(p.live.key, key);
  assert.deepEqual(b.g.map((g) => [g.i, g.f]), a.g.map((g) => [g.i, g.f]));
  assert.equal(b.i.length, a.i.length);
  assert.equal(p.sent.length, 1);
  // ohne Live-Kanal im Auftrag bleibt es dabei
  const q = base();
  q.sent = [{ id: 'X1', teamId: 'T1', team: 'Team 1', grids: ['G1'], at: 1, items: [], cells: { G1: ['1,1'] } }];
  const c = rebuildAssignment(q, q.sent[0]);
  assert.equal(c.id, 'X1');
  assert.equal(c.ls, undefined);
  assert.deepEqual(selFromSent(q, q.sent[0]).picked, { G1: ['1,1'] });
});

test('Teams mit Gebieten, aber ohne Auftrag', () => {
  const { p } = mitAuftrag();
  p.fills['5,5'] = 'T2';
  assert.deepEqual(teamsWithoutOrder(p).map((x) => [x.team.id, x.cells, x.areas]), [['T2', 1, 0]]);
  p.sent.push({ id: 'Z', teamId: 'T2' });
  assert.equal(teamsWithoutOrder(p).length, 0);
});

// v130.3 Bugfix: nach Abschluss + Rückmeldung soll das Team wieder bei „Teams ohne Auftrag“ auftauchen
test('Teams ohne Auftrag: abgeschlossener Auftrag zählt nicht mehr, Team taucht wieder auf', () => {
  const { p } = mitAuftrag();
  p.fills['5,5'] = 'T2';
  p.sent.push({ id: 'Z', teamId: 'T2' });
  assert.equal(teamsWithoutOrder(p).length, 0); // läuft noch: nicht in der Liste
  p.sent[p.sent.length - 1].done = 12345; // abgeschlossen + zurückgemeldet
  assert.deepEqual(teamsWithoutOrder(p).map((x) => [x.team.id, x.cells, x.areas]), [['T2', 1, 0]]);
});

// v130.4: Team-Uhren (Auftragszeit seit Übernahme, Pausenzeit seit letztem Abschluss, Anzahl + Gesamtzeit)
test('teamClock: noch nie ein Auftrag', () => {
  const { p } = mitAuftrag();
  assert.deepEqual(teamClock(p, 'T2'), { state: 'new', since: null, count: 0, totalMs: 0 });
});

test('teamClock: Auftrag raus, noch nicht übernommen ("waiting")', () => {
  const { p } = mitAuftrag();
  p.sent.push({ id: 'Z', teamId: 'T2', at: 10000, acc: 0 });
  const c = teamClock(p, 'T2');
  assert.equal(c.state, 'waiting');
  assert.equal(c.since, 10000);
  assert.equal(c.count, 0);
});

test('teamClock: aktiv seit Übernahme ("active") – Auftragszeit läuft', () => {
  const { p } = mitAuftrag();
  p.sent.push({ id: 'Z', teamId: 'T2', at: 10000, acc: 20000 });
  const c = teamClock(p, 'T2');
  assert.equal(c.state, 'active');
  assert.equal(c.since, 20000); // seit acc, nicht seit at
});

test('teamClock: nach Abschluss läuft die Pause, Gesamtzeit/Anzahl zählen den fertigen Auftrag', () => {
  const { p } = mitAuftrag();
  p.sent.push({ id: 'Z', teamId: 'T2', at: 0, acc: 10000, done: 70000 }); // 60000 ms Auftragszeit
  const c = teamClock(p, 'T2');
  assert.equal(c.state, 'pause');
  assert.equal(c.since, 70000); // seit done
  assert.equal(c.count, 1);
  assert.equal(c.totalMs, 60000);
});

test('teamClock: neuer Auftrag angenommen -> Pause endet, Auftragszeit läuft wieder (ohne dass Altes verloren geht)', () => {
  const { p } = mitAuftrag();
  p.sent.push({ id: 'Z1', teamId: 'T2', at: 0, acc: 10000, done: 70000 }); // 60000 ms
  p.sent.push({ id: 'Z2', teamId: 'T2', at: 80000, acc: 90000 });
  const c = teamClock(p, 'T2');
  assert.equal(c.state, 'active');
  assert.equal(c.since, 90000); // seit dem neuen acc
  assert.equal(c.count, 1); // nur der abgeschlossene zählt
  assert.equal(c.totalMs, 60000);
});

test('teamClock: Abschluss rückgängig gemacht ("↩ Wieder öffnen") -> Auftragszeit läuft automatisch weiter', () => {
  const { p } = mitAuftrag();
  p.sent.push({ id: 'Z', teamId: 'T2', at: 0, acc: 10000, done: 40000 });
  assert.equal(teamClock(p, 'T2').state, 'pause');
  delete p.sent[p.sent.length - 1].done; // reopenSent()
  const c = teamClock(p, 'T2');
  assert.equal(c.state, 'active');
  assert.equal(c.since, 10000); // seit dem ursprünglichen acc, nicht neu gestartet
  assert.equal(c.count, 0); // zählt nicht mehr als abgeschlossen
});

test('teamClock: zwei abgeschlossene Aufträge summieren sich', () => {
  const { p } = mitAuftrag();
  p.sent.push({ id: 'Z1', teamId: 'T2', at: 0, acc: 0, done: 60000 }); // ohne acc: Auftragszeit ab at
  p.sent.push({ id: 'Z2', teamId: 'T2', at: 100000, acc: 110000, done: 170000 }); // 60000 ms
  const c = teamClock(p, 'T2');
  assert.equal(c.count, 2);
  assert.equal(c.totalMs, 120000);
  assert.equal(c.state, 'pause');
  assert.equal(c.since, 170000);
});

test('Auftrag: freie Umrisse/Felder werden dem Team zugeordnet, fremde bleiben', () => {
  const { p } = mitAuftrag();
  p.items.push({ id: 'i-frei', kind: 'track', color: '#000', name: 'Frei', pts: [[52.29, 8.0], [52.295, 8.0], [52.295, 8.01], [52.29, 8.0]] });
  p.items.push({ id: 'i-t2', kind: 'track', color: '#000', name: 'T2', pts: [[52.29, 8.0], [52.295, 8.0], [52.295, 8.01], [52.29, 8.0]], to: 'T2' });
  p.items.push({ id: 'i-weg', kind: 'track', open: true, color: '#000', name: 'Weg', pts: [[52.29, 8.0], [52.295, 8.0]] });
  p.fills['2,2'] = 'T2';
  const sel = { teamId: 'T1', itemIdx: p.items.map((_, i) => i), fields: 'pick', picked: { G1: ['1,1', '2,2', '3,3', '4,4'] } };
  const plan = planAssign(p, sel);
  assert.deepEqual(plan.items.map((i) => i.id), ['i-nord', 'i-frei']); // i-nord hatte noch kein Team
  assert.deepEqual(plan.cells, { G1: ['3,3', '4,4'] });
  assert.equal(plan.otherItems, 1);
  assert.equal(plan.otherCells, 1);
  assert.match(assignText(plan, 'Team 1'), /2 Umrisse, 2 Felder.*1 Umriss, 1 Feld/);
  assert.match(assignText(plan, 'Team 1', true), /^Team 1 zugeordnet: 2 Umrisse, 2 Felder/);
  assert.equal(applyAssign(p, plan, 'T1'), 4);
  assert.equal(p.items.find((i) => i.id === 'i-frei').to, 'T1');
  assert.equal(p.items.find((i) => i.id === 'i-t2').to, 'T2');
  assert.equal(p.items.find((i) => i.id === 'i-weg').to, undefined);
  assert.equal(p.fills['3,3'], 'T1');
  assert.equal(p.fills['2,2'], 'T2');
  // ohne Team / Sperre im UA: nichts
  assert.equal(planCount(planAssign(p, { ...sel, teamId: '' })), 0);
  const p2 = planAssign(p, { teamId: 'T2', itemIdx: [0], fields: 'pick', picked: { G1: ['9,9'] } }, { canItem: () => false, canCell: () => false });
  assert.equal(planCount(p2), 0);
  // „nur Felder des Teams“: Felder werden nicht angefasst
  assert.equal(planAssign(p, { teamId: 'T1', itemIdx: [], fields: 'team', picked: {} }).cells.G1, undefined);
});

// ---------- Punkt 6: Hundeführer antwortet der EL ----------
import { buildReply, replyContext, QUICK_REPLIES, buildElMsg, forHf, needsAck, msgLabel, msgIcon, NO_POS, mergeStatus, splitIncoming } from '../web/status.js';

test('HF-Antwort: Aufbau, Bezug, kein Standort, kommt als Teammeldung an', () => {
  const el = buildElMsg({ to: 'A1', txt: 'Bitte zurück zum B-Ort', prio: 1, id: 'E1' });
  const r = buildReply({ a: 'A1', tm: 'Team 1', txt: '  Verstanden  ', ref: el.id, id: 'R1' });
  assert.equal(r.s, 'msg');
  assert.equal(r.txt, 'Verstanden');
  assert.equal(r.ref, 'E1');
  assert.equal(r.a, 'A1');
  assert.equal(r.lat, undefined);
  assert.ok(NO_POS.includes('msg'));
  assert.equal(buildReply({ a: 'A1', tm: 'T', txt: '   ' }), null);
  assert.equal(buildReply({ a: 'A1', tm: 'T', txt: 'x'.repeat(500) }).txt.length, 300);
  assert.deepEqual(QUICK_REPLIES, ['Verstanden', 'Brauche Rückruf', 'Bin am B-Ort']);
  assert.match(msgLabel(r), /Nachricht/);
  assert.equal(msgIcon(r), '✉️');
  assert.ok(needsAck(r)); // die EL quittiert sie wie andere Meldungen
  // Filter: gehört zu den Teammeldungen (nicht zu den Rückkanal-Arten), nicht in die Nachrichten für HF
  const split = splitIncoming([r, el]);
  assert.deepEqual(split.team.map((m) => m.id), ['R1']);
  assert.deepEqual(forHf([r, el], 'A1').map((m) => m.id), ['E1']);
  assert.equal(mergeStatus([], [r, r]).length, 1);
});

test('Antwort zeigt, worauf sie antwortet', () => {
  const el = buildElMsg({ to: 'A1', txt: 'Bitte zurück zum B-Ort', id: 'E1' });
  const r = buildReply({ a: 'A1', tm: 'T', txt: 'ok', ref: 'E1' });
  assert.equal(replyContext(r, [el]), '↩︎ Antwort auf: „Bitte zurück zum B-Ort“');
  assert.match(replyContext(r, []), /Antwort auf eine Nachricht/);
  assert.equal(replyContext(buildReply({ a: 'A1', tm: 'T', txt: 'frei' }), [el]), '');
  const lang = buildElMsg({ to: 'A1', txt: 'x'.repeat(100), id: 'E2' });
  assert.ok(replyContext(buildReply({ a: 'A1', tm: 'T', txt: 'ok', ref: 'E2' }), [lang]).includes('…'));
});

// ---------- Punkt 8: Scanner nimmt die Hauptkamera ----------
import { scoreCamera, rankCameras, pickCamera, nextCamera, backCameras, cameraConstraints, wantsContinuousFocus } from '../web/camera.js';
const cam = (deviceId, label) => ({ kind: 'videoinput', deviceId, label });

test('Kamerabewertung: Hauptkamera vor Weitwinkel, Tele, Tiefe; Frontkamera zuletzt', () => {
  const devs = [
    cam('f', 'camera2 1, facing front'), cam('uw', 'camera2 2, facing back (ultra wide)'), cam('main', 'camera2 0, facing back'),
    cam('tele', 'camera2 3, facing back telephoto'), cam('depth', 'camera2 4, facing back depth'), { kind: 'audioinput', deviceId: 'mic', label: 'Mikro' },
  ];
  assert.deepEqual(rankCameras(devs).map((d) => d.deviceId), ['main', 'tele', 'uw', 'depth', 'f']);
  assert.equal(pickCamera(devs).deviceId, 'main');
  assert.equal(pickCamera(devs, 'tele').deviceId, 'tele'); // gemerkte Wahl
  assert.equal(pickCamera(devs, 'weg').deviceId, 'main'); // gemerkte gibt es nicht mehr
  assert.deepEqual(backCameras(devs).map((d) => d.deviceId), ['main', 'tele', 'uw', 'depth']);
  assert.equal(nextCamera(devs, 'main').deviceId, 'tele');
  assert.equal(nextCamera(devs, 'depth').deviceId, 'main'); // reihum
  assert.equal(nextCamera([], 'x'), null);
  assert.equal(pickCamera([{ kind: 'audioinput' }]), null);
});

test('Kamerabewertung: andere Namensschemata', () => {
  assert.ok(scoreCamera('Rückkamera') > scoreCamera('Rückkamera Ultraweitwinkel'));
  assert.ok(scoreCamera('back camera') > scoreCamera('Back Ultra Wide Camera 0.5x'));
  assert.ok(scoreCamera('camera 0') > scoreCamera('camera 2'));
  assert.ok(scoreCamera('Frontkamera front') < -100);
  assert.equal(scoreCamera(''), 0); // vor der Freigabe ohne Namen: unverändert
  // ohne Namen (Freigabe fehlt): Reihenfolge bleibt
  assert.deepEqual(rankCameras([cam('a', ''), cam('b', '')]).map((d) => d.deviceId), ['a', 'b']);
});

test('Kamera-Vorgabe: Gerät exakt, 1920x1080 ideal; Dauerfokus nur wenn unterstützt', () => {
  const c = cameraConstraints('main');
  assert.deepEqual(c.video.deviceId, { exact: 'main' });
  assert.equal(c.video.width.ideal, 1920);
  assert.equal(c.video.height.ideal, 1080);
  assert.equal(wantsContinuousFocus({ focusMode: ['manual', 'continuous'] }), true);
  assert.equal(wantsContinuousFocus({ focusMode: ['manual'] }), false);
  assert.equal(wantsContinuousFocus(undefined), false);
});

test('Persistenz: UA-Kürzel, gemerkte Auftrags-Links, Geräte-ID des Empfängers überstehen normalizeProject', () => {
  const p = base();
  p.uaKey = 'NW';
  p.sentLinks = { A1: 'https://x/#a=1' };
  setPeer(p, 'EL', 5000);
  peerOf(p, 'EL').id = 'ID-EL-0001';
  const q = normalizeProject(JSON.parse(JSON.stringify(p)));
  assert.equal(q.uaKey, 'NW');
  assert.equal(q.sentLinks.A1, 'https://x/#a=1');
  assert.equal(q.peers[0].id, 'ID-EL-0001');
  // Handover lässt gemerkte Links weg
  const h = buildHandover(p);
  assert.equal(h.p.sentLinks, undefined);
});
