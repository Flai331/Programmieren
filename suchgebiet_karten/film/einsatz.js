// Drehbuch „Einsatz Scheuen“ – ein erfundener Einsatz von der Alarmierung bis zum Bericht, nachgestellt mit RHS Einsatz.
// Alle Personen, Zeiten und Abläufe sind frei erfunden.
// Start: REC_DIR=rec-einsatz node einsatz.js  ·  Schnitt: REC_DIR=rec-einsatz BUILD_DIR=build-einsatz OUT_NAME=RHS-Einsatz-Scheuen.mp4 node compose.js
const fs = require('fs');
const { Rec, sleep, dual, card, saveOrder, storyStart, storyNow, advance } = require('./lib');

const LIVE = 'https://flai331.github.io/Programmieren/suchgebiet-karten/';
const LOCAL = 'http://localhost:8765/';
const STOP = process.env.STOP || '';
const shots = !!process.env.SHOTS;
const ORIGIN = 'http://localhost:8765';

const FOREST = [52.6695, 10.1035];
const BORT_VIEW = [52.6745, 10.0835];
const o = (x, y) => [x + 160, y + 90]; // Punkte für 1280×720 ermittelt, Karte jetzt 1600×900
const O = (pts) => pts.map(([x, y]) => o(x, y));
const DAY = '2026-11-07';

// Film-GPS für Handys: Positionen nur aus dem Drehbuch
const GEO = `(() => {
  const G = window.__geo = { w: new Map(), id: 0, pos: null };
  const mk = (lat, lon) => ({ coords: { latitude: lat, longitude: lon, accuracy: 5, altitude: null, altitudeAccuracy: null, heading: null, speed: null }, timestamp: Date.now() });
  G.pos = mk(52.6741, 10.0832);
  window.__setPos = (lat, lon) => { G.pos = mk(lat, lon); G.w.forEach((ok) => { try { ok(G.pos); } catch (e) {} }); };
  const P = Geolocation.prototype;
  P.watchPosition = function (ok) { const id = ++G.id; G.w.set(id, ok); setTimeout(() => G.pos && ok(G.pos), 60); return id; };
  P.clearWatch = function (id) { G.w.delete(id); };
  P.getCurrentPosition = function (ok) { setTimeout(() => ok(G.pos), 60); };
})();`;

