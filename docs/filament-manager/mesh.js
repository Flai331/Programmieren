// 3D-Modelle (STL, OBJ, 3MF) auslesen und daraus den Filamentbedarf schätzen.
// Reine Logik ohne DOM – getestet in test/mesh.test.mjs.
//
// Schätzung wie ein Slicer, nur grob: Außenhaut (Wände, Boden, Deckel) wird voll gedruckt,
// das Innere mit dem Infill-Anteil. Stützen, Brim und Spülen beim Farbwechsel stecken im Zuschlag.

export const PRINTERS = {
  P1S: { name: 'Bambu P1S', x: 256, y: 256, z: 256 },
};

// ---------- Statistik-Sammler ----------

function newStats() {
  return {
    volume: 0, area: 0, triangles: 0,
    min: [Infinity, Infinity, Infinity], max: [-Infinity, -Infinity, -Infinity],
  };
}

function addTriangle(st, ax, ay, az, bx, by, bz, cx, cy, cz) {
  // Volumen über Tetraeder zum Ursprung (Vorzeichen je nach Umlaufsinn)
  st.volume += (ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)) / 6;
  const ux = bx - ax, uy = by - ay, uz = bz - az;
  const vx = cx - ax, vy = cy - ay, vz = cz - az;
  const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
  st.area += Math.sqrt(nx * nx + ny * ny + nz * nz) / 2;
  st.triangles++;
  for (const [x, y, z] of [[ax, ay, az], [bx, by, bz], [cx, cy, cz]]) {
    if (x < st.min[0]) st.min[0] = x; if (x > st.max[0]) st.max[0] = x;
    if (y < st.min[1]) st.min[1] = y; if (y > st.max[1]) st.max[1] = y;
    if (z < st.min[2]) st.min[2] = z; if (z > st.max[2]) st.max[2] = z;
  }
}

function finish(st, extra = {}) {
  if (!st.triangles) throw new Error('Keine Dreiecke im Modell gefunden');
  const size = st.max.map((v, i) => v - st.min[i]);
  return {
    volume: Math.abs(st.volume), // mm³
    area: st.area, // mm²
    triangles: st.triangles,
    size, // mm (x, y, z)
    ...extra,
  };
}

function mergeStats(a, b) {
  a.volume += b.volume; a.area += b.area; a.triangles += b.triangles;
  for (let i = 0; i < 3; i++) { a.min[i] = Math.min(a.min[i], b.min[i]); a.max[i] = Math.max(a.max[i], b.max[i]); }
}

// ---------- STL ----------

export function parseSTL(buffer) {
  const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
  const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const st = newStats();
  // Binär: 80 Byte Kopf, Anzahl, je Dreieck 50 Byte. Manche Binärdateien beginnen trotzdem mit "solid".
  if (bytes.length >= 84) {
    const n = dv.getUint32(80, true);
    if (84 + n * 50 === bytes.length) {
      for (let i = 0; i < n; i++) {
        const o = 84 + i * 50 + 12;
        const f = (k) => dv.getFloat32(o + k * 4, true);
        addTriangle(st, f(0), f(1), f(2), f(3), f(4), f(5), f(6), f(7), f(8));
      }
      return finish(st, { format: 'STL' });
    }
  }
  const text = new TextDecoder().decode(bytes);
  const re = /vertex\s+(\S+)\s+(\S+)\s+(\S+)/g;
  const v = [];
  let m;
  while ((m = re.exec(text))) {
    v.push(+m[1], +m[2], +m[3]);
    if (v.length === 9) { addTriangle(st, ...v); v.length = 0; }
  }
  return finish(st, { format: 'STL' });
}

// ---------- OBJ ----------

