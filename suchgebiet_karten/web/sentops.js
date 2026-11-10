// v125: Aufträge an Hundeführer – QR erneut zeigen, Teams ohne Auftrag, Gebiete beim Auftrag dem Team zuordnen.
// Reine Logik ohne DOM, testbar.
import { allGrids, NO_TEAM } from './store.js';
import { buildAssignment } from './share.js';
import { hasArea } from './gpx.js';
import { isDone } from './closeout.js';
import { isAccepted } from './locks.js';

// Auswahl (wie sendSelection() in app.js) aus einem gespeicherten Auftrag (P.sent-Eintrag) rekonstruieren.
// Hinweistext, Kontakte, Rettungspunkte und Lage-Orte sind dort nicht gespeichert – dafür gilt der gemerkte Link (P.sentLinks).
export function selFromSent(p, x) {
  const ids = new Set(x.items || []);
  return {
    teamId: x.teamId || '', gridIds: [...(x.grids || [])], fields: 'pick',
    picked: Object.fromEntries(Object.entries(x.cells || {}).map(([k, v]) => [k, [...v]])),
    itemIdx: p.items.map((it, i) => (it.id && ids.has(it.id) ? i : -1)).filter((i) => i >= 0),
    meet: false, poiIds: [], rescue: [], hint: '', person: false, contacts: [],
    liveUrl: (p.live && p.live.url) || '',
  };
}

// Auftrag erneut aufbauen: gleiche Auftrags-ID und gleicher Live-Kanal (Schlüssel des Einsatzes); legt nie einen neuen Kanal an
export function rebuildAssignment(p, x) {
  const a = buildAssignment(p, selFromSent(p, x));
  a.id = x.id;
  if (x.at) a.at = x.at;
  if (!x.live) delete a.ls;
  return a;
}

// Teams, die Gebiete haben (Felder oder zugeteilte Umrisse), aber noch keinen Auftrag
// v130.3: ein abgeschlossener (und damit „freier“) Auftrag zählt nicht mehr – sonst verschwindet das Team
// nach Abschluss und Rückmeldung dauerhaft aus dieser Liste, obwohl es wieder einsetzbar ist.
export function teamsWithoutOrder(p) {
  const have = new Set((p.sent || []).filter((x) => !isDone(x)).map((x) => x.teamId));
  const out = [];
  for (const m of p.marks || []) {
    if (m.kind !== 'team' || m.id === NO_TEAM || have.has(m.id)) continue;
    const cells = allGrids(p).reduce((n, g) => n + Object.values(g.fills || {}).filter((id) => id === m.id).length, 0);
    const areas = (p.items || []).filter((it) => it.to === m.id && hasArea(it)).length;
    if (cells || areas) out.push({ team: m, cells, areas });
  }
  return out;
}

// v130.4: Einsatzzeit eines Teams – Auftragszeit (seit „Auftrag angenommen“, x.acc) und Pausenzeit (seit dem letzten
// Abschluss, x.done), dazu Anzahl und Gesamtzeit aller abgeschlossenen Aufträge dieses Teams. Rein aus P.sent
// abgeleitet (nichts extra gespeichert): wird ein Abschluss rückgängig gemacht („↩ Wieder öffnen“ oder die
// schließende Meldung gelöscht und der Auftrag dadurch wieder offen), läuft die Auftragszeit von selbst weiter,
// ohne dass irgendwo ein Zwischenstand aufgeräumt werden müsste. Reset der Uhr passiert also nur, wenn die EL
// einen Auftrag tatsächlich abschließt (x.done, egal ob per QR-Rückmeldung, Link oder automatisch bei 100 %) –
// nicht schon dadurch, dass eine Rückmeldung nur eintrifft.
// state: 'new' (noch nie ein Auftrag) | 'waiting' (Auftrag raus, noch nicht übernommen) | 'active' (unterwegs) | 'pause'
// since: Zeitpunkt (ms), ab dem der jeweilige Zustand gilt – fürs Anzeigen mit hhmm()/sinceText() (wie beim „seit“-Text
// im Auftrag), damit nicht zwei verschiedene Uhren-Formate im Spiel sind
export function teamClock(p, teamId) {
  const mine = (p.sent || []).filter((x) => x.teamId === teamId).sort((a, b) => (a.at || 0) - (b.at || 0));
  const finished = mine.filter(isDone);
  const active = mine.find((x) => !isDone(x) && isAccepted(x));
  const waiting = mine.find((x) => !isDone(x) && !isAccepted(x));
  const totalMs = finished.reduce((s, x) => s + Math.max(0, (x.done || 0) - (x.acc || x.at || 0)), 0);
  const count = finished.length;
  if (active) return { state: 'active', since: active.acc, count, totalMs };
  if (waiting) return { state: 'waiting', since: waiting.at || null, count, totalMs };
  if (finished.length) return { state: 'pause', since: finished[finished.length - 1].done, count, totalMs };
  return { state: 'new', since: null, count: 0, totalMs: 0 };
}

// Was beim Erstellen eines Auftrags dem Team zugeordnet wird: noch nicht zugeteilte Umrisse und (bei „Felder antippen“)
// noch nicht zugeteilte Felder. Anderen Teams Zugeteiltes bleibt (other). canItem/canCell: Sperren des Unterabschnitts.
export function planAssign(p, sel, { canItem = () => true, canCell = () => true } = {}) {
  const plan = { items: [], cells: {}, otherItems: 0, otherCells: 0 };
  if (!sel || !sel.teamId) return plan;
  for (const i of sel.itemIdx || []) {
    const it = p.items[i];
    if (!it || it.resultKey || !hasArea(it)) continue;
    if (!it.to) { if (canItem(it)) plan.items.push(it); } else if (it.to !== sel.teamId) plan.otherItems++;
  }
  if (sel.fields === 'pick') {
    for (const g of allGrids(p)) {
      for (const k of (sel.picked && sel.picked[g.id]) || []) {
        const f = (g.fills || {})[k];
        if (!f || f === NO_TEAM) { if (canCell(g.id, k)) (plan.cells[g.id] = plan.cells[g.id] || []).push(k); } else if (f !== sel.teamId) plan.otherCells++;
      }
    }
  }
  return plan;
}
export const planCount = (plan) => plan.items.length + Object.values(plan.cells).reduce((a, l) => a + l.length, 0);

// Zuordnung ausführen (ändert p) -> Anzahl
export function applyAssign(p, plan, teamId) {
  for (const it of plan.items) it.to = teamId;
  for (const g of allGrids(p)) for (const k of plan.cells[g.id] || []) g.fills[k] = teamId;
  return planCount(plan);
}

// Hinweis für das Auftrags-Fenster
export function assignText(plan, teamLabel, done = false) {
  const pl = (n, one, many) => `${n} ${n === 1 ? one : many}`;
  const mine = [plan.items.length && pl(plan.items.length, 'Umriss', 'Umrisse'), planCount(plan) - plan.items.length && pl(planCount(plan) - plan.items.length, 'Feld', 'Felder')].filter(Boolean);
  const other = [plan.otherItems && pl(plan.otherItems, 'Umriss', 'Umrisse'), plan.otherCells && pl(plan.otherCells, 'Feld', 'Felder')].filter(Boolean);
  return [mine.length && `${done ? `${teamLabel} zugeordnet` : `Wird ${teamLabel} zugeordnet`}: ${mine.join(', ')}.`, other.length && `Schon anderen Teams zugeteilt (bleibt so): ${other.join(', ')}.`].filter(Boolean).join(' ');
}
