import test from 'node:test';
import assert from 'node:assert/strict';
import { makeZip, SLICE_INFO, GCODE_BAMBU, GCODE_PRUSA } from './helpers.mjs';
import { listZip, bytesToText } from '../web/zip.js';
import { parseFile } from '../web/importer.js';
import * as L from '../web/logic.js';

test('normHex', () => {
  assert.equal(L.normHex('#fff'), '#FFFFFF');
  assert.equal(L.normHex('FF0000FF'), '#FF0000');
  assert.equal(L.normHex('#00ae42'), '#00AE42');
  assert.equal(L.normHex('nix'), '');
});

test('colorDistance und Grundfarbe', () => {
  assert.equal(L.colorDistance('#FFFFFF', '#FFFFFF'), 0);
  assert.ok(L.colorDistance('#FFFFFF', '#000000') > 90);
  assert.equal(L.baseColorName('#FE0000'), 'Rot');
  assert.equal(L.baseColorName('#101010'), 'Schwarz');
});

test('materialBase', () => {
  assert.equal(L.materialBase('PLA Basic'), 'PLA');
  assert.equal(L.materialBase('pla matte'), 'PLA');
  assert.equal(L.materialBase('PLA-CF'), 'PLA-CF');
  assert.equal(L.materialBase('PETG HF'), 'PETG');
  assert.equal(L.materialBase('PLA+'), 'PLA');
});

test('gramsToMeters: 1 kg PLA 1,75 mm ≈ 335 m', () => {
  const m = L.gramsToMeters(1000, 'PLA', 1.75);
  assert.ok(m > 320 && m < 345, String(m));
});

test('ZIP-Leser liest Einträge', async () => {
  const zip = await listZip(makeZip({ 'a.txt': 'hallo', 'Metadata/slice_info.config': SLICE_INFO }));
  assert.equal(zip.entries.length, 2);
  assert.equal(bytesToText(await zip.read('a.txt')), 'hallo');
  assert.equal(await zip.read('fehlt'), null);
});

test('parseSliceInfo: Platten und Filamente, 0-g-Filamente ignoriert', () => {
  const plates = L.parseSliceInfo(SLICE_INFO);
  assert.equal(plates.length, 2);
  assert.equal(plates[0].durationS, 5013);
  assert.equal(plates[0].filaments.length, 2);
  assert.deepEqual(plates[0].filaments[0], {
    slot: 1, type: 'PLA', colorHex: '#FFFFFF', grams: 24.96, meters: 8.37, bambuId: 'GFA00',
  });
  assert.deepEqual(plates[0].objects, ['Halter.stl']);
});

test('parseFile: .gcode.3mf mit zwei Platten + Vorschaubild', async () => {
  const bytes = makeZip({
    'Metadata/slice_info.config': SLICE_INFO,
    'Metadata/plate_1.png': 'PNGDATA',
  });
  const file = new File([bytes], 'Halter.gcode.3mf', { lastModified: Date.UTC(2026, 10, 1) });
  const { prints, thumbs } = await parseFile(file);
  assert.equal(prints.length, 2);
  assert.equal(prints[0].name, 'Halter (Platte 1)');
  assert.equal(prints[0].date, '2026-11-01T00:00:00.000Z');
  assert.ok(thumbs[prints[0].fingerprint] instanceof Blob);
  assert.equal(thumbs[prints[1].fingerprint], undefined);
});

test('parseFile: ungeslicte 3MF gibt verständlichen Fehler', async () => {
  const file = new File([makeZip({ '3D/3dmodel.model': '<model/>' })], 'Projekt.3mf');
  await assert.rejects(parseFile(file), /nicht gesliced/);
});

test('parseGcode: Bambu-Kopf mit zwei Filamenten', () => {
  const [p] = L.parseGcode(GCODE_BAMBU, 'Teil.gcode', '2026-01-01T00:00:00.000Z');
  assert.equal(p.filaments.length, 2);
  assert.equal(p.filaments[0].grams, 39.63);
  assert.equal(p.filaments[0].colorHex, '#00AE42');
  assert.equal(p.filaments[1].bambuId, 'GFA01');
  assert.equal(p.filaments[0].meters, 13.29);
  assert.equal(p.durationS, 2 * 3600 + 26 * 60 + 33);
});

