// Fehlerberichte (nur Android-App): Bedienprotokoll und Bericht für die Notion-Fehlerzentrale.
// Wichtig: keine Einsatzdaten. Ins Protokoll kommen nur feste Kennungen (Fenster, Werkzeug,
// Knopf-ID), nie Text aus Eingabefeldern, Namen, Telefonnummern oder Koordinaten.

const MAX = 2000; // Notion: höchstens 2000 Zeichen je Textfeld

export function makeLog(max = 50) {
  const lines = [];
  return {
    add(text) {
      const t = new Date();
      const hh = (n) => String(n).padStart(2, '0');
      lines.push(`[${hh(t.getHours())}:${hh(t.getMinutes())}:${hh(t.getSeconds())}] ${String(text).slice(0, 120)}`);
      if (lines.length > max) lines.shift();
    },
    text() { return lines.join('\n'); },
    get size() { return lines.length; },
  };
}

// Knopf/Element für das Protokoll beschreiben – nur IDs und feste Attribute, kein Inhalt
export function describeTarget(el) {
  for (let e = el, i = 0; e && i < 4; e = e.parentElement, i++) {
    if (!e.getAttribute) continue;
    const id = e.getAttribute('id');
    const tab = e.getAttribute('data-tab');
    const tool = e.getAttribute('data-tool');
    if (tab) return `Reiter ${tab}`;
    if (tool) return `Werkzeug ${tool}`;
    if (id && /^[\w-]+$/.test(id)) return `#${id}`;
  }
  return null;
}

// Kurzer, stabiler Fingerabdruck: gleicher Fehler an gleicher Stelle = gleicher Wert
export function fingerprint(error, stack = '') {
  const first = String(stack).split('\n').find((l) => /\.js:\d+/.test(l)) || '';
  // Zeilennummern bleiben drin (Stelle), Spalten und Abfrageparameter nicht
  const key = `${String(error).replace(/\d{3,}/g, '#')}|${first.replace(/:\d+\)?$/, '').replace(/\?[^:)]*/, '').trim()}`;
  let h = 0x811c9dc5;
  for (let i = 0; i < key.length; i++) { h ^= key.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
  return `js-${h.toString(16).padStart(8, '0')}`;
}

// v116: Berichte gehen über den Status-Server (Apps Script) an Notion – der Token liegt dort, nicht in der App.
// Nur Adressen des Apps-Script-Dienstes werden angenommen.
export const REPORT_URL_PREFIX = 'https://script.google.com/';
export const validReportUrl = (u) => typeof u === 'string' && u.startsWith(REPORT_URL_PREFIX) && u.length <= 400 && !/\s/.test(u);

const cut = (s, n = MAX) => (String(s || '').length > n ? `${String(s).slice(0, n - 1)}…` : String(s || ''));

// kind: 'Manuelle Meldung' | 'Auto-Fehler'
export function buildReport({ kind, desc = '', error = '', stack = '', version, mode, page = '', log = '', url = '' }) {
  const title = kind === 'Manuelle Meldung'
    ? `Meldung: ${cut(desc.split('\n')[0] || 'ohne Beschreibung', 80)}`
    : `Fehler: ${cut(error || 'unbekannt', 100)}`;
  return {
    title,
    kind,
    desc: cut(desc),
    error: cut(error, 500),
    stack: cut(stack, 1400),
    page: cut(page, 200),
    role: mode === 'hf' ? 'Hundeführer' : 'Einsatzleitung',
    version: `Web ${version}`,
    log: cut(log),
    fingerprint: kind === 'Manuelle Meldung' ? '' : fingerprint(error, stack),
    time: new Date().toISOString(),
    url: validReportUrl(url) ? url : '', // Status-Server, an den die Android-App den Bericht schickt
  };
}

// POST-Body für den Status-Server: { rep: { …Bericht ohne url…, device, os, platform } }, alle Textfelder höchstens 2000 Zeichen.
// Die Android-App (ErrorReports.kt) baut denselben Body.
export function reportPayload(r, { device = '', os = '', platform = 'Android' } = {}) {
  const rep = {};
  for (const [k, v] of Object.entries(r || {})) if (k !== 'url') rep[k] = typeof v === 'string' ? cut(v) : v;
  return { rep: { ...rep, device: cut(device), os: cut(os), platform } };
}

// Gleicher Fehler höchstens alle 30 s
export function makeDedup(ms = 30000, now = () => Date.now()) {
  const seen = new Map();
  return (fp) => {
    const t = now();
    if (seen.has(fp) && t - seen.get(fp) < ms) return false;
    seen.set(fp, t);
    return true;
  };
}
