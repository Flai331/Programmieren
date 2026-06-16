import json, os

with open('C:/Users/klaas/Desktop/Programmieren/Rettungshunde_Theorietrainer/fragen.json', encoding='utf-8') as f:
    questions_json = f.read().strip()

HTML_TEMPLATE = """\
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<meta name="theme-color" content="#1f2733">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<title>Rettungshunde Theorie-Trainer</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#1f2733;--card:#2c3846;--card2:#33415a;
  --gold:#f6d365;--orange:#fda085;
  --ok:#28a745;--err:#dc3545;
  --text:#e8eaf0;--muted:rgba(255,255,255,.55);
  --radius:12px;
}
body{background:var(--bg);color:var(--text);font-family:system-ui,sans-serif;min-height:100vh}
.screen{display:none;flex-direction:column;min-height:100vh}
.screen.active{display:flex}
.appbar{display:flex;align-items:center;gap:10px;padding:14px 16px;background:var(--card);border-bottom:1px solid rgba(255,255,255,.08);position:sticky;top:0;z-index:10}
.appbar h1{font-size:1.05rem;font-weight:600;flex:1}
.appbar .back{background:none;border:none;color:var(--text);font-size:1.4rem;cursor:pointer;padding:4px 8px;border-radius:8px}
.appbar .back:hover{background:rgba(255,255,255,.08)}
.chip{padding:4px 10px;border-radius:20px;font-size:.75rem;font-weight:600}
.chip-retry{background:rgba(220,53,69,.25);color:#ff8a95}
.content{flex:1;padding:16px;max-width:600px;width:100%;margin:0 auto}
.content.centered{display:flex;flex-direction:column;justify-content:center;align-items:center;min-height:calc(100vh - 60px)}
.card{background:var(--card);border-radius:var(--radius);padding:16px;border:1px solid rgba(255,255,255,.06);margin-bottom:12px}
.card-clickable{cursor:pointer;transition:background .15s}
.card-clickable:hover{background:var(--card2)}
.card-row{display:flex;align-items:center;gap:12px}
.card-icon{font-size:1.4rem;flex-shrink:0}
.card-title{font-weight:600;font-size:.95rem}
.card-sub{font-size:.8rem;color:var(--muted);margin-top:2px}
.card-arrow{margin-left:auto;color:var(--muted);font-size:1.2rem}
.btn{width:100%;padding:14px 20px;border:none;border-radius:var(--radius);font-size:1rem;font-weight:600;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;transition:opacity .15s}
.btn:disabled{opacity:.4;cursor:not-allowed}
.btn-grad{background:linear-gradient(135deg,var(--gold),var(--orange));color:#1a1a1a}
.btn-grad:hover:not(:disabled){opacity:.88}
.btn-ok{background:var(--ok);color:#fff}
.btn-ok:hover:not(:disabled){opacity:.88}
.btn-sm{padding:10px 16px;font-size:.9rem}
.progress-bar{height:4px;background:rgba(255,255,255,.1);position:sticky;top:60px;z-index:9}
.progress-fill{height:100%;background:linear-gradient(90deg,var(--gold),var(--orange));transition:width .3s}
.question-text{font-size:1rem;line-height:1.55;margin-bottom:16px}
.option{display:flex;align-items:flex-start;gap:12px;padding:13px 14px;background:rgba(255,255,255,.04);border:2px solid rgba(255,255,255,.08);border-radius:10px;cursor:pointer;margin-bottom:8px;transition:background .12s,border-color .12s}
.option:hover:not(.disabled){background:rgba(255,255,255,.08);border-color:rgba(246,211,101,.35)}
.option.selected{border-color:var(--gold);background:rgba(246,211,101,.1)}
.option.correct{border-color:var(--ok)!important;background:rgba(40,167,69,.15)!important}
.option.wrong{border-color:var(--err)!important;background:rgba(220,53,69,.15)!important}
.option.disabled{cursor:default}
.option-letter{font-weight:700;font-size:.85rem;min-width:22px;padding-top:1px;color:var(--muted)}
.option.selected .option-letter,.option.correct .option-letter{color:var(--gold)}
.option.wrong .option-letter{color:#ff8a95}
.option-text{font-size:.9rem;line-height:1.45;flex:1}
.explanation{background:rgba(246,211,101,.07);border:1px solid rgba(246,211,101,.2);border-radius:10px;padding:13px;margin-top:12px;font-size:.85rem;line-height:1.5;color:rgba(255,255,255,.85)}
.explanation-label{font-weight:700;color:var(--gold);margin-bottom:4px}
.result-badge{font-size:3rem;font-weight:800;text-align:center}
.result-sub{text-align:center;color:var(--muted);margin-top:4px;font-size:.9rem}
.pass{color:var(--ok)}.fail{color:var(--err)}
.review-item{margin-bottom:8px;border-radius:10px;overflow:hidden;border:1px solid rgba(255,255,255,.06)}
.review-header{display:flex;align-items:center;gap:10px;padding:11px 14px;cursor:pointer;background:var(--card)}
.review-header:hover{background:var(--card2)}
.review-body{padding:14px;background:rgba(255,255,255,.03);display:none;border-top:1px solid rgba(255,255,255,.06)}
.review-body.open{display:block}
.dot{width:10px;height:10px;border-radius:50%;flex-shrink:0}
.dot-ok{background:var(--ok)}.dot-err{background:var(--err)}
.license-logo{font-size:3.5rem;text-align:center;margin-bottom:10px}
.license-title{font-size:1.3rem;font-weight:700;text-align:center;margin-bottom:6px}
.license-sub{color:var(--muted);text-align:center;font-size:.88rem;margin-bottom:28px;line-height:1.5}
input[type=text]{width:100%;padding:13px 14px;background:var(--card);border:2px solid rgba(255,255,255,.12);border-radius:10px;color:var(--text);font-size:1rem;letter-spacing:.08em;font-family:monospace;outline:none;margin-bottom:12px}
input[type=text]:focus{border-color:var(--gold)}
.err-msg{color:#ff8a95;font-size:.85rem;text-align:center;margin-bottom:10px;min-height:1.2em}
.stats-bar{padding:12px 16px;display:flex;justify-content:space-around;text-align:center;border-top:1px solid rgba(255,255,255,.06)}
.stats-val{font-size:1.1rem;font-weight:700}
.stats-label{font-size:.7rem;color:var(--muted);margin-top:2px}
.timer{font-size:.85rem;color:var(--muted);padding:4px 10px;border-radius:20px;border:1px solid rgba(255,255,255,.12)}
.timer.warn{color:#ff8a95;border-color:#ff8a95}
.section-hdr{font-size:.75rem;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin:20px 0 10px}
.exam-nav{display:flex;gap:10px;padding:16px;background:var(--bg);border-top:1px solid rgba(255,255,255,.06)}
.exam-nav .btn{flex:1}
.exam-hero{background:linear-gradient(135deg,rgba(246,211,101,.12),rgba(253,160,133,.12));border:1px solid rgba(246,211,101,.25)}
.scroll-content{flex:1;overflow-y:auto;padding:16px;max-width:600px;width:100%;margin:0 auto}
/* Discipline badge */
.disc-badge{display:inline-flex;align-items:center;gap:6px;padding:5px 14px;border-radius:20px;border:1px solid rgba(246,211,101,.4);background:rgba(246,211,101,.1);color:var(--gold);font-size:.82rem;font-weight:600;cursor:pointer;margin:0 auto 16px;width:auto}
.disc-badge:hover{background:rgba(246,211,101,.18)}
/* Discipline picker overlay */
.overlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,.6);z-index:50;align-items:center;justify-content:center}
.overlay.open{display:flex}
.modal{background:var(--card);border-radius:var(--radius);padding:24px;width:min(380px,90vw);border:1px solid rgba(255,255,255,.1)}
.modal-title{font-size:1.1rem;font-weight:700;margin-bottom:16px}
.disc-option{display:flex;align-items:center;gap:12px;padding:12px;border-radius:10px;cursor:pointer;border:2px solid rgba(255,255,255,.06);margin-bottom:8px;transition:background .12s,border-color .12s}
.disc-option:hover{background:rgba(255,255,255,.05);border-color:rgba(246,211,101,.3)}
.disc-option.sel{border-color:var(--gold);background:rgba(246,211,101,.1)}
.disc-radio{width:18px;height:18px;border-radius:50%;border:2px solid rgba(255,255,255,.3);flex-shrink:0;display:flex;align-items:center;justify-content:center}
.disc-option.sel .disc-radio{border-color:var(--gold)}
.disc-radio-dot{width:8px;height:8px;border-radius:50%;background:var(--gold);display:none}
.disc-option.sel .disc-radio-dot{display:block}
.disc-title{font-weight:600;font-size:.9rem}
.disc-sub{font-size:.78rem;color:var(--muted);margin-top:2px}
.modal-actions{display:flex;gap:8px;margin-top:16px;justify-content:flex-end}
.btn-text{background:none;border:none;color:var(--muted);cursor:pointer;padding:8px 12px;border-radius:8px;font-size:.9rem}
.btn-text:hover{background:rgba(255,255,255,.06);color:var(--text)}
.btn-save{background:linear-gradient(135deg,var(--gold),var(--orange));color:#1a1a1a;border:none;padding:8px 20px;border-radius:8px;font-weight:700;cursor:pointer;font-size:.9rem}
/* Safe area (iPhone notch/home bar) */
.appbar{padding-left:max(16px,env(safe-area-inset-left));padding-right:max(16px,env(safe-area-inset-right))}
.stats-bar,.exam-nav{padding-bottom:max(12px,env(safe-area-inset-bottom))}
.scroll-content{padding-left:max(16px,env(safe-area-inset-left));padding-right:max(16px,env(safe-area-inset-right))}

/* Mobile */
@media(max-width:480px){
  .appbar h1{font-size:.95rem}
  .appbar .back{padding:6px}
  .scroll-content{padding:12px}
  .card{padding:14px}
  .option{padding:12px 12px}
  .option-text{font-size:.88rem}
  .question-text{font-size:.95rem}
  .btn{padding:13px 16px;font-size:.95rem}
  .result-badge{font-size:2.5rem}
  .section-hdr{margin:16px 0 8px}
  .disc-badge{font-size:.78rem;padding:4px 12px}
  .modal{padding:18px}
}
/* Prevent text size inflation on iOS */
body{-webkit-text-size-adjust:100%}
/* Tap highlight */
*{-webkit-tap-highlight-color:rgba(246,211,101,.15)}
a,button,[onclick]{touch-action:manipulation}
/* ── TOUR ─────────────────────────────────────────────────────────────── */
#tour-overlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,.75);z-index:200;align-items:center;justify-content:center;padding:20px}
#tour-overlay.active{display:flex}
.tour-card{background:var(--card);border-radius:16px;padding:28px 24px 20px;max-width:400px;width:100%;box-shadow:0 8px 40px rgba(0,0,0,.5);border:1px solid rgba(255,255,255,.08)}
.tour-icon{font-size:3rem;text-align:center;margin-bottom:16px}
.tour-title{font-size:1.2rem;font-weight:700;text-align:center;margin-bottom:10px;color:var(--gold)}
.tour-body{color:rgba(255,255,255,.8);line-height:1.6;text-align:center;font-size:.95rem;margin-bottom:20px}
.tour-dots{display:flex;justify-content:center;gap:6px;margin-bottom:20px}
.tour-dot{width:8px;height:8px;border-radius:50%;background:rgba(255,255,255,.2);transition:background .2s}
.tour-dot.active{background:var(--gold)}
.tour-btns{display:flex;gap:10px}
.tour-btns button{flex:1;padding:12px;border-radius:10px;border:none;font-weight:600;font-size:.95rem;cursor:pointer}
.tour-btn-skip{background:rgba(255,255,255,.08);color:rgba(255,255,255,.6)}
.tour-btn-next{background:linear-gradient(135deg,var(--gold),var(--orange));color:#1f2733}
.tour-btn-back{background:rgba(255,255,255,.08);color:var(--text);flex:0.6}
.tour-check{display:flex;align-items:center;gap:8px;justify-content:center;margin-bottom:16px;color:rgba(255,255,255,.65);font-size:.88rem;cursor:pointer;user-select:none}
.tour-check input{width:17px;height:17px;accent-color:var(--gold);cursor:pointer}
</style>
</head>
<body>

<!-- ═══ TOUR OVERLAY ═════════════════════════════════════════════════════ -->
<div id="tour-overlay">
  <div class="tour-card">
    <div class="tour-icon" id="tour-icon"></div>
    <div class="tour-title" id="tour-title"></div>
    <div class="tour-body" id="tour-body"></div>
    <div class="tour-dots" id="tour-dots"></div>
    <div class="tour-btns" id="tour-btns"></div>
  </div>
</div>

<!-- ═══ DISCIPLINE PICKER (overlay modal) ════════════════════════════════ -->
<div id="disc-overlay" class="overlay">
  <div class="modal">
    <div class="modal-title" id="disc-modal-title">Für welche Sparte übst du?</div>
    <div id="disc-options"></div>
    <div class="modal-actions">
      <button class="btn-text" id="disc-cancel" onclick="closeDiscModal()" style="display:none">Abbrechen</button>
      <button class="btn-save" onclick="saveDisc()">Speichern</button>
    </div>
  </div>
</div>

<!-- ═══ LICENSE SCREEN ═══════════════════════════════════════════════════ -->
<div id="screen-license" class="screen active">
  <div class="content centered">
    <div class="license-logo">🐕</div>
    <div class="license-title">Rettungshunde Theorie-Trainer</div>
    <div class="license-sub">Gib deinen Freischalt-Code ein, um auf alle 192 Prüfungsfragen zuzugreifen.</div>
    <input type="text" id="license-input" placeholder="XXXXX-XXXXX" autocomplete="off" autocapitalize="characters" spellcheck="false" maxlength="11">
    <div class="err-msg" id="license-err"></div>
    <button class="btn btn-grad" onclick="submitLicense()">🔓 Freischalten</button>
  </div>
</div>

<!-- ═══ HOME SCREEN ══════════════════════════════════════════════════════ -->
<div id="screen-home" class="screen">
  <div class="appbar">
    <h1>🐕 RH Theorie-Trainer</h1>
    <button class="back" title="Statistik" onclick="showStats()">📊</button>
    <button class="back" title="Einstellungen" onclick="showSettingsScreen()">⚙️</button>
  </div>
  <div class="scroll-content" id="home-content"></div>
  <div class="stats-bar" id="home-stats"></div>
</div>

<!-- ═══ SETTINGS SCREEN ══════════════════════════════════════════════════ -->
<div id="screen-settings" class="screen">
  <div class="appbar">
    <button class="back" onclick="goHome()">←</button>
    <h1>Einstellungen</h1>
  </div>
  <div class="scroll-content" id="settings-content"></div>
</div>

<!-- ═══ LEARN SESSION ════════════════════════════════════════════════════ -->
<div id="screen-learn" class="screen">
  <div class="appbar">
    <button class="back" onclick="goHome()">←</button>
    <h1 id="learn-progress-label">0/0</h1>
    <span class="chip chip-retry" id="learn-retry-chip" style="display:none">Wiederholen</span>
  </div>
  <div class="progress-bar"><div class="progress-fill" id="learn-progress-fill" style="width:0%"></div></div>
  <div class="scroll-content" id="learn-content"></div>
  <div style="padding:16px;max-width:600px;width:100%;margin:0 auto;flex-shrink:0">
    <button class="btn btn-ok" id="learn-check-btn" disabled onclick="checkLearnAnswer()">✓ Antwort prüfen</button>
    <button class="btn btn-grad" id="learn-next-btn" onclick="nextLearnQuestion()" style="display:none">Weiter →</button>
  </div>
</div>

<!-- ═══ EXAM SCREEN ══════════════════════════════════════════════════════ -->
<div id="screen-exam" class="screen">
  <div class="appbar">
    <button class="back" onclick="confirmQuitExam()">←</button>
    <h1 id="exam-q-label">Frage 1/25</h1>
    <span class="timer" id="exam-timer">20:00</span>
  </div>
  <div class="progress-bar"><div class="progress-fill" id="exam-progress-fill" style="width:0%"></div></div>
  <div class="scroll-content" id="exam-content"></div>
  <div class="exam-nav">
    <button class="btn btn-grad btn-sm" id="exam-prev-btn" onclick="examPrev()" style="display:none">← Zurück</button>
    <button class="btn btn-grad btn-sm" id="exam-next-btn" onclick="examNext()">Weiter →</button>
    <button class="btn btn-ok btn-sm" id="exam-submit-btn" onclick="submitExam()" style="display:none">Abgeben ✓</button>
  </div>
</div>

<!-- ═══ EXAM RESULT ══════════════════════════════════════════════════════ -->
<div id="screen-result" class="screen">
  <div class="appbar">
    <button class="back" onclick="goHome()">←</button>
    <h1>Prüfungsergebnis</h1>
  </div>
  <div class="scroll-content" id="result-content"></div>
</div>

<!-- ═══ STATS SCREEN ════════════════════════════════════════════════════ -->
<div id="screen-stats" class="screen">
  <div class="appbar">
    <button class="back" onclick="goHome()">←</button>
    <h1>Statistik</h1>
  </div>
  <div class="scroll-content" id="stats-content"></div>
</div>

<script>
// ═══════════════════════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════════════════════
const QUESTIONS = QUESTIONS_PLACEHOLDER;

const CATEGORIES = [...new Set(QUESTIONS.map(q => q.kategorie))];

const DISC_CONFIG = {
  alle: {
    label: 'Alle Sparten',
    sub: 'Fläche + Trümmer (alle Kategorien)',
    excluded: [],
    dist: {
      'Erste Hilfe': 5, 'Erste Hilfe am Hund': 3, 'Kynologie': 3,
      'Unfallverhütung / Sicherheit im Einsatz': 3, 'Sprechfunk': 3,
      'Einsatztaktik Fläche': 2, 'Orientierung im Gelände': 2,
      'Einsatztaktik Trümmer/Trümmerkunde': 4,
    },
  },
  flaeche: {
    label: 'Flächensuche',
    sub: 'Ohne Trümmer/Trümmerkunde-Fragen',
    excluded: ['Einsatztaktik Trümmer/Trümmerkunde'],
    dist: {
      'Erste Hilfe': 5, 'Erste Hilfe am Hund': 3, 'Kynologie': 3,
      'Unfallverhütung / Sicherheit im Einsatz': 3, 'Sprechfunk': 3,
      'Einsatztaktik Fläche': 4, 'Orientierung im Gelände': 4,
    },
  },
  truemmer: {
    label: 'Trümmer',
    sub: 'Ohne Fläche- und Orientierungsfragen',
    excluded: ['Einsatztaktik Fläche', 'Orientierung im Gelände'],
    dist: {
      'Erste Hilfe': 5, 'Erste Hilfe am Hund': 3, 'Kynologie': 3,
      'Unfallverhütung / Sicherheit im Einsatz': 3, 'Sprechfunk': 3,
      'Einsatztaktik Trümmer/Trümmerkunde': 8,
    },
  },
};

// ═══════════════════════════════════════════════════════════════════════════
// LICENSE VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════
const _SECRET = 'RHTT-v1::Rettungshunde-Theorie::change-before-release';
const _ALPHA  = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

// Pure-JS SHA-256 — works on file://, WhatsApp in-app browser, iOS WKWebView
function _sha256(data) {
  const K=[0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
  let h0=0x6a09e667,h1=0xbb67ae85,h2=0x3c6ef372,h3=0xa54ff53a,
      h4=0x510e527f,h5=0x9b05688c,h6=0x1f83d9ab,h7=0x5be0cd19;
  const b=[...data,0x80];
  while(b.length%64!==56)b.push(0);
  const L=data.length*8;
  for(let i=7;i>=0;i--)b.push((L/Math.pow(2,i*8))&0xff);
  for(let i=0;i<b.length;i+=64){
    const w=[];
    for(let j=0;j<16;j++)w[j]=(b[i+j*4]<<24)|(b[i+j*4+1]<<16)|(b[i+j*4+2]<<8)|b[i+j*4+3];
    for(let j=16;j<64;j++){
      const s0=((w[j-15]>>>7)|(w[j-15]<<25))^((w[j-15]>>>18)|(w[j-15]<<14))^(w[j-15]>>>3);
      const s1=((w[j-2]>>>17)|(w[j-2]<<15))^((w[j-2]>>>19)|(w[j-2]<<13))^(w[j-2]>>>10);
      w[j]=(w[j-16]+s0+w[j-7]+s1)|0;
    }
    let a=h0,b2=h1,c=h2,d=h3,e=h4,f=h5,g=h6,h=h7;
    for(let j=0;j<64;j++){
      const S1=((e>>>6)|(e<<26))^((e>>>11)|(e<<21))^((e>>>25)|(e<<7));
      const ch=(e&f)^(~e&g);
      const t1=(h+S1+ch+K[j]+w[j])|0;
      const S0=((a>>>2)|(a<<30))^((a>>>13)|(a<<19))^((a>>>22)|(a<<10));
      const maj=(a&b2)^(a&c)^(b2&c);
      const t2=(S0+maj)|0;
      h=g;g=f;f=e;e=(d+t1)|0;d=c;c=b2;b2=a;a=(t1+t2)|0;
    }
    h0=(h0+a)|0;h1=(h1+b2)|0;h2=(h2+c)|0;h3=(h3+d)|0;
    h4=(h4+e)|0;h5=(h5+f)|0;h6=(h6+g)|0;h7=(h7+h)|0;
  }
  const r=[];
  for(const x of[h0,h1,h2,h3,h4,h5,h6,h7])r.push((x>>>24)&0xff,(x>>>16)&0xff,(x>>>8)&0xff,x&0xff);
  return r;
}

function _hmac(keyBytes, dataBytes) {
  const B=64;
  let k=keyBytes.length>B?_sha256(keyBytes):[...keyBytes];
  while(k.length<B)k.push(0);
  return _sha256([...k.map(x=>x^0x5c),..._sha256([...k.map(x=>x^0x36),...dataBytes])]);
}

function _b32decode(s) {
  let buf = 0, bits = 0;
  const out = [];
  for (const ch of s) {
    const v = _ALPHA.indexOf(ch);
    if (v < 0) return null;
    buf = (buf << 5) | v;
    bits += 5;
    if (bits >= 8) { bits -= 8; out.push((buf >> bits) & 0xFF); }
  }
  return out;
}

function _cleanCode(raw) {
  return raw.toUpperCase().split('').map(c => {
    if (c === '0') return 'O';
    if (c === '1') return 'I';
    if (c === '9') return '';
    return c;
  }).filter(c => _ALPHA.includes(c)).join('');
}

// Synchronous — no Web Crypto API needed
function verifyCode(raw) {
  const cleaned = _cleanCode(raw);
  const bytes = _b32decode(cleaned);
  if (!bytes || bytes.length < 6) return false;
  const serial = bytes.slice(0, 2);
  const mac    = bytes.slice(2, 6);
  const keyBytes = Array.from(new TextEncoder().encode(_SECRET));
  const expected = _hmac(keyBytes, serial);
  for (let i = 0; i < 4; i++) { if (mac[i] !== expected[i]) return false; }
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════
// STORAGE
// ═══════════════════════════════════════════════════════════════════════════
const PROGRESS_KEY = 'rhs_progress_v1';
const LICENSE_KEY  = 'rhs_license_v1';
const DISC_KEY     = 'rhs_discipline_v1';

function getProgress() {
  try { return JSON.parse(localStorage.getItem(PROGRESS_KEY) || '{}'); }
  catch { return {}; }
}
function setProgress(p) { localStorage.setItem(PROGRESS_KEY, JSON.stringify(p)); }

function recordAnswer(id, correct) {
  const p = getProgress();
  const e = p[id] || { seen: 0, correct: 0, wrong: 0, lastResult: null };
  e.seen++;
  correct ? (e.correct++, e.lastResult = 1) : (e.wrong++, e.lastResult = 0);
  p[id] = e;
  setProgress(p);
}

function resetProgress() { localStorage.removeItem(PROGRESS_KEY); }

function getOverallStats(excludedCats) {
  const p = getProgress();
  let correct = 0, wrong = 0, seen = 0;
  const pool = QUESTIONS.filter(q => !excludedCats.includes(q.kategorie));
  for (const q of pool) {
    if (p[q.id]) { seen++; correct += p[q.id].correct; wrong += p[q.id].wrong; }
  }
  return { seen, correct, wrong, total: pool.length };
}

// Discipline
function getDisc() { return localStorage.getItem(DISC_KEY) || null; }
function setDisc(d) { localStorage.setItem(DISC_KEY, d); }
function discConfig() { return DISC_CONFIG[getDisc() || 'alle'] || DISC_CONFIG.alle; }

// ═══════════════════════════════════════════════════════════════════════════
// ROUTER
// ═══════════════════════════════════════════════════════════════════════════
function showScreen(id) {
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  document.getElementById(id).classList.add('active');
  window.scrollTo(0, 0);
}

function goHome() {
  stopExamTimer();
  showScreen('screen-home');
  renderHome();
}

function logout() {
  if (confirm('Lizenz-Code entfernen und App sperren?')) {
    localStorage.removeItem(LICENSE_KEY);
    showScreen('screen-license');
    document.getElementById('license-input').value = '';
    document.getElementById('license-err').textContent = '';
  }
}

function showSettingsScreen() {
  showScreen('screen-settings');
  renderSettings();
}

// ═══════════════════════════════════════════════════════════════════════════
// DISCIPLINE MODAL
// ═══════════════════════════════════════════════════════════════════════════
let _discPending = null;
let _discCancelable = false;

function openDiscModal(cancelable) {
  _discPending = getDisc() || 'alle';
  _discCancelable = cancelable;
  document.getElementById('disc-modal-title').textContent = cancelable
    ? 'Suchhundtyp ändern' : 'Für welche Sparte übst du?';
  document.getElementById('disc-cancel').style.display = cancelable ? 'block' : 'none';
  renderDiscOptions();
  document.getElementById('disc-overlay').classList.add('open');
}

function closeDiscModal() {
  document.getElementById('disc-overlay').classList.remove('open');
}

function renderDiscOptions() {
  const keys = Object.keys(DISC_CONFIG);
  let html = '';
  for (const k of keys) {
    const c = DISC_CONFIG[k];
    const sel = _discPending === k;
    html += `<div class="disc-option${sel ? ' sel' : ''}" onclick="selectDisc('${k}')">
      <div class="disc-radio"><div class="disc-radio-dot"></div></div>
      <div>
        <div class="disc-title">${c.label}</div>
        <div class="disc-sub">${c.sub}</div>
      </div>
    </div>`;
  }
  document.getElementById('disc-options').innerHTML = html;
}

function selectDisc(k) {
  _discPending = k;
  renderDiscOptions();
}

function saveDisc() {
  setDisc(_discPending);
  closeDiscModal();
  goHome();
}

// ═══════════════════════════════════════════════════════════════════════════
// LICENSE SCREEN
// ═══════════════════════════════════════════════════════════════════════════
function submitLicense() {
  const inp = document.getElementById('license-input');
  const err = document.getElementById('license-err');
  const code = inp.value.trim();
  err.textContent = '';
  if (!code) { err.textContent = 'Bitte einen Code eingeben.'; return; }
  const ok = verifyCode(code);
  if (ok) {
    localStorage.setItem(LICENSE_KEY, code);
    if (!getDisc()) { showScreen('screen-home'); renderHome(); openDiscModal(false); }
    else goHome();
  } else {
    err.textContent = 'Ungültiger Code. Bitte erneut versuchen.';
    inp.focus();
  }
}

document.getElementById('license-input').addEventListener('keydown', e => {
  if (e.key === 'Enter') submitLicense();
});
document.getElementById('license-input').addEventListener('input', function() {
  let v = this.value.toUpperCase().replace(/[^A-Z2-7]/g, '');
  if (v.length > 5) v = v.slice(0, 5) + '-' + v.slice(5, 10);
  this.value = v;
});

// ═══════════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════
function esc(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function renderHome() {
  const dc = discConfig();
  const p = getProgress();
  const stats = getOverallStats(dc.excluded);
  const catCount = {}, catSeen = {};
  const pool = QUESTIONS.filter(q => !dc.excluded.includes(q.kategorie));
  for (const q of pool) {
    catCount[q.kategorie] = (catCount[q.kategorie] || 0) + 1;
    if (p[q.id]) catSeen[q.kategorie] = (catSeen[q.kategorie] || 0) + 1;
  }
  const visibleCats = CATEGORIES.filter(c => !dc.excluded.includes(c));

  let html = `<div style="text-align:center;margin-bottom:4px">
    <button class="disc-badge" onclick="openDiscModal(true)">🔍 ${esc(dc.label)} ✏️</button>
  </div>`;
  html += `<div class="section-hdr">Lernmodus</div>`;
  html += mkTile('♾️', 'Alle Fragen', `${stats.seen}/${stats.total} gesehen`, null);
  for (const cat of visibleCats) {
    const seen = catSeen[cat] || 0;
    html += mkTile('📁', cat, `${seen}/${catCount[cat]} gesehen`, cat);
  }
  html += `<div class="section-hdr">Prüfungsmodus</div>
    <div class="card exam-hero card-clickable" onclick="startExam()">
      <div class="card-row">
        <span class="card-icon">📋</span>
        <div><div class="card-title">GemPPO Prüfung starten</div>
        <div class="card-sub">25 Fragen · 20 Minuten · 80% zum Bestehen · ${esc(dc.label)}</div></div>
        <span class="card-arrow">›</span>
      </div>
    </div>`;
  document.getElementById('home-content').innerHTML = html;

  const rate = stats.correct + stats.wrong > 0 ? Math.round(stats.correct / (stats.correct + stats.wrong) * 100) : 0;
  document.getElementById('home-stats').innerHTML = `
    <div><div class="stats-val">${stats.seen}</div><div class="stats-label">Gesehen</div></div>
    <div><div class="stats-val">${stats.correct}</div><div class="stats-label">Richtig</div></div>
    <div><div class="stats-val">${stats.wrong}</div><div class="stats-label">Falsch</div></div>
    <div><div class="stats-val">${rate}%</div><div class="stats-label">Quote</div></div>`;

  maybeShowTour();
}

function mkTile(icon, title, sub, cat) {
  const onclick = cat === null ? 'startLearn(null)' : `startLearn('${cat.replace(/'/g,"\\\\'")}')`;
  return `<div class="card card-clickable" onclick="${onclick}">
    <div class="card-row">
      <span class="card-icon">${icon}</span>
      <div><div class="card-title">${esc(title)}</div><div class="card-sub">${esc(sub)}</div></div>
      <span class="card-arrow">›</span>
    </div>
  </div>`;
}

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ═══════════════════════════════════════════════════════════════════════════
function renderSettings() {
  const dc = discConfig();
  let html = `
    <div class="section-hdr">Suchhundtyp</div>
    <div class="card card-clickable" onclick="openDiscModal(true)">
      <div class="card-row">
        <span class="card-icon">🔍</span>
        <div><div class="card-title">${esc(dc.label)}</div><div class="card-sub">${esc(dc.sub)}</div></div>
        <span class="card-arrow">✏️</span>
      </div>
    </div>
    <div class="section-hdr">Lizenz</div>
    <div class="card card-clickable" onclick="logout()">
      <div class="card-row">
        <span class="card-icon">🔑</span>
        <div><div class="card-title">Lizenz entfernen</div><div class="card-sub">App wird gesperrt</div></div>
        <span class="card-arrow" style="color:var(--err)">›</span>
      </div>
    </div>
    <div class="section-hdr">App</div>
    <div class="card card-clickable" onclick="startTour()">
      <div class="card-row">
        <span class="card-icon">🗺️</span>
        <div><div class="card-title">Tour starten</div><div class="card-sub">App-Funktionen erklärt in 5 Schritten</div></div>
        <span class="card-arrow">›</span>
      </div>
    </div>
    <div class="card card-clickable" onclick="downloadApp()">
      <div class="card-row">
        <span class="card-icon" id="dl-icon">⬇️</span>
        <div><div class="card-title" id="dl-title">App herunterladen</div><div class="card-sub" id="dl-sub">HTML-Datei speichern – funktioniert offline</div></div>
        <span class="card-arrow">›</span>
      </div>
    </div>
    <div class="section-hdr">Daten</div>
    <button class="btn btn-sm" style="background:rgba(220,53,69,.2);border:1px solid rgba(220,53,69,.4);color:#ff8a95;margin-bottom:24px;width:auto;padding:10px 20px" onclick="doReset()">🗑️ Fortschritt zurücksetzen</button>`;
  document.getElementById('settings-content').innerHTML = html;
  if (_isIOS()) {
    document.getElementById('dl-icon').textContent = '📱';
    document.getElementById('dl-title').textContent = 'Zum Home-Bildschirm hinzufügen';
    document.getElementById('dl-sub').textContent = 'Als App-Icon speichern – kein Download nötig';
  }
}

function _isIOS() {
  return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
}

function downloadApp() {
  if (_isIOS()) { _showIOSModal(); return; }
  const html = '<!DOCTYPE html>' + document.documentElement.outerHTML;
  const blob = new Blob([html], {type: 'text/html;charset=utf-8'});
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'RHS_Theorie_Trainer.html';
  a.click();
  URL.revokeObjectURL(a.href);
}

function _showIOSModal() {
  const url = location.href.split('?')[0].split('#')[0];
  const m = document.createElement('div');
  m.id = 'ios-modal';
  m.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.8);z-index:300;display:flex;align-items:flex-end;padding:16px';
  m.innerHTML = `
    <div style="background:#2c3846;border-radius:16px;padding:24px;width:100%;max-width:420px;margin:0 auto;border:1px solid rgba(255,255,255,.1)">
      <div style="font-size:2rem;text-align:center;margin-bottom:12px">📱</div>
      <div style="font-size:1.1rem;font-weight:700;text-align:center;color:#f6d365;margin-bottom:16px">Zum Home-Bildschirm hinzufügen</div>
      <div style="color:rgba(255,255,255,.8);line-height:1.7;font-size:.93rem">
        Auf iPhone/iPad kann die HTML-Datei nicht direkt geöffnet werden.<br><br>
        So speicherst du die App als Icon:<br>
        <ol style="padding-left:20px;margin-top:8px;margin-bottom:8px">
          <li>Tippe unten auf das <strong>Teilen-Symbol</strong> <span style="font-size:1.1em">□↑</span></li>
          <li>Wähle <strong>„Zum Home-Bildschirm"</strong></li>
          <li>Tippe <strong>„Hinzufügen"</strong></li>
        </ol>
        Die App erscheint als Icon und öffnet immer direkt im Safari-Browser – ohne In-App-Browser.
      </div>
      <button onclick="document.getElementById('ios-modal').remove()"
        style="margin-top:20px;width:100%;padding:14px;border-radius:10px;border:none;background:linear-gradient(135deg,#f6d365,#fda085);color:#1f2733;font-weight:700;font-size:1rem;cursor:pointer">
        Verstanden
      </button>
    </div>`;
  document.body.appendChild(m);
  m.addEventListener('click', e => { if (e.target === m) m.remove(); });
}

// ═══════════════════════════════════════════════════════════════════════════
// TOUR
// ═══════════════════════════════════════════════════════════════════════════
const TOUR_KEY = 'rhs_tour_done';
const TOUR_STEPS = [
  {
    icon: '🐕',
    title: 'Willkommen!',
    body: 'Diese App bereitet dich auf die Rettungshunde-Theorieprüfung vor. Kurze Tour – 5 Schritte.'
  },
  {
    icon: '📖',
    title: 'Lernmodus',
    body: 'Übe nach Kategorie oder alle Fragen gemischt. Nach jeder Antwort siehst du sofort ob sie richtig war – inklusive Erklärung. Falsche Fragen kommen automatisch nochmal.'
  },
  {
    icon: '⏱️',
    title: 'Prüfungsmodus',
    body: 'Simuliere die echte Prüfung: 25 zufällige Fragen, 20 Minuten Zeit. Auswertung erst am Ende. Bestanden ab 80 % (20 von 25).'
  },
  {
    icon: '🔍',
    title: 'Suchhundtyp',
    body: 'Lernst du für Flächensuche, Trümmer oder beides? Wähle deine Sparte – die App blendet fachfremde Fragen aus. Jederzeit änderbar in den Einstellungen.'
  },
  {
    icon: '⬇️',
    title: 'Offline nutzen',
    body: 'Einstellungen → „App herunterladen" speichert die komplette App als eine einzige HTML-Datei auf dein Gerät. Danach kein Internet mehr nötig – einfach die Datei öffnen.'
  }
];

let _tourStep = 0;

function startTour() {
  _tourStep = 0;
  if (_isIOS()) {
    TOUR_STEPS[TOUR_STEPS.length - 1] = {
      icon: '📱',
      title: 'Offline nutzen (iPhone/iPad)',
      body: 'Tippe auf Teilen □↑ → „Zum Home-Bildschirm" → „Hinzufügen". Die App erscheint als Icon und öffnet immer direkt in Safari – kein Download nötig.'
    };
  }
  _renderTourStep();
  document.getElementById('tour-overlay').classList.add('active');
}

function _renderTourStep() {
  const s = TOUR_STEPS[_tourStep];
  const total = TOUR_STEPS.length;
  document.getElementById('tour-icon').textContent = s.icon;
  document.getElementById('tour-title').textContent = s.title;
  document.getElementById('tour-body').textContent = s.body;

  // dots
  let dots = '';
  for (let i = 0; i < total; i++)
    dots += `<div class="tour-dot${i === _tourStep ? ' active' : ''}"></div>`;
  document.getElementById('tour-dots').innerHTML = dots;

  // remove old checkbox if present
  const oldCb = document.getElementById('tour-no-repeat');
  if (oldCb) oldCb.closest('label') && oldCb.closest('label').remove();

  // checkbox + buttons
  const isLast = _tourStep === total - 1;
  const isFirst = _tourStep === 0;

  const checkHtml = isLast
    ? `<label class="tour-check"><input type="checkbox" id="tour-no-repeat" checked> Nicht mehr anzeigen</label>`
    : '';
  document.getElementById('tour-dots').insertAdjacentHTML('afterend', checkHtml);

  let btns = '';
  if (!isLast) btns += `<button class="tour-btns tour-btn-skip" onclick="closeTour(false)">Überspringen</button>`;
  if (!isFirst) btns += `<button class="tour-btns tour-btn-back" onclick="tourBack()">←</button>`;
  btns += `<button class="tour-btn-next" onclick="${isLast ? 'closeTour(true)' : 'tourNext()'}">
    ${isLast ? '✓ Los geht\\'s' : 'Weiter →'}</button>`;
  document.getElementById('tour-btns').innerHTML = btns;
}

function tourNext() {
  if (_tourStep < TOUR_STEPS.length - 1) { _tourStep++; _renderTourStep(); }
}

function tourBack() {
  if (_tourStep > 0) { _tourStep--; _renderTourStep(); }
}

function closeTour(checkboxMatters) {
  document.getElementById('tour-overlay').classList.remove('active');
  const cb = document.getElementById('tour-no-repeat');
  if (!checkboxMatters || (cb && cb.checked)) {
    localStorage.setItem(TOUR_KEY, '1');
  }
}

function maybeShowTour() {
  if (!localStorage.getItem(TOUR_KEY)) startTour();
}

function logout() {
  if (confirm('Lizenz-Code entfernen und App sperren?')) {
    localStorage.removeItem(LICENSE_KEY);
    showScreen('screen-license');
    document.getElementById('license-input').value = '';
    document.getElementById('license-err').textContent = '';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LEARN MODE
// ═══════════════════════════════════════════════════════════════════════════
let LS = null;

function weightFor(e) {
  if (!e) return 3;
  if (e.lastResult === 0) return 5;
  const r = e.seen > 0 ? e.wrong / e.seen : 0;
  if (r >= 0.5) return 3;
  if (r >= 0.2) return 2;
  return 1;
}

function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function startLearn(category) {
  const dc = discConfig();
  const p = getProgress();
  let pool = QUESTIONS.filter(q => {
    if (dc.excluded.includes(q.kategorie)) return false;
    if (category && q.kategorie !== category) return false;
    return true;
  });
  const seen = new Set();
  pool = pool.filter(q => { if (seen.has(q.id)) return false; seen.add(q.id); return true; });

  const expanded = [];
  for (const q of pool) {
    const w = weightFor(p[q.id]);
    for (let i = 0; i < w; i++) expanded.push(q);
  }
  shuffle(expanded);
  const ordSeen = new Set();
  const ordered = expanded.filter(q => { if (ordSeen.has(q.id)) return false; ordSeen.add(q.id); return true; });

  LS = { queue: ordered, retries: {}, done: 0, total: ordered.length, selected: new Set(), revealed: false, lastCorrect: false, MAX_RETRY: 2 };
  showScreen('screen-learn');
  renderLearnQ();
}

function renderLearnQ() {
  if (!LS || LS.queue.length === 0) { goHome(); return; }
  const q = LS.queue[0];
  const isRetry = (LS.retries[q.id] || 0) > 0;
  const retrying = Object.values(LS.retries).filter(v => v > 0).length;
  let label = `${LS.done}/${LS.total}`;
  if (retrying > 0) label += ` · ${retrying} wiederholen`;
  document.getElementById('learn-progress-label').textContent = label;
  document.getElementById('learn-retry-chip').style.display = isRetry ? 'inline-block' : 'none';
  document.getElementById('learn-progress-fill').style.width = (LS.total > 0 ? LS.done / LS.total * 100 : 0) + '%';

  let html = `<div class="card"><p class="question-text">${esc(q.frage)}</p></div>`;
  for (const opt of q.optionen) {
    html += `<div class="option" id="opt-${opt.letter}" onclick="toggleLearnOpt('${opt.letter}')">
      <span class="option-letter">${opt.letter.toUpperCase()}</span>
      <span class="option-text">${esc(opt.text)}</span>
    </div>`;
  }
  document.getElementById('learn-content').innerHTML = html;

  document.getElementById('learn-check-btn').style.display = 'flex';
  document.getElementById('learn-check-btn').disabled = true;
  document.getElementById('learn-next-btn').style.display = 'none';
  LS.selected = new Set();
  LS.revealed = false;
}

function toggleLearnOpt(letter) {
  if (LS.revealed) return;
  LS.selected = new Set([letter]);
  for (const opt of LS.queue[0].optionen) {
    const el = document.getElementById('opt-' + opt.letter);
    if (el) el.classList.toggle('selected', LS.selected.has(opt.letter));
  }
  document.getElementById('learn-check-btn').disabled = false;
}

function checkLearnAnswer() {
  if (!LS || LS.revealed) return;
  const q = LS.queue[0];
  const correct = [...LS.selected].sort().join(',') === [...q.richtig].sort().join(',');
  LS.revealed = true;
  LS.lastCorrect = correct;
  recordAnswer(q.id, correct);

  for (const opt of q.optionen) {
    const el = document.getElementById('opt-' + opt.letter);
    if (!el) continue;
    el.classList.add('disabled');
    if (q.richtig.includes(opt.letter)) el.classList.add('correct');
    else if (LS.selected.has(opt.letter)) el.classList.add('wrong');
  }

  const content = document.getElementById('learn-content');
  if (q.erklaerung) {
    content.insertAdjacentHTML('beforeend',
      `<div class="explanation"><div class="explanation-label">Erklärung</div>${esc(q.erklaerung)}</div>`);
  }
  const res = correct
    ? `<div class="card" style="border-color:var(--ok);background:rgba(40,167,69,.1)">✅ Richtig!</div>`
    : `<div class="card" style="border-color:var(--err);background:rgba(220,53,69,.1)">❌ Falsch — richtig: <strong>${q.richtig.map(l=>l.toUpperCase()).join(', ')}</strong></div>`;
  content.insertAdjacentHTML('beforeend', res);

  document.getElementById('learn-check-btn').style.display = 'none';
  const btn = document.getElementById('learn-next-btn');
  btn.style.display = 'flex';
  btn.textContent = (LS.queue.length === 1 && correct) ? 'Fertig 🎉' : 'Weiter →';
}

function nextLearnQuestion() {
  if (!LS) return;
  const q = LS.queue.shift();
  if (LS.lastCorrect) {
    LS.done++;
  } else {
    const tries = (LS.retries[q.id] || 0) + 1;
    LS.retries[q.id] = tries;
    if (tries <= LS.MAX_RETRY) {
      const len = LS.queue.length;
      const pos = len === 0 ? 0 : Math.floor(len * 2 / 3) + (Date.now() % (Math.floor(len / 3) + 1));
      LS.queue.splice(Math.min(pos, len), 0, q);
    } else {
      LS.done++;
    }
  }
  if (LS.queue.length === 0) { goHome(); return; }
  renderLearnQ();
}

// ═══════════════════════════════════════════════════════════════════════════
// EXAM MODE
// ═══════════════════════════════════════════════════════════════════════════
let ES = null;
let examTimerInterval = null;

function buildExamQuestions() {
  const dc = discConfig();
  const bycat = {};
  for (const q of QUESTIONS) {
    if (!dc.excluded.includes(q.kategorie)) {
      (bycat[q.kategorie] = bycat[q.kategorie] || []).push(q);
    }
  }
  const result = [];
  for (const [cat, count] of Object.entries(dc.dist)) {
    const pool = shuffle([...(bycat[cat] || [])]);
    result.push(...pool.slice(0, count));
  }
  return shuffle(result);
}

function startExam() {
  ES = {
    questions: buildExamQuestions(),
    answers: [],
    current: 0,
    secondsLeft: 20 * 60,
  };
  ES.answers = ES.questions.map(() => new Set());
  showScreen('screen-exam');
  startExamTimer();
  renderExamQ();
}

function startExamTimer() {
  stopExamTimer();
  examTimerInterval = setInterval(() => {
    if (!ES) { stopExamTimer(); return; }
    ES.secondsLeft--;
    updateTimerDisplay();
    if (ES.secondsLeft <= 0) { stopExamTimer(); submitExam(); }
  }, 1000);
}

function stopExamTimer() {
  if (examTimerInterval) { clearInterval(examTimerInterval); examTimerInterval = null; }
}

function updateTimerDisplay() {
  if (!ES) return;
  const m = Math.floor(ES.secondsLeft / 60);
  const s = ES.secondsLeft % 60;
  const el = document.getElementById('exam-timer');
  if (el) {
    el.textContent = `${m}:${String(s).padStart(2,'0')}`;
    el.classList.toggle('warn', ES.secondsLeft <= 120);
  }
}

function renderExamQ() {
  if (!ES) return;
  const idx = ES.current;
  const q = ES.questions[idx];
  const total = ES.questions.length;

  document.getElementById('exam-q-label').textContent = `Frage ${idx + 1}/${total}`;
  document.getElementById('exam-progress-fill').style.width = ((idx + 1) / total * 100) + '%';
  updateTimerDisplay();

  let html = `<div class="card"><p class="question-text">${esc(q.frage)}</p></div>`;
  for (const opt of q.optionen) {
    const sel = ES.answers[idx].has(opt.letter);
    html += `<div class="option${sel ? ' selected' : ''}" id="eopt-${opt.letter}" onclick="toggleExamOpt('${opt.letter}')">
      <span class="option-letter">${opt.letter.toUpperCase()}</span>
      <span class="option-text">${esc(opt.text)}</span>
    </div>`;
  }
  document.getElementById('exam-content').innerHTML = html;

  document.getElementById('exam-prev-btn').style.display = idx > 0 ? 'flex' : 'none';
  const isLast = idx === total - 1;
  document.getElementById('exam-next-btn').style.display = isLast ? 'none' : 'flex';
  document.getElementById('exam-submit-btn').style.display = isLast ? 'flex' : 'none';
}

function toggleExamOpt(letter) {
  if (!ES) return;
  const sel = ES.answers[ES.current];
  if (sel.has(letter)) sel.delete(letter); else { sel.clear(); sel.add(letter); }
  const q = ES.questions[ES.current];
  for (const opt of q.optionen) {
    const el = document.getElementById('eopt-' + opt.letter);
    if (el) el.classList.toggle('selected', sel.has(opt.letter));
  }
}

function examPrev() { if (ES && ES.current > 0) { ES.current--; renderExamQ(); } }
function examNext() { if (ES && ES.current < ES.questions.length - 1) { ES.current++; renderExamQ(); } }

function confirmQuitExam() {
  if (confirm('Prüfung abbrechen? Der Fortschritt geht verloren.')) { stopExamTimer(); goHome(); }
}

function submitExam() {
  stopExamTimer();
  if (!ES) return;
  let correct = 0;
  const review = [];
  for (let i = 0; i < ES.questions.length; i++) {
    const q = ES.questions[i];
    const ans = [...ES.answers[i]];
    const isCorrect = ans.sort().join(',') === [...q.richtig].sort().join(',');
    if (isCorrect) correct++;
    review.push({ q, ans, isCorrect });
  }
  const total = ES.questions.length;
  const pct = Math.round(correct / total * 100);
  const pass = pct >= 80;
  showScreen('screen-result');

  let html = `<div class="card" style="text-align:center;padding:24px;margin-bottom:16px">
    <div class="result-badge ${pass ? 'pass' : 'fail'}">${pct}%</div>
    <div class="result-sub">${correct}/${total} Fragen richtig</div>
    <div style="margin-top:12px;font-size:1.1rem;font-weight:700;color:${pass ? 'var(--ok)' : 'var(--err)'}">${pass ? '✅ Bestanden' : '❌ Nicht bestanden'}</div>
    <div style="color:var(--muted);font-size:.8rem;margin-top:4px">Mindestpunktzahl: 80% (20/25)</div>
  </div><div class="section-hdr">Fragen-Übersicht</div>`;

  for (let i = 0; i < review.length; i++) {
    const { q, ans, isCorrect } = review[i];
    const ansLetter = ans.length > 0 ? ans.map(l=>l.toUpperCase()).join(', ') : '–';
    const corrLetter = q.richtig.map(l=>l.toUpperCase()).join(', ');
    html += `<div class="review-item">
      <div class="review-header" onclick="toggleReview(${i})">
        <span class="dot ${isCorrect ? 'dot-ok' : 'dot-err'}"></span>
        <span style="flex:1;font-size:.85rem">${esc(q.frage.substring(0,80))}${q.frage.length>80?'…':''}</span>
        <span style="color:var(--muted);font-size:.8rem" id="rev-arrow-${i}">›</span>
      </div>
      <div class="review-body" id="rev-body-${i}">
        <p style="font-size:.85rem;margin-bottom:10px">${esc(q.frage)}</p>`;
    for (const opt of q.optionen) {
      const isC = q.richtig.includes(opt.letter), wasSel = ans.includes(opt.letter);
      const st = isC ? 'border-color:var(--ok);background:rgba(40,167,69,.1)' : wasSel ? 'border-color:var(--err);background:rgba(220,53,69,.1)' : '';
      html += `<div class="option disabled" style="${st};margin-bottom:6px">
        <span class="option-letter">${opt.letter.toUpperCase()}</span>
        <span class="option-text" style="font-size:.82rem">${esc(opt.text)}</span>
      </div>`;
    }
    html += `<div style="font-size:.8rem;color:var(--muted);margin-top:8px">Deine Antwort: <strong>${ansLetter}</strong> · Richtig: <strong>${corrLetter}</strong></div>`;
    if (q.erklaerung) html += `<div class="explanation" style="margin-top:8px"><div class="explanation-label">Erklärung</div>${esc(q.erklaerung)}</div>`;
    html += `</div></div>`;
  }
  html += `<div style="height:16px"></div><button class="btn btn-grad" onclick="goHome()">← Zurück zum Menü</button><div style="height:24px"></div>`;
  document.getElementById('result-content').innerHTML = html;
}

function toggleReview(i) {
  const body = document.getElementById('rev-body-' + i);
  const arrow = document.getElementById('rev-arrow-' + i);
  body.classList.toggle('open');
  arrow.textContent = body.classList.contains('open') ? '↓' : '›';
}

// ═══════════════════════════════════════════════════════════════════════════
// STATS SCREEN
// ═══════════════════════════════════════════════════════════════════════════
function showStats() {
  showScreen('screen-stats');
  const dc = discConfig();
  const p = getProgress();
  const stats = getOverallStats(dc.excluded);
  const rate = stats.correct + stats.wrong > 0 ? Math.round(stats.correct / (stats.correct + stats.wrong) * 100) : 0;
  const catStats = {};
  const pool = QUESTIONS.filter(q => !dc.excluded.includes(q.kategorie));
  for (const q of pool) {
    if (!catStats[q.kategorie]) catStats[q.kategorie] = { seen:0, correct:0, wrong:0, total:0 };
    catStats[q.kategorie].total++;
    if (p[q.id]) { catStats[q.kategorie].seen++; catStats[q.kategorie].correct += p[q.id].correct; catStats[q.kategorie].wrong += p[q.id].wrong; }
  }

  let html = `<div class="card" style="padding:20px;margin-bottom:16px">
    <div class="result-badge" style="font-size:2.5rem;color:var(--gold)">${rate}%</div>
    <div class="result-sub">Gesamtquote · ${stats.seen}/${stats.total} Fragen gesehen<br><small style="color:var(--muted)">${esc(dc.label)}</small></div>
    <div style="display:flex;justify-content:space-around;margin-top:16px">
      <div style="text-align:center"><div class="stats-val" style="color:var(--ok)">${stats.correct}</div><div class="stats-label">Richtig gesamt</div></div>
      <div style="text-align:center"><div class="stats-val" style="color:var(--err)">${stats.wrong}</div><div class="stats-label">Falsch gesamt</div></div>
    </div></div><div class="section-hdr">Nach Kategorie</div>`;

  for (const [cat, s] of Object.entries(catStats)) {
    const cr = s.correct + s.wrong > 0 ? Math.round(s.correct / (s.correct + s.wrong) * 100) : 0;
    const bw = Math.round(s.seen / s.total * 100);
    html += `<div class="card" style="margin-bottom:10px">
      <div style="display:flex;justify-content:space-between;margin-bottom:6px">
        <span style="font-size:.85rem;font-weight:600">${esc(cat)}</span>
        <span style="font-size:.8rem;color:var(--muted)">${s.seen}/${s.total} · ${cr}%</span>
      </div>
      <div style="height:6px;background:rgba(255,255,255,.08);border-radius:3px;overflow:hidden">
        <div style="height:100%;width:${bw}%;background:linear-gradient(90deg,var(--gold),var(--orange));border-radius:3px"></div>
      </div></div>`;
  }

  html += `<div class="section-hdr">Daten</div>
    <button class="btn btn-sm" style="background:rgba(220,53,69,.2);border:1px solid rgba(220,53,69,.4);color:#ff8a95;margin-bottom:24px;width:auto;padding:10px 20px" onclick="doReset()">🗑️ Fortschritt zurücksetzen</button>`;
  document.getElementById('stats-content').innerHTML = html;
}

function doReset() {
  if (confirm('Gesamten Lernfortschritt löschen? Kann nicht rückgängig gemacht werden.')) {
    resetProgress();
    showStats();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════════════════════════════════════
function init() {
  const saved = localStorage.getItem(LICENSE_KEY);
  if (saved && verifyCode(saved)) {
    showScreen('screen-home');
    renderHome();
    if (!getDisc()) openDiscModal(false);
    return;
  }
  showScreen('screen-license');
}

init();
</script>
</body>
</html>"""

html = HTML_TEMPLATE.replace('QUESTIONS_PLACEHOLDER', questions_json)

output = 'C:/Users/klaas/Desktop/Programmieren/Rettungshunde_Theorietrainer/RHS_Theorie_Trainer.html'
with open(output, 'w', encoding='utf-8') as f:
    f.write(html)

copy = 'C:/Users/klaas/Desktop/Programmieren/APKs/Windows/RHS_Theorie_Trainer.html'
os.makedirs(os.path.dirname(copy), exist_ok=True)
with open(copy, 'w', encoding='utf-8') as f:
    f.write(html)

pages = 'C:/Users/klaas/Desktop/Programmieren/docs/rettungshunde/index.html'
os.makedirs(os.path.dirname(pages), exist_ok=True)
with open(pages, 'w', encoding='utf-8') as f:
    f.write(html)

size = os.path.getsize(output)
print(f'OK: {size:,} Bytes ({size // 1024} KB)')
print(f'Kopie: {copy}')
print(f'GitHub Pages: {pages}')
