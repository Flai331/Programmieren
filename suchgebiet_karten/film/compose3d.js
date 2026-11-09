// 3D-Fassung: Tablet und Handy als Geräte im Raum (CSS-3D), Kamerafahrten je Szene, die App-Aufnahme läuft auf den Bildschirmen.
// Aufruf: REC_DIR=rec-einsatz OUT_NAME=RHS-Einsatz-Scheuen-3D-ohne-Ton.mp4 node compose3d.js   (PREVIEW=1: nur Probebilder)
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { chromium } = require('playwright');

const DIR = __dirname;
const REC = path.join(DIR, process.env.REC_DIR || 'rec-einsatz');
const OUT = path.join(DIR, process.env.OUT_NAME || 'RHS-Einsatz-Scheuen-3D-ohne-Ton.mp4');
const FPS = 25, W = 1920, H = 1080;
const ICON = 'data:image/png;base64,' + fs.readFileSync(path.join(DIR, '..', 'web', 'icon-512.png')).toString('base64');
const CARD_DUR = { intro: 4.6, alarm: 7.5, time: 3.0, story: 7.5, outro: 7.5 };
const TRANS = 1.0; // Kamerafahrt zwischen Szenen (s)

// ---------- Zeitplan ----------
const order = JSON.parse(fs.readFileSync(path.join(REC, 'order.json'), 'utf8'));
const segs = {};
for (const f of fs.readdirSync(REC).filter((x) => x.endsWith('.json') && x !== 'order.json')) for (const s of JSON.parse(fs.readFileSync(path.join(REC, f), 'utf8'))) segs[s.id] = s;
const sizeOf = (file) => { const b = fs.readFileSync(file); for (let i = 2; i < b.length - 9;) { if (b[i] !== 0xff) { i++; continue; } const m = b[i + 1]; if (m >= 0xc0 && m <= 0xc2) return `${b.readUInt16BE(i + 7)}x${b.readUInt16BE(i + 5)}`; i += 2 + b.readUInt16BE(i + 2); } return '?'; };
function clean(seg) { // Bilder mit abweichender Größe weglassen
  if (seg._fr) return seg._fr;
  const sizes = seg.frames.map((f) => sizeOf(f.file));
  const cnt = {}; sizes.forEach((x) => { cnt[x] = (cnt[x] || 0) + 1; });
  const main = Object.keys(cnt).sort((a, b) => cnt[b] - cnt[a])[0];
  seg._fr = seg.frames.filter((f, i) => sizes[i] === main);
  return seg._fr;
}
function frameAt(seg, t) { // letztes Bild mit Zeit <= t (binäre Suche)
  const fr = clean(seg);
  let lo = 0, hi = fr.length - 1;
  while (lo < hi) { const m = (lo + hi + 1) >> 1; if (fr[m].t <= t) lo = m; else hi = m - 1; }
  return 'file://' + fr[lo].file;
}
let chapter = '', T = 0;
const items = order.map((o) => {
  const it = { ...o, start: T };
  if (o.kind === 'card') {
    it.style = o.style || 'time';
    it.dur = CARD_DUR[it.style] || 3;
    if (o.title) chapter = o.title;
  } else {
    it.speed = (o.caption && o.caption.speed) || 1;
    if (o.kind === 'dual') { it.t0 = Math.max(segs[o.a].t0, segs[o.b].t0); it.t1 = Math.min(segs[o.a].t1, segs[o.b].t1); } else { it.t0 = segs[o.id].t0; it.t1 = segs[o.id].t1; }
    it.dur = (it.t1 - it.t0) / it.speed + 0.4; // kurzer Nachlauf
    it.chapter = chapter;
    it.dev = o.kind === 'dual' ? { tab: segs[o.a], ph: segs[o.b] } : o.kind === 'phone' ? { ph: segs[o.id] } : { tab: segs[o.id] };
  }
  T += it.dur;
  return it;
});
const TOTAL = T;
fs.writeFileSync(path.join(DIR, 'offsets-3d.json'), JSON.stringify({ total: TOTAL, at: Object.fromEntries(items.map((i) => [i.id, i.start])) }));

