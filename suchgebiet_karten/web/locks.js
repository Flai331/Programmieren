// Sperren im Unterabschnitt (UA): Was gehört dem Grund-Einsatz, was dem UA?
// Marke lock an Zeichnungen/Umrissen, Lage-Orten und B-Ort; Rastergebiete: p.glock = { Raster-ID: lock },
// optional p.gown = { Raster-ID: ["c,r" …] } (UA bekam nur einzelne Felder dieses Rasters).
//   'base' – gehört dem Grund-Einsatz: im UA nur ansehen (ausgegraut)
//   'ua'   – dem UA übergeben: bearbeitbar, aber nur der Grund-Einsatz darf es löschen
//   (kein lock) – im UA neu angelegt: frei
// Im Grund-Einsatz selbst (ohne parentEid) gibt es keine Sperren.
export const MSG_VIEW = '🔒 Gehört zum Grund-Einsatz – nur ansehen';
export const MSG_DELETE = '🔒 Nur der Grund-Einsatz kann das löschen';

export const isUA = (p) => !!(p && p.parentEid);
export const lockOf = (p, el) => (isUA(p) && el && (el.lock === 'base' || el.lock === 'ua') ? el.lock : '');

// Raster
export const gridLock = (p, gid) => (isUA(p) && p.glock && (p.glock[gid] === 'base' || p.glock[gid] === 'ua') ? p.glock[gid] : '');
// Feld: 'base' (nicht Teil des UA), 'ua' oder '' (frei)
export function cellLock(p, gid, key) {
  const l = gridLock(p, gid);
  if (l === 'ua' && p.gown && Array.isArray(p.gown[gid]) && !p.gown[gid].includes(key)) return 'base';
  return l;
}

// v101: Spuren des vorherigen Teams (el.prev = Teamname) beim neuen Hundeführer: nur ansehen
export const isPrev = (el) => !!(el && el.prev);
export const msgPrev = (el) => `🔒 Vom vorherigen Team (${el.prev}) – nur ansehen`;

// Bearbeiten (Form, Name, Farbe …) und Löschen für Zeichnung/Lage-Ort/B-Ort
export const canEdit = (p, el) => !isPrev(el) && lockOf(p, el) !== 'base';
export const canDelete = (p, el) => !isPrev(el) && !lockOf(p, el);
export const canEditCell = (p, gid, key) => cellLock(p, gid, key) !== 'base';
export const canEditGrid = (p, gid) => gridLock(p, gid) !== 'base';
export const canDeleteGrid = (p, gid) => !gridLock(p, gid);

// Meldetext, wenn die Aktion nicht erlaubt ist (sonst ''): act = 'edit' | 'delete'
export function denied(p, el, act = 'edit') {
  if (isPrev(el)) return msgPrev(el);
  const l = lockOf(p, el);
  if (l === 'base') return MSG_VIEW;
  return l && act === 'delete' ? MSG_DELETE : '';
}
export function deniedCell(p, gid, key) { return canEditCell(p, gid, key) ? '' : MSG_VIEW; }
export function deniedGrid(p, gid, act = 'edit') {
  const l = gridLock(p, gid);
  if (l === 'base') return MSG_VIEW;
  return l && act === 'delete' ? MSG_DELETE : '';
}

// ---------- v95: Schutz übernommener Aufträge (nur Einsatzleitung) ----------
// P.sent-Eintrag: acc (Zeit der Übernahme, 0 = noch nicht übernommen), items [Item-IDs], cells { Raster-ID: ["c,r" …] },
// unlock (bis wann der Schutz freigegeben ist). Geschützt = übernommen und nicht freigegeben.
export const UNLOCK_MS = 5 * 60e3;
export const isAccepted = (x) => !!x && Number(x.acc) > 0;
// abgeschlossener Auftrag (x.done, v101): kein Schutz mehr, das Gebiet lässt sich neu vergeben
const live = (x, now) => isAccepted(x) && !(Number(x.done) > 0) && !(Number(x.unlock) > now);
// Auftrag, der dieses Item schützt (sonst null)
export const assignedOf = (p, el, now = Date.now()) => (el && el.id ? (p.sent || []).find((x) => live(x, now) && Array.isArray(x.items) && x.items.includes(el.id)) || null : null);
// Auftrag, der dieses Feld schützt
export const assignedCell = (p, gid, key, now = Date.now()) => (p.sent || []).find((x) => live(x, now) && x.cells && Array.isArray(x.cells[gid]) && x.cells[gid].includes(key)) || null;
// Auftrag, der dieses Raster(gebiet) schützt (Felder des Rasters wurden mitgeschickt)
export const assignedGrid = (p, gid, now = Date.now()) => (p.sent || []).find((x) => live(x, now) && x.cells && Array.isArray(x.cells[gid])) || null;
export const unlockUntil = (now = Date.now()) => now + UNLOCK_MS;
// Übernahme erkennen: erste Meldung zu einem Auftrag setzt acc (Zeit der Meldung). Liefert Anzahl neu übernommener.
export function markAccepted(p, msgs, now = Date.now()) {
  let n = 0;
  for (const x of p.sent || []) {
    if (isAccepted(x)) continue;
    const mine = (msgs || []).filter((m) => m && m.a === x.id);
    if (!mine.length) continue;
    x.acc = Math.min(now, ...mine.map((m) => Number(m.t) || now));
    n++;
  }
  return n;
}
