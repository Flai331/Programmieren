// v108: Punkte eines Umrisses bearbeiten – reine Logik ohne Karte/DOM (testbar).
// Ein Umriss ist { pts: [[lat, lon], …], open? }. Geschlossene Umrisse speichern den ersten Punkt normalerweise
// nicht am Ende noch einmal; Importe (GPX) können das aber tun – dann bewegen beide Punkte gemeinsam.

const same = (a, b) => a[0] === b[0] && a[1] === b[1];

// Endet ein geschlossener Umriss mit einer Kopie des ersten Punkts?
export function dupEnd(pts, open) {
  return !open && pts.length > 3 && same(pts[0], pts[pts.length - 1]);
}

// Anzahl echter (sichtbarer) Eckpunkte
export function vertexCount(pts, open) {
  return pts.length - (dupEnd(pts, open) ? 1 : 0);
}

export const minPoints = (open) => (open ? 2 : 3);

// Punkt i auf neue Lage setzen; ein doppelter Schlusspunkt zieht mit
export function moveVertex(pts, i, lat, lon, open) {
  const dup = dupEnd(pts, open);
  pts[i] = [lat, lon];
  if (dup && i === 0) pts[pts.length - 1] = [lat, lon];
  return pts;
}

// Punkt i löschen. Rückgabe: false, wenn zu wenige Punkte blieben (pts bleibt dann unverändert).
export function removeVertex(pts, i, open) {
  const dup = dupEnd(pts, open);
  if (vertexCount(pts, open) <= minPoints(open) || i < 0 || i >= vertexCount(pts, open)) return false;
  pts.splice(i, 1);
  if (dup) { if (i === 0) pts[pts.length - 1] = [...pts[0]]; }
  return true;
}

// Punkt hinter Index i einfügen (Mitte einer Kante). Rückgabe: Index des neuen Punkts.
export function insertVertex(pts, i, lat, lon) {
  pts.splice(i + 1, 0, [lat, lon]);
  return i + 1;
}

// Kanten, auf deren Mitte ein Anfasser sitzt: { i, lat, lon } = Kante von Punkt i zum nächsten.
// Offene Linien: keine Kante vom letzten zum ersten Punkt.
export function edgeMids(pts, open) {
  const n = vertexCount(pts, open);
  const out = [];
  const last = open ? n - 1 : n;
  for (let i = 0; i < last; i++) {
    const a = pts[i], b = pts[(i + 1) % pts.length];
    out.push({ i, lat: (a[0] + b[0]) / 2, lon: (a[1] + b[1]) / 2 });
  }
  return out;
}
