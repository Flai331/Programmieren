// v128: Track-Import mit Auswahlliste (Garmin, Tractive, Drohne …): Name, Länge, Zeit, Team/Auftrag, Kennzeichen Hund/Mensch/Drohne.
// Reine Logik ohne DOM, testbar. Importierte Tracks sind offene Wege (open: true) mit imp: 1; ist dem Team ein Auftrag zugeordnet,
// bekommt der Weg einen resultKey „<Auftrags-ID>|timp…“ und zählt in der Auftrags-Übersicht (km, Zeit) wie eine HF-Rückmeldung.
import { trackLength, formatLength } from './gpx.js';
import { unitType } from './units.js';
import { isDone } from './closeout.js';

export const TRACK_KINDS = [
  { code: 'h', ico: '🐕', label: 'Hund' },
  { code: 'm', ico: '🚶', label: 'Mensch' },
  { code: 'd', ico: '🚁', label: 'Drohne' },
];
const KINDS = Object.fromEntries(TRACK_KINDS.map((k) => [k.code, k]));
export const trackKind = (code) => KINDS[code] || null;
export const DAY_MS = 24 * 3600e3;

const hm = (t) => { const d = new Date(t); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
// 4500000 -> „1 h 15 min“, 600000 -> „10 min“
export function durText(ms) {
  const m = Math.max(0, Math.round(ms / 60000));
  return m < 60 ? `${m} min` : `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')} min`;
}
// „18:05–19:20 (1 h 15 min)“, über Mitternacht/anderer Tag mit Datum; ohne Zeit ''
export function timeText(t0, t1, now = Date.now()) {
  if (!Number.isFinite(t0)) return '';
  const day = (t) => new Date(t).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' });
  const d0 = day(t0) !== day(now) ? `${day(t0)} ` : '';
  if (!Number.isFinite(t1) || t1 === t0) return `${d0}${hm(t0)}`;
  const d1 = day(t1) !== day(t0) ? `${day(t1)} ` : '';
  return `${d0}${hm(t0)}–${d1}${hm(t1)} (${durText(t1 - t0)})`;
}

export const isActiveLog = (name) => /^\s*(ACTIVE\s*LOG|AKTIV(ES|E)?\s*LOG|ACTIVE\b)/i.test(String(name || ''));

// Kennzeichen aus dem Namen („Rex Halsband“, „Hundeführer“, „DJI Drohne“), sonst aus dem Typ des Teams
export function guessKind(name, team) {
  const n = String(name || '');
  if (/drohne|uav|dji|mavic|flug/i.test(n)) return 'd';
  if (/f[üu]e?hrer|handler|mensch|person|fu[ßs]trupp|kette/i.test(n)) return 'm';
  if (/hund|dog|tractive|halsband|collar|\bk9\b/i.test(n)) return 'h';
  const t = unitType(team);
  return t === 'drohne' ? 'd' : t === 'hund' ? 'h' : 'm';
}

// Zeilen für die Auswahlliste. tracks: parseGpx().tracks. pre = vorab angehakt (nicht „ACTIVE LOG“, nicht älter als 24 h).
export function listTracks(tracks, now = Date.now()) {
  return (tracks || []).map((t, i) => {
    const active = isActiveLog(t.name);
    const old = Number.isFinite(t.t1) && now - t.t1 > DAY_MS;
    return {
      i, name: t.name || '', len: trackLength(t.pts), n: t.pts.length, t0: t.t0, t1: t.t1,
      time: timeText(t.t0, t.t1, now), pre: !active && !old, why: active ? 'Aufzeichnung (ACTIVE LOG)' : old ? 'älter als 24 Stunden' : '',
    };
  });
}
export const trackInfo = (row) => [formatLength(row.len), row.time].filter(Boolean).join(' · ');

// Aufträge eines Teams: der neueste laufende, sonst der neueste überhaupt (null ohne Auftrag)
export function orderFor(p, teamId) {
  const mine = (p.sent || []).filter((x) => teamId && x.teamId === teamId);
  const pick = (l) => l.reduce((a, x) => (!a || (x.at || 0) >= (a.at || 0) ? x : a), null);
  return pick(mine.filter((x) => !isDone(x))) || pick(mine);
}

// Importierte Tracks -> Zeichnungen. choices: [{ i, teamId?, kind? }] (nur die angehakten); base = Dateiname ohne Endung
// opts: { color: Standardfarbe, now }
export function importItems(p, tracks, choices, { base = '', color = '#d50000' } = {}) {
  const items = [];
  const orders = new Map();
  for (const c of choices) {
    const t = tracks[c.i];
    if (!t) continue;
    const team = c.teamId ? (p.marks || []).find((m) => m.id === c.teamId && m.kind === 'team') : null;
    const kind = KINDS[c.kind] ? c.kind : guessKind(t.name, team);
    const [a, z] = [t.pts[0], t.pts[t.pts.length - 1]];
    const open = !t.closed && trackLength([a, z]) > 30;
    const it = { kind: 'track', name: t.name || base, color: team ? team.color : t.color || color, w: 4, pts: t.pts, ...(open ? { open: true } : {}), imp: 1, tk: kind };
    if (Number.isFinite(t.t0)) { it.t0 = t.t0; if (Number.isFinite(t.t1)) it.t1 = t.t1; }
    if (team) {
      it.to = team.id;
      const x = orderFor(p, team.id);
      if (x) {
        it.resultKey = `${x.id}|timp${t.t0 || c.i}|${t.pts.length}|${Math.round(t.pts[0][0] * 1e5)},${Math.round(t.pts[0][1] * 1e5)}`;
        orders.set(x.id, x);
      }
    }
    items.push(it);
  }
  return { items, orders: [...orders.values()] };
}

// Summe der Importe zu einem Auftrag: { n, len (m), ms }
export function importTotals(p, x) {
  const its = (p.items || []).filter((it) => it.imp && it.resultKey && String(it.resultKey).startsWith(`${x.id}|`));
  return {
    n: its.length, len: its.reduce((a, it) => a + trackLength(it.pts || []), 0),
    ms: its.reduce((a, it) => a + (Number.isFinite(it.t0) && Number.isFinite(it.t1) ? it.t1 - it.t0 : 0), 0),
  };
}
// Rückmeldung buchen (ändert x): der Auftrag gilt als übernommen, „letzte Rückmeldung“ und Zusammenfassung wie bei der HF-Rückmeldung
export function noteImport(p, x, now = Date.now()) {
  const tot = importTotals(p, x);
  if (!(Number(x.acc) > 0)) x.acc = now;
  x.last = now;
  x.n = (x.n || 0) + 1;
  const km = tot.len / 1000;
  x.lastSum = [km && `${km.toLocaleString('de-DE', { maximumFractionDigits: 1 })} km gelaufen`, tot.ms > 0 && durText(tot.ms), 'Import'].filter(Boolean).join(', ');
  return tot;
}
// Kennzeichnung an der Zeichnung: „🐕 Hund · 18:05–19:20 (1 h 15 min)“ (leer für nicht importierte)
export function importTag(it, now = Date.now()) {
  if (!it || !it.imp) return '';
  const k = KINDS[it.tk];
  return [k ? `${k.ico} ${k.label}` : '', timeText(it.t0, it.t1, now)].filter(Boolean).join(' · ');
}
