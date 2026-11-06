// v128: Einsatzzeiten je Team aus den Meldungen: Start, Pausen, Ablösung, Ende/zurück am B-Ort; Personenstunden; „wer ist noch draußen?“.
// Reine Logik ohne DOM, testbar. Quelle sind die Meldungen der Teams (HF-App und Funkmeldungen der Einsatzleitung).
import { persons, unitLine } from './units.js';
import { durText } from './tracks.js';

const hm = (t) => { const d = new Date(t); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
const PRESENT = ['da', 'start', 'pause', 'fertig', 'ende', 'zu', 'ort'];

// Zeiten eines Teams aus seinen Meldungen (nach Zeit sortiert) -> { start, end, back, relieved, pauses: [[t0, t1]], activeMs, state, outside }
// state: 'none' (noch nichts), 'da' (am Einsatzort, Suche nicht begonnen), 'aktiv', 'pause', 'ende' (Suche beendet, noch nicht zurück), 'zurueck', 'abgeloest'
export function timesOf(msgs, now = Date.now()) {
  const list = [...(msgs || [])].filter((m) => m && Number.isFinite(m.t) && m.s !== 'kor' && !m.gone).sort((a, b) => a.t - b.t);
  const r = { start: null, end: null, back: null, relieved: null, pauses: [], activeMs: 0, state: 'none', outside: false };
  let runFrom = null; // Beginn des laufenden aktiven Stücks
  let pauseFrom = null;
  const stop = (t) => { if (runFrom != null) { r.activeMs += Math.max(0, t - runFrom); runFrom = null; } };
  for (const m of list) {
    if (m.s === 'start') {
      if (pauseFrom != null) { r.pauses.push([pauseFrom, m.t]); pauseFrom = null; }
      if (runFrom == null) runFrom = m.t;
      if (r.start == null) r.start = m.t;
      r.state = 'aktiv'; r.outside = true; r.end = null;
    } else if (m.s === 'pause') {
      if (runFrom != null) { stop(m.t); pauseFrom = m.t; r.state = 'pause'; }
      r.outside = true;
    } else if (m.s === 'ende' || m.s === 'zu') {
      if (pauseFrom != null) { r.pauses.push([pauseFrom, m.t]); pauseFrom = null; }
      stop(m.t);
      r.end = m.t; r.state = 'ende'; r.outside = true;
    } else if (m.s === 'abloes') {
      if (pauseFrom != null) { r.pauses.push([pauseFrom, m.t]); pauseFrom = null; }
      stop(m.t);
      r.end = r.end || m.t; r.relieved = m.t; r.state = 'abgeloest'; r.outside = false;
    } else if (m.s === 'zurueck') {
      if (pauseFrom != null) { r.pauses.push([pauseFrom, m.t]); pauseFrom = null; }
      stop(m.t);
      r.end = r.end || m.t; r.back = m.t; r.state = 'zurueck'; r.outside = false;
    } else if (PRESENT.includes(m.s) && r.state === 'none') {
      r.state = m.s === 'da' ? 'da' : 'aktiv'; r.outside = true; // Meldung ohne „Suche begonnen“: Zeit läuft nicht von selbst
    }
  }
  if (runFrom != null) r.activeMs += Math.max(0, now - runFrom);
  if (pauseFrom != null) r.pauses.push([pauseFrom, now]);
  r.pauseMs = r.pauses.reduce((a, [x, y]) => a + (y - x), 0);
  return r;
}

// Alle Teams mit Aufträgen: [{ teamId, label, mark, ...timesOf, persons, personMs }]. sent: Aufträge, msgs: Meldungen aller Teams
export function teamTimes(sent, msgs, marks, now = Date.now()) {
  const ids = new Map();
  for (const x of sent || []) {
    const k = x.teamId || `n:${x.team || ''}`;
    if (!ids.has(k)) ids.set(k, { teamId: x.teamId || '', label: x.team || 'Team', orders: new Set() });
    ids.get(k).orders.add(x.id);
  }
  const out = [];
  for (const [, g] of ids) {
    const mark = (marks || []).find((m) => m.id === g.teamId) || null;
    const mine = (msgs || []).filter((m) => g.orders.has(m.a));
    const t = timesOf(mine, now);
    const n = Math.max(1, persons(mark));
    out.push({ ...t, teamId: g.teamId, label: mark ? mark.label : g.label, mark, msgs: mine.length, persons: n, personMs: t.activeMs * n });
  }
  const order = (marks || []).map((m) => m.id);
  return out.sort((a, b) => (order.indexOf(a.teamId) + 1 || 1e9) - (order.indexOf(b.teamId) + 1 || 1e9));
}
export const personHours = (ms) => Math.round((ms / 3600e3) * 10) / 10;

// Wer ist noch draußen? (Teams, die am Einsatzort waren und nicht zurück/abgelöst sind)
export const outsideTeams = (rows) => (rows || []).filter((r) => r.outside);
const STATE_TEXT = { none: 'noch nicht gemeldet', da: 'am Einsatzort', aktiv: 'sucht', pause: 'Pause', ende: 'Suche beendet, noch draußen', zurueck: 'zurück am B-Ort', abgeloest: 'abgelöst' };
export const stateText = (r) => STATE_TEXT[r.state] || '';

// Zeile für den Bericht: { team, text } – Start, Pausen, Ablösung, Ende/zurück, Einsatzzeit, Personenstunden
export function timeLine(r, now = Date.now()) {
  if (r.state === 'none' || (r.start == null && !r.back && !r.relieved)) return { team: r.label, text: `${stateText(r) || 'keine Meldung'}` };
  const parts = [];
  if (r.start != null) parts.push(`Start ${hm(r.start)}`);
  for (const [a, b] of r.pauses) parts.push(`Pause ${hm(a)}–${hm(b)}`);
  if (r.relieved) parts.push(`Ablösung ${hm(r.relieved)}`);
  if (r.end && r.end !== r.relieved && r.end !== r.back) parts.push(`Ende ${hm(r.end)}`);
  if (r.back) parts.push(`zurück ${hm(r.back)}`);
  else if (r.outside) parts.push('noch draußen');
  parts.push(`Einsatzzeit ${durText(r.activeMs)}`);
  parts.push(`${personHours(r.personMs).toLocaleString('de-DE')} Personenstd. (${r.persons} Pers.)`);
  return { team: r.label, text: parts.join(' · ') };
}
// Zeilen für die Berichte; ohne Teams mit Meldungen leer
export function timeRows(rows, now = Date.now()) {
  return (rows || []).filter((r) => r.msgs).map((r) => {
    const l = timeLine(r, now);
    return { team: l.team, art: r.mark ? unitLine(r.mark) : '', text: l.text };
  });
}
export const totalPersonHours = (rows) => personHours((rows || []).reduce((a, r) => a + r.personMs, 0));