test('parseGcode: Prusa/Orca-Ende', () => {
  const [p] = L.parseGcode(GCODE_PRUSA, 'x.gcode', '');
  assert.equal(p.filaments.length, 1);
  assert.equal(p.filaments[0].grams, 15.2);
  assert.equal(p.filaments[0].type, 'PETG');
  assert.equal(p.durationS, 3903);
});

test('parseCloudTasks: Bambu-Cloud-Historie', () => {
  const json = {
    total: 3,
    hits: [
      {
        id: 111, designTitle: 'Benchy', status: 2, weight: 12.5, costTime: 2400,
        endTime: '2026-10-05T10:00:00Z',
        amsDetailMapping: [
          { ams: 2, sourceColor: 'FF0000FF', filamentType: 'PLA', filamentId: 'GFA00', weight: 12.5 },
        ],
      },
      { id: 112, title: 'Fehldruck', status: 3, weight: 30, amsDetailMapping: [] },
      { id: 113, title: 'Läuft', status: 1, weight: 5 },
    ],
  };
  const prints = L.parseCloudTasks(json);
  assert.equal(prints.length, 2);
  assert.equal(prints[0].fingerprint, 'cloud:111');
  assert.equal(prints[0].filaments[0].colorHex, '#FF0000');
  assert.equal(prints[0].filaments[0].amsSlot, 2);
  assert.equal(prints[1].status, 'failed');
  assert.equal(prints[1].filaments[0].grams, 30);
});

const spool = (o) => ({ id: 's1', brand: 'Bambu', material: 'PLA Basic', colorName: 'Weiß', colorHex: '#FFFFFF', netWeight: 1000, emptyWeight: 250, price: 20, ...o });

test('spoolRemaining: Verbrauch, Fehldruck anteilig, Wiegung setzt neu an', () => {
  const s = spool();
  const prints = [
    { id: 'p1', date: '2026-01-01T10:00:00Z', filaments: [{ spoolId: 's1', grams: 100 }] },
    { id: 'p2', date: '2026-01-02T10:00:00Z', status: 'failed', progress: 50, filaments: [{ spoolId: 's1', grams: 80 }] },
    { id: 'p3', date: '2026-01-03T10:00:00Z', filaments: [{ spoolId: 'x', grams: 500 }] },
  ];
  let r = L.spoolRemaining(s, prints);
  assert.equal(r.remaining, 860);
  assert.equal(r.used, 140);
  assert.equal(r.percent, 86);
  assert.equal(r.printCount, 2);

  s.weighings = [{ date: '2026-01-01T12:00:00Z', remaining: 850 }];
  r = L.spoolRemaining(s, prints);
  assert.equal(r.remaining, 810); // 850 − 40 (nur Fehldruck nach der Wiegung)
});

test('remainingFromScale', () => {
  assert.equal(L.remainingFromScale(780, 250), 530);
  assert.equal(L.remainingFromScale(200, 250), 0);
});

test('Box-Belegung, freier Platz, Doppelbelegung', () => {
  const settings = { boxCount: 2, slotsPerBox: 4 };
  const spools = [1, 2, 3, 4].map((n) => spool({ id: 'b' + n, location: { kind: 'box', box: 1, slot: n } }));
  assert.deepEqual(L.firstFreeSlot(spools, settings), { kind: 'box', box: 2, slot: 1 });
  assert.deepEqual(L.firstFreeSlot(spools, settings, 'b3'), { kind: 'box', box: 1, slot: 3 });
  assert.equal(L.boxOccupancy(1, spools, 4).filter(Boolean).length, 4);
  assert.equal(L.occupant({ kind: 'box', box: 1, slot: 2 }, spools).id, 'b2');
  assert.equal(L.occupant({ kind: 'box', box: 1, slot: 2 }, spools, 'b2'), null);
  assert.equal(L.locationLabel({ kind: 'box', box: 3, slot: 2 }), 'Box 3 · Platz 2');
});

