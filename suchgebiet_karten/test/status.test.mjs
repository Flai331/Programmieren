import test from 'node:test';
import assert from 'node:assert/strict';
import {
  STATUS_LIST, SPOT_LIST, newLiveKey, roomOf, encryptMsg, decryptMsg, statusLabel, msgLabel, isUrgent, buildMsg, mergeStatus,
  latestFor, flushOutbox, pollMessages, coveragePct, coverageGaps, areaShapes,
} from '../web/status.js';
import { buildAssignment, projectFromAssignment } from '../web/share.js';
import { buildHandover, projectFromHandover } from '../web/handover.js';
import { newProject, normalizeProject } from '../web/store.js';

test('Schlüssel: 16 Byte base64url, jedes Mal anders', () => {
  const k = newLiveKey();
  assert.match(k, /^[A-Za-z0-9_-]{22}$/);
  assert.notEqual(k, newLiveKey());
});

test('Raum-Kennung: stabil, 22 Zeichen, verrät den Schlüssel nicht', async () => {
  const k = newLiveKey();
  const r = await roomOf(k);
  assert.equal(r, await roomOf(k));
  assert.match(r, /^[A-Za-z0-9_-]{22}$/);
  assert.ok(!k.includes(r) && !r.includes(k));
  assert.notEqual(r, await roomOf(newLiveKey()));
});

test('Ver- und Entschlüsseln rund; falscher Schlüssel scheitert', async () => {
  const k = newLiveKey();
  const m = { v: 1, id: 'x1', a: 'A1', tm: 'Team 1', t: 1700000000000, s: 'pause', lat: 52.5, lon: 8.1, txt: 'Grüße ✓' };
  const d = await encryptMsg(k, m);
  assert.match(d, /^[A-Za-z0-9_-]+$/);
  assert.ok(!d.includes('Team'));
  assert.deepEqual(await decryptMsg(k, d), m);
  assert.notEqual(d, await encryptMsg(k, m)); // zufälliger IV
  await assert.rejects(decryptMsg(newLiveKey(), d));
});

test('Status-Tabellen und Beschriftungen', () => {
  assert.equal(STATUS_LIST.length, 6);
  assert.equal(SPOT_LIST.length, 6);
  assert.equal(statusLabel('pause'), '⏸ Pause');
  assert.equal(msgLabel({ s: 'ort', cat: 'gefahr' }), '⚠️ Gefahr');
  assert.ok(isUrgent({ s: 'hilfe' }) && isUrgent({ s: 'fund' }) && isUrgent({ s: 'ort', cat: 'fund' }));
  assert.ok(!isUrgent({ s: 'pause' }) && !isUrgent({ s: 'ort', cat: 'hinweis' }));
});

test('buildMsg: nur vorhandene Felder, Standort gerundet', () => {
  const m = buildMsg({ a: 'A', tm: 'T', s: 'start', pos: { lat: 52.123456789, lon: 8.1, acc: 12.4 }, t: 5 });
  assert.deepEqual(m, { v: 1, id: m.id, a: 'A', tm: 'T', t: 5, s: 'start', lat: 52.123457, lon: 8.1, acc: 12 });
  const n = buildMsg({ a: 'A', tm: 'T', s: 'fertig', pc: 70, pa: 65, txt: 'ok', t: 6 });
  assert.equal(n.lat, undefined);
  assert.equal(n.pc, 70);
  assert.notEqual(m.id, n.id);
});

test('mergeStatus: dedupliziert nach id, sortiert nach Zeit, ignoriert Müll', () => {
  const a = { id: 'a', t: 30, s: 'pause' };
  const b = { id: 'b', t: 10, s: 'start' };
  const out = mergeStatus([a], [b, { ...a, t: 99 }, null, { id: 'c' }, 'x']);
  assert.deepEqual(out.map((m) => m.id), ['b', 'a']);
  assert.equal(out[1].t, 30);
  assert.deepEqual(latestFor(out, 'zz'), { last: null, done: null });
  const x = mergeStatus(out, [{ id: 'd', t: 40, s: 'fertig', a: 'Q' }, { id: 'e', t: 50, s: 'pause', a: 'Q' }]);
  const l = latestFor(x, 'Q');
  assert.equal(l.last.id, 'e');
  assert.equal(l.done.id, 'd');
});

