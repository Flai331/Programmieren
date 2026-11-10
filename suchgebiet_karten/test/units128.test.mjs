// v128: Einheiten (Typ, Organisation, Funkruf, Personen) – Auftrag, Übergabe, Fortschritt, Kräfte aus Teams
import test from 'node:test';
import assert from 'node:assert/strict';
import { unitType, typeIcon, persons, unitLine, cleanUnit, packUnit, unpackUnit, fillUnit, forcesFromTeams, forcesText, typeCounts, anzeigeText, whoText, nextFunkrufname, UNIT_TYPES } from '../web/units.js';
import { buildAssignment, projectFromAssignment, pack, unpack, ensureLive } from '../web/share.js';
import { newProject, normalizeProject, assignTargets } from '../web/store.js';
import { buildHandover, projectFromHandover } from '../web/handover.js';
import { buildProgress, mergeProgress } from '../web/progress.js';
import { msgLabel, spotLabel, buildMsg, msgIcon } from '../web/status.js';

test('Altes Team ohne Felder ist ein Hund', () => {
  const m = { id: 'a', kind: 'team', label: 'Team 1', dog: 'Rex', helpers: 2 };
  assert.equal(unitType(m), 'hund');
  assert.equal(typeIcon(m), '🐕');
  assert.equal(persons(m), 3);
  assert.equal(unitType({ ty: 'quatsch' }), 'hund');
  assert.equal(UNIT_TYPES.length, 4);
  assert.match(unitLine(m), /^🐕 Hund · Hund Rex · 3 Pers\.$/);
});

test('Typ-Symbole, Texte je Typ', () => {
  assert.equal(typeIcon({ ty: 'kette' }), '🚶');
  assert.equal(typeIcon({ ty: 'kfz' }), '🚙');
  assert.equal(typeIcon({ ty: 'drohne' }), '🚁');
  assert.equal(anzeigeText('kette'), 'Trupp zeigt an');
  assert.equal(anzeigeText(undefined), 'Hund zeigt an');
  assert.equal(whoText('kette'), 'Trupp');
  assert.equal(spotLabel('anzeige'), '🐕 Hund zeigt an');
  assert.equal(spotLabel('anzeige', 'kette'), '🐕 Trupp zeigt an');
  assert.equal(msgLabel({ s: 'ort', cat: 'anzeige', ty: 'kfz' }), '🐕 Fahrzeug zeigt an');
  assert.equal(msgLabel({ s: 'ort', cat: 'fund' }), '🟢 Person gefunden');
  assert.equal(msgIcon({ s: 'abloes' }), '🔄');
  assert.equal(msgLabel({ s: 'abloes' }), '🔄 Ablösung');
});

test('cleanUnit: Standard Hund und leere Felder werden nicht gespeichert', () => {
  const m = cleanUnit({ id: 'x', ty: 'hund', org: ' ', fk: ' Florian 1 ', pers: '0' });
  assert.deepEqual(m, { id: 'x', fk: 'Florian 1' });
  // v130.6: Personenzahl nicht mehr frei eintragbar – immer 1 (Führer) + Suchhelfer, pers fällt immer weg
  assert.equal(cleanUnit({ ty: 'kette', pers: '6.0', org: 'FF' }).pers, undefined);
});

test('persons: immer 1 (Führer der Einheit) + Suchhelfer, unabhängig vom Typ', () => {
  assert.equal(persons({ ty: 'kette', helpers: 3 }), 4);
  assert.equal(persons({ ty: 'kfz' }), 1);
  assert.equal(persons({ ty: 'drohne', helpers: '2' }), 3);
  assert.equal(persons({ helpers: -5 }), 1); // nie unter 1
  assert.equal(persons(undefined), 0);
});

test('nextFunkrufname: Organisation + je Organisation eine laufende Nummer, nie doppelt', () => {
  const marks = [
    { id: 'a', kind: 'team', org: 'DRK', fk: 'DRK 1' },
    { id: 'b', kind: 'team', org: 'DRK', fk: 'DRK 2' },
    { id: 'c', kind: 'team', org: 'JUH', fk: 'JUH 1' },
  ];
  assert.equal(nextFunkrufname('DRK', marks), 'DRK 3');
  assert.equal(nextFunkrufname('JUH', marks), 'JUH 2');
  assert.equal(nextFunkrufname('THW', marks), 'THW 1');
  assert.equal(nextFunkrufname('', marks), ''); // ohne Organisation kein Funkrufname
  // das eigene Team beim Ändern ausnehmen (darf seine bisherige Nummer behalten)
  assert.equal(nextFunkrufname('DRK', marks, 'a'), 'DRK 1');
  // Lücke (gelöschtes/umbenanntes Team) wird nicht automatisch aufgefüllt – nur die nächste freie Nummer
  assert.equal(nextFunkrufname('DRK', [{ id: 'b', kind: 'team', org: 'DRK', fk: 'DRK 2' }]), 'DRK 1');
});

