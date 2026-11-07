// Aufnahme-Gerüst: Seite steuern, Finger einblenden, Bilder per CDP-Screencast mitschneiden.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const OUT = path.join(__dirname, 'rec');
fs.mkdirSync(OUT, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const FINGER_JS = `
(() => {
  if (window.__finger) return;
  const add = () => {
    const st = document.createElement('style');
    st.textContent = \`
      #__f { position: fixed; left: 0; top: 0; width: 46px; height: 46px; margin: -23px 0 0 -23px; border-radius: 50%;
        background: rgba(255,255,255,.35); border: 3px solid rgba(20,20,20,.55); box-shadow: 0 3px 12px rgba(0,0,0,.35);
        z-index: 2147483647; pointer-events: none; opacity: 0; transition: opacity .25s, transform .12s;
        will-change: left, top; }
      #__f.down { transform: scale(.78); background: rgba(255,210,60,.55); }
      .__rip { position: fixed; width: 20px; height: 20px; margin: -10px 0 0 -10px; border-radius: 50%;
        border: 4px solid rgba(255,200,40,.95); z-index: 2147483646; pointer-events: none;
        animation: __rip .55s ease-out forwards; }
      @keyframes __rip { from { transform: scale(.6); opacity: 1 } to { transform: scale(4.2); opacity: 0 } }
    \`;
    document.head.appendChild(st);
    const f = document.createElement('div'); f.id = '__f'; document.body.appendChild(f);
    window.__finger = {
      show(x, y) { f.style.left = x + 'px'; f.style.top = y + 'px'; f.style.opacity = 1; },
      hide() { f.style.opacity = 0; },
      move(x, y) { f.style.left = x + 'px'; f.style.top = y + 'px'; },
      down(on) { f.classList.toggle('down', on); },
      ripple(x, y) { const r = document.createElement('div'); r.className = '__rip'; r.style.left = x + 'px'; r.style.top = y + 'px';
        document.body.appendChild(r); setTimeout(() => r.remove(), 700); },
    };
  };
  if (document.body) add(); else document.addEventListener('DOMContentLoaded', add);
})();
`;

// Gemeinsame Reihenfolge aller Abschnitte (über alle Geräte)
const ORDER = [];
// Nachgebildeter Status-Server (Google Apps Script): Zeilen [zeit, id, daten] je Raum
const ROOMS = {};
let lastT = 0;
async function fakeServer(route) {
  const req = route.request();
  const url = new URL(req.url());
  if (req.method() === 'POST') {
    let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch {}
    if (b.rep) return route.fulfill({ status: 200, contentType: 'application/json', body: '{"ok":true}' });
    const rows = ROOMS[b.r] = ROOMS[b.r] || [];
    if (!rows.some((x) => x[1] === b.id)) { lastT = Math.max(lastT + 1, Date.now()); rows.push([lastT, b.id, b.d]); }
    return route.fulfill({ status: 200, contentType: 'application/json', body: '{"ok":true}' });
  }
  if (url.searchParams.get('lic')) return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ ok: true, aktiv: true, gesperrt: false }) });
  const r = url.searchParams.get('r');
  if (!r) return route.fulfill({ status: 200, contentType: 'application/json', body: '{"ok":true}' });
  const since = Number(url.searchParams.get('since')) || 0;
  const rows = (ROOMS[r] || []).filter((x) => x[0] > since);
  return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ ok: true, now: Date.now(), rows }) });
}