// kleiner In-Memory-Server wie Code.gs
function fakeServer() {
  const rows = [];
  let clock = 1000;
  const f = async (url, opt = {}) => {
    const u = new URL(url);
    if (opt.method === 'POST') {
      const b = JSON.parse(opt.body);
      if (!rows.some((r) => r[1] === b.r && r[2] === b.id)) rows.push([clock++, b.r, b.id, b.d]);
      return { json: async () => ({ ok: true }) };
    }
    const since = Number(u.searchParams.get('since')) || 0;
    return { json: async () => ({ ok: true, now: clock, rows: rows.filter((r) => r[1] === u.searchParams.get('r') && r[0] > since).map((r) => [r[0], r[2], r[3]]) }) };
  };
  return { f, rows };
}

test('Warteschlange senden und abholen (Doppelte fallen weg)', async () => {
  const srv = fakeServer();
  const key = newLiveKey();
  const url = 'https://script.google.com/macros/s/X/exec';
  const out = [buildMsg({ a: 'A', tm: 'T', s: 'start', t: 1 }), buildMsg({ a: 'A', tm: 'T', s: 'pause', t: 2 })];
  const r1 = await flushOutbox([url, key], out, srv.f);
  assert.deepEqual(r1.sent, out.map((m) => m.id));
  assert.equal(r1.left.length, 0);
  await flushOutbox([url, key], out, srv.f); // nochmal: Server hängt nichts doppelt an
  assert.equal(srv.rows.length, 2);
  const live = { url, key, since: 0 };
  const p1 = await pollMessages(live, srv.f);
  assert.deepEqual(p1.msgs.map((m) => m.s), ['start', 'pause']);
  const p2 = await pollMessages({ ...live, since: p1.since }, srv.f);
  assert.ok(p2.msgs.length <= 1); // eine Millisekunde Überlappung ist gewollt
  assert.deepEqual(mergeStatus(p1.msgs, p2.msgs).map((m) => m.s), ['start', 'pause']);
  // anderer Raum: nichts, fremde Zeilen mit falschem Schlüssel werden übergangen
  const other = await pollMessages({ url, key: newLiveKey(), since: 0 }, srv.f);
  assert.equal(other.msgs.length, 0);
});

test('Warteschlange: bei Fehler bleibt der Rest', async () => {
  const key = newLiveKey();
  let n = 0;
  const f = async () => { if (n++ >= 1) throw new Error('offline'); return { json: async () => ({ ok: true }) }; };
  const out = [buildMsg({ a: 'A', tm: 'T', s: 'start', t: 1 }), buildMsg({ a: 'A', tm: 'T', s: 'pause', t: 2 }), buildMsg({ a: 'A', tm: 'T', s: 'fertig', t: 3 })];
  const r = await flushOutbox(['https://x/exec', key], out, f);
  assert.equal(r.sent.length, 1);
  assert.deepEqual(r.left.map((m) => m.s), ['pause', 'fertig']);
  const bad = async () => ({ json: async () => ({ ok: false }) });
  assert.equal((await flushOutbox(['https://x/exec', key], out, bad)).sent.length, 0);
});

// Rechteck ca. 200 m (Ost-West) x 100 m (Nord-Süd) bei 52° N
const LAT = 52;
const dLat = (m) => m / 111320;
const dLon = (m) => m / (111320 * Math.cos((LAT * Math.PI) / 180));
const rect = { north: LAT + dLat(50), south: LAT - dLat(50), west: 8, east: 8 + dLon(200) };

test('Abdeckung: gerader Weg durch die Mitte, leer, voll', () => {
  const mid = [[LAT, 8 - dLon(50)], [LAT, 8 + dLon(250)]];
  assert.equal(coveragePct([mid], [rect], 30), 60); // Streifen 60 m von 100 m
  assert.equal(coveragePct([mid], [rect], 50), 100);
  assert.equal(coveragePct([mid], [rect], 20), 40);
  assert.equal(coveragePct([], [rect], 30), 0);
  assert.equal(coveragePct([[]], [rect], 30), 0);
  assert.equal(coveragePct([mid], [], 30), null);
  // Weg als einzelne Linie statt Liste von Wegen
  assert.equal(coveragePct(mid, [rect], 30), 60);
  // zwei Wege zusammen decken mehr ab
  const n = [[LAT + dLat(30), 8], [LAT + dLat(30), 8 + dLon(200)]];
  const s = [[LAT - dLat(30), 8], [LAT - dLat(30), 8 + dLon(200)]];
  assert.equal(coveragePct([n, s], [rect], 30), 100);
});

