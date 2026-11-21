// Reine Logik ohne DOM: Parser für Bambu-Dateien, Restmengen, Farbabgleich,
// Suche, Aufträge. Wird in den Node-Tests direkt geprüft.

// ---------- Allgemein ----------

export const MATERIAL_DENSITY = {
  PLA: 1.24, PETG: 1.27, ABS: 1.04, ASA: 1.07, TPU: 1.21, PA: 1.14,
  PC: 1.20, PVA: 1.23, HIPS: 1.04, PET: 1.27, PP: 0.90,
};

export const ORDER_STATUS = [
  { id: 'anfrage', label: 'Anfrage' },
  { id: 'angebot', label: 'Angebot raus' },
  { id: 'konstruktion', label: 'Konstruktion' },
  { id: 'druckbereit', label: 'Druckbereit' },
  { id: 'druck', label: 'Im Druck' },
  { id: 'fertig', label: 'Fertig' },
  { id: 'uebergeben', label: 'Übergeben' },
];
export const OPEN_STATUS = ['anfrage', 'angebot', 'konstruktion', 'druckbereit', 'druck'];

export const LICENSES = [
  { id: '', label: '– unbekannt –' },
  { id: 'eigen', label: 'Eigene Konstruktion' },
  { id: 'kommerziell', label: 'Kommerzielle Nutzung erlaubt' },
  { id: 'nc', label: 'Nur nicht-kommerziell (NC)' },
  { id: 'gekauft', label: 'Gekauft / Lizenz vorhanden' },
];

