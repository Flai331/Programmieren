// Suchgebiet-Karten – Status-Meldungen (v89)
// Google Apps Script, gehört in eine Google-Tabelle (Erweiterungen -> Apps Script).
// Der Server speichert nur verschlüsselte Zeilen: Serverzeit | Raum | MeldungsID | Daten.
// Er kann den Inhalt nicht lesen; der Schlüssel steckt nur in den Aufträgen der Einsatzleitung.

var BLATT = 'Meldungen';
var MAX_TAGE = 7;
var MAX_DATEN = 20000;

function antwort_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function blatt_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(BLATT);
  if (!sh) {
    sh = ss.insertSheet(BLATT);
    sh.getRange(1, 1, 1, 4).setValues([['Serverzeit', 'Raum', 'MeldungsID', 'Daten']]).setFontWeight('bold');
    sh.setFrozenRows(1);
  }
  return sh;
}

// Hundeführer schicken eine Meldung: Body ist JSON-Text { r: Raum, id: MeldungsID, d: verschlüsselte Daten }
function doPost(e) {
  var lock = LockService.getScriptLock();
  try {
    var b = JSON.parse(e.postData.contents);
    var r = String(b.r || '');
    var id = String(b.id || '');
    var d = String(b.d || '');
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(r)) return antwort_({ ok: false, fehler: 'Raum' });
    if (!id || id.length > 40) return antwort_({ ok: false, fehler: 'ID' });
    if (!d || d.length > MAX_DATEN) return antwort_({ ok: false, fehler: 'Daten' });
    lock.waitLock(20000);
    var sh = blatt_();
    var n = sh.getLastRow();
    if (n > 1) {
      // doppelte ID im selben Raum nicht noch einmal anhängen
      var alt = sh.getRange(2, 2, n - 1, 2).getValues();
      for (var i = 0; i < alt.length; i++) {
        if (String(alt[i][0]) === r && String(alt[i][1]) === id) return antwort_({ ok: true, doppelt: true });
      }
    }
    // Zeit erst im Schloss nehmen, damit sie mit der Zeilenfolge steigt
    sh.getRange(n + 1, 1, 1, 4).setNumberFormats([['0', '@', '@', '@']]).setValues([[Date.now(), r, id, d]]);
    return antwort_({ ok: true });
  } catch (err) {
    return antwort_({ ok: false, fehler: String(err) });
  } finally {
    try { lock.releaseLock(); } catch (x) { /* kein Schloss gehalten */ }
  }
}

// ---------- Freigabe (v113): Geräte sperren, Hauptschalter ----------
var BLATT_GERAETE = 'Geräte';
var BLATT_EINST = 'Einstellungen';
var STANDARD_KONTAKT = 'error.404.found@outlook.de';
var ZEIT_FORMAT = 'dd.mm.yyyy hh:mm:ss';

function geraeteBlatt_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(BLATT_GERAETE);
  if (!sh) {
    sh = ss.insertSheet(BLATT_GERAETE);
    sh.getRange(1, 1, 1, 9).setValues([['Geräte-ID', 'Name', 'Modus', 'Plattform', 'Version', 'Modell', 'zuerst gesehen', 'zuletzt gesehen', 'Gesperrt']]).setFontWeight('bold');
    sh.setFrozenRows(1);
  }
  return sh;
}

function einstellungenBlatt_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(BLATT_EINST);
  if (!sh) {
    sh = ss.insertSheet(BLATT_EINST);
    sh.getRange(1, 1, 2, 2).setValues([['App aktiv', 'JA'], ['Kontakt', STANDARD_KONTAKT]]);
    sh.getRange(1, 1, 2, 1).setFontWeight('bold');
  }
  return sh;
}

function kuerzen_(v) {
  return String(v === undefined || v === null ? '' : v).replace(/[\r\n\t]+/g, ' ').substring(0, 60);
}

// Gesperrt ist die Zeile bei jedem nicht leeren Wert außer „nein“, „0“, „false“
function istGesperrt_(wert) {
  var t = String(wert === undefined || wert === null ? '' : wert).replace(/^\s+|\s+$/g, '').toLowerCase();
  return t !== '' && t !== 'nein' && t !== '0' && t !== 'false';
}

// Aktiv, solange B1 nicht „NEIN“, „FALSE“ oder „0“ enthält
function istAktiv_(wert) {
  var t = String(wert === undefined || wert === null ? '' : wert).replace(/^\s+|\s+$/g, '').toLowerCase();
  return !(t === 'nein' || t === 'false' || t === '0');
}