export function parseOBJ(text) {
  const verts = [];
  const st = newStats();
  for (const line of String(text).split(/\r?\n/)) {
    const t = line.trim();
    if (t.startsWith('v ')) {
      const p = t.split(/\s+/);
      verts.push([+p[1], +p[2], +p[3]]);
    } else if (t.startsWith('f ')) {
      const idx = t.split(/\s+/).slice(1).map((s) => {
        const i = parseInt(s.split('/')[0], 10);
        return i < 0 ? verts.length + i : i - 1;
      });
      for (let k = 1; k + 1 < idx.length; k++) {
        const a = verts[idx[0]], b = verts[idx[k]], c = verts[idx[k + 1]];
        if (a && b && c) addTriangle(st, ...a, ...b, ...c);
      }
    }
  }
  return finish(st, { format: 'OBJ' });
}

// ---------- 3MF (Modell-Dateien aus dem ZIP) ----------

const UNITS = { micron: 0.001, millimeter: 1, centimeter: 10, inch: 25.4, foot: 304.8, meter: 1000 };

function attrs(tag) {
  const o = {};
  const re = /([\w:]+)\s*=\s*"([^"]*)"/g;
  let m;
  while ((m = re.exec(tag))) o[m[1]] = m[2];
  return o;
}

function parseTransform(s) {
  if (!s) return null;
  const n = s.trim().split(/\s+/).map(Number);
  return n.length === 12 && n.every(Number.isFinite) ? n : null;
}

// 3MF-Matrix (Zeilen, letzte Zeile = Verschiebung): p' = p · M
function mul(a, b) {
  if (!a) return b;
  if (!b) return a;
  const A = (r, c) => (r < 4 ? a[r * 3 + c] : 0);
  const B = (r, c) => b[r * 3 + c];
  const out = [];
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 3; c++) {
      let v = r === 3 ? B(3, c) : 0;
      for (let k = 0; k < 3; k++) v += A(r, k) * B(k, c);
      out.push(v);
    }
  }
  return out;
}

/** Liest eine .model-Datei: { unit, objects: Map(id → {name, verts, tris, components}), items } */
export function parseModelXml(xml) {
  const unitM = xml.match(/<model\b[^>]*\bunit\s*=\s*"([^"]+)"/);
  const unit = UNITS[unitM ? unitM[1] : 'millimeter'] || 1;
  const objects = new Map();
  const objRe = /<object\b([^>]*)>([\s\S]*?)<\/object>/g;
  let om;
  while ((om = objRe.exec(xml))) {
    const a = attrs(om[1]);
    const body = om[2];
    const verts = [];
    const vRe = /<vertex\b([^>]*)\/?>/g;
    let vm;
    while ((vm = vRe.exec(body))) {
      const v = attrs(vm[1]);
      verts.push(+v.x * unit, +v.y * unit, +v.z * unit);
    }
    const tris = [];
    const tRe = /<triangle\b([^>]*)\/?>/g;
    let tm;
    while ((tm = tRe.exec(body))) {
      const t = attrs(tm[1]);
      tris.push(+t.v1, +t.v2, +t.v3);
    }
    const components = [];
    const cRe = /<component\b([^>]*)\/?>/g;
    let cm;
    while ((cm = cRe.exec(body))) {
      const c = attrs(cm[1]);
      components.push({ objectid: c.objectid, path: c['p:path'] || c.path || '', transform: parseTransform(c.transform) });
    }
    objects.set(a.id, { name: a.name || '', verts, tris, components, unit });
  }
  const items = [];
  const iRe = /<item\b([^>]*)\/?>/g;
  let im;
  while ((im = iRe.exec(xml))) {
    const a = attrs(im[1]);
    if (a.printable === '0') continue;
    items.push({ objectid: a.objectid, path: a['p:path'] || '', transform: parseTransform(a.transform) });
  }
  return { unit, objects, items };
}

/**
 * Statistik eines 3MF aus allen .model-Dateien. models: Map(path → Text), path z. B. "/3D/3dmodel.model".
 * Liefert Gesamtwerte und pro Druckteil (Build-Item) die Einzelwerte.
 */
