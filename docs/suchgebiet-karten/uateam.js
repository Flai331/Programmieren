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
  if (!p.parentEid) return `Team ${teams.length + 1}`;
  const base = `${uaPrefix(p)}-Team `;
  const used = new Set(teams.map((m) => String(m.label || '').trim().toLowerCase()));
  let n = teams.filter((m) => String(m.label || '').startsWith(base)).length + 1;
  while (used.has(`${base}${n}`.toLowerCase())) n++;
  return `${base}${n}`;
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
