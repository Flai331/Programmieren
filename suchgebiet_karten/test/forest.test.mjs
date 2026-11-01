// v121: Wald erkennen und aufteilen (web/forest.js)
import test, { mock } from 'node:test';
import assert from 'node:assert/strict';
import {
  forestQuery, parseForest, forestInLasso, shares, splitArea, toTracks, makeOrigin, toLL, toXY, mpArea, chainLines, mainAxis, lassoPolygon,
} from '../web/forest.js';
import { polygonArea } from '../web/gpx.js';
import { overpass } from '../web/search.js';

const O = makeOrigin(52, 10);
// Rechteck in Metern (x0,y0)-(x1,y1) -> Ring [lat, lon] (geschlossen)
const rectLL = (x0, y0, x1, y1) => [[x0, y0], [x1, y0], [x1, y1], [x0, y1], [x0, y0]].map((q) => toLL(q, O));
const rectXY = (x0, y0, x1, y1) => [[[[x0, y0], [x1, y0], [x1, y1], [x0, y1], [x0, y0]]]]; // MultiPolygon
const geom = (ring) => ring.map(([lat, lon]) => ({ lat, lon }));
const near = (a, b, relTol, msg) => assert.ok(Math.abs(a - b) <= relTol * b, `${msg || ''} ${a} vs ${b}`);

