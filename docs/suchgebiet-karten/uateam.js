// v125: Team-Namen im Unterabschnitt (UA) – keine Überschneidung mit denen des Grund-Einsatzes. Reine Logik, testbar.
// Neue Teams im UA heißen „N-Team 1“ (Kürzel = erste Buchstaben des UA-Namens, in den Einstellungen änderbar);
// kommt beim EL ein Team, dessen Name schon ein anderes Team trägt, bekommt es den Zusatz „ (UA Nord)“.

// UA-Name aus dem Titel („Einsatz – UA Nord“ -> „Nord“), sonst der ganze Titel
export function uaName(title) {
  const m = /\bUA\s+(.+)$/.exec(String(title || ''));
  return (m ? m[1] : String(title || '')).trim();
}

// Kürzel: p.uaKey (eigene Wahl), sonst Anfangsbuchstaben der Wörter des UA-Namens (höchstens 3, groß)
export function uaPrefix(p) {
  const own = String((p && p.uaKey) || '').trim().slice(0, 4);
  if (own) return own;
  const words = uaName(p && p.title).replace(/^Team\s+/i, '').split(/[^\p{L}\p{N}]+/u).filter(Boolean);
  return (words.slice(0, 3).map((w) => w[0]).join('') || 'UA').toUpperCase();
}

// Standardname für ein neues Team: im UA „N-Team 1“ (nächste freie Nummer), sonst „Team n“
export function nextTeamLabel(p) {
  const teams = (p.marks || []).filter((m) => m.kind === 'team');
  const used = new Set(teams.map((m) => String(m.label || '').trim().toLowerCase()));
  if (!p.parentEid) { // v127: nächste freie Nummer (nicht doppelt, auch wenn ein Team gelöscht oder umbenannt wurde)
    let k = teams.length + 1;
    while (used.has(`team ${k}`)) k++;
    return `Team ${k}`;
  }
  const base = `${uaPrefix(p)}-Team `;
  let n = teams.filter((m) => String(m.label || '').startsWith(base)).length + 1;
  while (used.has(`${base}${n}`.toLowerCase())) n++;
  return `${base}${n}`;
}

// v127: Gibt es schon ein anderes Team mit diesem Namen (Groß-/Kleinschreibung egal)? -> das Team oder null
export function sameTeamName(marks, label, exceptId = '') {
  const l = String(label || '').trim().toLowerCase();
  if (!l) return null;
  return (marks || []).find((m) => m.kind === 'team' && m.id !== exceptId && String(m.label || '').trim().toLowerCase() === l) || null;
}

// Name für ein ankommendes Team: schon von einem ANDEREN Team benutzt -> Zusatz „ (UA Nord)“ (bei Bedarf mit Nummer)
export function uniqueTeamLabel(marks, inc, uaLabel) {
  const label = String(inc.label || '').trim();
  const taken = (l) => marks.some((m) => m.kind === 'team' && m.id !== inc.id && String(m.label || '').trim().toLowerCase() === l.toLowerCase());
  if (!label || !taken(label)) return inc.label;
  const suf = ` (${/^UA\b/.test(uaLabel) ? uaLabel : `UA ${uaLabel || '?'}`})`;
  let out = `${label}${suf}`;
  for (let n = 2; taken(out); n++) out = `${label}${suf} ${n}`;
  return out;
}

// v127: Name eines ankommenden Wegs/Eintrags, der schon vergeben ist -> Zusatz „ (UA Nord)“ (bei Bedarf mit Nummer)
export function uniqueName(taken, name, uaLabel) {
  const has = (l) => taken.some((n) => String(n || '').trim().toLowerCase() === l.toLowerCase());
  const label = String(name || '').trim();
  if (!label || !has(label)) return name;
  const suf = ` (${/^UA\b/.test(uaLabel) ? uaLabel : `UA ${uaLabel || '?'}`})`;
  let out = `${label}${suf}`;
  for (let n = 2; has(out); n++) out = `${label}${suf} ${n}`;
  return out;
}

// ---------- v128: Name des Unterabschnitts ----------
// Name ohne führendes „UA “ („UA Nord“ -> „Nord“): so entsteht nie „UA UA Nord“
export const stripUa = (name) => String(name || '').trim().replace(/^(?:UA\b[\s:–-]*)+/i, '').trim();
// Mehrere Gebiete -> ein Name „Nord + Süd“ (ohne Doppelte, ohne „UA “)
export const joinUaNames = (names) => [...new Set((names || []).map(stripUa).filter(Boolean))].join(' + ');
// Titel des Unterabschnitts: „<Einsatz> – UA <Name>“
export const uaTitle = (baseTitle, name) => `${String(baseTitle || 'Einsatz').trim() || 'Einsatz'} – UA ${stripUa(name) || 'Auswahl'}`;
// Umbenennen: der Einsatzteil bleibt, nur der UA-Name wechselt (ohne „ – UA …“ im Titel wird er angehängt)
export function renameUa(title, name) {
  const n = stripUa(name);
  if (!n) return String(title || '');
  const base = String(title || '').replace(/\s*[–-]\s*UA\s+.*$/, '').trim();
  return `${base || 'Einsatz'} – UA ${n}`;
}
