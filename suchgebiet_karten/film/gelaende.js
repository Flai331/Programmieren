// Holt das Gelände für den 3D-Film aus der App: Kartenbild (ohne Bedienelemente) und Raster/Orte als Bildpunkte.
// Ergebnis: gelaende.jpg und gelaende.json (alle Koordinaten in Bildpunkten des Kartenbilds, 1 px ≈ 1,45 m)
const fs = require('fs');
const { chromium } = require('playwright');
const FOREST = [52.6695, 10.1035], BORT_VIEW = [52.6745, 10.0835];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  const b = await chromium.launch();
  const open = async (w, h) => {
    const ctx = await b.newContext({ viewport: { width: w, height: h }, locale: 'de-DE', timezoneId: 'Europe/Berlin' });
    const p = await ctx.newPage();
    await p.route(/script\.google\.com|overpass/, (r) => r.abort());
    await p.goto('http://localhost:8765/');
    await sleep(1500);
    await p.click('text=Einsatzleitung'); await p.click('#wz-exit');
    await p.evaluate(([a, c]) => window.__app.map.setView([a, c], 16, { animate: false }), FOREST);
    await sleep(800);
    const rect = await p.evaluate(() => { const r = window.__app.map.getContainer().getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height }; });
    return { p, rect };
  };
  // Aufnahme-Seite (1600×900): Versatz der Seitenpunkte zur Kartenmitte
  const small = await open(1600, 900);
  const cS = [small.rect.x + small.rect.w / 2, small.rect.y + small.rect.h / 2];
  const big = await open(3400, 2100);
  const p = big.p, R = big.rect;
  const c = [R.w / 2, R.h / 2];
  const o = (x, y) => [x + 160, y + 90];
  const P = ([x, y]) => [c[0] + (x - cS[0]), c[1] + (y - cS[1])]; // Seitenpunkt der Aufnahme -> Bildpunkt im großen Kartenbild
  const px = (ll) => p.evaluate(([a, d]) => { const q = window.__app.map.latLngToContainerPoint([a, d]); return [q.x, q.y]; }, ll);
  // Raster wie im Film aufziehen und auslesen
  await p.click('#btn-grid'); await p.click('#grid-draw'); await sleep(300);
  const g0 = P(o(335, 155)), g1 = P(o(895, 515));
  await p.mouse.move(R.x + g0[0], R.y + g0[1]); await p.mouse.down();
  for (let k = 1; k <= 20; k++) { await p.mouse.move(R.x + g0[0] + (g1[0] - g0[0]) * k / 20, R.y + g0[1] + (g1[1] - g0[1]) * k / 20); await sleep(15); }
  await p.mouse.up(); await sleep(800);
  const area = await p.evaluate(() => ({ ...window.__app.P.area, cellM: window.__app.P.cellM }));
  const nw = await px([area.north, area.west]), se = await px([area.south, area.east]);
  const mPerPx = 156543.03392 * Math.cos(FOREST[0] * Math.PI / 180) / 2 ** 16;
  const cell = area.cellM / mPerPx;
  const grid = { x0: nw[0], y0: nw[1], x1: se[0], y1: se[1], cell, cols: Math.round((se[0] - nw[0]) / cell), rows: Math.round((se[1] - nw[1]) / cell) };
  await p.click('#grid-remove').catch(() => {});
  // Orte
  const bv = await px(BORT_VIEW);
  const bort = [bv[0] + (o(560, 380)[0] - cS[0]), bv[1] + (o(560, 380)[1] - cS[1])];
  const snake = (x0, x1, ys, n = 10) => { const out = []; ys.forEach((y, i) => { const a = i % 2 ? x1 : x0, d = i % 2 ? x0 : x1; for (let k = 0; k <= n; k++) out.push(P(o(a + (d - a) * k / n + Math.sin(k * 1.7 + i) * 7, y + Math.cos(k * 1.3 + i) * 6))); }); return out; };
  const ring = []; for (let k = 0; k <= 40; k++) { const a = k / 40 * Math.PI * 2 * 1.6; const rr = 40 + k * 1.2; ring.push(P(o(1085 + Math.cos(a) * rr, 245 + Math.sin(a) * rr * 0.8))); }
  const data = {
    w: R.w, h: R.h, mPerPx, grid, bort,
    teams: { Anna: { color: '#d50000', cells: [0, 2, 0, 2] }, Jonas: { color: '#1565c0', cells: [3, 5, 0, 2] }, Drohne: { color: '#00838f', cells: [6, 7, 0, 2] }, FF: { color: '#6a1b9a', cells: [0, 7, 3, 4] }, Mia: { color: '#ef6c00' } },
    walkAnna: snake(362, 505, [168, 198, 228, 258, 288, 318, 345]), walkJonas: snake(572, 715, [170, 205, 240, 275, 310, 345]), walkMia: ring, walkMia2: snake(900, 1030, [470, 500, 530], 6),
    see: [[985, 160], [1110, 115], [1185, 230], [1150, 360], [1010, 345]].map(([x, y]) => P(o(x, y))),
    bahndamm: [[880, 470], [1010, 430], [1060, 500], [940, 560]].map(([x, y]) => P(o(x, y))),
    schilf: P(o(1045, 260)), heat: P(o(470, 385)), cap: P(o(640, 430)), hut: P(o(650, 300)), toHeat: [o(380, 345), o(420, 362), o(450, 375), o(470, 385)].map(P),
  };
  // Kartenbild ohne Bedienelemente
  await p.evaluate(() => document.querySelectorAll('.panel:not([hidden]) .close').forEach((x) => x.click()));
  await p.click('[data-tool=pan]').catch(() => {});
  await p.addStyleTag({ content: 'body > *:not(#map){visibility:hidden!important} .leaflet-control-container,.leaflet-overlay-pane,.leaflet-marker-pane,.leaflet-tooltip-pane,#map canvas{visibility:hidden!important}' });
  await sleep(6000);
  await p.screenshot({ path: 'gelaende.jpg', type: 'jpeg', quality: 92, clip: { x: R.x, y: R.y, width: R.w, height: R.h } });
  fs.writeFileSync('gelaende.json', JSON.stringify(data));
  console.log(JSON.stringify({ rect: R, small: small.rect, grid, bort }));
  await b.close();
})().catch((e) => { console.error(e); process.exit(1); });