class Rec {
  constructor(name, { width = 1600, height = 900, scale = 1, mobile = false } = {}) {
    this.name = name; this.width = width; this.height = height; this.scale = scale; this.mobile = mobile;
    this.segments = []; this.cur = null; this.fx = width / 2; this.fy = height / 2; this.fingerOn = false;
  }
  async start(url = 'http://localhost:8765/', initState) {
    this.browser = await chromium.launch({ args: ['--lang=de-DE'] });
    this.ctx = await this.browser.newContext({
      viewport: { width: this.width, height: this.height }, deviceScaleFactor: this.scale,
      isMobile: this.mobile, hasTouch: this.mobile, locale: 'de-DE', timezoneId: 'Europe/Berlin',
      geolocation: { latitude: 52.6705, longitude: 10.0985 }, permissions: ['geolocation'],
    });
    this.page = await this.ctx.newPage();
    await this.page.route(/overpass/, (r) => r.abort());
    await this.page.route(/script\.google\.com/, fakeServer);
    await this.page.addInitScript(FINGER_JS);
    if (initState) await this.page.addInitScript(initState);
    this.page.on('pageerror', (e) => console.log('PAGEERR', e.message));
    this.page.on('dialog', (d) => d.accept());
    await this.page.goto(url);
    this.cdp = await this.ctx.newCDPSession(this.page);
    this.cdp.on('Page.screencastFrame', async (ev) => {
      try { await this.cdp.send('Page.screencastFrameAck', { sessionId: ev.sessionId }); } catch {}
      if (!this.cur) return;
      const n = this.cur.frames.length;
      const file = path.join(OUT, `${this.cur.id}_${String(n).padStart(5, '0')}.jpg`);
      fs.writeFileSync(file, Buffer.from(ev.data, 'base64'));
      this.cur.frames.push({ t: Date.now() / 1000, file });
    });
    return this.page;
  }
  // Abschnitt mit eigenem Untertitel beginnen (beendet den vorigen)
  async seg(id, caption = null, { noOrder = false } = {}) {
    await this.endSeg();
    this.cur = { id: `${this.name}-${id}`, kind: this.mobile ? 'phone' : 'tablet', caption, frames: [], t0: Date.now() / 1000 };
    if (!noOrder) ORDER.push({ id: this.cur.id, kind: this.cur.kind, caption });
    await this.cdp.send('Page.startScreencast', { format: 'jpeg', quality: 90,
      maxWidth: Math.round(this.width * this.scale), maxHeight: Math.round(this.height * this.scale), everyNthFrame: 1 });
    // ersten Frame erzwingen
    await this.page.evaluate(() => { document.body.style.outline = '0px solid transparent'; requestAnimationFrame(() => { document.body.style.outline = ''; }); });
    await sleep(120);
  }
  async endSeg() {
    if (!this.cur) return;
    await sleep(80);
    await this.cdp.send('Page.stopScreencast');
    this.cur.t1 = Date.now() / 1000;
    this.segments.push(this.cur);
    this.cur = null;
  }
  async finish() {
    await this.endSeg();
    fs.writeFileSync(path.join(OUT, `${this.name}.json`), JSON.stringify(this.segments, null, 1));
    await this.browser.close();
  }
  // ---- Finger ----
  async fingerTo(x, y, ms = 650) {
    const p = this.page;
    if (!this.fingerOn) { await p.evaluate(([x, y]) => window.__finger.show(x, y), [x, y]); this.fingerOn = true; this.fx = x; this.fy = y; await sleep(250); return; }
    const steps = Math.max(8, Math.round(ms / 16));
    const x0 = this.fx, y0 = this.fy;
    for (let i = 1; i <= steps; i++) {
      const k = i / steps, e = k < .5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
      const xx = x0 + (x - x0) * e, yy = y0 + (y - y0) * e;
      await p.evaluate(([a, b]) => window.__finger.move(a, b), [xx, yy]);
      await sleep(ms / steps);
    }
    this.fx = x; this.fy = y;
  }
  async fingerHide() { await this.page.evaluate(() => window.__finger.hide()); this.fingerOn = false; }
  async boxOf(target) {
    const loc = typeof target === 'string' ? this.page.locator(target).first() : target;
    await loc.waitFor({ state: 'visible', timeout: 8000 });
    await loc.scrollIntoViewIfNeeded();
    const b = await loc.boundingBox();
    return { loc, x: b.x + b.width / 2, y: b.y + b.height / 2, b };
  }
  // Antippen: Finger hin, Welle, echter Klick
  async tap(target, { wait = 700, ms = 650, real = true } = {}) {
    let x, y, loc = null;
    if (Array.isArray(target)) [x, y] = target; else ({ loc, x, y } = await this.boxOf(target));
    await this.fingerTo(x, y, ms);
    await this.page.evaluate(([x, y]) => { window.__finger.down(true); window.__finger.ripple(x, y); }, [x, y]);
    await sleep(110);
    if (real) { if (loc) await loc.click(); else await this.page.mouse.click(x, y); }
    await this.page.evaluate(() => window.__finger.down(false));
    await sleep(wait);
  }
  async type(target, text, { delay = 75, clear = true } = {}) {
    const { loc } = await this.boxOf(target);
    await this.tap(loc, { wait: 200 });
    if (clear) await loc.fill('');
    await loc.pressSequentially(text, { delay });
    await sleep(300);
  }
  // Ziehen entlang Punkten (Maus gedrückt), Finger folgt
  async drag(points, { ms = 1200, wait = 500 } = {}) {
    const p = this.page;
    await this.fingerTo(points[0][0], points[0][1], 500);
    await p.mouse.move(points[0][0], points[0][1]);
    await p.evaluate(() => window.__finger.down(true));
    await p.mouse.down();
    // gleichmäßig über alle Teilstrecken
    const segs = [];
    let total = 0;
    for (let i = 1; i < points.length; i++) { const d = Math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1]); segs.push(d); total += d; }
    const steps = Math.max(12, Math.round(ms / 16));
    for (let s = 1; s <= steps; s++) {
      let dist = total * s / steps, i = 0;
      while (i < segs.length - 1 && dist > segs[i]) { dist -= segs[i]; i++; }
      const k = segs[i] ? Math.min(1, dist / segs[i]) : 1;
      const x = points[i][0] + (points[i + 1][0] - points[i][0]) * k;
      const y = points[i][1] + (points[i + 1][1] - points[i][1]) * k;
      await p.mouse.move(x, y);
      await p.evaluate(([a, b]) => window.__finger.move(a, b), [x, y]);
      this.fx = x; this.fy = y;
      await sleep(ms / steps);
    }
    await p.mouse.up();
    await p.evaluate(() => window.__finger.down(false));
    await sleep(wait);
  }
  async pause(ms) { await sleep(ms); }
  async shot(file) { await this.page.screenshot({ path: path.join(__dirname, file) }); }
}

// Zwei Geräte gleichzeitig (Tablet links, Handy rechts)
async function dual(tab, phone, id, caption) {
  await tab.seg(id, caption, { noOrder: true });
  await phone.seg(id, caption, { noOrder: true });
  ORDER.push({ id: `dual-${id}`, kind: 'dual', a: `${tab.name}-${id}`, b: `${phone.name}-${id}`, caption });
}
function card(id, data) { ORDER.push({ id, kind: 'card', ...data }); }
function saveOrder() { fs.writeFileSync(path.join(OUT, 'order.json'), JSON.stringify(ORDER, null, 1)); }

module.exports = { Rec, sleep, OUT, dual, card, saveOrder, ORDER };
