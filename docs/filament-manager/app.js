import * as L from './logic.js';
import { loadState, saveState, putBlob, getBlob, deleteBlob, exportBackup, importBackup, loadMeta, saveMeta } from './db.js';
import { parseFile, analyzeModelFile } from './importer.js';
import * as M from './mesh.js';
import { buildDocPdf, docFileName } from './pdfdoc.js';
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
      let b = await getBlob(id).catch(() => null);
      if (!b && meta.url && navigator.onLine) {
        // noch nicht abgeglichen (z. B. Vorschaubild aus der Bambu-Cloud) → direkt vom Server holen
        try {
          const r = await S.makeCaller(meta.url, meta.key)({ a: 'get', id });
          if (r && r.ok) { b = b64ToBlob(r.b64, r.type); await putBlob(id, b); meta.blobs[id] = 1; }
        } catch { /* offline */ }
      }
      urlCache.set(id, b ? URL.createObjectURL(b) : '');
    }
    const url = urlCache.get(id);
    if (url) img.src = url;
    else img.replaceWith(Object.assign(document.createElement('div'), { className: img.className || 'thumb', textContent: '🧊' }));
  }
}

// ---------- Dialog ----------

const modal = () => $('#modal');
let modalDirty = false; // in einem Formular des Fensters wurde etwas eingegeben
function openModal(html, onMount) {
  $('#modal-body').innerHTML = html;
  modalDirty = false;
  if (!modal().open) modal().showModal();
  modal().scrollTop = 0;
  hydrate($('#modal-body'));
  if (onMount) onMount($('#modal-body'));
}
function closeModal() {
  modalDirty = false;
  if (modal().open) modal().close();
  $('#modal-body').innerHTML = '';
}
// Schließen auf Wunsch (✕, Abbrechen, Esc, Android-Zurück): bei Eingaben erst nachfragen
function requestClose() {
  if (modalDirty && !confirm('Eingaben verwerfen?')) return false;
  closeModal();
  return true;
}
// Android-Zurück-Taste (MainActivity): true = Fenster war offen und wurde behandelt
window.fmBack = () => {
  if (!modal().open) return false;
  requestClose();
  return true;
};
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
  const nIn = inboxDrafts().length;
  const tb = $('#tabs [data-tab=drucke]');
  let cnt = $('.cnt', tb);
  if (!cnt) { cnt = document.createElement('i'); cnt.className = 'cnt'; tb.appendChild(cnt); }
  cnt.textContent = nIn || '';
  cnt.hidden = !nIn;
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
  const inbox = inboxDrafts();
  if (inbox.length) {
    html = `<div class="card inbox">
      <div><b>📥 ${inbox.length} neue${inbox.length === 1 ? 'r' : ''} Druck${inbox.length === 1 ? '' : 'e'} vom Drucker</b><br>
      <small class="muted">aus der Bambu-Cloud: ${inbox.slice(0, 3).map((d) => esc(d.name)).join(', ')}${inbox.length > 3 ? ' …' : ''}</small></div>
      <button class="primary" data-act="inbox-open">Prüfen & buchen</button>
    </div>` + html;
  }
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
  prepareDrafts(drafts);
  importDialog(drafts, errors);
}

function prepareDrafts(drafts) {
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
  return drafts;
}

// ---------- Eingang: neue Drucke aus der Bambu-Cloud ----------

function inboxDrafts() {
  const items = (meta.inbox || []).filter((t) => !(meta.inboxDone || []).includes(String(t.id)));
  const drafts = L.parseCloudTasks({ hits: items });
  const known = new Set(state.prints.map((p) => p.fingerprint));
  return drafts.filter((d) => !known.has(d.fingerprint));
}

async function markInboxDone(ids) {
  meta.inboxDone = [...new Set([...(meta.inboxDone || []), ...ids.map(String)])];
  meta.inbox = (meta.inbox || []).filter((t) => !meta.inboxDone.includes(String(t.id)));
  await saveMeta(meta);
  scheduleSync(1000);
}

function openInbox() {
  const drafts = prepareDrafts(inboxDrafts());
  if (!drafts.length) { toast('Keine neuen Drucke'); return; }
  importDialog(drafts, [], { inbox: true });
}

