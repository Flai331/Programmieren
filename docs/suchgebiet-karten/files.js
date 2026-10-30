// Einheitliche Dateinamen für alles, was die App speichert oder teilt:
// <Einsatz>_<JJJJ-MM-TT>_<HHMM>_<Inhalt>.<Endung>, z. B. „Uebung_Nordhang_2026-10-30_1412_Karte.pdf“.
// Nur Buchstaben, Ziffern, - und _ (Umlaute umschreiben), damit Garmin, BaseCamp, Mail und Windows damit klarkommen.
const UMLAUT = { ä: 'ae', ö: 'oe', ü: 'ue', Ä: 'Ae', Ö: 'Oe', Ü: 'Ue', ß: 'ss' };

export function cleanPart(s, max = 40) {
  return String(s || '').replace(/[äöüÄÖÜß]/g, (ch) => UMLAUT[ch])
    .replace(/[^\w-]+/g, '_').replace(/_+/g, '_').replace(/^[_-]+|[_-]+$/g, '').slice(0, max).replace(/[_-]+$/, '');
}

export function fileName(title, what, ext, d = new Date()) {
  const pad = (n) => String(n).padStart(2, '0');
  const stamp = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}`;
  const w = cleanPart(what);
  return `${cleanPart(title) || 'Suchgebiet'}_${stamp}${w ? `_${w}` : ''}${ext}`;
}
