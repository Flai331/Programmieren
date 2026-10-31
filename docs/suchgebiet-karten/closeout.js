// v101: Auftrag abschließen (Einsatzleitung) und Markierungen des vorherigen Teams.
// Meldung „zu“ (Hundeführer: ✅ Auftrag abgeschlossen) + QR-Rückmeldung -> Rückfrage „Abschließen?“;
// abgeschlossene Aufträge (x.done = Zeit, x.pct) geben das Gebiet frei. Reine Logik ohne DOM, damit sie testbar ist.

import { allGrids } from './store.js';
import { makeGrid, cellAt } from './grid.js';
import { hasArea, pointInPolygon } from './gpx.js';
import { isUrgent, msgLabel } from './status.js';

export const isDone = (x) => !!x && Number(x.done) > 0;

// Prozent einer Meldung (Stand/Abschluss): bei mehreren Gebieten das kleinste, sonst pc; ohne Angabe null
export function msgPct(m) {
  if (!m) return null;
  if (Array.isArray(m.ar) && m.ar.length) return Math.min(...m.ar.map((q) => Number(q[1])));
  return m.pc != null && Number.isFinite(Number(m.pc)) ? Number(m.pc) : null;
}
// Letzte Abschluss-Meldung (s: 'zu') eines Auftrags
export const closeMsg = (msgs, a) => (msgs || []).filter((m) => m && m.a === a && m.s === 'zu').pop() || null;
// Abgesucht in Prozent: beim Abschließen gemerkt (x.pct), sonst aus der letzten Abschluss-/Stand-Meldung
export function sentPct(x, msgs) {
  if (x && x.pct != null) return x.pct;
  const own = (msgs || []).filter((m) => m && x && m.a === x.id && (m.s === 'zu' || m.s === 'fertig') && msgPct(m) != null);
  return own.length ? msgPct(own[own.length - 1]) : null;
}

// Rückfrage „Auftrag abschließen?“ fällig? Liefert die Abschluss-Meldung, sonst null.
// Fällig, sobald Meldung „zu“ UND eine QR-Rückmeldung dieses Auftrags (x.last) da sind – egal in welcher Reihenfolge.
// Nach „Noch offen lassen“ (x.noAsk = { zu, n }) erst wieder bei neuer Meldung oder neuer Rückmeldung.
export function closeAsk(x, msgs) {
  if (!x || isDone(x) || !x.last) return null;
  const zu = closeMsg(msgs, x.id);
  if (!zu) return null;
  const k = x.noAsk;
  if (k && k.zu === zu.id && k.n === (x.n || 0)) return null;
  return zu;
}
// „Noch offen lassen“ merken
export function declineClose(x, msgs) {
  const zu = closeMsg(msgs, x.id);
  x.noAsk = { zu: zu ? zu.id : '', n: x.n || 0 };
  return x;
}
// Abschließen: Zeit und Stand merken; der 🔒-Schutz entfällt (done), das Team gilt als frei
export function closeSent(x, msgs, now = Date.now()) {
  const pct = sentPct(x, msgs);
  x.done = now;
  if (pct != null) x.pct = pct;
  delete x.unlock;
  return x;
}
// Wieder öffnen; die Rückfrage kommt nicht gleich noch einmal
export function reopenSent(x, msgs) {
  declineClose(x, msgs);
  delete x.done;
  return x;
}

