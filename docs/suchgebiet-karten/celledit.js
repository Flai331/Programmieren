// v108: Ausgeblendetes lässt sich nicht verändern – reine Logik ohne DOM (testbar).
// Raster ausgeblendet (P.hide.grid): auf dem Raster tut ein Tipp nichts.
// Markierung ausgeblendet (m.hidden): ihre Ebene (Team = fills, Status = status) bleibt unberührt.
// fillMark/statusMark: Markierungen, die das Feld gerade belegen (oder null).

// Welche Ebenen eines Feldes darf ein Tipp/Wisch ändern? { team, status }
export function cellLayers({ hideGrid, fillMark, statusMark }) {
  if (hideGrid) return { team: false, status: false };
  return { team: !(fillMark && fillMark.hidden), status: !(statusMark && statusMark.hidden) };
}

// Ist am Feld überhaupt etwas veränderbar? Leeres Feld: ja. Belegtes Feld: nur, wenn mindestens eine
// belegende Markierung sichtbar ist (nur über Ausgeblendetes belegt = unberührbar).
export function cellEditable(o) {
  if (o.hideGrid) return false;
  const on = [o.fillMark, o.statusMark].filter(Boolean);
  return !on.length || on.some((m) => !m.hidden);
}

// Darf die aktive Markierung ein Feld bemalen? Weder Raster noch die Markierung selbst ausgeblendet,
// das Feld ist veränderbar, und die Ebene, in die sie schreibt, ist nicht von einer ausgeblendeten Markierung belegt.
export function canPaint({ hideGrid, mark, fillMark, statusMark }) {
  if (!mark || mark.hidden || !cellEditable({ hideGrid, fillMark, statusMark })) return false;
  const l = cellLayers({ hideGrid, fillMark, statusMark });
  return mark.kind === 'team' ? l.team : l.status;
}