export function uid(prefix = '') {
  return prefix + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

export function round(n, d = 1) {
  const f = 10 ** d;
  return Math.round((Number(n) || 0) * f) / f;
}

export function emptyState() {
  return {
    version: 1,
    settings: {
      boxCount: 6,
      slotsPerBox: 4,
      amsUnits: 1,
      lowThreshold: 150,
      defaultNet: 1000,
      defaultEmpty: 250,
      hourlyRate: 0.3,
      markup: 30,
      laborRate: 25,
      minOrder: 0,
      rounding: 0.1,
      biz: {},
    },
    boxes: {},
    spools: [],
    prints: [],
    orders: [],
    customers: [],
  };
}

export function normalizeState(s) {
  const base = emptyState();
  if (!s || typeof s !== 'object') return base;
  return {
    ...base,
    ...s,
    settings: { ...base.settings, ...(s.settings || {}) },
    boxes: s.boxes || {},
    spools: Array.isArray(s.spools) ? s.spools : [],
    prints: Array.isArray(s.prints) ? s.prints : [],
    orders: Array.isArray(s.orders) ? s.orders : [],
    customers: Array.isArray(s.customers) ? s.customers : [],
  };
}

// ---------- Farben ----------

export function normHex(c) {
  if (!c) return '';
  let h = String(c).trim().replace(/^#/, '').replace(/^0x/i, '');
  if (/^[0-9a-f]{3}$/i.test(h)) h = h.split('').map((x) => x + x).join('');
  if (/^[0-9a-f]{8}$/i.test(h)) h = h.slice(0, 6); // RRGGBBAA (Bambu Cloud)
  if (!/^[0-9a-f]{6}$/i.test(h)) return '';
  return '#' + h.toUpperCase();
}

function hexToRgb(hex) {
  const h = normHex(hex);
  if (!h) return null;
  return [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
}

function rgbToLab([r, g, b]) {
  const lin = (v) => {
    v /= 255;
    return v > 0.04045 ? ((v + 0.055) / 1.055) ** 2.4 : v / 12.92;
  };
  const R = lin(r), G = lin(g), B = lin(b);
  let x = (R * 0.4124 + G * 0.3576 + B * 0.1805) / 0.95047;
  let y = R * 0.2126 + G * 0.7152 + B * 0.0722;
  let z = (R * 0.0193 + G * 0.1192 + B * 0.9505) / 1.08883;
  const f = (t) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  x = f(x); y = f(y); z = f(z);
  return [116 * y - 16, 500 * (x - y), 200 * (y - z)];
}

/** Farbabstand (Delta E 76). ~0 gleich, <10 sehr ähnlich, >30 deutlich anders. */
export function colorDistance(a, b) {
  const ra = hexToRgb(a), rb = hexToRgb(b);
  if (!ra || !rb) return Infinity;
  const la = rgbToLab(ra), lb = rgbToLab(rb);
  return Math.hypot(la[0] - lb[0], la[1] - lb[1], la[2] - lb[2]);
}

export const BASE_COLORS = [
  ['Weiß', '#FFFFFF'], ['Schwarz', '#000000'], ['Grau', '#8E9089'], ['Silber', '#C0C0C0'],
  ['Rot', '#E01A1A'], ['Dunkelrot', '#8B1A1A'], ['Orange', '#FF7A10'], ['Gelb', '#F4EE2A'], ['Gold', '#E4BD68'],
  ['Grün', '#00AE42'], ['Dunkelgrün', '#1F5E3B'], ['Hellgrün', '#A6E22E'], ['Türkis', '#00B1B7'],
  ['Blau', '#0A2CA5'], ['Hellblau', '#5EB1E8'], ['Lila', '#8E44AD'], ['Pink', '#F55A74'],
  ['Braun', '#6F4E37'], ['Beige', '#E8D8B0'], ['Natur', '#F0E6D2'], ['Transparent', '#E8F0F2'],
];

export function baseColorName(hex) {
  let best = '', bestD = Infinity;
  for (const [name, h] of BASE_COLORS) {
    const d = colorDistance(hex, h);
    if (d < bestD) { bestD = d; best = name; }
  }
  return best;
}

// ---------- Material ----------

export function materialBase(m) {
  const s = String(m || '').toUpperCase().trim();
  if (!s) return '';
  // "PLA Basic", "PLA Matte", "PLA+" → PLA ; "PETG-HF" → PETG ; "PLA-CF" bleibt
  if (/^PLA[-\s]?CF/.test(s)) return 'PLA-CF';
  if (/^PETG[-\s]?CF/.test(s)) return 'PETG-CF';
  if (/^PA\d*[-\s]?CF/.test(s) || /^PAHT/.test(s)) return 'PA-CF';
  const m1 = s.match(/^[A-Z]+/);
  return m1 ? m1[0] : s;
}

export function densityFor(material) {
  const b = materialBase(material).replace(/-CF$/, '');
  return MATERIAL_DENSITY[b] || 1.24;
}

/** Gramm → Meter (bei gegebenem Durchmesser in mm). */
export function gramsToMeters(g, material, diameter = 1.75) {
  const r = diameter / 20; // cm
  const area = Math.PI * r * r; // cm²
  return (g / densityFor(material)) / area / 100;
}

// ---------- Restmenge ----------

/** Alle Verbräuche einer Rolle (Gramm) aus der Druckhistorie. */
export function spoolUsages(spoolId, prints) {
  const out = [];
  for (const p of prints) {
    const factor = p.status === 'failed' ? (Number(p.progress) || 0) / 100 : 1;
    for (const f of p.filaments || []) {
      if (f.spoolId === spoolId) {
        out.push({ date: p.date, grams: (Number(f.grams) || 0) * factor, printId: p.id, name: p.name });
      }
    }
  }
  return out.sort((a, b) => String(a.date).localeCompare(String(b.date)));
}

/**
 * Geschätzte Restmenge in Gramm.
 * Ohne Wiegung: Nettogewicht − Verbrauch.
 * Mit Wiegung: letzte Wiegung − Verbrauch nach der Wiegung.
 */
export function spoolRemaining(spool, prints) {
  const usages = spoolUsages(spool.id, prints);
  const weighings = (spool.weighings || []).slice().sort((a, b) => String(a.date).localeCompare(String(b.date)));
  const last = weighings[weighings.length - 1];
  let start = Number(spool.netWeight) || 0;
  let since = '';
  if (last) {
    start = Number(last.remaining) || 0;
    since = last.date;
  }
  const used = usages.filter((u) => !since || String(u.date) > since).reduce((s, u) => s + u.grams, 0);
  const totalUsed = usages.reduce((s, u) => s + u.grams, 0);
  const remaining = Math.max(0, start - used);
  const net = Number(spool.netWeight) || 0;
  return {
    remaining: round(remaining, 1),
    used: round(totalUsed, 1),
    percent: net > 0 ? Math.max(0, Math.min(100, Math.round((remaining / net) * 100))) : 0,
    meters: round(gramsToMeters(remaining, spool.material, spool.diameter || 1.75), 1),
    weighedAt: last ? last.date : null,
    printCount: new Set(usages.map((u) => u.printId)).size,
  };
}

/** Restmenge aus Waagen-Gewicht (Rolle inkl. Spule). */
export function remainingFromScale(gross, emptyWeight) {
  return Math.max(0, round((Number(gross) || 0) - (Number(emptyWeight) || 0), 1));
}

export function pricePerGram(spool) {
  const net = Number(spool && spool.netWeight) || 0;
  const price = Number(spool && spool.price) || 0;
  return net > 0 ? price / net : 0;
}

// ---------- Lagerplatz ----------

export function locationLabel(loc) {
  if (!loc || !loc.kind) return 'Ohne Platz';
  switch (loc.kind) {
    case 'box': return `Box ${loc.box} · Platz ${loc.slot}`;
    case 'ams': return `AMS ${loc.unit || 1} · Slot ${loc.slot}`;
    case 'printer': return 'Am Drucker (extern)';
    case 'other': return loc.text || 'Sonstiger Ort';
    case 'empty': return 'Aufgebraucht';
    default: return 'Ohne Platz';
  }
}

export function sameLocation(a, b) {
  if (!a || !b || a.kind !== b.kind) return false;
  if (a.kind === 'box') return Number(a.box) === Number(b.box) && Number(a.slot) === Number(b.slot);
  if (a.kind === 'ams') return Number(a.unit || 1) === Number(b.unit || 1) && Number(a.slot) === Number(b.slot);
  return false;
}

/** Belegung einer Box: Array der Länge slotsPerBox mit Rolle oder null. */
export function boxOccupancy(boxNo, spools, slotsPerBox) {
  const slots = Array.from({ length: slotsPerBox }, () => null);
  for (const s of spools) {
    if (s.archived) continue;
    const l = s.location;
    if (l && l.kind === 'box' && Number(l.box) === Number(boxNo)) {
      const i = Number(l.slot) - 1;
      if (i >= 0 && i < slotsPerBox && !slots[i]) slots[i] = s;
    }
  }
  return slots;
}

/** Erster freier Platz in den Boxen, oder null. */
export function firstFreeSlot(spools, settings, exceptId) {
  const list = spools.filter((s) => s.id !== exceptId);
  for (let b = 1; b <= settings.boxCount; b++) {
    const occ = boxOccupancy(b, list, settings.slotsPerBox);
    const i = occ.findIndex((x) => !x);
    if (i >= 0) return { kind: 'box', box: b, slot: i + 1 };
  }
  return null;
}

/** Wer belegt diesen Platz schon (außer der Rolle selbst)? */
export function occupant(loc, spools, exceptId) {
  if (!loc || (loc.kind !== 'box' && loc.kind !== 'ams')) return null;
  return spools.find((s) => !s.archived && s.id !== exceptId && sameLocation(s.location, loc)) || null;
}

// ---------- Suche ----------

export function spoolTitle(s) {
  return [s.brand, s.material, s.colorName].filter(Boolean).join(' ') || 'Rolle';
}

function fold(s) {
  return String(s || '').toLowerCase()
    .replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/ß/g, 'ss');
}

/** Freitextsuche: alle Wörter müssen passen (Marke, Material, Farbe, Grundfarbe, Ort, Notiz). */
export function searchSpools(spools, query, opts = {}) {
  const words = fold(query).split(/\s+/).filter(Boolean);
  let list = spools.filter((s) => (opts.includeArchived ? true : !s.archived));
  if (words.length) {
    list = list.filter((s) => {
      const hay = fold([
        s.brand, s.material, materialBase(s.material), s.colorName, baseColorName(s.colorHex),
        s.colorHex, locationLabel(s.location), s.note, s.diameter,
      ].join(' '));
      return words.every((w) => hay.includes(w));
    });
  }
  if (opts.colorHex) {
    list = list
      .map((s) => ({ s, d: colorDistance(s.colorHex, opts.colorHex) }))
      .filter((x) => x.d < (opts.maxDistance || 35))
      .sort((a, b) => a.d - b.d)
      .map((x) => x.s);
  }
  return list;
}

// ---------- Rollen-Vorschlag beim Import ----------

/**
 * Sortierte Kandidaten für ein Filament aus einem Druck.
 * Bewertet Material, Farbe, AMS-Slot und ob die Rolle noch genug hat.
 */
export function rankSpools(filament, spools, prints) {
  const fMat = materialBase(filament.type);
  const out = [];
  for (const s of spools) {
    if (s.archived) continue;
    const sMat = materialBase(s.material);
    const d = colorDistance(s.colorHex, filament.colorHex);
    let score = 0;
    if (fMat && sMat) score += fMat === sMat ? 40 : -40;
    if (Number.isFinite(d)) score += Math.max(-30, 40 - d * 2);
    if (filament.amsSlot != null && s.location && s.location.kind === 'ams') {
      const global = (Number(s.location.unit || 1) - 1) * 4 + Number(s.location.slot) - 1;
      if (global === Number(filament.amsSlot)) score += 30;
    }
    if (s.location && s.location.kind === 'ams') score += 10;
    if (s.location && s.location.kind === 'printer') score += 8;
    if (filament.bambuId && s.bambuId && filament.bambuId === s.bambuId) score += 10;
    const rem = spoolRemaining(s, prints).remaining;
    if (rem <= 0) score -= 50;
    out.push({ spool: s, score, distance: d, remaining: rem, materialMatch: fMat === sMat });
  }
  return out.sort((a, b) => b.score - a.score);
}

/** Beste Rolle, wenn sie sicher genug passt – sonst null. */
export function suggestSpool(filament, spools, prints) {
  const ranked = rankSpools(filament, spools, prints);
  const top = ranked[0];
  if (!top) return null;
  if (!top.materialMatch && materialBase(filament.type)) return null;
  if (top.distance > 25) return null;
  return top.spool;
}

// ---------- Parser: Bambu Studio 3MF (slice_info.config) ----------

function attrs(tag) {
  const o = {};
  const re = /([\w:-]+)\s*=\s*"([^"]*)"/g;
  let m;
  while ((m = re.exec(tag))) o[m[1]] = m[2];
  return o;
}

