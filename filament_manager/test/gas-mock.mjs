// Nachbau der Google-Apps-Script-Dienste, damit apps-script/Code.gs in Node läuft.
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';

// Wie Google Sheets: Datums-/Zahlentexte werden umgewandelt, ' am Anfang erzwingt Text.
function sheetValue(v) {
  if (typeof v !== 'string') return v;
  if (v.startsWith("'")) return v.slice(1);
  if (/^\d{4}-\d{2}-\d{2}/.test(v)) return new Date(v);
  if (/^-?\d+(\.\d+)?$/.test(v)) return Number(v);
  return v;
}

function makeSheet(name) {
  const data = [];
  const sheet = {
    name, data,
    getLastRow: () => data.length,
    getRange(r, c, nr = 1, nc = 1) {
      return {
        getValues: () => Array.from({ length: nr }, (_, i) => Array.from({ length: nc }, (_, j) => (data[r - 1 + i] || [])[c - 1 + j] ?? '')),
        setValues(vals) {
          vals.forEach((row, i) => {
            const target = (data[r - 1 + i] = data[r - 1 + i] || []);
            row.forEach((v, j) => { target[c - 1 + j] = sheetValue(v); });
          });
          return this;
        },
        setFontWeight() { return this; },
      };
    },
    setFrozenRows() {},
    setColumnWidth() {},
  };
  return sheet;
}

export function createServer() {
  const sheets = new Map();
  const props = new Map();
  const files = [];
  const folder = {
    getId: () => 'folder1',
    getUrl: () => 'https://drive.google.com/folder1',
    getFilesByName(n) {
      const list = files.filter((f) => f.name === n);
      let i = 0;
      return { hasNext: () => i < list.length, next: () => list[i++] };
    },
    createFile(blob) {
      const f = { name: blob.name, blob, trashed: false, isTrashed() { return this.trashed; }, setTrashed(t) { this.trashed = t; }, setDescription() {}, getBlob: () => blob };
      files.push(f);
      return f;
    },
  };
  const ctx = {
    SpreadsheetApp: {
      getActiveSpreadsheet: () => ({
        getName: () => 'Filament-Test',
        getSheetByName: (n) => sheets.get(n) || null,
        insertSheet: (n) => { const s = makeSheet(n); sheets.set(n, s); return s; },
      }),
    },
    ContentService: { MimeType: { JSON: 'json' }, createTextOutput: (text) => ({ text, setMimeType() { return this; } }) },
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props.get(k) ?? null, setProperty: (k, v) => props.set(k, v) }) },
    LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
    DriveApp: { createFolder: () => folder, getFolderById: () => folder },
    Utilities: {
      getUuid: () => crypto.randomUUID(),
      base64Decode: (b) => Buffer.from(b, 'base64'),
      base64Encode: (b) => Buffer.from(b).toString('base64'),
      newBlob: (bytes, type, name) => ({ bytes, type, name, getContentType: () => type, getBytes: () => bytes }),
    },
    Logger: { log() {} },
    Session: { getScriptTimeZone: () => 'Europe/Berlin' },
  };
  vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(new URL('../apps-script/Code.gs', import.meta.url), 'utf8'), ctx);
  ctx.setup();
  const key = props.get('schluessel');
  const post = (body) => JSON.parse(ctx.doPost({ postData: { contents: JSON.stringify(body) } }).text);
  return { ctx, sheets, files, key, post, doGet: () => ctx.doGet().text };
}