// Gerät melden: ?lic=<Geräte-ID>&m=&v=&p=&n=&ua= -> { ok, lic: true, aktiv, gesperrt, kontakt, now }
function lizenz_(p) {
  var id = String(p.lic || '');
  if (!/^[A-Za-z0-9_-]{8,40}$/.test(id)) return antwort_({ ok: false, fehler: 'Geräte-ID' });
  var name = kuerzen_(p.n);
  var modus = kuerzen_(p.m);
  var plattform = kuerzen_(p.p);
  var version = kuerzen_(p.v);
  var modell = kuerzen_(p.ua);
  var lock = LockService.getScriptLock();
  try {
    lock.waitLock(20000);
    var jetzt = Date.now();
    var sh = geraeteBlatt_();
    var n = sh.getLastRow();
    var zeile = 0;
    var gesperrt = false;
    if (n > 1) {
      var w = sh.getRange(2, 1, n - 1, 9).getValues();
      for (var i = 0; i < w.length; i++) {
        if (String(w[i][0]) !== id) continue;
        zeile = i + 2;
        gesperrt = istGesperrt_(w[i][8]);
        // Name nur überschreiben, wenn einer mitkam; zuerst gesehen und Gesperrt bleiben
        sh.getRange(zeile, 2, 1, 7).setValues([[name || w[i][1], modus, plattform, version, modell, w[i][6], new Date(jetzt)]]);
        break;
      }
    }
    if (!zeile) {
      zeile = n + 1;
      sh.getRange(zeile, 1, 1, 9).setNumberFormats([['@', '@', '@', '@', '@', '@', ZEIT_FORMAT, ZEIT_FORMAT, '@']])
        .setValues([[id, name, modus, plattform, version, modell, new Date(jetzt), new Date(jetzt), '']]);
    } else {
      sh.getRange(zeile, 7, 1, 2).setNumberFormat(ZEIT_FORMAT);
    }
    var es = einstellungenBlatt_();
    var kontakt = String(es.getRange(2, 2).getValue() || '') || STANDARD_KONTAKT;
    return antwort_({ ok: true, lic: true, aktiv: istAktiv_(es.getRange(1, 2).getValue()), gesperrt: gesperrt, kontakt: kontakt, now: jetzt });
  } catch (err) {
    return antwort_({ ok: false, fehler: String(err) });
  } finally {
    try { lock.releaseLock(); } catch (x) { /* kein Schloss gehalten */ }
  }
}

// Einsatzleitung holt ab: ?r=<Raum>&since=<Serverzeit in ms> -> { ok, now, rows: [[Serverzeit, ID, Daten], ...] }
function doGet(e) {
  var p = (e && e.parameter) || {};
  if (p.lic) return lizenz_(p);
  var r = String(p.r || '');
  if (!r) return antwort_({ ok: true, info: 'Suchgebiet-Karten Status-Server läuft.' });
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(r)) return antwort_({ ok: false, fehler: 'Raum' });
  var since = Number(p.since) || 0;
  var sh = blatt_();
  var n = sh.getLastRow();
  var rows = [];
  if (n > 1) {
    var w = sh.getRange(2, 1, n - 1, 4).getValues();
    for (var i = 0; i < w.length; i++) {
      if (String(w[i][1]) === r && Number(w[i][0]) > since) rows.push([Number(w[i][0]), String(w[i][2]), String(w[i][3])]);
    }
  }
  return antwort_({ ok: true, now: Date.now(), rows: rows });
}

// Täglich: Zeilen älter als 7 Tage löschen (die Zeilen stehen in zeitlicher Reihenfolge)
function cleanup() {
  var lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    var sh = blatt_();
    var n = sh.getLastRow();
    if (n < 2) return;
    var grenze = Date.now() - MAX_TAGE * 24 * 3600 * 1000;
    var zeiten = sh.getRange(2, 1, n - 1, 1).getValues();
    var alt = 0;
    while (alt < zeiten.length && Number(zeiten[alt][0]) < grenze) alt++;
    if (!alt) return;
    // Google lässt nicht alle Zeilen unter der Kopfzeile löschen: dann vorher eine leere anhängen
    if (alt === zeiten.length) sh.insertRowAfter(n);
    sh.deleteRows(2, alt);
  } finally {
    lock.releaseLock();
  }
}

// Einmal von Hand ausführen: legt das Blatt an und richtet das tägliche Aufräumen ein
function setup() {
  blatt_();
  geraeteBlatt_();
  einstellungenBlatt_();
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'cleanup') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('cleanup').timeBased().everyDays(1).atHour(4).create();
}