/** Liest Metadata/slice_info.config → eine Liste von Platten mit Filamentverbrauch. */
export function parseSliceInfo(xml) {
  const plates = [];
  const plateRe = /<plate>([\s\S]*?)<\/plate>/g;
  let pm;
  while ((pm = plateRe.exec(xml))) {
    const body = pm[1];
    const meta = {};
    const metaRe = /<metadata\b[^>]*\/?>/g;
    let mm;
    while ((mm = metaRe.exec(body))) {
      const a = attrs(mm[0]);
      if (a.key) meta[a.key] = a.value;
    }
    const filaments = [];
    const filRe = /<filament\b[^>]*\/?>/g;
    let fm;
    while ((fm = filRe.exec(body))) {
      const a = attrs(fm[0]);
      const grams = parseFloat(a.used_g);
      if (!(grams > 0)) continue;
      filaments.push({
        slot: Number(a.id) || filaments.length + 1,
        type: a.type || '',
        colorHex: normHex(a.color),
        grams: round(grams, 2),
        meters: round(parseFloat(a.used_m) || 0, 2),
        bambuId: a.tray_info_idx || '',
      });
    }
    const objects = [];
    const objRe = /<object\b[^>]*\/?>/g;
    let om;
    while ((om = objRe.exec(body))) {
      const a = attrs(om[0]);
      if (a.name && a.skipped !== 'true') objects.push(a.name);
    }
    plates.push({
      index: Number(meta.index) || plates.length + 1,
      durationS: Number(meta.prediction) || 0,
      weight: parseFloat(meta.weight) || filaments.reduce((s, f) => s + f.grams, 0),
      filaments,
      objects,
    });
  }
  return plates;
}

