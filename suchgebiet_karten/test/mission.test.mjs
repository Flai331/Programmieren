import test from 'node:test';
import assert from 'node:assert/strict';
import { forceTotals, forceLine, totalLine, missionText, lineLegend, normalizeMission, buildForceRequest, normForceItem, buildForceBatch, forceRowFromItem } from '../web/mission.js';
import { newProject, normalizeProject } from '../web/store.js';
import { forcesFromTeams, packReportTeam, teamFromReportItem } from '../web/units.js';

test('Kräfte: Summen und Zeilen (Hiorg/Kat-Schutz-Standard: Führung/Unterführer/Helfer//Gesamt)', () => {
  const f = [
    { org: 'DRK RHS Celle', lead: '1', uf: '1', helpers: '7', dogs: '4', vehicles: '2' },
    { org: 'Feuerwehr', lead: 2, uf: '', helpers: 'x', dogs: '', vehicles: -1 },
  ];
  assert.deepEqual(forceTotals(f), { lead: 3, uf: 1, helpers: 7, dogs: 4, vehicles: 2, people: 11 });
  assert.equal(forceLine(f[0]), 'DRK RHS Celle: 1/1/7//9 + 4 Hunde + 2 Fz.');
  assert.equal(totalLine(f), 'Gesamt: 3/1/7//11 + 4 Hunde + 2 Fz.');
});

test('Alte Suchgebiete bekommen ein leeres Protokoll', () => {
  const p = normalizeProject({ title: 'Alt', items: [] });
  assert.deepEqual(p.mission.forces, []);
  assert.equal(p.mission.summary, '');
  assert.deepEqual(normalizeMission({ forces: 'kaputt', legend: null }).forces, []);
});

test('Mailtext und Kartenlegende', () => {
  const p = newProject('Suche Wald');
  p.leader = 'K. Otte';
  p.items.push({ kind: 'stroke', color: '#d50000', w: 5, pts: [[1, 1], [2, 2]] });
  p.items.push({ kind: 'track', color: '#1565c0', w: 4, pts: [[1, 1], [2, 2]] });
  Object.assign(p.mission, {
    person: 'Herr M., 82 J., blaue Jacke',
    forces: [{ org: 'RHS', lead: 1, helpers: 4, dogs: 3, vehicles: 1 }],
    summary: '14:10 Person in C4 gefunden',
    author: 'Anna',
    legend: { '#d50000': 'Spur Mantrailer', '#1565c0': '  ', '#000000': 'nicht benutzt' },
  });
  assert.deepEqual(lineLegend(p), [{ color: '#d50000', label: 'Spur Mantrailer', line: true }]);
  const t = missionText(p, null);
  for (const part of ['Einsatz: Suche Wald', 'Verfasser: Anna', 'Herr M., 82 J.', 'RHS: 1/0/4//5 + 3 Hunde + 1 Fz.', 'Gesamt: 1/0/4//5', 'Person in C4 gefunden']) {
    assert.ok(t.includes(part), part);
  }
});

test('Empfänger: alte Liste wird zu einer Zeile, Adressen werden getrennt', async () => {
  const { mailAddresses } = await import('../web/mission.js');
  const m = normalizeMission({ recipients: 'a@b.de; c@d.de' });
  assert.equal(m.mailTo.length, 1);
  assert.deepEqual({ ...m.mailTo[0], to: undefined }, { to: undefined, times: true, person: true, forces: true, summary: true, notes: true, msgs: true, pad: true, photos: true, map: false, mapTeams: true, mapStatus: true, juh: true, gpx: false });
  assert.deepEqual(mailAddresses(m.mailTo[0]), ['a@b.de', 'c@d.de']);
  assert.equal(m.recipients, '');
  assert.deepEqual(normalizeMission({}).mailTo, []);
});

test('Empfänger-Zeilen älterer Versionen bekommen die heutigen Häkchen', () => {
  const m = normalizeMission({ mailTo: [{ to: 'a@b.de', report: true, map: true, notes: false, juh: false, gpx: true }, { to: 'c@d.de', juh: false, summary: false }] });
  assert.deepEqual(m.mailTo[0], { to: 'a@b.de', times: true, person: true, forces: true, summary: true, notes: true, msgs: true, pad: false, photos: false, map: false, mapTeams: true, mapStatus: true, juh: false, gpx: true });
  assert.equal(m.mailTo[1].summary, false);
  assert.equal(m.mailTo[1].juh, false);
  assert.equal(m.mailTo[1].person, true);
});

