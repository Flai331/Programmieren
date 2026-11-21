import * as L from './logic.js';
import { loadState, saveState, putBlob, getBlob, deleteBlob, exportBackup, importBackup, loadMeta, saveMeta } from './db.js';
import { parseFile } from './importer.js';
import * as S from './sync.js';

let state = L.emptyState();
let meta = S.emptyMeta();
const syncUi = { busy: false, timer: null, pending: false };
const ui = {
  tab: 'filament',
  q: '',
  color: '',
  material: '',
  low: false,
  archived: false,
  orderFilter: 'open',
  highlightBox: null,
  highlightSpool: null,
};

// ---------- Helfer ----------

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sw = (hex, cls = '') => `<span class="sw ${cls}" style="background:${esc(L.normHex(hex) || '#cccccc')}"></span>`;
const fmtDate = (d) => (d ? new Date(d).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '–');
const fmtDateTime = (d) => (d ? new Date(d).toLocaleString('de-DE', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' }) : '–');
const today = () => new Date().toISOString().slice(0, 10);
const toLocalInput = (iso) => {
  const d = iso ? new Date(iso) : new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
};
const g1 = (g) => L.round(g, 1).toLocaleString('de-DE');
const num = (v, def = 0) => {
  const n = parseFloat(String(v ?? '').replace(',', '.'));
  return Number.isFinite(n) ? n : def;
};

async function save() {
  try {
    await saveState(state);
    if (meta.url && S.stamp(state, meta)) {
      await saveMeta(meta);
      scheduleSync(3000);
    }
  } catch (e) {
    toast('Speichern fehlgeschlagen: ' + e.message);
  }
}

// ---------- Abgleich mit Google-Tabelle ----------

function blobToB64(blob) {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result).split(',')[1] || '');
    r.onerror = () => reject(r.error);
    r.readAsDataURL(blob);
  });
}

function b64ToBlob(b64, type) {
  const bin = atob(b64 || '');
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new Blob([bytes], { type: type || 'application/octet-stream' });
}

const blobAdapter = {
  get: (id) => getBlob(id).catch(() => null),
  put: (id, b) => putBlob(id, b),
  toB64: blobToB64,
  fromB64: b64ToBlob,
};

// Nicht neu zeichnen, während jemand in einem Formular der Seite tippt.
function typingInForm() {
  const a = document.activeElement;
  return !!(a && a.closest && a.closest('#view form'));
}

function scheduleSync(ms = 3000) {
  if (!meta.url) return;
  clearTimeout(syncUi.timer);
  syncUi.timer = setTimeout(() => syncNow(), ms);
}

async function syncNow({ manual = false } = {}) {
  if (!meta.url) return;
  if (syncUi.busy) { syncUi.pending = true; return; }
  if (!navigator.onLine) { if (manual) toast('Offline – Abgleich später'); return; }
  syncUi.busy = true;
  renderSyncBadge();
  try {
    const call = S.makeCaller(meta.url, meta.key);
    const r = await S.runSync(state, meta, call, blobAdapter);
    await saveMeta(meta);
    if (r.changed || r.downloaded) {
      await saveState(state);
      for (const [k, v] of urlCache) if (!v) urlCache.delete(k);
      if (!typingInForm()) render();
    }
    if (manual) toast(`Abgeglichen${r.changed ? ` · ${r.changed} neu vom anderen Gerät` : ''}${r.uploaded ? ` · ${r.uploaded} Datei(en) hochgeladen` : ''}`);
  } catch (e) {
    meta.lastError = e.message;
    await saveMeta(meta).catch(() => {});
    if (manual) toast('Abgleich fehlgeschlagen: ' + e.message);
  } finally {
    syncUi.busy = false;
    renderSyncBadge();
    if (ui.tab === 'mehr' && !modal().open && !typingInForm()) render();
    if (syncUi.pending) { syncUi.pending = false; scheduleSync(500); }
  }
}

function renderSyncBadge() {
  const el = $('#sync-badge');
  if (!el) return;
  if (!meta.url) { el.hidden = true; return; }
  el.hidden = false;
  const dirty = S.planPush(state, meta).length;
  el.textContent = syncUi.busy ? '⟳' : meta.lastError ? '⚠️' : dirty ? '☁️•' : '☁️✓';
  el.title = syncUi.busy ? 'Gleiche ab …' : meta.lastError ? 'Fehler: ' + meta.lastError
    : (dirty ? `${dirty} Änderung(en) noch nicht abgeglichen` : 'Abgeglichen') + (meta.lastSync ? ` (zuletzt ${fmtDateTime(meta.lastSync)})` : '');
  el.classList.toggle('err', !!meta.lastError && !syncUi.busy);
}

async function connectSync(url, key) {
  url = String(url || '').trim();
  key = String(key || '').trim();
  if (!S.validUrl(url)) throw new Error('Die Adresse muss mit https://script.google.com/ beginnen.');
  if (!key) throw new Error('Bitte den Schlüssel aus dem Blatt „Einrichtung“ eintragen.');
  const res = await S.makeCaller(url, key)({ a: 'ping' });
  if (!res || !res.ok) throw new Error(res && res.fehler === 'schluessel' ? 'Falscher Schlüssel.' : 'Server antwortet nicht richtig (' + ((res && res.fehler) || '?') + ').');
  meta = { ...S.emptyMeta(), url, key, sheetName: res.name || '' };
  S.stamp(state, meta);
  await saveMeta(meta);
  await syncNow({ manual: true });
}

let toastTimer;
function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 2800);
}

const spoolById = (id) => state.spools.find((s) => s.id === id);
const orderById = (id) => state.orders.find((o) => o.id === id);
const rem = (s) => L.spoolRemaining(s, state.prints);

function remBar(r) {
  const low = r.remaining < state.settings.lowThreshold;
  const crit = r.remaining < state.settings.lowThreshold / 3;
  return `<div class="bar ${crit ? 'crit' : low ? 'low' : ''}"><i style="width:${r.percent}%"></i></div>`;
}

function locBadge(loc, big = false) {
  const none = !loc || !loc.kind || loc.kind === 'none';
  return `<span class="loc ${none ? 'none' : ''} ${big ? 'big' : ''}">${esc(L.locationLabel(loc))}</span>`;
}

// Bilder aus IndexedDB nachladen
const urlCache = new Map();
async function hydrate(root = document) {
  for (const img of $$('img[data-blob]', root)) {
    const id = img.dataset.blob;
    if (!urlCache.has(id)) {
      const b = await getBlob(id).catch(() => null);
      urlCache.set(id, b ? URL.createObjectURL(b) : '');
    }
    const url = urlCache.get(id);
    if (url) img.src = url;
    else img.replaceWith(Object.assign(document.createElement('div'), { className: 'thumb', textContent: '🖼️' }));
  }
}

// ---------- Dialog ----------

const modal = () => $('#modal');
function openModal(html, onMount) {
  $('#modal-body').innerHTML = html;
  if (!modal().open) modal().showModal();
  modal().scrollTop = 0;
  hydrate($('#modal-body'));
  if (onMount) onMount($('#modal-body'));
}
function closeModal() {
  if (modal().open) modal().close();
  $('#modal-body').innerHTML = '';
}
const head = (title) => `<div class="mhead"><h2>${esc(title)}</h2><button type="button" class="ghost" data-close>✕</button></div>`;

// ---------- Navigation ----------

const TITLES = { filament: 'Filament', boxen: 'Boxen & AMS', drucke: 'Druckhistorie', auftraege: 'Aufträge', mehr: 'Mehr' };

function setTab(tab) {
  ui.tab = tab;
  try { localStorage.setItem('fm-tab', tab); } catch { /* egal */ }
  render();
  window.scrollTo(0, 0);
}

function render() {
  $$('#tabs button').forEach((b) => b.classList.toggle('active', b.dataset.tab === ui.tab));
  $('#title').textContent = TITLES[ui.tab];
  const hadFocus = document.activeElement && document.activeElement.id === 'q' ? document.activeElement.selectionStart : null;
  $('#top-actions').innerHTML = '<button id="sync-badge" class="small ghost" data-act="sync-now" hidden></button>';
  renderSyncBadge();
  const v = $('#view');
  if (ui.tab === 'filament') v.innerHTML = viewFilament();
  else if (ui.tab === 'boxen') v.innerHTML = viewBoxes();
  else if (ui.tab === 'drucke') v.innerHTML = viewPrints();
  else if (ui.tab === 'auftraege') v.innerHTML = viewOrders();
  else v.innerHTML = viewMore();
  hydrate(v);
  if (hadFocus !== null && $('#q')) { $('#q').focus(); $('#q').setSelectionRange(hadFocus, hadFocus); }
  if (ui.tab === 'boxen' && ui.highlightBox) {
    const el = $(`[data-box-card="${ui.highlightBox}"]`);
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    setTimeout(() => { ui.highlightBox = null; ui.highlightSpool = null; }, 100);
  }
}

// ---------- Ansicht: Filament ----------

function viewFilament() {
  const materials = [...new Set(state.spools.filter((s) => !s.archived).map((s) => L.materialBase(s.material)).filter(Boolean))].sort();
  let list = L.searchSpools(state.spools, ui.q, {
    includeArchived: ui.archived,
    colorHex: ui.color || undefined,
  });
  if (ui.material) list = list.filter((s) => L.materialBase(s.material) === ui.material);
  if (ui.low) list = list.filter((s) => rem(s).remaining < state.settings.lowThreshold);
  if (!ui.color) {
    list = list.slice().sort((a, b) =>
      (a.archived - b.archived) ||
      L.materialBase(a.material).localeCompare(L.materialBase(b.material)) ||
      String(a.colorName).localeCompare(String(b.colorName)));
  }

  const active = state.spools.filter((s) => !s.archived);
  const lowCount = active.filter((s) => rem(s).remaining < state.settings.lowThreshold).length;

  let html = `
    <div class="search">
      <input id="q" type="text" enterkeyhint="search" placeholder="Suchen: z. B. „petg schwarz“, „bambu weiß“, „box 3“" value="${esc(ui.q)}" autocomplete="off">
      ${ui.q ? '<button class="clear" data-act="clear-q">✕</button>' : ''}
    </div>
    <div class="chips">
      <label class="chip ${ui.color ? 'on' : ''}" title="Nach ähnlicher Farbe suchen">
        <input type="color" id="colorpick" value="${esc(ui.color || '#888888')}"> Farbe
      </label>
      ${ui.color ? '<button class="chip" data-act="clear-color">Farbe ✕</button>' : ''}
      ${materials.map((m) => `<button class="chip ${ui.material === m ? 'on' : ''}" data-act="mat" data-m="${esc(m)}">${esc(m)}</button>`).join('')}
      <button class="chip ${ui.low ? 'on' : ''}" data-act="low">Wenig Rest${lowCount ? ` (${lowCount})` : ''}</button>
      <button class="chip ${ui.archived ? 'on' : ''}" data-act="archived">Aufgebrauchte</button>
    </div>`;

  if (!state.spools.length) {
    html += `<div class="empty"><div class="big">🧵</div><p>Noch keine Rollen erfasst.</p>
      <p><button class="primary" data-act="new-spool">Erste Rolle anlegen</button></p></div>`;
  } else if (!list.length) {
    html += `<div class="empty"><p>Nichts gefunden.</p></div>`;
  } else {
    html += `<div class="list">${list.map(spoolCard).join('')}</div>`;
  }
  html += `<button class="primary fab" data-act="new-spool">＋ Rolle</button>`;
  return html;
}