function baseName(fileName) {
  return String(fileName || 'Druck')
    .replace(/\.gcode\.3mf$/i, '')
    .replace(/\.(3mf|gcode|bgcode)$/i, '');
}

/** Baut aus Platten eines 3MF die Druck-Entwürfe für den Import. */
export function printsFrom3mf(fileName, plates, dateIso) {
  const name = baseName(fileName);
  const multi = plates.filter((p) => p.filaments.length).length > 1;
  return plates
    .filter((p) => p.filaments.length)
    .map((p) => ({
      name: multi ? `${name} (Platte ${p.index})` : name,
      date: dateIso,
      source: '3mf',
      plate: p.index,
      durationS: p.durationS,
      objects: p.objects,
      filaments: p.filaments,
      fingerprint: fingerprint('3mf', name, p.index, p.filaments),
    }));
}

export function fingerprint(kind, name, plate, filaments) {
  const w = (filaments || []).map((f) => `${f.slot}:${round(f.grams, 1)}`).join('|');
  return `${kind}:${name}:${plate || 1}:${w}`;
}

// ---------- Parser: G-Code (Bambu Studio, Orca, Prusa) ----------

function splitList(v) {
  return String(v || '').split(/[;,]/).map((x) => x.trim()).filter((x) => x !== '');
}

function parseDuration(text) {
  if (!text) return 0;
  let s = 0;
  const re = /(\d+)\s*([dhms])/g;
  let m;
  while ((m = re.exec(text))) {
    const n = Number(m[1]);
    s += m[2] === 'd' ? n * 86400 : m[2] === 'h' ? n * 3600 : m[2] === 'm' ? n * 60 : n;
  }
  return s;
}

/** text = Anfang + Ende der G-Code-Datei (Kommentare reichen). */
export function parseGcode(text, fileName, dateIso) {
  const get = (re) => {
    const m = text.match(re);
    return m ? m[1].trim() : '';
  };
  let grams = splitList(get(/;\s*total filament weight \[g\]\s*[:=]\s*([^\n\r]*)/i)).map(Number);
  if (!grams.length || grams.length === 1) {
    const per = splitList(get(/;\s*filament used \[g\]\s*[:=]\s*([^\n\r]*)/i)).map(Number);
    if (per.length) grams = per;
  }
  if (!grams.length) {
    const tot = Number(get(/;\s*total filament used \[g\]\s*[:=]\s*([^\n\r]*)/i));
    if (tot) grams = [tot];
  }
  let mm = splitList(get(/;\s*total filament length \[mm\]\s*[:=]\s*([^\n\r]*)/i)).map(Number);
  if (!mm.length) mm = splitList(get(/;\s*filament used \[mm\]\s*[:=]\s*([^\n\r]*)/i)).map(Number);
  const colors = splitList(get(/;\s*filament_colou?r\s*=\s*([^\n\r]*)/i));
  const types = splitList(get(/;\s*filament_type\s*=\s*([^\n\r]*)/i));
  const ids = splitList(get(/;\s*filament_ids\s*=\s*([^\n\r]*)/i));
  const duration = parseDuration(
    get(/total estimated time:\s*([^;\n\r]*)/i) || get(/estimated printing time \(normal mode\)\s*=\s*([^\n\r]*)/i),
  );

  const filaments = [];
  grams.forEach((g, i) => {
    if (!(g > 0)) return;
    filaments.push({
      slot: i + 1,
      type: types[i] || types[0] || '',
      colorHex: normHex(colors[i] || colors[0] || ''),
      grams: round(g, 2),
      meters: round((mm[i] || 0) / 1000, 2),
      bambuId: ids[i] || '',
    });
  });
  if (!filaments.length) return [];
  const name = baseName(fileName);
  return [{
    name,
    date: dateIso,
    source: 'gcode',
    plate: 1,
    durationS: duration,
    objects: [],
    filaments,
    fingerprint: fingerprint('gcode', name, 1, filaments),
  }];
}

// ---------- Parser: Bambu Cloud Druckhistorie (JSON) ----------

// Bambu dokumentiert die Status-Codes nicht: 2 = fertig, 3 = abgebrochen/fehlgeschlagen sind sicher,
// 1 = läuft. Andere Codes werden als "unklar" markiert, damit man das Ergebnis selbst prüft.
const CLOUD_STATUS = { 1: 'running', 2: 'ok', 3: 'failed' };