test('searchSpools: Wörter, Umlaute, Grundfarbe, Farbwähler', () => {
  const spools = [
    spool({ id: 'a', colorName: 'Jade White', colorHex: '#FFFFFF', location: { kind: 'box', box: 2, slot: 1 } }),
    spool({ id: 'b', material: 'PETG HF', colorName: 'Kirsche', colorHex: '#C0101A' }),
    spool({ id: 'c', colorName: 'Grün', colorHex: '#00AE42', archived: true }),
  ];
  assert.deepEqual(L.searchSpools(spools, 'weiss').map((s) => s.id), ['a']);
  assert.deepEqual(L.searchSpools(spools, 'petg rot').map((s) => s.id), ['b']);
  assert.deepEqual(L.searchSpools(spools, 'box 2').map((s) => s.id), ['a']);
  assert.deepEqual(L.searchSpools(spools, 'grün').map((s) => s.id), []);
  assert.deepEqual(L.searchSpools(spools, 'grün', { includeArchived: true }).map((s) => s.id), ['c']);
  assert.deepEqual(L.searchSpools(spools, '', { colorHex: '#FF0000' }).map((s) => s.id), ['b']);
});

test('suggestSpool: Material + Farbe, AMS-Slot bevorzugt', () => {
  const spools = [
    spool({ id: 'w1', location: { kind: 'box', box: 1, slot: 1 } }),
    spool({ id: 'w2', location: { kind: 'ams', unit: 1, slot: 3 } }),
    spool({ id: 'r', material: 'PETG', colorHex: '#FF0000' }),
  ];
  assert.equal(L.suggestSpool({ type: 'PLA', colorHex: '#FFFFFF' }, spools, []).id, 'w2');
  assert.equal(L.suggestSpool({ type: 'PLA', colorHex: '#FAFAFA', amsSlot: 2 }, spools, []).id, 'w2');
  assert.equal(L.suggestSpool({ type: 'PLA', colorHex: '#FF0000' }, spools, []), null);
  assert.equal(L.suggestSpool({ type: 'PETG', colorHex: '#EE0000' }, spools, []).id, 'r');
});

test('Aufträge: Fortschritt, Kosten, Angebot, passende Rollen', () => {
  const order = { id: 'o1', quantity: 10, manualDone: 1, gramsPerPiece: 20, material: 'PLA', colorHex: '#FFFFFF' };
  const spools = [spool(), spool({ id: 's2', netWeight: 1000, weighings: [{ date: '2020-01-01', remaining: 50 }] })];
  const prints = [
    { id: 'p1', orderId: 'o1', pieces: 4, durationS: 7200, filaments: [{ spoolId: 's1', grams: 80 }] },
    { id: 'p2', orderId: 'o1', pieces: 4, status: 'failed', progress: 25, durationS: 7200, filaments: [{ spoolId: 's1', grams: 80 }] },
  ];
  const pr = L.orderProgress(order, prints);
  assert.equal(pr.done, 5);
  assert.equal(pr.open, 5);
  assert.equal(pr.percent, 50);
  const c = L.orderCosts(order, prints, spools, { hourlyRate: 1 });
  assert.equal(c.grams, 100);
  assert.equal(c.material, 2);
  assert.equal(c.hours, 2.5);
  assert.equal(c.total, 4.5);
  const q = L.quote({ gramsPerPiece: 20, hoursPerPiece: 0.5, pieces: 5, pricePerKg: 20, hourlyRate: 1, markup: 100 });
  assert.equal(q.material, 2);
  assert.equal(q.total, 9);
  const fit = L.spoolsForOrder(order, spools, prints);
  assert.equal(fit.find((x) => x.spool.id === 's1').enough, true);
  assert.equal(fit.find((x) => x.spool.id === 's2').enough, false);
});

