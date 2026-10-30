// v103: Selbst-Update der Android-App – reine Logik ohne DOM (testbar).
// Die Android-Hülle (Updater.kt) meldet über window.sgkUpdate({state, code, name, pct, msg}).

// Ist gerade ein Einsatz offen? Dann wird kein Update angeboten (mitten im Einsatz keine Unterbrechung).
// EL: offen, solange der Einsatz nicht „frei“ (leere Karte) oder abgeschlossen ist. HF: sobald ein Auftrag geladen ist.
export function einsatzOffen({ mode, free, closed, hfAssigned }) {
  if (mode === 'hf') return !!hfAssigned;
  return !(free || closed);
}

// Soll der Update-Hinweis jetzt erscheinen?
// installed/latest: Versionsnummern (versionCode); later: „Später“ wurde seit dem App-Start gewählt.
export function shouldOfferUpdate({ installed, latest, einsatzOffen: offen, later }) {
  const i = Number(installed);
  const l = Number(latest);
  if (!Number.isFinite(i) || !Number.isFinite(l) || !(l > i)) return false;
  return !offen && !later;
}

export function updateText(installedName, latestName) {
  return `Neue Version ${latestName} verfügbar (installiert ${installedName}). Jetzt aktualisieren? Die Daten bleiben erhalten.`;
}

export const PERMISSION_HINT = 'Android fragt jetzt einmalig, ob Suchgebiet-Karten Apps installieren darf – bitte erlauben und danach hierher zurückkommen.';
