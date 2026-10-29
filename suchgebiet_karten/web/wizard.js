// Assistent „Neuen Einsatz anlegen“: Schritte und kleine Hilfen ohne DOM (testbar).

export const WIZ_STEPS = [
  ['name', 'Einsatz'],
  ['lead', 'Einsatzleitung & Funk'],
  ['meet', 'B-Ort'],
  ['wx', 'Wetter beim Start'],
  ['person', 'Vermisste Person'],
  ['times', 'Zeiten'],
  ['contacts', 'Kontakte'],
  ['done', 'Fertig'],
];

const pad = (n) => String(n).padStart(2, '0');
export const wizTitle = (d = new Date()) => `Einsatz ${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}`;
export const hhmmOf = (d) => `${pad(d.getHours())}:${pad(d.getMinutes())}`;
export const isoDate = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

// Einsatzleitung des zuletzt geänderten anderen Einsatzes („wie letztes Mal“)
export function lastLead(projects, exceptId) {
  const p = Object.values(projects)
    .filter((x) => x.id !== exceptId && x.lead && (x.lead.name || x.lead.phone || x.lead.call || x.lead.elw))
    .sort((a, b) => b.updated - a.updated)[0];
  return p ? { lead: { ...p.lead }, radio: (p.radio || []).map((r) => ({ ...r })) } : null;
}
