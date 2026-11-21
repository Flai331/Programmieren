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
