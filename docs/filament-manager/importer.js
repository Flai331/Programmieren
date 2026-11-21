// Liest Dateien (File/Blob) und liefert Druck-Entwürfe für den Import-Dialog.
import { listZip, bytesToText } from './zip.js';
import { parseSliceInfo, printsFrom3mf, parseGcode, parseCloudTasks } from './logic.js';
import { parseSTL, parseOBJ, stats3mf } from './mesh.js';

const GCODE_CHUNK = 512 * 1024;

function fileDate(file) {
  const t = file.lastModified || Date.now();
  return new Date(t).toISOString();
}

export async function parseFile(file) {
  const name = file.name || 'Datei';
  const lower = name.toLowerCase();

  if (lower.endsWith('.json')) {
    const prints = parseCloudTasks(await file.text());
    if (!prints.length) throw new Error('Keine Drucke in der JSON-Datei gefunden');
    return { prints, thumbs: {} };
  }

  if (lower.endsWith('.3mf')) {
    const zip = await listZip(file);
    if (!zip.has('Metadata/slice_info.config')) {
      throw new Error(
        'Diese 3MF ist nicht gesliced. In Bambu Studio erst „Slicen“ und dann ' +
        '„Datei → Exportieren → Geslicte Datei exportieren“ (.gcode.3mf) verwenden.',
      );
    }
    const plates = parseSliceInfo(bytesToText(await zip.read('Metadata/slice_info.config')));
    const prints = printsFrom3mf(name, plates, fileDate(file));
    if (!prints.length) throw new Error('Kein Filamentverbrauch in der Datei gefunden');
    const thumbs = {};
    for (const p of prints) {
      for (const cand of [`Metadata/plate_${p.plate}.png`, `Metadata/plate_${p.plate}_small.png`, `Metadata/top_${p.plate}.png`]) {
        if (zip.has(cand)) {
          thumbs[p.fingerprint] = new Blob([await zip.read(cand)], { type: 'image/png' });
          break;
        }
      }
    }
    return { prints, thumbs };
  }

  if (lower.endsWith('.gcode')) {
    const head = await file.slice(0, GCODE_CHUNK).text();
    const tail = file.size > GCODE_CHUNK ? await file.slice(Math.max(GCODE_CHUNK, file.size - GCODE_CHUNK)).text() : '';
    const prints = parseGcode(head + '\n' + tail, name, fileDate(file));
    if (!prints.length) throw new Error('Kein Filamentverbrauch im G-Code gefunden');
    return { prints, thumbs: {} };
  }

  throw new Error('Dateityp nicht unterstützt (erlaubt: .gcode.3mf, .3mf, .gcode, .json)');
}

// ---------- 3D-Modell eines Auftrags (STL / OBJ / 3MF) ----------
const MAX_MODEL = 300 * 1024 * 1024;

/**
 * Liest ein 3D-Modell. Rückgabe:
 *  { kind: 'mesh', stats }                 – Geometrie, Filament wird geschätzt
 *  { kind: 'sliced', plates, stats? }      – geslicte 3MF: exakte Gramm aus Bambu Studio
 */
export async function analyzeModelFile(file) {
  const name = (file.name || '').toLowerCase();
  if (file.size > MAX_MODEL) throw new Error('Datei zu groß (über 300 MB)');
  if (name.endsWith('.stl')) return { kind: 'mesh', stats: parseSTL(new Uint8Array(await file.arrayBuffer())) };
  if (name.endsWith('.obj')) return { kind: 'mesh', stats: parseOBJ(await file.text()) };
  if (name.endsWith('.3mf')) {
    const zip = await listZip(file);
    let stats = null;
    const models = new Map();
    for (const e of zip.entries) {
      if (/\.model$/i.test(e.name)) models.set(e.name, bytesToText(await zip.read(e.name)));
    }
    if (models.size) {
      try { stats = stats3mf(models); } catch { stats = null; }
    }
    if (zip.has('Metadata/slice_info.config')) {
      const plates = parseSliceInfo(bytesToText(await zip.read('Metadata/slice_info.config'))).filter((p) => p.filaments.length);
      if (plates.length) return { kind: 'sliced', plates, stats };
    }
    if (!stats) throw new Error('Kein 3D-Modell in der 3MF-Datei gefunden');
    return { kind: 'mesh', stats };
  }
  throw new Error('Bitte eine STL-, OBJ- oder 3MF-Datei wählen');
}
