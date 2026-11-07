// Nur die PDF-Szene des Films „Einsatz Scheuen“ neu aufnehmen (ohne JUH-Formular)
const fs = require('fs');
const { Rec, sleep } = require('./lib');
(async () => {
  const imgs = fs.readdirSync('pdfimg-einsatz').filter((x) => !x.startsWith('e-juh')).sort()
    .sort((a, b) => (a.startsWith('e-karte') ? 0 : 1) - (b.startsWith('e-karte') ? 0 : 1)).map((x) => `file://${__dirname}/pdfimg-einsatz/${x}`);
  const html = `<html><head><style>body{margin:0;width:1600px;height:900px;overflow:hidden;background:#e9ebef}
    .pg{position:absolute;top:50px;height:800px;box-shadow:0 12px 40px rgba(0,0,0,.28);background:#fff;opacity:0;transform:translateY(60px) scale(.96);transition:all .7s cubic-bezier(.2,.8,.2,1)} .pg.on{opacity:1;transform:none}</style></head>
    <body>${imgs.map((u, i) => `<img class="pg" id="pg${i}" src="${u}" style="left:${120 + i * (900 / Math.max(1, imgs.length - 1))}px;z-index:${i}">`).join('')}</body></html>`;
  fs.writeFileSync('pdfs-einsatz.html', html);
  const pdf = new Rec('pdf');
  const pp = await pdf.start(`file://${__dirname}/pdfs-einsatz.html`);
  await sleep(800);
  await pdf.seg('pdfs', { t: 'Fertig zum Verschicken', s: '' });
  for (let i = 0; i < imgs.length; i++) { await pp.evaluate((i) => document.getElementById('pg' + i).classList.add('on'), i); await sleep(900); }
  await sleep(2400);
  await pdf.finish();
  console.log('Seiten:', imgs.length);
})();
