// v128: UA-Übersicht beim Haupt-ELW (und jedem EL-Gerät des Grund-Einsatzes): Tabelle UA -> Teams -> Stand / letzte Meldung / offen,
// Ampel für UAs ohne Rückmeldung länger als 60 Minuten. Reine Logik ohne DOM, testbar.
// Ein Team gehört zu einem UA, wenn es dort angelegt wurde (Team-Feld ua = UA-Name); Teams ohne ua gehören zum Grund-Einsatz.
import { isDone, msgPct, closeMsg } from './closeout.js';
import { msgLabel } from './status.js';
import { unitType, typeIcon } from './units.js';

export const STALE_MS = 60 * 60e3;
export const BASE_UA = 'Grund-Einsatz';

// Stand (0–100) des Teams: abgeschlossener Auftrag 100 bzw. gemerkt, sonst letzte Stand-/Abschlussmeldung des laufenden Auftrags
function standOf(x, msgs) {
  if (!x) return null;
  if (isDone(x)) return x.pct != null ? x.pct : 100;
  const own = msgs.filter((m) => m.a === x.id && (m.s === 'fertig' || m.s === 'zu') && msgPct(m) != null);
  return own.length ? msgPct(own[own.length - 1]) : null;
}

// -> [{ ua, teams: [{ teamId, label, ico, ty, open, done, pct, last, lastText, state }], open, done, last, pct, level }]
// level: 'ok' | 'stale' (keine Meldung seit > 60 min trotz offener Aufträge) | 'idle' (keine offenen Aufträge)
export function uaOverview(p, msgs, now = Date.now()) {
  const groups = new Map();
  const sent = p.sent || [];
  for (const m of p.marks || []) {
    if (m.kind !== 'team' || m.id === '-' || m.hidden) continue;
    const ua = String(m.ua || '').trim() || BASE_UA;
    if (!groups.has(ua)) groups.set(ua, []);
    const orders = sent.filter((x) => x.teamId === m.id);
    const run = orders.filter((x) => !isDone(x));
    const cur = run.reduce((a, x) => (!a || (x.at || 0) >= (a.at || 0) ? x : a), null) || orders.reduce((a, x) => (!a || (x.at || 0) >= (a.at || 0) ? x : a), null);
    const ids = new Set(orders.map((x) => x.id));
    const mine = msgs.filter((q) => ids.has(q.a) && q.s !== 'kor' && q.s !== 'ok' && !q.gone);
    const last = mine.length ? mine[mine.length - 1] : null;
    const zu = cur && !isDone(cur) ? closeMsg(msgs, cur.id) : null;
    groups.get(ua).push({
      teamId: m.id, label: m.label, ico: typeIcon(m), ty: unitType(m), open: run.length, done: orders.length - run.length, orders: orders.length,
      pct: standOf(cur, msgs), last: last ? last.t : 0, lastText: last ? msgLabel(last) : '', meldetAbgeschlossen: !!zu,
      accepted: orders.some((x) => Number(x.acc) > 0), since: orders.reduce((a, x) => Math.max(a, x.acc || x.at || 0), 0),
    });
  }
  const rows = [];
  for (const [ua, teams] of groups) {
    const open = teams.reduce((a, t) => a + t.open, 0);
    const last = Math.max(0, ...teams.map((t) => t.last));
    const known = teams.filter((t) => t.pct != null);
    const ref = last || Math.max(0, ...teams.filter((t) => t.open).map((t) => t.since));
    const level = !open ? 'idle' : ref && now - ref > STALE_MS ? 'stale' : 'ok';
    rows.push({ ua, teams, open, done: teams.reduce((a, t) => a + t.done, 0), last, pct: known.length ? Math.round(known.reduce((a, t) => a + t.pct, 0) / known.length) : null, level });
  }
  // Grund-Einsatz zuerst, dann UAs nach Name
  return rows.sort((a, b) => (a.ua === BASE_UA ? -1 : b.ua === BASE_UA ? 1 : a.ua.localeCompare(b.ua, 'de')));
}
export const levelIcon = (l) => (l === 'stale' ? '🔴' : l === 'idle' ? '⚪' : '🟢');
// UAs, die als Unterabschnitt bekannt sind (mindestens ein Team mit ua-Feld)
export const hasUas = (p) => (p.marks || []).some((m) => m.kind === 'team' && String(m.ua || '').trim());
// Minuten seit der letzten Meldung als Text
export function agoText(t, now = Date.now()) {
  if (!t) return 'noch keine Meldung';
  const m = Math.max(0, Math.floor((now - t) / 60000));
  return m < 60 ? `vor ${m} min` : `vor ${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')} min`;
}
