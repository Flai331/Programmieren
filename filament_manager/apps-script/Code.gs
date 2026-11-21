// Filament-Manager – Abgleich-Server
// Google Apps Script, gehört in eine Google-Tabelle (Erweiterungen -> Apps Script).
// Speichert Rollen, Drucke, Aufträge und Einstellungen als Zeilen (eine pro Eintrag)
// und Fotos/Dateien in einem Ordner in Google Drive.
// Zugriff nur mit dem geheimen Schlüssel aus dem Blatt "Einrichtung".
//
// Spalten je Blatt: ID | Geändert | Gelöscht | Server | Daten (JSON) | Prüfsumme | Übersicht …
// Die Übersichts-Spalten sind nur zum Ansehen – Änderungen bitte in der App machen.

var BLAETTER = {
  spools: { name: 'Rollen', spalten: ['Marke', 'Material', 'Farbe', 'Farbcode', 'Lagerplatz', 'Rest (g)', 'Netto (g)', 'Preis (€)', 'Status'] },
  prints: { name: 'Drucke', spalten: ['Datum', 'Name', 'Gramm', 'Rollen', 'Auftrag', 'Stück', 'Ergebnis'] },
  orders: { name: 'Auftraege', spalten: ['Titel', 'Kunde', 'Kontakt', 'Status', 'Stück', 'Termin', 'Preis (€)', 'Bezahlt'] },
  config: { name: 'Einstellungen', spalten: [] }
};
var FEST = ['ID', 'Geändert', 'Gelöscht', 'Server', 'Daten', 'Prüfsumme'];
var MAX_JSON = 49000; // Zellen fassen max. 50.000 Zeichen

function antwort_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function props_() { return PropertiesService.getScriptProperties(); }

function blatt_(c) {
  var def = BLAETTER[c];
  if (!def) return null;
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(def.name);
  if (!sh) {
    sh = ss.insertSheet(def.name);
    var kopf = FEST.concat(def.spalten);
    sh.getRange(1, 1, 1, kopf.length).setValues([kopf]).setFontWeight('bold');
    sh.setFrozenRows(1);
  }
  return sh;
}

function breite_(c) { return FEST.length + BLAETTER[c].spalten.length; }

function zeilen_(sh, c) {
  var last = sh.getLastRow();
  if (last < 2) return [];
  return sh.getRange(2, 1, last - 1, breite_(c)).getValues();
}

// Verhindert, dass Text wie "=…" in der Tabelle als Formel ausgeführt wird.
function zelle_(v) {
  if (v === null || v === undefined) return '';
  if (typeof v === 'number' || typeof v === 'boolean') return v;
  var s = String(v);
  if (/^[=+\-@]/.test(s)) s = "'" + s;
  return s.length > 1000 ? s.slice(0, 1000) : s;
}

function zeileBauen_(c, item, jetzt) {
  var json = item.del ? '' : JSON.stringify(item.d);
  if (json.length > MAX_JSON) throw new Error('zu_gross:' + item.id);
  var row = [String(item.id), Number(item.u) || 0, item.del ? 1 : '', jetzt, json, item.del ? '' : zelle_(item.vh || '')];
  var n = BLAETTER[c].spalten.length;
  var v = item.del ? [] : (item.v || []);
  for (var i = 0; i < n; i++) row.push(zelle_(v[i]));
  return row;
}

function zeileLesen_(c, r) {
  var del = r[2] === 1 || r[2] === '1' || r[2] === true;
  var d = null;
  if (!del && r[4]) { try { d = JSON.parse(r[4]); } catch (e) { d = null; } }
  return { c: c, id: String(r[0]), u: Number(r[1]) || 0, del: del, d: d, vh: String(r[5] || '') };
}

// Abgleich: eigene Änderungen schreiben (neuere gewinnt), dann alles seit "since" zurückgeben.
// Streng aufsteigende Serverzeit (läuft unter der Sperre), damit kein Abgleich
// eine Änderung aus derselben Millisekunde übersieht.
function serverZeit_() {
  var letzte = Number(props_().getProperty('zeit')) || 0;
  var jetzt = Math.max(Date.now(), letzte + 1);
  props_().setProperty('zeit', String(jetzt));
  return jetzt;
}

