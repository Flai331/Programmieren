// Abgleich mit der Google-Tabelle (Apps Script, siehe apps-script/Code.gs).
// Ohne DOM – wird in test/sync.test.mjs gegen den echten Server-Code geprüft.
//
// Pro Eintrag (Rolle, Druck, Auftrag, Einstellungen) merkt sich das Gerät in meta.rec:
//   u  – Zeitpunkt der letzten Änderung (ms)    h  – Prüfsumme der Daten ('DEL' = gelöscht)
//   s  – Prüfsumme des zuletzt abgeglichenen Stands
//   sv – Prüfsumme der zuletzt hochgeladenen Übersichtszeile
// Konflikt: die neuere Änderung gewinnt (pro Eintrag).
import * as L from './logic.js';

export function emptyMeta() {
  return { url: '', key: '', since: 0, rec: {}, blobs: {}, lastSync: null, lastError: '' };
}

export function hash(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return 'h' + (h >>> 0).toString(36);
}

// ---------- Datensätze ----------

export function records(state) {
  const out = [];
  for (const s of state.spools) out.push({ c: 'spools', id: s.id, d: s });
  for (const p of state.prints) out.push({ c: 'prints', id: p.id, d: p });
  for (const o of state.orders) out.push({ c: 'orders', id: o.id, d: o });
  out.push({ c: 'config', id: 'settings', d: state.settings });
  out.push({ c: 'config', id: 'boxes', d: state.boxes });
  return out;
}

const keyOf = (c, id) => c + ':' + id;
const LIST = { spools: 'spools', prints: 'prints', orders: 'orders' };

function applyRecord(state, c, id, d, del) {
  if (c === 'config') {
    if (del || !d) return;
    if (id === 'settings') state.settings = { ...L.emptyState().settings, ...d };
    if (id === 'boxes') state.boxes = d || {};
    return;
  }
  const arr = state[LIST[c]];
  if (!arr) return;
  const i = arr.findIndex((x) => x.id === id);
  if (del) {
    if (i >= 0) arr.splice(i, 1);
  } else if (i >= 0) {
    // im selben Objekt aktualisieren, damit offene Dialoge ihre Referenz behalten
    const obj = arr[i];
    for (const key of Object.keys(obj)) delete obj[key];
    Object.assign(obj, d);
  } else {
    arr.push(d);
  }
}

/** Lesbare Übersichtszeile für die Tabelle (Spalten wie in Code.gs). */
export function viewOf(state, c, d) {
  if (c === 'spools') {
    return [d.brand, d.material, d.colorName, d.colorHex, L.locationLabel(d.location),
      Math.round(L.spoolRemaining(d, state.prints).remaining), d.netWeight, d.price || '', d.archived ? 'aufgebraucht' : 'aktiv'];
  }
  if (c === 'prints') {
    const total = (d.filaments || []).reduce((t, f) => t + (Number(f.grams) || 0), 0);
    const names = (d.filaments || []).map((f) => {
      const s = state.spools.find((x) => x.id === f.spoolId);
      return s ? L.spoolTitle(s) : '–';
    }).join(', ');
    const o = d.orderId ? state.orders.find((x) => x.id === d.orderId) : null;
    const dt = d.date ? new Date(d.date) : null;
    const date = dt ? `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}` : '';
    return [date, d.name, L.round(total, 1), names, o ? o.title : '', d.pieces || 0,
      d.status === 'failed' ? `abgebrochen (${d.progress} %)` : 'ok'];
  }
  if (c === 'orders') {
    const pr = L.orderProgress(d, state.prints);
    const st = (L.ORDER_STATUS.find((s) => s.id === d.status) || {}).label || d.status;
    return [d.title, d.customer, d.contact, st, `${pr.done}/${pr.quantity}`, d.deadline || '', d.price || '', d.paid ? 'ja' : 'nein'];
  }
  return [];
}

