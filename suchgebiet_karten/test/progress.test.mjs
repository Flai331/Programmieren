import test from 'node:test';
import assert from 'node:assert/strict';
import { buildProgress, mergeProgress, progressSummary, snapshotBase, stampChanges, setPeer, peerOf, progressTarget, progressPreview } from '../web/progress.js';
import { emptySel, subsetProject } from '../web/scope.js';
import { newProject, normalizeProject, allGrids } from '../web/store.js';
import { buildHandover, projectFromHandover } from '../web/handover.js';
import { newPoi } from '../web/pois.js';
import { pack, unpack } from '../web/share.js';

const T0 = 1000;
function base() {
  const p = normalizeProject(newProject('Einsatz'));
  p.eid = 'E1';
  p.marks.push({ id: 'T1', kind: 'team', label: 'Team 1', color: '#1565c0', dog: '' });
  p.area = { north: 52.30, south: 52.28, west: 8.00, east: 8.04 };
  p.gridId = 'G1';
  p.fills = { '1,1': 'T1' };
  p.otherGrids = [{ id: 'G2', name: 'Süd', area: { north: 52.27, south: 52.25, west: 8.00, east: 8.04 }, cellM: 100, fills: { '0,0': 'T1' }, status: {} }];
  p.items = [
    { id: 'i-nord', t: T0, by: 'EL', kind: 'track', color: '#000', name: 'Nord', pts: [[52.29, 8.01], [52.295, 8.02], [52.29, 8.03]] },
    { id: 'i-sued', t: T0, by: 'EL', kind: 'track', color: '#000', name: 'Süd', pts: [[52.26, 8.01], [52.265, 8.02], [52.26, 8.03]] },
  ];
  p.pois.push({ ...newPoi({ cat: 'elw', lat: 52.2, lon: 8, by: 'EL' }, T0), id: 'poi1' });
  p.updated = T0;
  return normalizeProject(p);
}
const statusId = (p) => p.marks.find((m) => m.kind === 'status').id;
// UA „Nord“ (Raster G1 + Umriss Nord) aus dem Grund-Einsatz
function makeUA(p) {
  const s = emptySel();
  s.items.add(p.items[0]);
  s.edges.add('G1');
  return subsetProject(p, s, 'UA Nord', { base: true });
}
// Bearbeitung mit Änderungserkennung (wie changed() in der App)
function edit(p, by, now, fn) {
  const b = snapshotBase(p);
  fn(p);
  stampChanges(p, b, by, now);
}
const wire = async (f) => unpack(await pack(f)); // wie QR/Link

test('Änderungen werden erkannt: neue Zeichnung, geänderte, gelöschte, Felder', () => {
  const p = base();
  edit(p, 'EL', 2000, (x) => {
    x.items.push({ kind: 'text', text: 'neu', lat: 1, lon: 1, color: '#000' });
    x.items[0].name = 'Nord 2';
    x.fills['3,3'] = 'T1';
    x.items.splice(1, 1);
  });
  const neu = p.items.find((i) => i.kind === 'text');
  assert.ok(neu.id);
  assert.equal(neu.t, 2000);
  assert.equal(neu.by, 'EL');
  assert.equal(p.items[0].t, 2000);
  assert.equal(p.itemDel['i-sued'], 2000);
  assert.equal(p.cellT['G1|3,3|f'], 2000);
  assert.equal(p.cellT['G1|1,1|f'], undefined);
  // Rückgängig: wieder da -> Löschvermerk weg
  p.items.push({ id: 'i-sued', t: T0, kind: 'track', pts: [[1, 1], [2, 2]] });
  stampChanges(p, snapshotBase(p), 'EL', 3000);
  assert.equal(p.itemDel['i-sued'], undefined);
});

test('Delta: nur Änderungen seit lastSent, leer -> null', () => {
  const p = base();
  assert.equal(buildProgress(p, { since: 1500 }), null);
  edit(p, 'EL', 2000, (x) => { x.fills['3,3'] = 'T1'; x.items[0].name = 'N'; });
  const f = buildProgress(p, { from: 'EL', since: 1500 });
  assert.deepEqual(f.it.map((i) => i.id), ['i-nord']);
  assert.deepEqual(Object.keys(f.g[0].f), ['3,3']);
  assert.equal(f.po, undefined);
  assert.equal(buildProgress(p, { from: 'EL', since: 2000 }), null);
  // since = 0: alles
  const all = buildProgress(p, { from: 'EL', since: 0 });
  assert.equal(all.it.length, 2);
  assert.equal(all.po.length, 1);
  assert.equal(all.g.length, 2);
  assert.match(progressPreview(f), /Feld/);
});