function abgleich_(req) {
  var jetzt = serverZeit_();
  var push = req.push || [];
  var abgelehnt = {};
  var gruppen = {};
  push.forEach(function (it) {
    if (!BLAETTER[it.c] || !it.id) return;
    (gruppen[it.c] = gruppen[it.c] || []).push(it);
  });
  Object.keys(gruppen).forEach(function (c) {
    var sh = blatt_(c);
    var werte = zeilen_(sh, c);
    var index = {};
    werte.forEach(function (r, i) { index[String(r[0])] = i; });
    var neu = [];
    gruppen[c].forEach(function (it) {
      var i = index[String(it.id)];
      if (i !== undefined && Number(werte[i][1]) > Number(it.u)) { abgelehnt[c + ':' + it.id] = true; return; }
      var row = zeileBauen_(c, it, jetzt);
      if (i !== undefined) {
        sh.getRange(i + 2, 1, 1, row.length).setValues([row]);
        werte[i] = row;
      } else {
        index[String(it.id)] = werte.length + neu.length;
        neu.push(row);
      }
    });
    if (neu.length) sh.getRange(sh.getLastRow() + 1, 1, neu.length, neu[0].length).setValues(neu);
  });

  var since = Number(req.since) || 0;
  var rows = [];
  Object.keys(BLAETTER).forEach(function (c) {
    var sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(BLAETTER[c].name);
    if (!sh) return;
    zeilen_(sh, c).forEach(function (r) {
      if (!r[0]) return;
      if (Number(r[3]) > since || abgelehnt[c + ':' + r[0]]) rows.push(zeileLesen_(c, r));
    });
  });
  return { ok: true, now: jetzt, rows: rows, rejected: Object.keys(abgelehnt) };
}

// ---------- Dateien in Google Drive ----------

function ordner_() {
  var id = props_().getProperty('ordner');
  if (id) {
    try { return DriveApp.getFolderById(id); } catch (e) { /* gelöscht → neu */ }
  }
  var f = DriveApp.createFolder('Filament-Manager Fotos & Dateien');
  props_().setProperty('ordner', f.getId());
  return f;
}

function sichereId_(id) { return /^[A-Za-z0-9_-]{1,80}$/.test(String(id || '')); }

function dateiFinden_(id) {
  var it = ordner_().getFilesByName(id);
  while (it.hasNext()) {
    var f = it.next();
    if (!f.isTrashed()) return f;
  }
  return null;
}

function dateiAblegen_(req) {
  if (!sichereId_(req.id) || !req.b64) return { ok: false, fehler: 'ungueltig' };
  if (dateiFinden_(req.id)) return { ok: true, vorhanden: true };
  var blob = Utilities.newBlob(Utilities.base64Decode(req.b64), req.type || 'application/octet-stream', req.id);
  var f = ordner_().createFile(blob);
  if (req.name) f.setDescription(String(req.name).slice(0, 200));
  return { ok: true };
}

function dateiHolen_(req) {
  if (!sichereId_(req.id)) return { ok: false, fehler: 'ungueltig' };
  var f = dateiFinden_(req.id);
  if (!f) return { ok: false, fehler: 'fehlt' };
  var b = f.getBlob();
  return { ok: true, type: b.getContentType(), b64: Utilities.base64Encode(b.getBytes()) };
}

function dateienLoeschen_(req) {
  (req.ids || []).forEach(function (id) {
    if (!sichereId_(id)) return;
    var f = dateiFinden_(id);
    if (f) f.setTrashed(true);
  });
  return { ok: true };
}

// ---------- Bambu-Cloud: Druckhistorie automatisch abholen ----------
// Anmeldung aus der App (E-Mail + Passwort, dann Code aus der Bambu-Mail). Gespeichert wird nur
// das Zugangs-Token (Skripteigenschaften), nie das Passwort. Ein Zeitauslöser ("bambuAbrufen",
// alle 30 Minuten) legt neue, fertige Drucke im Blatt "Eingang" ab; die App zeigt sie zum Bestätigen.
// Die Bambu-Schnittstelle ist nicht offiziell dokumentiert.

var BAMBU_API = 'https://api.bambulab.com';
var EINGANG = 'Eingang';
var EINGANG_KOPF = ['TaskID', 'Abgerufen', 'Erledigt', 'Daten', 'Datum', 'Name', 'Gramm', 'Status'];
var HALTEN_MS = 24 * 3600 * 1000; // Drucke ohne klaren Status erst nach 24 h übernehmen