function importDialog(drafts, errors, opts = {}) {
  const thumbUrls = drafts.map((d) => (d.thumb ? URL.createObjectURL(d.thumb) : ''));
  openModal(`
    <form id="import-form">
    ${head(opts.inbox ? `${drafts.length} neue${drafts.length > 1 ? '' : 'r'} Druck${drafts.length > 1 ? 'e' : ''} vom Drucker` : `${drafts.length} Druck${drafts.length > 1 ? 'e' : ''} importieren`)}
    <div class="mbody">
      ${errors.length ? `<div class="card" style="background:var(--warn-soft)"><b>Nicht gelesen:</b><br>${errors.map(esc).join('<br>')}</div>` : ''}
      <p class="muted">Prüfe die Rollen-Zuordnung. Vorschläge kommen aus Material, Farbe und AMS-Slot.${opts.inbox ? ' Nicht angehakte Drucke werden verworfen (z. B. Testdrucke).' : ''}</p>
      ${drafts.map((d, i) => `
        <div class="card draft ${d.include ? '' : 'off'}" data-draft="${i}">
          <div class="row" style="align-items:center">
            <label class="check shrink"><input type="checkbox" name="d${i}_inc" ${d.include ? 'checked' : ''}> übernehmen</label>
            ${thumbUrls[i] ? `<img class="thumb shrink" src="${thumbUrls[i]}" alt="">` : d.thumbId ? `<img class="thumb shrink" data-blob="${esc(d.thumbId)}" alt="">` : ''}
            <div>${d.duplicate ? '<span class="badge warn">schon importiert</span> ' : ''}${d.statusUnsure ? '<span class="badge warn">Ergebnis prüfen</span> ' : ''}<small>${esc(d.source)} · ${L.formatDuration(d.durationS)}${d.device ? ' · ' + esc(d.device) : ''}</small></div>
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
        } else if (d.thumbId) {
          p.thumbId = d.thumbId;
        }
        if (d.device) p.device = d.device;
        state.prints.push(p);
        orderIds.push(p.orderId);
        n++;
      }
      thumbUrls.forEach((u) => u && URL.revokeObjectURL(u));
      if (opts.inbox) await markInboxDone(drafts.map((d) => d.taskId).filter(Boolean));
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
      <h3>Am bequemsten: automatisch aus der Bambu-Cloud</h3>
      <p>Mit eingerichtetem Abgleich (Google-Tabelle) unter <b>Mehr → Bambu-Cloud</b> anmelden. Dein Google-Script holt dann alle 30 Minuten neue Drucke; hier erscheint „Neue Drucke vom Drucker“ zum Bestätigen.</p>
      <h3>Variante C: Cloud-Historie als Datei</h3>
      <p>Das Hilfsskript <code>tools/bambu_cloud_export.py</code> lädt die Historie als <code>bambu_history.json</code> herunter (Login mit deinem Bambu-Konto, nur auf deinem PC). Die JSON-Datei hier importieren.</p>
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
  // Abgeleitete Werte (Zeilen, Gramm, Preis) mit aktuellen Rollen/Preisen neu rechnen
  const before = JSON.stringify([o.lines, o.gramsPerPiece, o.hoursPerPiece, o.price]);
  const pc = refreshDerived(o);
  if (JSON.stringify([o.lines, o.gramsPerPiece, o.hoursPerPiece, o.price]) !== before) save();
  const idx = L.ORDER_STATUS.findIndex((s) => s.id === o.status);
  const images = (o.photos || []).filter((p) => /^image\//.test(p.type || 'image/') && !MODEL_RE.test(p.name || ''));
  const files = (o.photos || []).filter((p) => !images.includes(p));
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
        <dt>Material</dt><dd>${esc(o.material || '–')} ${o.colorHex ? sw(o.colorHex, 's') : ''} ${esc(o.colorWish || '')}${o.gramsPerPiece ? ` · ${g1(o.gramsPerPiece)} g/Stück` : ''}${o.hoursPerPiece ? ` · ${L.round(o.hoursPerPiece, 1).toLocaleString('de-DE')} h` : ''}</dd>
        <dt>Preis</dt><dd>${o.price ? L.formatMoney(o.price) : '–'}${o.price && !o.priceManual ? ' <small class="muted">(berechnet)</small>' : ''} ${o.price ? (o.paid ? '<span class="badge ok">bezahlt</span>' : '<span class="badge warn">offen</span>') : ''}</dd>
      </dl>
      <div class="bar"><i style="width:${pr.percent}%"></i></div>

      ${(o.urls || []).length ? `<h3>Modell-Links</h3>${o.urls.map((u) => `<div><a href="${esc(safeUrl(u))}" target="_blank" rel="noopener">${esc(L.modelSite(u))}</a> <small class="muted">${esc(u)}</small></div>`).join('')}
        ${o.license ? `<p><small>Lizenz: ${esc((L.LICENSES.find((l) => l.id === o.license) || {}).label)}</small>${o.license === 'nc' && o.price ? ' <span class="badge danger">NC-Lizenz – Verkauf nicht erlaubt!</span>' : ''}</p>` : `<p><small class="muted">Lizenz prüfen: Viele Modelle sind nur für nicht-kommerzielle Nutzung.</small></p>`}` : ''}

      ${o.measurements ? `<h3>Maße & Beschreibung</h3><div class="card pre">${esc(o.measurements)}</div>` : ''}
      ${images.length ? `<h3>Fotos</h3><div class="gallery">${images.map((ph) => `<div class="ph"><img data-blob="${esc(ph.id)}" data-act="zoom" alt=""></div>`).join('')}</div>` : ''}
      ${files.length ? `<h3>Dateien</h3>${files.map((f) => `<div class="filerow"><a href="#" data-act="download" data-blobid="${esc(f.id)}" data-name="${esc(f.name)}">📎 ${esc(f.name)}</a>
        ${f.analysis ? `<small class="muted">${f.analysis.kind === 'sliced' ? 'geslict, exakt' : `${f.analysis.size.map((n) => Math.round(n)).join('×')} mm${M.fitsPrinter(f.analysis.size) ? '' : ' ⚠️ zu groß für P1S'}`}</small>` : ''}</div>`).join('')}` : ''}
      ${o.notes ? `<h3>Notizen</h3><div class="pre">${esc(o.notes)}</div>` : ''}

      ${pc.plan.rows.length ? `<h3>Filament & Rollen</h3><div class="list">${pc.plan.rows.map((r, i) => `
        <div class="card">
          <div>${sw(r.line.colorHex, 's')} <b>${esc(r.line.name || [r.line.material, r.line.colorWish].filter(Boolean).join(' ') || `Zeile ${i + 1}`)}</b>
            · ${esc(r.line.material || '?')} · ${g1(r.perPiece)} g/Stück${r.line.supportGrams ? ` (inkl. ${g1(r.line.supportGrams)} g Stützen)` : ''}
            ${r.line.exact ? '<span class="badge ok">exakt</span>' : r.line.auto ? '<span class="badge info">geschätzt</span>' : ''}</div>
          <div class="meta muted" style="margin-top:4px">Bedarf für ${pc.plan.open} offene Stück: ${L.formatGrams(r.need)}</div>
          <div style="margin-top:4px">${lineSpoolHtml(r)}</div>
          <div class="meta muted">${L.formatMoney(r.pricePerKg)}/kg${r.priceSource === 'avg' ? ' (Ø, Rolle ohne Preis)' : r.priceSource === 'default' ? ' (angenommen – Rollenpreis eintragen)' : ''} · ${L.formatMoney(r.costPiece)} pro Stück</div>
        </div>`).join('')}</div>` : ''}

      <h3>Drucke (${prints.length})</h3>
      ${prints.length ? `<div class="list">${prints.map(printCard).join('')}</div>` : '<p class="muted">Noch keine. Beim Import einer Datei diesen Auftrag wählen.</p>'}
      <p><button class="small" data-act="order-print" data-id="${o.id}">＋ Druck manuell hinzufügen</button></p>

      <h3>Kosten</h3>
      <dl class="kv">
        <dt>Bisher verbraucht</dt><dd>${L.formatGrams(costs.grams)} · ${L.formatMoney(costs.material)} Material${costs.hours ? ` · ${costs.hours} h` : ''}${costs.machine ? ` · ${L.formatMoney(costs.machine)} Maschine` : ''}</dd>
      </dl>
      <h3>Preiskalkulation</h3>
      ${pc.plan.rows.length || o.designHours || o.extraCost ? `<div class="card">${priceHtml(o, pc)}
        ${o.priceManual ? `<p class="muted">Fester Preis ${L.formatMoney(o.price)} gilt (berechnet wären ${L.formatMoney(pc.calc.total)}).</p>` : '<p class="muted">Der Preis wird automatisch mitgeführt. Im Auftrag lässt sich ein fester Preis setzen.</p>'}
      </div>` : '<p class="muted">Lade eine STL/3MF hoch oder trage Filament ein – dann rechnet die App den Preis.</p>'}

      <h3>Angebot & Rechnung</h3>
      ${(o.docs || []).length ? `<div class="list">${o.docs.slice().reverse().map((d) => `<div class="card filerow" style="justify-content:space-between">
          <span>${d.type === 'rechnung' ? '🧾 Rechnung' : '📄 Angebot'} <b>${esc(d.number)}</b> · ${fmtDate(d.date)} · ${L.formatMoney(d.totals.gross)}</span>
          <button class="small" data-act="doc-pdf" data-id="${o.id}" data-n="${esc(d.number)}">PDF</button></div>`).join('')}</div>` : ''}
      <div class="row" style="margin-top:8px">
        <button data-act="doc-new" data-id="${o.id}" data-t="angebot">📄 Angebot erstellen</button>
        <button data-act="doc-new" data-id="${o.id}" data-t="rechnung">🧾 Rechnung erstellen</button>
      </div>
    </div>
    <div class="mfoot">
      <button class="left" data-act="copy-order" data-id="${o.id}">Text kopieren</button>
      <button class="primary" data-act="edit-order" data-id="${o.id}">Bearbeiten</button>
    </div>`);
}

// ---------- Angebot / Rechnung ----------

async function ensureJsPdf() {
  if (window.jspdf) return;
  await new Promise((resolve, reject) => {
    const sc = document.createElement('script');
    sc.src = 'lib/jspdf.umd.min.js';
    sc.onload = resolve;
    sc.onerror = () => reject(new Error('PDF-Bibliothek konnte nicht geladen werden'));
    document.head.appendChild(sc);
  });
}

function addDays(dateStr, days) {
  const d = new Date(dateStr + 'T00:00:00');
  d.setDate(d.getDate() + (Number(days) || 0));
  return d.toISOString().slice(0, 10);
}

function docDialog(orderId, type) {
  const o = orderById(orderId);
  const biz = bizData();
  const pr = L.orderProgress(o, state.prints);
  const op = refreshDerived(o);
  const pp = op.p;
  const pc = op.calc;
  // Rechnung: Positionen des letzten Angebots übernehmen, falls vorhanden
  const lastOffer = (o.docs || []).filter((d) => d.type === 'angebot').pop();
  let lines = type === 'rechnung' && lastOffer ? lastOffer.lines.map((l) => ({ ...l })) : L.docLines(o, pc, pp);
  // fester Preis: Stückpreis so anpassen, dass die Summe stimmt
  if (!(type === 'rechnung' && lastOffer) && o.priceManual && Number(o.price) > 0 && lines.length) {
    const others = lines.slice(1).reduce((t, l) => t + l.qty * l.unit, 0);
    lines[0].unit = L.round(Math.max(0, Number(o.price) - others) / (lines[0].qty || 1), 2);
  }
  if (!lines.length) lines = [{ text: o.title || '3D-Druck', detail: '', qty: pr.quantity, unit: 0 }];
  const isInv = type === 'rechnung';
  const number = isInv ? L.docNumber(biz.invoicePrefix, biz.nextInvoice) : L.docNumber(biz.offerPrefix, biz.nextOffer);
  const missing = [!biz.name && 'Name', !biz.address && 'Anschrift', isInv && !biz.taxId && 'Steuernummer', isInv && !biz.iban && 'IBAN'].filter(Boolean);

  const lineRow = (l, i) => `<div class="docline" data-i="${i}">
      <input name="t" value="${esc(l.text)}" placeholder="Beschreibung">
      <input name="d" value="${esc(l.detail)}" placeholder="Details (optional)" class="muted">
      <div class="row">
        <label class="f">Menge<input name="q" inputmode="decimal" value="${esc(String(l.qty).replace('.', ','))}"></label>
        <label class="f">Einzelpreis €<input name="u" inputmode="decimal" value="${esc(String(l.unit).replace('.', ','))}"></label>
        <button type="button" class="small ghost shrink" data-rmline="${i}" title="Position entfernen">🗑</button>
      </div>
    </div>`;
  const readLines = (root) => $$('.docline', root).map((el) => ({
    text: $('[name=t]', el).value.trim(),
    detail: $('[name=d]', el).value.trim(),
    qty: num($('[name=q]', el).value, 0),
    unit: num($('[name=u]', el).value, 0),
  })).filter((l) => l.text || l.unit);
  const totalsHtml = (ls) => {
    const t = L.docTotals(ls, biz);
    return t.rate
      ? `Netto ${L.formatMoney(t.net)} + ${t.rate} % USt ${L.formatMoney(t.vat)} = <b>${L.formatMoney(t.gross)}</b>`
      : `<b>${L.formatMoney(t.gross)}</b> <small class="muted">(Kleinunternehmer, ohne USt)</small>`;
  };

  openModal(`
    <form id="doc-form">
    ${head(isInv ? 'Rechnung erstellen' : 'Angebot erstellen')}
    <div class="mbody">
      ${missing.length ? `<p class="card" style="background:var(--warn-soft)">Es fehlen noch Absenderangaben: ${missing.join(', ')}. <a href="#" data-act="goto-biz">Unter Mehr → Angebote & Rechnungen eintragen</a></p>` : ''}
      <div class="row">
        <label class="f">Nummer<input name="number" value="${esc(number)}"></label>
        <label class="f">Datum<input type="date" name="date" value="${today()}"></label>
        ${isInv ? `<label class="f">Leistungsdatum<input type="date" name="serviceDate" value="${today()}"></label>` : ''}
      </div>
      <label class="f">Kunde<input name="customer" value="${esc(o.customer)}"></label>
      <label class="f">Anschrift<textarea name="customerAddress" rows="2">${esc(o.customerAddress)}</textarea></label>
      <h3>Positionen</h3>
      <div id="doc-lines">${lines.map(lineRow).join('')}</div>
      <p><button type="button" class="small" id="doc-addline">＋ Position</button></p>
      <p id="doc-totals" style="font-size:16px">${totalsHtml(lines)}</p>
      <label class="f">Zusätzlicher Hinweis (optional)<textarea name="note" rows="2"></textarea></label>
    </div>
    <div class="mfoot"><button type="button" data-close>Abbrechen</button><button class="primary" type="submit">PDF erstellen</button></div>
    </form>`, (root) => {
    const form = $('#doc-form', root);
    const linesEl = $('#doc-lines', root);
    const upd = () => { $('#doc-totals', root).innerHTML = totalsHtml(readLines(root)); };
    form.addEventListener('input', upd);
    $('#doc-addline', root).addEventListener('click', () => {
      linesEl.insertAdjacentHTML('beforeend', lineRow({ text: '', detail: '', qty: 1, unit: 0 }, linesEl.children.length));
    });
    linesEl.addEventListener('click', (e) => {
      const b = e.target.closest('[data-rmline]');
      if (b) { b.closest('.docline').remove(); upd(); modalDirty = true; }
    });
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const ls = readLines(root);
      if (!ls.length) { toast('Mindestens eine Position nötig'); return; }
      const date = form.date.value || today();
      const doc = {
        type, number: form.number.value.trim() || number, date,
        serviceDate: isInv ? (form.serviceDate.value || date) : '',
        dueDate: isInv && biz.payDays ? addDays(date, biz.payDays) : '',
        validUntil: !isInv && biz.offerDays ? addDays(date, biz.offerDays) : '',
        customer: form.customer.value.trim(), customerAddress: form.customerAddress.value.trim(),
        title: o.title, lines: ls, totals: L.docTotals(ls, biz), note: form.note.value.trim(),
        created: new Date().toISOString(),
      };
      try {
        await ensureJsPdf();
        const blob = buildDocPdf(doc, biz);
        o.docs = [...(o.docs || []), doc];
        if (!o.customerAddress && doc.customerAddress) o.customerAddress = doc.customerAddress;
        o.price = doc.totals.gross;
        o.priceManual = true; // vereinbarter Preis
        if (isInv) biz.nextInvoice = (Number(biz.nextInvoice) || 1) + 1;
        else {
          biz.nextOffer = (Number(biz.nextOffer) || 1) + 1;
          if (o.status === 'anfrage') o.status = 'angebot';
        }
        state.settings.biz = biz;
        o.updated = new Date().toISOString();
        await save();
        downloadBlob(blob, docFileName(doc));
        render();
        orderDetail(o.id);
        toast(`${isInv ? 'Rechnung' : 'Angebot'} ${doc.number} erstellt`);
      } catch (err) {
        alert('PDF konnte nicht erstellt werden: ' + err.message);
      }
    });
  });
}

async function docPdfAgain(orderId, number) {
  const o = orderById(orderId);
  const doc = (o.docs || []).find((d) => d.number === number);
  if (!doc) return;
  try {
    await ensureJsPdf();
    downloadBlob(buildDocPdf(doc, bizData()), docFileName(doc));
  } catch (err) { alert(err.message); }
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

// ---------- 3D-Dateien eines Auftrags automatisch auswerten ----------

const MODEL_RE = /\.(stl|3mf|obj)$/i;

function sliceDefaults() {
  return { ...M.DEFAULT_SLICE, ...(state.settings.calc || {}) };
}

/** Datei auswerten; das Ergebnis wird im Auftrag gespeichert (Neuberechnung ohne Datei, auch auf anderen Geräten). */
async function analyzeForOrder(file) {
  const res = await analyzeModelFile(file);
  if (res.kind === 'sliced') {
    const bySlot = new Map();
    let secs = 0, pieces = 0;
    for (const p of res.plates) {
      secs += p.durationS || 0;
      pieces += Math.max(1, (p.objects || []).length);
      for (const f of p.filaments) {
        const cur = bySlot.get(f.slot) || { type: f.type, colorHex: f.colorHex, grams: 0 };
        cur.grams += f.grams;
        bySlot.set(f.slot, cur);
      }
    }
    return {
      kind: 'sliced', plates: res.plates.length, pieces: Math.max(1, pieces), hours: L.round(secs / 3600, 2),
      filaments: [...bySlot.values()].map((f) => ({ ...f, grams: L.round(f.grams, 2) })),
      size: res.stats ? res.stats.size : null,
    };
  }
  const st = res.stats;
  let pieces = 1;
  if (st.parts && st.parts.length > 1) {
    const v = st.parts.map((x) => x.volume);
    if (Math.max(...v) - Math.min(...v) <= Math.max(...v) * 0.01) pieces = v.length; // gleiche Teile = Kopien
  }
  return {
    kind: 'mesh', pieces, volume: st.volume, area: st.area, size: st.size,
    overhangArea: st.overhangArea || 0, supportVolume: st.supportVolume || 0,
  };
}

const baseName = (n) => String(n || '').replace(/\.(gcode\.3mf|3mf|stl|obj)$/i, '');

/**
 * Filament-Zeilen aus den ausgewerteten Dateien + selbst hinzugefügten Zeilen.
 * Bei Datei-Zeilen bleiben Material/Farbe/Rolle erhalten, die man selbst geändert hat.
 */
function buildLines(draft) {
  const slice = { ...sliceDefaults(), ...(draft.slice || {}) };
  const old = new Map((draft.lines || []).map((l) => [l.id, l]));
  const lines = [];
  let hours = 0;
  for (const f of draft.photos || []) {
    const a = f.analysis;
    if (!a) continue;
    if (a.kind === 'sliced') {
      a.filaments.forEach((fil, i) => {
        const id = `f:${f.id}:${i}`;
        const prev = old.get(id) || {};
        lines.push({
          id, src: f.id, auto: true, exact: true,
          name: a.filaments.length > 1 ? `${baseName(f.name)} · Farbe ${i + 1}` : baseName(f.name),
          material: prev.own ? prev.material : L.materialBase(fil.type) || draft.material || '',
          colorHex: prev.own ? prev.colorHex : fil.colorHex || draft.colorHex || '',
          colorWish: prev.own ? prev.colorWish : '',
          own: !!prev.own, spoolId: prev.spoolId || '',
          grams: L.round(fil.grams / a.pieces, 1), supportGrams: 0,
        });
      });
      hours += a.hours / a.pieces;
    } else {
      const id = `f:${f.id}`;
      const prev = old.get(id) || {};
      const material = prev.own ? prev.material : draft.material || 'PLA';
      const e = M.estimateGrams(a, { ...slice, density: L.densityFor(material) });
      lines.push({
        id, src: f.id, auto: true, exact: false, name: baseName(f.name),
        material, colorHex: prev.own ? prev.colorHex : draft.colorHex || '',
        colorWish: prev.own ? prev.colorWish : draft.colorWish || '',
        own: !!prev.own, spoolId: prev.spoolId || '',
        grams: L.round(e.grams / a.pieces, 1), supportGrams: L.round(e.supportGrams / a.pieces, 1),
        supportLevel: e.supportLevel,
      });
      hours += e.hours / a.pieces;
    }
  }
  const fromFiles = lines.length > 0;
  for (const l of draft.lines || []) {
    if (l.auto) continue;
    if (l.id === 'm:alt' && fromFiles) continue; // alte „Gramm pro Stück“ durch die Datei ersetzt
    lines.push(l); // selbst hinzugefügte Zeilen
  }
  // ältere Aufträge: Zeile aus material/gramsPerPiece übernehmen, solange keine Datei da ist
  if (!lines.length && !(draft.lines || []).length && (draft.gramsPerPiece || draft.material)) {
    lines.push({ id: 'm:alt', auto: false, name: '', material: draft.material || '', colorHex: draft.colorHex || '', colorWish: draft.colorWish || '', grams: Number(draft.gramsPerPiece) || 0, supportGrams: 0, spoolId: '' });
  }
  return { lines, hours: L.round(hours, 2) };
}

/** Abgeleitete Werte eines Auftrags neu setzen (Zeilen, Gramm, Stunden, Preis) */
function refreshDerived(o) {
  const { lines, hours } = buildLines(o);
  o.lines = lines;
  o.gramsPerPiece = L.orderGramsPerPiece(o);
  if (!o.hoursManual) o.hoursPerPiece = hours || o.hoursPerPiece || '';
  const pr = L.orderPrice(o, state.spools, state.prints, state.settings);
  if (!o.priceManual) o.price = pr.calc.total || '';
  return pr;
}

function lineSpoolHtml(row) {
  if (row.chosen) return `🎯 ${esc(L.spoolTitle(row.chosen))} · ${locBadge(row.chosen.location)}`;
  if (!row.use.length) return '<span class="badge warn">keine passende Rolle im Lager</span>';
  const parts = row.use.map((u) => `${esc(L.spoolTitle(u.spool))} ${locBadge(u.spool.location)}${row.use.length > 1 ? ` (${g1(u.grams)} g)` : ''}`);
  return `${row.use.length > 1 ? '✂️ aufgeteilt: ' : '✓ '}${parts.join(' + ')}${row.enough ? '' : ` <span class="badge danger">es fehlen ${g1(row.rec.missing)} g</span>`}`;
}

function lineOptions(row) {
  const cands = row.rec.candidates.map((c) => c.spool);
  if (row.chosen && !cands.some((s) => s.id === row.chosen.id)) cands.unshift(row.chosen);
  return `<option value="">Automatisch (Empfehlung)</option>${cands.map((s) => `<option value="${s.id}" ${row.line.spoolId === s.id ? 'selected' : ''}>${esc(L.spoolTitle(s))} · ${L.formatGrams(L.spoolRemaining(s, state.prints).remaining)} · ${esc(L.locationLabel(s.location))}</option>`).join('')}`;
}

function linesHtml(o, pr) {
  const rows = pr.plan.rows;
  if (!rows.length) {
    return `<p class="muted">Noch nichts zu rechnen. Lade oben eine STL/3MF hoch oder füge eine Zeile hinzu.</p>`;
  }
  return rows.map((r, i) => {
    const l = r.line;
    return `<div class="fline" data-line="${esc(l.id)}">
      <div class="fline-head">${sw(l.colorHex, 's')} <b>${esc(l.name || `Farbe/Material ${i + 1}`)}</b>
        ${l.exact ? '<span class="badge ok">exakt (geslict)</span>' : l.auto ? '<span class="badge info">aus Datei geschätzt</span>' : ''}
        ${l.supportLevel === 'needed' ? '<span class="badge warn">Stützen</span>' : l.supportLevel === 'small' ? '<span class="badge info">kleine Überhänge</span>' : ''}
        ${!l.auto ? `<button type="button" class="small ghost" data-rmline="${esc(l.id)}" title="Zeile entfernen">🗑</button>` : ''}</div>
      <div class="row">
        <label class="f">Material<input data-lf="material" list="materials2" value="${esc(l.material)}"></label>
        <label class="f shrink" style="width:64px">Farbe<input type="color" data-lf="colorHex" value="${esc(L.normHex(l.colorHex) || '#888888')}"></label>
        <label class="f">Gramm/Stück<input data-lf="grams" inputmode="decimal" value="${esc(String(l.grams).replace('.', ','))}" ${l.auto ? 'readonly title="aus der Datei berechnet"' : ''}></label>
        ${l.supportGrams ? `<label class="f" style="flex:0 0 90px">Stützen g<input value="${esc(String(l.supportGrams).replace('.', ','))}" readonly></label>` : ''}
      </div>
      <label class="f">Rolle<select data-lf="spoolId">${lineOptions(r)}</select></label>
      <div class="muted small-line">${lineSpoolHtml(r)} · ${L.formatMoney(r.pricePerKg)}/kg${r.priceSource === 'avg' ? ' (Ø, Rolle ohne Preis)' : r.priceSource === 'default' ? ' (angenommen)' : ''} · ${L.formatMoney(r.costPiece)} pro Stück</div>
    </div>`;
  }).join('');
}

function priceHtml(o, pr) {
  const c = pr.calc, p = pr.p;
  const ust = bizData().vatMode === 'ust';
  return `<dl class="kv">
    <dt>Material</dt><dd>${g1(pr.plan.gramsPerPiece)} g = ${L.formatMoney(c.materialPiece)} pro Stück</dd>
    ${c.machinePiece ? `<dt>Maschine</dt><dd>${L.round(o.hoursPerPiece, 2).toLocaleString('de-DE')} h × ${L.formatMoney(p.hourlyRate)} = ${L.formatMoney(c.machinePiece)} pro Stück</dd>` : ''}
    <dt>Marge</dt><dd>${L.round(p.markup, 1).toLocaleString('de-DE')} % → <b>${L.formatMoney(c.unit)}</b> pro Stück × ${c.qty} = ${L.formatMoney(c.pieces)}</dd>
    ${c.labor ? `<dt>Arbeit</dt><dd>${L.round(o.designHours, 2).toLocaleString('de-DE')} h × ${L.formatMoney(p.laborRate)} = ${L.formatMoney(c.labor)}</dd>` : ''}
    ${c.extras ? `<dt>Versand/Sonst.</dt><dd>${L.formatMoney(c.extras)}</dd>` : ''}
    ${c.minFill ? `<dt>Mindestpreis</dt><dd>+ ${L.formatMoney(c.minFill)}</dd>` : ''}
    <dt>Berechnet</dt><dd><b style="font-size:18px">${L.formatMoney(c.total)}</b>${ust ? ' netto' : ''} · Gewinn ${L.formatMoney(c.profit)}</dd>
    ${pr.manual ? `<dt>Fester Preis</dt><dd><b>${L.formatMoney(pr.total)}</b></dd>` : ''}
  </dl>`;
}

function orderForm(id) {
  const existing = id ? orderById(id) : null;
  const draft = existing ? JSON.parse(JSON.stringify(existing)) : {
    kind: 'modell', status: 'anfrage', quantity: 1, urls: [], photos: [], lines: [], slice: {},
    created: new Date().toISOString(),
  };
  draft.photos = draft.photos || [];
  draft.slice = { ...sliceDefaults(), ...(draft.slice || {}) };
  const added = [];
  const customers = state.customers || [];
  const pr0 = L.pricingFor(state.settings, null);

  const filesHtml = () => draft.photos.map((ph, i) => {
    const a = ph.analysis;
    const info = a ? (a.kind === 'sliced'
      ? `geslict · ${a.filaments.length} Farbe${a.filaments.length > 1 ? 'n' : ''}`
      : `${a.size.map((n) => Math.round(n)).join('×')} mm${M.fitsPrinter(a.size) ? '' : ' ⚠️ zu groß für P1S'}`) : '';
    return /^image\//.test(ph.type || 'image/') && !MODEL_RE.test(ph.name || '')
      ? `<div class="ph"><img data-blob="${esc(ph.id)}" alt=""><button type="button" class="x" data-rm="${i}">✕</button></div>`
      : `<div class="ph card filecard">${MODEL_RE.test(ph.name) ? '🧊' : '📎'} ${esc(ph.name)}${info ? `<br><small class="muted">${esc(info)}</small>` : ''}<button type="button" class="x" data-rm="${i}">✕</button></div>`;
  }).join('');

  openModal(`
    <form id="order-form" autocomplete="off">
    ${head(existing ? 'Auftrag bearbeiten' : 'Neuer Auftrag')}
    <div class="mbody">
      <label class="f">Was soll gedruckt werden?<input name="title" value="${esc(draft.title)}" required placeholder="z. B. Ersatz-Knopf Spülmaschine"></label>
      <div class="row">
        <label class="f">Kunde<input name="customer" list="customers" value="${esc(draft.customer)}" placeholder="Name – gespeicherte werden vorgeschlagen"></label>
        <label class="f" style="flex:0 0 80px">Stück<input name="quantity" type="number" min="1" value="${esc(draft.quantity || 1)}"></label>
        <label class="f" style="flex:0 0 150px">Termin<input name="deadline" type="date" value="${esc(draft.deadline || '')}"></label>
      </div>
      <datalist id="customers">${customers.map((c) => `<option value="${esc(c.name)}">`).join('')}</datalist>
      <div class="chips">
        <label class="chip ${draft.kind === 'modell' ? 'on' : ''}"><input type="radio" name="kind" value="modell" ${draft.kind === 'modell' ? 'checked' : ''} hidden> 🌐 Modell aus dem Netz</label>
        <label class="chip ${draft.kind === 'eigen' ? 'on' : ''}"><input type="radio" name="kind" value="eigen" ${draft.kind === 'eigen' ? 'checked' : ''} hidden> ✏️ Selbst konstruieren</label>
      </div>
      <label class="f" data-kind="modell">Link(s) zum Modell<textarea name="urls" rows="2" placeholder="https://makerworld.com/…">${esc((draft.urls || []).join('\n'))}</textarea></label>
      <label class="f" data-kind="eigen">Maße & Beschreibung<textarea name="measurements" rows="3" placeholder="z. B. Innen-Ø 12 mm, Länge 40 mm, Loch für M3">${esc(draft.measurements)}</textarea></label>
      <div class="row">
        <label class="f">Material<input name="material" list="materials2" value="${esc(draft.material)}" placeholder="PLA"></label>
        <label class="f">Farbwunsch<input name="colorWish" value="${esc(draft.colorWish)}" placeholder="z. B. schwarz matt"></label>
        <label class="f shrink" style="width:64px">Farbe<input type="color" name="colorHex" value="${esc(L.normHex(draft.colorHex) || '#888888')}"></label>
      </div>
      <label class="check"><input type="checkbox" name="noColor" ${draft.colorHex ? '' : 'checked'}> Farbe egal</label>
      <datalist id="materials2">${MATERIALS.map((b) => `<option value="${esc(b)}">`).join('')}</datalist>

      <div class="dropzone" id="order-drop">
        <div><b>Fotos & Dateien</b> <small class="muted">– STL/3MF/OBJ werden automatisch berechnet, auch mehrere Teile/Farben</small></div>
        <div class="gallery" id="photo-list">${filesHtml()}</div>
        <div class="row">
          <label class="btn">📷 Foto<input type="file" accept="image/*" capture="environment" id="photo-cam" hidden></label>
          <label class="btn">📎 Dateien / Bilder<input type="file" multiple id="file-add" hidden></label>
        </div>
        <p id="file-msg" class="muted" hidden></p>
      </div>

      <details class="sect" id="sect-druck">
        <summary>🧵 Druck & Filament <span class="sum" id="sum-druck"></span></summary>
        <div id="lines-area"></div>
        <p><button type="button" class="small" id="add-line">＋ Farbe / Material</button></p>
        <div class="row">
          <label class="f">Infill %<input name="s_infill" type="number" min="0" max="100" value="${esc(draft.slice.infill)}"></label>
          <label class="f">Wände<input name="s_walls" type="number" min="1" max="10" value="${esc(draft.slice.walls)}"></label>
          <label class="f">Zuschlag %<input name="s_extra" type="number" min="0" max="200" value="${esc(draft.slice.extra)}"></label>
          <label class="f">Stützen<select name="s_supports">
            <option value="auto" ${draft.slice.supports === 'auto' ? 'selected' : ''}>automatisch</option>
            <option value="on" ${draft.slice.supports === 'on' ? 'selected' : ''}>immer</option>
            <option value="off" ${draft.slice.supports === 'off' ? 'selected' : ''}>keine</option>
          </select></label>
        </div>
        <div class="row">
          <label class="f">Druckzeit pro Stück (h)<input name="hoursPerPiece" inputmode="decimal" value="${esc(String(draft.hoursPerPiece || '').replace('.', ','))}" placeholder="automatisch"></label>
          <label class="check shrink" style="margin-top:22px"><input type="checkbox" name="hoursManual" ${draft.hoursManual ? 'checked' : ''}> selbst festgelegt</label>
        </div>
        <p class="muted">Schätzung aus STL: Wände + Infill + Zuschlag; Stützen werden aus Überhängen erkannt (Ausrichtung wie in der Datei). Geslicte 3MF aus Bambu Studio sind exakt.</p>
      </details>

      <details class="sect" id="sect-preis">
        <summary>💶 Preis & Status <span class="sum" id="sum-preis"></span></summary>
        <div id="price-area"></div>
        <div class="row">
          <label class="f">Arbeitszeit (h)<input name="designHours" inputmode="decimal" value="${esc(String(draft.designHours ?? '').replace('.', ','))}" placeholder="z. B. Konstruktion"></label>
          <label class="f">Versand / Sonstiges (€)<input name="extraCost" inputmode="decimal" value="${esc(String(draft.extraCost ?? '').replace('.', ','))}"></label>
        </div>
        <div class="row">
          <label class="f">Marge %<input name="p_markup" inputmode="decimal" value="${esc((draft.pricing || {}).markup ?? '')}" placeholder="${esc(pr0.markup)}"></label>
          <label class="f">Stundensatz €<input name="p_laborRate" inputmode="decimal" value="${esc((draft.pricing || {}).laborRate ?? '')}" placeholder="${esc(pr0.laborRate)}"></label>
          <label class="f">Maschine €/h<input name="p_hourlyRate" inputmode="decimal" value="${esc((draft.pricing || {}).hourlyRate ?? '')}" placeholder="${esc(pr0.hourlyRate)}"></label>
        </div>
        <div class="row">
          <label class="check shrink"><input type="checkbox" name="priceManual" ${draft.priceManual ? 'checked' : ''}> fester Preis</label>
          <label class="f">Preis (€)<input name="price" inputmode="decimal" value="${esc(draft.priceManual ? String(draft.price ?? '').replace('.', ',') : '')}" placeholder="automatisch"></label>
        </div>
        <div class="row">
          <label class="f">Status<select name="status">${L.ORDER_STATUS.map((s) => `<option value="${s.id}" ${draft.status === s.id ? 'selected' : ''}>${esc(s.label)}</option>`).join('')}</select></label>
          <label class="check shrink" style="margin-top:22px"><input type="checkbox" name="paid" ${draft.paid ? 'checked' : ''}> bezahlt</label>
        </div>
      </details>

      <details class="sect" id="sect-kunde">
        <summary>👤 Kunde & Notizen <span class="sum" id="sum-kunde"></span></summary>
        <label class="f">Kontakt<input name="contact" value="${esc(draft.contact)}" placeholder="Telefon / E-Mail"></label>
        <label class="f">Anschrift (für Angebot/Rechnung)<textarea name="customerAddress" rows="2" placeholder="Straße Nr.&#10;PLZ Ort">${esc(draft.customerAddress)}</textarea></label>
        <label class="f" data-kind="modell">Lizenz des Modells<select name="license">${L.LICENSES.map((l) => `<option value="${l.id}" ${draft.license === l.id ? 'selected' : ''}>${esc(l.label)}</option>`).join('')}</select></label>
        <label class="f">Notizen<textarea name="notes" rows="2">${esc(draft.notes)}</textarea></label>
        <label class="f">Zusätzlich fertig (ohne importierten Druck)<input name="manualDone" type="number" min="0" value="${esc(draft.manualDone || 0)}"></label>
      </details>
    </div>
    <div class="mfoot">
      ${existing ? `<button type="button" class="danger left" data-act="del-order" data-id="${existing.id}">Löschen</button>` : ''}
      <button type="button" data-close>Abbrechen</button><button class="primary" type="submit">${existing ? 'Speichern' : 'Anlegen'}</button>
    </div>
    </form>`, (root) => {
    const form = $('#order-form', root);
    const val = (n) => (form[n] ? form[n].value : '');

    // Formular → draft (alles außer Dateien/Zeilen, die direkt im draft gepflegt werden)
    const readForm = () => {
      draft.title = val('title').trim();
      draft.customer = val('customer').trim();
      draft.quantity = Math.max(1, parseInt(val('quantity'), 10) || 1);
      draft.deadline = val('deadline');
      draft.kind = form.kind.value === 'eigen' ? 'eigen' : 'modell';
      draft.urls = val('urls').split(/\s*\n\s*/).map((s) => s.trim()).filter(Boolean);
      draft.measurements = val('measurements');
      draft.material = val('material').trim();
      draft.colorWish = val('colorWish').trim();
      draft.colorHex = form.noColor.checked ? '' : L.normHex(val('colorHex'));
      draft.slice = {
        infill: num(val('s_infill'), 15), walls: num(val('s_walls'), 2), extra: num(val('s_extra'), 5), supports: val('s_supports') || 'auto',
      };
      draft.hoursManual = form.hoursManual.checked;
      if (draft.hoursManual) draft.hoursPerPiece = num(val('hoursPerPiece'), 0) || '';
      draft.designHours = num(val('designHours'), 0) || '';
      draft.extraCost = num(val('extraCost'), 0) || '';
      const ov = (n) => (val(n).trim() === '' ? '' : num(val(n), 0));
      draft.pricing = { markup: ov('p_markup'), laborRate: ov('p_laborRate'), hourlyRate: ov('p_hourlyRate') };
      draft.priceManual = form.priceManual.checked && num(val('price'), 0) > 0;
      if (draft.priceManual) draft.price = num(val('price'), 0);
      draft.status = val('status');
      draft.paid = form.paid.checked;
      draft.contact = val('contact').trim();
      draft.customerAddress = val('customerAddress').trim();
      draft.license = val('license');
      draft.notes = val('notes');
      draft.manualDone = Math.max(0, parseInt(val('manualDone'), 10) || 0);
    };

    const update = () => {
      readForm();
      const pr = refreshDerived(draft);
      $('#lines-area', root).innerHTML = linesHtml(draft, pr);
      $('#price-area', root).innerHTML = priceHtml(draft, pr);
      if (!draft.hoursManual) form.hoursPerPiece.value = draft.hoursPerPiece ? String(draft.hoursPerPiece).replace('.', ',') : '';
      const nColors = pr.plan.rows.length;
      const sup = draft.lines.some((l) => l.supportGrams > 0);
      $('#sum-druck', root).textContent = nColors
        ? `${g1(pr.plan.gramsPerPiece)} g/Stück${nColors > 1 ? ` · ${nColors} Farben/Materialien` : ''}${draft.hoursPerPiece ? ` · ${L.round(draft.hoursPerPiece, 1).toLocaleString('de-DE')} h` : ''}${sup ? ' · Stützen' : ''}${pr.plan.rows.some((r) => !r.enough) ? ' · ⚠️ Rolle reicht nicht' : ''}`
        : 'noch keine Datei';
      $('#sum-preis', root).textContent = `${L.formatMoney(pr.total)}${pr.manual ? ' (fest)' : ''} · ${statusLabel(draft.status)}`;
      $('#sum-kunde', root).textContent = [draft.contact, draft.customerAddress ? 'Anschrift ✓' : ''].filter(Boolean).join(' · ');
      $$('[data-kind]', root).forEach((el) => { el.style.display = el.dataset.kind === draft.kind ? '' : 'none'; });
      $$('input[name=kind]', root).forEach((r) => r.parentElement.classList.toggle('on', r.checked));
    };

    // Kunde aus der Liste gewählt → Kontakt und Anschrift übernehmen (nur leere Felder)
    form.customer.addEventListener('change', () => {
      const c = customers.find((x) => x.name.toLowerCase() === form.customer.value.trim().toLowerCase());
      if (!c) return;
      if (!form.contact.value && c.contact) form.contact.value = c.contact;
      if (!form.customerAddress.value && c.address) form.customerAddress.value = c.address;
      update();
    });

    // Dateien: Bilder verkleinern, 3D-Dateien auswerten
    const msg = $('#file-msg', root);
    const refreshFiles = () => { $('#photo-list', root).innerHTML = filesHtml(); hydrate($('#photo-list', root)); };
    const addFiles = async (files, cameraImage = false) => {
      for (const f of files) {
        const isModel = MODEL_RE.test(f.name || '');
        const isImage = cameraImage || (!isModel && /^image\//.test(f.type || ''));
        const blob = isImage ? await resizeImage(f) : f;
        const pid = L.uid('ph');
        await putBlob(pid, blob);
        added.push(pid);
        const entry = { id: pid, name: f.name || 'Foto.jpg', type: isImage ? 'image/jpeg' : (f.type || 'application/octet-stream') };
        if (isModel) {
          msg.hidden = false;
          msg.textContent = `Rechne ${f.name} …`;
          try {
            entry.analysis = await analyzeForOrder(f);
            msg.hidden = true;
            $('#sect-druck', root).open = true;
          } catch (err) {
            msg.textContent = `${f.name}: ${err.message}`;
          }
        }
        draft.photos.push(entry);
      }
      modalDirty = true;
      refreshFiles();
      update();
    };
    $('#photo-cam', root).addEventListener('change', (e) => { addFiles([...e.target.files], true); e.target.value = ''; });
    $('#file-add', root).addEventListener('change', (e) => { addFiles([...e.target.files]); e.target.value = ''; });
    $('#photo-list', root).addEventListener('click', (e) => {
      const b = e.target.closest('[data-rm]');
      if (!b) return;
      draft.photos.splice(Number(b.dataset.rm), 1);
      modalDirty = true;
      refreshFiles();
      update();
    });
    // Dateien ins Formular ziehen (statt in den Druck-Import)
    window.__orderDrop = (files) => addFiles(files);

    // Zeilen bearbeiten
    const linesArea = $('#lines-area', root);
    linesArea.addEventListener('change', (e) => {
      const el = e.target.closest('[data-lf]');
      if (!el) return;
      const line = draft.lines.find((l) => l.id === el.closest('[data-line]').dataset.line);
      if (!line) return;
      const k = el.dataset.lf;
      if (k === 'grams') line.grams = num(el.value, 0);
      else if (k === 'colorHex') { line.colorHex = L.normHex(el.value); line.own = true; }
      else if (k === 'material') { line.material = el.value.trim(); line.own = true; }
      else if (k === 'spoolId') line.spoolId = el.value;
      update();
    });
    linesArea.addEventListener('click', (e) => {
      const b = e.target.closest('[data-rmline]');
      if (!b) return;
      draft.lines = draft.lines.filter((l) => l.id !== b.dataset.rmline);
      modalDirty = true;
      update();
    });
    $('#add-line', root).addEventListener('click', () => {
      readForm();
      draft.lines.push({ id: L.uid('m:'), auto: false, name: '', material: draft.material || 'PLA', colorHex: '', colorWish: '', grams: 0, supportGrams: 0, spoolId: '' });
      modalDirty = true;
      update();
    });

    form.addEventListener('change', (e) => { if (!e.target.closest('[data-lf]')) update(); });
    update();

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      readForm();
      refreshDerived(draft);
      if (draft.kind === 'eigen' && !draft.license) draft.license = 'eigen';
      // Kundenliste pflegen
      if (draft.customer) {
        const r = L.upsertCustomer(state.customers || [], { name: draft.customer, contact: draft.contact, address: draft.customerAddress });
        state.customers = r.list;
        draft.customerId = r.id;
      }
      state.settings.calc = { infill: draft.slice.infill, walls: draft.slice.walls, extra: draft.slice.extra, supports: draft.slice.supports };
      draft.updated = new Date().toISOString();
      let target;
      if (existing) {
        const removed = (existing.photos || []).filter((p) => !draft.photos.some((x) => x.id === p.id));
        for (const r of removed) await deleteBlob(r.id).catch(() => {});
        Object.assign(existing, draft);
        target = existing;
      } else {
        target = { ...draft, id: L.uid('o') };
        state.orders.push(target);
      }
      added.length = 0;
      window.__orderDrop = null;
      await save();
      render();
      orderDetail(target.id);
    });
    modal().addEventListener('close', async function cleanup() {
      modal().removeEventListener('close', cleanup);
      window.__orderDrop = null;
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

function bizData() {
  return { ...L.DEFAULT_BIZ, ...(state.settings.biz || {}) };
}

function viewMore() {
  const st = state.settings;
  const pr0 = L.pricingFor(st, null);
  const biz = bizData();
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
      <p class="muted">Leerspulen-Gewicht: Bambu-Kunststoffspule ca. 250 g, Pappspule ca. 140–180 g – am besten eine leere Spule wiegen.</p>
      <h3>Preise (Vorgaben – im Auftrag änderbar)</h3>
      <div class="row">
        <label class="f">Marge (%)<input name="markup" inputmode="decimal" value="${esc(pr0.markup)}"></label>
        <label class="f">Maschinenkosten (€/Druckstunde)<input name="hourlyRate" inputmode="decimal" value="${esc(pr0.hourlyRate)}"></label>
        <label class="f">Stundensatz Arbeit (€/h)<input name="laborRate" inputmode="decimal" value="${esc(pr0.laborRate)}"></label>
      </div>
      <div class="row">
        <label class="f">Mindestpreis je Auftrag (€)<input name="minOrder" inputmode="decimal" value="${esc(pr0.minOrder)}"></label>
        <label class="f">Stückpreis aufrunden auf<select name="rounding">
          ${[0.01, 0.1, 0.5, 1].map((r) => `<option value="${r}" ${Number(pr0.rounding) === r ? 'selected' : ''}>${r.toLocaleString('de-DE', { style: 'currency', currency: 'EUR' })}</option>`).join('')}
        </select></label>
      </div>
      <p class="muted">Stückpreis = (Material mit dem Preis der passenden Rolle + Druckzeit × Maschinenkosten) × (1 + Marge). Arbeitszeit (z. B. Konstruktion) und Versand kommen im Auftrag dazu.</p>
      <button class="primary">Einstellungen speichern</button>
    </form>

    <h2>Angebote & Rechnungen</h2>
    <form id="biz-form" class="card">
      <label class="f">Name / Firma<input name="name" value="${esc(biz.name)}" placeholder="z. B. Klaas 3D-Druck"></label>
      <label class="f">Anschrift<textarea name="address" rows="3" placeholder="Straße Nr.&#10;PLZ Ort">${esc(biz.address)}</textarea></label>
      <div class="row">
        <label class="f">E-Mail<input name="email" value="${esc(biz.email)}"></label>
        <label class="f">Telefon<input name="phone" value="${esc(biz.phone)}"></label>
      </div>
      <div class="row">
        <label class="f">Steuernummer / USt-IdNr.<input name="taxId" value="${esc(biz.taxId)}"></label>
        <label class="f">Umsatzsteuer<select name="vatMode">
          <option value="klein" ${biz.vatMode !== 'ust' ? 'selected' : ''}>Kleinunternehmer (§ 19 UStG)</option>
          <option value="ust" ${biz.vatMode === 'ust' ? 'selected' : ''}>mit Umsatzsteuer</option>
        </select></label>
        <label class="f" style="flex:0 0 90px">USt %<input name="vatRate" inputmode="decimal" value="${esc(biz.vatRate)}"></label>
      </div>
      <div class="row">
        <label class="f">Bank<input name="bank" value="${esc(biz.bank)}"></label>
        <label class="f">IBAN<input name="iban" value="${esc(biz.iban)}"></label>
        <label class="f" style="flex:0 0 140px">BIC<input name="bic" value="${esc(biz.bic)}"></label>
      </div>
      <div class="row">
        <label class="f">Zahlungsziel (Tage)<input name="payDays" type="number" min="0" value="${esc(biz.payDays)}"></label>
        <label class="f">Angebot gültig (Tage)<input name="offerDays" type="number" min="0" value="${esc(biz.offerDays)}"></label>
      </div>
      <div class="row">
        <label class="f">Rechnungsnr. Präfix<input name="invoicePrefix" value="${esc(biz.invoicePrefix)}"></label>
        <label class="f">nächste Rechnungsnr.<input name="nextInvoice" type="number" min="1" value="${esc(biz.nextInvoice)}"></label>
        <label class="f">Angebotsnr. Präfix<input name="offerPrefix" value="${esc(biz.offerPrefix)}"></label>
        <label class="f">nächste Angebotsnr.<input name="nextOffer" type="number" min="1" value="${esc(biz.nextOffer)}"></label>
      </div>
      <label class="f">Fußzeile (optional)<input name="footer" value="${esc(biz.footer)}" placeholder="z. B. Vielen Dank für Ihr Vertrauen!"></label>
      <p class="muted">Diese Angaben stehen auf jedem Angebot und jeder Rechnung. Für eine Rechnung in Deutschland nötig: Name und Anschrift, Steuernummer, fortlaufende Nummer, Datum, Leistung und Betrag.</p>
      <button class="primary">Speichern</button>
    </form>

    <h2>Abgleich zwischen Geräten</h2>
    ${syncCard()}

    <h2>Bambu-Cloud (Drucke automatisch)</h2>
    ${bambuCard()}

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
    <h2>App</h2>
    ${appCard()}
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

function bambuCard() {
  if (!meta.url) {
    return `<div class="card"><p class="muted">Zuerst oben den Abgleich mit der Google-Tabelle einrichten – dein Google-Script holt dann alle 30 Minuten die neuen Drucke aus der Bambu-Cloud, auch wenn kein Gerät an ist.</p></div>`;
  }
  const b = meta.bambu;
  if (!b || !b.angemeldet) {
    return `<div class="card">
      <p>Dein Google-Script holt alle 30 Minuten neue Drucke aus der Bambu-Cloud (Gramm je AMS-Slot, Farbe, Material, Vorschaubild). Du bestätigst sie hier nur noch.</p>
      ${b && b.fehler ? `<p style="color:var(--danger)">${esc(b.fehler)}</p>` : ''}
      <button class="primary" data-act="bambu-login">Bei Bambu anmelden</button>
    </div>`;
  }
  const tage = b.bis ? Math.round((b.bis - Date.now()) / 86400000) : null;
  return `<div class="card">
    <p>✅ Mit Bambu verbunden${b.ab ? ` · Drucke ab ${fmtDate(b.ab)}` : ''}.</p>
    <dl class="kv">
      <dt>Zuletzt geholt</dt><dd>${b.zuletzt ? fmtDateTime(b.zuletzt) : 'noch nicht'}</dd>
      ${tage !== null ? `<dt>Anmeldung</dt><dd>${tage > 0 ? `gültig noch ca. ${tage} Tage (wird automatisch verlängert)` : 'abgelaufen'}</dd>` : ''}
      ${b.fehler ? `<dt>Fehler</dt><dd style="color:var(--danger)">${esc(b.fehler)}</dd>` : ''}
    </dl>
    <div class="row">
      <button class="primary" data-act="bambu-now">Jetzt abrufen</button>
      ${b.fehler ? '<button data-act="bambu-login">Neu anmelden</button>' : ''}
      <button data-act="bambu-logout">Abmelden</button>
    </div>
  </div>`;
}

function bambuLoginDialog() {
  openModal(`
    <form id="bambu-form">
    ${head('Bei Bambu anmelden')}
    <div class="mbody">
      <p class="muted">Die Anmeldung läuft über dein eigenes Google-Script. Gespeichert wird dort nur das Zugangs-Token, nicht dein Passwort.</p>
      <div id="bambu-step1">
        <label class="f">E-Mail (Bambu-Konto)<input name="email" type="email" autocomplete="username" required></label>
        <label class="f">Passwort<input name="password" type="password" autocomplete="current-password" required></label>
        <label class="f">Drucke übernehmen ab<input name="ab" type="date" value="${today()}"></label>
        <p class="muted">Frühere Drucke bleiben außen vor – sonst würden alte Drucke von Rollen abgezogen, die du schon gewogen oder neu erfasst hast.</p>
      </div>
      <div id="bambu-step2" hidden>
        <p>Bambu hat dir einen <b>Code per E-Mail</b> geschickt.</p>
        <label class="f">Code<input name="code" inputmode="numeric" autocomplete="one-time-code"></label>
      </div>
      <p id="bambu-msg" style="color:var(--danger)"></p>
    </div>
    <div class="mfoot"><button type="button" data-close>Abbrechen</button><button class="primary" type="submit">Anmelden</button></div>
    </form>`, (root) => {
    const f = $('#bambu-form', root);
    let step = 1;
    f.addEventListener('submit', async (e) => {
      e.preventDefault();
      const btn = $('button[type=submit]', f);
      const msg = $('#bambu-msg', root);
      btn.disabled = true;
      msg.textContent = '';
      try {
        const call = S.makeCaller(meta.url, meta.key);
        let r;
        if (step === 1) {
          const ab = f.ab.value ? new Date(f.ab.value + 'T00:00:00').getTime() : 0;
          r = await call({ a: 'bambuLogin', email: f.email.value, password: f.password.value, ab });
          f.password.value = '';
          if (r.ok && r.code) {
            step = 2;
            $('#bambu-step1', root).hidden = true;
            $('#bambu-step2', root).hidden = false;
            f.email.required = false;
            f.password.required = false;
            f.code.focus();
            btn.textContent = 'Code bestätigen';
            return;
          }
        } else {
          r = await call({ a: 'bambuCode', code: f.code.value });
        }
        if (!r.ok) throw new Error(r.fehler || 'Anmeldung fehlgeschlagen');
        closeModal();
        toast('Mit Bambu verbunden – hole Drucke …');
        await call({ a: 'bambuNow' }).catch(() => null);
        await syncNow();
        render();
      } catch (err) {
        msg.textContent = err.message;
      } finally {
        btn.disabled = false;
      }
    });
  });
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
  if (e.target.closest('[data-close]')) return requestClose();
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
    case 'upd-check': case 'upd-later': case 'upd-go': case 'upd-perm': updAction(act); break;
    case 'doc-new': docDialog(id, el.dataset.t); break;
    case 'doc-pdf': docPdfAgain(id, el.dataset.n); break;
    case 'goto-biz': e.preventDefault(); closeModal(); setTab('mehr'); setTimeout(() => { const f = $('#biz-form'); if (f) f.scrollIntoView({ behavior: 'smooth' }); }, 50); break;
    case 'price-apply': {
      const o = orderById(id);
      o.price = Number(el.dataset.v) || 0;
      o.updated = new Date().toISOString();
      await save(); render(); orderDetail(id); toast('Preis übernommen');
      break;
    }
    case 'inbox-open': openInbox(); break;
    case 'bambu-login': bambuLoginDialog(); break;
    case 'bambu-now': {
      el.disabled = true;
      try {
        const r = await S.makeCaller(meta.url, meta.key)({ a: 'bambuNow' });
        if (!r.ok) throw new Error(r.fehler === 'anmeldung' ? 'Anmeldung abgelaufen – bitte neu anmelden' : (r.fehler || 'Fehler'));
        await syncNow();
        toast(r.neu ? `${r.neu} neue Drucke` : 'Keine neuen Drucke');
      } catch (err) { toast('Abruf fehlgeschlagen: ' + err.message); }
      render();
      break;
    }
    case 'bambu-logout': {
      if (!confirm('Bambu-Konto abmelden? Neue Drucke werden dann nicht mehr automatisch geholt.')) return;
      try { await S.makeCaller(meta.url, meta.key)({ a: 'bambuLogout' }); await syncNow(); } catch (err) { toast(err.message); }
      render();
      break;
    }
    case 'backup': {
      const text = await exportBackup(state);
      downloadBlob(new Blob([text], { type: 'application/json' }), `filament-sicherung-${today()}.json`);
      break;
    }
    default: break;
  }
});

function downloadBlob(blob, name) {
  // Android-App: Speichern über die Hülle (Android fragt nach dem Ort); <a download> geht dort nicht
  if (window.AndroidBridge && window.AndroidBridge.saveFile) {
    blobToB64(blob).then((b64) => window.AndroidBridge.saveFile(name || 'datei', blob.type || 'application/octet-stream', b64));
    return;
  }
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
  s.laborRate = num(fd.get('laborRate'), 0);
  s.minOrder = num(fd.get('minOrder'), 0);
  s.rounding = num(fd.get('rounding'), 0.1);
  await save();
  render();
  toast('Einstellungen gespeichert');
});

document.addEventListener('submit', async (e) => {
  if (e.target.id !== 'biz-form') return;
  e.preventDefault();
  const fd = new FormData(e.target);
  const b = bizData();
  for (const k of ['name', 'address', 'email', 'phone', 'taxId', 'vatMode', 'bank', 'iban', 'bic', 'invoicePrefix', 'offerPrefix', 'footer']) {
    b[k] = String(fd.get(k) || '').trim();
  }
  b.iban = b.iban.toUpperCase();
  b.vatRate = num(fd.get('vatRate'), 19);
  b.payDays = Math.max(0, parseInt(fd.get('payDays'), 10) || 0);
  b.offerDays = Math.max(0, parseInt(fd.get('offerDays'), 10) || 0);
  b.nextInvoice = Math.max(1, parseInt(fd.get('nextInvoice'), 10) || 1);
  b.nextOffer = Math.max(1, parseInt(fd.get('nextOffer'), 10) || 1);
  state.settings.biz = b;
  await save();
  render();
  toast('Gespeichert');
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
  if (window.__orderDrop && modal().open && $('#order-form')) { window.__orderDrop(files); return; }
  if (ui.tab !== 'drucke') setTab('drucke');
  await handleFiles(files);
});

// Klick neben das Fenster: nur reine Ansichten schließen, Formulare bleiben offen
modal().addEventListener('click', (e) => { if (e.target === modal() && !$('#modal-body form')) closeModal(); });
// Esc-Taste: wie ✕ (bei Eingaben nachfragen)
modal().addEventListener('cancel', (e) => { e.preventDefault(); requestClose(); });
// Eingaben in einem Formular merken
modal().addEventListener('input', (e) => { if (e.target.closest('form')) modalDirty = true; });
modal().addEventListener('change', (e) => { if (e.target.closest('form')) modalDirty = true; });

// ---------- App-Version und Selbst-Update (Android-App und Windows-App) ----------
// Die Hülle (Android: Updater.kt, Windows: electron-updater) prüft im GitHub-Release, ob es eine neuere
// Version gibt, lädt sie und startet die Installation. Antworten kommen über window.fmUpdate({state, …}).

const RELEASE = 'https://github.com/Flai331/Programmieren/releases/download/filament-manager/';
const nativeBridge = window.AndroidBridge || window.DesktopBridge || null;
const upd = { installed: null, avail: null, later: false, busy: false, manual: false, msg: '', waitInstall: false };

function appCard() {
  if (!upd.installed) {
    return `<div class="card">
      <p>Den Filament-Manager gibt es auch als App mit automatischen Updates:</p>
      <div class="row">
        <a class="btn" href="${RELEASE}Filament-Manager.apk">🤖 Android-App (APK)</a>
        <a class="btn" href="${RELEASE}Filament-Manager-Setup.exe">🪟 Windows-App</a>
      </div>
      <p class="muted">Die App hat ihre eigenen Daten. Mit dem Abgleich über die Google-Tabelle ist alles sofort da.</p>
    </div>`;
  }
  const kind = window.AndroidBridge ? 'Android' : 'Windows';
  return `<div class="card">
    <p>${kind}-App · Version <b>${esc(upd.installed.name)}</b></p>
    ${upd.msg ? `<p class="muted">${esc(upd.msg)}</p>` : ''}
    <button data-act="upd-check" ${upd.busy ? 'disabled' : ''}>Nach Updates suchen</button>
  </div>`;
}

function updRefresh() { if (ui.tab === 'mehr' && !modal().open && !typingInForm()) render(); }

function updOffer(manual) {
  if (!upd.avail || upd.busy) return;
  if (!manual && (upd.later || modal().open)) return;
  upd.busy = true;
  openModal(`${head('⬇️ Update verfügbar')}
    <div class="mbody">
      <p>Neue Version <b>${esc(upd.avail.name)}</b> (installiert ${esc(upd.installed.name)}). Jetzt aktualisieren? Deine Daten bleiben erhalten.</p>
      <p id="upd-progress" class="muted"></p>
    </div>
    <div class="mfoot">
      <button type="button" data-act="upd-later">Später</button>
      <button class="primary" data-act="upd-go">Jetzt aktualisieren</button>
    </div>`);
}

function updInstall() {
  if (nativeBridge.updateCanInstall && !nativeBridge.updateCanInstall()) {
    upd.waitInstall = true;
    openModal(`${head('⬇️ Update bereit')}
      <div class="mbody"><p>Android fragt jetzt einmalig, ob der Filament-Manager Apps installieren darf – bitte erlauben und danach hierher zurückkommen.</p></div>
      <div class="mfoot"><button type="button" data-close>Abbrechen</button><button class="primary" data-act="upd-perm">Weiter</button></div>`);
    return;
  }
  upd.waitInstall = false;
  closeModal();
  nativeBridge.updateInstall();
  upd.busy = false;
  upd.later = true;
}

window.fmUpdate = (s) => {
  if (!s || !upd.installed) return;
  if (s.state === 'available') {
    upd.avail = { code: s.code, name: s.name || `1.0.${s.code}` };
    upd.msg = `Version ${upd.avail.name} verfügbar.`;
    const manual = upd.manual;
    upd.manual = false;
    updOffer(manual);
  } else if (s.state === 'none') {
    if (upd.manual) { upd.manual = false; upd.msg = `✓ Du hast die neueste Version (${upd.installed.name}).`; updRefresh(); }
  } else if (s.state === 'progress') {
    const el = $('#upd-progress');
    if (el) el.textContent = `Lädt … ${s.pct || 0} %`;
  } else if (s.state === 'ready') {
    upd.downloading = false;
    updInstall();
  } else if (s.state === 'error') {
    upd.busy = false;
    upd.downloading = false;
    upd.manual = false;
    closeModal();
    toast(`Update fehlgeschlagen: ${s.msg || 'unbekannter Fehler'}`);
    upd.msg = 'Update fehlgeschlagen – die neueste Version gibt es auch im GitHub-Release.';
    updRefresh();
  }
};
// Update-Fenster mit ✕ geschlossen (ohne Download) → später wieder anbieten können
modal().addEventListener('close', () => { if (upd.busy && !upd.downloading && !upd.waitInstall) upd.busy = false; });
// Windows-App liefert die Meldungen per postMessage (contextIsolation)
window.addEventListener('message', (e) => {
  if (e.source === window && e.data && e.data.type === 'fm-update') window.fmUpdate(e.data.state);
});
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && upd.waitInstall && nativeBridge && (!nativeBridge.updateCanInstall || nativeBridge.updateCanInstall())) updInstall();
});

function updAction(act) {
  if (act === 'upd-check') {
    if (!upd.installed.enabled) { upd.msg = 'Diese Version hat keine Update-Suche (Testbau).'; updRefresh(); return; }
    if (upd.busy) return;
    if (upd.avail) { updOffer(true); return; }
    upd.manual = true;
    upd.msg = 'Suche läuft …';
    updRefresh();
    nativeBridge.updateCheck();
  } else if (act === 'upd-later') {
    upd.later = true;
    upd.busy = false;
    closeModal();
  } else if (act === 'upd-go') {
    const el = $('#upd-progress');
    if (el) el.textContent = 'Lädt …';
    $$('#modal .mfoot button').forEach((b) => { b.disabled = true; });
    upd.downloading = true;
    nativeBridge.updateDownload();
  } else if (act === 'upd-perm') {
    nativeBridge.updateInstall(); // öffnet die Einstellung; zurück in der App geht es weiter
  }
}

// Druckdatei per „Teilen“ / „Öffnen mit“ an die Android-App
window.onSharedFile = async () => {
  if (!window.AndroidBridge || !window.AndroidBridge.takeSharedFile) return;
  let f;
  try { f = JSON.parse(window.AndroidBridge.takeSharedFile() || 'null'); } catch { f = null; }
  if (!f || !f.data) return;
  const file = new File([b64ToBlob(f.data)], f.name || 'Datei', { lastModified: Date.now() });
  if (ui.tab !== 'drucke') setTab('drucke');
  await handleFiles([file]);
};

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
  // In der Android-/Windows-App kommen die Dateien aus der App selbst – kein Service Worker (sonst alte Stände nach Updates)
  if (!nativeBridge && 'serviceWorker' in navigator && location.protocol !== 'file:') {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
  if (nativeBridge && nativeBridge.appVersion) {
    try { upd.installed = JSON.parse(nativeBridge.appVersion()); } catch { upd.installed = null; }
    if (upd.installed && upd.installed.enabled) setTimeout(() => nativeBridge.updateCheck(), 4000);
    if (ui.tab === 'mehr') render();
  }
  window.onSharedFile();
  // Startmeldung (die automatischen Starttests der Android- und Windows-App warten darauf)
  console.info(`Filament-Manager bereit (${window.AndroidBridge ? 'Android-App' : window.DesktopBridge ? 'Windows-App' : 'Browser'})`);
})();
