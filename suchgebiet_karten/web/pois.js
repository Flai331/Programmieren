// Lage-Orte (ELW, Bereitstellungsraum, Parkplatz …): feste Punkte der Einsatzorganisation.
// P.pois = [{ id, cat, name, desc, lat, lon, t (letzte Änderung, ms), by (Gerätename) }]
// Feste IDs und Änderungszeit, damit sich Stände verschiedener Geräte später zusammenführen lassen.

export const POI_CATS = [
  { id: 'elw', icon: '🚐', label: 'ELW', color: '#c62828', gpx: 'Truck' },
  { id: 'br', icon: '🅱️', label: 'Bereitstellungsraum', color: '#1565c0', gpx: 'Parking Area' },
  { id: 'park', icon: '🅿️', label: 'Parkplatz', color: '#1565c0', gpx: 'Parking Area' },
  { id: 'wc', icon: '🚻', label: 'Toilette', color: '#6a1b9a', gpx: 'Restroom' },
  { id: 'food', icon: '🍲', label: 'Verpflegung', color: '#ef6c00', gpx: 'Restaurant' },
  { id: 'water', icon: '🚰', label: 'Ver-/Entsorgung', color: '#00838f', gpx: 'Drinking Water' },
  { id: 'san', icon: '🚑', label: 'Sanität', color: '#d50000', gpx: 'Medical Facility' },
  { id: 'lkl', icon: '❓', label: 'Letzter bekannter Ort', color: '#ad1457', gpx: 'Flag, Red' },
  { id: 'other', icon: '📌', label: 'Sonstiges', color: '#455a64', gpx: 'Pin, Blue' },
];

export function poiCat(id) {
  return POI_CATS.find((c) => c.id === id) || POI_CATS[POI_CATS.length - 1];
}

// Anzeigename: eigener Name, sonst die Kategorie
export function poiName(p) {
  return (p.name || '').trim() || poiCat(p.cat).label;
}

export function poiLabel(p) {
  return `${poiCat(p.cat).icon} ${poiName(p)}`;
}

let seq = 0;
export function newPoi({ cat, lat, lon, name = '', desc = '', by = '' }, now = Date.now()) {
  seq = (seq + 1) % 1296;
  const id = `${now.toString(36)}${seq.toString(36).padStart(2, '0')}${Math.random().toString(36).slice(2, 6)}`;
  return {
    id, cat: poiCat(cat).id, name: name.trim(), desc: desc.trim(),
    lat: Math.round(lat * 1e6) / 1e6, lon: Math.round(lon * 1e6) / 1e6, t: now, by,
  };
}

// Nur gültige Einträge (ältere Dateien, Importe)
export function normalizePois(list) {
  return (Array.isArray(list) ? list : [])
    .filter((p) => p && typeof p.id === 'string' && Number.isFinite(p.lat) && Number.isFinite(p.lon))
    .map((p) => ({ ...p, cat: poiCat(p.cat).id, name: String(p.name || ''), desc: String(p.desc || ''), t: Number(p.t) || 0 }));
}

// Reihenfolge für Listen (PDF, Fenster): nach Kategorie wie in POI_CATS, dann Name
export function sortPois(list) {
  const rank = (p) => POI_CATS.findIndex((c) => c.id === poiCat(p.cat).id);
  return [...list].sort((a, b) => rank(a) - rank(b) || poiName(a).localeCompare(poiName(b), 'de'));
}
