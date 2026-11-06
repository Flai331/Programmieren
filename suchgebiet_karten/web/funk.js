// v128: Funkmeldung für ein Team eintragen (Einheit ohne App: Kette, Drohne, Feuerwehr-Trupp) und Fund/Hinweis der Einsatzleitung.
// Beides sind ganz normale Meldungen im Live-Raum (wie eine HF-Meldung), nur mit Quelle „Funk“ (src: 'f') und Gerät (by).
// Reine Logik ohne DOM, testbar.
import { buildMsg, mergeStatus } from './status.js';
import { findKind, FIND_A, msgSource } from './finds.js';
import { unitType, anzeigeText } from './units.js';
import { isDone } from './closeout.js';
import { markAccepted } from './locks.js';
import { normTime } from './mission.js';

// Was sich für ein Team eintragen lässt. s/cat wie bei der HF-Meldung; pos: braucht einen Ort (Karte tippen); pct: Stand in Prozent
export const FUNK_KINDS = [
  { code: 'start', ico: '▶️', label: 'Suche begonnen', s: 'start' },
  { code: 'fertig', ico: '📊', label: 'Stand in Prozent', s: 'fertig', pct: true },
  { code: 'fund', ico: '🟢', label: 'Person gefunden', s: 'ort', cat: 'fund', pos: true },
  { code: 'anzeige', ico: '🐕', label: 'Anzeige', s: 'ort', cat: 'anzeige', pos: true },
  { code: 'hinweis', ico: '👕', label: 'Hinweis', s: 'ort', cat: 'hinweis', pos: true },
  { code: 'gegenstand', ico: '🎒', label: 'Fundstück', s: 'ort', cat: 'gegenstand', pos: true },
  { code: 'hilfe', ico: '🆘', label: 'Brauche Hilfe', s: 'ort', cat: 'hilfe', pos: true },
  { code: 'pause', ico: '⏸', label: 'Pause', s: 'pause' },
  { code: 'abloes', ico: '🔄', label: 'Ablösung', s: 'abloes' },
  { code: 'ende', ico: '⏹', label: 'Suche beendet', s: 'ende' },
  { code: 'zu', ico: '✅', label: 'Abgeschlossen', s: 'zu', pct: true },
  { code: 'zurueck', ico: '🏁', label: 'Zurück am B-Ort', s: 'zurueck' },
];
export const funkKind = (code) => FUNK_KINDS.find((k) => k.code === code) || null;
// Beschriftung je Einheitentyp („Trupp zeigt an“ statt „Anzeige“)
export const funkLabel = (k, ty) => (k.code === 'anzeige' ? anzeigeText(ty) : k.label);

// Uhrzeit „HH:MM“ (oder „930“) von heute -> ms; ungültig null. Liegt sie in der Zukunft (> 5 min), gilt gestern (Einsatz über Mitternacht).
export function timeOfDay(text, now = Date.now()) {
  const hm = normTime(text);
  if (hm === null) return null;
  if (!hm) return now;
  const [h, m] = hm.split(':').map(Number);
  const d = new Date(now);
  d.setHours(h, m, 0, 0);
  let t = d.getTime();
  if (t > now + 5 * 60e3) t -= 24 * 3600e3;
  return t;
}

// Aufträge, für die man eine Funkmeldung eintragen kann: je Team der neueste laufende Auftrag -> [{ x, team }]
export function funkTargets(p) {
  const by = new Map();
  for (const x of p.sent || []) {
    if (isDone(x)) continue;
    const k = x.teamId || `n:${x.team || ''}`;
    const prev = by.get(k);
    if (!prev || (x.at || 0) >= (prev.at || 0)) by.set(k, x);
  }
  return [...by.values()].map((x) => ({ x, team: (p.marks || []).find((m) => m.id === x.teamId) || null }));
}

// Funkmeldung bauen. o: { x (Auftrag), team (Team oder null), kind (Code aus FUNK_KINDS), pc, txt, pos {lat, lon}, t, by }
export function buildFunkMsg(o) {
  const k = funkKind(o.kind);
  if (!k || !o.x) return null;
  const label = o.team ? o.team.label : o.x.team || 'Team';
  return buildMsg({
    a: o.x.id, tm: label, s: k.s, cat: k.cat, txt: o.txt, pc: k.pct && o.pc != null ? Number(o.pc) : undefined,
    pos: k.pos ? o.pos : null, ty: o.team ? unitType(o.team) : undefined, src: 'f', by: o.by || '', t: o.t || Date.now(),
  });
}

// Meldung in den Einsatz eintragen (ändert p): Live-Liste (bzw. QR-Meldungen ohne Status-Server), Auftrag gilt als übernommen.
// -> true, wenn neu
export function addFunkMsg(p, m) {
  if (!m) return false;
  const holder = p.live ? p.live : null;
  const list = holder ? holder.msgs : (p.qmsgs = p.qmsgs || []);
  if (list.some((x) => x.id === m.id)) return false;
  const merged = mergeStatus(list, [m]).slice(-500);
  if (holder) holder.msgs = merged; else p.qmsgs = merged;
  markAccepted(p, [m]);
  p.updated = Date.now();
  return true;
}

export { msgSource };

// ---------- Fund/Hinweis der Einsatzleitung ----------
// o: { art (Code aus FIND_KINDS), txt, pos {lat, lon}, finder (frei: Team/Einheit/Person), teamId, t, by, dringend, foto }
export function buildFindMsg(o) {
  const k = findKind(o.art);
  if (!k || !o.pos) return null;
  const m = buildMsg({
    a: FIND_A, tm: o.finder || 'Einsatzleitung', s: 'ort', cat: k.cat, txt: o.txt, pos: o.pos, fa: o.art, fs: o.geprueft ? 'g' : 'o',
    fb: o.finder || '', dr: o.dringend, ph: o.foto, src: 'f', by: o.by || '', t: o.t || Date.now(),
  });
  return m;
}
