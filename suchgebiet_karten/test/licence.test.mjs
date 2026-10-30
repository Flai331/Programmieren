import test from 'node:test';
import assert from 'node:assert/strict';
import {
  licenceState, applyLicenceReply, newLicence, normalizeLicence, checkUrl, deviceModel, mailtoHref, LIC_MS,
} from '../web/licence.js';

const D = 24 * 3600 * 1000;
const now = 1e12;

test('licenceState: Frist ab firstStart bzw. lastOk, genau 14 Tage', () => {
  assert.equal(licenceState({ now, firstStart: now }), 'ok');
  assert.equal(licenceState({ now, firstStart: now - 14 * D }), 'ok'); // genau 14 Tage noch ok
  assert.equal(licenceState({ now, firstStart: now - 14 * D - 1 }), 'expired');
  assert.equal(licenceState({ now, firstStart: now - 30 * D, lastOk: now - 13 * D }), 'ok');
  assert.equal(licenceState({ now, firstStart: now - 30 * D, lastOk: now - 15 * D }), 'expired');
  assert.equal(licenceState({ now, firstStart: now - 30 * D, lastOk: now - 14 * D - 1 }), 'expired');
  assert.equal(LIC_MS, 14 * D);
});

test('licenceState: blocked/inactive haben Vorrang', () => {
  assert.equal(licenceState({ now, firstStart: now, blocked: true }), 'blocked');
  assert.equal(licenceState({ now, firstStart: now, inactive: true }), 'blocked');
  assert.equal(licenceState({ now, firstStart: now - 99 * D, blocked: true }), 'blocked');
});

test('applyLicenceReply: alte Server-Antwort gilt als ok', () => {
  const s = { ...newLicence('abcdefghijkl', 5), blocked: true, inactive: true };
  const r = applyLicenceReply(s, { ok: true, info: 'läuft' }, 99);
  assert.equal(r.lastOk, 99);
  assert.equal(r.blocked, false);
  assert.equal(r.inactive, false);
});

test('applyLicenceReply: lic-Antwort gesperrt / Hauptschalter / aktiv', () => {
  const s = newLicence('abcdefghijkl', 5);
  let r = applyLicenceReply(s, { ok: true, lic: true, aktiv: true, gesperrt: true, kontakt: ' a@b.de ' }, 50);
  assert.deepEqual([r.blocked, r.inactive, r.lastOk, r.kontakt], [true, false, 50, 'a@b.de']);
  r = applyLicenceReply(s, { ok: true, lic: true, aktiv: false, gesperrt: false, kontakt: '' }, 60);
  assert.deepEqual([r.blocked, r.inactive, r.kontakt], [false, true, '']);
  r = applyLicenceReply(r, { ok: true, lic: true, aktiv: true, gesperrt: false }, 70);
  assert.deepEqual([r.blocked, r.inactive, r.lastOk], [false, false, 70]);
});

test('applyLicenceReply: Fehler ändern nichts', () => {
  const s = { ...newLicence('abcdefghijkl', 5), lastOk: 7 };
  assert.equal(applyLicenceReply(s, null, 99), s);
  assert.equal(applyLicenceReply(s, { ok: false, fehler: 'x' }, 99), s);
  assert.equal(applyLicenceReply(s, undefined, 99), s);
});

test('newLicence/normalizeLicence: ID-Muster', () => {
  for (const raw of ['ab', 'x y!ä', 'abcdefghij12345678901234567890123456789012345']) {
    const l = newLicence(raw, 1);
    assert.match(l.id, /^[A-Za-z0-9_-]{12,40}$/);
  }
  assert.equal(normalizeLicence(null, 1), null);
  assert.equal(normalizeLicence({ id: 'kurz' }, 1), null);
  assert.equal(normalizeLicence({ id: 'abcdefghijkl', lastOk: 3 }, 9).firstStart, 9);
});

test('checkUrl/deviceModel/mailtoHref', () => {
  assert.equal(deviceModel('Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit'), 'Pixel 7');
  assert.equal(deviceModel('x'.repeat(100)).length, 60);
  const u = checkUrl('https://x/exec', { id: 'abcdefghijkl', mode: 'hf', version: 'v113', platform: 'web', name: 'Max & Co', ua: 'Linux; Android 13; Pixel 7)' });
  assert.match(u, /^https:\/\/x\/exec\?lic=abcdefghijkl&m=hf&v=v113&p=web&n=Max%20%26%20Co&ua=Pixel%207$/);
  const m = mailtoHref('', 'abcdefghijkl');
  assert.match(m, /^mailto:error\.404\.found@outlook\.de\?subject=Suchgebiet-Karten%20Freigabe&body=Ger%C3%A4te-ID%3A%20abcdefghijkl$/);
});