test('forestQuery: Wald, Wege und Gewässer in einer Abfrage', () => {
  const q = forestQuery({ south: 52, west: 10, north: 52.01, east: 10.02 });
  assert.match(q, /^\[out:json\]\[timeout:25\]/);
  assert.match(q, /"landuse"="forest"/);
  assert.match(q, /"natural"="wood"/);
  assert.match(q, /relation\["landuse"="forest"\]/);
  assert.match(q, /"highway"~"\^\(track\|path/);
  assert.match(q, /"waterway"~"\^\(stream\|river\|ditch\|canal\)\$"/);
  assert.match(q, /\(52\.000000,10\.000000,52\.010000,10\.020000\)/);
  assert.match(q, /out geom;$/);
});

test('parseForest: Way-Wald, Multipolygon aus gestückelten outer-Ways, Linien', () => {
  const sq = rectLL(0, 0, 100, 100);
  const a = sq.slice(0, 3); // Ecke 0,1,2
  const b = sq.slice(2, 5).slice().reverse(); // Rest, umgedreht: Ende -> Anfang
  const json = {
    elements: [
      { type: 'way', tags: { landuse: 'forest' }, geometry: geom(rectLL(0, 0, 500, 500)) },
      { type: 'way', tags: { natural: 'wood' }, geometry: geom(rectLL(0, 0, 10, 10)).slice(0, 3) }, // offen -> verworfen
      { type: 'relation', tags: { type: 'multipolygon', landuse: 'forest' }, members: [
        { type: 'way', role: 'outer', geometry: geom(a) },
        { type: 'way', role: 'outer', geometry: geom(b) },
        { type: 'way', role: 'inner', geometry: geom(rectLL(40, 40, 60, 60)) },
      ] },
      { type: 'relation', tags: { landuse: 'forest' }, members: [{ type: 'way', role: 'outer', geometry: geom(a) }] }, // offen -> verworfen
      { type: 'way', tags: { highway: 'track' }, geometry: geom([[52, 10], [52.001, 10.001]]) },
      { type: 'way', tags: { waterway: 'stream' }, geometry: geom([[52, 10], [52.002, 10.001], [52.003, 10.002]]) },
      { type: 'way', tags: { building: 'yes' }, geometry: geom(sq) },
    ],
  };
  const r = parseForest(json);
  assert.equal(r.forests.length, 2);
  assert.equal(r.lines.length, 2);
  const rel = r.forests[1];
  assert.equal(rel[0][0], rel[rel.length - 1][0]);
  near(polygonArea(rel), 10000, 0.01, 'Fläche des gestückelten Rings');
  assert.deepEqual(parseForest(null), { forests: [], lines: [] });
});

test('forestInLasso: Quadrat 1 x 1 km, halbes Lasso -> ca. 50 ha', () => {
  const forest = rectLL(-500, -500, 500, 500);
  const lasso = rectLL(-600, -600, 0, 600);
  const mp = forestInLasso([forest], lasso, O);
  near(mpArea(mp), 500000, 0.01);
  assert.deepEqual(forestInLasso([forest], rectLL(2000, 2000, 2500, 2500), O), []); // kein Schnitt
  assert.deepEqual(forestInLasso([], lasso, O), []);
});

test('forestInLasso: Lichtung zählt mit, Kleinstteil entfällt, Achter-Lasso wird bereinigt', () => {
  const big = rectLL(0, 0, 1000, 1000);
  const tiny = rectLL(1200, 0, 1240, 40); // 1600 m²
  const mp = forestInLasso([big, tiny], rectLL(-100, -100, 1300, 1100), O);
  assert.equal(mp.length, 1);
  assert.ok(mp[0].length === 1, 'ohne Löcher');
  near(mpArea(mp), 1e6, 0.001);
  // Kleinstteil unter 0,5 %: 0,36 ha neben 100 ha
  const small = rectLL(1200, 0, 1260, 60);
  assert.equal(forestInLasso([big, small], rectLL(-100, -100, 1400, 1100), O).length, 1);
  // Achter: Selbstüberschneidung -> zwei Dreiecke
  const fig8 = [[0, 0], [200, 200], [200, 0], [0, 200], [0, 0]].map((q) => toLL(q, O));
  assert.equal(lassoPolygon(fig8, O).length, 2);
});

test('shares: gleich/gleich/kleiner 50 -> 0.4/0.4/0.2, Fehler bei fehlendem oder falschem Prozentwert', () => {
  const r = shares([{ size: 'gleich' }, { size: 'gleich' }, { size: 'kleiner', pct: 50 }]);
  assert.deepEqual(r.shares.map((x) => Math.round(x * 1000) / 1000), [0.4, 0.4, 0.2]);
  assert.match(shares([{ size: 'gleich' }, { size: 'kleiner', pct: '' }]).error, /Prozentwert fehlt/);
  assert.match(shares([{ size: 'kleiner' }, { size: 'gleich' }]).error, /fehlt/);
  assert.match(shares([{ size: 'kleiner', pct: 100 }, { size: 'gleich' }]).error, /1 bis 99/);
  assert.match(shares([{ size: 'kleiner', pct: 0 }, { size: 'gleich' }]).error, /1 bis 99/);
  assert.match(shares([{ size: 'größer', pct: 99 }, { size: 'gleich' }]).error, /101 bis 400/);
  assert.match(shares([{ size: 'größer', pct: 401 }, { size: 'gleich' }]).error, /101 bis 400/);
  const g = shares([{ size: 'größer', pct: 150 }, { size: 'gleich' }]);
  assert.deepEqual(g.shares.map((x) => Math.round(x * 1000) / 1000), [0.6, 0.4]);
  assert.deepEqual(shares([{ size: 'gleich' }]).shares, [1]);
  assert.ok(shares([]).error);
});

test('splitArea ohne Wege: Rechteck 3 x 1 km, 3 gleich', () => {
  const mp = rectXY(0, 0, 3000, 1000);
  const parts = splitArea(mp, [1 / 3, 1 / 3, 1 / 3], [], { followWays: true });
  assert.equal(parts.length, 3);
  for (const p of parts) { near(p.area, 1e6, 0.01); assert.equal(p.onWay, false); }
  near(parts.reduce((s, p) => s + p.area, 0), 3e6, 0.001);
});

test('splitArea ohne Wege: 2 gleich und 1 kleiner 50 % -> 40/40/20', () => {
  const mp = rectXY(0, 0, 1000, 3000); // Hochformat: Achse läuft in y
  const s = shares([{ size: 'gleich' }, { size: 'gleich' }, { size: 'kleiner', pct: 50 }]).shares;
  const parts = splitArea(mp, s, []);
  [0.4, 0.4, 0.2].forEach((f, i) => near(parts[i].area, f * 3e6, 0.01, `Teil ${i}`));
});

test('splitArea: ein Teil gibt das ganze Gebiet zurück', () => {
  const parts = splitArea(rectXY(0, 0, 500, 500), [1], []);
  assert.equal(parts.length, 1);
  near(parts[0].area, 250000, 0.001);
});

test('splitArea mit Weg: Schnitt folgt dem Weg (onWay), Flächen +-15 %', () => {
  const mp = rectXY(0, 0, 2000, 1000);
  // Weg quer bei x = 1100, leicht schräg, beginnt/endet im Wald kurz vor dem Rand (wird verlängert)
  const way = [[1080, 20], [1100, 500], [1120, 980]];
  const parts = splitArea(mp, [0.5, 0.5], [way], { followWays: true });
  assert.equal(parts.length, 2);
  assert.ok(parts[0].onWay && parts[1].onWay);
  near(parts[0].area, 1e6, 0.15);
  near(parts[1].area, 1e6, 0.15);
  near(parts[0].area + parts[1].area, 2e6, 0.001);
  // Teil 1 reicht bis zum Weg: größte x-Koordinate ca. 1100
  const maxX = Math.max(...parts[0].polys[0].map((q) => q[0]));
  assert.ok(maxX > 1070 && maxX < 1130, `maxX ${maxX}`);
  // ohne followWays: gerade bei 1000
  const straight = splitArea(mp, [0.5, 0.5], [way], { followWays: false });
  assert.equal(straight[0].onWay, false);
  near(straight[0].area, 1e6, 0.01);
});

test('splitArea mit Weg außerhalb der Toleranz: gerader Schnitt', () => {
  const mp = rectXY(0, 0, 2000, 1000);
  const way = [[1600, 0], [1600, 1000]];
  const parts = splitArea(mp, [0.5, 0.5], [way], { followWays: true });
  assert.equal(parts[0].onWay, false);
  near(parts[0].area, 1e6, 0.01);
});

test('splitArea: zwei zusammenstoßende Wegstücke werden verkettet', () => {
  const mp = rectXY(0, 0, 2000, 1000);
  const parts = splitArea(mp, [0.5, 0.5], [[[1000, 0], [1000, 400]], [[1000, 400], [1000, 1000]]], { followWays: true });
  assert.ok(parts[0].onWay);
  near(parts[0].area, 1e6, 0.02);
  assert.equal(chainLines([[[0, 0], [1, 0]], [[1, 0], [2, 0]]]).length, 1);
  assert.equal(chainLines([[[0, 0], [1, 0]], [[1, 0], [2, 0]], [[1, 0], [1, 5]]]).length, 3); // Kreuzung: nicht verketten
});

test('splitArea: Wald aus zwei getrennten Stücken, 2 Teile', () => {
  const mp = [rectXY(0, 0, 1000, 1000)[0], rectXY(1500, 0, 2500, 1000)[0]];
  const parts = splitArea(mp, [0.5, 0.5], []);
  near(parts[0].area, 1e6, 0.01);
  near(parts[1].area, 1e6, 0.01);
});

test('mainAxis: längere Seite', () => {
  const [ux, uy] = mainAxis(rectXY(0, 0, 100, 1000));
  assert.ok(Math.abs(uy) > 0.99 && Math.abs(ux) < 0.05);
});

test('toTracks: Namen, Teams, Rundung, höchstens 400 Punkte', () => {
  const mp = rectXY(0, 0, 3000, 1000);
  const parts = splitArea(mp, [0.5, 0.5], []);
  const tr = toTracks(parts, ['Nord A', 'Nord B'], ['t1', ''], O);
  assert.equal(tr.length, 2);
  assert.equal(tr[0].name, 'Nord A');
  assert.equal(tr[0].to, 't1');
  assert.equal(tr[1].to, undefined);
  for (const t of tr) {
    assert.ok(t.pts.length >= 3 && t.pts.length <= 400);
    for (const [la, lo] of t.pts) assert.equal(la, Math.round(la * 1e6) / 1e6, lo);
    assert.notDeepEqual(t.pts[0], t.pts[t.pts.length - 1]); // nicht geschlossen gespeichert
  }
  near(polygonArea(tr[0].pts), 1.5e6, 0.01);
  // Kreis mit vielen Punkten wird ausgedünnt
  const circle = Array.from({ length: 3000 }, (_, i) => [Math.cos(i / 3000 * 2 * Math.PI) * 800, Math.sin(i / 3000 * 2 * Math.PI) * 800]);
  circle.push(circle[0]);
  const t2 = toTracks([{ polys: [circle], area: 1, onWay: false }], ['Kreis'], [], O);
  assert.ok(t2[0].pts.length <= 400 && t2[0].pts.length > 30);
  // mehrere Stücke: „(2)“
  const two = toTracks([{ polys: [rectXY(0, 0, 100, 100)[0][0], rectXY(500, 0, 700, 200)[0][0]], area: 1, onWay: false }], ['X'], ['t9'], O);
  assert.equal(two.length, 2);
  assert.equal(two[0].name, 'X');
  assert.equal(two[1].to, 't9');
  assert.deepEqual(toXY(toLL([12, 34], O), O).map(Math.round), [12, 34]);
});

test('overpass: Fehlertext trägt den Namen der Suche', async () => {
  const old = globalThis.fetch;
  mock.timers.enable({ apis: ['setTimeout'] }); // fetchT lässt sonst 30 s Zeitgeber laufen
  globalThis.fetch = async () => ({ ok: false, status: 429 });
  try {
    await assert.rejects(overpass('x', undefined, 'Waldsuche'), /Waldsuche gerade überlastet/);
    await assert.rejects(overpass('x'), /Kreuzungssuche gerade überlastet/);
  } finally { globalThis.fetch = old; mock.timers.reset(); }
});
