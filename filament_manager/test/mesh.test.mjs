import test from 'node:test';
import assert from 'node:assert/strict';
import { makeZip } from './helpers.mjs';
import * as M from '../web/mesh.js';
import { analyzeModelFile } from '../web/importer.js';
import { SLICE_INFO } from './helpers.mjs';

// Würfel mit Kantenlänge s (12 Dreiecke, nach außen orientiert)
function cubeTris(s = 20, o = [0, 0, 0]) {
  const v = [[0, 0, 0], [s, 0, 0], [s, s, 0], [0, s, 0], [0, 0, s], [s, 0, s], [s, s, s], [0, s, s]].map((p) => p.map((x, i) => x + o[i]));
  const f = [[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7], [0, 1, 5], [0, 5, 4], [1, 2, 6], [1, 6, 5], [2, 3, 7], [2, 7, 6], [3, 0, 4], [3, 4, 7]];
  return { v, f };
}

function binarySTL({ v, f }) {
  const buf = Buffer.alloc(84 + f.length * 50);
  buf.write('solid binary-aber-mit-solid-im-Kopf', 0);
  buf.writeUInt32LE(f.length, 80);
  f.forEach((t, i) => {
    const o = 84 + i * 50 + 12;
    t.forEach((vi, k) => v[vi].forEach((c, j) => buf.writeFloatLE(c, o + (k * 3 + j) * 4)));
  });
  return new Uint8Array(buf);
}

function asciiSTL({ v, f }) {
  return 'solid cube\n' + f.map((t) => `facet normal 0 0 0\nouter loop\n${t.map((i) => `vertex ${v[i].join(' ')}`).join('\n')}\nendloop\nendfacet`).join('\n') + '\nendsolid cube\n';
}

const near = (a, b, eps = 1e-6) => assert.ok(Math.abs(a - b) <= eps * Math.max(1, Math.abs(b)), `${a} ≉ ${b}`);

test('STL binär (auch mit "solid" im Kopf) und ASCII', () => {
  for (const st of [M.parseSTL(binarySTL(cubeTris())), M.parseSTL(new TextEncoder().encode(asciiSTL(cubeTris())))]) {
    near(st.volume, 8000);
    near(st.area, 2400);
    assert.deepEqual(st.size.map(Math.round), [20, 20, 20]);
    assert.equal(st.triangles, 12);
  }
});

test('Umgekehrt orientierte Flächen ergeben trotzdem positives Volumen', () => {
  const c = cubeTris();
  c.f = c.f.map((t) => [t[0], t[2], t[1]]);
  near(M.parseSTL(binarySTL(c)).volume, 8000);
});

test('OBJ mit Vierecken und negativen Indizes', () => {
  const obj = `v 0 0 0\nv 10 0 0\nv 10 10 0\nv 0 10 0\nv 0 0 10\nv 10 0 10\nv 10 10 10\nv 0 10 10
f 1 4 3 2\nf 5 6 7 8\nf 1 2 6 5\nf 2 3 7 6\nf 3 4 8 7\nf -4 -8 -5 -1`;
  const st = M.parseOBJ(obj);
  near(st.volume, 1000);
  near(st.area, 600);
});

function modelXml(unit = 'millimeter') {
  const { v, f } = cubeTris(10);
  return `<?xml version="1.0"?><model unit="${unit}" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02"><resources>
<object id="1" name="Würfel" type="model"><mesh><vertices>${v.map((p) => `<vertex x="${p[0]}" y="${p[1]}" z="${p[2]}"/>`).join('')}</vertices>
<triangles>${f.map((t) => `<triangle v1="${t[0]}" v2="${t[1]}" v3="${t[2]}"/>`).join('')}</triangles></mesh></object></resources><build><item objectid="1"/></build></model>`;
}

test('3MF: Einheit cm, Bambu-Aufbau mit Bauteil-Verweis, Skalierung und zwei Druckteilen', () => {
  near(M.stats3mf(new Map([['3D/3dmodel.model', modelXml('centimeter')]])).volume, 1e6); // 10 cm Würfel

  const sub = modelXml().replace(/<build>[\s\S]*<\/build>/, '<build/>');
  const main = `<?xml version="1.0"?><model unit="millimeter" xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06"><resources>
<object id="5" name="Halter" type="model"><components><component p:path="/3D/Objects/object_1.model" objectid="1" transform="2 0 0 0 2 0 0 0 2 0 0 0"/></components></object>
</resources><build><item objectid="5" transform="1 0 0 0 1 0 0 0 1 100 0 0"/><item objectid="5" transform="1 0 0 0 1 0 0 0 1 0 100 0" printable="1"/><item objectid="5" printable="0"/></build></model>`;
  const st = M.stats3mf(new Map([['3D/3dmodel.model', main], ['3D/Objects/object_1.model', sub]]));
  assert.equal(st.parts.length, 2);
  near(st.parts[0].volume, 8000); // 10 mm × 2 = 20 mm Würfel
  assert.equal(st.parts[0].name, 'Halter');
  near(st.volume, 16000);
  assert.deepEqual(st.parts[0].size.map(Math.round), [20, 20, 20]);
  assert.deepEqual(st.size.map(Math.round), [120, 120, 20]);
});

test('Schätzung: Haut + Infill, Grenzen, Bauraum', () => {
  const cube = { volume: 8000, area: 2400 };
  const e = M.estimateGrams(cube, { density: 1.24, infill: 15, walls: 2, extra: 0 });
  // Haut 2400 × 0,84 = 2016 mm³, Inneres 5984 × 15 % = 897,6 → 2913,6 mm³ × 1,24 g/cm³ = 3,61 g
  assert.equal(e.grams, 3.6);
  assert.equal(e.solidGrams, 9.9);
  assert.equal(M.estimateGrams(cube, { density: 1.24, infill: 100, extra: 0 }).grams, 9.9);
  // dünnes Teil: Haut höchstens das ganze Volumen
  assert.equal(M.estimateGrams({ volume: 100, area: 10000 }, { density: 1, extra: 0 }).grams, 0.1);
  assert.equal(M.estimateGrams(cube, { density: 1.24, infill: 15, extra: 10 }).grams, 4);
  assert.equal(M.fitsPrinter([250, 100, 50]), true);
  assert.equal(M.fitsPrinter([100, 300, 50]), false);
  assert.equal(M.fitsPrinter([100, 100, 257]), false);
});

test('analyzeModelFile: STL, ungeslicte und geslicte 3MF', async () => {
  const stl = await analyzeModelFile(new File([binarySTL(cubeTris())], 'Teil.STL'));
  assert.equal(stl.kind, 'mesh');
  near(stl.stats.volume, 8000);

  const raw = await analyzeModelFile(new File([makeZip({ '3D/3dmodel.model': modelXml() })], 'Projekt.3mf'));
  assert.equal(raw.kind, 'mesh');
  near(raw.stats.volume, 1000);

  const sliced = await analyzeModelFile(new File([makeZip({ '3D/3dmodel.model': modelXml(), 'Metadata/slice_info.config': SLICE_INFO })], 'Halter.gcode.3mf'));
  assert.equal(sliced.kind, 'sliced');
  assert.equal(sliced.plates.length, 2);
  assert.equal(sliced.plates[0].filaments[0].grams, 24.96);
  near(sliced.stats.volume, 1000);

  await assert.rejects(analyzeModelFile(new File(['x'], 'bild.png')), /STL/);
});