// ---------- Kamera-/Gerätestellungen ----------
const POSE = {
  tablet: { tab: { x: 0, y: -40, z: 0, ry: -9, rx: 5, s: 0.8, op: 1 }, ph: { x: 1250, y: -20, z: -400, ry: -32, rx: 4, s: 0.7, op: 0 } },
  phone: { tab: { x: -470, y: -40, z: -520, ry: 24, rx: 5, s: 0.8, op: 0.38 }, ph: { x: 300, y: -45, z: 120, ry: -13, rx: 4, s: 0.78, op: 1 } },
  dual: { tab: { x: -255, y: -55, z: -80, ry: 10, rx: 5, s: 0.7, op: 1 }, ph: { x: 650, y: -55, z: 60, ry: -16, rx: 4, s: 0.7, op: 1 } },
  card: { tab: { x: -330, y: -10, z: -950, ry: 20, rx: 7, s: 0.8, op: 0.09 }, ph: { x: 560, y: -10, z: -950, ry: -20, rx: 7, s: 0.7, op: 0.09 } },
};
const ease = (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2);
const lerpObj = (a, b, k) => Object.fromEntries(Object.keys(a).map((n) => [n, a[n] + (b[n] - a[n]) * k]));
const poseOf = (it) => POSE[it.kind === 'card' ? 'card' : it.kind];

function stateAt(t) {
  let i = items.findIndex((x) => t < x.start + x.dur);
  if (i < 0) i = items.length - 1;
  const it = items[i], lt = t - it.start;
  const prev = items[i - 1];
  const k = prev ? ease(Math.min(1, lt / TRANS)) : 1;
  const a = prev ? poseOf(prev) : poseOf(it), b = poseOf(it);
  const tab = lerpObj(a.tab, b.tab, k), ph = lerpObj(a.ph, b.ph, k);
  // leichtes Schweben
  tab.ry += Math.sin(t * 0.33) * 1.6; tab.y += Math.sin(t * 0.5) * 4;
  ph.ry += Math.sin(t * 0.33 + 1) * 1.8; ph.y += Math.sin(t * 0.5 + 0.8) * 5;
  const st = { tab, ph, t, lt, id: it.id, kind: it.kind };
  // Bildquellen: laufender Abschnitt, sonst letzter Stand des Geräts
  for (const d of ['tab', 'ph']) {
    if (it.dev && it.dev[d]) st[d + 'Src'] = frameAt(it.dev[d], it.t0 + Math.min(lt, it.dur - 0.4) * it.speed);
    else {
      let src = null;
      for (let j = i - 1; j >= 0 && !src; j--) if (items[j].dev && items[j].dev[d]) src = frameAt(items[j].dev[d], items[j].t1);
      for (let j = i + 1; j < items.length && !src; j++) if (items[j].dev && items[j].dev[d]) src = frameAt(items[j].dev[d], items[j].t0);
      st[d + 'Src'] = src;
    }
  }
  if (it.kind === 'card') st.card = { ...it, dev: undefined };
  else st.cap = { ...(it.caption || {}), chapter: it.chapter, fade: Math.min(1, lt / 0.5) * Math.min(1, (it.dur - lt) / 0.3) };
  st.link = it.kind === 'dual' ? Math.min(1, lt / 1.2) * Math.min(1, (it.dur - lt) / 0.4) : 0;
  return st;
}