function spoolCard(s) {
  const r = rem(s);
  const low = r.remaining < state.settings.lowThreshold;
  return `<div class="card click spool" data-act="spool" data-id="${s.id}">
    ${sw(s.colorHex)}
    <div>
      <div class="t">${esc(L.spoolTitle(s))} ${s.archived ? '<span class="badge info">leer</span>' : low ? '<span class="badge warn">wenig</span>' : ''}</div>
      <div class="meta">${L.formatGrams(r.remaining)} übrig (${r.percent} %) · ca. ${Math.round(r.meters)} m${r.weighedAt ? ' · gewogen' : ''}</div>
      ${remBar(r)}
    </div>
    ${locBadge(s.location)}
  </div>`;
}

// ---------- Rollen-Detail ----------

function spoolDetail(id) {
  const s = spoolById(id);
  if (!s) return;
  const r = rem(s);
  const usages = L.spoolUsages(s.id, state.prints).reverse();
  const home = s.homeLocation && s.location && s.location.kind !== 'box' ? s.homeLocation : null;
  const homeFree = home && !L.occupant(home, state.spools, s.id);
  openModal(`
    ${head(L.spoolTitle(s))}
    <div class="mbody">
      <div class="row" style="align-items:center">
        <div class="shrink">${sw(s.colorHex, 'xl')}</div>
        <div>
          <div style="font-size:26px;font-weight:700">${L.formatGrams(r.remaining)}</div>
          <div class="muted">${r.percent} % von ${L.formatGrams(s.netWeight)} · ca. ${Math.round(r.meters)} m · ${r.printCount} Drucke</div>
          ${remBar(r)}
        </div>
      </div>
      <h3>Lagerplatz</h3>
      <div>${locBadge(s.location, true)}
        ${s.location && s.location.kind === 'box' ? `<button class="small" data-act="show-box" data-box="${s.location.box}" data-id="${s.id}">In Boxen zeigen</button>` : ''}
      </div>
      <div class="row" style="margin-top:8px">
        ${!s.archived ? `<button class="small" data-act="to-ams" data-id="${s.id}">Ins AMS legen</button>` : ''}
        ${home ? `<button class="small" data-act="to-home" data-id="${s.id}" ${homeFree ? '' : 'disabled'}>Zurück in ${esc(L.locationLabel(home))}${homeFree ? '' : ' (belegt)'}</button>` : ''}
        ${!s.archived && (!s.location || s.location.kind !== 'box') ? `<button class="small" data-act="to-free-box" data-id="${s.id}">In freie Box</button>` : ''}
      </div>
      <h3>Daten</h3>
      <dl class="kv">
        <dt>Marke</dt><dd>${esc(s.brand || '–')}</dd>
        <dt>Material</dt><dd>${esc(s.material || '–')} · ${esc(s.diameter || 1.75)} mm</dd>
        <dt>Farbe</dt><dd>${esc(s.colorName || L.baseColorName(s.colorHex))} <small>${esc(s.colorHex)}</small></dd>
        <dt>Leerspule</dt><dd>${esc(s.emptyWeight || 0)} g</dd>
        <dt>Preis</dt><dd>${s.price ? L.formatMoney(s.price) + ` (${L.formatMoney(L.pricePerGram(s) * 1000)}/kg)` : '–'}</dd>
        <dt>Gekauft</dt><dd>${fmtDate(s.purchaseDate)}</dd>
        ${s.weighings && s.weighings.length ? `<dt>Gewogen</dt><dd>${fmtDateTime(r.weighedAt)}</dd>` : ''}
        ${s.note ? `<dt>Notiz</dt><dd class="pre">${esc(s.note)}</dd>` : ''}
      </dl>
      <h3>Verbrauch</h3>
      ${usages.length ? `<div class="list">${usages.slice(0, 30).map((u) => `
        <div class="card" style="padding:8px 10px;display:flex;justify-content:space-between;gap:8px">
          <span>${esc(u.name)}<br><small>${fmtDateTime(u.date)}</small></span><b>${g1(u.grams)} g</b>
        </div>`).join('')}</div>` : '<p class="muted">Noch keine Drucke mit dieser Rolle.</p>'}
    </div>
    <div class="mfoot">
      <button class="left" data-act="weigh" data-id="${s.id}">⚖️ Wiegen</button>
      <button data-act="dup-spool" data-id="${s.id}">Duplizieren</button>
      <button class="primary" data-act="edit-spool" data-id="${s.id}">Bearbeiten</button>
    </div>`);
}

function locationOptions(current, exceptId) {
  const st = state.settings;
  const enc = (l) => !l || !l.kind ? 'none' : l.kind === 'box' ? `box:${l.box}:${l.slot}` : l.kind === 'ams' ? `ams:${l.unit || 1}:${l.slot}` : l.kind;
  const cur = enc(current);
  const opt = (val, label) => `<option value="${val}" ${val === cur ? 'selected' : ''}>${esc(label)}</option>`;
  let html = opt('none', 'Ohne Platz');
  for (let b = 1; b <= st.boxCount; b++) {
    const name = state.boxes[b] && state.boxes[b].name ? ` (${state.boxes[b].name})` : '';
    html += `<optgroup label="Box ${b}${esc(name)}">`;
    for (let p = 1; p <= st.slotsPerBox; p++) {
      const occ = L.occupant({ kind: 'box', box: b, slot: p }, state.spools, exceptId);
      html += opt(`box:${b}:${p}`, `Box ${b} · Platz ${p} — ${occ ? 'belegt: ' + L.spoolTitle(occ) : 'frei'}`);
    }
    html += '</optgroup>';
  }
  for (let u = 1; u <= st.amsUnits; u++) {
    html += `<optgroup label="AMS ${u}">`;
    for (let p = 1; p <= 4; p++) {
      const occ = L.occupant({ kind: 'ams', unit: u, slot: p }, state.spools, exceptId);
      html += opt(`ams:${u}:${p}`, `AMS ${u} · Slot ${p} — ${occ ? 'belegt: ' + L.spoolTitle(occ) : 'frei'}`);
    }
    html += '</optgroup>';
  }
  html += opt('printer', 'Am Drucker (externe Halterung)');
  html += opt('other', 'Sonstiger Ort …');
  return html;
}

function decodeLocation(val, text) {
  if (!val || val === 'none') return { kind: 'none' };
  const [kind, a, b] = val.split(':');
  if (kind === 'box') return { kind, box: Number(a), slot: Number(b) };
  if (kind === 'ams') return { kind, unit: Number(a), slot: Number(b) };
  if (kind === 'other') return { kind, text: text || 'Sonstiger Ort' };
  return { kind };
}

const MATERIALS = ['PLA', 'PLA Basic', 'PLA Matte', 'PLA Silk', 'PLA-CF', 'PETG', 'PETG HF', 'PETG-CF', 'ABS', 'ASA', 'TPU 95A', 'PA-CF', 'PC', 'PVA', 'Support'];
const BRANDS = () => [...new Set(['Bambu Lab', 'Sunlu', 'eSun', 'Elegoo', 'Polymaker', 'Prusament', 'Geeetech', 'Jayo', 'Extrudr', 'DasFilament', ...state.spools.map((s) => s.brand).filter(Boolean)])];

function spoolForm(id, copyFrom) {
  const existing = id ? spoolById(id) : null;
  const st = state.settings;
  const s = existing || {
    ...(copyFrom ? { ...copyFrom, id: undefined, weighings: [], location: null, archived: false, homeLocation: null } : {}),
    netWeight: copyFrom ? copyFrom.netWeight : st.defaultNet,
    emptyWeight: copyFrom ? copyFrom.emptyWeight : st.defaultEmpty,
    diameter: copyFrom ? copyFrom.diameter : 1.75,
    colorHex: copyFrom ? copyFrom.colorHex : '#FFFFFF',
    purchaseDate: today(),
  };
  const loc = existing ? existing.location : L.firstFreeSlot(state.spools, st);
  const r = existing ? rem(existing) : null;
  openModal(`
    <form id="spool-form">
    ${head(existing ? 'Rolle bearbeiten' : 'Neue Rolle')}
    <div class="mbody">
      <div class="row">
        <label class="f">Marke<input name="brand" list="brands" value="${esc(s.brand)}" placeholder="z. B. Bambu Lab"></label>
        <label class="f">Material<input name="material" list="materials" value="${esc(s.material)}" placeholder="PLA Basic" required></label>
      </div>
      <datalist id="brands">${BRANDS().map((b) => `<option value="${esc(b)}">`).join('')}</datalist>
      <datalist id="materials">${MATERIALS.map((b) => `<option value="${esc(b)}">`).join('')}</datalist>
      <div class="row">
        <label class="f">Farbname<input name="colorName" value="${esc(s.colorName)}" placeholder="z. B. Jade White"></label>
        <label class="f shrink" style="width:90px">Farbe<input type="color" name="colorHex" value="${esc(L.normHex(s.colorHex) || '#FFFFFF')}"></label>
      </div>
      <label class="f">Lagerplatz
        <select name="loc">${locationOptions(loc, existing && existing.id)}</select>
      </label>
      <label class="f" id="loc-text-wrap" style="${loc && loc.kind === 'other' ? '' : 'display:none'}">Ort (Freitext)
        <input name="locText" value="${esc(loc && loc.text)}" placeholder="z. B. Regal oben">
      </label>
      <div class="row">
        <label class="f">Netto (g)<input name="netWeight" inputmode="decimal" value="${esc(s.netWeight)}"></label>
        <label class="f">Leerspule (g)<input name="emptyWeight" inputmode="decimal" value="${esc(s.emptyWeight)}"></label>
        <label class="f">Ø (mm)<select name="diameter">
          <option ${Number(s.diameter) !== 2.85 ? 'selected' : ''}>1.75</option><option ${Number(s.diameter) === 2.85 ? 'selected' : ''}>2.85</option>
        </select></label>
      </div>
      <div class="row">
        <label class="f">Preis (€)<input name="price" inputmode="decimal" value="${esc(s.price ?? '')}"></label>
        <label class="f">Gekauft am<input type="date" name="purchaseDate" value="${esc(s.purchaseDate || '')}"></label>
      </div>
      ${existing ? '' : `
      <label class="f">Schon angebrochen? Aktuelles Waagengewicht inkl. Spule (g, leer lassen = voll)
        <input name="gross" inputmode="decimal" placeholder="z. B. 780">
      </label>
      <label class="f">Anzahl gleicher Rollen<input name="count" type="number" min="1" max="20" value="1"></label>`}
      <label class="f">Bambu-Filament-ID (optional, verbessert die Zuordnung)<input name="bambuId" value="${esc(s.bambuId)}" placeholder="z. B. GFA00"></label>
      <label class="f">Notiz<textarea name="note">${esc(s.note)}</textarea></label>
      ${existing ? `<label class="check"><input type="checkbox" name="archived" ${s.archived ? 'checked' : ''}> Aufgebraucht / ausgemustert (Platz wird frei)</label>
        <p class="muted">Aktuell geschätzt: ${L.formatGrams(r.remaining)}</p>` : ''}
    </div>
    <div class="mfoot">
      ${existing ? `<button type="button" class="danger left" data-act="del-spool" data-id="${existing.id}">Löschen</button>` : ''}
      <button type="button" data-close>Abbrechen</button>
      <button class="primary" type="submit">Speichern</button>
    </div>
    </form>`, (root) => {
    const sel = $('select[name=loc]', root);
    sel.addEventListener('change', () => { $('#loc-text-wrap', root).style.display = sel.value === 'other' ? '' : 'none'; });
    $('#spool-form', root).addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const location = decodeLocation(fd.get('loc'), fd.get('locText'));
      const data = {
        brand: String(fd.get('brand') || '').trim(),
        material: String(fd.get('material') || '').trim(),
        colorName: String(fd.get('colorName') || '').trim(),
        colorHex: L.normHex(fd.get('colorHex')),
        netWeight: num(fd.get('netWeight'), 1000),
        emptyWeight: num(fd.get('emptyWeight'), 0),
        diameter: num(fd.get('diameter'), 1.75),
        price: num(fd.get('price'), 0),
        purchaseDate: fd.get('purchaseDate') || '',
        bambuId: String(fd.get('bambuId') || '').trim().toUpperCase(),
        note: String(fd.get('note') || ''),
      };
      if (existing) {
        const occ = L.occupant(location, state.spools, existing.id);
        if (occ) {
          if (!confirm(`Der Platz ist belegt von „${L.spoolTitle(occ)}“. Plätze tauschen?`)) return;
          occ.location = existing.location || { kind: 'none' };
        }
        if (existing.location && existing.location.kind === 'box' && location.kind !== 'box') data.homeLocation = existing.location;
        data.archived = fd.get('archived') === 'on';
        if (data.archived && !existing.archived) data.location = { kind: 'empty' };
        else data.location = location;
        Object.assign(existing, data);
        await save();
        closeModal();
        render();
        toast('Gespeichert');
      } else {
        const count = Math.max(1, Math.min(20, parseInt(fd.get('count'), 10) || 1));
        const gross = num(fd.get('gross'), NaN);
        const created = [];
        let nextLoc = location;
        for (let i = 0; i < count; i++) {
          if (i > 0) nextLoc = L.firstFreeSlot(state.spools, state.settings) || { kind: 'none' };
          else {
            const occ = L.occupant(nextLoc, state.spools);
            if (occ && !confirm(`Platz ist schon belegt von „${L.spoolTitle(occ)}“. Trotzdem dort einlagern?`)) return;
          }
          const sp = { id: L.uid('s'), ...data, location: nextLoc, weighings: [], archived: false, created: new Date().toISOString() };
          if (Number.isFinite(gross) && i === 0) sp.weighings.push({ date: new Date().toISOString(), remaining: L.remainingFromScale(gross, data.emptyWeight) });
          state.spools.push(sp);
          created.push(sp);
        }
        await save();
        closeModal();
        render();
        toast(created.length > 1 ? `${created.length} Rollen angelegt` : `Angelegt: ${L.locationLabel(created[0].location)}`);
      }
    });
  });
}

