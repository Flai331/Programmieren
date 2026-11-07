// Schnitt: Titelkarten (animiert), Layout mit Rahmen + Untertitel, ffmpeg-Zusammenbau
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

const DIR = __dirname;
const REC = path.join(DIR, process.env.REC_DIR || 'rec');
const BUILD = path.join(DIR, process.env.BUILD_DIR || 'build');
const OUTNAME = process.env.OUT_NAME || 'RHS-Einsatz-Film.mp4';
fs.mkdirSync(BUILD, { recursive: true });
const FPS = 30;
const W = 1920, H = 1080;
const ICON = 'data:image/png;base64,' + fs.readFileSync(path.join(__dirname, '..', 'web', 'icon-512.png')).toString('base64');
const ONLY = process.env.ONLY ? process.env.ONLY.split(',') : null;
// Sprecher (optional): NARR=datei.json mit { id: "Text" }, Stimme: Piper-Modell (VOICE)
const NARR = process.env.NARR ? JSON.parse(fs.readFileSync(process.env.NARR, 'utf8')) : {};
const VOICE = process.env.VOICE || path.join(DIR, 'tts', 'de_DE-thorsten-high.onnx');
const probe = (f) => Number(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f]).toString().trim());
function speak(id) {
  const text = NARR[id];
  if (!text) return null;
  const wav = path.join(BUILD, `tts_${id}.wav`), txt = wav + '.txt';
  if (!(fs.existsSync(wav) && fs.existsSync(txt) && fs.readFileSync(txt, 'utf8') === text)) {
    execFileSync('python3', ['-m', 'piper', '-m', VOICE, '-f', wav, '--length-scale', '1.04', '--sentence-silence', '0.3'], { input: text });
    fs.writeFileSync(txt, text);
  }
  return { wav, dur: probe(wav) };
}
// Tonspur: Sprecher ab 'delay' s, sonst Stille
const audioIn = (sp) => (sp ? ['-i', sp.wav] : ['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo']);
const audioFx = (n, sp, delay) => (sp ? `[${n}:a]aresample=48000,aformat=channel_layouts=stereo,adelay=${Math.round(delay * 1000)}|${Math.round(delay * 1000)},apad[aud]` : `[${n}:a]anull[aud]`);

const ff = (args) => execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...args], { stdio: 'inherit' });
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');

// Rechtecke der Bildschirme je Layout
const L = {
  tablet: { v: { x: 160, y: 22, w: 1600, h: 900, r: 18 } },
  phone: { v: { x: 1290, y: 50, w: 454, h: 982, r: 46 } },
  dual: { v: { x: 40, y: 40, w: 1352, h: 760, r: 16 }, v2: { x: 1452, y: 40, w: 423, h: 915, r: 42 } },
};

const BASE_CSS = `
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body { width: ${W}px; height: ${H}px; overflow: hidden; font-family: 'Inter', sans-serif; }
  body.bg { background: radial-gradient(1400px 900px at 20% 10%, #2a2f3a 0%, #15171c 60%, #0f1013 100%); }
  .hole { position: absolute; box-shadow: 0 0 0 4000px #15171c; }
  .ring { position: absolute; border: 2px solid rgba(255,255,255,.14); }
  .bezel { position: absolute; border: 12px solid #050506; box-shadow: 0 0 0 2px #3a3d45, 0 0 0 4000px #15171c; }
  .tag { display: inline-block; white-space: nowrap; background: #c62828; color: #fff; font-weight: 700; font-size: 22px; letter-spacing: .06em; text-transform: uppercase; padding: 6px 14px; border-radius: 8px; }
`;

