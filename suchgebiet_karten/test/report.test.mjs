import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildReport, scrub, fingerprint, createLog, throttle, clip, describeTarget, MAX_FIELD, LOG_SIZE,
} from '../web/report.js';

test('Fehlerbericht: keine Einsatzdaten', () => {
  const s = scrub('Fehler bei 52.12345, 9.87654 Tel. 0171 2345678 max@example.de 32U NC 12345 67890 #a=eJzLSM3JyVcozy');
  assert.ok(!s.includes('52.12345'));
  assert.ok(!s.includes('2345678'));
  assert.ok(!s.includes('max@example.de'));
  assert.ok(!s.includes('12345 67890'));
  assert.ok(!s.includes('eJzLSM3'));
  assert.ok(s.includes('Fehler bei'));
  // kurze Zahlen (Zeilennummern, Versionen) bleiben
  assert.equal(scrub('app.js:1234:5 v76'), 'app.js:1234:5 v76');
  const big = 'A'.repeat(200);
  assert.ok(!scrub(`foto ${big}`).includes(big));
});

test('Fehlerbericht: Felder, Kürzung, Rolle', () => {
  const r = buildReport({
    kind: 'auto', message: 'x is undefined', stack: 'at f (app.js:1:2)\n'.repeat(500),
    log: ['a', 'b'], page: 'panel-teams', role: 'hf', version: 'v76',
  });
  assert.equal(r.kind, 'Auto-Fehler');
  assert.equal(r.role, 'HF');
  assert.ok(r.title.startsWith('Auto-Fehler: x is undefined'));
  assert.equal(r.error.length, MAX_FIELD);
  assert.equal(r.log, 'a\nb');
  assert.equal(r.version, 'v76');
  const m = buildReport({ kind: 'manual', description: 'Knopf geht nicht\nmehr Text', role: 'el' });
  assert.equal(m.kind, 'Manuelle Meldung');
  assert.equal(m.role, 'EL');
  assert.equal(m.title, 'Meldung: Knopf geht nicht');
  assert.equal(clip('abc', 2), 'a…');
});

test('Fehlerbericht: Fingerprint und Wiederholung', () => {
  const a = fingerprint('auto', 'Fehler in Zeile 12', 'at f (https://x.de/app.js?v=1:12:3)');
  const b = fingerprint('auto', 'Fehler in Zeile 99', 'at f (https://y.de/app.js?v=2:12:3)');
  assert.equal(a, b); // Zahlen in der Meldung und Host/Query zählen nicht
  assert.notEqual(a, fingerprint('auto', 'Anderer Fehler', ''));
  const m1 = buildReport({ kind: 'manual', description: 'x', now: new Date(1) });
  const m2 = buildReport({ kind: 'manual', description: 'x', now: new Date(2) });
  assert.notEqual(m1.fingerprint, m2.fingerprint);
  const seen = new Map();
  assert.equal(throttle(seen, a, 1000), true);
  assert.equal(throttle(seen, a, 20000), false);
  assert.equal(throttle(seen, a, 31001), true);
});

test('Fehlerbericht: Bedienschritte als Ringpuffer ohne Texte', () => {
  const log = createLog(LOG_SIZE, () => new Date(2026, 0, 1, 8, 5, 9).getTime());
  for (let i = 0; i < 60; i++) log.add(`Schritt ${i}`);
  const l = log.list();
  assert.equal(l.length, LOG_SIZE);
  assert.equal(l[0], '08:05:09 Schritt 10');
  const btn = { tagName: 'BUTTON', id: '', className: 'mini', dataset: {}, parentElement: { tagName: 'DIV', id: 'team-list', dataset: {} } };
  assert.equal(describeTarget(btn), 'div#team-list');
  assert.equal(describeTarget({ tagName: 'BUTTON', id: 'btn-more', dataset: {} }), 'button#btn-more');
  assert.equal(describeTarget({ tagName: 'SPAN', className: 'x y', dataset: {} }), 'span.x');
});
