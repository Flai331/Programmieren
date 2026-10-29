// Fehlermeldungen aus der Android-App an die Notion-Fehlerzentrale (🐛 Suchgebiet-Karten).
// Hier nur das Zusammenstellen; gesendet wird nativ (AndroidBridge.reportBug).
// Grundsatz: keine Einsatzdaten – keine Namen, Personenbeschreibung, Kontakte,
// Telefonnummern, Koordinaten, Notizen oder Fotos.

export const MAX_FIELD = 2000; // Notion-Grenze je Textfeld
export const LOG_SIZE = 50; // so viele Bedienschritte gehen mit
export const REPEAT_MS = 30000; // gleicher Fehler höchstens alle 30 s
export const KINDS = { crash: 'Absturz', auto: 'Auto-Fehler', manual: 'Manuelle Meldung' };

export function clip(s, n = MAX_FIELD) {
  s = String(s ?? '');
  return s.length > n ? `${s.slice(0, n - 1)}…` : s;
}

// Entfernt, was nach Einsatzdaten aussieht, aus Fehlertexten und Bedienschritten
export function scrub(s) {
  return String(s ?? '')
    // Base64-/Datenblöcke (z. B. Fotos, gepackte Links)
    .replace(/data:[^\s'"]+/g, '‹Daten›')
    .replace(/#[areim]=[A-Za-z0-9_\-+/=.%]+/g, '#‹Link›')
    .replace(/[A-Za-z0-9+/_-]{60,}={0,2}/g, '‹Daten›')
    // E-Mail-Adressen
    .replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, '‹Mail›')
    // Koordinaten (Dezimalgrad) und MGRS/UTM
    .replace(/-?\d{1,3}[.,]\d{3,}\s*[,;/ ]\s*-?\d{1,3}[.,]\d{3,}/g, '‹Ort›')
    .replace(/\b\d{1,2}[C-X]\s?[A-Z]{2}\s?\d{3,5}\s?\d{3,5}\b/g, '‹Ort›')
    // Telefonnummern (mind. 6 Ziffern, auch mit Leerzeichen/Strichen)
    .replace(/\+?\d[\d ()/-]{5,}\d/g, (m) => (m.replace(/\D/g, '').length >= 6 ? '‹Nr›' : m));
}

// Kurzer, stabiler Schlüssel für „gleicher Fehler“ (ohne Zeilen-/Spaltennummern-Rauschen der URL)
export function fingerprint(kind, message, stack) {
  const top = String(stack || '').split('\n').slice(0, 3).join('|')
    .replace(/https?:\/\/[^/\s]+/g, '')
    .replace(/\?[^\s:)]*/g, '');
  const text = `${kind}|${String(message || '').replace(/\d+/g, '#')}|${top}`;
  let h = 0x811c9dc5; // FNV-1a
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, '0');
}

// Bedienschritte als Ringpuffer
export function createLog(size = LOG_SIZE, now = () => Date.now()) {
  const items = [];
  return {
    add(step) {
      const t = new Date(now());
      const hh = `${String(t.getHours()).padStart(2, '0')}:${String(t.getMinutes()).padStart(2, '0')}:${String(t.getSeconds()).padStart(2, '0')}`;
      items.push(`${hh} ${clip(scrub(step), 80)}`);
      if (items.length > size) items.splice(0, items.length - size);
    },
    list: () => items.slice(),
  };
}

// Beschreibt ein angetipptes Element ohne seinen Text (der kann Namen enthalten)
export function describeTarget(el) {
  for (let e = el, i = 0; e && i < 5; e = e.parentElement, i++) {
    if (e.id) return `${e.tagName.toLowerCase()}#${e.id}`;
    if (e.dataset && e.dataset.tool) return `Werkzeug ${e.dataset.tool}`;
  }
  if (!el || !el.tagName) return '';
  const cls = typeof el.className === 'string' ? el.className.split(/\s+/).filter(Boolean)[0] : '';
  return `${el.tagName.toLowerCase()}${cls ? `.${cls}` : ''}`;
}

// Darf dieser Fehler jetzt gemeldet werden? (merkt sich die letzte Meldung je Fingerprint)
export function throttle(seen, fp, now = Date.now(), ms = REPEAT_MS) {
  const last = seen.get(fp);
  if (last != null && now - last < ms) return false;
  seen.set(fp, now);
  return true;
}

// Bericht für AndroidBridge.reportBug (Gerät und Android-Version ergänzt die App selbst)
export function buildReport({
  kind = 'auto', description = '', message = '', stack = '', log = [], page = '', role = '', version = '', now = new Date(),
}) {
  const art = KINDS[kind] || KINDS.auto;
  const msg = scrub(message).trim();
  const title = kind === 'manual'
    ? `Meldung: ${clip(String(description).trim().split('\n')[0] || 'ohne Text', 80)}`
    : `${art}: ${clip(msg || 'Unbekannter Fehler', 80)}`;
  return {
    title: clip(title, 120),
    kind: art,
    description: clip(String(description).trim()),
    error: clip([msg, scrub(stack).trim()].filter(Boolean).join('\n')),
    log: clip(log.join('\n')),
    page: clip(scrub(page), 200),
    role: role === 'hf' ? 'HF' : 'EL',
    version: clip(version, 40),
    // Manuelle Meldungen sind nie „doppelt“ – jede bekommt einen eigenen Schlüssel
    fingerprint: kind === 'manual' ? fingerprint(kind, description, `t${now.getTime()}`) : fingerprint(kind, msg, scrub(stack)),
    time: now.toISOString(),
  };
}
