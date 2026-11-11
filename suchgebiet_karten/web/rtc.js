// v130.15: Automatischer Live-Abgleich zwischen Geräten der Einsatzleitung (EL/ELW/UA) per WebRTC – sobald sie
// einen Weg zueinander haben (meist: dasselbe WLAN, z. B. am ELW-Router), baut sich eine direkte Verbindung auf
// und hält Felder/Teams/Aufträge/Meldungen laufend aktuell, ohne manuelles "Fortschritt senden". Bricht die
// Verbindung ab, bleibt "Fortschritt senden" per QR/Link wie bisher der verlässliche Rückweg.
//
// Die Signalisierung (Angebot/Antwort/ICE) läuft über denselben Status-Server-Raum (Google Sheets) wie alle
// anderen Meldungen – Ende-zu-Ende verschlüsselt, bereits vorhandene Warteschlange/Abfrage. Ein späterer Wechsel
// auf einen eigenen Server braucht dafür nur eine neue URL (db.statusUrl), nicht ein neues Protokoll: die
// eigentliche Nutzlast (buildProgress/mergeProgress aus progress.js) bleibt unverändert, nur der Transportweg
// (WebRTC-Datenkanal statt QR-Code) ist neu.
// Reine Logik ohne DOM (RTCPeerConnection selbst lebt in app.js, da node:test kein WebRTC kennt).

export const RTC_KIND = 'rtc';

// Signalisierungs-Nachricht (geht wie jede andere Statusmeldung über buildMsg/encryptMsg/postMsg).
// by/byName: Geräte-ID und -Name des Absenders; to: Geräte-ID des Ziels oder '*' (noch unbekannt, erstes Angebot)
export function buildRtcMsg({ by, byName, to, rt, sdp, cand, t, id }) {
  const m = { v: 1, id, a: 'EL', tm: 'Einsatzleitung', s: RTC_KIND, t: t || Date.now(), by, to: to || '*', rt };
  if (byName) m.byName = String(byName).slice(0, 60);
  if (sdp) m.sdp = sdp;
  if (cand) m.cand = cand;
  return m;
}
export const isRtcMsg = (m) => !!m && m.s === RTC_KIND && typeof m.by === 'string' && typeof m.rt === 'string';
// An mich gerichtete (oder noch offene) Signalisierungs-Nachrichten eines anderen Geräts, zeitlich sortiert
export const rtcFor = (msgs, myId) => (msgs || [])
  .filter((m) => isRtcMsg(m) && m.by !== myId && (m.to === myId || m.to === '*'))
  .sort((a, b) => a.t - b.t);

// Zwei Geräte schicken gleichzeitig ein Angebot ("Glarre"): eine feste Regel entscheidet ohne Rückfrage, wer
// nachgibt und stattdessen die Antwort des anderen annimmt – die mit der (als Text) kleineren Geräte-ID.
export const shouldYield = (myId, otherId) => String(myId) > String(otherId);
