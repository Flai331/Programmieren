// v98: Team-Chips, Ungelesen-Logik, Erinnerung und Verlauf der Status-Meldungen (Einsatzleitung).
// Reine Logik ohne DOM, damit sie testbar ist.
import { msgLabel, isUrgent, headMsg } from './status.js';
import { isAccepted } from './locks.js';
import { isDone, closeMsg, msgPct } from './closeout.js';

export const BANNER_MS = 5 * 60e3; // so lange ungelesen: Banner
export const BEEP_MS = 7 * 60e3; // so lange ungelesen: Piepton
export const BEEP_EVERY_MS = 2 * 60e3; // danach alle …
export const SNOOZE_PICKS = [5, 10, 15, 30];
export const SNOOZE_MAX_MIN = 720;

const hm = (t) => new Date(t).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });

// Gebietsnamen eines Auftrags, wenn die App keine Namen liefert: gemerkte Beschreibung bzw. „Umriss n“
function defaultAreas(x, items) {
  const names = [];
  let n = 0;
  for (const id of x.items || []) {
    const it = (items || []).find((q) => q && q.id === id);
    if (!it || it.kind !== 'track' || it.open || (it.pts || []).length < 3) continue;
    names.push(it.name || `Umriss ${++n}`);
  }
  return names.length ? names.join(' + ') : x.what || '';
}

// Wurde die QR-Rückmeldung dieses Auftrags eingelesen und kam seither nichts Neueres?
export function isReturned(x, msgs) {
  if (!x.last) return false;
  return !(msgs || []).some((m) => m.a === x.id && m.t > x.last);
}

// Chips: einer je Team mit laufendem Auftrag, in fester Team-Reihenfolge (marks); Teams ohne Eintrag in marks danach
// (in der Reihenfolge der Aufträge). areasOf(x) -> Gebietsnamen als Text (optional); ack = quittierte Fund-/Hilfe-IDs.
// Dringende Meldungen (Fund/Hilfe) bleiben als Chip-Text stehen, auch wenn danach Routinemeldungen kamen.
export function teamChips(sent, msgs, marks, items, areasOf, ack = []) {
  const byTeam = new Map();
  for (const x of sent || []) {
    if (isDone(x)) continue; // abgeschlossen: Team gilt als frei
    // Rückmeldung da, aber das Team meldet „abgeschlossen“: Chip bleibt, bis die Einsatzleitung abschließt
    if (isReturned(x, msgs) && !closeMsg(msgs, x.id)) continue;
    const key = x.teamId || `n:${x.team || ''}`;
    const prev = byTeam.get(key);
    // mehrere Aufträge: der neueste (nicht zurückgemeldete)
    if (!prev || (x.at || 0) >= (prev.at || 0)) byTeam.set(key, x);
  }
  const out = [];
  for (const [key, x] of byTeam) {
    const team = (marks || []).find((m) => m.id === x.teamId);
    const own = (msgs || []).filter((m) => m.a === x.id);
    const last = own[own.length - 1] || null;
    const head = headMsg(own);
    const acc = isAccepted(x);
    let status;
    let t;
    if (last && last.s === 'zu') { const pc = msgPct(last); status = `✅ meldet abgeschlossen ${hm(last.t)}${pc != null ? ` (${pc} %)` : ''}`; t = last.t; }
    else if (last && last.s !== 'ok') { status = `${msgLabel(head)} ${hm(head.t)}`; t = last.t; }
    else if (last || acc) { const at = last ? last.t : x.acc; status = `📲 übernommen ${hm(at)}`; t = at; }
    else { status = '📲 wartet'; t = x.at || 0; }
    out.push({
      key, a: x.id, teamId: x.teamId || '', color: team ? team.color : '#455a64',
      team: team ? team.label : x.team || 'Team', dog: team && team.dog ? team.dog : '',
      areas: areasOf ? areasOf(x) : defaultAreas(x, items), status, t, wait: !last && !acc,
      urgent: !!head && isUrgent(head), todo: !!head && isUrgent(head) && !(ack || []).includes(head.id), last,
    });
  }
  // feste Reihenfolge wie im Teams-Fenster; nicht gelistete Teams hinten (stabil)
  return teamOrder(out, marks);
}
// Feste Team-Reihenfolge (wie im Teams-Fenster = Reihenfolge von marks); gleiche/unbekannte Teams behalten ihre Reihenfolge.
// Elemente tragen die Team-ID als teamId.
export function teamOrder(list, marks) {
  const rank = (c) => { const i = (marks || []).findIndex((m) => m.id === c.teamId); return i < 0 ? 1e9 : i; };
  return list.map((c, i) => [c, i]).sort((p, q) => rank(p[0]) - rank(q[0]) || p[1] - q[1]).map((e) => e[0]);
}
// Passen nicht alle Chips hin: Teams mit ungequittiertem Fund/Hilfe zuerst (sonst Reihenfolge unverändert)
export const todoFirst = (chips) => [...chips.filter((c) => c.todo), ...chips.filter((c) => !c.todo)];
export const chipText = (c) => [`${c.team}${c.dog ? ` (${c.dog})` : ''}`, c.areas, c.status].filter(Boolean).join(' · ');