/** Akzeptiert die Antwort von /v1/user-service/my/tasks ({hits:[…]}) oder ein Array. */
export function parseCloudTasks(json) {
  const data = typeof json === 'string' ? JSON.parse(json) : json;
  const tasks = Array.isArray(data) ? data : (data && (data.hits || data.tasks || data.data)) || [];
  const out = [];
  for (const t of tasks) {
    if (!t || typeof t !== 'object') continue;
    const status = CLOUD_STATUS[t.status] || 'ok';
    const statusUnsure = !CLOUD_STATUS[t.status];
    if (status === 'running') continue;
    const mapping = Array.isArray(t.amsDetailMapping) ? t.amsDetailMapping : [];
    let filaments = mapping
      .filter((m) => Number(m.weight) > 0)
      .map((m, i) => ({
        slot: i + 1,
        type: m.filamentType || m.targetFilamentType || '',
        colorHex: normHex(m.sourceColor || m.targetColor || ''),
        grams: round(Number(m.weight), 2),
        meters: 0,
        bambuId: m.filamentId || '',
        amsSlot: Number.isFinite(Number(m.ams)) && Number(m.ams) >= 0 && Number(m.ams) < 64 ? Number(m.ams) : null,
      }));
    if (!filaments.length && Number(t.weight) > 0) {
      filaments = [{ slot: 1, type: '', colorHex: '', grams: round(Number(t.weight), 2), meters: 0, bambuId: '', amsSlot: null }];
    }
    if (!filaments.length) continue;
    const date = t.endTime || t.startTime || t.createTime || '';
    out.push({
      name: t.designTitle || t.title || t.modelName || 'Cloud-Druck',
      date: date ? new Date(date).toISOString() : new Date().toISOString(),
      source: 'cloud',
      plate: Number(t.plateIndex) || 1,
      durationS: Number(t.costTime) || 0,
      objects: [],
      filaments,
      status,
      statusUnsure,
      progress: status === 'failed' ? 50 : 100,
      taskId: t.id != null ? String(t.id) : '',
      thumbId: t.id != null ? 'cthumb_' + t.id : '',
      device: t.deviceName || t.deviceModel || '',
      fingerprint: 'cloud:' + (t.id != null ? t.id : fingerprint('c', t.title, t.plateIndex, filaments)),
    });
  }
  return out;
}

// ---------- Aufträge ----------

export function orderProgress(order, prints) {
  const linked = prints.filter((p) => p.orderId === order.id);
  const done = linked
    .filter((p) => p.status !== 'failed')
    .reduce((s, p) => s + (Number(p.pieces) || 0), 0) + (Number(order.manualDone) || 0);
  const qty = Math.max(1, Number(order.quantity) || 1);
  return {
    done,
    quantity: qty,
    open: Math.max(0, qty - done),
    percent: Math.min(100, Math.round((done / qty) * 100)),
    prints: linked.length,
  };
}

/** Material und Kosten eines Auftrags aus den verknüpften Drucken. */
export function orderCosts(order, prints, spools, settings = {}) {
  const linked = prints.filter((p) => p.orderId === order.id);
  let grams = 0, material = 0, seconds = 0;
  for (const p of linked) {
    const factor = p.status === 'failed' ? (Number(p.progress) || 0) / 100 : 1;
    seconds += (Number(p.durationS) || 0) * factor;
    for (const f of p.filaments || []) {
      const g = (Number(f.grams) || 0) * factor;
      grams += g;
      const sp = spools.find((s) => s.id === f.spoolId);
      material += g * pricePerGram(sp);
    }
  }
  const hours = seconds / 3600;
  const machine = hours * (Number(settings.hourlyRate) || 0);
  return {
    grams: round(grams, 1),
    material: round(material, 2),
    hours: round(hours, 1),
    machine: round(machine, 2),
    total: round(material + machine, 2),
  };
}

/** Preisvorschlag für Rest-Stückzahl: Gramm/Stück × €/g + Std/Stück × Stundensatz, plus Aufschlag. */
export function quote({ gramsPerPiece, hoursPerPiece, pieces, pricePerKg, hourlyRate, markup }) {
  const n = Math.max(0, Number(pieces) || 0);
  const mat = (Number(gramsPerPiece) || 0) * n * ((Number(pricePerKg) || 0) / 1000);
  const mach = (Number(hoursPerPiece) || 0) * n * (Number(hourlyRate) || 0);
  const base = mat + mach;
  return {
    material: round(mat, 2),
    machine: round(mach, 2),
    total: round(base * (1 + (Number(markup) || 0) / 100), 2),
    grams: round((Number(gramsPerPiece) || 0) * n, 1),
  };
}

/** Rollen, die für den offenen Rest eines Auftrags reichen würden. */
export function spoolsForOrder(order, spools, prints) {
  const need = (Number(order.gramsPerPiece) || 0) * orderProgress(order, prints).open;
  return spools
    .filter((s) => !s.archived)
    .filter((s) => !order.material || materialBase(s.material) === materialBase(order.material))
    .map((s) => ({
      spool: s,
      remaining: spoolRemaining(s, prints).remaining,
      distance: order.colorHex ? colorDistance(s.colorHex, order.colorHex) : 0,
    }))
    .filter((x) => x.distance < 30)
    .map((x) => ({ ...x, enough: x.remaining >= need, need: round(need, 1) }))
    .sort((a, b) => a.distance - b.distance || b.remaining - a.remaining);
}

