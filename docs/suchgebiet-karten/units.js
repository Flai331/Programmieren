// v128: Einheiten (Teams) mit Typ, Organisation, Funkrufname und Personenzahl. Reine Logik ohne DOM, testbar.
// Team-Felder (alle optional, ältere Teams ohne Felder gelten als Hund):
//   ty      – Typ: 'hund' (Standard, wird nicht gespeichert), 'kette', 'kfz', 'drohne'
//   org     – Organisation (FF, BW, DRK, JUH, ASB, MHD, THW, Polizei oder frei)
//   fk      – Funkrufname, automatisch gebildet: Organisation + je Organisation eine laufende Nummer (z. B. „DRK 2“)
//   helpers – Anzahl Suchhelfer (ohne Führer der Einheit)
// v130.6: Personenzahl ist nie mehr frei eintragbar – immer 1 (Führer der Einheit, z. B. Hundeführer) + Suchhelfer.
// Funkrufname und Teamname (label) entstehen automatisch aus der Organisation und werden einmal beim Setzen/Ändern
// der Organisation gebildet und gespeichert (nicht bei jeder Anzeige neu berechnet) – so bleibt der Name stabil,
// auch wenn auf einem anderen Gerät (z. B. im Unterabschnitt) nur ein Teil der Teams bekannt ist.
// Im Auftrag (QR) heißen sie kurz: tm.ty, tm.o, tm.fk, tm.n – nur gesetzte Felder.

export const UNIT_TYPES = [
  { code: 'hund', ico: '🐕', label: 'Hund', short: 'Hund', who: 'Hundeführer', anzeige: 'Hund zeigt an' },
  { code: 'kette', ico: '🚶', label: 'Fußtrupp / Kette', short: 'Kette', who: 'Trupp', anzeige: 'Trupp zeigt an' },
  { code: 'kfz', ico: '🚙', label: 'Fahrzeug / Quad', short: 'Fahrzeug', who: 'Fahrzeug', anzeige: 'Fahrzeug zeigt an' },
  { code: 'drohne', ico: '🚁', label: 'Drohne', short: 'Drohne', who: 'Drohnenteam', anzeige: 'Drohne zeigt an' },
];
export const ORGS = ['FF', 'BW', 'DRK', 'JUH', 'ASB', 'MHD', 'THW', 'Polizei'];
const TYPES = Object.fromEntries(UNIT_TYPES.map((t) => [t.code, t]));

// Typ-Code eines Teams (oder einer Meldung/eines Auftrags: Feld ty); unbekannt/leer = Hund
export const unitType = (m) => (m && TYPES[m.ty] ? m.ty : 'hund');
export const unitInfo = (m) => TYPES[unitType(m)];
export const typeIcon = (m) => unitInfo(m).ico;
// „🚶 Kette“, „🐕 Hund“
export const typeText = (m) => `${unitInfo(m).ico} ${unitInfo(m).short}`;
export const isDog = (m) => unitType(m) === 'hund';
// Wer meldet: „Hundeführer“, „Trupp“ …
export const whoText = (ty) => (TYPES[ty] || TYPES.hund).who;
// „Hund zeigt an“ je Typ (für die Meldungsarten und Texte)
export const anzeigeText = (ty) => (TYPES[ty] || TYPES.hund).anzeige;

// Personenzahl: immer 1 (Führer der Einheit) + Suchhelfer
export function persons(m) {
  if (!m) return 0;
  return 1 + Math.max(0, Math.floor(Number(m.helpers)) || 0);
}

// Kurzzeile unter dem Teamnamen: „🚶 Kette · FF · „Florian 1“ · 6 Pers.“
export function unitLine(m) {
  const n = persons(m);
  const h = isDog(m) && m.dog ? `Hund ${m.dog}` : '';
  return [typeText(m), String(m.org || '').trim(), m.fk ? `„${String(m.fk).trim()}“` : '', h, n ? `${n} Pers.` : ''].filter(Boolean).join(' · ');
}

// Team-Felder normalisieren (ändert m): Standardtyp wird nicht gespeichert, leere Felder fallen weg
export function cleanUnit(m) {
  if (!m) return m;
  if (!TYPES[m.ty] || m.ty === 'hund') delete m.ty;
  for (const k of ['org', 'fk']) { const v = String(m[k] == null ? '' : m[k]).trim(); if (v) m[k] = v; else delete m[k]; }
  delete m.pers; // v130.6: Personenzahl nicht mehr frei eintragbar (immer 1 + Suchhelfer)
  return m;
}