// ---------- Markierungen des vorherigen Teams ----------
// Rückmeldungs-Items (it.resultKey = „<Auftrags-ID>|…“) früherer Aufträge, die im neu vergebenen Gebiet liegen.
// sel: { teamId, gridIds, fields: 'team'|'all'|'pick', picked: { Raster-ID: ["c,r"] }, areaItems: [gewählte Umrisse] }
// Liefert Gruppen je früherem Auftrag: [{ a, team, pct, label, items }] (älteste zuerst).
// Läuft der Auftrag desselben Teams noch (nicht abgeschlossen), gehören die Spuren dem Team selbst – sie bleiben draußen.
export function predecessorGroups(p, sel, msgs = []) {
  const teamId = sel.teamId || '';
  const keysOf = (g) => {
    let keys = [];
    if (sel.fields === 'pick') keys = (sel.picked && sel.picked[g.id]) || [];
    else if (sel.fields !== 'all' && teamId) keys = Object.keys(g.fills || {}).filter((k) => g.fills[k] === teamId);
    return new Set(keys); // leer = ganzes Gebiet
  };
  const grids = allGrids(p).filter((g) => (sel.gridIds || []).includes(g.id)).map((g) => ({ g, gr: makeGrid(g.area, g.cellM), keys: keysOf(g) }));
  const polys = (sel.areaItems || []).filter(hasArea).map((it) => it.pts);
  if (!grids.length && !polys.length) return [];
  const inside = (pt) => polys.some((poly) => pointInPolygon(pt, poly)) || grids.some(({ g, gr, keys }) => {
    const a = g.area;
    if (pt[0] > a.north || pt[0] < a.south || pt[1] < a.west || pt[1] > a.east) return false;
    if (!keys.size) return true;
    const c = cellAt(gr, pt[0], pt[1]);
    return !!c && keys.has(`${c.c},${c.r}`);
  });
  const by = new Map();
  for (const it of p.items || []) {
    if (!it.resultKey || it.hidden) continue;
    const a = String(it.resultKey).split('|')[0];
    const x = (p.sent || []).find((q) => q.id === a);
    if (x && teamId && x.teamId === teamId && !isDone(x)) continue;
    const pts = it.kind === 'text' ? [[it.lat, it.lon]] : it.pts || [];
    if (!pts.some(inside)) continue;
    if (!by.has(a)) by.set(a, []);
    by.get(a).push(it);
  }
  const out = [];
  for (const [a, items] of by) {
    const x = (p.sent || []).find((q) => q.id === a);
    const team = x ? x.team || 'Team' : 'früheres Team';
    const pct = x ? sentPct(x, msgs) : null;
    out.push({ a, team, pct, label: `${team}${pct != null ? `, ${pct} %` : ''}`, items, at: x ? x.at || 0 : 0 });
  }
  return out.sort((u, v) => u.at - v.at);
}
// Text für die Auswahl: „Vom vorherigen Team (Team 1, 80 %) – 2 Wege, 3 Markierungen“
export function predecessorText(g) {
  const ways = g.items.filter((it) => it.kind === 'track' && it.open).length;
  const rest = g.items.length - ways;
  const pl = (n, one, many) => `${n} ${n === 1 ? one : many}`;
  return `Vom vorherigen Team (${g.label}) – ${[ways && pl(ways, 'Weg', 'Wege'), rest && pl(rest, 'Markierung', 'Markierungen')].filter(Boolean).join(', ')}`;
}

// ---------- v116: Einsatz abschließen – offene Punkte ----------
// p: Einsatz (sent, marks, live.ack), msgs: Meldungen (ohne zurückgezogene/gelöschte, z. B. allMsgs()).
// -> { open: offene Aufträge (nicht abgeschlossen), unacked: Fund-/Hilfe-Meldungen ohne „Gesehen“,
//      noReturn: abgeschlossene Aufträge ohne eingelesene Rückgabe, count }
// „Rückgabe“ = QR-Rückmeldung eingelesen und seither nichts Neueres (wie isReturned in statusbar.js)
export function openPoints(p, msgs = []) {
  const sent = (p && p.sent) || [];
  const ack = (p && p.live && p.live.ack) || [];
  const teamOf = (x) => { const t = ((p && p.marks) || []).find((m) => m.id === x.teamId); return t ? t.label : x.team || 'Team'; };
  const returned = (x) => !!x.last && !msgs.some((m) => m.a === x.id && m.t > x.last);
  const open = sent.filter((x) => !isDone(x)).map((x) => ({ id: x.id, team: teamOf(x), what: x.what || '', returned: returned(x) }));
  const noReturn = sent.filter((x) => isDone(x) && !returned(x)).map((x) => ({ id: x.id, team: teamOf(x) }));
  const unacked = msgs.filter((m) => m && isUrgent(m) && !m.gone && !ack.includes(m.id))
    .map((m) => ({ id: m.id, team: m.tm || 'Team', label: msgLabel(m), t: m.t }));
  return { open, unacked, noReturn, count: open.length + unacked.length + noReturn.length };
}