function layerHtml(kind) {
  const rs = [L[kind].v, L[kind].v2].filter(Boolean);
  const isPhone = (i) => kind === 'phone' || (kind === 'dual' && i === 1);
  const holes = rs.map((r) => `<rect x="${r.x}" y="${r.y}" width="${r.w}" height="${r.h}" rx="${r.r}" fill="#000"/>`).join('');
  const deco = rs.map((r, i) => isPhone(i)
    ? `<rect x="${r.x - 7}" y="${r.y - 7}" width="${r.w + 14}" height="${r.h + 14}" rx="${r.r + 7}" fill="none" stroke="#050506" stroke-width="14"/><rect x="${r.x - 14}" y="${r.y - 14}" width="${r.w + 28}" height="${r.h + 28}" rx="${r.r + 14}" fill="none" stroke="#3a3d45" stroke-width="2"/>`
    : `<rect x="${r.x - 1}" y="${r.y - 1}" width="${r.w + 2}" height="${r.h + 2}" rx="${r.r + 1}" fill="none" stroke="rgba(255,255,255,.16)" stroke-width="2"/>`).join('');
  return `<html><head><style>${BASE_CSS} body{background:transparent}</style></head><body>
    <svg width="${W}" height="${H}" style="position:absolute;inset:0"><defs>
      <radialGradient id="g" cx="20%" cy="10%" r="90%"><stop offset="0" stop-color="#2a2f3a"/><stop offset=".6" stop-color="#15171c"/><stop offset="1" stop-color="#0f1013"/></radialGradient>
      <mask id="m"><rect width="${W}" height="${H}" fill="#fff"/>${holes}</mask></defs>
      <rect width="${W}" height="${H}" fill="url(#g)" mask="url(#m)"/>${deco}</svg></body></html>`;
}

function capHtml(kind, cap, chapter) {
  let box;
  const clk = cap.clock ? `<span style="display:inline-flex;align-items:center;gap:10px;background:#fff;color:#15171c;font-weight:800;font-size:30px;padding:6px 16px;border-radius:10px;font-variant-numeric:tabular-nums">🕒 ${esc(cap.clock)}</span>` : '';
  if (kind === 'tablet') box = `<div style="position:absolute;left:160px;top:944px;width:1600px;display:flex;align-items:baseline;gap:22px">
      <span class="tag">${esc(chapter)}</span>
      <div><div style="color:#fff;font-weight:700;font-size:40px;line-height:1.15">${esc(cap.t)}</div>
      <div style="color:#c8ccd4;font-size:28px;line-height:1.35;margin-top:6px">${esc(cap.s)}</div></div></div>
      <div style="position:absolute;right:160px;top:940px">${clk}</div>`;
  else if (kind === 'phone') box = `<div style="position:absolute;left:150px;top:0;width:1000px;height:${H}px;display:flex;flex-direction:column;justify-content:center;gap:26px">
      <div style="display:flex;gap:16px;align-items:center">${clk}<span class="tag">${esc(chapter)}</span></div>
      <div style="color:#fff;font-weight:800;font-size:66px;line-height:1.1">${esc(cap.t)}</div>
      <div style="color:#c8ccd4;font-size:38px;line-height:1.4">${esc(cap.s)}</div></div>`;
  else box = `<div style="position:absolute;left:40px;top:826px;width:1352px">
      <div style="display:flex;gap:18px;align-items:center">${clk}<span class="tag">${esc(chapter)}</span>
      <div style="color:#fff;font-weight:700;font-size:40px">${esc(cap.t)}</div></div>
      <div style="color:#c8ccd4;font-size:29px;line-height:1.38;margin-top:12px">${esc(cap.s)}</div></div>`;
  return `<html><head><style>${BASE_CSS} body{background:transparent}</style></head><body>${box}</body></html>`;
}