test('modelSite und daysUntil', () => {
  assert.equal(L.modelSite('https://makerworld.com/de/models/123'), 'MakerWorld');
  assert.equal(L.modelSite('https://www.printables.com/model/1'), 'Printables');
  assert.equal(L.modelSite('https://example.org/x'), 'example.org');
  assert.equal(L.daysUntil('2026-11-25', new Date(2026, 10, 21, 15)), 4);
});

test('orderSpoolCosts: Kosten je passender Rolle, beste Rolle mit Preis die reicht', () => {
  const order = { id: 'o', quantity: 10, gramsPerPiece: 50, material: 'PLA', colorHex: '#FFFFFF' };
  const spools = [
    spool({ id: 'a', price: 0 }), // ohne Preis
    spool({ id: 'b', price: 25, weighings: [{ date: '2020-01-01', remaining: 200 }] }), // reicht nicht (500 g nötig)
    spool({ id: 'c', price: 30, colorHex: '#F4F4F4' }),
    spool({ id: 'd', material: 'PETG', price: 10 }), // falsches Material
  ];
  const r = L.orderSpoolCosts(order, spools, []);
  assert.deepEqual(r.rows.map((x) => x.spool.id).sort(), ['a', 'b', 'c']);
  const b = r.rows.find((x) => x.spool.id === 'b');
  assert.equal(b.pricePerKg, 25);
  assert.equal(b.perPiece, 1.25);
  assert.equal(b.piecesPossible, 4);
  assert.equal(b.enough, false);
  assert.equal(r.rows.find((x) => x.spool.id === 'a').hasPrice, false);
  assert.equal(r.best.spool.id, 'c');
  assert.equal(r.best.total, 15);
});

test('Preiskalkulation: Vorgaben, Überschreiben im Auftrag, Marge, Rundung, Mindestpreis', () => {
  const settings = { markup: 50, hourlyRate: 0.5, laborRate: 30, minOrder: 10, rounding: 0.5 };
  assert.deepEqual(L.pricingFor(settings, {}), { markup: 50, hourlyRate: 0.5, laborRate: 30, minOrder: 10, rounding: 0.5 });
  assert.equal(L.pricingFor(settings, { pricing: { markup: '80', laborRate: '' } }).markup, 80);
  assert.equal(L.pricingFor(settings, { pricing: { markup: '80', laborRate: '' } }).laborRate, 30);
  assert.equal(L.pricingFor({}, {}).markup, 30);

  const p = L.pricingFor(settings, {});
  // 20 g à 25 €/kg = 0,50 € + 1 h × 0,50 € = 1,00 € Kosten → × 1,5 = 1,50 €
  const c = L.priceCalc({ gramsPerPiece: 20, hoursPerPiece: 1, quantity: 10, pricePerKg: 25, designHours: 2, extraCost: 4.9 }, p);
  assert.equal(c.costPiece, 1);
  assert.equal(c.unit, 1.5);
  assert.equal(c.pieces, 15);
  assert.equal(c.labor, 60);
  assert.equal(c.total, 79.9);
  assert.equal(c.minFill, 0);
  assert.equal(c.profit, 65); // 79,90 − 10 Kosten − 4,90 Versand
  // Aufrunden auf 0,50: 1,04 → 1,50
  assert.equal(L.priceCalc({ gramsPerPiece: 20, quantity: 1, pricePerKg: 26 }, { ...p, markup: 100 }).unit, 1.5);
  // Mindestpreis füllt auf
  const small = L.priceCalc({ gramsPerPiece: 5, quantity: 1, pricePerKg: 20 }, p);
  assert.equal(small.unit, 0.5);
  assert.equal(small.minFill, 9.5);
  assert.equal(small.total, 10);

  const lines = L.docLines({ title: 'Halter', kind: 'eigen', material: 'PETG', colorWish: 'schwarz', designHours: 2, extraCost: 4.9 }, c, p);
  assert.deepEqual(lines.map((l) => [l.text, l.qty, l.unit]), [['Halter', 10, 1.5], ['Konstruktion / Modellierung', 1, 60], ['Versand / Sonstiges', 1, 4.9]]);
  assert.equal(lines[0].detail, '3D-Druck, PETG schwarz');
  assert.deepEqual(L.docTotals(lines, { vatMode: 'klein' }), { net: 79.9, vat: 0, rate: 0, gross: 79.9 });
  assert.deepEqual(L.docTotals(lines, { vatMode: 'ust', vatRate: 19 }), { net: 79.9, vat: 15.18, rate: 19, gross: 95.08 });
  assert.equal(L.docNumber('RE', 7, new Date(2026, 10, 21)), 'RE-2026-007');
});

