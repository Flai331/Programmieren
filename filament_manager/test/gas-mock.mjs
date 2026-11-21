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

// Nachgebaute Bambu-Cloud (nur was Code.gs benutzt).
export function createBambu() {
  const b = {
    tasks: [], validTokens: new Set(), calls: [], codeSent: 0,
    response(method, url, opt) {
      const body = opt.payload ? JSON.parse(opt.payload) : {};
      const auth = (opt.headers || {}).Authorization || '';
      b.calls.push(url);
      if (url.startsWith('https://cover/')) return { code: 200, bytes: Buffer.from('JPEGDATA'), type: 'image/jpeg' };
      const path = url.replace('https://api.bambulab.com', '');
      if (path === '/v1/user-service/user/login') {
        if (body.password === 'pw') return { code: 200, json: { loginType: 'verifyCode' } };
        if (body.password === 'direkt') { b.validTokens.add('tok0'); return { code: 200, json: { accessToken: 'tok0', refreshToken: 'ref0', expiresIn: 7776000 } }; }
        if (body.code === '123456') { b.validTokens.add('tok1'); return { code: 200, json: { accessToken: 'tok1', refreshToken: 'ref1', expiresIn: 7776000 } }; }
        return { code: 400, json: { message: 'Incorrect password' } };
      }
      if (path === '/v1/user-service/user/sendemail/code') { b.codeSent++; return { code: 200, json: {} }; }
      if (path === '/v1/user-service/user/refreshtoken') {
        if (body.refreshToken === 'ref1') { b.validTokens.add('tok2'); return { code: 200, json: { accessToken: 'tok2', refreshToken: 'ref2', expiresIn: 7776000 } }; }
        return { code: 401, json: {} };
      }
      if (path.startsWith('/v1/user-service/my/tasks')) {
        const tok = auth.replace('Bearer ', '');
        if (!b.validTokens.has(tok)) return { code: 401, json: { message: 'unauthorized' } };
        return { code: 200, json: { total: b.tasks.length, hits: b.tasks } };
      }
      return { code: 404, json: {} };
    },
  };
  return b;
}

export function createServer({ bambu = createBambu() } = {}) {
  const sheets = new Map();
  const props = new Map();
  const files = [];
  const triggers = [];
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
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props.get(k) ?? null, setProperty: (k, v) => props.set(k, String(v)), deleteProperty: (k) => props.delete(k) }) },
    LockService: { getScriptLock: () => ({ waitLock() {}, tryLock: () => true, releaseLock() {} }) },
    ScriptApp: {
      getProjectTriggers: () => triggers.map((f) => ({ getHandlerFunction: () => f })),
      newTrigger: (f) => ({ timeBased: () => ({ everyMinutes: () => ({ create: () => triggers.push(f) }) }) }),
    },
    UrlFetchApp: {
      fetch(url, opt = {}) {
        const r = bambu.response((opt.method || 'get').toLowerCase(), url, opt);
        return {
          getResponseCode: () => r.code,
          getContentText: () => JSON.stringify(r.json || {}),
          getBlob: () => {
            const blob = { bytes: r.bytes, type: r.type, name: '', getContentType: () => r.type, getBytes: () => r.bytes, setName(n) { this.name = n; return this; } };
            return blob;
          },
        };
      },
    },
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
  return { ctx, sheets, files, key, post, props, triggers, bambu, doGet: () => ctx.doGet().text };
}
