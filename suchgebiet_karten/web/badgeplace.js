// Plaketten der Auftragsgebiete platzieren: immer außerhalb des Gebiets, ohne Markierungen, Lage-Orte oder
// andere Plaketten zu überdecken. Reine Bildschirm-Geometrie (Pixel), damit sie testbar ist.

const GAP = 10; // Abstand zum Gebietsrand
const PAD = 4; // Rand zum Bildschirm

export const boxOf = (x, y, w, h) => ({ x0: x, y0: y, x1: x + w, y1: y + h });
const overlap = (a, b) => Math.max(0, Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0)) * Math.max(0, Math.min(a.y1, b.y1) - Math.max(a.y0, b.y0));

// Kandidaten rund um das Gebiet (oben, unten, rechts, links, Ecken), jeweils auch weiter außen
function candidates(a, w, h) {
  const cx = (a.x0 + a.x1) / 2;
  const cy = (a.y0 + a.y1) / 2;
  const out = [];
  for (let ring = 0; ring < 4; ring++) {
    const d = GAP + ring * (h + 6);
    const dx = GAP + ring * (w / 2 + 6);
    for (const shift of [0, -0.6, 0.6, -1.2, 1.2]) {
      out.push([cx - w / 2 + shift * w, a.y0 - d - h]); // oben
      out.push([cx - w / 2 + shift * w, a.y1 + d]); // unten
    }
    for (const shift of [0, -0.8, 0.8]) {
      out.push([a.x1 + dx, cy - h / 2 + shift * h]); // rechts
      out.push([a.x0 - dx - w, cy - h / 2 + shift * h]); // links
    }
    out.push([a.x1 + dx, a.y0 - d - h], [a.x0 - dx - w, a.y0 - d - h], [a.x1 + dx, a.y1 + d], [a.x0 - dx - w, a.y1 + d]);
  }
  return out;
}

// list: [{ area: {x0,y0,x1,y1}, w, h }] · obstacles: [{x0,y0,x1,y1}] · view: { w, h } · ui: Knöpfe über der Karte
// -> [{ x0, y0, ax, ay }] (Lage der Plakette, Punkt am Gebietsrand für die Verbindungslinie)
export function placeBadges(list, obstacles, view, ui = []) {
  const placed = [];
  const areas = list.map((b) => b.area);
  return list.map((b, i) => {
    const a = b.area;
    let best = null;
    candidates(a, b.w, b.h).forEach(([x, y], k) => {
      // in den sichtbaren Bereich schieben (großes Gebiet / am Rand)
      const cx = Math.min(Math.max(x, PAD), Math.max(PAD, view.w - b.w - PAD));
      const cy = Math.min(Math.max(y, PAD), Math.max(PAD, view.h - b.h - PAD));
      const r = boxOf(cx, cy, b.w, b.h);
      let score = k * 0.5 + Math.hypot(cx - x, cy - y) * 0.2;
      score += overlap(r, a) * 3; // eigenes Gebiet nur, wenn es nicht anders geht
      for (const p of placed) score += overlap(r, p) * 20;
      for (const o of obstacles) score += overlap(r, o) * 8;
      for (const o of ui) score += overlap(r, o) * 25; // unter Knöpfen nicht lesbar
      areas.forEach((q, j) => { if (j !== i) score += overlap(r, q) * 0.5; });
      if (!best || score < best.score) best = { score, r };
    });
    placed.push(best.r);
    const { x0, y0 } = best.r;
    // Punkt am Gebietsrand, der der Plakette am nächsten ist
    const mx = x0 + b.w / 2;
    const my = y0 + b.h / 2;
    const ax = Math.min(Math.max(mx, a.x0), a.x1);
    const ay = Math.min(Math.max(my, a.y0), a.y1);
    return { x0, y0, ax, ay };
  });
}