function weighDialog(id) {
  const s = spoolById(id);
  const r = rem(s);
  openModal(`
    <form id="weigh-form">
    ${head('Rolle wiegen')}
    <div class="mbody">
      <p>Lege die Rolle (mit Spule) auf die Waage. Die Schätzung wird ab jetzt von diesem Wert aus weitergerechnet.</p>
      <label class="f">Waagengewicht inkl. Spule (g)<input name="gross" inputmode="decimal" autofocus required></label>
      <label class="f">Gewicht der leeren Spule (g)<input name="empty" inputmode="decimal" value="${esc(s.emptyWeight || 0)}"></label>
      <p class="muted">Bisher geschätzt: ${L.formatGrams(r.remaining)} Filament (= ${L.formatGrams(r.remaining + (Number(s.emptyWeight) || 0))} auf der Waage)</p>
      <p id="weigh-preview" class="muted"></p>
    </div>
    <div class="mfoot"><button type="button" data-close>Abbrechen</button><button class="primary" type="submit">Übernehmen</button></div>
    </form>`, (root) => {
    const f = $('#weigh-form', root);
    const upd = () => {
      const g = num(f.gross.value, NaN);
      $('#weigh-preview', root).textContent = Number.isFinite(g)
        ? `→ ${L.formatGrams(L.remainingFromScale(g, num(f.empty.value)))} Filament (Abweichung ${L.round(L.remainingFromScale(g, num(f.empty.value)) - r.remaining, 0)} g)` : '';
    };
    f.addEventListener('input', upd);
    f.addEventListener('submit', async (e) => {
      e.preventDefault();
      s.emptyWeight = num(f.empty.value);
      s.weighings = s.weighings || [];
      s.weighings.push({ date: new Date().toISOString(), remaining: L.remainingFromScale(num(f.gross.value), s.emptyWeight) });
      await save();
      render();
      spoolDetail(s.id);
      toast('Restmenge aktualisiert');
    });
  });
}

async function moveSpool(s, loc) {
  if (s.location && s.location.kind === 'box') s.homeLocation = s.location;
  s.location = loc;
  await save();
  render();
  spoolDetail(s.id);
}

function amsDialog(id) {
  const s = spoolById(id);
  let html = '';
  for (let u = 1; u <= state.settings.amsUnits; u++) {
    html += `<h3>AMS ${u}</h3><div class="slots">`;
    for (let p = 1; p <= 4; p++) {
      const occ = L.occupant({ kind: 'ams', unit: u, slot: p }, state.spools, s.id);
      html += `<button class="slot ${occ ? 'full' : ''}" data-act="pick-ams" data-id="${s.id}" data-u="${u}" data-p="${p}">
        ${occ ? sw(occ.colorHex) : ''}<span><span class="n">Slot ${p}</span><br><span class="r">${occ ? esc(L.spoolTitle(occ)) + ' → kommt zurück in seine Box' : 'frei'}</span></span></button>`;
    }
    html += '</div>';
  }
  openModal(`${head('In welchen AMS-Slot?')}<div class="mbody">${html}</div>`);
}

async function pickAms(id, unit, slot) {
  const s = spoolById(id);
  const loc = { kind: 'ams', unit, slot };
  const occ = L.occupant(loc, state.spools, s.id);
  if (occ) {
    const back = occ.homeLocation && !L.occupant(occ.homeLocation, state.spools, occ.id) && !L.sameLocation(occ.homeLocation, s.location)
      ? occ.homeLocation
      : (s.location && s.location.kind === 'box' ? s.location : L.firstFreeSlot(state.spools, state.settings, occ.id));
    occ.location = back || { kind: 'none' };
    toast(`„${L.spoolTitle(occ)}“ → ${L.locationLabel(occ.location)}`);
  }
  await moveSpool(s, loc);
}

// ---------- Ansicht: Boxen ----------

function viewBoxes() {
  const st = state.settings;
  let html = '<div class="boxes">';
  for (let b = 1; b <= st.boxCount; b++) {
    const info = state.boxes[b] || {};
    const occ = L.boxOccupancy(b, state.spools, st.slotsPerBox);
    const age = info.desiccantDate ? -L.daysUntil(info.desiccantDate) : null;
    const dryBadge = age == null ? '<span class="badge info">Trockenmittel ?</span>'
      : age > 60 ? `<span class="badge danger">Trockenm. ${age} T</span>`
        : age > 30 ? `<span class="badge warn">Trockenm. ${age} T</span>` : `<span class="badge ok">Trockenm. ${age} T</span>`;
    html += `<div class="card box ${ui.highlightBox == b ? 'hl' : ''}" data-box-card="${b}">
      <h3><span>📦 Box ${b}${info.name ? ' · ' + esc(info.name) : ''}</span>
        <button class="small ghost" data-act="box-edit" data-box="${b}">✎</button></h3>
      <div>${dryBadge} <small>${occ.filter(Boolean).length}/${st.slotsPerBox} belegt</small></div>
      <div class="slots">${occ.map((s, i) => slotHtml(s, 'box', b, i + 1)).join('')}</div>
    </div>`;
  }
  html += '</div>';
  for (let u = 1; u <= st.amsUnits; u++) {
    html += `<h2>🖨️ AMS ${u}</h2><div class="card"><div class="slots">`;
    for (let p = 1; p <= 4; p++) {
      const s = L.occupant({ kind: 'ams', unit: u, slot: p }, state.spools);
      html += slotHtml(s, 'ams', u, p);
    }
    html += '</div></div>';
  }
  const elsewhere = state.spools.filter((s) => !s.archived && (!s.location || !['box', 'ams'].includes(s.location.kind)));
  if (elsewhere.length) {
    html += `<h2>Ohne Box</h2><div class="list">${elsewhere.map(spoolCard).join('')}</div>`;
  }
  return html;
}

function slotHtml(s, kind, a, p) {
  const label = kind === 'box' ? `Platz ${p}` : `Slot ${p}`;
  if (!s) return `<button class="slot" data-act="slot-empty" data-kind="${kind}" data-a="${a}" data-p="${p}"><span class="no">${label}<br>frei – ＋</span></button>`;
  const r = rem(s);
  return `<button class="slot full ${ui.highlightSpool === s.id ? 'hl' : ''}" data-act="spool" data-id="${s.id}">
    ${sw(s.colorHex)}<span><span class="no">${label}</span><br><span class="n">${esc(s.colorName || L.baseColorName(s.colorHex))}</span><br>
    <span class="r">${esc(L.materialBase(s.material))} · ${L.formatGrams(r.remaining)}</span></span></button>`;
}

function boxEdit(b) {
  const info = state.boxes[b] || {};
  openModal(`
    <form id="box-form">${head('Box ' + b)}
    <div class="mbody">
      <label class="f">Beschriftung (optional)<input name="name" value="${esc(info.name)}" placeholder="z. B. PLA bunt"></label>
      <label class="f">Trockenmittel zuletzt gewechselt<input type="date" name="desiccantDate" value="${esc(info.desiccantDate || '')}"></label>
      <button type="button" data-act="dry-today">Heute gewechselt</button>
      <label class="f">Notiz<textarea name="note">${esc(info.note)}</textarea></label>
    </div>
    <div class="mfoot"><button type="button" data-close>Abbrechen</button><button class="primary">Speichern</button></div>
    </form>`, (root) => {
    const f = $('#box-form', root);
    $('[data-act=dry-today]', root).addEventListener('click', () => { f.desiccantDate.value = today(); });
    f.addEventListener('submit', async (e) => {
      e.preventDefault();
      state.boxes[b] = { name: f.name.value.trim(), desiccantDate: f.desiccantDate.value, note: f.note.value };
      await save();
      closeModal();
      render();
    });
  });
}

function slotEmptyDialog(kind, a, p) {
  const loc = kind === 'box' ? { kind, box: a, slot: p } : { kind, unit: a, slot: p };
  const movable = state.spools.filter((s) => !s.archived && !L.sameLocation(s.location, loc))
    .sort((x, y) => (x.location && ['box', 'ams'].includes(x.location.kind) ? 1 : 0) - (y.location && ['box', 'ams'].includes(y.location.kind) ? 1 : 0));
  openModal(`${head(L.locationLabel(loc))}
    <div class="mbody">
      <p><button class="primary" data-act="new-spool-at" data-loc='${esc(JSON.stringify(loc))}'>＋ Neue Rolle hier anlegen</button></p>
      ${movable.length ? `<h3>Oder vorhandene Rolle hierher legen</h3><div class="list">${movable.map((s) => `
        <div class="card click spool" data-act="move-here" data-id="${s.id}" data-loc='${esc(JSON.stringify(loc))}'>
          ${sw(s.colorHex)}<div><div class="t">${esc(L.spoolTitle(s))}</div><div class="meta">${L.formatGrams(rem(s).remaining)}</div></div>${locBadge(s.location)}
        </div>`).join('')}</div>` : ''}
    </div>`);
}

