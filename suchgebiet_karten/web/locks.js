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

// Bearbeiten (Form, Name, Farbe …) und Löschen für Zeichnung/Lage-Ort/B-Ort
export const canEdit = (p, el) => lockOf(p, el) !== 'base';
export const canDelete = (p, el) => !lockOf(p, el);
export const canEditCell = (p, gid, key) => cellLock(p, gid, key) !== 'base';
export const canEditGrid = (p, gid) => gridLock(p, gid) !== 'base';
export const canDeleteGrid = (p, gid) => !gridLock(p, gid);

// Meldetext, wenn die Aktion nicht erlaubt ist (sonst ''): act = 'edit' | 'delete'
export function denied(p, el, act = 'edit') {
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
