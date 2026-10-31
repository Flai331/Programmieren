// v113: Freigabe – Installationen abschalten (Hauptschalter + einzelne Geräte). Reine Logik ohne DOM (testbar).
// Der Status-Server (apps-script/Code.gs, ?lic=<Geräte-ID>) sagt, ob die App aktiv ist und ob dieses Gerät gesperrt ist.

export const LIC_KEY = 'sgk-licence';
export const LIC_DAYS = 14; // so lange läuft die App ohne erfolgreiche Prüfung weiter
export const LIC_MS = LIC_DAYS * 24 * 3600 * 1000;
export const LIC_CHECK_MS = 6 * 3600 * 1000; // erneut prüfen, solange die App offen ist
export const LIC_TIMEOUT = 8000;
export const LIC_CONTACT = 'error.404.found@outlook.de';
export const LIC_UNLOCK_MS = 24 * 3600 * 1000; // so lange entsperrt ein richtiger Notfallcode

// 'ok' | 'blocked' | 'expired' | 'deferred'
// until: Notfallcode eingegeben, entsperrt bis dahin (auch offline).
// busy: ein Einsatz läuft – die Sperre greift nie mitten im Einsatz, sondern wird als 'deferred' (nur Hinweis) angezeigt.
export function licenceState({ now, lastOk, firstStart, blocked, inactive, busy, until }) {
  if (Number(until) > now) return 'ok';
  let st = 'ok';
  if (blocked || inactive) st = 'blocked';
  else {
    const base = Number(lastOk) || Number(firstStart) || now;
    if (now - base > LIC_MS) st = 'expired';
  }
  return st !== 'ok' && busy ? 'deferred' : st;
}

// Frischer Zustand beim ersten Start; die ID muss zu ^[A-Za-z0-9_-]{8,40}$ passen (mindestens 12 Zeichen)
export function newLicence(id, now) {
  let s = String(id || '').replace(/[^A-Za-z0-9_-]/g, '');
  while (s.length < 12) s += Math.random().toString(36).slice(2);
  return { id: s.slice(0, 40), firstStart: now, lastOk: 0, blocked: false, inactive: false, kontakt: '', notfall: '', until: 0 };
}

// SHA-256 als 64 Hex-Zeichen, sonst ''
const validHash = (h) => (typeof h === 'string' && /^[0-9a-f]{64}$/i.test(h.trim()) ? h.trim().toLowerCase() : '');

// Gespeicherten Zustand prüfen und ergänzen; null/kaputt -> null (dann neu anlegen)
export function normalizeLicence(s, now) {
  if (!s || typeof s !== 'object' || !/^[A-Za-z0-9_-]{8,40}$/.test(String(s.id || ''))) return null;
  return {
    id: s.id, firstStart: Number(s.firstStart) || now, lastOk: Number(s.lastOk) || 0,
    blocked: !!s.blocked, inactive: !!s.inactive, kontakt: typeof s.kontakt === 'string' ? s.kontakt.slice(0, 120) : '',
    notfall: validHash(s.notfall), until: Number(s.until) || 0,
  };
}

// Antwort des Servers einarbeiten. Fehler/Netzfehler (null, ok:false): nichts ändern.
// Alte Server-Version ohne `lic` ({ ok: true, info }): gilt als erfolgreich und nicht gesperrt.
export function applyLicenceReply(state, reply, now) {
  if (!reply || reply.ok !== true) return state;
  if (reply.lic !== true) return { ...state, lastOk: now, blocked: false, inactive: false };
  const kontakt = typeof reply.kontakt === 'string' && reply.kontakt.trim() ? reply.kontakt.trim().slice(0, 120) : state.kontakt;
  // notfall: Hash des Notfallcodes; fehlt er in der Antwort, ist keiner hinterlegt
  return { ...state, lastOk: now, blocked: reply.gesperrt === true, inactive: reply.aktiv === false, kontakt, notfall: validHash(reply.notfall) };
}

// SHA-256 (Hex) eines Textes – wie der Server den Notfallcode hasht
export async function sha256Hex(text) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(String(text)));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// Notfallcode prüfen: richtig -> neuer Zustand mit until = jetzt + 24 h, falsch/leer/unbekannt -> null
export async function applyEmergencyCode(state, code, now) {
  const want = validHash(state && state.notfall);
  const c = String(code || '').trim();
  if (!want || !c) return null;
  return (await sha256Hex(c)) === want ? { ...state, until: now + LIC_UNLOCK_MS } : null;
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

export const DEFERRED_TEXT = 'Diese Installation ist gesperrt – nach Einsatzende nicht mehr nutzbar';

export const lockTitle = (st) => (st === 'expired' ? '🔒 Freigabe abgelaufen' : '🔒 Suchgebiet-Karten ist gesperrt');
export const lockText = (st) => (st === 'expired'
  ? `Seit über ${LIC_DAYS} Tagen konnte die Freigabe nicht geprüft werden. Bitte mit dem Internet verbinden und erneut prüfen.`
  : 'Diese Installation wurde vom Administrator deaktiviert.');

export function mailtoHref(kontakt, id) {
  const body = `Geräte-ID: ${id}`;
  return `mailto:${kontakt || LIC_CONTACT}?subject=${encodeURIComponent('Suchgebiet-Karten Freigabe')}&body=${encodeURIComponent(body)}`;
}