export function stats3mf(models) {
  const parsed = new Map();
  for (const [path, xml] of models) parsed.set(normPath(path), parseModelXml(xml));
  const main = parsed.get('/3D/3dmodel.model') || [...parsed.values()][0];
  if (!main) throw new Error('Kein 3D-Modell in der 3MF-Datei');

  function objectStats(path, id, transform, depth = 0) {
    if (depth > 10) throw new Error('3MF verschachtelt zu tief');
    const file = parsed.get(normPath(path)) || main;
    const obj = file.objects.get(String(id));
    if (!obj) return newStats();
    const st = newStats();
    const { verts, tris } = obj;
    const T = transform;
    const tp = (i) => {
      const x = verts[i * 3], y = verts[i * 3 + 1], z = verts[i * 3 + 2];
      if (!T) return [x, y, z];
      return [
        x * T[0] + y * T[3] + z * T[6] + T[9],
        x * T[1] + y * T[4] + z * T[7] + T[10],
        x * T[2] + y * T[5] + z * T[8] + T[11],
      ];
    };
    for (let k = 0; k + 2 < tris.length; k += 3) {
      addTriangle(st, ...tp(tris[k]), ...tp(tris[k + 1]), ...tp(tris[k + 2]));
    }
    for (const c of obj.components) {
      mergeStats(st, objectStats(c.path || path, c.objectid, mul(c.transform, T), depth + 1));
    }
    return st;
  }

  const total = newStats();
  const parts = [];
  const items = main.items.length ? main.items : [...main.objects.keys()].map((id) => ({ objectid: id, path: '', transform: null }));
  for (const it of items) {
    const st = objectStats(it.path || '/3D/3dmodel.model', it.objectid, it.transform);
    if (!st.triangles) continue;
    const name = (main.objects.get(String(it.objectid)) || {}).name || `Teil ${parts.length + 1}`;
    parts.push({ name, ...finish({ ...st, min: [...st.min], max: [...st.max] }) });
    mergeStats(total, st);
  }
  return finish(total, { format: '3MF', parts });
}

function normPath(p) {
  const s = String(p || '').replace(/\\/g, '/');
  return s.startsWith('/') ? s : '/' + s;
}

// ---------- Filament-Schätzung ----------

export const DEFAULT_SLICE = { infill: 15, walls: 2, lineWidth: 0.42, topBottom: 0.8, extra: 5 };

/**
 * Gramm aus Volumen und Oberfläche.
 * Haut = Oberfläche × Wandstärke (mind. Boden/Deckel-Dicke), höchstens das ganze Volumen;
 * Inneres = Rest × Infill. Zuschlag in % für Stützen/Brim/Ausschuss.
 */
export function estimateGrams(stats, opts = {}) {
  const o = { ...DEFAULT_SLICE, ...opts };
  const density = Number(o.density) || 1.24; // g/cm³
  const shellT = Math.max(o.walls * o.lineWidth, o.topBottom);
  const shell = Math.min(stats.volume, stats.area * shellT);
  const inner = Math.max(0, stats.volume - shell);
  const printed = shell + inner * Math.min(100, Math.max(0, o.infill)) / 100; // mm³
  const grams = (printed / 1000) * density * (1 + (Number(o.extra) || 0) / 100);
  return {
    grams: Math.round(grams * 10) / 10,
    solidGrams: Math.round((stats.volume / 1000) * density * 10) / 10,
    shellShare: stats.volume ? Math.round((shell / stats.volume) * 100) : 0,
  };
}

/** Passt das Teil in den Bauraum (auch gedreht um die Hochachse)? */
export function fitsPrinter(size, printer = PRINTERS.P1S) {
  const [x, y, z] = size;
  if (z > printer.z) return false;
  return (x <= printer.x && y <= printer.y) || (y <= printer.x && x <= printer.y);
}