function cardHtml(c) {
  const anim = `
    @keyframes up { from { opacity: 0; transform: translateY(40px) } to { opacity: 1; transform: none } }
    @keyframes pop { 0% { opacity: 0; transform: scale(.6) rotate(-8deg) } 70% { transform: scale(1.06) } 100% { opacity: 1; transform: none } }
    @keyframes line { from { width: 0 } to { width: 260px } }
    @keyframes fadeout { to { opacity: 0 } }
    @keyframes blink { 50% { opacity: .25 } }
    @keyframes drift { from { transform: translate(0,0) scale(1) } to { transform: translate(-60px,-30px) scale(1.08) } }
    .a { opacity: 0; animation: up .7s cubic-bezier(.2,.8,.2,1) forwards; }
    .grid { position: absolute; inset: -100px; background-image: linear-gradient(rgba(255,255,255,.05) 2px, transparent 2px), linear-gradient(90deg, rgba(255,255,255,.05) 2px, transparent 2px); background-size: 120px 120px; animation: drift ${c.dur}s linear forwards; }
    .wrap { position: absolute; inset: 0; animation: fadeout .45s ease-in ${c.dur - 0.45}s forwards; }
    .in { position: absolute; inset: 0; background: #000; animation: fadeout .4s ease-out forwards; }
  `;
  let body;
  if (c.style === 'intro') {
    body = `<div class="grid"></div><div class="wrap" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:30px">
      <img src="${ICON}" style="width:230px;height:230px;border-radius:48px;box-shadow:0 20px 60px rgba(0,0,0,.5);opacity:0;animation:pop .9s .2s cubic-bezier(.2,.8,.2,1) forwards">
      <div class="a" style="animation-delay:.8s;color:#fff;font-size:120px;font-weight:800;letter-spacing:-.02em">RHS Einsatz</div>
      <div style="height:6px;background:#c62828;border-radius:3px;width:0;animation:line .8s 1.2s ease-out forwards"></div>
      <div class="a" style="animation-delay:1.4s;color:#d6d9df;font-size:46px">${esc(c.sub || 'Die Einsatz-App für Rettungshundestaffeln')}</div>
      <div class="a" style="animation-delay:2.0s;color:#9aa0aa;font-size:32px">${esc(c.sub2 || 'Einsatzleitung · Hundeführer · Bericht – in einer App')}</div></div>`;
  } else if (c.style === 'outro') {
    const feats = c.feats.map((f, i) => `<div class="a" style="animation-delay:${0.6 + i * 0.12}s;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);border-radius:16px;padding:22px 26px;color:#e8eaee;font-size:30px;display:flex;gap:16px;align-items:center"><span style="font-size:40px">${f[0]}</span>${esc(f[1])}</div>`).join('');
    body = `<div class="grid"></div><div class="wrap" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:40px;padding:0 140px">
      <div class="a" style="display:flex;align-items:center;gap:30px"><img src="${ICON}" style="width:120px;height:120px;border-radius:26px"><span style="color:#fff;font-size:90px;font-weight:800">RHS Einsatz</span></div>
      <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:20px;width:100%">${feats}</div>
      <div class="a" style="animation-delay:${0.8 + c.feats.length * 0.12}s;color:#fff;font-size:38px;font-weight:600;background:#c62828;padding:16px 34px;border-radius:14px">flai331.github.io/Programmieren/suchgebiet-karten</div>
      <div class="a" style="animation-delay:${1.0 + c.feats.length * 0.12}s;color:#9aa0aa;font-size:28px">Kostenlos · im Browser oder als Android-App · funktioniert auch offline</div></div>`;
  } else if (c.style === 'alarm') {
    const lines = c.lines.map((l, i) => `<div class="a" style="animation-delay:${1.1 + i * 0.35}s;color:#e8eaee;font-size:40px;line-height:1.35;margin-top:6px">${esc(l)}</div>`).join('');
    body = `<div class="grid"></div><div class="wrap" style="display:flex;align-items:center;justify-content:center">
      <div style="width:1300px;background:#1f232b;border:2px solid #c62828;border-radius:26px;padding:50px 64px;box-shadow:0 30px 90px rgba(0,0,0,.6);opacity:0;animation:pop .7s .15s cubic-bezier(.2,.8,.2,1) forwards">
        <div style="display:flex;align-items:center;gap:22px"><span style="font-size:64px;animation:blink 1s steps(2) infinite">🚨</span>
          <span style="color:#ff5252;font-size:34px;font-weight:800;letter-spacing:.12em">ALARMIERUNG</span>
          <span style="margin-left:auto;color:#fff;font-size:56px;font-weight:800;font-variant-numeric:tabular-nums">${esc(c.time)}</span></div>
        <div class="a" style="animation-delay:.6s;color:#fff;font-size:62px;font-weight:800;margin:26px 0 14px">${esc(c.head)}</div>${lines}
        <div class="a" style="animation-delay:${1.4 + c.lines.length * 0.35}s;color:#8a909a;font-size:26px;margin-top:30px">${esc(c.note || '')}</div></div></div>`;
  } else if (c.style === 'story') {
    const lines = c.lines.map((l, i) => `<div class="a" style="animation-delay:${0.5 + i * 0.6}s;color:${i ? '#c8ccd4' : '#fff'};font-size:${i ? 40 : 58}px;font-weight:${i ? 400 : 800};line-height:1.35;margin-top:${i ? 18 : 0}px">${esc(l)}</div>`).join('');
    body = `<div class="grid"></div><div class="wrap" style="display:flex;flex-direction:column;justify-content:center;padding:0 240px">${lines}</div>`;
  } else {
    body = `<div class="grid"></div><div class="wrap" style="display:flex;align-items:center;padding-left:240px;gap:60px">
      <div style="font-size:${String(c.num).length > 2 ? 200 : 300}px;font-weight:800;color:#c62828;line-height:1;opacity:0;animation:pop .8s .1s cubic-bezier(.2,.8,.2,1) forwards">${esc(c.num)}</div>
      <div><div class="a" style="animation-delay:.35s;color:#fff;font-size:96px;font-weight:800;letter-spacing:-.01em">${esc(c.title)}</div>
      <div style="height:6px;background:#c62828;border-radius:3px;width:0;margin:26px 0;animation:line .7s .6s ease-out forwards"></div>
      <div class="a" style="animation-delay:.75s;color:#c8ccd4;font-size:44px">${esc(c.sub)}</div></div></div>`;
  }
  return `<html><head><style>${BASE_CSS}${anim}</style></head><body class="bg">${body}<div class="in"></div></body></html>`;
}