// ---------- Ansicht: Drucke ----------

function viewPrints() {
  const prints = state.prints.slice().sort((a, b) => String(b.date).localeCompare(String(a.date)));
  const unassigned = prints.filter((p) => (p.filaments || []).some((f) => !f.spoolId)).length;
  let html = `
    <div class="drop">
      <p><b>Druckhistorie aus Bambu Studio einlesen</b></p>
      <p class="muted">Geslicte Dateien (<code>.gcode.3mf</code>), <code>.gcode</code> oder die Cloud-Historie (<code>.json</code>) hierher ziehen oder auswählen.</p>
      <p><label class="btn primary">📂 Dateien wählen<input type="file" id="import-files" multiple accept=".3mf,.gcode,.json" hidden></label>
      <button data-act="manual-print">✎ Manuell eintragen</button></p>
      <p><a href="#" data-act="import-help">Wie komme ich an die Dateien?</a></p>
    </div>`;
  if (unassigned) html += `<p><span class="badge warn">${unassigned} Druck(e) ohne zugeordnete Rolle</span> – antippen und Rolle wählen, sonst zählt der Verbrauch nicht.</p>`;
  if (!prints.length) {
    html += '<div class="empty"><div class="big">🖨️</div><p>Noch keine Drucke importiert.</p></div>';
  } else {
    html += `<div class="list">${prints.map(printCard).join('')}</div>`;
  }
  return html;
}

function printCard(p) {
  const total = (p.filaments || []).reduce((s, f) => s + (Number(f.grams) || 0), 0);
  const o = p.orderId ? orderById(p.orderId) : null;
  return `<div class="card click print" data-act="print" data-id="${p.id}">
    ${p.thumbId ? `<img class="thumb" data-blob="${esc(p.thumbId)}" alt="">` : '<div class="thumb">🧊</div>'}
    <div>
      <div class="t"><b>${esc(p.name)}</b> ${p.status === 'failed' ? `<span class="badge danger">abgebrochen ${esc(p.progress)} %</span>` : ''}</div>
      <div class="meta muted" style="font-size:13px">${fmtDateTime(p.date)} · ${L.formatDuration(p.durationS)}${o ? ` · 📋 ${esc(o.title)} (${esc(p.pieces || 0)} Stk.)` : ''}</div>
      <div class="fils">${(p.filaments || []).map((f) => {
        const s = spoolById(f.spoolId);
        return `<span>${sw(s ? s.colorHex : f.colorHex, 's')} ${g1(f.grams)} g ${s ? esc(s.colorName || L.materialBase(s.material)) : '<span class="miss">keine Rolle</span>'}</span>`;
      }).join('')}</div>
    </div>
    <div class="right"><b>${g1(total)} g</b></div>
  </div>`;
}

function spoolSelect(name, selectedId, filament) {
  const ranked = filament ? L.rankSpools(filament, state.spools, state.prints) : state.spools.filter((s) => !s.archived).map((s) => ({ spool: s, remaining: rem(s).remaining }));
  const sel = selectedId ? spoolById(selectedId) : null;
  if (sel && sel.archived) ranked.push({ spool: sel, remaining: rem(sel).remaining });
  return `<select name="${name}">
    <option value="">— keine Rolle (zählt nicht) —</option>
    ${ranked.map((x) => `<option value="${x.spool.id}" ${x.spool.id === selectedId ? 'selected' : ''}>${esc(L.spoolTitle(x.spool))} · ${L.formatGrams(x.remaining)} · ${esc(L.locationLabel(x.spool.location))}</option>`).join('')}
  </select>`;
}

function orderSelect(name, selectedId) {
  const list = state.orders.filter((o) => L.OPEN_STATUS.includes(o.status) || o.id === selectedId);
  return `<select name="${name}">
    <option value="">— kein Auftrag (eigener Druck) —</option>
    ${list.map((o) => `<option value="${o.id}" ${o.id === selectedId ? 'selected' : ''}>${esc(o.title)}${o.customer ? ' – ' + esc(o.customer) : ''}</option>`).join('')}
  </select>`;
}

function printFields(p, i) {
  const k = (n) => `d${i}_${n}`;
  return `
    <div class="row">
      <label class="f">Name<input name="${k('name')}" value="${esc(p.name)}"></label>
      <label class="f">Datum<input type="datetime-local" name="${k('date')}" value="${esc(toLocalInput(p.date))}"></label>
    </div>
    ${(p.filaments || []).map((f, j) => `
      <div class="filrow">
        <span class="lbl">${sw(f.colorHex, 's')} ${esc(f.type || 'Filament')}
          <input name="${k('g' + j)}" inputmode="decimal" value="${esc(f.grams)}" style="width:80px;padding:4px 6px"> g</span>
        ${spoolSelect(k('s' + j), f.spoolId, f)}
      </div>`).join('')}
    <div class="row">
      <label class="f">Auftrag${orderSelect(k('order'), p.orderId)}</label>
      <label class="f" style="flex:0 0 90px">Stück<input name="${k('pieces')}" type="number" min="0" value="${esc(p.pieces ?? 1)}"></label>
    </div>
    <div class="row">
      <label class="f">Ergebnis<select name="${k('status')}">
        <option value="ok" ${p.status !== 'failed' ? 'selected' : ''}>Erfolgreich</option>
        <option value="failed" ${p.status === 'failed' ? 'selected' : ''}>Abgebrochen / Fehldruck</option>
      </select></label>
      <label class="f" style="flex:0 0 140px">Gedruckt bis (%)<input name="${k('progress')}" type="number" min="0" max="100" value="${esc(p.progress ?? 100)}"></label>
    </div>`;
}

function readPrintFields(fd, p, i) {
  const k = (n) => `d${i}_${n}`;
  p.name = String(fd.get(k('name')) || p.name).trim();
  const d = fd.get(k('date'));
  if (d) p.date = new Date(d).toISOString();
  p.filaments = (p.filaments || []).map((f, j) => ({ ...f, grams: num(fd.get(k('g' + j)), f.grams), spoolId: fd.get(k('s' + j)) || '' }));
  p.orderId = fd.get(k('order')) || '';
  p.pieces = Math.max(0, parseInt(fd.get(k('pieces')), 10) || 0);
  p.status = fd.get(k('status')) === 'failed' ? 'failed' : 'ok';
  p.progress = p.status === 'failed' ? Math.max(0, Math.min(100, num(fd.get(k('progress')), 50))) : 100;
}

async function afterBooking(orderIds) {
  for (const id of new Set(orderIds.filter(Boolean))) {
    const o = orderById(id);
    if (!o) continue;
    const pr = L.orderProgress(o, state.prints);
    if (['anfrage', 'angebot', 'konstruktion', 'druckbereit'].includes(o.status) && pr.done > 0) o.status = 'druck';
    if (pr.open === 0 && L.OPEN_STATUS.includes(o.status)) {
      o.status = 'fertig';
      toast(`Auftrag „${o.title}“ ist fertig gedruckt 🎉`);
    }
  }
  const low = state.spools.filter((s) => !s.archived && rem(s).remaining < state.settings.lowThreshold && rem(s).remaining > 0);
  return low;
}

async function handleFiles(files) {
  const drafts = [];
  const errors = [];
  toast('Lese Dateien …');
  for (const f of files) {
    try {
      const { prints, thumbs } = await parseFile(f);
      for (const p of prints) drafts.push({ ...p, thumb: thumbs[p.fingerprint] || null });
    } catch (e) {
      errors.push(`${f.name}: ${e.message}`);
    }
  }
  if (!drafts.length) {
    alert(errors.join('\n\n') || 'Nichts gefunden');
    return;
  }
  const printing = state.orders.filter((o) => o.status === 'druck');
  for (const d of drafts) {
    d.duplicate = state.prints.some((p) => p.fingerprint === d.fingerprint);
    d.include = !d.duplicate;
    d.status = d.status || 'ok';
    d.progress = d.progress ?? 100;
    d.pieces = d.objects && d.objects.length ? d.objects.length : 1;
    d.orderId = printing.length === 1 ? printing[0].id : '';
    d.filaments = d.filaments.map((f) => ({ ...f, spoolId: (L.suggestSpool(f, state.spools, state.prints) || {}).id || '' }));
  }
  importDialog(drafts, errors);
}

function importDialog(drafts, errors) {
  const thumbUrls = drafts.map((d) => (d.thumb ? URL.createObjectURL(d.thumb) : ''));
  openModal(`
    <form id="import-form">
    ${head(`${drafts.length} Druck${drafts.length > 1 ? 'e' : ''} importieren`)}
    <div class="mbody">
      ${errors.length ? `<div class="card" style="background:var(--warn-soft)"><b>Nicht gelesen:</b><br>${errors.map(esc).join('<br>')}</div>` : ''}
      <p class="muted">Prüfe die Rollen-Zuordnung. Vorschläge kommen aus Material, Farbe und AMS-Slot.</p>
      ${drafts.map((d, i) => `
        <div class="card draft ${d.include ? '' : 'off'}" data-draft="${i}">
          <div class="row" style="align-items:center">
            <label class="check shrink"><input type="checkbox" name="d${i}_inc" ${d.include ? 'checked' : ''}> übernehmen</label>
            ${thumbUrls[i] ? `<img class="thumb shrink" src="${thumbUrls[i]}" alt="">` : ''}
            <div>${d.duplicate ? '<span class="badge warn">schon importiert</span> ' : ''}<small>${esc(d.source)} · ${L.formatDuration(d.durationS)}${d.device ? ' · ' + esc(d.device) : ''}</small></div>
          </div>
          ${printFields(d, i)}
        </div>`).join('')}
    </div>
    <div class="mfoot"><button type="button" data-close>Abbrechen</button><button class="primary" type="submit">Buchen</button></div>
    </form>`, (root) => {
    const form = $('#import-form', root);
    form.addEventListener('change', (e) => {
      if (e.target.name && e.target.name.endsWith('_inc')) e.target.closest('.draft').classList.toggle('off', !e.target.checked);
    });
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(form);
      let n = 0;
      const orderIds = [];
      for (let i = 0; i < drafts.length; i++) {
        if (fd.get(`d${i}_inc`) !== 'on') continue;
        const d = drafts[i];
        const p = {
          id: L.uid('p'), name: d.name, date: d.date, source: d.source, plate: d.plate, durationS: d.durationS,
          fingerprint: d.fingerprint, filaments: d.filaments.map((f) => ({ ...f })), objects: d.objects || [],
        };
        readPrintFields(fd, p, i);
        if (d.thumb) {
          p.thumbId = 'thumb_' + p.id;
          await putBlob(p.thumbId, d.thumb);
        }
        state.prints.push(p);
        orderIds.push(p.orderId);
        n++;
      }
      thumbUrls.forEach((u) => u && URL.revokeObjectURL(u));
      const low = await afterBooking(orderIds);
      await save();
      closeModal();
      render();
      toast(`${n} Druck${n === 1 ? '' : 'e'} gebucht` + (low.length ? ` · ⚠ wenig: ${low.map((s) => s.colorName || s.material).slice(0, 3).join(', ')}` : ''));
    });
  });
}