// ---------- Seite ----------
const PAGE = `<!doctype html><html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:${W}px;height:${H}px;overflow:hidden;background:#0c0e12;font-family:Inter,sans-serif}
#bg{position:absolute;inset:0;background:radial-gradient(1300px 800px at 50% 35%,#2b3140 0%,#161920 55%,#0b0c10 100%)}
#scene{position:absolute;inset:0;perspective:2400px;perspective-origin:50% 42%;transform-style:preserve-3d}
#floor{position:absolute;left:50%;top:50%;width:5200px;height:5200px;margin:-2600px 0 0 -2600px;transform:translateY(470px) rotateX(90deg);
  background-image:linear-gradient(rgba(255,255,255,.13) 2px,transparent 2px),linear-gradient(90deg,rgba(255,255,255,.13) 2px,transparent 2px);background-size:130px 130px;
  -webkit-mask-image:radial-gradient(closest-side,#000 0%,rgba(0,0,0,.5) 45%,transparent 75%);mask-image:radial-gradient(closest-side,#000 0%,rgba(0,0,0,.5) 45%,transparent 75%)}
.shadow{position:absolute;left:50%;top:50%;border-radius:50%;background:rgba(0,0,0,.6);filter:blur(40px)}
.dev{position:absolute;left:50%;top:44%;transform-style:preserve-3d}
.dev .ly{position:absolute;inset:-14px;border-radius:38px;background:#07080a}
.dev.ph .ly{inset:-11px;border-radius:52px}
.dev .rim{position:absolute;inset:-14px;border-radius:38px;box-shadow:0 0 0 2px #454a55, 0 40px 120px rgba(0,0,0,.55)}
.dev.ph .rim{inset:-11px;border-radius:52px}
.dev img{position:absolute;inset:0;width:100%;height:100%;border-radius:22px;background:#111}
.dev.ph img{border-radius:40px}
.dev .glare{position:absolute;inset:0;border-radius:22px;background:linear-gradient(115deg,rgba(255,255,255,.13) 0%,rgba(255,255,255,0) 32%,rgba(255,255,255,0) 100%)}
.dev.ph .glare{border-radius:40px}
#hud{position:absolute;inset:0}
.tag{display:inline-block;white-space:nowrap;background:#c62828;color:#fff;font-weight:700;font-size:22px;letter-spacing:.06em;text-transform:uppercase;padding:6px 14px;border-radius:8px}
.clk{display:inline-flex;align-items:center;gap:10px;background:#fff;color:#15171c;font-weight:800;font-size:30px;padding:6px 16px;border-radius:10px;font-variant-numeric:tabular-nums}
#cap{position:absolute;left:210px;right:210px;top:872px}
#cap .t{color:#fff;font-weight:800;font-size:42px}
#cap .s{color:#c8ccd4;font-size:28px;line-height:1.35;margin-top:10px}
#card{position:absolute;inset:0;perspective:1800px}
#cardin{position:absolute;inset:0;transform-style:preserve-3d}
.a{will-change:transform,opacity}
#linklbl{position:absolute;color:#9fe3b0;font-size:22px;font-weight:700;letter-spacing:.04em;text-align:center;width:400px}
</style></head><body>
<div id="bg"></div>
<div id="scene"><div id="floor"></div>
  <div class="shadow" id="shT"></div><div class="shadow" id="shP"></div>
  <div class="dev tab" id="tab" style="width:1600px;height:900px;margin:-450px 0 0 -800px"></div>
  <div class="dev ph" id="ph" style="width:454px;height:982px;margin:-491px 0 0 -227px"></div>
</div>
<div id="hud">
  <svg id="link" width="${W}" height="${H}" style="position:absolute;inset:0"><path id="linkp" fill="none" stroke="#6fdc8c" stroke-width="5" stroke-linecap="round" stroke-dasharray="4 22"/><circle id="linkdot" r="11" fill="#b8ffd0"/></svg>
  <div id="linklbl">🔒 Status-Server · verschlüsselt</div>
  <div id="cap"></div>
  <div id="card"><div id="cardin"></div></div>
</div>
<script>
const $=(i)=>document.getElementById(i);
for(const d of ['tab','ph']){const e=$(d);let h='';for(let i=12;i>=1;i--)h+='<div class="ly" style="transform:translateZ('+(-i*2.4)+'px)"></div>';
  e.innerHTML=h+'<div class="rim"></div><img id="'+d+'Img"><div class="glare"></div>';}
const esc=(s)=>String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;');
const cur={};
function setDev(id,p){const e=$(id);e.style.transform='translate3d('+p.x+'px,'+p.y+'px,'+p.z+'px) rotateY('+p.ry+'deg) rotateX('+p.rx+'deg) scale('+p.s+')';e.style.opacity=p.op;
  const sh=$(id==='tab'?'shT':'shP');const w=(id==='tab'?1500:520)*p.s,h=160*p.s;sh.style.width=w+'px';sh.style.height=h+'px';sh.style.margin=(-h/2)+'px 0 0 '+(-w/2)+'px';
  sh.style.transform='translate3d('+p.x+'px,470px,'+p.z+'px) rotateX(90deg)';sh.style.opacity=p.op*0.9;}
async function setImg(id,src){if(!src||cur[id]===src)return;cur[id]=src;const im=$(id+'Img');im.src=src;try{await im.decode();}catch(e){}}
const cl=(v)=>Math.max(0,Math.min(1,v));
function cardHtml(c){
  if(c.style==='intro')return '<div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:28px">'
    +'<img class="a" data-d="0.2" data-pop="1" src="${ICON}" style="width:230px;height:230px;border-radius:48px;box-shadow:0 20px 60px rgba(0,0,0,.5)">'
    +'<div class="a" data-d="0.8" style="color:#fff;font-size:120px;font-weight:800;letter-spacing:-.02em">RHS Einsatz</div>'
    +'<div class="a" data-d="1.3" style="color:#d6d9df;font-size:46px">'+esc(c.sub||'')+'</div>'
    +'<div class="a" data-d="1.9" style="color:#9aa0aa;font-size:32px">'+esc(c.sub2||'')+'</div></div>';
  if(c.style==='alarm')return '<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center"><div class="a" data-d="0.15" data-pop="1" style="width:1300px;background:#1f232b;border:2px solid #c62828;border-radius:26px;padding:50px 64px;box-shadow:0 30px 90px rgba(0,0,0,.6)">'
    +'<div style="display:flex;align-items:center;gap:22px"><span style="font-size:64px">🚨</span><span style="color:#ff5252;font-size:34px;font-weight:800;letter-spacing:.12em">ALARMIERUNG</span><span style="margin-left:auto;color:#fff;font-size:56px;font-weight:800">'+esc(c.time)+'</span></div>'
    +'<div class="a" data-d="0.6" style="color:#fff;font-size:62px;font-weight:800;margin:26px 0 14px">'+esc(c.head)+'</div>'
    +c.lines.map((l,i)=>'<div class="a" data-d="'+(1.1+i*0.35)+'" style="color:#e8eaee;font-size:40px;line-height:1.35;margin-top:6px">'+esc(l)+'</div>').join('')
    +'<div class="a" data-d="'+(1.4+c.lines.length*0.35)+'" style="color:#8a909a;font-size:26px;margin-top:30px">'+esc(c.note||'')+'</div></div></div>';
  if(c.style==='story')return '<div style="position:absolute;inset:0;display:flex;flex-direction:column;justify-content:center;padding:0 240px">'
    +c.lines.map((l,i)=>'<div class="a" data-d="'+(0.5+i*0.6)+'" style="color:'+(i?'#c8ccd4':'#fff')+';font-size:'+(i?40:58)+'px;font-weight:'+(i?400:800)+';line-height:1.35;margin-top:'+(i?18:0)+'px">'+esc(l)+'</div>').join('')+'</div>';
  if(c.style==='outro')return '<div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:40px;padding:0 140px">'
    +'<div class="a" data-d="0.2" style="display:flex;align-items:center;gap:30px"><img src="${ICON}" style="width:120px;height:120px;border-radius:26px"><span style="color:#fff;font-size:90px;font-weight:800">RHS Einsatz</span></div>'
    +'<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:20px;width:100%">'+c.feats.map((f,i)=>'<div class="a" data-d="'+(0.6+i*0.12)+'" style="background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.12);border-radius:16px;padding:22px 26px;color:#e8eaee;font-size:30px;display:flex;gap:16px;align-items:center"><span style="font-size:40px">'+f[0]+'</span>'+esc(f[1])+'</div>').join('')+'</div>'
    +'<div class="a" data-d="'+(0.8+c.feats.length*0.12)+'" style="color:#fff;font-size:38px;font-weight:600;background:#c62828;padding:16px 34px;border-radius:14px">flai331.github.io/Programmieren/suchgebiet-karten</div>'
    +'<div class="a" data-d="'+(1.0+c.feats.length*0.12)+'" style="color:#9aa0aa;font-size:28px">Kostenlos · im Browser oder als Android-App · funktioniert auch offline</div></div>';
  return '<div style="position:absolute;inset:0;display:flex;align-items:center;padding-left:230px;gap:60px">'
    +'<div class="a" data-d="0.1" data-pop="1" style="font-size:'+(String(c.num).length>2?210:300)+'px;font-weight:800;color:#e53935;line-height:1;text-shadow:0 20px 60px rgba(0,0,0,.6)">'+esc(c.num)+'</div>'
    +'<div><div class="a" data-d="0.35" style="color:#fff;font-size:92px;font-weight:800">'+esc(c.title)+'</div><div class="a" data-d="0.6" style="height:6px;background:#c62828;border-radius:3px;width:260px;margin:26px 0"></div>'
    +'<div class="a" data-d="0.75" style="color:#c8ccd4;font-size:42px">'+esc(c.sub)+'</div></div></div>';
}
let capKey='',cardKey='';
window.render=async(st)=>{
  setDev('tab',st.tab);setDev('ph',st.ph);
  await Promise.all([setImg('tab',st.tabSrc),setImg('ph',st.phSrc)]);
  // Bildunterschrift
  const cap=$('cap');
  if(st.cap){const key=st.id;if(key!==capKey){capKey=key;cap.innerHTML='<div style="display:flex;gap:18px;align-items:center">'+(st.cap.clock?'<span class="clk">🕒 '+esc(st.cap.clock)+'</span>':'')+(st.cap.chapter?'<span class="tag">'+esc(st.cap.chapter)+'</span>':'')+'<span class="t">'+esc(st.cap.t)+'</span></div><div class="s">'+esc(st.cap.s)+'</div>';}
    cap.style.opacity=st.cap.fade;cap.style.transform='translateY('+((1-st.cap.fade)*20)+'px)';}else{cap.style.opacity=0;}
  // Karte
  const ci=$('cardin');
  if(st.card){if(cardKey!==st.id){cardKey=st.id;ci.innerHTML=cardHtml(st.card);}
    const out=cl((st.card.dur-st.lt)/0.45);const k=cl(st.lt/0.9);const e=1-Math.pow(1-k,3);
    ci.style.opacity=out;ci.style.transform='translateZ('+(-260*(1-e))+'px) rotateY('+(-16*(1-e)+Math.sin(st.t*0.4)*1.2)+'deg) rotateX('+(5*(1-e))+'deg)';
    ci.querySelectorAll('.a').forEach((el)=>{const d=Number(el.dataset.d||0);const p=cl((st.lt-d)/0.6);const q=1-Math.pow(1-p,3);el.style.opacity=q;
      el.style.transform=el.dataset.pop?'scale('+(0.6+0.4*q)+')':'translateY('+(40*(1-q))+'px)';});
  }else if(cardKey){cardKey='';ci.innerHTML='';}
  // Live-Verbindung zwischen den Geräten
  const lk=$('link'),ll=$('linklbl');lk.style.opacity=st.link;ll.style.opacity=st.link;
  if(st.link>0){const a=$('tab').getBoundingClientRect(),b=$('ph').getBoundingClientRect();
    const x1=a.right-20,y1=a.top+a.height*0.2,x2=b.left+b.width*0.5,y2=b.top-6,cx=(x1+x2)/2,cy=Math.max(70,Math.min(y1,y2)-90);
    const p=$('linkp');p.setAttribute('d','M'+x1+' '+y1+' Q'+cx+' '+cy+' '+x2+' '+y2);p.setAttribute('stroke-dashoffset',String(-st.t*60));
    const u=(st.t*0.45)%1,dir=Math.floor(st.t*0.45)%2?1-u:u;const px=(1-dir)*(1-dir)*x1+2*(1-dir)*dir*cx+dir*dir*x2,py=(1-dir)*(1-dir)*y1+2*(1-dir)*dir*cy+dir*dir*y2;
    const dot=$('linkdot');dot.setAttribute('cx',px);dot.setAttribute('cy',py);
    ll.style.left=(cx-200)+'px';ll.style.top='14px';}
};
</script></body></html>`;