test('Mailtext nur mit angekreuzten Inhalten', () => {
  const p = newProject('X');
  Object.assign(p.mission, { person: 'Herr M.', summary: 'gefunden', forces: [{ org: 'RHS', helpers: 3 }] });
  const t = missionText(p, null, 'Anhang', { person: false, forces: true, summary: false });
  assert.ok(!t.includes('Herr M.') && !t.includes('gefunden') && t.includes('RHS: 0/0/3//3'));
});

test('Zeiten: Zeilen und Dauer über Mitternacht', async () => {
  const { timeLines, missionHours } = await import('../web/mission.js');
  const m = normalizeMission({ times: { alarm: '22:30', alarmDate: '2026-10-28', depart: '22:45', back: '02:00' } });
  assert.deepEqual(timeLines(m), ['Alarmierung: 28.10.2026 22:30 Uhr', 'Abfahrt Wache: 22:45 Uhr', 'Rückkehr Unterkunft: 02:00 Uhr']);
  assert.equal(missionHours(m), 3.5);
  assert.equal(missionHours(normalizeMission({})), 0);
});

test('normTime: Uhrzeit von Hand', async () => {
  const { normTime } = await import('../web/mission.js');
  assert.equal(normTime('1430'), '14:30');
  assert.equal(normTime('930'), '09:30');
  assert.equal(normTime('9:5'), '09:05');
  assert.equal(normTime('14'), '14:00');
  assert.equal(normTime('14.30'), '14:30');
  assert.equal(normTime(''), '');
  assert.equal(normTime('2460'), null);
  assert.equal(normTime('25:00'), null);
  assert.equal(normTime('12345'), null);
});

test('Kräfteübersicht: der Hundeführer zählt als Helfer, nicht als Führung', () => {
  const marks = [
    { id: '1', kind: 'team', label: 'H1', dog: 'Rex', helpers: 2, org: 'DRK' },
    { id: '2', kind: 'team', label: 'K1', ty: 'kette', org: 'DRK', helpers: 3 },
  ];
  const f = forcesFromTeams(marks).find((x) => x.org === 'DRK');
  // Hund-Team (1 Hundeführer + 2 Suchhelfer): alle 3 zählen als Helfer, keine Führung
  // Kette (1 Truppführer + 3 Helfer): der Truppführer zählt weiter als Führung
  assert.deepEqual(f, { org: 'DRK', lead: 1, uf: 0, helpers: 6, dogs: 1, vehicles: 0, teams: 2 });
});

test('Rundgang per QR: Formular anfordern, Stärken+Teams sammeln, als ein Paket bauen', () => {
  const p = normalizeProject({ title: 'Übung Stadtwald' });
  assert.deepEqual(buildForceRequest(p), { k: 'k', v: 1, ti: 'Übung Stadtwald' });
  const item = normForceItem({ org: '  THW OV Celle  ', lead: '1', uf: '1', helpers: '7', dogs: '', vehicles: '-2' });
  assert.deepEqual(item, { t: 'o', org: 'THW OV Celle', lead: '1', uf: '1', helpers: '7', dogs: '0', vehicles: '0' });
  const row = forceRowFromItem(item);
  assert.deepEqual(row, { org: 'THW OV Celle', lead: '1', uf: '1', helpers: '7', dogs: '0', vehicles: '0' });
  // leere Organisation -> Platzhalter statt leerer Zeile
  assert.equal(forceRowFromItem(normForceItem({ org: '' })).org, '(ohne Namen)');
  const batch = buildForceBatch([item], 1700000000000);
  assert.deepEqual(batch, { k: 's', v: 2, at: 1700000000000, items: [item] });
});

test('Rundgang: Team-Eintrag (Hund) im Formular packen und bei der EL wieder auspacken', () => {
  const t1 = packReportTeam({ ty: 'hund', org: 'DRK', dog: 'Rex', helpers: '2' });
  assert.deepEqual(t1, { t: 'u', o: 'DRK', dog: 'Rex', n: 3 }); // ty: 'hund' ist Standard, wird nicht gespeichert
  assert.deepEqual(teamFromReportItem(t1), { org: 'DRK', dog: 'Rex', helpers: 2 });
  const t2 = packReportTeam({ ty: 'kette', org: 'FF', helpers: '4' });
  assert.deepEqual(t2, { t: 'u', ty: 'kette', o: 'FF', n: 5 });
  assert.deepEqual(teamFromReportItem(t2), { ty: 'kette', org: 'FF', helpers: 4 });
});