test('Peers: Empfänger mit lastSent', () => {
  const p = base();
  setPeer(p, 'ELW', 5000);
  assert.equal(peerOf(p, 'ELW').lastSent, 5000);
  setPeer(p, 'ELW', 6000);
  assert.equal(p.peers.length, 1);
  assert.equal(peerOf(p, 'X'), null);
  assert.equal(normalizeProject(JSON.parse(JSON.stringify(p))).peers[0].lastSent, 6000);
});

test('UA -> EL: nur UA-Gebiet, Neues und eigene Änderungen; EL ergänzt, löscht nichts', async () => {
  const el = base();
  const ua = makeUA(el);
  const t1 = 5000;
  edit(ua, 'UA1', t1, (u) => {
    u.fills['4,4'] = 'T1'; // im UA-Gebiet (G1)
    u.status['4,4'] = statusId(u);
    u.items[0].name = 'Nord (UA)'; // übergebener Umriss
    u.items.push({ kind: 'track', color: '#d50000', name: 'Neu im UA', pts: [[52.29, 8.0], [52.29, 8.01]] });
  });
  const f = await wire(buildProgress(ua, { from: 'UA1', since: 2000 }));
  assert.equal(f.pe, 'E1');
  assert.equal(f.it.length, 2);
  assert.ok(!f.it.some((i) => i.name === 'Süd'));
  assert.ok(f.it.every((i) => i.lock !== 'base'));
  assert.deepEqual(f.g.map((g) => g.i), ['G1']);
  assert.equal(f.po, undefined); // Lage-Orte des Grund-Einsatzes (gesperrt) gehen nicht zurück
  assert.equal(progressTarget({ a: el }, f), el);
  const n0 = el.items.length;
  const r = mergeProgress(el, f);
  assert.equal(r.fields, 2);
  assert.equal(r.items + r.ways, 2);
  assert.equal(el.items.length, n0 + 1);
  assert.equal(el.items.find((i) => i.id === 'i-nord').name, 'Nord (UA)'); // UA gewinnt im UA-Gebiet
  assert.equal(el.fills['4,4'], 'T1');
  assert.equal(el.items.find((i) => i.name === 'Neu im UA').lock, undefined);
  assert.ok(el.items.some((i) => i.id === 'i-sued'));
  assert.equal(el.pois.length, 1);
  assert.match(progressSummary(r), /2 Felder/);
  // idempotent
  const again = mergeProgress(el, f);
  assert.equal(Object.values(again).reduce((a, b) => a + b, 0), 0);
  assert.equal(progressSummary(again), '');
  assert.equal(el.items.length, n0 + 1);
});

test('UA -> EL: Rückmeldungen seiner Teams (Weg mit resultKey) kommen mit, kein Duplikat', async () => {
  const el = base();
  const ua = makeUA(el);
  edit(ua, 'UA1', 5000, (u) => {
    u.items.push({ kind: 'track', color: '#000', open: true, name: 'Weg Team 1', pts: [[52.29, 8.0], [52.291, 8.001]], resultKey: 'A1|t5' });
    u.imported = { 'A1|t5': 12 };
    u.mission.wind.push({ t: 5000, from: 200, strength: 'light', src: 'gemessen', by: 'Team 1' });
  });
  const f = await wire(buildProgress(ua, { from: 'UA1', since: 2000 }));
  assert.deepEqual(f.im, { 'A1|t5': 12 });
  const r = mergeProgress(el, f);
  assert.equal(r.ways, 1);
  assert.equal(r.wind, 1);
  assert.equal(el.imported['A1|t5'], 12);
  assert.equal(el.items.filter((i) => i.resultKey === 'A1|t5').length, 1);
  // längere Fassung desselben Wegs unter anderer ID ersetzt, kürzere nicht
  const longer = { ...f, it: [{ ...f.it[0], id: 'andere', pe: undefined, pts: [[52.29, 8.0], [52.291, 8.001], [52.292, 8.002]] }] };
  mergeProgress(el, longer);
  assert.equal(el.items.filter((i) => i.resultKey === 'A1|t5').length, 1);
  assert.equal(el.items.find((i) => i.resultKey === 'A1|t5').pts.length, 3);
  mergeProgress(el, f);
  assert.equal(el.items.find((i) => i.resultKey === 'A1|t5').pts.length, 3);
});