(async () => {
  fs.writeFileSync(path.join(DIR, 'scene3d.html'), PAGE);
  const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  await page.goto('file://' + path.join(DIR, 'scene3d.html'));
  await page.evaluate(() => document.fonts.ready);
  if (process.env.PREVIEW) {
    const at = (id, d) => items.find((x) => x.id === id).start + d;
    const list = (process.env.PREVIEW_AT || '').split(',').filter(Boolean).map(Number);
    const ts = list.length ? list : [2.5, at('alarm', 4), at('t1', 0.5), at('el-grid', 4), at('anna-open', 0.5), at('anna-open', 4), at('dual-reed', 6), at('t6', 1.5), at('dual-fund', 9)];
    for (const [i, t] of ts.entries()) { await page.evaluate((s) => window.render(s), stateAt(t)); await page.screenshot({ path: path.join(DIR, `pv3d_${i}.jpg`), type: 'jpeg', quality: 85 }); }
    console.log('Länge', TOTAL.toFixed(1));
    await browser.close();
    return;
  }
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-', '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo', '-shortest',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-r', String(FPS), '-c:a', 'aac', '-movflags', '+faststart', OUT], { stdio: ['pipe', 'inherit', 'inherit'] });
  const n = Math.round(TOTAL * FPS);
  const t0 = Date.now();
  for (let i = 0; i < n; i++) {
    await page.evaluate((s) => window.render(s), stateAt(i / FPS));
    const buf = await page.screenshot({ type: 'jpeg', quality: 90 });
    if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
    if (i % 500 === 0) console.log(`${i}/${n} Bilder, ${((Date.now() - t0) / 1000).toFixed(0)} s`);
  }
  ff.stdin.end();
  await new Promise((r) => ff.on('close', r));
  await browser.close();
  console.log('Fertig:', TOTAL.toFixed(1), 's');
})().catch((e) => { console.error(e); process.exit(1); });