function printEdit(id, preset = {}) {
  const existing = id ? state.prints.find((p) => p.id === id) : null;
  const p = existing ? JSON.parse(JSON.stringify(existing)) : {
    name: preset.name || '', date: new Date().toISOString(), source: 'manual', status: 'ok', progress: 100,
    pieces: preset.pieces ?? 1, orderId: preset.orderId || '', durationS: 0,
    filaments: [],
  };
  // eine leere Zeile für weiteres Filament
  p.filaments.push({ slot: p.filaments.length + 1, type: '', colorHex: '', grams: '', spoolId: '' , _new: true });
  openModal(`
    <form id="print-form">
    ${head(existing ? 'Druck bearbeiten' : 'Druck manuell eintragen')}
    <div class="mbody">
      ${p.thumbId ? `<img class="thumb" data-blob="${esc(p.thumbId)}" alt="" style="width:110px;height:110px">` : ''}
      ${printFields(p, 0)}
      <label class="f">Druckzeit (Stunden)<input name="hours" inputmode="decimal" value="${esc(p.durationS ? L.round(p.durationS / 3600, 2) : '')}"></label>
      <p class="muted">Letzte Filament-Zeile leer lassen, wenn nicht gebraucht. Gramm aus Bambu Studio (Slicer-Vorschau) übernehmen.</p>
    </div>
    <div class="mfoot">
      ${existing ? `<button type="button" class="danger left" data-act="del-print" data-id="${existing.id}">Löschen</button>` : ''}
      <button type="button" data-close>Abbrechen</button><button class="primary" type="submit">Speichern</button>
    </div>
    </form>`, (root) => {
    const form = $('#print-form', root);
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(form);
      readPrintFields(fd, p, 0);
      p.filaments = p.filaments.filter((f) => num(f.grams) > 0).map((f) => {
        const s = spoolById(f.spoolId);
        const out = { ...f, grams: num(f.grams) };
        delete out._new;
        if (s && !out.type) { out.type = L.materialBase(s.material); out.colorHex = s.colorHex; }
        return out;
      });
      const h = num(fd.get('hours'), NaN);
      if (Number.isFinite(h)) p.durationS = Math.round(h * 3600);
      if (!p.name) p.name = 'Druck';
      const oldOrder = existing && existing.orderId;
      if (existing) Object.assign(existing, p);
      else state.prints.push({ ...p, id: L.uid('p'), fingerprint: 'manual:' + Date.now() });
      await afterBooking([p.orderId, oldOrder]);
      await save();
      closeModal();
      render();
      toast('Gespeichert');
    });
  });
}

function importHelp() {
  openModal(`${head('Druckhistorie aus Bambu Studio')}
    <div class="mbody help">
      <h3>Variante A: geslicte Datei (am genauesten)</h3>
      <ol>
        <li>In Bambu Studio die Platte slicen.</li>
        <li><b>Datei → Exportieren → Geslicte Datei exportieren</b> (bzw. „Alle geslicten Platten exportieren“) → <code>.gcode.3mf</code>.</li>
        <li>Datei hier hineinziehen. Die App liest Gramm pro Filament, Farbe, Material, Druckzeit und das Vorschaubild.</li>
      </ol>
      <p class="muted">Tipp: Lege dir einen Ordner „Gedruckt“ an und exportiere jeden Druck dorthin – dann einfach alle neuen Dateien auf einmal importieren. Doppelte werden erkannt.</p>
      <h3>Variante B: G-Code</h3>
      <p>Auch <code>.gcode</code>-Dateien (Bambu Studio, Orca, PrusaSlicer) werden gelesen – z. B. von der SD-Karte des Druckers.</p>
      <h3>Variante C: komplette Cloud-Historie</h3>
      <p>Wenn du über die Bambu-Cloud druckst, speichert Bambu jeden Druck mit Verbrauch pro AMS-Slot. Das Hilfsskript <code>tools/bambu_cloud_export.py</code> im Repo lädt die Historie als <code>bambu_history.json</code> herunter (Login mit deinem Bambu-Konto, nur auf deinem PC). Die JSON-Datei hier importieren.</p>
      <p class="muted">Abgebrochene Drucke: Die Cloud meldet den geplanten Verbrauch. Gib bei „Gedruckt bis (%)“ an, wie weit er kam – die App zieht nur diesen Anteil ab.</p>
      <h3>Genauigkeit</h3>
      <p>Die Slicer-Werte sind Schätzungen (Spülen beim Farbwechsel ist enthalten, Fehlversuche nicht). Wiege die Rolle ab und zu (⚖️ in der Rolle) – ab dann wird von diesem Wert aus weitergerechnet.</p>
    </div>`);
}

// ---------- Ansicht: Aufträge ----------

function statusLabel(id) {
  return (L.ORDER_STATUS.find((s) => s.id === id) || { label: id }).label;
}

function viewOrders() {
  const f = ui.orderFilter;
  let list = state.orders.slice();
  if (f === 'open') list = list.filter((o) => L.OPEN_STATUS.includes(o.status));
  if (f === 'done') list = list.filter((o) => !L.OPEN_STATUS.includes(o.status));
  list.sort((a, b) => (a.deadline || '9999').localeCompare(b.deadline || '9999') || String(b.created).localeCompare(String(a.created)));
  const openCount = state.orders.filter((o) => L.OPEN_STATUS.includes(o.status)).length;
  const unpaid = state.orders.filter((o) => !o.paid && o.price && ['fertig', 'uebergeben'].includes(o.status));
  let html = `<div class="chips">
    <button class="chip ${f === 'open' ? 'on' : ''}" data-act="ofilter" data-f="open">Offen (${openCount})</button>
    <button class="chip ${f === 'done' ? 'on' : ''}" data-act="ofilter" data-f="done">Erledigt</button>
    <button class="chip ${f === 'all' ? 'on' : ''}" data-act="ofilter" data-f="all">Alle</button>
  </div>`;
  if (unpaid.length) html += `<p><span class="badge warn">${unpaid.length} fertig, aber nicht bezahlt</span> ${unpaid.map((o) => esc(o.title)).join(', ')}</p>`;
  if (!list.length) {
    html += `<div class="empty"><div class="big">📋</div><p>${state.orders.length ? 'Keine Aufträge in dieser Ansicht.' : 'Noch keine Aufträge.'}</p></div>`;
  } else {
    html += `<div class="list">${list.map(orderCard).join('')}</div>`;
  }
  html += '<button class="primary fab" data-act="new-order">＋ Auftrag</button>';
  return html;
}

function deadlineBadge(o) {
  if (!o.deadline || !L.OPEN_STATUS.includes(o.status)) return '';
  const d = L.daysUntil(o.deadline);
  if (d < 0) return `<span class="badge danger">${-d} T überfällig</span>`;
  if (d === 0) return '<span class="badge danger">heute fällig</span>';
  if (d <= 3) return `<span class="badge warn">in ${d} T</span>`;
  return `<span class="badge info">bis ${fmtDate(o.deadline)}</span>`;
}

function orderCard(o) {
  const pr = L.orderProgress(o, state.prints);
  return `<div class="card click order" data-act="order" data-id="${o.id}">
    <div class="head">
      <div>
        <div class="t">${o.kind === 'eigen' ? '✏️' : '🌐'} ${esc(o.title)}</div>
        <div class="meta">${esc(o.customer || 'ohne Kunde')}${o.material ? ' · ' + esc(o.material) : ''} ${o.colorHex ? sw(o.colorHex, 's') : ''}</div>
      </div>
      <span class="st ${esc(o.status)}">${esc(statusLabel(o.status))}</span>
    </div>
    <div class="meta" style="margin-top:6px">${pr.done}/${pr.quantity} Stück ${deadlineBadge(o)} ${o.price ? `· ${L.formatMoney(o.price)}${o.paid ? ' ✓' : ''}` : ''}</div>
    <div class="bar"><i style="width:${pr.percent}%"></i></div>
    ${(o.photos || []).length ? `<div class="photos">${o.photos.slice(0, 5).map((ph) => `<img data-blob="${esc(ph.id)}" alt="">`).join('')}</div>` : ''}
  </div>`;
}

