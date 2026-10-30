// v103: Tipp ins Leere schließt, was offen ist – reine Entscheidungslogik ohne DOM (testbar).
// Umgesetzt wird sie zentral in app.js (ein pointerdown-Listener in der Capture-Phase).

// Knöpfe, die einen Dialog abbrechen/schließen (Tipp auf den dunklen Hintergrund löst den letzten davon aus)
export const CANCEL_LABEL = /^\s*(Abbrechen|Schließen|Fenster schließen|Später)\s*$/;

// Welcher Knopf eines Dialogs ist „Abbrechen“? labels: Beschriftungen in Reihenfolge; -1 = keiner.
export function cancelIndex(labels) {
  for (let i = labels.length - 1; i >= 0; i--) if (CANCEL_LABEL.test(labels[i])) return i;
  return -1;
}

// Dialoge, die der Hintergrund-Tipp nicht schließt: Dringend (🆘), Warnungen vor Ändern/Löschen (🔒, 🗑)
export const PROTECTED_HEAD = /^\s*(🔒|🗑|🆘)|löschen|entfernen/i;
export const isProtectedHead = (head) => PROTECTED_HEAD.test(head || '');

// Tipp auf den Hintergrund eines Dialogs: welcher Knopf wird ausgelöst (-1 = Dialog bleibt)?
// keep: Dialog ausdrücklich geschützt (laufender Vorgang wie der Update-Download);
// head: Überschrift; typed: in ein Textfeld wurde schon etwas getippt.
export function backdropAction({ keep, head, typed, labels }) {
  if (keep || typed || isProtectedHead(head)) return -1;
  return cancelIndex(labels);
}

// Was macht ein Tipp (pointerdown)?
// dlgOpen: Dialog offen; target: 'backdrop' (Dialog-Hintergrund) | 'empty' (Karte/leere Fläche) | 'ui' (alles andere)
// anyOpen: Fenster, HF-Menü, Team-Liste/-Info oder Suchergebnisse offen
// Rückgabe: 'dlg-backdrop' | 'close' | 'none'
export function tapVerdict({ dlgOpen, target, anyOpen }) {
  if (dlgOpen) return target === 'backdrop' ? 'dlg-backdrop' : 'none';
  if (anyOpen && target === 'empty') return 'close';
  return 'none';
}