test('EL -> UA: kommt als lock base an, UA-eigenes bleibt unangetastet', async () => {
  const el = base();
  const ua = makeUA(el);
  edit(el, 'EL', 6000, (e) => {
    e.items.push({ kind: 'text', text: 'Hinweis', lat: 52.29, lon: 8.0, color: '#000' });
    e.items[0].name = 'Nord (EL)'; // dem UA übergeben: UA entscheidet
    e.items[1].name = 'Süd (EL)'; // Grund-Einsatz: geht durch
    e.fills['2,2'] = 'T1'; // im UA-Gebiet
    e.otherGrids[0].fills['5,5'] = 'T1'; // außerhalb
    e.pois.push(newPoi({ cat: 'park', lat: 52.2, lon: 8.1, by: 'EL' }, 6000));
    e.pois[0].name = 'ELW 2'; e.pois[0].t = 6000;
  });
  edit(ua, 'UA1', 6500, (u) => { u.items[0].name = 'Nord (UA)'; });
  const f = await wire(buildProgress(el, { from: 'EL', to: 'UA1', since: 3000 }));
  assert.equal(f.pe, undefined);
  assert.equal(progressTarget({ x: ua }, f), ua);
  const r = mergeProgress(ua, f);
  assert.equal(ua.items.find((i) => i.text === 'Hinweis').lock, 'base');
  assert.equal(ua.items.find((i) => i.id === 'i-nord').name, 'Nord (UA)'); // UA gewinnt
  assert.equal(ua.items.find((i) => i.id === 'i-nord').lock, 'ua');
  assert.equal(ua.items.find((i) => i.id === 'i-sued').name, 'Süd (EL)');
  assert.equal(ua.items.find((i) => i.id === 'i-sued').lock, 'base');
  assert.equal(ua.fills['2,2'], 'T1');
  assert.equal(ua.otherGrids[0].fills['5,5'], 'T1');
  assert.equal(ua.pois.find((x) => x.cat === 'park').lock, 'base');
  assert.equal(ua.pois.find((x) => x.id === 'poi1').name, 'ELW 2'); // Lage-Ort des Grund-Einsatzes, Änderung des EL kommt an
  assert.ok(r.fields >= 2);
});

test('Feldkonflikt: neuere Änderung gewinnt, im UA-Gebiet der UA', async () => {
  const el = base();
  el.marks.push({ id: 'S1', kind: 'status', label: 'abgesucht', color: '#0f0' }, { id: 'S2', kind: 'status', label: 'teilweise abgesucht', color: '#ff0' });
  const ua = makeUA(el);
  // G1 gehört dem UA: beide färben denselben Status unterschiedlich
  edit(el, 'EL', 6000, (e) => { e.status['1,1'] = 'S1'; e.otherGrids[0].status['0,0'] = 'S1'; });
  edit(ua, 'UA1', 5000, (u) => { u.status['1,1'] = 'S2'; });
  await (async () => {
    mergeProgress(ua, await wire(buildProgress(el, { from: 'EL', since: 0 })));
    assert.equal(ua.status['1,1'], 'S2'); // UA gewinnt in seinem Gebiet, obwohl EL neuer ist
    assert.equal(ua.otherGrids.find((g) => g.id === 'G2').status['0,0'], 'S1'); // Grund-Einsatz-Gebiet kommt an
    mergeProgress(el, await wire(buildProgress(ua, { from: 'UA1', since: 0 })));
    assert.equal(el.status['1,1'], 'S2'); // beim EL entscheidet im UA-Gebiet ebenfalls der UA
  })();
  // zwei gleichberechtigte ELs: die neuere Änderung gewinnt
  const a = base();
  a.marks.push({ id: 'S1', kind: 'status', label: 'abgesucht', color: '#0f0' }, { id: 'S2', kind: 'status', label: 'teilweise abgesucht', color: '#ff0' });
  const b = normalizeProject(JSON.parse(JSON.stringify(a)));
  edit(a, 'A', 7000, (x) => { x.status['2,2'] = 'S1'; });
  edit(b, 'B', 8000, (x) => { x.status['2,2'] = 'S2'; });
  mergeProgress(a, await wire(buildProgress(b, { from: 'B', since: 0 })));
  mergeProgress(b, await wire(buildProgress(a, { from: 'A', since: 0 })));
  assert.equal(a.status['2,2'], 'S2');
  assert.equal(b.status['2,2'], 'S2');
  // ... auch wenn die ältere zuerst ankommt
  const c = normalizeProject(JSON.parse(JSON.stringify(base())));
  c.marks = a.marks;
  mergeProgress(c, await wire(buildProgress(b, { from: 'B', since: 0 })));
  mergeProgress(c, await wire(buildProgress(a, { from: 'A', since: 0 })));
  assert.equal(c.status['2,2'], 'S2');
});