export function modelSite(url) {
  const u = String(url || '').toLowerCase();
  if (u.includes('makerworld')) return 'MakerWorld';
  if (u.includes('printables')) return 'Printables';
  if (u.includes('thingiverse')) return 'Thingiverse';
  if (u.includes('cults3d')) return 'Cults3D';
  if (u.includes('myminifactory')) return 'MyMiniFactory';
  if (u.includes('thangs')) return 'Thangs';
  try { return new URL(url).hostname.replace(/^www\./, ''); } catch { return 'Link'; }
}

export function formatDuration(s) {
  s = Math.round(Number(s) || 0);
  if (!s) return '–';
  const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
  return h ? `${h} h ${m} min` : `${m} min`;
}

export function formatGrams(g) {
  g = Number(g) || 0;
  return g >= 1000 ? `${round(g / 1000, 2).toLocaleString('de-DE')} kg` : `${Math.round(g).toLocaleString('de-DE')} g`;
}

export function formatMoney(v) {
  return (Number(v) || 0).toLocaleString('de-DE', { style: 'currency', currency: 'EUR' });
}

export function daysUntil(dateStr, now = new Date()) {
  if (!dateStr) return null;
  const d = new Date(dateStr + 'T00:00:00');
  const t = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return Math.round((d - t) / 86400000);
}

/**
 * Materialkosten eines Auftrags mit den passenden Rollen aus dem Lager.
 * Je Rolle: €/kg, Kosten pro Stück und für die offenen Stück, ob sie reicht, für wie viele Stück sie reicht.
 * best = bestpassende Rolle mit Preis, die für den Rest reicht (sonst die bestpassende mit Preis).
 */
export function orderSpoolCosts(order, spools, prints) {
  const gpp = Number(order.gramsPerPiece) || 0;
  const open = orderProgress(order, prints).open;
  const rows = spoolsForOrder(order, spools, prints).map((x) => {
    const ppg = pricePerGram(x.spool);
    return {
      ...x,
      hasPrice: ppg > 0,
      pricePerKg: round(ppg * 1000, 2),
      perPiece: round(gpp * ppg, 2),
      total: round(gpp * open * ppg, 2),
      piecesPossible: gpp > 0 ? Math.floor(x.remaining / gpp) : null,
    };
  });
  const priced = rows.filter((r) => r.hasPrice);
  const best = priced.find((r) => r.enough) || priced[0] || null;
  return { rows, best, open, gramsPerPiece: gpp };
}

// ---------- Preiskalkulation, Angebot und Rechnung ----------

export const DEFAULT_PRICING = {
  markup: 30, // Marge in % auf Material + Maschine
  hourlyRate: 0.3, // Maschinenkosten €/Druckstunde (Strom, Verschleiß)
  laborRate: 25, // Stundensatz Arbeit (Konstruktion, Nacharbeit) €/h
  minOrder: 0, // Mindestpreis je Auftrag €
  rounding: 0.1, // Stückpreis aufrunden auf …
};

export const DEFAULT_BIZ = {
  name: '', address: '', email: '', phone: '', taxId: '',
  vatMode: 'klein', vatRate: 19, // 'klein' = Kleinunternehmer § 19 UStG, 'ust' = mit Umsatzsteuer
  iban: '', bic: '', bank: '',
  payDays: 14, offerDays: 30,
  invoicePrefix: 'RE', nextInvoice: 1, offerPrefix: 'AN', nextOffer: 1,
  footer: '',
};

/** Preis-Einstellungen: Vorgaben aus den Einstellungen, im Auftrag überschreibbar (leer = Vorgabe). */
export function pricingFor(settings, order) {
  const base = { ...DEFAULT_PRICING };
  for (const k of Object.keys(base)) {
    if (settings && settings[k] !== undefined && settings[k] !== '' && Number.isFinite(Number(settings[k]))) base[k] = Number(settings[k]);
  }
  const ov = (order && order.pricing) || {};
  for (const k of Object.keys(base)) {
    if (ov[k] !== undefined && ov[k] !== '' && ov[k] !== null && Number.isFinite(Number(ov[k]))) base[k] = Number(ov[k]);
  }
  return base;
}

function roundUp(v, step) {
  const s = Number(step) || 0.01;
  return round(Math.ceil(round(v / s, 6)) * s, 2);
}

/**
 * Kalkulation: Stückpreis = (Material + Maschine) × (1 + Marge), aufgerundet.
 * Arbeit = Stunden × Stundensatz, Extras = Versand/Sonstiges, Mindestpreis füllt auf.
 */
export function priceCalc({ gramsPerPiece, hoursPerPiece, quantity, pricePerKg, materialPiece, designHours, extraCost }, p) {
  const qty = Math.max(1, Number(quantity) || 1);
  // Materialkosten pro Stück direkt (mehrere Zeilen/Rollen) oder aus Gramm × €/kg
  const material = materialPiece !== undefined && materialPiece !== null
    ? Number(materialPiece) || 0
    : (Number(gramsPerPiece) || 0) * (Number(pricePerKg) || 0) / 1000;
  const machine = (Number(hoursPerPiece) || 0) * p.hourlyRate;
  const cost = material + machine;
  const unit = cost > 0 ? roundUp(cost * (1 + p.markup / 100), p.rounding) : 0;
  const pieces = round(unit * qty, 2);
  const labor = round((Number(designHours) || 0) * p.laborRate, 2);
  const extras = round(Number(extraCost) || 0, 2);
  let total = round(pieces + labor + extras, 2);
  const minFill = p.minOrder > total ? round(p.minOrder - total, 2) : 0;
  total = round(total + minFill, 2);
  return {
    qty,
    materialPiece: round(material, 3),
    machinePiece: round(machine, 3),
    costPiece: round(cost, 3),
    unit, pieces, labor, extras, minFill, total,
    costTotal: round(cost * qty + extras, 2),
    profit: round(total - cost * qty - extras, 2), // Gewinn inkl. eigener Arbeitszeit
  };
}