test('Abdeckung: Umriss (Dreieck) und Lücken', () => {
  const tri = { pts: [[LAT - dLat(50), 8], [LAT + dLat(50), 8], [LAT - dLat(50), 8 + dLon(100)]] };
  assert.equal(coveragePct([[[LAT, 8 - dLon(20)], [LAT, 8 + dLon(120)]]], [tri], 1000), 100);
  const mid = [[LAT, 8 - dLon(50)], [LAT, 8 + dLon(250)]];
  const g = coverageGaps([mid], [rect], 30);
  assert.equal(g.step, 5);
  assert.equal(g.pts.length, 40 * 8); // 8 Reihen à 40 Stellen bleiben frei (100 m - 60 m = 40 m)
  for (const [la] of g.pts) assert.ok(Math.abs(la - LAT) > dLat(29));
});

test('Abdeckung: Rechenaufwand begrenzt (großes Gebiet)', () => {
  const big = { north: 53, south: 52, west: 8, east: 9 }; // ~ 70 x 111 km
  const t0 = Date.now();
  const g = coverageGaps([[[52.5, 8.4], [52.5, 8.6]]], [big], 30);
  assert.ok(g.pts.length <= 200000 + 10);
  assert.ok(g.step > 5);
  assert.ok(Date.now() - t0 < 20000);
});

function elProject() {
  const p = normalizeProject(newProject('Vermisst Musterwald'));
  p.area = { north: 52.30, south: 52.28, west: 8.00, east: 8.04 };
  p.cellM = 100;
  p.marks.push({ id: 'T2', kind: 'team', label: 'Team 2', color: '#1565c0', dog: 'Kira' });
  p.fills = { '1,1': 'T2', '2,1': 'T2', '5,5': 'X' };
  return p;
}

test('Auftrag ohne Status-Server: kein ls, keine live', () => {
  const p = elProject();
  const a = buildAssignment(p, { teamId: 'T2', gridIds: [p.gridId], fields: 'team' });
  assert.equal(a.ls, undefined);
  assert.equal(p.live, undefined);
  const h = projectFromAssignment(a);
  assert.equal(h.hf.ls, undefined);
  assert.deepEqual(h.hf.outbox, []);
});

test('Auftrag mit Status-Server: ls = [Adresse, Schlüssel], Schlüssel bleibt pro Einsatz gleich', () => {
  const p = elProject();
  const url = 'https://script.google.com/macros/s/X/exec';
  const a = buildAssignment(p, { teamId: 'T2', gridIds: [p.gridId], fields: 'team', liveUrl: url });
  assert.equal(a.ls[0], url);
  assert.match(a.ls[1], /^[A-Za-z0-9_-]{22}$/);
  assert.equal(p.live.key, a.ls[1]);
  const b = buildAssignment(p, { teamId: 'T2', gridIds: [p.gridId], fields: 'team', liveUrl: url });
  assert.equal(b.ls[1], a.ls[1]);
  const h = projectFromAssignment(JSON.parse(JSON.stringify(a)));
  assert.deepEqual(h.hf.ls, a.ls);
  // Schlüssel überlebt Normalisierung
  assert.deepEqual(normalizeProject(JSON.parse(JSON.stringify(h))).hf.ls, a.ls);
});

test('Übergabe an weiteres EL-Gerät nimmt live (Schlüssel, Meldungen) mit', () => {
  const p = elProject();
  buildAssignment(p, { teamId: 'T2', gridIds: [], fields: 'team', liveUrl: 'https://script.google.com/macros/s/X/exec' });
  p.live.msgs = [{ id: 'm1', t: 1, s: 'start', a: 'A' }];
  p.live.ack = ['m1'];
  const q = projectFromHandover(JSON.parse(JSON.stringify(buildHandover(p))));
  assert.deepEqual(q.live, p.live);
});

test('normalizeProject: kaputte live/hf-Angaben werden geradegezogen', () => {
  const p = normalizeProject({ ...newProject('x'), live: { url: 'u' }, hf: { id: 'a', track: [], ls: ['nur eins'], outbox: 5 } });
  assert.equal(p.live, undefined);
  assert.equal(p.hf.ls, undefined);
  assert.deepEqual(p.hf.outbox, []);
  assert.deepEqual(p.hf.log, []);
  const q = normalizeProject({ ...newProject('x'), live: { url: 'https://script.google.com/macros/s/X/exec', key: 'k', msgs: 'x', ack: null } });
  assert.deepEqual(q.live, { url: 'https://script.google.com/macros/s/X/exec', key: 'k', since: 0, ack: [], msgs: [] });
});

