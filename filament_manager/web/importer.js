// Liest Dateien (File/Blob) und liefert Druck-Entwürfe für den Import-Dialog.
import { listZip, bytesToText } from './zip.js';
import { parseSliceInfo, printsFrom3mf, parseGcode, parseCloudTasks } from './logic.js';

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