function bambuRuf_(methode, pfad, body, token) {
  var opt = {
    method: methode,
    contentType: 'application/json',
    muteHttpExceptions: true,
    headers: token ? { Authorization: 'Bearer ' + token } : {}
  };
  if (body) opt.payload = JSON.stringify(body);
  var res = UrlFetchApp.fetch(BAMBU_API + pfad, opt);
  var code = res.getResponseCode();
  var json = {};
  try { json = JSON.parse(res.getContentText() || '{}'); } catch (e) { json = { roh: String(res.getContentText()).slice(0, 200) }; }
  return { code: code, json: json };
}

function tokenSpeichern_(j) {
  var p = props_();
  p.setProperty('bambuToken', j.accessToken);
  if (j.refreshToken) p.setProperty('bambuRefresh', j.refreshToken);
  var sek = Number(j.expiresIn) || 90 * 24 * 3600;
  p.setProperty('bambuBis', String(Date.now() + sek * 1000));
  p.deleteProperty('bambuFehler');
  p.deleteProperty('bambuEmail');
}

function bambuLogin_(req) {
  var email = String(req.email || '').trim();
  if (!email || !req.password) return { ok: false, fehler: 'E-Mail und Passwort angeben' };
  var p = props_();
  if (req.ab) p.setProperty('bambuAb', String(Number(req.ab) || 0));
  var r = bambuRuf_('post', '/v1/user-service/user/login', { account: email, password: String(req.password) });
  if (r.json.accessToken) { tokenSpeichern_(r.json); return { ok: true, angemeldet: true }; }
  if (r.json.loginType === 'verifyCode') {
    p.setProperty('bambuEmail', email);
    var c = bambuRuf_('post', '/v1/user-service/user/sendemail/code', { email: email, type: 'codeLogin' });
    if (c.code >= 300) return { ok: false, fehler: 'Bambu konnte keinen Code senden (' + c.code + ')' };
    return { ok: true, code: true };
  }
  if (r.json.loginType === 'tfa') return { ok: false, fehler: 'Konto nutzt eine Authenticator-App – wird nicht unterstützt' };
  return { ok: false, fehler: 'Anmeldung abgelehnt (' + r.code + '): ' + (r.json.message || r.json.error || JSON.stringify(r.json).slice(0, 120)) };
}

function bambuCode_(req) {
  var email = props_().getProperty('bambuEmail');
  if (!email) return { ok: false, fehler: 'Bitte zuerst mit E-Mail und Passwort anmelden' };
  var r = bambuRuf_('post', '/v1/user-service/user/login', { account: email, code: String(req.code || '').trim() });
  if (r.json.accessToken) { tokenSpeichern_(r.json); return { ok: true, angemeldet: true }; }
  return { ok: false, fehler: 'Code falsch oder abgelaufen' };
}

function bambuAbmelden_() {
  var p = props_();
  ['bambuToken', 'bambuRefresh', 'bambuBis', 'bambuFehler', 'bambuEmail', 'bambuZuletzt'].forEach(function (k) { p.deleteProperty(k); });
  return { ok: true };
}

function bambuErneuern_() {
  var p = props_();
  var rt = p.getProperty('bambuRefresh');
  if (!rt) return false;
  var r = bambuRuf_('post', '/v1/user-service/user/refreshtoken', { refreshToken: rt });
  if (r.json.accessToken) { tokenSpeichern_(r.json); return true; }
  return false;
}

function bambuStatus_() {
  var p = props_();
  return {
    angemeldet: !!p.getProperty('bambuToken'),
    bis: Number(p.getProperty('bambuBis')) || 0,
    zuletzt: Number(p.getProperty('bambuZuletzt')) || 0,
    fehler: p.getProperty('bambuFehler') || '',
    ab: Number(p.getProperty('bambuAb')) || 0
  };
}

function eingangBlatt_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(EINGANG);
  if (!sh) {
    sh = ss.insertSheet(EINGANG);
    sh.getRange(1, 1, 1, EINGANG_KOPF.length).setValues([EINGANG_KOPF]).setFontWeight('bold');
    sh.setFrozenRows(1);
  }
  return sh;
}

function eingangZeilen_(sh) {
  var last = sh.getLastRow();
  return last < 2 ? [] : sh.getRange(2, 1, last - 1, EINGANG_KOPF.length).getValues();
}

