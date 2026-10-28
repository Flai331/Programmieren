import test from 'node:test';
import assert from 'node:assert/strict';
import { forceTotals, forceLine, totalLine, missionText, lineLegend, normalizeMission } from '../web/mission.js';
import { newProject, normalizeProject } from '../web/store.js';

test('Kräfte: Summen und Zeilen', () => {
  const f = [
    { org: 'DRK RHS Celle', lead: '1', helpers: '6', dogs: '4', vehicles: '2' },
    { org: 'Feuerwehr', lead: 2, helpers: 'x', dogs: '', vehicles: -1 },
  ];
  assert.deepEqual(forceTotals(f), { lead: 3, helpers: 6, dogs: 4, vehicles: 2, people: 9 });
  assert.equal(forceLine(f[0]), 'DRK RHS Celle: 1 Führung, 6 Helfer, 4 Hunde, 2 Fahrz.');
  assert.equal(totalLine(f), 'Gesamt: 9 Einsatzkräfte (3 Führung, 6 Helfer), 4 Hunde, 2 Fahrzeuge');
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
  for (const part of ['Einsatz: Suche Wald', 'Verfasser: Anna', 'Herr M., 82 J.', 'RHS: 1 Führung', 'Gesamt: 5 Einsatzkräfte', 'Person in C4 gefunden', 'Spur Mantrailer (rot)']) {
    assert.ok(t.includes(part), part);
  }
});