/** Positionen für Angebot/Rechnung aus der Kalkulation. */
export function docLines(order, calc, p) {
  const lines = [];
  // Materialien/Farben aller Zeilen (mehrfarbig), sonst Material/Farbwunsch des Auftrags
  const mats = [...new Set(orderLines(order).map((l) => [l.material, l.colorWish || (l.colorHex ? baseColorName(l.colorHex).toLowerCase() : '')].filter(Boolean).join(' ')).filter(Boolean))];
  const detail = mats.length ? mats.join(' / ') : [order.material, order.colorWish].filter(Boolean).join(', ');
  if (calc.unit > 0) lines.push({ text: order.title || '3D-Druck', detail: detail ? `3D-Druck, ${detail}` : '3D-Druck', qty: calc.qty, unit: calc.unit });
  if (calc.labor > 0) {
    lines.push({
      text: order.kind === 'eigen' ? 'Konstruktion / Modellierung' : 'Arbeitszeit (Vorbereitung, Nacharbeit)',
      detail: `${String(Number(order.designHours) || 0).replace('.', ',')} h à ${String(p.laborRate).replace('.', ',')} €`,
      qty: 1, unit: calc.labor,
    });
  }
  if (calc.extras > 0) lines.push({ text: order.extraLabel || 'Versand / Sonstiges', detail: '', qty: 1, unit: calc.extras });
  if (calc.minFill > 0) lines.push({ text: 'Ausgleich Mindestauftragswert', detail: '', qty: 1, unit: calc.minFill });
  return lines;
}

/** Summen eines Dokuments (Netto/Umsatzsteuer/Brutto; Kleinunternehmer ohne USt). */
export function docTotals(lines, biz) {
  const net = round(lines.reduce((t, l) => t + (Number(l.qty) || 0) * (Number(l.unit) || 0), 0), 2);
  const rate = biz && biz.vatMode === 'ust' ? Number(biz.vatRate) || 0 : 0;
  const vat = round(net * rate / 100, 2);
  return { net, vat, rate, gross: round(net + vat, 2) };
}

export function docNumber(prefix, n, date = new Date()) {
  return `${prefix || ''}${prefix ? '-' : ''}${date.getFullYear()}-${String(Math.max(1, Number(n) || 1)).padStart(3, '0')}`;
}

// ---------- Auftrag v2: Filament-Zeilen, Rollenempfehlung, Endpreis, Kunden ----------

/**
 * Filament-Zeilen eines Auftrags – ein Teil bzw. eine Farbe je Zeile:
 * { id, name, material, colorHex, colorWish, grams (pro Stück, Modell), supportGrams (pro Stück), spoolId ('' = automatisch), src }
 * Ältere Aufträge ohne Zeilen bekommen eine Zeile aus material/colorHex/gramsPerPiece.
 */
export function orderLines(o) {
  if (o && Array.isArray(o.lines) && o.lines.length) return o.lines;
  if (o && (o.gramsPerPiece || o.material || o.colorHex)) {
    return [{ id: 'l0', name: '', material: o.material || '', colorHex: o.colorHex || '', colorWish: o.colorWish || '', grams: Number(o.gramsPerPiece) || 0, supportGrams: 0, spoolId: '', src: '' }];
  }
  return [];
}

export function lineGrams(l) {
  return (Number(l.grams) || 0) + (Number(l.supportGrams) || 0);
}

export function orderGramsPerPiece(o) {
  return round(orderLines(o).reduce((t, l) => t + lineGrams(l), 0), 1);
}

const colorBucket = (d) => (d < 8 ? 0 : d < 18 ? 1 : 2);

/**
 * Rollen für eine Zeile: Material muss passen, Farbe ähnlich (ΔE < 30; ohne Farbwunsch egal).
 * best = passende Rolle, die reicht – bevorzugt die ähnlichste Farbe, dann die angebrochene mit dem
 * kleinsten Rest, der noch reicht (damit Reste aufgebraucht werden).
 * Reicht keine allein: split = mehrere Rollen gleicher Farbe nacheinander.
 * reserved: {spoolId: g} schon für andere Zeilen eingeplant.
 */