async function renderCards(browser, cards) {
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  for (const c of cards) {
    const out = path.join(BUILD, `${c.id}.mp4`);
    if (ONLY && !ONLY.includes(c.id)) continue;
    const sig = path.join(BUILD, `${c.id}.sig`);
    const want = `${c.dur.toFixed(2)}|${NARR[c.id] || ''}`;
    if (fs.existsSync(out) && !process.env.CARDS && fs.existsSync(sig) && fs.readFileSync(sig, 'utf8') === want) continue;
    const fdir = path.join(BUILD, `frames_${c.id}`);
    fs.rmSync(fdir, { recursive: true, force: true }); fs.mkdirSync(fdir);
    await page.setContent(cardHtml(c));
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(300);
    const n = Math.round(c.dur * FPS);
    for (let i = 0; i < n; i++) {
      const t = (i / FPS) * 1000;
      await page.evaluate((t) => document.getAnimations().forEach((a) => { a.pause(); a.currentTime = t; }), t);
      await page.screenshot({ path: path.join(fdir, `${String(i).padStart(4, '0')}.jpg`), type: 'jpeg', quality: 92 });
    }
    const sp = speak(c.id);
    ff(['-framerate', String(FPS), '-i', path.join(fdir, '%04d.jpg'), ...audioIn(sp), '-filter_complex', audioFx(1, sp, 0.5), '-map', '0:v', '-map', '[aud]',
      '-t', c.dur.toFixed(3), '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-r', String(FPS), '-c:a', 'aac', '-ar', '48000', '-ac', '2', out]);
    fs.writeFileSync(sig, want);
    fs.rmSync(fdir, { recursive: true, force: true });
    console.log('Karte', c.id);
  }
  await page.close();
}

async function png(browser, html, file, transparent) {
  for (let i = 0; ; i++) {
    const page = await browser.newPage({ viewport: { width: W, height: H } });
    try {
      await page.setContent(html);
      await page.evaluate(() => document.fonts.ready);
      await page.screenshot({ path: file, omitBackground: !!transparent });
      return;
    } catch (e) { if (i >= 3) throw e; await new Promise((r) => setTimeout(r, 500)); } finally { await page.close().catch(() => {}); }
  }
}