test('Zusammenführen löscht nie: Löschen beim Absender wirkt nicht, Löschvermerke des Empfängers blocken', async () => {
  const a = base();
  const b = normalizeProject(JSON.parse(JSON.stringify(a)));
  // A löscht Nord; B bekommt weiter alles von A (nichts wird gelöscht)
  edit(a, 'A', 3000, (x) => { x.items.splice(0, 1); x.fills['9,9'] = 'T1'; });
  mergeProgress(b, await wire(buildProgress(a, { from: 'A', since: 0 })));
  assert.ok(b.items.some((i) => i.id === 'i-nord'));
  assert.equal(b.fills['9,9'], 'T1');
  // B löscht Sued (Löschvermerk) -> ein späteres Fortschritt von A bringt ihn nicht zurück
  edit(b, 'B', 4000, (x) => { x.items.splice(x.items.findIndex((i) => i.id === 'i-sued'), 1); });
  assert.equal(b.itemDel['i-sued'], 4000);
  edit(a, 'A', 5000, (x) => { x.items.find((i) => i.id === 'i-sued').name = 'Süd neu'; });
  const f = await wire(buildProgress(a, { from: 'A', since: 4500 }));
  mergeProgress(b, f);
  assert.ok(!b.items.some((i) => i.id === 'i-sued'));
  // gelöschter Lage-Ort kommt nicht wieder
  b.poiDel = { poi1: 4000 };
  b.pois = [];
  edit(a, 'A', 6000, (x) => { x.pois[0].name = 'x'; x.pois[0].t = 6000; });
  mergeProgress(b, await wire(buildProgress(a, { from: 'A', since: 0 })));
  assert.equal(b.pois.length, 0);
});

test('Geändertes nur vom Absender (by === from) und nur wenn neuer', async () => {
  const a = base();
  const b = normalizeProject(JSON.parse(JSON.stringify(a)));
  edit(a, 'A', 3000, (x) => { x.items[0].name = 'von A'; });
  // B hat selbst neuer bearbeitet
  edit(b, 'B', 4000, (x) => { x.items[0].name = 'von B'; });
  mergeProgress(b, await wire(buildProgress(a, { from: 'A', since: 0 })));
  assert.equal(b.items[0].name, 'von B');
  // A gibt sich als anderes Gerät aus -> nicht übernommen
  const f = await wire(buildProgress(a, { from: 'A', since: 0 }));
  const c = normalizeProject(JSON.parse(JSON.stringify(base())));
  mergeProgress(c, { ...f, from: 'Fremd' });
  assert.equal(c.items[0].name, 'Nord');
  mergeProgress(c, f);
  assert.equal(c.items[0].name, 'von A');
});

test('Relay und kein Zurückspiegeln: was der Empfänger zuletzt bearbeitet hat, geht nicht zurück', async () => {
  const a = base();
  edit(a, 'A', 3000, (x) => { x.items[0].name = 'von A'; });
  const b = normalizeProject(JSON.parse(JSON.stringify(base())));
  mergeProgress(b, await wire(buildProgress(a, { from: 'A', since: 0 })));
  assert.equal(buildProgress(b, { from: 'B', to: 'A', since: 2000 }), null);
  const toC = buildProgress(b, { from: 'B', to: 'C', since: 2000 });
  assert.deepEqual(toC.it.map((i) => i.id), ['i-nord']);
});