function orderDetail(id) {
  const o = orderById(id);
  if (!o) return;
  const pr = L.orderProgress(o, state.prints);
  const costs = L.orderCosts(o, state.prints, state.spools, state.settings);
  const prints = state.prints.filter((p) => p.orderId === o.id).sort((a, b) => String(b.date).localeCompare(String(a.date)));
  const fits = o.material || o.colorHex ? L.spoolsForOrder(o, state.spools, state.prints).slice(0, 6) : [];
  const avgPrice = (() => {
    const s = state.spools.filter((x) => !x.archived && x.price && (!o.material || L.materialBase(x.material) === L.materialBase(o.material)));
    return s.length ? s.reduce((t, x) => t + L.pricePerGram(x) * 1000, 0) / s.length : 20;
  })();
  const q = L.quote({
    gramsPerPiece: o.gramsPerPiece, hoursPerPiece: o.hoursPerPiece, pieces: pr.quantity,
    pricePerKg: avgPrice, hourlyRate: state.settings.hourlyRate, markup: state.settings.markup,
  });
  const idx = L.ORDER_STATUS.findIndex((s) => s.id === o.status);
  const images = (o.photos || []).filter((p) => /^image\//.test(p.type || 'image/'));
  const files = (o.photos || []).filter((p) => p.type && !/^image\//.test(p.type));
  openModal(`
    ${head(o.title)}
    <div class="mbody">
      <div class="steps">${L.ORDER_STATUS.filter((s) => o.kind === 'eigen' || s.id !== 'konstruktion').map((s) => {
        const i = L.ORDER_STATUS.findIndex((x) => x.id === s.id);
        return `<button class="${s.id === o.status ? 'on' : i < idx ? 'past' : ''}" data-act="set-status" data-id="${o.id}" data-s="${s.id}">${esc(s.label)}</button>`;
      }).join('')}</div>
      <dl class="kv">
        <dt>Kunde</dt><dd>${esc(o.customer || '–')}${o.contact ? `<br><small>${linkify(o.contact)}</small>` : ''}</dd>
        <dt>Art</dt><dd>${o.kind === 'eigen' ? '✏️ Eigene Konstruktion' : '🌐 Modell aus dem Netz'}</dd>
        <dt>Stückzahl</dt><dd><b>${pr.done} / ${pr.quantity}</b> gedruckt${pr.open ? ` · noch ${pr.open}` : ' ✓'}</dd>
        ${o.deadline ? `<dt>Termin</dt><dd>${fmtDate(o.deadline)} ${deadlineBadge(o)}</dd>` : ''}
        <dt>Material</dt><dd>${esc(o.material || '–')} ${o.colorHex ? sw(o.colorHex, 's') : ''} ${esc(o.colorWish || '')}</dd>
        <dt>Preis</dt><dd>${o.price ? L.formatMoney(o.price) : '–'} ${o.price ? (o.paid ? '<span class="badge ok">bezahlt</span>' : '<span class="badge warn">offen</span>') : ''}</dd>
      </dl>
      <div class="bar"><i style="width:${pr.percent}%"></i></div>

      ${(o.urls || []).length ? `<h3>Modell-Links</h3>${o.urls.map((u) => `<div><a href="${esc(safeUrl(u))}" target="_blank" rel="noopener">${esc(L.modelSite(u))}</a> <small class="muted">${esc(u)}</small></div>`).join('')}
        ${o.license ? `<p><small>Lizenz: ${esc((L.LICENSES.find((l) => l.id === o.license) || {}).label)}</small>${o.license === 'nc' && o.price ? ' <span class="badge danger">NC-Lizenz – Verkauf nicht erlaubt!</span>' : ''}</p>` : `<p><small class="muted">Lizenz prüfen: Viele Modelle sind nur für nicht-kommerzielle Nutzung.</small></p>`}` : ''}

      ${o.measurements ? `<h3>Maße & Beschreibung</h3><div class="card pre">${esc(o.measurements)}</div>` : ''}
      ${images.length ? `<h3>Fotos</h3><div class="gallery">${images.map((ph) => `<div class="ph"><img data-blob="${esc(ph.id)}" data-act="zoom" alt=""></div>`).join('')}</div>` : ''}
      ${files.length ? `<h3>Dateien</h3>${files.map((f) => `<div><a href="#" data-act="download" data-blobid="${esc(f.id)}" data-name="${esc(f.name)}">📎 ${esc(f.name)}</a></div>`).join('')}` : ''}
      ${o.notes ? `<h3>Notizen</h3><div class="pre">${esc(o.notes)}</div>` : ''}

      ${fits.length ? `<h3>Passende Rollen</h3><div class="list">${fits.map((x) => `
        <div class="card click spool" data-act="spool" data-id="${x.spool.id}">${sw(x.spool.colorHex)}
          <div><div class="t">${esc(L.spoolTitle(x.spool))}</div><div class="meta">${L.formatGrams(x.remaining)}${x.need ? (x.enough ? ` · reicht für Rest (${L.formatGrams(x.need)})` : ` · <b style="color:var(--warn)">reicht nicht für ${L.formatGrams(x.need)}</b>`) : ''}</div></div>
          ${locBadge(x.spool.location)}</div>`).join('')}</div>` : ''}

      <h3>Drucke (${prints.length})</h3>
      ${prints.length ? `<div class="list">${prints.map(printCard).join('')}</div>` : '<p class="muted">Noch keine. Beim Import einer Datei diesen Auftrag wählen.</p>'}
      <p><button class="small" data-act="order-print" data-id="${o.id}">＋ Druck manuell hinzufügen</button></p>

      <h3>Kosten</h3>
      <dl class="kv">
        <dt>Bisher verbraucht</dt><dd>${L.formatGrams(costs.grams)} · ${L.formatMoney(costs.material)} Material${costs.hours ? ` · ${costs.hours} h` : ''}${costs.machine ? ` · ${L.formatMoney(costs.machine)} Maschine` : ''}</dd>
        ${o.gramsPerPiece ? `<dt>Kalkulation</dt><dd>${pr.quantity} × ${esc(o.gramsPerPiece)} g${o.hoursPerPiece ? ` / ${esc(o.hoursPerPiece)} h` : ''} = ${L.formatGrams(q.grams)}<br>
          Material ${L.formatMoney(q.material)}${q.machine ? ` + Maschine ${L.formatMoney(q.machine)}` : ''}${state.settings.markup ? ` + ${state.settings.markup} % Aufschlag` : ''} → <b>${L.formatMoney(q.total)}</b>
          <br><small class="muted">mit Ø ${L.formatMoney(avgPrice)}/kg</small></dd>` : '<dt>Kalkulation</dt><dd class="muted">„Gramm pro Stück“ im Auftrag eintragen für einen Preisvorschlag.</dd>'}
      </dl>
    </div>
    <div class="mfoot">
      <button class="left" data-act="copy-order" data-id="${o.id}">Text kopieren</button>
      <button class="primary" data-act="edit-order" data-id="${o.id}">Bearbeiten</button>
    </div>`);
}

function safeUrl(u) {
  const s = String(u || '').trim();
  return /^https?:\/\//i.test(s) ? s : 'https://' + s;
}

function linkify(text) {
  const t = String(text || '').trim();
  if (/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(t)) return `<a href="mailto:${esc(t)}">${esc(t)}</a>`;
  if (/^[+\d][\d\s/()-]{5,}$/.test(t)) return `<a href="tel:${esc(t.replace(/[^\d+]/g, ''))}">${esc(t)}</a>`;
  return esc(t);
}

async function resizeImage(file, max = 1600) {
  try {
    const bmp = await createImageBitmap(file);
    const scale = Math.min(1, max / Math.max(bmp.width, bmp.height));
    const c = document.createElement('canvas');
    c.width = Math.round(bmp.width * scale);
    c.height = Math.round(bmp.height * scale);
    c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height);
    return await new Promise((res) => c.toBlob((b) => res(b || file), 'image/jpeg', 0.85));
  } catch {
    return file;
  }
}

function orderForm(id) {
  const existing = id ? orderById(id) : null;
  const o = existing ? JSON.parse(JSON.stringify(existing)) : {
    kind: 'modell', status: 'anfrage', quantity: 1, urls: [], photos: [], created: new Date().toISOString(),
  };
  const photos = (o.photos || []).slice();
  const added = [];
  const renderPhotos = () => photos.map((ph, i) => /^image\//.test(ph.type || 'image/')
    ? `<div class="ph"><img data-blob="${esc(ph.id)}" alt=""><button type="button" class="x" data-rm="${i}">✕</button></div>`
    : `<div class="ph card" style="padding:6px;font-size:12px;word-break:break-all">📎 ${esc(ph.name)}<button type="button" class="x" data-rm="${i}">✕</button></div>`).join('');
  openModal(`
    <form id="order-form">
    ${head(existing ? 'Auftrag bearbeiten' : 'Neuer Auftrag')}
    <div class="mbody">
      <label class="f">Was soll gedruckt werden?<input name="title" value="${esc(o.title)}" required placeholder="z. B. Ersatz-Knopf Spülmaschine"></label>
      <div class="row">
        <label class="f">Kunde<input name="customer" value="${esc(o.customer)}" placeholder="Name"></label>
        <label class="f">Kontakt<input name="contact" value="${esc(o.contact)}" placeholder="Telefon / E-Mail"></label>
      </div>
      <div class="chips">
        <label class="chip ${o.kind === 'modell' ? 'on' : ''}"><input type="radio" name="kind" value="modell" ${o.kind === 'modell' ? 'checked' : ''} hidden> 🌐 Modell aus dem Netz</label>
        <label class="chip ${o.kind === 'eigen' ? 'on' : ''}"><input type="radio" name="kind" value="eigen" ${o.kind === 'eigen' ? 'checked' : ''} hidden> ✏️ Selbst konstruieren</label>
      </div>
      <div data-kind="modell">
        <label class="f">Links zum Modell (einer pro Zeile – MakerWorld, Printables, Thingiverse …)<textarea name="urls" placeholder="https://makerworld.com/…">${esc((o.urls || []).join('\n'))}</textarea></label>
        <label class="f">Lizenz<select name="license">${L.LICENSES.map((l) => `<option value="${l.id}" ${o.license === l.id ? 'selected' : ''}>${esc(l.label)}</option>`).join('')}</select></label>
      </div>
      <label class="f"><span data-kind="eigen">Maße & Beschreibung (was muss passen, wofür ist es?)</span><span data-kind="modell">Hinweise (Größe/Skalierung, Varianten …)</span>
        <textarea name="measurements" rows="4" placeholder="z. B. Innen-Ø 12 mm, Länge 40 mm, Loch für M3">${esc(o.measurements)}</textarea></label>
      <h3>Fotos & Dateien</h3>
      <div class="gallery" id="photo-list">${renderPhotos()}</div>
      <p class="row">
        <label class="btn">📷 Foto<input type="file" accept="image/*" capture="environment" id="photo-cam" hidden></label>
        <label class="btn">🖼️ Bilder<input type="file" accept="image/*" multiple id="photo-add" hidden></label>
        <label class="btn">📎 Datei (STL, 3MF, PDF …)<input type="file" multiple id="file-add" hidden></label>
      </p>
      <div class="row">
        <label class="f">Stückzahl<input name="quantity" type="number" min="1" value="${esc(o.quantity || 1)}"></label>
        <label class="f">Termin<input name="deadline" type="date" value="${esc(o.deadline || '')}"></label>
      </div>
      <div class="row">
        <label class="f">Material<input name="material" list="materials2" value="${esc(o.material)}" placeholder="PLA"></label>
        <label class="f">Farbwunsch<input name="colorWish" value="${esc(o.colorWish)}" placeholder="z. B. schwarz matt"></label>
        <label class="f shrink" style="width:80px">Farbe<input type="color" name="colorHex" value="${esc(L.normHex(o.colorHex) || '#888888')}"></label>
      </div>
      <label class="check"><input type="checkbox" name="noColor" ${o.colorHex ? '' : 'checked'}> Farbe egal</label>
      <datalist id="materials2">${MATERIALS.map((b) => `<option value="${esc(b)}">`).join('')}</datalist>
      <div class="row">
        <label class="f">Gramm pro Stück<input name="gramsPerPiece" inputmode="decimal" value="${esc(o.gramsPerPiece ?? '')}" placeholder="aus Slicer"></label>
        <label class="f">Std. pro Stück<input name="hoursPerPiece" inputmode="decimal" value="${esc(o.hoursPerPiece ?? '')}"></label>
      </div>
      <div class="row">
        <label class="f">Status<select name="status">${L.ORDER_STATUS.map((s) => `<option value="${s.id}" ${o.status === s.id ? 'selected' : ''}>${esc(s.label)}</option>`).join('')}</select></label>
        <label class="f">Preis (€)<input name="price" inputmode="decimal" value="${esc(o.price ?? '')}"></label>
      </div>
      <label class="check"><input type="checkbox" name="paid" ${o.paid ? 'checked' : ''}> Bezahlt</label>
      <label class="f">Zusätzlich fertig (ohne importierten Druck)<input name="manualDone" type="number" min="0" value="${esc(o.manualDone || 0)}"></label>
      <label class="f">Notizen<textarea name="notes">${esc(o.notes)}</textarea></label>
    </div>
    <div class="mfoot">
      ${existing ? `<button type="button" class="danger left" data-act="del-order" data-id="${existing.id}">Löschen</button>` : ''}
      <button type="button" data-close>Abbrechen</button><button class="primary" type="submit">Speichern</button>
    </div>
    </form>`, (root) => {
    const form = $('#order-form', root);
    const syncKind = () => {
      const k = form.kind.value;
      $$('[data-kind]', root).forEach((el) => { el.style.display = el.dataset.kind === k ? '' : 'none'; });
      $$('input[name=kind]', root).forEach((r) => r.parentElement.classList.toggle('on', r.checked));
    };
    syncKind();
    $$('input[name=kind]', root).forEach((r) => r.addEventListener('change', syncKind));
    const refresh = () => { $('#photo-list', root).innerHTML = renderPhotos(); hydrate($('#photo-list', root)); };
    $('#photo-list', root).addEventListener('click', (e) => {
      const b = e.target.closest('[data-rm]');
      if (b) { photos.splice(Number(b.dataset.rm), 1); refresh(); }
    });
    const addFiles = async (files, asImage) => {
      for (const f of files) {
        const blob = asImage ? await resizeImage(f) : f;
        const pid = L.uid('ph');
        await putBlob(pid, blob);
        added.push(pid);
        photos.push({ id: pid, name: f.name, type: asImage ? 'image/jpeg' : (f.type || 'application/octet-stream') });
      }
      refresh();
    };
    $('#photo-cam', root).addEventListener('change', (e) => addFiles([...e.target.files], true));
    $('#photo-add', root).addEventListener('change', (e) => addFiles([...e.target.files], true));
    $('#file-add', root).addEventListener('change', (e) => addFiles([...e.target.files], false));
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(form);
      const data = {
        title: String(fd.get('title')).trim(),
        customer: String(fd.get('customer') || '').trim(),
        contact: String(fd.get('contact') || '').trim(),
        kind: fd.get('kind') === 'eigen' ? 'eigen' : 'modell',
        urls: String(fd.get('urls') || '').split(/\s*\n\s*/).map((s) => s.trim()).filter(Boolean),
        license: fd.get('license') || '',
        measurements: String(fd.get('measurements') || ''),
        quantity: Math.max(1, parseInt(fd.get('quantity'), 10) || 1),
        deadline: fd.get('deadline') || '',
        material: String(fd.get('material') || '').trim(),
        colorWish: String(fd.get('colorWish') || '').trim(),
        colorHex: fd.get('noColor') === 'on' ? '' : L.normHex(fd.get('colorHex')),
        gramsPerPiece: num(fd.get('gramsPerPiece'), 0) || '',
        hoursPerPiece: num(fd.get('hoursPerPiece'), 0) || '',
        status: fd.get('status'),
        price: num(fd.get('price'), 0) || '',
        paid: fd.get('paid') === 'on',
        manualDone: Math.max(0, parseInt(fd.get('manualDone'), 10) || 0),
        notes: String(fd.get('notes') || ''),
        photos,
        updated: new Date().toISOString(),
      };
      if (data.kind === 'eigen' && !data.license) data.license = 'eigen';
      let target;
      if (existing) {
        const removed = (existing.photos || []).filter((p) => !photos.some((x) => x.id === p.id));
        for (const r of removed) await deleteBlob(r.id).catch(() => {});
        Object.assign(existing, data);
        target = existing;
      } else {
        target = { id: L.uid('o'), created: new Date().toISOString(), ...data };
        state.orders.push(target);
      }
      added.length = 0;
      await save();
      render();
      orderDetail(target.id);
    });
    modal().addEventListener('close', async function cleanup() {
      modal().removeEventListener('close', cleanup);
      for (const pid of added) await deleteBlob(pid).catch(() => {});
    });
  });
}