test('areaShapes: Felder des Teams, sonst ganzes Raster, sonst Umrisse', () => {
  const p = elProject();
  const h = projectFromAssignment(buildAssignment(p, { teamId: 'T2', gridIds: [p.gridId], fields: 'team' }));
  const s = areaShapes(h);
  assert.equal(s.length, 2); // zwei Felder des Teams
  assert.ok(s.every((r) => r.north > r.south));
  const all = areaShapes(p, { gridIds: [p.gridId], teamId: '' });
  assert.equal(all.length, 1);
  assert.equal(all[0].north, 52.30);
  const q = normalizeProject(newProject('x'));
  q.items = [{ kind: 'track', pts: [[1, 1], [1, 2], [2, 2]] }, { kind: 'track', open: true, pts: [[1, 1], [1, 2], [2, 2]] }];
  q.hf = { grids: [], track: [] };
  assert.equal(areaShapes(q).length, 1);
});

test('Stand-Meldung: unter 100 % nicht „Gebiet fertig“', async () => {
  const { msgLabel, msgIcon } = await import('../web/status.js');
  assert.equal(msgLabel({ s: 'fertig', pc: 40 }), '📊 40 % abgesucht');
  assert.equal(msgIcon({ s: 'fertig', pc: 40 }), '📊');
  assert.equal(msgLabel({ s: 'fertig', pc: 100 }), '✅ Gebiet fertig');
  assert.equal(msgLabel({ s: 'fertig' }), '✅ Gebiet fertig');
});

test('Stand je Gebiet: mehrere Gebiete einzeln', async () => {
  const { msgLabel, buildMsg } = await import('../web/status.js');
  const m = buildMsg({ a: 'A', tm: 'T', s: 'fertig', pc: 40, ar: [['Nord', 40], ['Süd', 100]], t: 1 });
  assert.equal(msgLabel(m), '📊 Nord 40 % · Süd ✅');
  assert.equal(msgLabel({ ...m, ar: [['Nord', 100], ['Süd', 100]] }), '✅ Alle Gebiete fertig');
});

test('Status-Tasten: „Parkplatz Auto“ statt „Anfahrt“, alte Meldungen lesbar', async () => {
  const { STATUS_LIST, statusLabel } = await import('../web/status.js');
  assert.ok(!STATUS_LIST.some((s) => s.code === 'anfahrt'));
  assert.equal(statusLabel('da'), '🅿️ Parkplatz Auto');
  assert.equal(statusLabel('anfahrt'), '🚗 Anfahrt');
});

test('Suche begonnen/beendet für ausgewählte Gebiete', async () => {
  const { msgLabel, buildMsg } = await import('../web/status.js');
  assert.equal(msgLabel(buildMsg({ a: 'A', tm: 'T', s: 'start', gb: ['Umriss 1', 'Umriss 2'], t: 1 })), '▶️ Suche begonnen: Umriss 1, Umriss 2');
  assert.equal(msgLabel(buildMsg({ a: 'A', tm: 'T', s: 'ende', gb: ['Umriss 2'], t: 1 })), '⏹ Suche beendet: Umriss 2');
  assert.equal(msgLabel({ s: 'start' }), '▶️ Suche begonnen');
});

test('Suchstand ohne Standort, Markierungen mit', async () => {
  const { NO_POS } = await import('../web/status.js');
  for (const c of ['start', 'ende', 'pause', 'fertig', 'zurueck']) assert.ok(NO_POS.includes(c), c);
  assert.ok(!NO_POS.includes('ort'));
  assert.ok(!NO_POS.includes('da')); // Parkplatz geht mit Standort
  const { STATUS_LIST, SPOT_LIST, isUrgent } = await import('../web/status.js');
  assert.deepEqual(STATUS_LIST.map((s) => s.code), ['da', 'start', 'ende', 'pause', 'fertig', 'zurueck']);
  assert.deepEqual(SPOT_LIST.slice(0, 3).map((s) => s.code), ['anzeige', 'fund', 'hilfe']);
  assert.ok(isUrgent({ s: 'ort', cat: 'hilfe' }) && isUrgent({ s: 'ort', cat: 'fund' }) && !isUrgent({ s: 'ort', cat: 'anzeige' }));
});

// ---------- v103: Korrekturen ----------
import { buildKor, applyKor, qrMsgs } from '../web/status.js';
const M = (id, t, o = {}) => buildMsg({ a: 'A1', tm: 'Team', s: 'ort', cat: 'anzeige', pos: { lat: 50, lon: 8 }, t, id, ...o });