function zeit_(t) {
  if (!t) return 0;
  var n = new Date(t).getTime();
  return isNaN(n) ? 0 : n;
}

// Nur die Felder, die die App braucht.
function taskKurz_(t) {
  return {
    id: t.id, designTitle: t.designTitle, title: t.title, status: t.status, weight: t.weight,
    length: t.length, costTime: t.costTime, startTime: t.startTime, endTime: t.endTime,
    deviceName: t.deviceName, deviceModel: t.deviceModel, plateIndex: t.plateIndex,
    amsDetailMapping: (t.amsDetailMapping || []).map(function (m) {
      return { ams: m.ams, sourceColor: m.sourceColor, targetColor: m.targetColor, filamentId: m.filamentId,
        filamentType: m.filamentType, targetFilamentType: m.targetFilamentType, weight: m.weight };
    })
  };
}

/** Neue fertige Drucke in den Eingang legen. Gibt die Anzahl neuer Einträge zurück. */
function eingangAufnehmen_(tasks, jetzt) {
  var sh = eingangBlatt_();
  var bekannt = {};
  eingangZeilen_(sh).forEach(function (r) { bekannt[String(r[0])] = true; });
  var ab = Number(props_().getProperty('bambuAb')) || 0;
  var neu = [];
  (tasks || []).forEach(function (t) {
    if (!t || t.id === undefined || t.id === null || bekannt[String(t.id)]) return;
    var start = zeit_(t.startTime), ende = zeit_(t.endTime);
    if (ab && (ende || start) && (ende || start) < ab) return;
    var fertig = t.status === 2 || t.status === 3;
    if (!fertig && !(start && jetzt - start > HALTEN_MS)) return; // läuft vermutlich noch
    bekannt[String(t.id)] = true;
    var kurz = taskKurz_(t);
    var gramm = Number(t.weight) || 0;
    neu.push([String(t.id), jetzt, '', JSON.stringify(kurz),
      zelle_(t.endTime || t.startTime || ''), zelle_(t.designTitle || t.title || ''), gramm, t.status]);
    if (t.cover) vorschauSichern_('cthumb_' + t.id, t.cover);
  });
  if (neu.length) sh.getRange(sh.getLastRow() + 1, 1, neu.length, EINGANG_KOPF.length).setValues(neu);
  return neu.length;
}

function vorschauSichern_(id, url) {
  try {
    if (!/^https:\/\//.test(url) || dateiFinden_(id)) return;
    var res = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
    if (res.getResponseCode() !== 200) return;
    var blob = res.getBlob().setName(id);
    if (blob.getBytes().length > 2 * 1024 * 1024) return;
    ordner_().createFile(blob);
  } catch (e) { /* Vorschau ist nur nett, nicht nötig */ }
}

function bambuHolen_() {
  var p = props_();
  var token = p.getProperty('bambuToken');
  if (!token) return { ok: false, fehler: 'nicht angemeldet' };
  var bis = Number(p.getProperty('bambuBis')) || 0;
  if (bis && bis - Date.now() < 14 * 24 * 3600 * 1000 && bambuErneuern_()) token = p.getProperty('bambuToken');
  var r = bambuRuf_('get', '/v1/user-service/my/tasks?limit=50', null, token);
  if ((r.code === 401 || r.code === 403) && bambuErneuern_()) {
    r = bambuRuf_('get', '/v1/user-service/my/tasks?limit=50', null, p.getProperty('bambuToken'));
  }
  if (r.code === 401 || r.code === 403) {
    p.setProperty('bambuFehler', 'Anmeldung abgelaufen – bitte in der App neu anmelden');
    return { ok: false, fehler: 'anmeldung' };
  }
  if (r.code >= 300 || !r.json.hits) {
    p.setProperty('bambuFehler', 'Bambu antwortet nicht wie erwartet (' + r.code + ')');
    return { ok: false, fehler: 'bambu_' + r.code };
  }
  var n = eingangAufnehmen_(r.json.hits, Date.now());
  p.setProperty('bambuZuletzt', String(Date.now()));
  p.deleteProperty('bambuFehler');
  return { ok: true, neu: n };
}

// Zeitauslöser (von setup eingerichtet). Ohne Anmeldung passiert nichts.
function bambuAbrufen() {
  if (!props_().getProperty('bambuToken')) return;
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) return;
  try { bambuHolen_(); } catch (e) { props_().setProperty('bambuFehler', String(e && e.message || e)); } finally { lock.releaseLock(); }
}

