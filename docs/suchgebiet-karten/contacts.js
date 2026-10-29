// Adressbuch: Kontakte (für alle Suchgebiete gemeinsam), Import/Export als vCard (.vcf) –
// das Format, das Handy-Kontakte, Outlook, WhatsApp usw. verstehen – oder als JSON.
// Kontakt: { id, name, role, org, call, phone, phone2, email, note }

export const FIELDS = [
  ['name', 'Name'],
  ['role', 'Funktion (z. B. Einsatzleiter, Hundeführerin)'],
  ['org', 'Organisation / Staffel / Behörde'],
  ['call', 'Funkrufname'],
  ['phone', 'Telefon'],
  ['phone2', 'Weitere Nummer'],
  ['email', 'E-Mail'],
  ['note', 'Notiz'],
];

export function normalizeContact(c) {
  const o = { id: c.id || Math.random().toString(36).slice(2, 10) };
  for (const [k] of FIELDS) o[k] = String(c[k] ?? '').trim();
  return o;
}

// Kurzform für Auftrags-Links: [Name, Funktion, Funkrufname, Telefon, weitere Nummer], leere Felder hinten weg
const COMPACT = ['name', 'role', 'call', 'phone', 'phone2'];
export function compactContact(c) {
  const a = COMPACT.map((k) => String(c[k] || '').trim().slice(0, 60));
  while (a.length > 1 && !a[a.length - 1]) a.pop();
  return a;
}
export function fromCompact(a) {
  return normalizeContact(Object.fromEntries(COMPACT.map((k, i) => [k, (Array.isArray(a) && a[i]) || ''])));
}

export function sortContacts(list) {
  return [...list].sort((a, b) => a.name.localeCompare(b.name, 'de', { sensitivity: 'base' }));
}

// Suche über alle Felder, mehrere Wörter = alle müssen vorkommen; Nummern ohne Leerzeichen
export function matches(c, q) {
  const words = q.toLowerCase().split(/\s+/).filter(Boolean);
  if (!words.length) return true;
  const hay = FIELDS.map(([k]) => c[k]).join(' ').toLowerCase();
  const digits = `${c.phone} ${c.phone2}`.replace(/[^\d+]/g, '');
  return words.every((w) => hay.includes(w) || (/^[\d+]/.test(w) && digits.includes(w.replace(/[^\d+]/g, ''))));
}

// Telefonnummer für tel:-Links (nur Ziffern und +)
export const telHref = (n) => `tel:${n.replace(/[^\d+]/g, '')}`;

// ---------- vCard ----------
const esc = (s) => s.replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/[,;]/g, (m) => `\\${m}`);
const unesc = (s) => s.replace(/\\n/gi, '\n').replace(/\\([,;\\])/g, '$1');

export function toVcf(list) {
  return list.map((c) => {
    const lines = ['BEGIN:VCARD', 'VERSION:3.0', `FN:${esc(c.name)}`];
    // N: Nachname;Vorname – einfache Aufteilung am letzten Leerzeichen
    const parts = c.name.split(' ');
    const last = parts.length > 1 ? parts.pop() : c.name;
    lines.push(`N:${esc(last)};${esc(parts.length && last !== c.name ? parts.join(' ') : '')};;;`);
    if (c.org) lines.push(`ORG:${esc(c.org)}`);
    if (c.role) lines.push(`TITLE:${esc(c.role)}`);
    if (c.phone) lines.push(`TEL;TYPE=CELL:${c.phone}`);
    if (c.phone2) lines.push(`TEL;TYPE=WORK:${c.phone2}`);
    if (c.email) lines.push(`EMAIL;TYPE=INTERNET:${c.email}`);
    if (c.call) lines.push(`NICKNAME:${esc(c.call)}`);
    if (c.note) lines.push(`NOTE:${esc(c.note)}`);
    lines.push('END:VCARD');
    return lines.join('\r\n');
  }).join('\r\n') + '\r\n';
}

// Quoted-Printable (ältere Android-Exporte)
function decodeQP(s) {
  const bytes = [];
  for (let i = 0; i < s.length; i++) {
    if (s[i] === '=' && /^[0-9A-F]{2}$/i.test(s.slice(i + 1, i + 3))) {
      bytes.push(parseInt(s.slice(i + 1, i + 3), 16));
      i += 2;
    } else bytes.push(s.charCodeAt(i));
  }
  return new TextDecoder().decode(new Uint8Array(bytes));
}

export function parseVcf(text) {
  // gefaltete Zeilen zusammenfügen (Fortsetzung beginnt mit Leerzeichen/Tab; bei QP mit „=“ am Ende)
  const raw = text.replace(/\r\n/g, '\n').replace(/=\n/g, '').replace(/\n[ \t]/g, '');
  const out = [];
  let cur = null;
  for (const line of raw.split('\n')) {
    const i = line.indexOf(':');
    if (i < 0) continue;
    const head = line.slice(0, i);
    let value = line.slice(i + 1).trim();
    const [nameRaw, ...params] = head.split(';');
    const name = nameRaw.replace(/^item\d+\./i, '').toUpperCase();
    if (name === 'BEGIN' && value.toUpperCase() === 'VCARD') { cur = { tels: [] }; continue; }
    if (!cur) continue;
    if (name === 'END') {
      const c = normalizeContact({
        name: cur.fn || cur.n || cur.org || cur.email || cur.tels[0] || '',
        role: cur.title, org: cur.org, call: cur.nick, phone: cur.tels[0], phone2: cur.tels[1], email: cur.email, note: cur.note,
      });
      if (c.name) out.push(c);
      cur = null;
      continue;
    }
    if (params.some((p) => /ENCODING=QUOTED-PRINTABLE/i.test(p))) value = decodeQP(value);
    value = unesc(value);
    if (name === 'FN') cur.fn = value;
    else if (name === 'N') cur.n = value.split(';').slice(0, 2).reverse().filter(Boolean).join(' ');
    else if (name === 'ORG') cur.org = value.split(';').filter(Boolean).join(', ');
    else if (name === 'TITLE' || name === 'ROLE') cur.title = cur.title || value;
    else if (name === 'TEL') cur.tels.push(value.replace(/^tel:/i, ''));
    else if (name === 'EMAIL') cur.email = cur.email || value;
    else if (name === 'NICKNAME') cur.nick = value;
    else if (name === 'NOTE') cur.note = value;
  }
  return out;
}

// Datei-Inhalt (vCard oder JSON) -> Kontakte
export function parseContacts(text) {
  const t = text.trim();
  if (/^BEGIN:VCARD/im.test(t)) return parseVcf(t);
  const data = JSON.parse(t);
  const list = Array.isArray(data) ? data : data.contacts || [];
  return list.map(normalizeContact).filter((c) => c.name);
}

// Neue Kontakte übernehmen; gleicher Name + gleiche Nummer/Mail = schon vorhanden
export function mergeContacts(existing, incoming) {
  const key = (c) => `${c.name.toLowerCase()}|${c.phone.replace(/\D/g, '')}|${c.email.toLowerCase()}`;
  const seen = new Set(existing.map(key));
  const added = incoming.filter((c) => !seen.has(key(c)) && seen.add(key(c)));
  return { list: [...existing, ...added.map((c) => ({ ...c, id: Math.random().toString(36).slice(2, 10) }))], added: added.length };
}