test('buildKor: eigene ID, Zeit, ref; del/nopos/Ort/Notiz', () => {
  const k = buildKor({ a: 'A1', tm: 'Team', ref: 'x1', del: true, t: 5 });
  assert.equal(k.s, 'kor'); assert.equal(k.ref, 'x1'); assert.equal(k.del, 1); assert.equal(k.t, 5); assert.ok(k.id);
  assert.equal(buildKor({ a: 'A1', ref: 'x', nopos: true }).nopos, 1);
  const v = buildKor({ a: 'A1', ref: 'x', pos: { lat: 1.1234567, lon: 2 } });
  assert.equal(v.lat, 1.123457); assert.equal(v.lon, 2);
  assert.equal(buildKor({ a: 'A1', ref: 'x', txt: '' }).txt, '');
  assert.ok(!('txt' in buildKor({ a: 'A1', ref: 'x', pos: { lat: 1, lon: 2 } })));
  assert.ok(!('txt' in buildMsg({ a: 'A1', tm: 'T', s: 'pause', txt: '' })));
});
test('applyKor: Notiz, Verlegen, Ort entfernen, Notiz entfernen; kor erscheint nie selbst', () => {
  const m = M('m1', 10, { txt: 'alt' });
  const l = applyKor([m, buildKor({ a: 'A1', ref: 'm1', txt: 'neu', t: 20, id: 'k1' }), buildKor({ a: 'A1', ref: 'm1', pos: { lat: 51, lon: 9 }, t: 30, id: 'k2' })]);
  assert.equal(l.length, 1);
  assert.equal(l[0].txt, 'neu'); assert.equal(l[0].lat, 51); assert.equal(l[0].lon, 9); assert.equal(l[0].ed, 30);
  assert.equal(l[0].t, 10);
  const n = applyKor([m, buildKor({ a: 'A1', ref: 'm1', nopos: true, txt: '', t: 20, id: 'k3' })]);
  assert.ok(n[0].lat === undefined && n[0].lon === undefined && n[0].txt === undefined);
  assert.equal(m.lat, 50); // Original unverändert
});
test('applyKor: mehrere kor in Zeitfolge (spätere gewinnt, auch bei umgekehrter Listenfolge)', () => {
  const k1 = buildKor({ a: 'A1', ref: 'm1', txt: 'eins', t: 20, id: 'k1' });
  const k2 = buildKor({ a: 'A1', ref: 'm1', txt: 'zwei', t: 30, id: 'k2' });
  assert.equal(applyKor([k2, M('m1', 10), k1])[0].txt, 'zwei');
});
test('applyKor: Löschen – normale Meldung fällt weg, Fund/Hilfe bleiben mit gone', () => {
  const k = (ref) => buildKor({ a: 'A1', ref, del: true, t: 40, id: `k${ref}` });
  assert.deepEqual(applyKor([M('m1', 10), k('m1')]), []);
  const f = applyKor([M('m2', 10, { cat: 'fund' }), M('m3', 11, { cat: 'hilfe' }), k('m2')]);
  assert.equal(f.length, 2);
  assert.equal(f[0].gone, 40); assert.ok(isUrgent(f[0])); assert.equal(f[1].gone, undefined);
  assert.equal(applyKor([buildMsg({ a: 'A1', tm: 'T', s: 'fund', id: 'f1', t: 1 }), k('f1')])[0].gone, 40);
});
test('applyKor: kor ohne Ziel oder fremdes Team wird ignoriert, ohne kor bleibt die Liste', () => {
  const m = M('m1', 10);
  assert.deepEqual(applyKor([m, buildKor({ a: 'A1', ref: 'nix', del: true, t: 5, id: 'k' })]), [m]);
  assert.deepEqual(applyKor([m, buildKor({ a: 'B2', ref: 'm1', del: true, t: 5, id: 'k' })]), [m]);
  assert.deepEqual(applyKor([m]), [m]);
  assert.deepEqual(applyKor(null), []);
});
test('QR-Auswahl: letzte n ohne kor samt ihrer Korrekturen', () => {
  const log = [];
  for (let i = 0; i < 25; i++) log.push(M(`m${i}`, i + 1));
  log.push(buildKor({ a: 'A1', ref: 'm24', txt: 'x', t: 100, id: 'k1' }), buildKor({ a: 'A1', ref: 'm0', del: true, t: 101, id: 'k2' }));
  const q = qrMsgs(log, 20);
  assert.equal(q.filter((m) => m.s !== 'kor').length, 20);
  assert.ok(q.some((m) => m.id === 'k1') && !q.some((m) => m.id === 'k2'));
  assert.ok(!q.some((m) => m.id === 'm0'));
  assert.equal(applyKor(q).find((m) => m.id === 'm24').txt, 'x');
});
