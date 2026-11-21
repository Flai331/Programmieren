// Minimaler ZIP-Leser (für .3mf-Dateien aus Bambu Studio).
// Liest nur das Inhaltsverzeichnis und entpackt gezielt einzelne Einträge –
// die oft riesige plate_N.gcode wird nie geladen.
// Funktioniert mit Blob/File (Browser) und Uint8Array (Tests).

const SIG_EOCD = 0x06054b50;
const SIG_EOCD64_LOC = 0x07064b50;
const SIG_EOCD64 = 0x06064b50;
const SIG_CEN = 0x02014b50;
const SIG_LOC = 0x04034b50;

function source(input) {
  if (input instanceof Uint8Array) {
    return {
      size: input.length,
      read: async (start, end) => input.subarray(start, end),
    };
  }
  // Blob / File
  return {
    size: input.size,
    read: async (start, end) => new Uint8Array(await input.slice(start, end).arrayBuffer()),
  };
}

function u16(b, o) { return b[o] | (b[o + 1] << 8); }
function u32(b, o) { return (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) >>> 0; }
function u64(b, o) { return u32(b, o) + u32(b, o + 4) * 0x100000000; }

const utf8 = new TextDecoder('utf-8');

export async function listZip(input) {
  const src = source(input);
  const tailLen = Math.min(src.size, 65557 + 20);
  const tail = await src.read(src.size - tailLen, src.size);
  let eocd = -1;
  for (let i = tail.length - 22; i >= 0; i--) {
    if (u32(tail, i) === SIG_EOCD) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('Keine gültige ZIP/3MF-Datei');

  let count = u16(tail, eocd + 10);
  let cdSize = u32(tail, eocd + 12);
  let cdOffset = u32(tail, eocd + 16);

  // ZIP64
  if (count === 0xffff || cdSize === 0xffffffff || cdOffset === 0xffffffff) {
    const loc = eocd - 20;
    if (loc >= 0 && u32(tail, loc) === SIG_EOCD64_LOC) {
      const off64 = u64(tail, loc + 8);
      const rec = await src.read(off64, off64 + 56);
      if (u32(rec, 0) === SIG_EOCD64) {
        count = u64(rec, 32);
        cdSize = u64(rec, 40);
        cdOffset = u64(rec, 48);
      }
    }
  }

  const cd = await src.read(cdOffset, cdOffset + cdSize);
  const entries = [];
  let p = 0;
  for (let n = 0; n < count && p + 46 <= cd.length; n++) {
    if (u32(cd, p) !== SIG_CEN) break;
    const method = u16(cd, p + 10);
    let compSize = u32(cd, p + 20);
    let size = u32(cd, p + 24);
    const nameLen = u16(cd, p + 28);
    const extraLen = u16(cd, p + 30);
    const commentLen = u16(cd, p + 32);
    let localOffset = u32(cd, p + 42);
    const name = utf8.decode(cd.subarray(p + 46, p + 46 + nameLen));
    // ZIP64-Extrafeld
    let e = p + 46 + nameLen;
    const eEnd = e + extraLen;
    while (e + 4 <= eEnd) {
      const id = u16(cd, e);
      const len = u16(cd, e + 2);
      if (id === 0x0001) {
        let q = e + 4;
        if (size === 0xffffffff) { size = u64(cd, q); q += 8; }
        if (compSize === 0xffffffff) { compSize = u64(cd, q); q += 8; }
        if (localOffset === 0xffffffff) { localOffset = u64(cd, q); q += 8; }
      }
      e += 4 + len;
    }
    entries.push({ name, method, compSize, size, localOffset });
    p += 46 + nameLen + extraLen + commentLen;
  }

  return {
    entries,
    has: (name) => entries.some((x) => x.name === name),
    read: (name) => readEntry(src, entries.find((x) => x.name === name)),
  };
}

async function inflateRaw(data) {
  const ds = new DecompressionStream('deflate-raw');
  const stream = new Blob([data]).stream().pipeThrough(ds);
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

async function readEntry(src, entry) {
  if (!entry) return null;
  const head = await src.read(entry.localOffset, entry.localOffset + 30);
  if (u32(head, 0) !== SIG_LOC) throw new Error('Beschädigter ZIP-Eintrag: ' + entry.name);
  const start = entry.localOffset + 30 + u16(head, 26) + u16(head, 28);
  const raw = await src.read(start, start + entry.compSize);
  if (entry.method === 0) return raw;
  if (entry.method === 8) return inflateRaw(raw);
  throw new Error('Nicht unterstützte Kompression (' + entry.method + ') in ' + entry.name);
}

export function bytesToText(bytes) {
  return bytes ? utf8.decode(bytes) : '';
}