function orderText(o) {
  const pr = L.orderProgress(o, state.prints);
  return [
    `Auftrag: ${o.title}`,
    o.customer && `Kunde: ${o.customer}${o.contact ? ' (' + o.contact + ')' : ''}`,
    `Stückzahl: ${pr.done}/${pr.quantity}`,
    o.material && `Material: ${o.material}${o.colorWish ? ', ' + o.colorWish : ''}`,
    o.deadline && `Termin: ${fmtDate(o.deadline)}`,
    o.price && `Preis: ${L.formatMoney(o.price)}${o.paid ? ' (bezahlt)' : ''}`,
    `Status: ${statusLabel(o.status)}`,
    ...(o.urls || []).map((u) => `Modell: ${u}`),
    o.measurements && `Maße: ${o.measurements}`,
  ].filter(Boolean).join('\n');
}

// ---------- Ansicht: Mehr ----------

function viewMore() {
  const st = state.settings;
  const active = state.spools.filter((s) => !s.archived);
  const total = active.reduce((t, s) => t + rem(s).remaining, 0);
  const value = active.reduce((t, s) => t + rem(s).remaining * L.pricePerGram(s), 0);
  const byMat = {};
  for (const s of active) {
    const m = L.materialBase(s.material) || '?';
    byMat[m] = (byMat[m] || 0) + rem(s).remaining;
  }
  const month = new Date().toISOString().slice(0, 7);
  const usedMonth = state.prints.filter((p) => String(p.date).startsWith(month))
    .reduce((t, p) => t + (p.filaments || []).reduce((a, f) => a + (Number(f.grams) || 0) * (p.status === 'failed' ? (p.progress || 0) / 100 : 1), 0), 0);
  return `
    <div class="stats">
      <div class="card stat"><div class="v">${L.formatGrams(total)}</div><div class="l">Filament auf Lager (${active.length} Rollen)</div></div>
      <div class="card stat"><div class="v">${L.formatMoney(value)}</div><div class="l">Restwert</div></div>
      <div class="card stat"><div class="v">${L.formatGrams(usedMonth)}</div><div class="l">Verbrauch diesen Monat</div></div>
      <div class="card stat"><div class="v">${state.orders.filter((o) => L.OPEN_STATUS.includes(o.status)).length}</div><div class="l">offene Aufträge</div></div>
    </div>
    ${Object.keys(byMat).length ? `<div class="card"><dl class="kv">${Object.entries(byMat).sort((a, b) => b[1] - a[1]).map(([m, g]) => `<dt>${esc(m)}</dt><dd>${L.formatGrams(g)}</dd>`).join('')}</dl></div>` : ''}

    <h2>Einstellungen</h2>
    <form id="settings-form" class="card">
      <div class="row">
        <label class="f">Anzahl Boxen<input name="boxCount" type="number" min="1" max="100" value="${st.boxCount}"></label>
        <label class="f">Rollen pro Box<input name="slotsPerBox" type="number" min="1" max="12" value="${st.slotsPerBox}"></label>
        <label class="f">AMS-Einheiten<input name="amsUnits" type="number" min="0" max="4" value="${st.amsUnits}"></label>
      </div>
      <div class="row">
        <label class="f">Warnen unter (g)<input name="lowThreshold" type="number" min="0" value="${st.lowThreshold}"></label>
        <label class="f">Standard netto (g)<input name="defaultNet" type="number" min="0" value="${st.defaultNet}"></label>
        <label class="f">Standard Leerspule (g)<input name="defaultEmpty" type="number" min="0" value="${st.defaultEmpty}"></label>
      </div>
      <div class="row">
        <label class="f">Maschinenkosten (€/h, Strom + Verschleiß)<input name="hourlyRate" inputmode="decimal" value="${st.hourlyRate}"></label>
        <label class="f">Aufschlag für Preisvorschlag (%)<input name="markup" type="number" min="0" value="${st.markup}"></label>
      </div>
      <p class="muted">Leerspulen-Gewicht: Bambu-Kunststoffspule ca. 250 g, Pappspule ca. 140–180 g – am besten eine leere Spule wiegen.</p>
      <button class="primary">Einstellungen speichern</button>
    </form>

    <h2>Abgleich zwischen Geräten</h2>
    ${syncCard()}

    <h2>Daten</h2>
    <div class="card">
      <p>${meta.url ? 'Die Daten liegen auf diesem Gerät und in deiner Google-Tabelle.' : 'Ohne Abgleich liegen alle Daten nur auf diesem Gerät (im Browser).'} Eine Sicherungsdatei (inkl. Fotos) ist trotzdem sinnvoll – z. B. vor größeren Änderungen.</p>
      <div class="row">
        <button data-act="backup">⬇️ Sicherung speichern</button>
        <label class="btn">⬆️ Sicherung laden<input type="file" id="restore" accept=".json,application/json" hidden></label>
      </div>
    </div>

    <h2>Hilfe</h2>
    <div class="card help">
      <p><a href="#" data-act="import-help">Druckhistorie aus Bambu Studio einlesen</a></p>
      <p><b>Filament finden:</b> Im Reiter Filament einfach tippen, z. B. „petg schwarz“ – Grundfarben werden auch ohne Farbnamen erkannt. Oder mit dem Farbwähler die ähnlichste Rolle suchen. Das grüne Feld zeigt Box und Platz.</p>
      <p><b>AMS:</b> „Ins AMS legen“ merkt sich den Box-Platz. „Zurück in Box …“ legt die Rolle wieder an ihren Platz.</p>
      <p><b>Aufträge:</b> Beim Import einer Druckdatei den Auftrag und die Stückzahl wählen – dann zählt der Fortschritt automatisch hoch und die Materialkosten werden berechnet.</p>
    </div>
    <p class="muted" style="text-align:center">Filament-Manager v2</p>`;
}

function syncCard() {
  if (!meta.url) {
    return `<form id="sync-form" class="card">
      <p>Mit einer eigenen <b>Google-Tabelle</b> als Server siehst du auf PC und Handy denselben Stand – inklusive Fotos (in deinem Google Drive).
        <a href="#" data-act="sync-help">Einrichtung (ca. 10 Minuten)</a></p>
      <label class="f">Web-App-Adresse<input name="url" placeholder="https://script.google.com/macros/s/…/exec" autocomplete="off"></label>
      <label class="f">Schlüssel (aus dem Blatt „Einrichtung“)<input name="key" autocomplete="off"></label>
      <button class="primary">Verbinden</button>
    </form>`;
  }
  const dirty = S.planPush(state, meta).length;
  return `<div class="card">
    <p>☁️ Verbunden${meta.sheetName ? ` mit <b>${esc(meta.sheetName)}</b>` : ''}.</p>
    <dl class="kv">
      <dt>Zuletzt</dt><dd>${meta.lastSync ? fmtDateTime(meta.lastSync) : 'noch nie'}</dd>
      <dt>Offen</dt><dd>${dirty ? `${dirty} Änderung(en)` : 'nichts'}</dd>
      ${meta.lastError ? `<dt>Fehler</dt><dd style="color:var(--danger)">${esc(meta.lastError)}</dd>` : ''}
    </dl>
    <p class="muted">Gleicht automatisch ab: beim Öffnen, nach Änderungen und alle 1½ Minuten. Ohne Internet arbeitest du normal weiter.</p>
    <div class="row">
      <button class="primary" data-act="sync-now" ${syncUi.busy ? 'disabled' : ''}>${syncUi.busy ? 'Gleiche ab …' : 'Jetzt abgleichen'}</button>
      <button data-act="sync-disconnect">Trennen</button>
    </div>
  </div>`;
}