// Bildfolge eines Abschnitts -> concat-Liste (Zeit ab t0, optional schneller)
const sizeOf = (file) => { const b = fs.readFileSync(file); for (let i = 2; i < b.length - 9;) { if (b[i] !== 0xff) { i++; continue; } const m = b[i + 1]; if (m >= 0xc0 && m <= 0xc2) return `${b.readUInt16BE(i + 7)}x${b.readUInt16BE(i + 5)}`; i += 2 + b.readUInt16BE(i + 2); } return '?'; };
function concatList(seg, file, speed = 1, t0 = seg.t0, t1 = seg.t1) {
  // Bilder mit abweichender Größe (einzelne Vollbilder des Screencasts) weglassen – sonst bricht concat ab
  const sizes = seg.frames.map((f) => sizeOf(f.file));
  const cnt = {}; sizes.forEach((x) => { cnt[x] = (cnt[x] || 0) + 1; });
  const main = Object.keys(cnt).sort((a, b) => cnt[b] - cnt[a])[0];
  const fr = seg.frames.filter((f, i) => f.t <= t1 && sizes[i] === main);
  if (!fr.length) throw new Error('keine Bilder: ' + seg.id);
  let s = '';
  for (let i = 0; i < fr.length; i++) {
    const a = i === 0 ? t0 : fr[i].t;
    const b = i + 1 < fr.length ? fr[i + 1].t : t1;
    s += `file '${fr[i].file}'\nduration ${Math.max(0.001, (b - a) / speed).toFixed(4)}\n`;
  }
  s += `file '${fr[fr.length - 1].file}'\n`;
  fs.writeFileSync(file, s);
  return (t1 - t0) / speed;
}