(async () => {
  storyStart(new Date(`${DAY}T15:10:00+01:00`));
  const recs = [];
  const at = async (hhmm) => { const d = (Date.parse(`${DAY}T${hhmm}:00+01:00`) - storyNow()) / 60000; if (d > 0) await advance(d, recs); };

  const el = new Rec('el');
  recs.push(el);
  const p = await el.start(LOCAL);
  // Wetter: Messzeit auf die Filmzeit stellen (sonst stünde dort die echte Uhrzeit)
  await p.route(/api\.brightsky\.dev\/current_weather/, async (route) => {
    try {
      const r = await route.fetch();
      const j = await r.json();
      const t = new Date(Math.floor(storyNow() / 1800000) * 1800000);
      const iso = new Date(t.getTime() + 3600000).toISOString().replace('Z', '+01:00').replace(/\.\d{3}/, '');
      if (j.weather) j.weather.timestamp = iso;
      for (const s of j.sources || []) s.last_record = iso;
      await route.fulfill({ response: r, json: j });
    } catch { await route.continue(); }
  });
  await el.ctx.grantPermissions(['clipboard-read', 'clipboard-write', 'geolocation'], { origin: ORIGIN });
  await el.ctx.setGeolocation({ latitude: 52.6741, longitude: 10.0832, accuracy: 8 });
  await sleep(2500);
  const snap = async (n) => { if (shots) await el.shot(`chk_${n}.png`); };
  const map = (fn, arg) => p.evaluate(fn, arg);
  const closePanels = () => p.evaluate(() => document.querySelectorAll('.panel:not([hidden]) .close').forEach((b) => b.click()));
  const pickBtn = (pg, re) => pg.evaluate((re) => { const b = [...document.querySelectorAll('#dlg-box button')].find((x) => new RegExp(re).test(x.textContent)); if (b && !document.getElementById('dlg').hidden) { b.click(); return true; } return false; }, re).catch(() => false);
  const poll = (pg) => pg.evaluate(() => window.dispatchEvent(new Event('online'))).catch(() => {});

  card('intro', { style: 'intro', sub: 'Ein Einsatz von der Alarmierung bis zum Bericht', sub2: 'Nachgestellt – Personen und Ablauf frei erfunden' });
  card('alarm', { style: 'alarm', time: '15:10', head: 'Vermisste Person – Rettungshundestaffel', lines: ['Heinz K., 81 Jahre, dement, mit Gehstock', 'Seit 13:30 aus dem Seniorenheim in Scheuen (Celle) abgängig', 'Zuletzt gesehen am Waldweg Richtung Norden', 'Treffpunkt: Ortsrand Scheuen'], note: 'Fiktive Alarmierung für diesen Film' });

  // ================= 15:24 Ankunft: Einsatz anlegen =================
  await at('15:24');
  card('t1', { style: 'time', num: '15:24', title: 'Ankunft am Einsatzort', sub: 'Die Einsatzleitung legt den Einsatz an' });
  await el.seg('start', { t: 'Einsatzleitung am Tablet', s: 'Neuer Einsatz in wenigen Schritten: Name, B-Ort, Wetter, vermisste Person.', speed: 1.3 });
  await el.pause(800);
  await el.tap('text=Einsatzleitung', { wait: 700 });
  await el.type('#wz-body input', 'Vermisste Person Scheuen', { delay: 45 });
  await el.tap('#wz-next', { wait: 500 });
  await el.type('#wz-body input >> nth=0', 'Klaas Otte', { delay: 45 });
  await el.tap('#wz-next', { wait: 500 });
  await el.seg('bort', { t: 'B-Ort am Ortsrand', s: 'Adresse suchen, Treffer wählen, den genauen Treffpunkt antippen.', speed: 1.3 });
  await el.tap('text=Adresse oder Kreuzung suchen', { wait: 400 });
  await p.keyboard.type('Scheuen, Celle', { delay: 80 });
  await sleep(1700);
  await el.tap('#search-results button >> nth=0', { wait: 1500 });
  await map(([a, b]) => window.__app.map.flyTo([a, b], 16, { duration: 1.1 }), BORT_VIEW);
  await sleep(2000);
  await el.tap(o(560, 380), { wait: 1300 });
  await snap('bort');
  await el.seg('wx', { t: 'Wind und Licht', s: 'DWD-Wetter am B-Ort: Ansatz gegen den Wind – und wie lange es noch hell ist.' });
  await el.pause(2600);
  await el.tap('#wz-next', { wait: 400 });
  await el.type('#wz-body textarea, #wz-body input >> nth=0', 'Heinz K., 81 J., 1,75 m, dunkelgrüne Jacke, graue Mütze, Gehstock, dement', { delay: 18 });
  await el.tap('#wz-next', { wait: 400 });
  await el.tap('text=Jetzt >> nth=0', { wait: 300 });
  await el.tap('#wz-next', { wait: 300 });
  await el.tap('#wz-next', { wait: 500 });
  await el.tap('text=Raster aufziehen', { wait: 300 });
  await el.endSeg();
  if (STOP === '1') return done();

  // ================= 15:31 Lage und Planung =================
  await at('15:31');
  card('t2', { style: 'time', num: '15:31', title: 'Planung', sub: 'Suchgebiete einteilen, fünf Einheiten zuteilen' });
  await map(([a, b]) => window.__app.map.setView([a, b], 16, { animate: false }), FOREST);
  await sleep(2500);
  await el.seg('grid', { t: 'Raster über den Wald', s: 'Nördlich des Ortes, entlang des Bachs – dort wurde Herr K. zuletzt gesehen.', speed: 1.2 });
  await el.pause(500);
  await el.drag(O([[335, 155], [610, 330], [895, 515]]), { ms: 1400, wait: 1000 });
  await el.tap('button:visible:has-text("Fertig")', { wait: 500 });

  await el.seg('teams', { t: 'Fünf Einheiten', s: 'Drei Hundeteams, ein Fußtrupp der Feuerwehr und eine Drohne – mit Funkrufname und Personen.', speed: 1.8 });
  await el.tap('#btn-teams', { wait: 500 });
  const TEAMS = [
    { n: 'Anna', d: 'Rex', org: 'JUH', p: '2' },
    { n: 'Jonas', d: 'Luna', org: 'JUH', p: '2' },
    { n: 'Mia', d: 'Balu', org: 'DRK', p: '2' },
    { n: 'FF Scheuen', ty: 'kette', org: 'FF', p: '8', fk: 'Florian Scheuen 1' },
    { n: 'Drohne', ty: 'drohne', org: 'THW', p: '2', fk: 'Heros 1' },
  ];
  for (const [i, t] of TEAMS.entries()) {
    await el.tap('#team-add', { wait: 250 });
    const L = (c) => p.locator(`#mark-list ${c}`).last();
    await L('.name').fill('');
    await L('.name').pressSequentially(t.n, { delay: i ? 25 : 70 });
    if (t.ty) { await L('.uty').selectOption(t.ty); await sleep(250); }
    await L('.uorg').fill(t.org); await L('.uorg').dispatchEvent('change');
    await L('.upers').fill(t.p); await L('.upers').dispatchEvent('change');
    if (t.fk) { await L('.ufk').fill(t.fk); await L('.ufk').dispatchEvent('change'); }
    if (t.d) { await L('.dog').fill(t.d); await L('.dog').dispatchEvent('change'); }
    await sleep(i ? 150 : 500);
  }
  await sleep(600);
  await snap('teams');
  await closePanels();
  await sleep(300);

  await el.seg('fill', { t: 'Gebiete zuteilen', s: 'Felder mit dem Finger wischen, das Gebiet am See als Umriss – jede Einheit in ihrer Farbe.', speed: 1.7 });
  await el.tap('[data-tool=fill]', { wait: 400 });
  const swipe = async (team, x0, x1, ys) => {
    await el.tap(`#fillbar button:has-text("${team}"), button:visible:has-text("${team}")`, { wait: 300 });
    const pts = [];
    ys.forEach((y, i) => { if (i % 2) pts.push([x1, y], [x0, y]); else pts.push([x0, y], [x1, y]); });
    await el.drag(O(pts), { ms: 260 * pts.length, wait: 300 });
  };
  await swipe('Anna', 365, 505, [190, 255, 325]);
  await swipe('Jonas', 575, 715, [190, 255, 325]);
  await swipe('FF Scheuen', 365, 855, [395, 465]);
  await swipe('Drohne', 785, 855, [190, 255, 325]);
  await el.tap('[data-tool=track]', { wait: 400 });
  for (const pt of O([[985, 160], [1110, 115], [1185, 230], [1150, 360], [1010, 345]])) await el.tap(pt, { wait: 250, ms: 380 });
  await el.tap('#track-done', { wait: 600 });
  await el.type('#dlg-box input[type=text]', 'See', { delay: 60 });
  await p.locator('#dlg-box select').selectOption({ label: '🐕 Mia (Balu)' }).catch(async () => {
    const opts = await p.locator('#dlg-box select option').allTextContents();
    await p.locator('#dlg-box select').selectOption({ index: opts.findIndex((x) => x.includes('Mia')) });
  });
  await el.tap('#dlg-box button:has-text("Speichern")', { wait: 900 });
  await el.tap('[data-tool=pan]', { wait: 600 });
  await snap('fill');
  await el.endSeg();
  if (STOP === '2') return done();

  // ================= 15:42 Aufträge =================
  await at('15:42');
  card('t3', { style: 'time', num: '15:42', title: 'Aufträge raus', sub: 'Jedes Team bekommt seinen Auftrag als QR-Code' });
  const links = {};
  const order = async (idx, visible) => {
    await p.selectOption('#send-team', { index: idx });
    await sleep(300);
    if (visible) await el.tap('#send-qr', { wait: 1800 }); else { await p.click('#send-qr'); await sleep(500); }
    await p.click('#qr-copy'); await sleep(200);
    const l = (await p.evaluate(() => navigator.clipboard.readText())).replace(LIVE, LOCAL);
    if (visible) await el.tap('#qr-close', { wait: 400 }); else { await p.click('#qr-close'); await sleep(250); }
    return l;
  };
  await el.seg('qr', { t: 'Auftrag per QR-Code', s: 'Gebiet, B-Ort, Rettungspunkte, Hinweis und Kontakte – der Hundeführer scannt, fertig.', speed: 1.3 });
  await el.tap('#btn-teams', { wait: 500 });
  await el.tap('#send-open', { wait: 800 });
  await el.type('#panel-send textarea', 'Achtung Bahnlinie im Süden. Person evtl. desorientiert, Gehstock.', { delay: 20 });
  links.anna = await order(0, true);
  await snap('qr');
  await el.endSeg();
  links.jonas = await order(1, false);
  links.mia = await order(2, false);
  links.ff = await order(3, false);
  links.drohne = await order(4, false);
  await closePanels();
  fs.writeFileSync('links-einsatz.json', JSON.stringify(links));

  // Handys: Anna (sichtbar), Jonas und Mia (im Hintergrund)
  const mkHf = async (name, link, show) => {
    const r = new Rec(name, { width: 454, height: 982, scale: 1, mobile: true });
    const pg = await r.start(show ? 'about:blank' : link, GEO);
    await r.ctx.grantPermissions(['clipboard-read', 'clipboard-write', 'geolocation'], { origin: ORIGIN });
    recs.push(r);
    return r;
  };
  const anna = await mkHf('anna', links.anna, true);
  const jonas = await mkHf('jonas', links.jonas, false);
  const mia = await mkHf('mia', links.mia, false);
  const A = anna.page, J = jonas.page, M = mia.page;
  const setPos = (pg, ll) => pg.evaluate(([a, b]) => window.__setPos && window.__setPos(a, b), ll).catch(() => {});
  const hsnap = async (n) => { if (shots) await anna.shot(`chk_hf_${n}.png`); };
  await sleep(2500);

  // Wege (Seitenpunkte -> Koordinaten über die EL-Karte)
  await map(([a, b]) => window.__app.map.setView([a, b], 16, { animate: false }), FOREST);
  await sleep(400);
  const toLL = (pts) => p.evaluate((pts) => { const m = window.__app.map; const r = m.getContainer().getBoundingClientRect(); return pts.map(([x, y]) => { const ll = m.containerPointToLatLng([x - r.left, y - r.top]); return [ll.lat, ll.lng]; }); }, pts);
  const snake = (x0, x1, ys, n = 10) => { const out = []; ys.forEach((y, i) => { const a = i % 2 ? x1 : x0, b = i % 2 ? x0 : x1; for (let k = 0; k <= n; k++) out.push(o(a + (b - a) * k / n + Math.sin(k * 1.7 + i) * 7, y + Math.cos(k * 1.3 + i) * 6)); }); return out; };
  const walkAnna = await toLL(snake(362, 505, [168, 198, 228, 258, 288, 318, 345]));
  const walkJonas = await toLL(snake(572, 715, [170, 205, 240, 275, 310, 345]));
  const ring = []; for (let k = 0; k <= 40; k++) { const a = k / 40 * Math.PI * 2 * 1.6; const rr = 40 + k * 1.2; ring.push(o(1085 + Math.cos(a) * rr, 245 + Math.sin(a) * rr * 0.8)); }
  const walkMia = await toLL(ring);
  const HEAT = o(470, 385); // Wärmequelle / Fundort (C4, am Bahndamm)
  const CAP = o(640, 430); // Mütze (E4/E5)
  const toHeat = await toLL([o(380, 345), o(420, 362), o(450, 375), HEAT]);
  const walker = (pg, pts, ms) => (async () => { for (const ll of pts) { await setPos(pg, ll); await sleep(ms); } })();

  await setPos(A, walkAnna[0]); await setPos(J, walkJonas[0]); await setPos(M, walkMia[0]);
  await anna.seg('open', { t: 'Anna und Rex übernehmen', s: 'Der Auftrag öffnet sich auf dem Handy – Gebiet, Hinweis, B-Ort, Kontakte. Auch ohne Netz nutzbar.' });
  await A.goto(links.anna);
  await sleep(2600);
  await anna.tap('#hfi-area', { wait: 1400 });
  await hsnap('open');
  await anna.seg('start', { t: '„Suche begonnen“', s: 'Ein Tipp – die Meldung geht live und verschlüsselt an die Einsatzleitung. Dann läuft der GPS-Weg mit.' });
  await anna.tap('#hf-status', { wait: 700 });
  await anna.tap('button:visible:has-text("Suche begonnen")', { wait: 1000 });
  await anna.tap('#hf-rec', { wait: 800 });
  await anna.endSeg();
  // die anderen beiden starten ebenfalls
  for (const pg of [J, M]) { await pg.click('#hf-status'); await sleep(400); await pg.click('button:visible:has-text("Suche begonnen")'); await sleep(500); await pg.click('#hf-rec'); await sleep(400); }
  if (STOP === '3') return done();

  // ================= 15:50 Die Suche läuft =================
  await at('15:50');
  // Feuerwehr und Drohne melden per Funk – die EL trägt es ein
  const funk = async (team, kind, visible) => {
    if (await p.locator('#dlg').isVisible().catch(() => false)) {
      console.log('EL-Fenster offen:', (await p.locator('#dlg-box').innerText().catch(() => '')).slice(0, 80).replace(/\n/g, ' | '));
      await pickBtn(p, 'Noch offen|Später|Gesehen|Schließen|Abbrechen');
      await sleep(300);
    }
    if (!(await p.locator('#st-funk').isVisible())) { await p.click('#btn-status'); await sleep(600); }
    if (visible) await el.tap('#st-funk', { wait: 700 }); else { await p.click('#st-funk'); await sleep(400); }
    const sel = p.locator('#funk-team');
    const opts = await sel.locator('option').allTextContents();
    await sel.selectOption({ index: opts.findIndex((x) => x.includes(team)) });
    await sleep(200);
    const b = p.locator(`#funk-kinds button:has-text("${kind}")`);
    if (visible) await el.tap(b, { wait: 500 }); else { await b.click(); await sleep(200); }
    const go = p.locator('#dlg-box button.primary');
    if (visible) await el.tap(go, { wait: 900 }); else { await go.click(); await sleep(400); }
  };
  await poll(p); await sleep(2500); await poll(p); await sleep(1200);
  card('t4', { style: 'time', num: '15:50', title: 'Die Suche läuft', sub: 'Alle Einheiten sind im Gelände' });
  await el.seg('chips', { t: 'Wer sucht wo?', s: 'Jede Einheit oben als Status-Chip: Gebiet, letzte Meldung, Uhrzeit.' });
  await el.pause(2200);
  await snap('chips');
  await el.tap('#btn-status', { wait: 900 });
  await el.seg('funk', { t: 'Funkmeldung eintragen', s: 'Einheiten ohne App – Feuerwehr, Drohne – meldet die Einsatzleitung selbst: zählt wie eine Meldung aus der App.', speed: 1.3 });
  await funk('FF Scheuen', 'Suche begonnen', true);
  await snap('funk');
  await funk('Drohne', 'Suche begonnen', false);
  await closePanels();
  await el.pause(900);
  await el.endSeg();

  // im Hintergrund suchen alle drei
  let w1 = walker(A, walkAnna.slice(0, 30), 160), w2 = walker(J, walkJonas.slice(0, 26), 170), w3 = walker(M, walkMia.slice(0, 18), 220);
  await anna.seg('walk', { t: 'Rex sucht – der Weg läuft mit', s: 'Die Karte folgt dem Standort. Felder, Bereiche und Wind meldet das Handy genauso einfach.', speed: 1.4 });
  await Promise.all([w1, w2, w3]);
  await hsnap('walk');
  await anna.endSeg();
  if (STOP === '4') return done();

  // ================= 16:12 Mütze gefunden =================
  await at('16:12');
  card('t5', { style: 'time', num: '16:12', title: 'Ein erster Hinweis', sub: 'Die Feuerwehr findet eine graue Mütze' });
  await el.seg('find', { t: 'Fund per Funk: graue Mütze', s: '„Fund/Hinweis eintragen“: Art, Beschreibung, Finder, Ort auf der Karte – erscheint bei allen Geräten und im Bericht.', speed: 1.4 });
  await el.tap('#btn-status', { wait: 800 });
  await el.tap('#st-find', { wait: 700 });
  await el.tap('#find-kinds button:has-text("Kleidungsstück")', { wait: 400 });
  await el.type('#find-txt', 'Graue Strickmütze am Weg', { delay: 30 });
  await el.type('#find-finder', 'FF Scheuen', { delay: 30 });
  await el.tap('#dlg-box button:has-text("Ort auf der Karte antippen")', { wait: 900 });
  await el.tap(CAP, { wait: 1800 });
  await p.evaluate(() => { const b = [...document.querySelectorAll('#dlg-box button')].find((x) => /Gesehen|OK|Schließen/.test(x.textContent)); if (b && !document.getElementById('dlg').hidden) b.click(); });
  await snap('find');
  await el.pause(1200);
  await el.endSeg();
  w1 = walker(A, walkAnna.slice(30, 60), 120); w2 = walker(J, walkJonas.slice(26, 52), 120); w3 = walker(M, walkMia.slice(18, 34), 160);
  await Promise.all([w1, w2, w3]);
  if (STOP === '5') return done();

  // ================= 16:20 Absuche am See (Umriss) =================
  await at('16:20');
  card('t5b', { style: 'time', num: '16:20', title: 'Absuche am See', sub: 'Mia und Balu suchen den Umriss ab' });
  const msnap = async (n) => { if (shots) await mia.shot(`chk_mia_${n}.png`); };
  const pickBtn2 = (pg, re) => pg.evaluate((re) => { const b = [...document.querySelectorAll('#dlg-box button')].find((x) => new RegExp(re).test(x.textContent)); if (b && !document.getElementById('dlg').hidden) { b.click(); return true; } return false; }, re).catch(() => false);
  // Mias Karte auf ihr Gebiet
  await M.click('#hfi-area').catch(() => {}); await sleep(1500);
  // Schilfgürtel am Westufer: Koordinaten -> Punkte auf Mias Handy
  const reedLL = await toLL(ring.length ? [o(1035, 255), o(1045, 225), o(1060, 300)] : []);
  const reedPx = await M.evaluate((lls) => { const m = window.__app.map; const r = m.getContainer().getBoundingClientRect(); return lls.map(([a, b]) => { const pt = m.latLngToContainerPoint([a, b]); return [pt.x + r.left, pt.y + r.top]; }); }, reedLL);
  const cx = reedPx.reduce((s, q) => s + q[0], 0) / reedPx.length, cy = reedPx.reduce((s, q) => s + q[1], 0) / reedPx.length;
  const lasso = []; for (let k = 0; k <= 28; k++) { const a = k / 28 * Math.PI * 2; lasso.push([cx + Math.cos(a) * 46 + Math.sin(k) * 3, cy + Math.sin(a) * 70]); }
  await dual(el, mia, 'reed', { t: 'Mia umkreist einen Bereich', s: '„✏️ Bereich“: mit dem Finger umkreisen, Namen und Notiz eingeben – geht mit der Rückmeldung an die Einsatzleitung.' });
  await mia.pause(1000);
  await mia.tap('#hf-draw', { wait: 700 });
  await mia.drag(lasso, { ms: 1600, wait: 700 });
  await mia.type('#dlg-box input', 'Schilfgürtel', { delay: 60 });
  await mia.type('#dlg-box textarea', 'nicht begehbar, sumpfig – nur vom Ufer abgesucht', { delay: 25 });
  await mia.tap('#dlg-box button:has-text("Speichern")', { wait: 1400 });
  await msnap('reed');
  await el.endSeg(); await mia.endSeg();
  await dual(el, mia, 'stand', { t: '„📊 Stand 60 %“ – live bei der Einsatzleitung', s: 'Wie viel vom Gebiet abgesucht ist, mit Grund. Der Status-Chip zeigt es sofort.' });
  await mia.tap('#hf-status', { wait: 600 });
  await mia.tap('button:visible:has-text("Stand")', { wait: 700 });
  const rng = M.locator('#dlg-box .st-range');
  const rb = await rng.boundingBox();
  await mia.drag([[rb.x + rb.width * 0.5, rb.y + rb.height / 2], [rb.x + rb.width * 0.6, rb.y + rb.height / 2]], { ms: 500, wait: 300 });
  await M.evaluate(() => { const r = document.querySelector('#dlg-box .st-range'); r.value = 60; r.dispatchEvent(new Event('input', { bubbles: true })); });
  await mia.type('#dlg-box input[type=text]', 'Schilfgürtel nicht begehbar', { delay: 30 });
  await mia.tap('#dlg-box button:has-text("Melden")', { wait: 900 });
  await poll(p); await sleep(2600);
  await snap('stand');
  await el.pause(800);
  await el.endSeg(); await mia.endSeg();
  if (STOP === '5a') return done();

  // ================= 16:33 Umriss fertig =================
  await at('16:33');
  await walker(M, walkMia.slice(34), 150);
  await dual(el, mia, 'zu', { t: 'Gebiet fertig: „✅ Auftrag abschließen“', s: '100 % – die Einsatzleitung schließt den Auftrag automatisch ab (mit „Rückgängig“). Mia ist wieder frei.' });
  await mia.tap('#hf-status', { wait: 600 });
  await mia.tap('button:visible:has-text("Auftrag abschließen")', { wait: 700 });
  { const rb2 = await M.locator('#dlg-box .st-range').boundingBox();
    await mia.drag([[rb2.x + rb2.width * 0.6, rb2.y + rb2.height / 2], [rb2.x + rb2.width - 4, rb2.y + rb2.height / 2]], { ms: 500, wait: 200 });
    await M.evaluate(() => { const r = document.querySelector('#dlg-box .st-range'); r.value = 100; r.dispatchEvent(new Event('input', { bubbles: true })); }); }
  await sleep(400);
  await mia.tap('#dlg-box button:has-text("Abschließen")', { wait: 1500 });
  await msnap('zu');
  await poll(p); await sleep(2800);
  await snap('zu');
  await el.pause(1000);
  await el.endSeg(); await mia.endSeg();
  // Mias Rückmeldung (QR) übernehmen
  let miaBack1 = '';
  try {
    if (!(await M.locator('#qr-copy').isVisible().catch(() => false))) { await pickBtn(M, 'Schließen|Später|OK'); await M.click('#hf-back'); await sleep(1500); }
    await M.click('#qr-copy'); await sleep(300);
    miaBack1 = (await M.evaluate(() => navigator.clipboard.readText())).replace(LIVE, LOCAL);
    await M.click('#qr-close').catch(() => {});
  } catch (e) { console.log('miaBack1', e.message.split('\n')[0]); }
  console.log('MIA1', miaBack1.length);

  await el.seg('next', { t: 'Rückmeldung übernehmen – neues Gebiet für Mia', s: 'Weg und Schilfgürtel landen auf der Karte. Dann ein neuer Umriss am Bahndamm Ost – Auftrag per QR-Code.', speed: 1.5 });
  if (miaBack1) {
    await el.tap('#btn-teams', { wait: 500 });
    await el.tap('#recv-paste', { wait: 500 });
    await p.fill('#dlg-box textarea', miaBack1);
    await el.tap('#dlg-box button:has-text("Übernehmen")', { wait: 1500 });
    await pickBtn(p, 'Noch offen|Später');
    await closePanels();
    await sleep(600);
  }
  await snap('miaback');
  await el.tap('[data-tool=track]', { wait: 400 });
  for (const pt of O([[880, 470], [1010, 430], [1060, 500], [940, 560]])) await el.tap(pt, { wait: 250, ms: 380 });
  await el.tap('#track-done', { wait: 600 });
  await el.type('#dlg-box input[type=text]', 'Bahndamm Ost', { delay: 50 });
  await p.locator('#dlg-box select').selectOption({ label: '🐕 Mia (Balu)' }).catch(async () => {
    const opts = await p.locator('#dlg-box select option').allTextContents();
    await p.locator('#dlg-box select').selectOption({ index: opts.findIndex((x) => x.includes('Mia')) });
  });
  await el.tap('#dlg-box button:has-text("Speichern")', { wait: 800 });
  await el.tap('[data-tool=pan]', { wait: 400 });
  await el.tap('#btn-teams', { wait: 500 });
  await el.tap('#send-open', { wait: 800 });
  { const opts = await p.locator('#send-team option').allTextContents(); await p.selectOption('#send-team', { index: opts.findIndex((x) => x.includes('Mia')) }); }
  await sleep(500);
  // nur das neue Gebiet mitgeben (der See ist fertig)
  await p.evaluate(() => document.querySelectorAll('#send-items label').forEach((l) => { if (/See/.test(l.textContent) && !/Bahndamm/.test(l.textContent)) { const i = l.querySelector('input'); if (i && i.checked) i.click(); } }));
  await sleep(300);
  await el.tap('#send-qr', { wait: 1500 });
  await p.click('#qr-copy'); await sleep(200);
  const linkMia2 = (await p.evaluate(() => navigator.clipboard.readText())).replace(LIVE, LOCAL);
  await el.tap('#qr-close', { wait: 400 });
  await closePanels();
  await snap('next');
  await el.endSeg();
  // Mia übernimmt das neue Gebiet (im Hintergrund)
  await M.goto(linkMia2); await sleep(2500);
  await pickBtn(M, 'Ersetzen|Übernehmen|Ja|OK');
  await sleep(800);
  await M.click('#hf-status').catch(() => {}); await sleep(400); await M.click('button:visible:has-text("Suche begonnen")').catch(() => {}); await sleep(600);
  await pickBtn(M, 'Melden'); await sleep(400);
  await M.click('#hf-rec').catch(() => {}); await sleep(300);
  const walkMia2 = await toLL(snake(900, 1030, [470, 500, 530], 6));
  w3 = walker(M, walkMia2, 200);

  // Jonas meldet seinen Stand, die Feuerwehr ist fertig
  await J.click('#hf-status'); await sleep(400); await J.click('button:visible:has-text("Stand")'); await sleep(400);
  await J.evaluate(() => { const r = document.querySelector('#dlg-box .st-range'); r.value = 80; r.dispatchEvent(new Event('input', { bubbles: true })); });
  await J.click('#dlg-box button:has-text("Melden")'); await sleep(600);
  await poll(p); await sleep(2500);
  await el.seg('progress', { t: 'Überblick über den Fortschritt', s: 'Jonas meldet 80 %, die Feuerwehr per Funk „Abgeschlossen“ – jeder Chip zeigt den aktuellen Stand.', speed: 1.3 });
  await el.tap('#btn-status', { wait: 700 });
  await funk('FF Scheuen', 'Abgeschlossen', true);
  await closePanels();
  await el.pause(2200);
  await snap('progress');
  await el.endSeg();
  await w3;

  // ================= 16:41 Dämmerung, Drohne meldet Wärmequelle =================
  await at('16:41');
  card('t6', { style: 'time', num: '16:41', title: 'Es wird dunkel', sub: 'Sonnenuntergang – die Drohne fliegt mit Wärmebild' });
  await el.seg('dusk', { t: 'Nachtmodus', s: 'Das Wetter zeigt: in gut 30 Minuten ist es dunkel. Die App schaltet auf dunkel – schont die Augen.' });
  await el.tap('#quick-wx', { wait: 2600 });
  await snap('wx');
  await el.tap('#quick-wx', { wait: 500 });
  await el.tap('#quick-night', { wait: 1400 });
  await el.seg('heat', { t: 'Drohne: Wärmequelle am Bahndamm', s: 'Eintragen und gleich einen Prüfauftrag an das nächste Hundeteam schicken.', speed: 1.3 });
  await el.tap('#btn-status', { wait: 800 });
  await el.tap('#st-find', { wait: 700 });
  await el.tap('#find-kinds button:has-text("Wärmequelle")', { wait: 400 });
  await el.type('#find-txt', 'Wärmebild: liegende Person? Böschung Bahndamm', { delay: 22 });
  await el.type('#find-finder', 'Drohne', { delay: 30 });
  const chk = p.locator('#find-check');
  if (await chk.count()) {
    const opts = await chk.locator('option').allTextContents();
    await chk.selectOption({ index: Math.max(0, opts.findIndex((x) => x.includes('Anna'))) });
  }
  await sleep(500);
  await el.tap('#dlg-box button:has-text("Ort auf der Karte antippen")', { wait: 900 });
  await el.tap(HEAT, { wait: 1800 });
  await snap('heat');
  await el.endSeg();
  if (STOP === '6') return done();

  // Anna bekommt den Prüfauftrag
  await sleep(1000);
  await poll(A); await sleep(2500);
  await dual(el, anna, 'check', { t: 'Prüfauftrag kommt beim Team an', s: 'Anna sieht die Nachricht der Einsatzleitung – und den Ort auf ihrer Karte.' });
  await poll(A); await sleep(2500);
  await hsnap('check');
  await anna.pause(1500);
  await anna.tap('#dlg-box button:has-text("Verstanden"), #dlg-box button:has-text("OK"), #dlg-box button.primary', { wait: 1000 }).catch(() => {});
  await el.endSeg(); await anna.endSeg();

  // ================= 16:55 Fund =================
  await at('16:55');
  card('t7', { style: 'time', num: '16:55', title: 'Rex zeigt an', sub: 'Am Bahndamm, unter Brombeeren' });
  await anna.seg('go', { t: 'Auf dem Weg zur Wärmequelle', s: 'Rex nimmt Witterung auf …', speed: 1.3 });
  await walker(A, toHeat, 450);
  await anna.endSeg();
  await dual(el, anna, 'fund', { t: '✅ Person gefunden', s: 'Der Fund geht sofort an die Einsatzleitung – mit Ort, Ton und Hinweis, den man bestätigen muss.' });
  await anna.tap('#hf-mark', { wait: 600 });
  await anna.type('#dlg-box input', 'Herr K. gefunden, ansprechbar, unterkühlt – RD anfordern', { delay: 25 });
  await anna.tap('#dlg-box button:has-text("Fund")', { wait: 800 });
  await poll(p); await sleep(2600);
  await snap('fund');
  await el.pause(1000);
  await el.tap('#dlg-box button:has-text("Gesehen")', { wait: 1400 }).catch((e) => console.log('gesehen', e.message));
  await el.endSeg(); await anna.endSeg();
  if (STOP === '7') return done();

  // ================= 16:58 Alle zurück =================
  await at('16:58');
  card('t8', { style: 'time', num: '16:58', title: 'Suche beenden', sub: 'Nachricht an alle Teams' });
  await el.seg('msg', { t: 'Nachricht an alle Teams', s: '„Wichtig“ – mit Ton und Fenster beim Hundeführer, bis er „Verstanden“ tippt. Die EL sieht, wer gelesen hat.', speed: 1.3 });
  await el.tap('#btn-status', { wait: 800 });
  const to = p.locator('#el-to');
  const tos = await to.locator('option').allTextContents();
  await to.selectOption({ index: Math.max(0, tos.findIndex((x) => /alle/i.test(x))) });
  await el.type('#el-txt', 'Person gefunden! Suche beenden, alle zurück zum B-Ort.', { delay: 28 });
  await el.tap('#el-prio', { wait: 300 });
  await el.tap('#el-go', { wait: 1200 });
  await snap('msg');
  await closePanels();
  await el.endSeg();
  await sleep(1000);
  await poll(J); await sleep(2500);
  await dual(el, jonas, 'msg2', { t: 'Bei Jonas und Luna kommt die Nachricht an', s: 'Ton, Fenster, „Verstanden“ – die Quittung geht zurück an die Einsatzleitung.' });
  await poll(J); await sleep(2800);
  await jonas.tap('#dlg-box button:has-text("Verstanden"), #dlg-box button.primary', { wait: 1500 }).catch((e) => console.log('verstanden', e.message));
  await el.endSeg(); await jonas.endSeg();
  // Zurückkommen: Rückmeldungen im Hintergrund vorbereiten
  for (const pg of [A, J, M]) await pg.evaluate(() => document.querySelectorAll('#dlg-box button').forEach((b) => { if (/Verstanden|OK/.test(b.textContent)) b.click(); })).catch(() => {});

  // ================= 17:20 Rückmeldungen =================
  await at('17:16');
  // alle Handys holen die Nachricht ab und quittieren sie
  for (const pg of [A, J, M]) {
    await poll(pg); await sleep(2500);
    const v = pg.locator('#dlg-box button:has-text("Verstanden")');
    if (await v.isVisible().catch(() => false)) { await v.click(); await sleep(400); }
  }
  for (const [i, pg] of [A, J, M].entries()) {
    if (shots) await pg.screenshot({ path: `chk_back_${i}.png` }).catch(() => {});
    console.log('URL', i, pg.url().slice(0, 60), await pg.evaluate(() => [document.body.className, !!document.getElementById('hf-status'), document.getElementById('dlg') && !document.getElementById('dlg').hidden && document.getElementById('dlg-box').innerText.slice(0, 120)]).catch((e) => e.message));
    try { await pg.click('#hf-status', { timeout: 5000 }); await sleep(400); await pg.click('button:visible:has-text("Zurück am B-Ort")', { timeout: 5000 }); await sleep(500); } catch (e) { console.log('zurueck', i, e.message.split('\n')[0]); }
  }
  await funk('FF Scheuen', 'Zurück am B-Ort', false).catch((e) => console.log('ff', e.message));
  await funk('Drohne', 'Zurück am B-Ort', false).catch((e) => console.log('drohne', e.message));
  await closePanels();
  await at('17:20');
  await poll(p); await sleep(2500);
  card('t9', { style: 'time', num: '17:20', title: 'Zurück am B-Ort', sub: 'Rückmeldungen einsammeln' });
  await el.seg('out', { t: '„Wer ist noch draußen?“', s: 'Die Liste zeigt, welche Einheit sich noch nicht zurückgemeldet hat – mit Einsatzzeit.' });
  await el.tap('#btn-status', { wait: 900 });
  await el.tap('#st-out summary, #st-out-sum', { wait: 1800 });
  await snap('out');
  await closePanels();
  await el.endSeg();
  // Rückmelde-Links holen
  const backOf = async (r) => {
    const pg = r.page;
    await pg.evaluate(() => document.querySelectorAll('#dlg-box button').forEach((b) => { if (/Verstanden|OK/.test(b.textContent)) b.click(); })).catch(() => {});
    await pg.click('#hf-back'); await sleep(1500);
    await pg.click('#qr-copy'); await sleep(300);
    const l = await pg.evaluate(() => navigator.clipboard.readText()).catch(() => '');
    await pg.click('#qr-close').catch(() => {});
    return l.replace(LIVE, LOCAL);
  };
  const backs = [await backOf(anna), await backOf(jonas), await backOf(mia)];
  console.log('BACKS', backs.map((x) => x.length));
  // Nachtmodus aus (rot, dann aus) für den Überblick
  await p.click('#quick-night'); await sleep(200); await p.click('#quick-night'); await sleep(400);
  await el.seg('recv', { t: 'Alle Wege auf einer Karte', s: 'Rückmeldungen scannen oder einfügen: gelaufene Wege, Markierungen und Funde jedes Teams.', speed: 1.5 });
  await el.tap('#btn-teams', { wait: 500 });
  for (const [i, b] of backs.entries()) {
    if (!b) continue;
    if (i === 0) await el.tap('#recv-paste', { wait: 500 }); else { await p.click('#recv-paste'); await sleep(300); }
    await p.fill('#dlg-box textarea', b);
    await el.tap('#dlg-box button:has-text("Übernehmen")', { wait: 1200, ms: i ? 250 : 600 });
    await p.evaluate(() => { const b = [...document.querySelectorAll('#dlg-box button')].find((x) => /Noch offen|Später/.test(x.textContent)); if (b && !document.getElementById('dlg').hidden) b.click(); });
  }
  await closePanels();
  await map(([a, b]) => window.__app.map.flyTo([a, b], 16, { duration: 1.2 }), FOREST);
  await sleep(2400);
  await snap('recv');
  await el.pause(1500);
  await el.endSeg();
  if (STOP === '8') return done();

  // ================= 17:40 Einsatzende =================
  await at('17:40');
  card('t10', { style: 'time', num: '17:40', title: 'Einsatzende', sub: 'Bericht schreiben, verschicken, fertig' });
  await el.seg('report', { t: 'Bericht auf Knopfdruck', s: 'Zeiten, Kräfte aus den Teams, Einsatzzeiten und Personenstunden, alle Meldungen mit Ort.', speed: 1.5 });
  await el.tap('#btn-mission', { wait: 800 });
  await el.tap('[data-tab=ende]', { wait: 800 });
  await el.type('#ms-summary', '15:50 Suche mit 3 Hundeteams, Fußtrupp FF und Drohne.\n16:12 Mütze gefunden (FF).\n16:44 Wärmequelle (Drohne), Prüfauftrag an Anna.\n16:55 Fund durch Anna/Rex am Bahndamm, an RD übergeben.', { delay: 8 });
  await snap('report');
  const save = async (sel, file) => { const d = p.waitForEvent('download', { timeout: 90000 }).catch(() => null); await el.tap(sel, { wait: 1300 }); const x = await d; if (x) await x.saveAs(file); };
  await save('#ms-save', 'e-bericht.pdf');
  await el.endSeg();
  await closePanels();
  // Karten-PDF
  await p.click('#btn-pdf'); await sleep(800);
  await p.click('#share-to [data-to=other]'); await sleep(600);
  await p.click('#share-scopes [data-scope=all]').catch(() => {}); await sleep(600);
  await p.click('#share-pdf'); await sleep(1200);
  { const d = p.waitForEvent('download', { timeout: 90000 }).catch(() => null); await p.click('#pdf-save'); const x = await d; if (x) await x.saveAs('e-karte.pdf'); }

  // PDFs zeigen
  try {
    const { execFileSync } = require('child_process');
    fs.rmSync('pdfimg-einsatz', { recursive: true, force: true });
    fs.mkdirSync('pdfimg-einsatz');
    for (const [f, n] of [['e-karte.pdf', 1], ['e-bericht.pdf', 2]]) {
      if (fs.existsSync(f)) execFileSync('pdftoppm', ['-png', '-r', '110', '-f', '1', '-l', String(n), f, `pdfimg-einsatz/${f.replace('.pdf', '')}`]);
    }
    const ord = ['e-karte', 'e-bericht'];
    const imgs = fs.readdirSync('pdfimg-einsatz').sort().sort((a, b) => ord.findIndex((x) => a.startsWith(x)) - ord.findIndex((x) => b.startsWith(x))).map((x) => `file://${__dirname}/pdfimg-einsatz/${x}`);
    const html = `<html><head><style>body{margin:0;width:1600px;height:900px;overflow:hidden;background:#e9ebef}
      .pg{position:absolute;top:50px;height:800px;box-shadow:0 12px 40px rgba(0,0,0,.28);background:#fff;opacity:0;transform:translateY(60px) scale(.96);transition:all .7s cubic-bezier(.2,.8,.2,1)} .pg.on{opacity:1;transform:none}</style></head>
      <body>${imgs.map((u, i) => `<img class="pg" id="pg${i}" src="${u}" style="left:${70 + i * (1000 / Math.max(1, imgs.length - 1))}px;z-index:${i}">`).join('')}</body></html>`;
    fs.writeFileSync('pdfs-einsatz.html', html);
    const pdf = new Rec('pdf');
    const pp = await pdf.start(`file://${__dirname}/pdfs-einsatz.html`);
    await sleep(800);
    await pdf.seg('pdfs', { t: 'Fertig zum Verschicken', s: 'Karte mit allen Wegen und Funden und der Abschlussbericht – per Mail, WhatsApp oder Drucker.' });
    for (let i = 0; i < imgs.length; i++) { await pp.evaluate((i) => document.getElementById('pg' + i).classList.add('on'), i); await sleep(800); }
    await sleep(2200);
    await pdf.finish();
  } catch (e) { console.log('PDF-Bilder', e.message); }

  card('story', { style: 'story', lines: ['Herr K. wurde um 16:55 gefunden.', 'Unterkühlt, aber ansprechbar – übergeben an den Rettungsdienst.', 'Suchzeit 65 Minuten · 5 Einheiten · 3 Hundeteams', 'Einsatz, Personen und Ablauf sind frei erfunden.'] });
  card('outro', { style: 'outro', feats: [['📲', 'Aufträge per QR-Code'], ['📣', 'Live-Status & Fund-Alarm'], ['✍️', 'Funkmeldungen für Teams ohne App'], ['🔎', 'Funde mit Prüfauftrag'], ['🌙', 'Wetter, Dämmerung, Nachtmodus'], ['📄', 'Abschlussbericht auf Knopfdruck']] });
  await done();

  async function done() {
    saveOrder();
    for (const r of recs.slice(1)) await r.finish().catch(() => {});
    await el.finish();
    saveOrder();
  }
})().catch((e) => { console.error(e); saveOrder(); process.exit(1); });