test('Rollenempfehlung: Material, Farbe, Reste aufbrauchen, Aufteilen auf zwei Rollen', () => {
  const sp = [
    spool({ id: 'w-voll', colorHex: '#FFFFFF', price: 20 }),
    spool({ id: 'w-rest', colorHex: '#FDFDFD', price: 20, weighings: [{ date: '2020-01-01', remaining: 150 }] }),
    spool({ id: 'w-rest2', colorHex: '#FAFAFA', price: 20, weighings: [{ date: '2020-01-01', remaining: 80 }] }),
    spool({ id: 'grau', colorHex: '#8E9089', price: 20 }),
    spool({ id: 'petg-w', material: 'PETG', colorHex: '#FFFFFF', price: 25 }),
  ];
  const line = { material: 'PLA', colorHex: '#FFFFFF' };
  // 100 g: der kleinste Rest, der reicht (150 g), wird zuerst verbraucht
  assert.equal(L.recommendSpools(line, 100, sp, []).best.id, 'w-rest');
  // 500 g: nur die volle Rolle reicht
  assert.equal(L.recommendSpools(line, 500, sp, []).best.id, 'w-voll');
  // 1200 g: keine reicht allein → aufteilen auf weiße Rollen (voll + Reste), Rest fehlt
  const big = L.recommendSpools(line, 1200, sp, []);
  assert.equal(big.best, null);
  assert.deepEqual(big.split.map((x) => [x.spool.id, x.grams]), [['w-voll', 1000], ['w-rest', 150], ['w-rest2', 50]]);
  assert.equal(big.enough, true);
  // Material falsch → PETG-Rolle nie für PLA
  assert.ok(!L.recommendSpools(line, 10, sp, []).candidates.some((c) => c.spool.id === 'petg-w'));
  // schon für eine andere Zeile verplant
  assert.equal(L.recommendSpools(line, 100, sp, [], { 'w-rest': 100 }).best.id, 'w-voll');
});

