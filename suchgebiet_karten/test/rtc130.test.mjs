// v130.15: Automatischer Live-Abgleich per WebRTC – Signalisierungs-Nachrichten (reine Logik)
import test from 'node:test';
import assert from 'node:assert/strict';
import { RTC_KIND, buildRtcMsg, isRtcMsg, rtcFor, shouldYield } from '../web/rtc.js';

test('buildRtcMsg: Angebot/Antwort/ICE mit Absender, Ziel, Art', () => {
  const offer = buildRtcMsg({ by: 'id-a', byName: 'EL', to: '*', rt: 'offer', sdp: 'v=0...', id: 'm1' });
  assert.deepEqual(offer, { v: 1, id: 'm1', a: 'EL', tm: 'Einsatzleitung', s: RTC_KIND, t: offer.t, by: 'id-a', byName: 'EL', to: '*', rt: 'offer', sdp: 'v=0...' });
  const ice = buildRtcMsg({ by: 'id-a', to: 'id-b', rt: 'ice', cand: { candidate: 'x' }, id: 'm2' });
  assert.deepEqual(ice.cand, { candidate: 'x' });
  assert.equal(ice.to, 'id-b');
});

test('isRtcMsg: erkennt nur gültige Signalisierungs-Nachrichten', () => {
  assert.equal(isRtcMsg(buildRtcMsg({ by: 'a', rt: 'offer', id: 'x' })), true);
  assert.equal(isRtcMsg({ s: 'el', by: 'a' }), false);
  assert.equal(isRtcMsg({ s: RTC_KIND, by: 'a' }), false); // kein rt
  assert.equal(isRtcMsg(null), false);
});

test('rtcFor: nur an mich gerichtete (oder offene) Nachrichten anderer Geräte, zeitlich sortiert', () => {
  const msgs = [
    buildRtcMsg({ by: 'me', to: '*', rt: 'offer', t: 1, id: 'own' }), // eigene Nachricht: raus
    buildRtcMsg({ by: 'other', to: 'someoneElse', rt: 'answer', t: 2, id: 'notmine' }), // für jemand anderen: raus
    buildRtcMsg({ by: 'other', to: '*', rt: 'offer', t: 3, id: 'broadcast' }),
    buildRtcMsg({ by: 'other2', to: 'me', rt: 'answer', t: 2, id: 'direct' }),
    { s: 'el', txt: 'normale Nachricht' }, // keine Signalisierung: raus
  ];
  assert.deepEqual(rtcFor(msgs, 'me').map((m) => m.id), ['direct', 'broadcast']);
});

test('shouldYield: feste, überschneidungsfreie Regel bei gleichzeitigem Angebot beider Seiten', () => {
  assert.equal(shouldYield('a-device', 'b-device'), false); // 'a' < 'b' -> bleibt Anbieter
  assert.equal(shouldYield('b-device', 'a-device'), true); // 'b' > 'a' -> gibt nach, nimmt die Antwort des anderen an
  assert.notEqual(shouldYield('x', 'y'), shouldYield('y', 'x')); // nie beide nachgeben oder beide anbieten
});
