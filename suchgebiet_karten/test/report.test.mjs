import test from 'node:test';
import assert from 'node:assert/strict';
import { buildReport, describeTarget, fingerprint, makeDedup, makeLog, validReportUrl, reportPayload } from '../web/report.js';

test('makeLog: hält nur die letzten Einträge', () => {
  const log = makeLog(3);
  for (const x of ['a', 'b', 'c', 'd']) log.add(x);
  assert.equal(log.size, 3);
  assert.ok(!log.text().includes('] a'));
  assert.ok(log.text().endsWith('] d'));
});

test('fingerprint: gleiche Stelle gleich, andere Stelle anders', () => {
  const a = fingerprint('x is undefined', 'at f (https://h/app.js:120:5)');
  assert.equal(a, fingerprint('x is undefined', 'at f (https://h/app.js:120:9)'));
  assert.notEqual(a, fingerprint('x is undefined', 'at f (https://h/app.js:300:5)'));
  assert.notEqual(a, fingerprint('y is undefined', 'at f (https://h/app.js:120:5)'));
  assert.match(a, /^js-[0-9a-f]{8}$/);
});

test('buildReport: kürzt, keine Einsatzdaten außer der eigenen Beschreibung', () => {
  const r = buildReport({ kind: 'Auto-Fehler', error: 'E'.repeat(900), stack: 'S'.repeat(3000), version: 'v76', mode: 'hf', page: 'Karte', log: 'L'.repeat(5000) });
  assert.equal(r.kind, 'Auto-Fehler');
  assert.equal(r.role, 'Hundeführer');
  assert.ok(r.error.length <= 500 && r.stack.length <= 1400 && r.log.length <= 2000);
  assert.ok(r.title.startsWith('Fehler: '));
  assert.ok(r.fingerprint);
  assert.deepEqual(Object.keys(r).sort(), ['desc', 'error', 'fingerprint', 'kind', 'log', 'page', 'role', 'stack', 'time', 'title', 'url', 'version']);
  const m = buildReport({ kind: 'Manuelle Meldung', desc: 'PDF geht nicht\nmehr Text', version: 'v76', mode: 'el' });
  assert.equal(m.title, 'Meldung: PDF geht nicht');
  assert.equal(m.role, 'Einsatzleitung');
  assert.equal(m.fingerprint, '');
});

test('makeDedup: gleicher Fehler höchstens alle 30 s', () => {
  let t = 0;
  const ok = makeDedup(30000, () => t);
  assert.equal(ok('a'), true);
  assert.equal(ok('a'), false);
  assert.equal(ok('b'), true);
  t = 30001;
  assert.equal(ok('a'), true);
});

test('describeTarget: nur Kennungen, kein Inhalt', () => {
  const el = (attrs, parent = null) => ({ getAttribute: (k) => attrs[k] ?? null, parentElement: parent });
  assert.equal(describeTarget(el({ id: 'pdf-save' })), '#pdf-save');
  assert.equal(describeTarget(el({}, el({ 'data-tool': 'track' }))), 'Werkzeug track');
  assert.equal(describeTarget(el({ 'data-tab': 'ende' })), 'Reiter ende');
  assert.equal(describeTarget(el({})), null);
});

const SRV = 'https://script.google.com/macros/s/AKfycbxyz/exec';

test('validReportUrl: nur Adressen des Apps-Script-Dienstes', () => {
  assert.equal(validReportUrl(SRV), true);
  for (const u of ['', null, undefined, 'http://script.google.com/macros/s/x/exec', 'https://evil.example/https://script.google.com/', 'https://script.google.com/x y', `https://script.google.com/${'a'.repeat(400)}`]) {
    assert.equal(validReportUrl(u), false, String(u));
  }
});

test('buildReport: url nur mit gültiger Status-Server-Adresse', () => {
  assert.equal(buildReport({ kind: 'Auto-Fehler', error: 'x', version: 'v116', mode: 'el', url: SRV }).url, SRV);
  assert.equal(buildReport({ kind: 'Auto-Fehler', error: 'x', version: 'v116', mode: 'el', url: 'https://evil.example/' }).url, '');
  assert.equal(buildReport({ kind: 'Auto-Fehler', error: 'x', version: 'v116', mode: 'el' }).url, '');
});

test('reportPayload: { rep } ohne url, mit Gerät/OS/Plattform, Felder auf 2000 Zeichen', () => {
  const r = buildReport({ kind: 'Manuelle Meldung', desc: 'D'.repeat(5000), version: 'v116', mode: 'hf', url: SRV });
  const p = reportPayload({ ...r, log: 'L'.repeat(9000) }, { device: 'Google Pixel 7', os: 'Android 14 (SDK 34)' });
  assert.deepEqual(Object.keys(p), ['rep']);
  assert.equal('url' in p.rep, false);
  assert.equal(p.rep.platform, 'Android');
  assert.equal(p.rep.device, 'Google Pixel 7');
  assert.equal(p.rep.os, 'Android 14 (SDK 34)');
  assert.equal(p.rep.kind, 'Manuelle Meldung');
  assert.ok(p.rep.desc.length <= 2000 && p.rep.log.length <= 2000);
  assert.equal(p.rep.version, 'Web v116');
  assert.equal(reportPayload({}, { platform: 'Web' }).rep.platform, 'Web');
});