function syncHelp() {
  openModal(`${head('Google-Tabelle einrichten')}
    <div class="mbody help">
      <ol>
        <li>Auf <a href="https://sheets.google.com" target="_blank" rel="noopener">sheets.google.com</a> eine <b>leere Tabelle</b> anlegen, z. B. „Filament-Manager“.</li>
        <li>Menü <b>Erweiterungen → Apps Script</b>. Den vorhandenen Text löschen und den Inhalt von <code>filament_manager/apps-script/Code.gs</code> einfügen. Speichern (Disketten-Symbol).</li>
        <li>Oben die Funktion <b>setup</b> auswählen → <b>Ausführen</b>. Berechtigung erlauben (Konto wählen → „Erweitert“ → „… öffnen (unsicher)“ → Zulassen – das ist normal bei eigenen Skripten).</li>
        <li><b>Bereitstellen → Neue Bereitstellung</b> → Zahnrad → <b>Web-App</b>. „Ausführen als: <b>Ich</b>“, „Zugriff: <b>Jeder</b>“ → Bereitstellen. Die <b>Web-App-URL</b> kopieren.</li>
        <li>In der Tabelle steht im Blatt <b>Einrichtung</b> der <b>Schlüssel</b>.</li>
        <li>Adresse und Schlüssel hier eintragen → <b>Verbinden</b>. Auf jedem Gerät (PC, Handy) einmal.</li>
      </ol>
      <p><b>Sicherheit:</b> Ohne den Schlüssel kann niemand lesen oder schreiben. Gib ihn nicht weiter.</p>
      <p><b>Tabelle:</b> Reiter Rollen, Drucke, Auftraege zeigen deinen Stand zum Ansehen/Filtern. Bitte dort nichts ändern – Änderungen in der App machen.</p>
      <p><b>Fotos & Dateien</b> liegen im Drive-Ordner „Filament-Manager Fotos & Dateien“.</p>
      <p><b>Code geändert?</b> Nach einer neuen Version von Code.gs: Bereitstellen → Bereitstellungen verwalten → Bearbeiten → Version „Neu“ – dann bleibt die Adresse gleich.</p>
    </div>`);
}

// ---------- Ereignisse ----------

document.addEventListener('click', async (e) => {
  const tabBtn = e.target.closest('#tabs button');
  if (tabBtn) return setTab(tabBtn.dataset.tab);
  if (e.target.closest('[data-close]')) return closeModal();
  const el = e.target.closest('[data-act]');
  if (!el) return;
  const act = el.dataset.act;
  const id = el.dataset.id;
  switch (act) {
    case 'clear-q': ui.q = ''; render(); $('#q').focus(); break;
    case 'clear-color': ui.color = ''; render(); break;
    case 'mat': ui.material = ui.material === el.dataset.m ? '' : el.dataset.m; render(); break;
    case 'low': ui.low = !ui.low; render(); break;
    case 'archived': ui.archived = !ui.archived; render(); break;
    case 'new-spool': spoolForm(); break;
    case 'spool': spoolDetail(id); break;
    case 'edit-spool': spoolForm(id); break;
    case 'dup-spool': spoolForm(null, spoolById(id)); break;
    case 'weigh': weighDialog(id); break;
    case 'del-spool': {
      const s = spoolById(id);
      const used = L.spoolUsages(id, state.prints).length;
      if (!confirm(`„${L.spoolTitle(s)}“ löschen?${used ? `\n${used} Drucke verlieren die Zuordnung. Besser „Aufgebraucht“ markieren.` : ''}`)) return;
      state.spools = state.spools.filter((x) => x.id !== id);
      for (const p of state.prints) for (const f of p.filaments || []) if (f.spoolId === id) f.spoolId = '';
      await save(); closeModal(); render(); break;
    }
    case 'show-box': ui.highlightBox = Number(el.dataset.box); ui.highlightSpool = id; closeModal(); setTab('boxen'); break;
    case 'to-ams': if (state.settings.amsUnits > 0) amsDialog(id); else toast('Keine AMS-Einheit eingestellt (Mehr → Einstellungen)'); break;
    case 'pick-ams': await pickAms(id, Number(el.dataset.u), Number(el.dataset.p)); break;
    case 'to-home': { const s = spoolById(id); const h = s.homeLocation; s.homeLocation = null; s.location = h; await save(); render(); spoolDetail(id); break; }
    case 'to-free-box': {
      const s = spoolById(id);
      const free = L.firstFreeSlot(state.spools, state.settings, id);
      if (!free) { toast('Alle Boxen sind voll'); return; }
      s.location = free; s.homeLocation = null; await save(); render(); spoolDetail(id); toast(L.locationLabel(free)); break;
    }
    case 'box-edit': boxEdit(Number(el.dataset.box)); break;
    case 'slot-empty': slotEmptyDialog(el.dataset.kind, Number(el.dataset.a), Number(el.dataset.p)); break;
    case 'new-spool-at': {
      const loc = JSON.parse(el.dataset.loc);
      spoolForm();
      const sel = $('select[name=loc]');
      if (sel) sel.value = loc.kind === 'box' ? `box:${loc.box}:${loc.slot}` : `ams:${loc.unit}:${loc.slot}`;
      break;
    }
    case 'move-here': {
      const s = spoolById(id);
      const loc = JSON.parse(el.dataset.loc);
      if (s.location && s.location.kind === 'box' && loc.kind !== 'box') s.homeLocation = s.location;
      if (loc.kind === 'box') s.homeLocation = null;
      s.location = loc;
      await save(); closeModal(); render(); toast(`${L.spoolTitle(s)} → ${L.locationLabel(loc)}`); break;
    }
    case 'print': printEdit(id); break;
    case 'manual-print': printEdit(null); break;
    case 'del-print': {
      if (!confirm('Druck löschen? Der Verbrauch wird den Rollen wieder gutgeschrieben.')) return;
      const p = state.prints.find((x) => x.id === id);
      if (p && p.thumbId) await deleteBlob(p.thumbId).catch(() => {});
      state.prints = state.prints.filter((x) => x.id !== id);
      await save(); closeModal(); render(); break;
    }
    case 'import-help': e.preventDefault(); importHelp(); break;
    case 'ofilter': ui.orderFilter = el.dataset.f; render(); break;
    case 'new-order': orderForm(); break;
    case 'order': orderDetail(id); break;
    case 'edit-order': orderForm(id); break;
    case 'order-print': {
      const o = orderById(id);
      printEdit(null, { orderId: id, name: o.title, pieces: L.orderProgress(o, state.prints).open || 1 });
      break;
    }
    case 'set-status': { const o = orderById(id); o.status = el.dataset.s; o.updated = new Date().toISOString(); await save(); render(); orderDetail(id); break; }
    case 'del-order': {
      const o = orderById(id);
      if (!confirm(`Auftrag „${o.title}“ löschen? Die Drucke bleiben erhalten.`)) return;
      for (const ph of o.photos || []) await deleteBlob(ph.id).catch(() => {});
      for (const p of state.prints) if (p.orderId === id) p.orderId = '';
      state.orders = state.orders.filter((x) => x.id !== id);
      await save(); closeModal(); render(); break;
    }
    case 'copy-order': {
      const text = orderText(orderById(id));
      try { await navigator.clipboard.writeText(text); toast('Kopiert'); } catch { prompt('Text:', text); }
      break;
    }
    case 'zoom': openModal(`${head('Foto')}<div class="lightbox"><img src="${el.src}" alt=""></div>`); break;
    case 'download': {
      e.preventDefault();
      const b = await getBlob(el.dataset.blobid);
      if (b) downloadBlob(b, el.dataset.name);
      break;
    }
    case 'sync-now': syncNow({ manual: true }); break;
    case 'sync-disconnect': {
      if (!confirm('Abgleich auf diesem Gerät beenden? Die Daten hier und in der Tabelle bleiben erhalten.')) return;
      meta = S.emptyMeta();
      await saveMeta(meta);
      render();
      break;
    }
    case 'sync-help': e.preventDefault(); syncHelp(); break;
    case 'backup': {
      const text = await exportBackup(state);
      downloadBlob(new Blob([text], { type: 'application/json' }), `filament-sicherung-${today()}.json`);
      break;
    }
    default: break;
  }
});

function downloadBlob(blob, name) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name || 'datei';
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
}

document.addEventListener('input', (e) => {
  if (e.target.id === 'q') {
    ui.q = e.target.value;
    const pos = e.target.selectionStart;
    render();
    const q = $('#q');
    q.focus();
    q.setSelectionRange(pos, pos);
  }
});

document.addEventListener('change', async (e) => {
  const t = e.target;
  if (t.id === 'colorpick') { ui.color = L.normHex(t.value); render(); }
  if (t.id === 'import-files' && t.files.length) { await handleFiles([...t.files]); t.value = ''; }
  if (t.id === 'restore' && t.files[0]) {
    if (!confirm('Sicherung laden? Die aktuellen Daten auf diesem Gerät werden ersetzt.' + (meta.url ? '\n\nAchtung: Der Abgleich ist aktiv – der Stand der Sicherung wird danach auch in die Google-Tabelle übertragen.' : ''))) { t.value = ''; return; }
    try {
      state = await importBackup(await t.files[0].text());
      urlCache.clear();
      if (meta.url && S.stamp(state, meta)) { await saveMeta(meta); scheduleSync(500); }
      render();
      toast('Sicherung geladen');
    } catch (err) {
      alert('Fehler: ' + err.message);
    }
    t.value = '';
  }
});

document.addEventListener('submit', async (e) => {
  if (e.target.id === 'sync-form') {
    e.preventDefault();
    const btn = $('button', e.target);
    btn.disabled = true;
    btn.textContent = 'Verbinde …';
    try {
      await connectSync(e.target.url.value, e.target.key.value);
      render();
    } catch (err) {
      alert(err.message);
      btn.disabled = false;
      btn.textContent = 'Verbinden';
    }
    return;
  }
  if (e.target.id !== 'settings-form') return;
  e.preventDefault();
  const fd = new FormData(e.target);
  const s = state.settings;
  s.boxCount = Math.max(1, parseInt(fd.get('boxCount'), 10) || 1);
  s.slotsPerBox = Math.max(1, parseInt(fd.get('slotsPerBox'), 10) || 4);
  s.amsUnits = Math.max(0, parseInt(fd.get('amsUnits'), 10) || 0);
  s.lowThreshold = num(fd.get('lowThreshold'), 150);
  s.defaultNet = num(fd.get('defaultNet'), 1000);
  s.defaultEmpty = num(fd.get('defaultEmpty'), 250);
  s.hourlyRate = num(fd.get('hourlyRate'), 0);
  s.markup = num(fd.get('markup'), 0);
  await save();
  render();
  toast('Einstellungen gespeichert');
});

// Drag & Drop überall
let dragDepth = 0;
window.addEventListener('dragenter', (e) => { if ([...(e.dataTransfer.types || [])].includes('Files')) { dragDepth++; document.body.classList.add('dragging'); } });
window.addEventListener('dragleave', () => { dragDepth = Math.max(0, dragDepth - 1); if (!dragDepth) document.body.classList.remove('dragging'); });
window.addEventListener('dragover', (e) => e.preventDefault());
window.addEventListener('drop', async (e) => {
  e.preventDefault();
  dragDepth = 0;
  document.body.classList.remove('dragging');
  const files = [...(e.dataTransfer.files || [])];
  if (!files.length) return;
  if (ui.tab !== 'drucke') setTab('drucke');
  await handleFiles(files);
});

modal().addEventListener('click', (e) => { if (e.target === modal()) closeModal(); });

// ---------- Start ----------

(async function start() {
  state = await loadState();
  meta = { ...S.emptyMeta(), ...((await loadMeta()) || {}) };
  try { ui.tab = localStorage.getItem('fm-tab') || 'filament'; } catch { /* egal */ }
  if (!TITLES[ui.tab]) ui.tab = 'filament';
  render();
  if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {});
  if (meta.url) {
    syncNow();
    setInterval(() => { if (document.visibilityState === 'visible') syncNow(); }, 90_000);
  }
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') scheduleSync(300); });
  window.addEventListener('online', () => scheduleSync(300));
  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
})();
