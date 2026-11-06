// v128: Fund/Hinweis der Einsatzleitung (Kleidungsstück, Gegenstand, Spur, Wärmequelle …) – reine Logik ohne DOM.
// Ein Fund ist eine Meldung mit Ort (s: 'ort'): Felder fa = Art, fs = Status ('o' offen / 'g' geprüft), fb = Finder, ph = Foto da,
// dr = 1 dringend (Fenster bei allen Geräten wie Fund/Hilfe). Er läuft wie jede Meldung: Bericht, GPX/PDF, alle UAs.
export const FIND_KINDS = [
  { code: 'kleid', ico: '👕', label: 'Kleidungsstück', cat: 'gegenstand', hints: ['Jacke', 'Schuh', 'Mütze', 'Pullover'], urgent: true },
  { code: 'gegen', ico: '🎒', label: 'Gegenstand', cat: 'gegenstand', hints: ['Rucksack', 'Handy', 'Schlüssel', 'Brille'], urgent: false },
  { code: 'spur', ico: '🐾', label: 'Spur', cat: 'hinweis', hints: ['Fußspur', 'Zigarette', 'Geknickte Zweige'], urgent: false },
  { code: 'waerme', ico: '🔥', label: 'Wärmequelle', cat: 'hinweis', hints: ['Drohne: Wärmequelle prüfen'], urgent: true },
  { code: 'sonst', ico: '📌', label: 'Sonstiges', cat: 'sonst', hints: [], urgent: false },
];
const BY = Object.fromEntries(FIND_KINDS.map((k) => [k.code, k]));
export const findKind = (code) => BY[code] || null;
export const findLabel = (code) => { const k = BY[code]; return k ? `${k.ico} ${k.label}` : ''; };
// „Offen“ / „geprüft“
export const FIND_STATUS = { o: '⏳ offen', g: '✔ geprüft' };
export const findStatusText = (m) => (m && m.fa ? FIND_STATUS[m.fs === 'g' ? 'g' : 'o'] : '');
// Ist die Meldung ein EL-Fund (hat Art)?
export const isFind = (m) => !!m && m.s === 'ort' && !!BY[m.fa];
// Meldungen, die in jedem Unterabschnitt sichtbar sind: Fund, Hilfe (dringend) und jeder Fund/Hinweis mit Ort
export const FOR_ALL_CATS = ['fund', 'hinweis', 'gegenstand', 'hilfe'];
export const forAllUa = (m, urgent) => !!m && ((urgent && urgent(m)) || isFind(m) || (m.s === 'ort' && FOR_ALL_CATS.includes(m.cat)));
// Absender „Finder“ in Meldungen der EL: a-Kennung (kein Auftrag) – darf nie 'EL' heißen (das wären Nachrichten der EL an Teams)
export const FIND_A = 'FUND';
// Text für den Prüfauftrag an ein Team
export function checkText(m, where = '') {
  const k = BY[m.fa];
  return `Bitte prüfen: ${k ? k.label : 'Fund'}${m.txt ? ` „${m.txt}“` : ''}${where ? ` bei ${where}` : ''}.`.slice(0, 300);
}
// Quelle einer Meldung als Text: „📻 Funk (ELW)“ bzw. '' (von Hand durch die Einsatzleitung eingetragen)
export const msgSource = (m) => (m && m.src === 'f' ? `📻 Funk${m.by ? ` (${m.by})` : ''}` : '');