test('Ganzer Einsatz erneut (#e): ergänzend zusammenführen, nichts überschrieben, UA bleibt geschützt', async () => {
  const el = base();
  const dev2 = projectFromHandover(await wire(buildHandover(el)));
  assert.equal(dev2.eid, 'E1');
  // beide arbeiten weiter
  edit(el, 'EL', 7000, (e) => { e.items.push({ kind: 'text', text: 'nur EL', lat: 1, lon: 1, color: '#000' }); e.fills['7,7'] = 'T1'; });
  edit(dev2, 'ELW', 7500, (d) => { d.items.push({ kind: 'text', text: 'nur ELW', lat: 2, lon: 2, color: '#000' }); d.fills['8,8'] = 'T1'; });
  // dev2 bekommt den ganzen Einsatz erneut
  const e2 = await wire(buildHandover(el));
  const inc = projectFromHandover(e2);
  const r = mergeProgress(dev2, buildProgress(inc, { from: 'EL', since: 0 }));
  assert.equal(r.fields, 1);
  assert.ok(dev2.items.some((i) => i.text === 'nur ELW'));
  assert.ok(dev2.items.some((i) => i.text === 'nur EL'));
  assert.equal(dev2.fills['8,8'], 'T1');
  assert.equal(dev2.fills['7,7'], 'T1');
  assert.equal(dev2.items.length, 4);
  // nochmal: nichts Neues
  assert.equal(progressSummary(mergeProgress(dev2, buildProgress(inc, { from: 'EL', since: 0 }))), '');
  assert.equal(dev2.items.length, 4);
  // das UA-Exemplar desselben Einsatzes (gleiche eid) behält seine Sperren
  const ua = makeUA(el);
  const ua2 = projectFromHandover(await wire(buildHandover(ua)));
  assert.equal(ua2.items[1].lock, 'base');
  assert.equal(ua2.glock.G2, 'base');
  edit(ua, 'UA1', 8000, (u) => { u.items.push({ kind: 'text', text: 'frei', lat: 3, lon: 3, color: '#000' }); });
  mergeProgress(ua2, buildProgress(ua, { from: 'UA1', since: 0 }));
  const frei = ua2.items.find((i) => i.text === 'frei');
  assert.ok(frei && !frei.lock);
  assert.equal(ua2.items.find((i) => i.id === 'i-sued').lock, 'base');
});

test('Fremder Einsatz wird nicht vermischt; neues Raster und Teams kommen mit', async () => {
  const el = base();
  const ua = makeUA(el);
  const other = base();
  other.eid = 'ANDERS';
  assert.equal(mergeProgress(other, { k: 'f', eid: 'x', pe: 'y', from: 'a' }), null);
  // im UA neu angelegtes Raster mit neuem Team
  edit(ua, 'UA1', 9000, (u) => {
    u.marks.push({ id: 'T9', kind: 'team', label: 'Team 9', color: '#000', dog: '' });
    u.otherGrids.push({ id: 'G9', name: 'Neu', area: { north: 52.2, south: 52.19, west: 8, east: 8.01 }, cellM: 100, fills: { '0,0': 'T9' }, status: {} });
  });
  const f = await wire(buildProgress(ua, { from: 'UA1', since: 8000 }));
  const r = mergeProgress(el, f);
  assert.equal(r.grids, 1);
  assert.equal(r.marks, 1);
  assert.equal(allGrids(el).find((g) => g.id === 'G9').fills['0,0'], 'T9');
  assert.equal(el.glock.G9, undefined);
  // umgekehrt: neues Raster vom EL ist im UA gesperrt
  edit(el, 'EL', 9500, (e) => { e.otherGrids.push({ id: 'G7', name: 'Ost', area: { north: 52.2, south: 52.19, west: 8.1, east: 8.11 }, cellM: 100, fills: { '0,0': 'T1' }, status: {} }); });
  mergeProgress(ua, await wire(buildProgress(el, { from: 'EL', to: 'UA1', since: 9000 })));
  assert.equal(ua.glock.G7, 'base');
});

test('Status-Meldungen, Aufträge, Eckzeiten werden ergänzt (nie überschrieben)', async () => {
  const a = base();
  a.live = { url: 'https://script.google.com/x', key: 'k'.repeat(22), since: 0, ack: [], msgs: [{ id: 'm1', t: 5000, s: 'start', a: 'A1' }] };
  a.sent = [{ id: 'A1', teamId: 'T1', team: 'Team 1', grids: ['G1'], at: 4000, n: 1, last: 5000, lastSum: '1 km' }];
  a.mission.times = { alarm: '10:00', start: '10:30' };
  a.mission.forces = [{ org: 'DRK', lead: 1, helpers: 4, dogs: 2, vehicles: 1 }];
  a.updated = 5000;
  const b = base();
  b.live = { url: 'https://script.google.com/x', key: 'k'.repeat(22), since: 0, ack: [], msgs: [] };
  b.mission.times = { alarm: '09:55' };
  const r = mergeProgress(b, await wire(buildProgress(a, { from: 'A', since: 0 })));
  assert.equal(b.live.msgs.length, 1);
  assert.equal(r.msgs, 1);
  assert.equal(b.sent.length, 1);
  assert.equal(b.mission.times.alarm, '09:55');
  assert.equal(b.mission.times.start, '10:30');
  assert.equal(b.mission.forces.length, 1);
  assert.match(progressSummary(r), /Protokolleintr/);
});