/**
 * Nach jeder lokalen Änderung aufrufen: stempelt geänderte/gelöschte Einträge mit "now".
 * Gibt true zurück, wenn sich etwas geändert hat.
 */
export function stamp(state, meta, now = Date.now()) {
  let changed = false;
  const seen = new Set();
  for (const r of records(state)) {
    const k = keyOf(r.c, r.id);
    seen.add(k);
    const h = hash(JSON.stringify(r.d));
    const m = meta.rec[k];
    if (!m) { meta.rec[k] = { u: now, h }; changed = true; }
    else if (m.h !== h) { m.u = now; m.h = h; changed = true; }
  }
  for (const [k, m] of Object.entries(meta.rec)) {
    if (!seen.has(k) && m.h !== 'DEL') {
      if (k.startsWith('config:')) continue;
      if (m.s === undefined) { delete meta.rec[k]; continue; } // nie hochgeladen → einfach vergessen
      m.u = now; m.h = 'DEL'; changed = true;
    }
  }
  return changed;
}

/** Was muss hochgeladen werden? */
export function planPush(state, meta) {
  const push = [];
  const byKey = new Map(records(state).map((r) => [keyOf(r.c, r.id), r]));
  for (const [k, m] of Object.entries(meta.rec)) {
    const i = k.indexOf(':');
    const c = k.slice(0, i), id = k.slice(i + 1);
    if (m.h === 'DEL') {
      if (m.s !== 'DEL' && m.s !== undefined) push.push({ c, id, u: m.u, del: true });
      continue;
    }
    const r = byKey.get(k);
    if (!r) continue;
    const v = viewOf(state, c, r.d);
    const vh = hash(JSON.stringify(v));
    if (m.h !== m.s || vh !== m.sv) push.push({ c, id, u: m.u, d: r.d, v, vh, h: m.h });
  }
  return push;
}

/**
 * Ergebnis vom Server einarbeiten.
 * serverWinsConfig: beim ersten Abgleich eines Geräts gewinnen die Einstellungen/Boxen der Tabelle
 * (sonst würden die Standard-Einstellungen eines neuen Handys die echten überschreiben).
 * Gibt die Anzahl geänderter lokaler Einträge zurück.
 */
export function applyResponse(state, meta, pushed, res, { serverWinsConfig = false } = {}) {
  const rejected = new Set(res.rejected || []);
  for (const it of pushed) {
    const k = keyOf(it.c, it.id);
    if (rejected.has(k)) continue;
    const m = meta.rec[k];
    if (!m || m.u !== it.u) continue; // inzwischen erneut geändert
    if (it.del) m.s = 'DEL';
    else { m.s = it.h; m.sv = it.vh; }
  }
  let changed = 0;
  for (const row of res.rows || []) {
    const k = keyOf(row.c, row.id);
    const m = meta.rec[k];
    const localDirty = m && m.h !== m.s;
    const serverWins = serverWinsConfig && row.c === 'config';
    if (m && !serverWins && localDirty && m.u > row.u) continue; // eigene neuere Änderung behalten
    if (m && m.u === row.u && !localDirty && (row.del ? m.h === 'DEL' : m.h === hash(JSON.stringify(row.d)))) {
      m.sv = row.vh || m.sv;
      continue; // schon gleich
    }
    if (row.del) {
      applyRecord(state, row.c, row.id, null, true);
      meta.rec[k] = { u: row.u, h: 'DEL', s: 'DEL' };
    } else if (row.d) {
      applyRecord(state, row.c, row.id, row.d, false);
      const h = hash(JSON.stringify(row.d));
      meta.rec[k] = { u: row.u, h, s: h, sv: row.vh || '' };
    } else continue;
    changed++;
  }
  if (res.now) meta.since = res.now;
  return changed;
}

/** Alle Bild-/Datei-IDs, die der Zustand braucht. */
export function blobRefs(state) {
  const ids = new Set();
  for (const o of state.orders) for (const ph of o.photos || []) if (ph && ph.id) ids.add(ph.id);
  for (const p of state.prints) if (p.thumbId) ids.add(p.thumbId);
  return ids;
}