test('packUnit/unpackUnit: kurze Schlüssel, nur gesetzte Felder', () => {
  assert.deepEqual(packUnit({ kind: 'team', label: 'T', dog: 'Rex' }), {});
  assert.deepEqual(packUnit({ ty: 'kette', org: 'FF', fk: 'Florian 1', helpers: 5 }), { ty: 'kette', o: 'FF', fk: 'Florian 1', n: 6 });
  assert.deepEqual(packUnit({ dog: 'Rex', helpers: 2 }), { n: 3 });
  assert.deepEqual(unpackUnit({ ty: 'drohne', o: 'FF', n: 2 }), { ty: 'drohne', org: 'FF', helpers: 1 });
  assert.deepEqual(unpackUnit({ l: 'x' }), {});
  assert.deepEqual(unpackUnit(undefined), {});
});

function el() {
  const p = normalizeProject(newProject('Einsatz'));
  p.marks.push({ id: 'T1', kind: 'team', label: 'Kette Nord', color: '#1565c0', dog: '', ty: 'kette', org: 'FF', fk: 'Florian 1', helpers: 5 });
  p.marks.push({ id: 'T2', kind: 'team', label: 'Team 2', color: '#2e7d32', dog: 'Luna', helpers: 1 });
  p.area = { north: 52.30, south: 52.28, west: 8.00, east: 8.04 };
  p.gridId = 'G1';
  p.fills = { '1,1': 'T1', '2,2': 'T2' };
  return normalizeProject(p);
}

test('Auftrag (QR) trägt Typ, Organisation, Funkruf, Personen; HF-Gerät baut daraus ein Team', async () => {
  const p = el();
  const a = buildAssignment(p, { teamId: 'T1', gridIds: ['G1'], fields: 'team', itemIdx: [] });
  assert.deepEqual(a.tm, { l: 'Kette Nord', c: '#1565c0', d: '', ty: 'kette', o: 'FF', fk: 'Florian 1', n: 6 });
  const a2 = await unpack(await pack(a));
  const hf = projectFromAssignment(a2);
  const t = hf.marks.find((m) => m.id === 'team');
  assert.equal(t.ty, 'kette'); assert.equal(t.org, 'FF'); assert.equal(t.fk, 'Florian 1'); assert.equal(t.helpers, 5); assert.equal(persons(t), 6);
  assert.equal(hf.hf.ty, 'kette');
  // Hund ohne Zusatzfelder: Auftrag wie bisher (kein Mehraufwand)
  const b = buildAssignment(p, { teamId: 'T2', gridIds: ['G1'], fields: 'team', itemIdx: [] });
  assert.deepEqual(b.tm, { l: 'Team 2', c: '#2e7d32', d: 'Luna', n: 2 });
  const hf2 = projectFromAssignment(b);
  assert.equal(hf2.hf.ty, undefined);
  assert.equal(unitType(hf2.marks.find((m) => m.id === 'team')), 'hund');
  // QR-Größe: ohne neue Felder unverändert, mit Feldern nur wenige Zeichen mehr
  const small = (await pack(buildAssignment(p, { teamId: 'T2', gridIds: ['G1'], fields: 'team', itemIdx: [] }))).length;
  const big = (await pack(a)).length;
  assert.ok(big - small < 60, `Typ-Felder machen den Code nur ${big - small} Zeichen größer`);
});

test('Auftrag ohne neue Felder (alter Stand) lässt sich lesen', () => {
  const hf = projectFromAssignment({ v: 1, k: 'a', id: 'X', t: 'Alt', at: 1, g: [], i: [], tm: { l: 'Team 7', c: '#d50000', d: 'Rex' } });
  assert.equal(unitType(hf.marks.find((m) => m.id === 'team')), 'hund');
  assert.equal(hf.hf.ty, undefined);
});

