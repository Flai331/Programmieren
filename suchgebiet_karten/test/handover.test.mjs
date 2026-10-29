import test from 'node:test';
import assert from 'node:assert/strict';
import { pack, unpack, parseShared, shareLink, buildAssignment, buildResult, applyResult, projectFromAssignment } from '../web/share.js';
import { buildHandover, projectFromHandover, replaceWithHandover, splitParts, addPart } from '../web/handover.js';
import { newProject, normalizeProject } from '../web/store.js';

function elProject() {
  const p = normalizeProject(newProject('Vermisst Musterwald'));
  p.area = { north: 52.30, south: 52.28, west: 8.00, east: 8.04 };
  p.marks.push({ id: 'T2', kind: 'team', label: 'Team 2', color: '#1565c0', dog: 'Kira' });
  p.fills = { '1,1': 'T2', '2,1': 'T2' };
  p.items = [
    { kind: 'track', color: '#000', name: 'Waldstück', pts: [[52.29, 8.01], [52.295, 8.02], [52.29, 8.03]] },
    { kind: 'text', color: '#000', text: 'ELW', lat: 52.281, lon: 8.002 },
  ];
  p.lead = { name: 'Klaas', phone: '0170 1', call: 'RH 1', elw: '11-1' };
  p.radio = [{ call: 'RH 2', who: 'Zugführer' }];
  p.mission.person = 'Herr M.';
  p.mission.photos = [{ t: 1, src: 'data:image/jpeg;base64,AAAA' }];
  p.mission.pages = [{ t: 1, strokes: [{ color: '#000', w: 2, pts: [[0.123456, 0.654321]] }] }];
  return p;
}

test('Übergabe: alles außer Fotos kommt an, Einsatz-ID bleibt', async () => {
  const p = elProject();
  const link = shareLink('e', await pack(buildHandover(p)));
  const sh = parseShared(link);
  assert.equal(sh.kind, 'e');
  const e = await unpack(sh.data);
  assert.equal(e.np, 1);
  const q = projectFromHandover(e);
  assert.notEqual(q.id, p.id);
  assert.equal(q.eid, p.eid);
  assert.deepEqual(q.fills, p.fills);
  assert.deepEqual(q.lead, p.lead);
  assert.deepEqual(q.radio, p.radio);
  assert.equal(q.items[0].pts.length, 3);
  assert.equal(q.items[1].text, 'ELW');
  assert.equal(q.mission.photos.length, 0);
  assert.deepEqual(q.mission.pages[0].strokes[0].pts, [[0.123, 0.654]]);
  assert.equal(p.mission.photos.length, 1, 'Original unverändert');
  assert.equal(p.items[0].pts.length, 3);
});

test('Übergabe: Rückmeldung zu einem Auftrag des Handys passt auf dem Tablet, nichts doppelt', async () => {
  const p = elProject();
  const a = buildAssignment(p, { teamId: 'T2', gridIds: [p.gridId], fields: 'team' });
  p.sent = [{ id: a.id, teamId: 'T2', team: 'Team 2', grids: a.g.map((g) => g.i) }];
  const hf = projectFromAssignment(await unpack(await pack(a)));
  hf.hf.track.push({ t0: 5, pts: [[52.29, 8.01], [52.291, 8.012]] });
  const r = buildResult(hf);
  applyResult(p, r);
  const q = projectFromHandover(await unpack(await pack(buildHandover(p))));
  const res = applyResult(q, r);
  assert.equal(res.known, true);
  assert.equal(res.ways, 0);
  assert.equal(res.who, 'Team 2');
});

test('Ersetzen behält Fotos und (falls nicht mitgekommen) den Notizblock', () => {
  const old = elProject();
  const e = buildHandover(old, { pages: false });
  assert.equal(e.nn, 1);
  const inc = projectFromHandover(e);
  const r = replaceWithHandover(old, inc, e);
  assert.equal(r.id, old.id);
  assert.equal(r.mission.photos.length, 1);
  assert.equal(r.mission.pages.length, 1);
});

test('Mehrteiliger QR-Code: Teile in beliebiger Reihenfolge, doppelt gelesen', () => {
  const data = 'abc-_'.repeat(700);
  const parts = splitParts(data, 1000);
  assert.equal(parts.length, 4);
  const links = parts.map((x) => shareLink('m', x));
  assert.equal(parseShared(links[0]).kind, 'm');
  const store = {};
  let r;
  for (const i of [2, 0, 2, 3]) r = addPart(store, parseShared(links[i]).data);
  assert.equal(r.done, null);
  assert.equal(r.have, 3);
  r = addPart(store, parts[1]);
  assert.equal(r.done, data);
  // neuer Code (andere Kennung) beginnt von vorn
  const other = splitParts('xyz', 1000);
  assert.equal(addPart(store, other[0]).done, 'xyz');
});