// ---------- Ablauf ----------

/**
 * Ein kompletter Abgleich.
 * call(body) → Antwort-JSON des Servers; blobs = { get(id), put(id, blob), toB64(blob), fromB64(b64, type) }
 * Gibt { changed, uploaded, downloaded } zurück.
 */
export async function runSync(state, meta, call, blobs) {
  let changed = 0;
  const firstTime = !meta.since;
  if (firstTime) {
    // Neues Gerät: erst den Stand der Tabelle holen, dann Eigenes hochladen.
    const res = await call({ a: 'sync', since: 0, push: [] });
    check(res);
    changed += applyResponse(state, meta, [], res, { serverWinsConfig: true });
    stamp(state, meta);
  }
  const push = planPush(state, meta);
  const res = await call({ a: 'sync', since: meta.since, push });
  check(res);
  changed += applyResponse(state, meta, push, res);

  const { uploaded, downloaded } = await syncBlobs(state, meta, call, blobs);
  meta.lastSync = new Date().toISOString();
  meta.lastError = '';
  return { changed, uploaded, downloaded, pushed: push.length };
}

async function syncBlobs(state, meta, call, blobs) {
  const refs = blobRefs(state);
  let uploaded = 0, downloaded = 0;
  for (const id of refs) {
    const local = await blobs.get(id);
    if (meta.blobs[id]) {
      if (local) continue;
      const res = await call({ a: 'get', id });
      if (res && res.ok) { await blobs.put(id, blobs.fromB64(res.b64, res.type)); downloaded++; }
      continue;
    }
    if (local) {
      const res = await call({ a: 'put', id, type: local.type || 'application/octet-stream', b64: await blobs.toB64(local) });
      check(res);
      meta.blobs[id] = 1;
      uploaded++;
    } else {
      const res = await call({ a: 'get', id });
      if (res && res.ok) {
        await blobs.put(id, blobs.fromB64(res.b64, res.type));
        meta.blobs[id] = 1;
        downloaded++;
      }
    }
  }
  const gone = Object.keys(meta.blobs).filter((id) => !refs.has(id));
  if (gone.length) {
    const res = await call({ a: 'del', ids: gone });
    if (res && res.ok) for (const id of gone) delete meta.blobs[id];
  }
  return { uploaded, downloaded };
}

const FEHLER = {
  schluessel: 'Falscher Schlüssel – bitte aus dem Blatt „Einrichtung“ kopieren.',
  setup_fehlt: 'Im Apps-Script wurde „setup“ noch nicht ausgeführt.',
  beschaeftigt: 'Server gerade beschäftigt – gleich nochmal.',
};

function check(res) {
  if (!res || res.ok !== true) {
    const f = res && res.fehler;
    throw new Error(FEHLER[f] || ('Server-Fehler: ' + (f || 'unbekannt')));
  }
}

/** HTTP-Aufruf an die Apps-Script-Web-App (text/plain vermeidet CORS-Preflight). */
export function makeCaller(url, key, fetchFn = fetch) {
  return async (body) => {
    let res;
    try {
      res = await fetchFn(url, {
        method: 'POST',
        redirect: 'follow',
        headers: { 'Content-Type': 'text/plain;charset=utf-8' },
        body: JSON.stringify({ ...body, key }),
      });
    } catch {
      throw new Error('Keine Verbindung zum Server');
    }
    const text = await res.text();
    try {
      return JSON.parse(text);
    } catch {
      throw new Error(/<html/i.test(text)
        ? 'Server antwortet nicht mit Daten – ist die Web-App für „Jeder“ freigegeben?'
        : 'Ungültige Antwort vom Server');
    }
  };
}

export function validUrl(url) {
  return /^https:\/\/script\.google(usercontent)?\.com\//.test(String(url || '').trim());
}
