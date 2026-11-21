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
