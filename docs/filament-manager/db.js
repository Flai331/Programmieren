// Speicherung in IndexedDB: der App-Zustand als ein JSON-Objekt,
// Fotos/Vorschaubilder als Blobs in einem eigenen Store.
import { normalizeState } from './logic.js';

const DB_NAME = 'filament-manager';
const DB_VERSION = 1;
let dbPromise = null;

function open() {
  if (!dbPromise) {
    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains('kv')) db.createObjectStore('kv');
        if (!db.objectStoreNames.contains('blobs')) db.createObjectStore('blobs');
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }
  return dbPromise;
}

async function tx(store, mode, fn) {
  const db = await open();
  return new Promise((resolve, reject) => {
    const t = db.transaction(store, mode);
    const s = t.objectStore(store);
    let result;
    const r = fn(s);
    if (r) r.onsuccess = () => { result = r.result; };
    t.oncomplete = () => resolve(result);
    t.onerror = () => reject(t.error);
    t.onabort = () => reject(t.error);
  });
}

export async function loadState() {
  try {
    return normalizeState(await tx('kv', 'readonly', (s) => s.get('state')));
  } catch (e) {
    console.error(e);
    return normalizeState(null);
  }
}

export function saveState(state) {
  return tx('kv', 'readwrite', (s) => s.put(state, 'state'));
}

export function putBlob(id, blob) {
  return tx('blobs', 'readwrite', (s) => s.put(blob, id));
}

export function getBlob(id) {
  return tx('blobs', 'readonly', (s) => s.get(id));
}

export function deleteBlob(id) {
  return tx('blobs', 'readwrite', (s) => s.delete(id));
}

export function allBlobKeys() {
  return tx('blobs', 'readonly', (s) => s.getAllKeys());
}

// ---------- Sicherung ----------

function blobToDataUrl(blob) {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(r.result);
    r.onerror = () => reject(r.error);
    r.readAsDataURL(blob);
  });
}

async function dataUrlToBlob(url) {
  return (await fetch(url)).blob();
}

export async function exportBackup(state) {
  const blobs = {};
  for (const key of await allBlobKeys()) {
    const b = await getBlob(key);
    if (b) blobs[key] = await blobToDataUrl(b);
  }
  return JSON.stringify({ app: 'filament-manager', exportedAt: new Date().toISOString(), state, blobs });
}

export async function importBackup(text) {
  const data = JSON.parse(text);
  if (!data || data.app !== 'filament-manager' || !data.state) throw new Error('Keine Sicherung dieser App');
  for (const [key, url] of Object.entries(data.blobs || {})) {
    await putBlob(key, await dataUrlToBlob(url));
  }
  const state = normalizeState(data.state);
  await saveState(state);
  return state;
}

// ---------- Abgleich-Status (nicht Teil der Sicherung) ----------

export async function loadMeta() {
  try {
    return (await tx('kv', 'readonly', (s) => s.get('sync'))) || null;
  } catch {
    return null;
  }
}

export function saveMeta(meta) {
  return tx('kv', 'readwrite', (s) => s.put(meta, 'sync'));
}