test('Endpreis: mehrere Farben/Materialien, Stützen, Maschine, Marge, Arbeit, Versand – von Hand nachgerechnet', () => {
  const sp = [
    spool({ id: 'schwarz', material: 'PETG', colorHex: '#000000', price: 22 }), // 22 €/kg
    spool({ id: 'weiss', material: 'PLA', colorHex: '#FFFFFF', price: 0 }), // ohne Preis
    spool({ id: 'pla-rot', material: 'PLA', colorHex: '#E01A1A', price: 18 }),
    spool({ id: 'pla-blau', material: 'PLA', colorHex: '#0A2CA5', price: 26 }), // PLA-Schnitt 22 €/kg
  ];
  const order = {
    id: 'o1', quantity: 4, hoursPerPiece: 2, designHours: 1.5, extraCost: 4.95,
    lines: [
      { id: 'a', material: 'PETG', colorHex: '#000000', grams: 30, supportGrams: 5 },
      { id: 'b', material: 'PLA', colorHex: '#FFFFFF', grams: 10, supportGrams: 0 },
    ],
  };
  const settings = { markup: 40, hourlyRate: 0.3, laborRate: 25, minOrder: 0, rounding: 0.1 };
  const r = L.orderPrice(order, sp, [], settings);
  // Zeile a: 35 g × 22 €/kg = 0,77 € ; Zeile b: 10 g × Ø PLA 22 €/kg = 0,22 €
  assert.equal(r.plan.rows[0].spool.id, 'schwarz');
  assert.equal(r.plan.rows[0].priceSource, 'spool');
  assert.equal(r.plan.rows[1].spool.id, 'weiss');
  assert.equal(r.plan.rows[1].priceSource, 'avg');
  assert.equal(r.plan.rows[1].pricePerKg, 22);
  assert.equal(r.plan.gramsPerPiece, 45);
  assert.equal(r.plan.materialPiece, 0.99);
  // Kosten/Stück = 0,99 + 2 h × 0,30 = 1,59 ; × 1,4 = 2,226 → aufgerundet 2,30
  assert.equal(r.calc.costPiece, 1.59);
  assert.equal(r.calc.unit, 2.3);
  // 4 × 2,30 = 9,20 + 1,5 h × 25 = 37,50 + 4,95 = 51,65
  assert.equal(r.calc.pieces, 9.2);
  assert.equal(r.calc.labor, 37.5);
  assert.equal(r.total, 51.65);
  // Gewinn = 51,65 − 4 × 1,59 − 4,95 = 40,34
  assert.equal(r.calc.profit, 40.34);
  // Marge im Auftrag überschrieben
  assert.equal(L.orderPrice({ ...order, pricing: { markup: 100 } }, sp, [], settings).calc.unit, 3.2);
  // fester Preis
  const m = L.orderPrice({ ...order, priceManual: true, price: 60 }, sp, [], settings);
  assert.equal(m.total, 60);
  assert.equal(m.manual, true);
  // gewählte Rolle statt Empfehlung
  const own = L.orderPrice({ ...order, lines: [{ ...order.lines[0], spoolId: 'schwarz' }, { ...order.lines[1], spoolId: 'pla-blau' }] }, sp, [], settings);
  assert.equal(own.plan.rows[1].pricePerKg, 26);
  // alte Aufträge ohne Zeilen
  const old = L.orderPrice({ id: 'x', quantity: 2, gramsPerPiece: 50, material: 'PETG', colorHex: '#000000' }, sp, [], settings);
  assert.equal(old.plan.rows.length, 1);
  assert.equal(old.plan.materialPiece, 1.1);
  // Mindestpreis
  const tiny = L.orderPrice({ id: 't', quantity: 1, lines: [{ material: 'PETG', colorHex: '#000000', grams: 5 }] }, sp, [], { ...settings, minOrder: 10 });
  assert.equal(tiny.calc.minFill > 0, true);
  assert.equal(tiny.total, 10);
});

test('Kundenliste: zusammenführen nach Namen, leere Felder überschreiben nicht', () => {
  let r = L.upsertCustomer([], { name: 'Erika Mustermann', contact: '0171', address: 'Weg 1' });
  const id = r.id;
  r = L.upsertCustomer(r.list, { name: ' erika mustermann ', contact: '', address: 'Weg 2' });
  assert.equal(r.id, id);
  assert.equal(r.list.length, 1);
  assert.equal(r.list[0].contact, '0171');
  assert.equal(r.list[0].address, 'Weg 2');
  r = L.upsertCustomer(r.list, { name: 'Anton' });
  assert.deepEqual(r.list.map((c) => c.name), ['Anton', 'Erika Mustermann']);
  assert.equal(L.upsertCustomer(r.list, { name: '  ' }).id, '');
});

test('Angebot: Materialien und Farben aller Zeilen', () => {
  const o = { title: 'Figur', lines: [{ material: 'PLA', colorHex: '#FFFFFF', grams: 15 }, { material: 'PLA', colorHex: '#E01A1A', grams: 3 }, { material: 'PETG', colorWish: 'schwarz matt', grams: 2 }] };
  const lines = L.docLines(o, { unit: 1, qty: 2, labor: 0, extras: 0, minFill: 0 }, L.pricingFor({}, o));
  assert.equal(lines[0].detail, '3D-Druck, PLA weiß / PLA rot / PETG schwarz matt');
});