// Alle Aufträge eines Teams (IDs)
export const teamAssignments = (sent, teamId) => (sent || []).filter((x) => x.teamId === teamId).map((x) => x.id);
// Letzte n Meldungen eines Teams (neueste zuerst)
export function teamMsgs(sent, msgs, teamId, n = 3) {
  const ids = new Set(teamAssignments(sent, teamId));
  return (msgs || []).filter((m) => ids.has(m.a)).slice(-n).reverse();
}

// ---------- ungelesen ----------
// Ungelesen: auf diesem Gerät eingegangen (recv[id]), nicht gesehen (seen[id]), nicht dringend (Fund/Hilfe haben ihren Dialog)
export function unreadMsgs(msgs, seen, recv) {
  return (msgs || []).filter((m) => recv && recv[m.id] && !(seen && seen[m.id]) && !isUrgent(m));
}
// Eingang vermerken (nur neue IDs)
export function noteReceived(recv, msgs, now = Date.now()) {
  for (const m of msgs || []) if (!recv[m.id]) recv[m.id] = now;
  return recv;
}
// Als gelesen markieren; ids = Liste von IDs oder Meldungen
export function markSeen(seen, ids, now = Date.now()) {
  for (const i of ids || []) { const id = typeof i === 'string' ? i : i.id; if (id && !seen[id]) seen[id] = now; }
  return seen;
}
// Karten kleinhalten: höchstens max Einträge (die neuesten)
export function prune(obj, max = 600) {
  const keys = Object.keys(obj);
  if (keys.length <= max) return obj;
  keys.sort((a, b) => obj[a] - obj[b]).slice(0, keys.length - max).forEach((k) => delete obj[k]);
  return obj;
}

// Erinnerung: 'none' | 'banner' | 'beep'. Alter ab Eingang der ältesten ungelesenen Meldung.
// lastBeep: Zeit des letzten Pieptons (null = noch keiner). snoozeUntil > now -> 'none'.
export function unreadAlert(unread, recvTimes, now, snoozeUntil = 0, lastBeep = null) {
  if (!unread || !unread.length) return 'none';
  if (Number(snoozeUntil) > now) return 'none';
  const ts = unread.map((m) => Number(recvTimes && recvTimes[typeof m === 'string' ? m : m.id]) || now);
  const age = now - Math.min(...ts);
  if (age < BANNER_MS) return 'none';
  if (age >= BEEP_MS && (lastBeep == null || now - lastBeep >= BEEP_EVERY_MS)) return 'beep';
  return 'banner';
}
export const unreadAge = (unread, recvTimes, now) => (unread && unread.length ? now - Math.min(...unread.map((m) => Number(recvTimes[m.id]) || now)) : 0);
export function bannerText(n, ageMs) {
  const min = Math.max(1, Math.floor(ageMs / 60e3));
  return `📣 ${n} ungelesene Meldung${n === 1 ? '' : 'en'} seit ${min} min – antippen`;
}
// Minuten aus dem Freitextfeld: ganze Zahl 1 … 720, sonst null
export function parseSnooze(text) {
  const s = String(text ?? '').trim().replace(',', '.');
  if (!/^\d+(\.\d+)?$/.test(s)) return null;
  const n = Math.round(Number(s));
  return n >= 1 && n <= SNOOZE_MAX_MIN ? n : null;
}
export const snoozeUntilFrom = (now, min) => now + min * 60e3;
export const snoozeText = (until) => `💤 bis ${hm(until)}`;

// ---------- Verlauf ----------
// Alle Meldungen (neueste oben), optional auf ein Team (teamId) beschränkt; '' = alle Teams
export function historyFilter(msgs, sent, teamId = '') {
  const ids = teamId ? new Set(teamAssignments(sent, teamId)) : null;
  return [...(msgs || [])].filter((m) => !ids || ids.has(m.a)).sort((a, b) => b.t - a.t);
}
// Teams, die im Verlauf zur Auswahl stehen: [{ id, label }] (nur solche mit Aufträgen)
export function historyTeams(sent, marks) {
  const seen = new Map();
  for (const x of sent || []) {
    if (!x.teamId || seen.has(x.teamId)) continue;
    const t = (marks || []).find((m) => m.id === x.teamId);
    seen.set(x.teamId, { id: x.teamId, label: t ? t.label : x.team || 'Team' });
  }
  return [...seen.values()];
}
export { msgLabel, isUrgent };
