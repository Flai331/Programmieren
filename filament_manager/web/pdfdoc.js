// Angebot / Rechnung als PDF (jsPDF aus lib/jspdf.umd.min.js, global window.jspdf).
// doc = { type: 'angebot'|'rechnung', number, date, dueDate?, validUntil?, customer, customerAddress,
//         title, lines: [{text, detail, qty, unit}], totals: {net, vat, rate, gross}, note }
// biz = Absenderdaten aus den Einstellungen (siehe DEFAULT_BIZ in logic.js)

const money = (v) => (Number(v) || 0).toLocaleString('de-DE', { style: 'currency', currency: 'EUR' });
const qtyFmt = (v) => (Number(v) || 0).toLocaleString('de-DE', { maximumFractionDigits: 2 });
const dateFmt = (d) => (d ? new Date(d + (String(d).length === 10 ? 'T00:00:00' : '')).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '');

export function buildDocPdf(doc, biz) {
  const { jsPDF } = window.jspdf;
  const pdf = new jsPDF({ unit: 'mm', format: 'a4' });
  const L = 20, R = 190, W = R - L;
  const isInvoice = doc.type === 'rechnung';
  let y = 20;

  // Absender oben rechts
  pdf.setFont('helvetica', 'bold');
  pdf.setFontSize(14);
  pdf.text(biz.name || 'Absender', R, y, { align: 'right' });
  pdf.setFont('helvetica', 'normal');
  pdf.setFontSize(9);
  const senderLines = [
    ...String(biz.address || '').split(/\r?\n/).filter(Boolean),
    biz.phone ? `Tel. ${biz.phone}` : '',
    biz.email || '',
  ].filter(Boolean);
  senderLines.forEach((l, i) => pdf.text(l, R, y + 6 + i * 4.2, { align: 'right' }));

  // Rücksendezeile + Empfänger (Fensterumschlag-Position)
  y = 50;
  pdf.setFontSize(7);
  pdf.setTextColor(120);
  const back = [biz.name, ...String(biz.address || '').split(/\r?\n/).filter(Boolean)].filter(Boolean).join(' · ');
  if (back) pdf.text(back, L, y);
  pdf.setTextColor(0);
  pdf.setFontSize(11);
  const recipient = [doc.customer, ...String(doc.customerAddress || '').split(/\r?\n/)].filter((x) => x && x.trim());
  recipient.forEach((l, i) => pdf.text(l, L, y + 6 + i * 5));

  // Infoblock rechts
  pdf.setFontSize(10);
  const info = [
    [isInvoice ? 'Rechnungsnr.' : 'Angebotsnr.', doc.number],
    ['Datum', dateFmt(doc.date)],
    ...(isInvoice && doc.serviceDate ? [['Leistungsdatum', dateFmt(doc.serviceDate)]] : []),
    ...(!isInvoice && doc.validUntil ? [['Gültig bis', dateFmt(doc.validUntil)]] : []),
    ...(biz.taxId ? [[biz.vatMode === 'ust' && /^DE/i.test(biz.taxId) ? 'USt-IdNr.' : 'Steuernr.', biz.taxId]] : []),
  ];
  info.forEach(([k, v], i) => {
    pdf.text(k, 130, y + 6 + i * 5);
    pdf.text(String(v || ''), R, y + 6 + i * 5, { align: 'right' });
  });

  // Titel
  y = 95;
  pdf.setFont('helvetica', 'bold');
  pdf.setFontSize(16);
  pdf.text(isInvoice ? 'Rechnung' : 'Angebot', L, y);
  pdf.setFont('helvetica', 'normal');
  pdf.setFontSize(10);
  y += 8;
  const intro = isInvoice
    ? 'Vielen Dank für Ihren Auftrag. Ich berechne Ihnen folgende Leistungen:'
    : 'Vielen Dank für Ihre Anfrage. Gerne biete ich Ihnen Folgendes an:';
  pdf.text(doc.title ? `${intro.replace(/:$/, '')} – ${doc.title}:` : intro, L, y, { maxWidth: W });
  y += 10;

  // Tabelle
  const cols = { pos: L, text: L + 10, qty: 140, unit: 165, total: R };
  const head = () => {
    pdf.setFont('helvetica', 'bold');
    pdf.setFillColor(238, 241, 244);
    pdf.rect(L, y - 5, W, 7, 'F');
    pdf.text('Pos.', cols.pos + 1, y);
    pdf.text('Beschreibung', cols.text, y);
    pdf.text('Menge', cols.qty, y, { align: 'right' });
    pdf.text('Einzelpreis', cols.unit, y, { align: 'right' });
    pdf.text('Gesamt', cols.total, y, { align: 'right' });
    pdf.setFont('helvetica', 'normal');
    y += 7;
  };
  head();
  doc.lines.forEach((l, i) => {
    const textLines = pdf.splitTextToSize(String(l.text || ''), cols.qty - cols.text - 18);
    const detailLines = l.detail ? pdf.splitTextToSize(String(l.detail), cols.qty - cols.text - 18) : [];
    const h = textLines.length * 4.6 + detailLines.length * 4 + 4.5;
    if (y + h > 250) { pdf.addPage(); y = 25; head(); }
    pdf.text(String(i + 1), cols.pos + 1, y);
    pdf.text(textLines, cols.text, y);
    if (detailLines.length) {
      pdf.setFontSize(8.5);
      pdf.setTextColor(100);
      pdf.text(detailLines, cols.text, y + textLines.length * 4.6);
      pdf.setTextColor(0);
      pdf.setFontSize(10);
    }
    pdf.text(qtyFmt(l.qty), cols.qty, y, { align: 'right' });
    pdf.text(money(l.unit), cols.unit, y, { align: 'right' });
    pdf.text(money((Number(l.qty) || 0) * (Number(l.unit) || 0)), cols.total, y, { align: 'right' });
    y += h;
    pdf.setDrawColor(225);
    pdf.line(L, y - 4, R, y - 4);
  });

  // Summen
  y += 3;
  const t = doc.totals;
  const sumRow = (k, v, bold) => {
    pdf.setFont('helvetica', bold ? 'bold' : 'normal');
    pdf.text(k, 140, y, { align: 'right' });
    pdf.text(money(v), R, y, { align: 'right' });
    y += 5.5;
  };
  if (t.rate) {
    sumRow('Nettobetrag', t.net);
    sumRow(`zzgl. ${String(t.rate).replace('.', ',')} % USt.`, t.vat);
    sumRow(isInvoice ? 'Rechnungsbetrag' : 'Gesamtbetrag', t.gross, true);
  } else {
    sumRow(isInvoice ? 'Rechnungsbetrag' : 'Gesamtbetrag', t.gross, true);
  }
  pdf.setFont('helvetica', 'normal');

  // Hinweise
  y += 4;
  const notes = [];
  if (!t.rate) notes.push('Gemäß § 19 UStG wird keine Umsatzsteuer berechnet (Kleinunternehmerregelung).');
  if (isInvoice) {
    notes.push(doc.dueDate
      ? `Bitte überweisen Sie den Betrag bis zum ${dateFmt(doc.dueDate)} unter Angabe der Rechnungsnummer ${doc.number}.`
      : `Bitte überweisen Sie den Betrag unter Angabe der Rechnungsnummer ${doc.number}.`);
  } else {
    if (doc.validUntil) notes.push(`Dieses Angebot ist gültig bis ${dateFmt(doc.validUntil)}.`);
    notes.push('Farben und Oberflächen können je nach Material leicht abweichen. Ich freue mich auf Ihre Rückmeldung.');
  }
  if (doc.note) notes.push(doc.note);
  for (const n of notes) {
    const lines = pdf.splitTextToSize(n, W);
    if (y + lines.length * 4.6 > 265) { pdf.addPage(); y = 25; }
    pdf.text(lines, L, y);
    y += lines.length * 4.6 + 1.5;
  }

  // Fußzeile auf jeder Seite
  const pages = pdf.getNumberOfPages();
  const foot = [
    [biz.name, ...String(biz.address || '').split(/\r?\n/).filter(Boolean)].filter(Boolean).join(' · '),
    [biz.bank, biz.iban ? `IBAN ${biz.iban}` : '', biz.bic ? `BIC ${biz.bic}` : ''].filter(Boolean).join(' · '),
    biz.footer || '',
  ].filter(Boolean);
  for (let i = 1; i <= pages; i++) {
    pdf.setPage(i);
    pdf.setFontSize(7.5);
    pdf.setTextColor(110);
    pdf.setDrawColor(200);
    pdf.line(L, 278, R, 278);
    foot.forEach((f, k) => pdf.text(f, 105, 282 + k * 3.6, { align: 'center', maxWidth: W }));
    if (pages > 1) pdf.text(`Seite ${i} von ${pages}`, R, 292, { align: 'right' });
    pdf.setTextColor(0);
  }
  return pdf.output('blob');
}

export function docFileName(doc) {
  const kind = doc.type === 'rechnung' ? 'Rechnung' : 'Angebot';
  const who = String(doc.customer || '').replace(/[^\wäöüÄÖÜß-]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 30);
  return `${kind}_${doc.number}${who ? '_' + who : ''}.pdf`;
}
