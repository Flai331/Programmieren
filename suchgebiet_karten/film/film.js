// Drehbuch „RHS Einsatz – die App in 3 Minuten“
const fs = require('fs');
const { Rec, sleep, dual, card, saveOrder } = require('./lib');

const LIVE = 'https://flai331.github.io/Programmieren/suchgebiet-karten/';
const LOCAL = 'http://localhost:8765/';
const STOP = process.env.STOP || '';
const shots = !!process.env.SHOTS;

const FOREST = [52.6695, 10.1035];
// Bildschirmpunkte wurden für 1280×720 ermittelt; die Karte ist jetzt 1600×900 (gleiche Mitte)
const o = (x, y) => [x + 160, y + 90];
const O = (pts) => pts.map(([x, y]) => o(x, y));
const BORT_VIEW = [52.6745, 10.0835];

(async () => {
  const el = new Rec('el');
  const p = await el.start(LOCAL);
  await el.ctx.grantPermissions(['clipboard-read', 'clipboard-write', 'geolocation'], { origin: 'http://localhost:8765' });
  await el.ctx.setGeolocation({ latitude: 52.6741, longitude: 10.0832, accuracy: 8 });
  await sleep(2500);
  const snap = async (n) => { if (shots) await el.shot(`chk_${n}.png`); };
  const map = (fn, arg) => p.evaluate(fn, arg);
  let gpsTimer = null;

  card('intro', { style: 'intro' });
  // ================= Kapitel 1: Einsatz anlegen =================
  card('c1', { num: '1', title: 'Einsatz anlegen', sub: 'Ein Assistent führt durch die ersten Minuten' });
  await el.seg('start', { t: 'Eine App – zwei Modi', s: 'Einsatzleitung plant und behält den Überblick, Hundeführer bekommen eine einfache Ansicht.' });
  await el.pause(1600);
  await el.tap('text=Einsatzleitung', { wait: 900 });
  await el.seg('wz1', { t: 'Assistent „Neuer Einsatz“', s: 'Name, Einsatzleitung, B-Ort, Wetter, vermisste Person, Zeiten, Kontakte.' , speed: 1.3 });
  await el.type('#wz-body input', 'Vermisste Person Scheuen', { delay: 55 });
  await el.tap('#wz-next', { wait: 600 });
  await el.type('#wz-body input >> nth=0', 'Thomas Berger', { delay: 60 });
  await el.type('#wz-body input >> nth=2', 'Rettungshund 1', { delay: 45 });
  await el.tap('#wz-next', { wait: 700 });
  await snap('wz');
  await el.seg('bort', { t: 'B-Ort per Adresse oder Kreuzung', s: 'Suche tippen, Treffer wählen, genauen Punkt auf der Karte antippen.' , speed: 1.2 });
  await el.tap('text=Adresse oder Kreuzung suchen', { wait: 500 });
  await p.keyboard.type('Scheuen, Celle', { delay: 90 });
  await sleep(1800);
  await snap('search');
  await el.tap('#search-results button >> nth=0', { wait: 1800 });
  await map(([a, b]) => window.__app.map.flyTo([a, b], 16, { duration: 1.2 }), BORT_VIEW);
  await sleep(2200);
  await el.tap(o(560, 380), { wait: 1400 });
  await snap('bort');
  await el.seg('wx', { t: 'Wetter am B-Ort – automatisch', s: 'Wind, Böen und Temperatur vom Deutschen Wetterdienst für den Ansatz gegen den Wind.' , speed: 1.35 });
  await el.pause(2600);
  await el.tap('#wz-next', { wait: 500 });
  await el.type('#wz-body textarea, #wz-body input >> nth=0', 'Erika M., 78 J., 1,60 m, graue Haare, blaue Regenjacke, dement', { delay: 28 });
  await el.pause(500);
  await el.tap('#wz-next', { wait: 500 });
  await el.tap('text=Jetzt >> nth=0', { wait: 500 });
  await el.tap('#wz-next', { wait: 400 });
  await el.tap('#wz-next', { wait: 700 });
  await snap('fertig');
  await el.tap('text=Raster aufziehen', { wait: 300 });
  await el.endSeg();
  if (STOP === '1') return done();

  // ================= Kapitel 2: Raster, Teams, Gebiete =================
  card('c2', { num: '2', title: 'Raster, Teams, Suchgebiete', sub: 'Gebiete planen und Teams zuteilen' });
  await map(([a, b]) => window.__app.map.setView([a, b], 16, { animate: false }), FOREST);
  await sleep(2500);
  await el.seg('grid', { t: 'Raster mit dem Finger aufziehen', s: 'Feste Koordinaten: Feld C4 liegt auf jeder Karte und in jedem PDF an derselben Stelle.' });
  await el.pause(700);
  await el.drag(O([[335, 155], [610, 330], [895, 515]]), { ms: 1600, wait: 1400 });
  await el.tap('#gridfit-done, button:visible:has-text("Fertig")', { wait: 600 });
  await snap('grid');

  await el.seg('teams', { t: 'Teams anlegen', s: 'Hundeführer, Hund, Farbe – auch Fußtrupps, Fahrzeuge und Drohnen mit Funkrufname.' , speed: 1.35 });
  await el.tap('#btn-teams', { wait: 600 });
  await el.tap('#team-add', { wait: 400 });
  await p.locator('#mark-list .name').last().fill('');
  await p.locator('#mark-list .name').last().pressSequentially('Anna', { delay: 90 });
  await el.type(p.locator('#mark-list .dog').last(), 'Rex', { delay: 90 });
  for (const [n, d] of [['Jonas', 'Luna'], ['Mia', 'Balu']]) {
    await el.tap('#team-add', { wait: 300 });
    await p.locator('#mark-list .name').last().fill('');
    await p.locator('#mark-list .name').last().pressSequentially(n, { delay: 50 });
    await p.locator('#mark-list .dog').last().fill(d);
    await sleep(250);
  }
  await sleep(700);
  await snap('teams');
  await el.tap('#panel-teams .close', { wait: 500 });

  await el.seg('fill', { t: 'Felder zuteilen', s: 'Team wählen und mit dem Finger über die Felder wischen.' , speed: 1.3 });
  await el.tap('[data-tool=fill]', { wait: 500 });
  await el.tap('button:visible:has-text("Anna")', { wait: 400 });
  await el.drag(O([[365, 190], [505, 190], [505, 255], [365, 255], [365, 325], [505, 325]]), { ms: 1800, wait: 400 });
  await el.tap('button:visible:has-text("Jonas")', { wait: 400 });
  await el.drag(O([[575, 190], [715, 190], [715, 255], [575, 255], [575, 325], [715, 325]]), { ms: 1600, wait: 500 });
  await snap('fill');

  await el.seg('outline', { t: 'Umriss zeichnen', s: 'Gebiet Punkt für Punkt umranden – mit Fläche in Hektar, Name und Team.' , speed: 1.4 });
  await el.tap('[data-tool=track]', { wait: 500 });
  for (const pt of O([[985, 160], [1110, 115], [1185, 230], [1150, 360], [1010, 345]])) await el.tap(pt, { wait: 350, ms: 450 });
  await el.tap('#track-done', { wait: 700 });
  await el.type('#dlg-box input[type=text]', 'Nord 1', { delay: 70 });
  const sel = p.locator('#dlg-box select');
  await el.tap(sel, { wait: 200, real: false });
  await sel.selectOption({ label: '🐕 Mia (Balu)' }).catch(async () => { const o = await sel.locator('option').allTextContents(); console.log('OPTS', o); await sel.selectOption({ index: o.findIndex((x) => x.includes('Mia')) }); });
  await sleep(500);
  await el.tap('button:visible:has-text("Speichern")', { wait: 1500 });
  await el.tap('[data-tool=pan]', { wait: 600 });
  await snap('outline');
  await el.endSeg();
  if (STOP === '2') return done();

  // ================= Kapitel 3: Auftrag per QR-Code =================
  card('c3', { num: '3', title: 'Auftrag per QR-Code', sub: 'Ohne Anmeldung, ohne Server – alles steckt im Code' });
  await el.seg('send', { t: 'Auftrag zusammenstellen', s: 'Felder, Umrisse, B-Ort, Rettungspunkte, Hinweise und Kontakte – vorausgewählt.' , speed: 1.35 });
  await el.tap('#btn-teams', { wait: 600 });
  await el.tap('#send-open', { wait: 900 });
  await el.pause(1200);
  await el.type('#panel-send textarea, #send-note', 'Achtung Bahnlinie im Süden. Stand alle 30 min melden.', { delay: 30 });
  await el.pause(500);
  await el.tap('#send-qr', { wait: 1800 });
  await snap('qr');
  await el.seg('qr', { t: 'QR-Code scannen – fertig', s: 'Der Hundeführer scannt mit der Handy-Kamera. Die Ansicht öffnet sich im Browser oder in der App.' });
  await el.pause(2500);
  await el.tap('#qr-copy', { wait: 300, real: true });
  const linkAnna = (await p.evaluate(() => navigator.clipboard.readText())).replace(LIVE, LOCAL);
  await el.tap('#qr-close', { wait: 500 });
  await el.endSeg();

  // Auftrag für Jonas still im Hintergrund (für das zweite Team auf der Karte)
  await p.selectOption('#send-team', { index: 1 }).catch(() => {});
  await p.click('#send-qr'); await sleep(600);
  await p.click('#qr-copy'); await sleep(200);
  const linkJonas = (await p.evaluate(() => navigator.clipboard.readText())).replace(LIVE, LOCAL);
  await p.click('#qr-close'); await sleep(300);
  await p.evaluate(() => document.querySelectorAll('.panel:not([hidden]) .close').forEach((b) => b.click()));
  fs.writeFileSync('links.json', JSON.stringify({ linkAnna, linkJonas }));
  if (STOP === '3') return done();

  // ================= Kapitel 4: Hundeführer am Handy =================
  card('c4', { num: '4', title: 'Hundeführer im Gelände', sub: 'Große Knöpfe, alles Wichtige auf einen Blick' });
  const hf = new Rec('hf', { width: 454, height: 982, scale: 1, mobile: true });
  const h = await hf.start('about:blank', `(() => {
    // Ruhiges Film-GPS: Positionen kommen nur aus dem Drehbuch (window.__setPos), nie ein Zeitlimit-Fehler
    const G = window.__geo = { w: new Map(), id: 0, pos: null };
    const mk = (lat, lon) => ({ coords: { latitude: lat, longitude: lon, accuracy: 5, altitude: null, altitudeAccuracy: null, heading: null, speed: null }, timestamp: Date.now() });
    G.pos = mk(52.6741, 10.0832);
    window.__setPos = (lat, lon) => { G.pos = mk(lat, lon); G.w.forEach((ok) => { try { ok(G.pos); } catch (e) {} }); };
    const P = Geolocation.prototype;
    P.watchPosition = function (ok) { const id = ++G.id; G.w.set(id, ok); setTimeout(() => G.pos && ok(G.pos), 60); return id; };
    P.clearWatch = function (id) { G.w.delete(id); };
    P.getCurrentPosition = function (ok) { setTimeout(() => ok(G.pos), 60); };
  })();`);
  await hf.ctx.setGeolocation({ latitude: 52.6741, longitude: 10.0832, accuracy: 6 });
  await hf.ctx.grantPermissions(['clipboard-read', 'clipboard-write', 'geolocation'], { origin: 'http://localhost:8765' });
  const hsnap = async (n) => { if (shots) await hf.shot(`chk_hf_${n}.png`); };
  // GPS „lebt“: alle 0,8 s die aktuelle Position minimal verändert neu setzen (sonst meldet die App „kein GPS-Empfang“)
  let gpsNow = [52.6741, 10.0832];
  let gpsTick = 0;
  const setGps = async (lat, lon) => { gpsNow = [lat, lon]; await h.evaluate(([a, b]) => window.__setPos && window.__setPos(a, b), [lat, lon]).catch(() => {}); };
  // zweites Team (Jonas) unsichtbar: nimmt an und meldet „Suche begonnen“
  const jo = new Rec('jo', { width: 390, height: 844, scale: 1, mobile: true });
  const j = await jo.start(linkJonas);
  await jo.ctx.setGeolocation({ latitude: 52.6712, longitude: 10.1012, accuracy: 6 });
  await sleep(3000);

  await hf.seg('open', { t: 'Auftrag auf dem Handy', s: 'Team, Gebiet, Felder und Hinweise der Einsatzleitung – auch offline nutzbar.' });
  await h.goto(linkAnna);
  await sleep(3000);
  await hf.tap('#hfi-area', { wait: 1600 });
  await hsnap('open');
  await hf.pause(1200);

  await hf.seg('status', { t: 'Status mit einem Tipp', s: 'Parkplatz, Suche begonnen, Pause, Stand in Prozent – geht live an die Einsatzleitung.' });
  await hf.tap('#hf-status', { wait: 900 });
  await hsnap('statusdlg');
  await hf.tap('button:visible:has-text("Suche begonnen")', { wait: 1500 });
  await hsnap('status');
  // Jonas meldet ebenfalls
  await j.click('#hf-status'); await sleep(500);
  await j.click('button:visible:has-text("Suche begonnen")'); await sleep(800);
  if (STOP === '4') return done(hf, jo);

  // Weg: Schlangenlinie durch Annas Felder (A1–C3), aus Bildschirmpunkten der EL-Karte berechnet
  await map(([a, b]) => window.__app.map.setView([a, b], 16, { animate: false }), FOREST);
  await sleep(500);
  const walkPx = [];
  const rows = [168, 198, 228, 258, 288, 318, 345];
  rows.forEach((y, i) => { const xs = i % 2 ? [505, 362] : [362, 505]; for (let k = 0; k <= 10; k++) walkPx.push(o(xs[0] + (xs[1] - xs[0]) * k / 10 + Math.sin(k * 1.7 + i) * 7, y + Math.cos(k * 1.3 + i) * 6)); });
  // Seitenpunkte -> Kartenpunkte (die Karte beginnt nicht oben links an der Seite)
  const walk = await p.evaluate((pts) => { const m = window.__app.map; const r = m.getContainer().getBoundingClientRect(); return pts.map(([x, y]) => { const ll = m.containerPointToLatLng([x - r.left, y - r.top]); return [ll.lat, ll.lng]; }); }, walkPx);
  const fundAt = walk[Math.floor(walk.length * 0.8)];
  const gegAt = walk[Math.floor(walk.length * 0.35)];
  await setGps(walk[0][0], walk[0][1]);
  await sleep(1500);

  await hf.seg('rec', { t: 'Weg aufzeichnen', s: 'Der GPS-Weg läuft mit – die Einsatzleitung sieht später genau, was abgesucht wurde.', speed: 1.6 });
  await hf.tap('#hf-rec', { wait: 1000 });
  const gi = Math.floor(walk.length * 0.35);
  for (let i = 1; i <= gi; i++) { await setGps(walk[i][0], walk[i][1]); await sleep(230); }
  await hsnap('rec');
  await hf.seg('mark', { t: 'Markieren am eigenen Standort', s: 'Anzeige, Fund, Spur, Gegenstand, Gefahr oder Hinweis – mit Notiz.' });
  await hf.tap('#hf-mark', { wait: 800 });
  await hf.type('#dlg-box input', 'Blaue Mütze am Wegrand', { delay: 45 });
  await hf.tap('#dlg-box button:has-text("Gegenstand")', { wait: 1500 });
  await hsnap('mark');
  await hf.seg('rec2', { t: 'Weiter suchen', s: 'Felder, umkreiste Bereiche und Wind lassen sich genauso einfach melden.', speed: 1.8 });
  const fi = Math.floor(walk.length * 0.8);
  for (let i = gi + 1; i <= fi; i++) { await setGps(walk[i][0], walk[i][1]); await sleep(220); }
  await hf.endSeg();
  if (STOP === '5') return done(hf, jo);

  // ================= Kapitel 5: Live bei der Einsatzleitung =================
  card('c5', { num: '5', title: 'Live bei der Einsatzleitung', sub: 'Meldungen kommen sofort an – verschlüsselt' });
  // EL holt die Meldungen ab (sonst alle 15 s) und blickt auf das Suchgebiet
  await p.evaluate(() => window.dispatchEvent(new Event('online')));
  await sleep(2500);
  await p.evaluate(() => window.dispatchEvent(new Event('online')));
  await sleep(1500);
  await el.fingerHide();
  await dual(el, hf, 'chips', { t: 'Team-Status in der Kopfleiste', s: 'Jedes Team mit Gebiet, letzter Meldung und Uhrzeit. Antippen springt zum Gebiet.' });
  await el.pause(1800);
  await snap('chips');
  await el.tap('button.tchip >> nth=0', { wait: 1800 }).catch((e) => console.log('chip', e.message));
  await snap('chipinfo');
  await el.pause(800);
  await el.tap('#tm-pop .close, #tm-pop button:has-text("✕"), #tm-pop button:has-text("×")', { wait: 500 }).catch(() => p.evaluate(() => { document.getElementById('tm-pop').hidden = true; }));

  await dual(el, hf, 'fund', { t: '✅ Fund – sofort bei der Einsatzleitung', s: 'Mit Ort auf der Karte, Ton und Hinweis. Fund und Hilfe sind nie stummgeschaltet.' });
  await hf.tap('#hf-mark', { wait: 700 });
  await hf.type('#dlg-box input', 'Person gefunden, ansprechbar, unterkühlt', { delay: 35 });
  await hf.tap('#dlg-box button:has-text("Fund")', { wait: 900 });
  await p.evaluate(() => window.dispatchEvent(new Event('online')));
  await sleep(2600);
  await snap('fund');
  await el.pause(1200);
  await el.tap('#dlg-box button:has-text("Gesehen")', { wait: 1500 }).catch((e) => console.log('gesehen', e.message));
  await el.endSeg(); await hf.endSeg();
  if (STOP === '6') return done(hf, jo);

  // ================= Kapitel 6: Rückmeldung =================
  card('c6', { num: '6', title: 'Rückmeldung & Überblick', sub: 'Weg, Markierungen und Felder zurück an die Einsatzleitung' });
  await hf.seg('back', { t: 'Zurückgeben per QR-Code', s: 'Der Hundeführer zeigt den Code, die Einsatzleitung scannt – alles landet automatisch beim richtigen Team.' });
  await hf.tap('#hf-rec', { wait: 600 });
  await h.evaluate(() => document.querySelectorAll('#dlg-box button').forEach((b) => { if (/beenden|stopp|anhalten|ja/i.test(b.textContent)) b.click(); }));
  await sleep(500);
  await hf.tap('#hf-back', { wait: 2200 });
  await hsnap('back');
  await hf.tap('#qr-copy', { wait: 300 });
  const backLink = (await h.evaluate(() => navigator.clipboard.readText().catch(() => ''))) || '';
  await hf.endSeg();
  await hf.ctx.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: 'http://localhost:8765' });
  const back2 = backLink || (await h.evaluate(() => navigator.clipboard.readText()));
  console.log('BACK', back2.length);

  await el.seg('recv', { t: 'Rückmeldung übernehmen', s: 'Gelaufener Weg, Markierungen und abgesuchte Felder erscheinen auf der Karte der Einsatzleitung.' , speed: 1.2 });
  await el.tap('#btn-teams', { wait: 600 });
  await el.tap('#recv-paste', { wait: 600 });
  await p.fill('#dlg-box textarea', back2.replace(LIVE, LOCAL));
  await sleep(500);
  await el.tap('#dlg-box button:has-text("Übernehmen")', { wait: 2000 });
  await p.evaluate(() => document.querySelectorAll('.panel:not([hidden]) .close').forEach((b) => b.click()));
  await sleep(300);
  await snap('recv');
  // Abschließen-Rückfrage o. ä. stehen lassen, kurz zeigen, dann schließen
  await el.pause(1500);
  await p.evaluate(() => { const b = [...document.querySelectorAll('#dlg-box button')].find((x) => /Noch offen|Später|Schließen|OK/i.test(x.textContent)); if (b && !document.getElementById('dlg').hidden) b.click(); });
  await map(([a, b]) => window.__app.map.flyTo([a, b], 16, { duration: 1 }), FOREST);
  await sleep(1800);
  await snap('recv2');

  await el.seg('status', { t: 'Alle Meldungen im Verlauf', s: 'Filter nach Team, Sprung zur Karte, Nachrichten an Teams – und „Wer ist noch draußen?“.' });
  await el.tap('#btn-status', { wait: 1800 });
  await snap('statuspanel');
  await el.pause(1200);
  await p.evaluate(() => document.querySelectorAll('.panel:not([hidden]) .close').forEach((b) => b.click()));
  await sleep(500);
  await el.endSeg();
  if (STOP === '7') return done(hf, jo);

  // ================= Kapitel 7: Wetter, Wind, Nacht =================
  card('c7', { num: '7', title: 'Wetter, Wind & Nacht', sub: 'Was im Gelände wirklich hilft' });
  await el.seg('wx2', { t: 'Wetter und Wind vom DWD', s: 'Windrichtung, Böen, Vorhersage, Sonnenuntergang und wann es dunkel wird.' });
  await el.tap('#quick-wx', { wait: 2600 });
  await snap('wxpanel');
  await el.pause(1000);
  await el.tap('#quick-arrows', { wait: 1800 });
  await snap('arrows');
  await el.tap('#quick-wx', { wait: 600 });
  await el.seg('night', { t: 'Nachtmodus', s: 'Dunkel oder rot – schont die Nachtsicht bei Einsätzen in der Dunkelheit.' });
  await el.tap('#quick-night', { wait: 1400 });
  await el.tap('#quick-night', { wait: 1600 });
  await snap('night');
  await el.tap('#quick-night', { wait: 800 });
  await el.endSeg();

  // ================= Kapitel 8: Bericht & Export =================
  card('c8', { num: '8', title: 'Bericht & Export', sub: 'PDF-Karten, GPX für Garmin, Einsatzbericht' });
  await el.seg('share', { t: 'Teilen – erst „An wen?“', s: 'Hundeführer, Unterabschnitt, weiteres EL-Gerät oder Sonstige: Polizei, Druck, Garmin.' , speed: 1.3 });
  await el.tap('#btn-pdf', { wait: 1200 });
  await el.tap('#share-to [data-to=other]', { wait: 1000 });
  await el.tap('#share-scopes [data-scope=all]', { wait: 1200 }).catch(() => {});
  await snap('share');
  await el.tap('#share-pdf', { wait: 1500 });
  await snap('export');
  const dlP = p.waitForEvent('download', { timeout: 90000 }).catch(() => null);
  await el.tap('#pdf-save', { wait: 1500 });
  const dl = await dlP;
  if (dl) await dl.saveAs('karte.pdf');
  await el.pause(800);
  await p.evaluate(() => document.querySelectorAll('.panel:not([hidden]) .close').forEach((b) => b.click()));
  await el.seg('report', { t: 'Einsatzende: Bericht auf Knopfdruck', s: 'Abschlussbericht mit Zeiten, Kräften und Einsatzzeiten – und das JUH-Formular, vorausgefüllt.' , speed: 1.4 });
  await el.tap('#btn-mission', { wait: 900 });
  await el.tap('[data-tab=ende]', { wait: 900 });
  await el.type('#ms-summary', '17:10 Suche begonnen (3 Teams).\n17:31 Fund durch Team Anna (Rex) in B3, Person ansprechbar, an RD übergeben.', { delay: 14 });
  await snap('report');
  const dl2P = p.waitForEvent('download', { timeout: 60000 }).catch(() => null);
  await el.tap('#ms-save', { wait: 1500 });
  const dl2 = await dl2P; if (dl2) await dl2.saveAs('bericht.pdf');
  const dl3P = p.waitForEvent('download', { timeout: 60000 }).catch(() => null);
  await el.tap('#ms-juh-save', { wait: 1500 });
  const dl3 = await dl3P; if (dl3) await dl3.saveAs('juh.pdf');
  await el.endSeg();

  // PDFs als Bilder zeigen
  try {
    const { execFileSync } = require('child_process');
    fs.mkdirSync('pdfimg', { recursive: true });
    const imgs = [];
    for (const [f, pages] of [['karte.pdf', '1-3'], ['bericht.pdf', '1-1'], ['juh.pdf', '1-1']]) {
      if (!fs.existsSync(f)) continue;
      const [a, b] = pages.split('-');
      execFileSync('pdftoppm', ['-png', '-r', '110', '-f', a, '-l', b, f, `pdfimg/${f.replace('.pdf', '')}`]);
    }
    for (const x of fs.readdirSync('pdfimg').sort()) imgs.push(`file://${__dirname}/pdfimg/${x}`);
    const order = ['karte', 'bericht', 'juh'];
    imgs.sort((a, b) => order.findIndex((o) => a.includes('/' + o)) - order.findIndex((o) => b.includes('/' + o)));
    const html = `<html><head><style>
      body{margin:0;width:1600px;height:900px;overflow:hidden;background:#e9ebef;font-family:Inter,sans-serif}
      .pg{position:absolute;top:50px;height:800px;box-shadow:0 12px 40px rgba(0,0,0,.28);background:#fff;opacity:0;transform:translateY(60px) scale(.96);transition:all .7s cubic-bezier(.2,.8,.2,1)}
      .pg.on{opacity:1;transform:none}
    </style></head><body>${imgs.map((u, i) => `<img class="pg" id="pg${i}" src="${u}" style="left:${90 + i * 290}px;z-index:${i}">`).join('')}</body></html>`;
    fs.writeFileSync('pdfs.html', html);
    const pdf = new Rec('pdf');
    const pp = await pdf.start(`file://${__dirname}/pdfs.html`);
    await sleep(800);
    await pdf.seg('pdfs', { t: 'Fertige PDFs zum Ausdrucken und Verschicken', s: 'Karte mit Raster und Teams, Einsatzinfos, Abschlussbericht, JUH-Formular – per Mail, WhatsApp oder Drucker.' });
    for (let i = 0; i < imgs.length; i++) { await pp.evaluate((i) => document.getElementById('pg' + i).classList.add('on'), i); await sleep(900); }
    await sleep(2200);
    await pdf.finish();
  } catch (e) { console.log('PDF-Bilder', e.message); }

  card('outro', { style: 'outro', feats: [['🗺️', 'Topo, Luftbild, Offline-Karten'], ['📐', 'Raster, Umrisse, Wald aufteilen'], ['📲', 'Aufträge per QR-Code'], ['📣', 'Live-Status & Fund-Alarm'], ['🧭', 'GPX für Garmin & BaseCamp'], ['📄', 'PDF, Bericht, JUH-Formular']] });
  saveOrder();
  await done(hf, jo);

  async function done(...more) {
    if (gpsTimer) clearInterval(gpsTimer);
    saveOrder();
    for (const r of more) if (r) await r.finish();
    await el.finish();
    saveOrder();
  }
})().catch((e) => { console.error(e); saveOrder(); process.exit(1); });