test('Übergabe trägt die Team-Felder mit', () => {
  const p = el();
  const e = buildHandover(p, { liveUrl: '' });
  const q = projectFromHandover(JSON.parse(JSON.stringify(e)));
  const t = q.marks.find((m) => m.id === 'T1');
  assert.deepEqual([t.ty, t.org, t.fk, t.helpers], ['kette', 'FF', 'Florian 1', 5]);
});

test('Fortschritt: neues Team mit Feldern kommt an, vorhandenes wird nur ergänzt; UA merkt sich der Grund-Einsatz', () => {
  const ua = el();
  ua.eid = 'UAX'; ua.parentEid = 'E1'; ua.title = 'Einsatz – UA Nord';
  const base = normalizeProject(newProject('Einsatz'));
  base.eid = 'E1';
  base.marks.push({ id: 'T2', kind: 'team', label: 'Team 2', color: '#2e7d32', dog: '' }); // alt, ohne Felder
  const f = buildProgress(ua, { from: 'UA', fromId: 'u1', since: 0, now: 5000, full: true });
  assert.ok(f);
  const r = mergeProgress(base, JSON.parse(JSON.stringify(f)));
  assert.ok(r.marks >= 1);
  const t1 = base.marks.find((m) => m.id === 'T1');
  assert.deepEqual([t1.ty, t1.org, t1.fk, t1.helpers, t1.ua], ['kette', 'FF', 'Florian 1', 5, 'Nord']);
  const t2 = base.marks.find((m) => m.id === 'T2');
  assert.equal(t2.helpers, 1); // ergänzt (war leer)
  assert.equal(t2.dog, 'Luna');
  // überschreibt nichts
  base.marks.find((m) => m.id === 'T1').fk = 'Eigener Ruf';
  mergeProgress(base, JSON.parse(JSON.stringify(f)));
  assert.equal(base.marks.find((m) => m.id === 'T1').fk, 'Eigener Ruf');
});

test('Kräfteübersicht aus den Teams', () => {
  const marks = [
    { id: '1', kind: 'team', label: 'K1', ty: 'kette', org: 'FF', helpers: 5 },
    { id: '2', kind: 'team', label: 'Q1', ty: 'kfz', org: 'FF', helpers: 1 },
    { id: '3', kind: 'team', label: 'H1', dog: 'Rex', helpers: 1, org: 'DRK' },
    { id: '4', kind: 'team', label: 'D1', ty: 'drohne', helpers: 1 },
    { id: '-', kind: 'team', label: 'ohne Team' },
    { id: 's', kind: 'status', label: 'abgesucht' },
  ];
  const f = forcesFromTeams(marks);
  assert.deepEqual(f.find((x) => x.org === 'FF'), { org: 'FF', lead: 2, helpers: 6, dogs: 0, vehicles: 1, teams: 2 });
  assert.deepEqual(f.find((x) => x.org === 'DRK'), { org: 'DRK', lead: 1, helpers: 1, dogs: 1, vehicles: 0, teams: 1 });
  assert.equal(f.find((x) => x.org === 'ohne Organisation').teams, 1);
  assert.match(forcesText(f)[0], /^FF: 2 Einheiten, 8 Pers\., 1 Fahrz\.$/);
  assert.deepEqual(typeCounts(marks), { hund: 1, kette: 1, kfz: 1, drohne: 1 });
});

test('fillUnit ergänzt nur Fehlendes', () => {
  const o = { id: 'a', kind: 'team', label: 'x', org: 'FF' };
  assert.equal(fillUnit(o, { ty: 'kette', org: 'BW', fk: 'F1' }), true);
  assert.deepEqual([o.ty, o.org, o.fk], ['kette', 'FF', 'F1']);
  assert.equal(fillUnit(o, { ty: 'kfz' }), false);
});

test('Nachrichten tragen den Typ nur, wenn er nicht Hund ist', () => {
  assert.equal(buildMsg({ a: 'x', tm: 't', s: 'ort', cat: 'anzeige', ty: 'hund' }).ty, undefined);
  assert.equal(buildMsg({ a: 'x', tm: 't', s: 'ort', cat: 'anzeige', ty: 'kette' }).ty, 'kette');
});

test('assignTargets: gleiche Reihenfolge wie bisher (Teams, dann Einheiten aus Kräften)', () => {
  const p = el();
  p.mission.forces = [{ org: 'Polizei' }];
  const t = assignTargets(p);
  assert.deepEqual(t.map((x) => x.to), ['T1', 'T2', 'u:Polizei']);
});