if (process.env.PREVIEW) {
  (async () => {
    const b = await chromium.launch();
    const pg = await b.newPage({ viewport: { width: W, height: H } });
    const show = async (html, file, t) => { await pg.setContent(html); await pg.evaluate(() => document.fonts.ready); await pg.evaluate((t) => document.getAnimations().forEach((a) => { a.pause(); a.currentTime = t; }), t || 0); await pg.screenshot({ path: file }); };
    await show(cardHtml({ style: 'intro', dur: 4.6 }), 'pv_intro.png', 3000);
    await show(cardHtml({ num: '2', title: 'Raster, Teams, Suchgebiete', sub: 'Gebiete planen und Teams zuteilen', dur: 2.8 }), 'pv_card.png', 1800);
    await show(cardHtml({ style: 'outro', dur: 7, feats: [['🗺️', 'Topo, Luftbild, Offline-Karten'], ['📐', 'Raster, Umrisse, Wald aufteilen'], ['📲', 'Aufträge per QR-Code'], ['📣', 'Live-Status & Fund-Alarm'], ['🧭', 'GPX für Garmin & BaseCamp'], ['📄', 'PDF, Bericht, JUH-Formular']] }), 'pv_outro.png', 4000);
    const cap = { t: 'Felder zuteilen', s: 'Team wählen und mit dem Finger über die Felder wischen.' };
    for (const k of ['tablet', 'phone', 'dual']) {
      await pg.setContent(`<html><body style="margin:0;background:#3a7">${''}</body></html>`);
      await show(layerHtml(k).replace('</body>', capHtml(k, cap, '2 · Raster, Teams').match(/<body>([\s\S]*)<\/body>/)[1] + '</body>'), `pv_${k}.png`);
    }
    await b.close();
  })();
} else (async () => {
  const order = JSON.parse(fs.readFileSync(path.join(REC, 'order.json'), 'utf8'));
  const segs = {};
  for (const f of fs.readdirSync(REC).filter((x) => x.endsWith('.json') && x !== 'order.json')) {
    for (const s of JSON.parse(fs.readFileSync(path.join(REC, f), 'utf8'))) segs[s.id] = s;
  }
  const browser = await chromium.launch();
  const cards = order.filter((o) => o.kind === 'card').map((c) => ({ ...c, dur: c.dur || (c.style === 'intro' ? 4.6 : c.style === 'outro' ? 7 : c.style === 'alarm' ? 7 : c.style === 'story' ? 7.5 : 2.8) }));
  for (const c of cards) { const sp = speak(c.id); if (sp) c.dur = Math.max(c.dur, sp.dur + 1.3); }
  await renderCards(browser, cards);

  let chapter = '';
  const parts = [];
  for (const o of order) {
    if (o.kind === 'card') { parts.push(path.join(BUILD, `${o.id}.mp4`)); if (o.title) chapter = o.style === 'time' ? o.title : `${o.num} · ${o.title}`; continue; }
    const out = path.join(BUILD, `${o.id}.mp4`);
    parts.push(out);
    if (ONLY && !ONLY.includes(o.id)) continue;
    const cap = o.caption || { t: '', s: '' };
    let speed = cap.speed || 1;
    const layer = path.join(BUILD, `layer_${o.kind}.png`);
    if (!fs.existsSync(layer)) await png(browser, layerHtml(o.kind), layer, true);
    const capf = path.join(BUILD, `cap_${o.id}.png`);
    await png(browser, capHtml(o.kind, cap, chapter), capf, true);
    const fade = 'format=rgba,fade=in:st=0:d=0.45:alpha=1';
    const sp = speak(o.id);
    if (sp && speed > 1) {
      const real = o.kind === 'dual' ? Math.min(segs[o.a].t1, segs[o.b].t1) - Math.max(segs[o.a].t0, segs[o.b].t0) : segs[o.id].t1 - segs[o.id].t0;
      const need = sp.dur + 0.8;
      if (real / speed < need) speed = Math.max(1, real / need);
    }
    let dur, inputs, fc;
    if (o.kind === 'dual') {
      const a = segs[o.a], b = segs[o.b];
      const t0 = Math.max(a.t0, b.t0), t1 = Math.min(a.t1, b.t1);
      const la = path.join(BUILD, `${o.id}_a.txt`), lb = path.join(BUILD, `${o.id}_b.txt`);
      dur = concatList(a, la, speed, t0, t1); concatList(b, lb, speed, t0, t1);
      const v = L.dual.v, v2 = L.dual.v2;
      var total = Math.max(dur, sp ? sp.dur + 0.8 : 0), pad = total > dur + 0.05 ? `,tpad=stop_mode=clone:stop_duration=${(total - dur + 0.2).toFixed(2)}` : '';
      inputs = ['-f', 'concat', '-safe', '0', '-i', la, '-f', 'concat', '-safe', '0', '-i', lb, '-loop', '1', '-i', layer, '-loop', '1', '-i', capf];
      fc = `color=c=#15171c:s=${W}x${H}:r=${FPS}[bg];[0:v]fps=${FPS},scale=${v.w}:${v.h}:flags=lanczos${pad}[va];[1:v]fps=${FPS},scale=${v2.w}:${v2.h}:flags=lanczos${pad}[vb];`
        + `[bg][va]overlay=${v.x}:${v.y}:shortest=1[t1];[t1][vb]overlay=${v2.x}:${v2.y}[t2];[t2][2:v]overlay=0:0[t3];[3:v]${fade}[c];[t3][c]overlay=0:0,format=yuv420p[out]`;
    } else {
      const s = segs[o.id];
      const lf = path.join(BUILD, `${o.id}.txt`);
      dur = concatList(s, lf, speed);
      const v = L[o.kind].v;
      var total = Math.max(dur, sp ? sp.dur + 0.8 : 0), pad = total > dur + 0.05 ? `,tpad=stop_mode=clone:stop_duration=${(total - dur + 0.2).toFixed(2)}` : '';
      inputs = ['-f', 'concat', '-safe', '0', '-i', lf, '-loop', '1', '-i', layer, '-loop', '1', '-i', capf];
      fc = `color=c=#15171c:s=${W}x${H}:r=${FPS}[bg];[0:v]fps=${FPS},scale=${v.w}:${v.h}:flags=lanczos${pad}[va];`
        + `[bg][va]overlay=${v.x}:${v.y}:shortest=1[t1];[t1][1:v]overlay=0:0[t2];[2:v]${fade}[c];[t2][c]overlay=0:0,format=yuv420p[out]`;
    }
    const an = o.kind === 'dual' ? 4 : 3;
    ff([...inputs, ...audioIn(sp), '-filter_complex', `${fc};${audioFx(an, sp, 0.3)}`, '-map', '[out]', '-map', '[aud]',
      '-t', total.toFixed(3), '-r', String(FPS), '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-ar', '48000', '-ac', '2', out]);
    console.log('Abschnitt', o.id, total.toFixed(1) + ' s', sp ? `(Sprecher ${sp.dur.toFixed(1)} s)` : '');
  }
  await browser.close();
  const list = path.join(BUILD, 'parts.txt');
  fs.writeFileSync(list, parts.filter((p) => fs.existsSync(p)).map((p) => `file '${p}'`).join('\n'));
  ff(['-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', '-movflags', '+faststart', path.join(DIR, OUTNAME)]);
  const d = execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path.join(DIR, OUTNAME)]).toString().trim();
  console.log('Fertig:', d, 's');
})().catch((e) => { console.error(e); process.exit(1); });