// Nächster freier Funkrufname für eine Organisation: „<Org> <N>“ – N ist die nächste freie, je Organisation
// laufende Nummer (wie bei nextTeamLabel: nie doppelt, auch wenn eine Nummer gelöscht/umbenannt wurde).
// Ohne Organisation gibt es keinen Funkrufnamen ('').
export function nextFunkrufname(org, marks, exceptId = '') {
  const o = String(org || '').trim();
  if (!o) return '';
  const used = new Set((marks || [])
    .filter((m) => m && m.kind === 'team' && m.id !== exceptId && String(m.org || '').trim() === o)
    .map((m) => String(m.fk || '').trim().toLowerCase()));
  let n = 1;
  while (used.has(`${o} ${n}`.toLowerCase())) n++;
  return `${o} ${n}`;
}

// ---------- im Auftrag (QR): kurze Schlüssel, nur gesetzte Felder ----------
// -> Teil von tm: { ty?, o?, fk?, n? }
export function packUnit(m) {
  const out = {};
  if (m && TYPES[m.ty] && m.ty !== 'hund') out.ty = m.ty;
  if (m && String(m.org || '').trim()) out.o = String(m.org).trim().slice(0, 30);
  if (m && String(m.fk || '').trim()) out.fk = String(m.fk).trim().slice(0, 40);
  if (m && Math.max(0, Math.floor(Number(m.helpers)) || 0) > 0) out.n = persons(m);
  return out;
}
// tm -> Team-Felder { ty?, org?, fk?, helpers? }
export function unpackUnit(tm) {
  const out = {};
  if (!tm) return out;
  if (TYPES[tm.ty] && tm.ty !== 'hund') out.ty = tm.ty;
  if (tm.o) out.org = String(tm.o).slice(0, 30);
  if (tm.fk) out.fk = String(tm.fk).slice(0, 40);
  const n = Math.floor(Number(tm.n));
  if (n > 0) out.helpers = Math.max(0, n - 1);
  return out;
}
// Fortschritt/Übergabe: fehlende Team-Felder des vorhandenen Teams old aus inc ergänzen (ändert old) -> true, wenn etwas dazukam
export function fillUnit(old, inc) {
  let n = 0;
  for (const k of ['ty', 'org', 'fk', 'dog', 'helpers', 'ua']) {
    if (inc[k] != null && inc[k] !== '' && (old[k] == null || old[k] === '')) { old[k] = inc[k]; n++; }
  }
  return n > 0;
}

// ---------- Kräfteübersicht aus den Teams ----------
// -> [{ org, lead, helpers, dogs, vehicles, teams }] je Organisation (Reihenfolge des ersten Auftretens);
// Führung = 1 je Einheit, Helfer = übrige Personen, Hunde = Hund-Teams, Fahrzeuge = Fahrzeug/Quad-Teams
export const NO_ORG = 'ohne Organisation';
export function forcesFromTeams(marks) {
  const by = new Map();
  for (const m of marks || []) {
    if (!m || m.kind !== 'team' || m.id === '-' || m.hidden) continue;
    const org = String(m.org || '').trim() || NO_ORG;
    if (!by.has(org)) by.set(org, { org, lead: 0, helpers: 0, dogs: 0, vehicles: 0, teams: 0 });
    const f = by.get(org);
    const n = Math.max(1, persons(m));
    f.teams++;
    f.lead += 1;
    f.helpers += n - 1;
    if (isDog(m)) f.dogs++;
    if (unitType(m) === 'kfz') f.vehicles++;
  }
  return [...by.values()];
}
// Zeile für den Bericht/die Kräfte: „FF: 3 Einheiten (1 Fußtrupp …)“ – Stärke wie im Kräfte-Fenster
export function forcesText(list) {
  return (list || []).map((f) => `${f.org}: ${f.teams} Einheit${f.teams === 1 ? '' : 'en'}, ${f.lead + f.helpers} Pers.${f.dogs ? `, ${f.dogs} Hund${f.dogs === 1 ? '' : 'e'}` : ''}${f.vehicles ? `, ${f.vehicles} Fahrz.` : ''}`);
}
// Teams, die in der Kräfteübersicht stehen: Anzahl je Typ „2 Hunde-Teams, 1 Kette“
export function typeCounts(marks) {
  const c = { hund: 0, kette: 0, kfz: 0, drohne: 0 };
  for (const m of marks || []) if (m && m.kind === 'team' && m.id !== '-' && !m.hidden) c[unitType(m)]++;
  return c;
}