function eingang_() {
  var items = [];
  eingangZeilen_(eingangBlatt_()).forEach(function (r) {
    if (!r[0] || r[2]) return;
    try { items.push(JSON.parse(r[3])); } catch (e) { /* kaputte Zeile überspringen */ }
  });
  return { ok: true, items: items, bambu: bambuStatus_() };
}

function eingangErledigt_(req) {
  var ids = {};
  (req.ids || []).forEach(function (id) { ids[String(id)] = true; });
  var sh = eingangBlatt_();
  var jetzt = Date.now();
  eingangZeilen_(sh).forEach(function (r, i) {
    if (ids[String(r[0])] && !r[2]) sh.getRange(i + 2, 3, 1, 1).setValues([[jetzt]]);
  });
  return { ok: true };
}

// ---------- Einstieg ----------

function doPost(e) {
  var req;
  try { req = JSON.parse(e.postData.contents); } catch (err) { return antwort_({ ok: false, fehler: 'json' }); }
  var schluessel = props_().getProperty('schluessel');
  if (!schluessel) return antwort_({ ok: false, fehler: 'setup_fehlt' });
  if (!req || req.key !== schluessel) return antwort_({ ok: false, fehler: 'schluessel' });

  var lock = LockService.getScriptLock();
  try {
    lock.waitLock(25000);
  } catch (err) {
    return antwort_({ ok: false, fehler: 'beschaeftigt' });
  }
  try {
    switch (req.a) {
      case 'ping': return antwort_({ ok: true, name: SpreadsheetApp.getActiveSpreadsheet().getName() });
      case 'sync': return antwort_(abgleich_(req));
      case 'put': return antwort_(dateiAblegen_(req));
      case 'get': return antwort_(dateiHolen_(req));
      case 'del': return antwort_(dateienLoeschen_(req));
      case 'inbox': return antwort_(eingang_());
      case 'inboxDone': return antwort_(eingangErledigt_(req));
      case 'inboxAdd': return antwort_({ ok: true, neu: eingangAufnehmen_(req.tasks, Date.now()) });
      case 'bambuLogin': return antwort_(bambuLogin_(req));
      case 'bambuCode': return antwort_(bambuCode_(req));
      case 'bambuLogout': return antwort_(bambuAbmelden_());
      case 'bambuNow': return antwort_(bambuHolen_());
      default: return antwort_({ ok: false, fehler: 'aktion' });
    }
  } catch (err) {
    return antwort_({ ok: false, fehler: String(err && err.message || err) });
  } finally {
    lock.releaseLock();
  }
}

function doGet() {
  return ContentService.createTextOutput('Filament-Manager-Server läuft. Adresse in der App unter „Mehr → Abgleich“ eintragen.');
}

// Einmal im Editor ausführen: legt Blätter, Drive-Ordner und den geheimen Schlüssel an.
function setup() {
  var p = props_();
  var key = p.getProperty('schluessel');
  if (!key) {
    key = Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, '').slice(0, 8);
    p.setProperty('schluessel', key);
  }
  Object.keys(BLAETTER).forEach(function (c) { blatt_(c); });
  eingangBlatt_();
  // Zeitauslöser für die Bambu-Druckhistorie (alle 30 Minuten), nur einmal anlegen
  var hat = ScriptApp.getProjectTriggers().some(function (t) { return t.getHandlerFunction() === 'bambuAbrufen'; });
  if (!hat) ScriptApp.newTrigger('bambuAbrufen').timeBased().everyMinutes(30).create();
  var ordner = ordner_();
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName('Einrichtung') || ss.insertSheet('Einrichtung', 0);
  sh.getRange(1, 1, 4, 2).setValues([
    ['Schlüssel (in der App eintragen)', key],
    ['Drive-Ordner für Fotos', ordner.getUrl()],
    ['Hinweis', 'Änderungen bitte in der App machen – die Tabelle zeigt nur den Stand.'],
    ['Eingerichtet am', new Date()]
  ]);
  sh.getRange(1, 1, 4, 1).setFontWeight('bold');
  sh.setColumnWidth(1, 260);
  sh.setColumnWidth(2, 420);
  Logger.log('Schlüssel: ' + key);
}