export function recommendSpools(line, needGrams, spools, prints, reserved = {}) {
  const need = Math.max(0, Number(needGrams) || 0);
  const mat = materialBase(line.material);
  const cands = spools
    .filter((s) => !s.archived)
    .filter((s) => !mat || materialBase(s.material) === mat)
    .map((s) => {
      const distance = line.colorHex ? colorDistance(s.colorHex, line.colorHex) : 0;
      const avail = Math.max(0, spoolRemaining(s, prints).remaining - (reserved[s.id] || 0));
      return { spool: s, distance, bucket: colorBucket(distance), avail: round(avail, 1), enough: avail >= need && avail > 0 };
    })
    .filter((x) => x.distance < 30 && x.avail > 0);
  cands.sort((a, b) =>
    (b.enough - a.enough) || (a.bucket - b.bucket) ||
    (a.enough ? a.avail - b.avail : b.avail - a.avail) || (a.distance - b.distance));
  const best = cands.find((c) => c.enough) || null;
  let split = [];
  let missing = 0;
  if (!best && need > 0 && cands.length) {
    const bucket = Math.min(...cands.map((c) => c.bucket));
    let rest = need;
    for (const c of cands.filter((x) => x.bucket === bucket).sort((a, b) => b.avail - a.avail)) {
      if (rest <= 0) break;
      const take = Math.min(rest, c.avail);
      split.push({ spool: c.spool, grams: round(take, 1) });
      rest -= take;
    }
    missing = round(Math.max(0, rest), 1);
  } else if (!best && need > 0) {
    missing = need;
  }
  if (best) split = [{ spool: best.spool, grams: round(need, 1) }];
  return { candidates: cands, best: best ? best.spool : null, split, enough: !!best || (split.length > 0 && missing === 0), missing };
}

/** €/kg einer Rolle, sonst Durchschnitt der Rollen gleichen Materials mit Preis, sonst 20 €/kg */
export function pricePerKgFor(spool, material, spools) {
  if (spool && pricePerGram(spool) > 0) return { value: round(pricePerGram(spool) * 1000, 2), source: 'spool' };
  const mat = materialBase(material || (spool && spool.material));
  const priced = spools.filter((s) => !s.archived && pricePerGram(s) > 0 && (!mat || materialBase(s.material) === mat));
  if (priced.length) return { value: round(priced.reduce((t, s) => t + pricePerGram(s) * 1000, 0) / priced.length, 2), source: 'avg' };
  return { value: 20, source: 'default' };
}

/**
 * Materialplan: je Zeile Bedarf für die offenen Stück, gewählte oder empfohlene Rolle(n), €/kg, Kosten pro Stück.
 * Eine Rolle wird nicht doppelt verplant (reserved über die Zeilen).
 */
export function orderMaterialPlan(o, spools, prints) {
  const open = orderProgress(o, prints).open;
  const reserved = {};
  const rows = orderLines(o).map((line) => {
    const perPiece = lineGrams(line);
    const need = round(perPiece * open, 1);
    const rec = recommendSpools(line, need, spools, prints, reserved);
    const chosen = line.spoolId ? spools.find((s) => s.id === line.spoolId) || null : null;
    const use = chosen ? [{ spool: chosen, grams: need }] : rec.split;
    for (const u of use) reserved[u.spool.id] = (reserved[u.spool.id] || 0) + u.grams;
    const main = chosen || (use[0] && use[0].spool) || null;
    const ppk = pricePerKgFor(main, line.material, spools);
    return {
      line, perPiece, need, rec, chosen, use, spool: main,
      pricePerKg: ppk.value, priceSource: ppk.source,
      costPiece: round(perPiece * ppk.value / 1000, 4),
      enough: chosen ? spoolRemaining(chosen, prints).remaining >= need : rec.enough,
    };
  });
  return { rows, open, gramsPerPiece: round(rows.reduce((t, r) => t + r.perPiece, 0), 1), materialPiece: round(rows.reduce((t, r) => t + r.costPiece, 0), 4) };
}

/**
 * Endpreis eines Auftrags:
 *   Kosten/Stück = Material (je Zeile mit dem €/kg der Rolle) + Druckstunden × Maschinenkosten
 *   Stückpreis   = Kosten/Stück × (1 + Marge), aufgerundet
 *   Gesamt       = Stückpreis × Menge + Arbeitszeit × Stundensatz + Versand/Sonstiges (+ Ausgleich Mindestpreis)
 * Fester Preis (o.priceManual) ersetzt den berechneten Gesamtpreis.
 */
export function orderPrice(o, spools, prints, settings) {
  const p = pricingFor(settings, o);
  const plan = orderMaterialPlan(o, spools, prints);
  const calc = priceCalc({
    materialPiece: plan.materialPiece, hoursPerPiece: o.hoursPerPiece, quantity: o.quantity,
    designHours: o.designHours, extraCost: o.extraCost,
  }, p);
  const manual = !!o.priceManual && Number(o.price) > 0;
  return { p, plan, calc, manual, total: manual ? round(Number(o.price), 2) : calc.total };
}

/** Kunden: nach Namen (ohne Groß/Klein) zusammenführen; leere Felder überschreiben nichts. */
export function upsertCustomer(list, c) {
  const name = String(c.name || '').trim();
  if (!name) return { list, id: '' };
  const out = Array.isArray(list) ? list.slice() : [];
  const i = out.findIndex((x) => String(x.name).trim().toLowerCase() === name.toLowerCase());
  if (i >= 0) {
    const cur = { ...out[i] };
    for (const k of ['contact', 'address']) if (String(c[k] || '').trim()) cur[k] = String(c[k]).trim();
    out[i] = cur;
    return { list: out, id: cur.id };
  }
  const id = uid('k');
  out.push({ id, name, contact: String(c.contact || '').trim(), address: String(c.address || '').trim() });
  out.sort((a, b) => a.name.localeCompare(b.name, 'de'));
  return { list: out, id };
}
