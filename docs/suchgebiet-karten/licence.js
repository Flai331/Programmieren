// v113: Freigabe – Installationen abschalten (Hauptschalter + einzelne Geräte). Reine Logik ohne DOM (testbar).
// Der Status-Server (apps-script/Code.gs, ?lic=<Geräte-ID>) sagt, ob die App aktiv ist und ob dieses Gerät gesperrt ist.

export const LIC_KEY = 'sgk-licence';
export const LIC_DAYS = 14; // so lange läuft die App ohne erfolgreiche Prüfung weiter
export const LIC_MS = LIC_DAYS * 24 * 3600 * 1000;
export const LIC_CHECK_MS = 6 * 3600 * 1000; // erneut prüfen, solange die App offen ist
export const LIC_TIMEOUT = 8000;
export const LIC_CONTACT = 'error.404.found@outlook.de';

// 'ok' | 'blocked' | 'expired'
export function licenceState({ now, lastOk, firstStart, blocked, inactive }) {
  if (blocked || inactive) return 'blocked';
  const base = Number(lastOk) || Number(firstStart) || now;
  return now - base > LIC_MS ? 'expired' : 'ok';
}

// Frischer Zustand beim ersten Start; die ID muss zu ^[A-Za-z0-9_-]{8,40}$ passen (mindestens 12 Zeichen)
export function newLicence(id, now) {
  let s = String(id || '').replace(/[^A-Za-z0-9_-]/g, '');
  while (s.length < 12) s += Math.random().toString(36).slice(2);
  return { id: s.slice(0, 40), firstStart: now, lastOk: 0, blocked: false, inactive: false, kontakt: '' };
}

// Gespeicherten Zustand prüfen und ergänzen; null/kaputt -> null (dann neu anlegen)
export function normalizeLicence(s, now) {
  if (!s || typeof s !== 'object' || !/^[A-Za-z0-9_-]{8,40}$/.test(String(s.id || ''))) return null;
  return {
    id: s.id, firstStart: Number(s.firstStart) || now, lastOk: Number(s.lastOk) || 0,
    blocked: !!s.blocked, inactive: !!s.inactive, kontakt: typeof s.kontakt === 'string' ? s.kontakt.slice(0, 120) : '',
  };
}

// Antwort des Servers einarbeiten. Fehler/Netzfehler (null, ok:false): nichts ändern.
// Alte Server-Version ohne `lic` ({ ok: true, info }): gilt als erfolgreich und nicht gesperrt.
export function applyLicenceReply(state, reply, now) {
  if (!reply || reply.ok !== true) return state;
  if (reply.lic !== true) return { ...state, lastOk: now, blocked: false, inactive: false };
  const kontakt = typeof reply.kontakt === 'string' && reply.kontakt.trim() ? reply.kontakt.trim().slice(0, 120) : state.kontakt;
  return { ...state, lastOk: now, blocked: reply.gesperrt === true, inactive: reply.aktiv === false, kontakt };
}

// Gerätemodell aus dem User-Agent („Pixel 7“); sonst der gekürzte User-Agent
export function deviceModel(ua) {
  const s = String(ua || '');
  const m = /Android [\d.]+; ([^;)]+)/.exec(s);
  return (m ? m[1].trim() : s).slice(0, 60);
}

export function checkUrl(base, { id, mode, version, platform, name, ua }) {
  const q = [['lic', id], ['m', mode || ''], ['v', version], ['p', platform], ['n', name || ''], ['ua', deviceModel(ua)]];
  return `${base}${base.includes('?') ? '&' : '?'}${q.map(([k, v]) => `${k}=${encodeURIComponent(String(v).slice(0, 60))}`).join('&')}`;
}

export const lockTitle = (st) => (st === 'expired' ? '🔒 Freigabe abgelaufen' : '🔒 Suchgebiet-Karten ist gesperrt');
export const lockText = (st) => (st === 'expired'
  ? `Seit über ${LIC_DAYS} Tagen konnte die Freigabe nicht geprüft werden. Bitte mit dem Internet verbinden und erneut prüfen.`
  : 'Diese Installation wurde vom Administrator deaktiviert.');

export function mailtoHref(kontakt, id) {
  const body = `Geräte-ID: ${id}`;
  return `mailto:${kontakt || LIC_CONTACT}?subject=${encodeURIComponent('Suchgebiet-Karten Freigabe')}&body=${encodeURIComponent(body)}`;
}
