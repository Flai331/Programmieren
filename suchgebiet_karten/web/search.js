// Suche: Feldnamen („C4“), Koordinaten („50.12, 8.61“) oder Adressen über OpenStreetMap (Nominatim).

import { parseCell } from './grid.js';

// -> {type: 'cell', c, r} | {type: 'coords', lat, lon} | {type: 'address', q} | null
export function parseQuery(text) {
  const q = (text || '').trim();
  if (!q) return null;
  if (/^[A-Za-z]{1,3}\s*\d{1,4}$/.test(q)) return { type: 'cell', ...parseCell(q) };
  const m = /^(-?\d{1,3}(?:[.,]\d+)?)°?\s*[,;\s]\s*(-?\d{1,3}(?:[.,]\d+)?)°?$/.exec(q);
  if (m) {
    const lat = parseFloat(m[1].replace(',', '.'));
    const lon = parseFloat(m[2].replace(',', '.'));
    if (Math.abs(lat) <= 90 && Math.abs(lon) <= 180) return { type: 'coords', lat, lon };
  }
  return { type: 'address', q };
}

// Nominatim-Suche; view (aktueller Kartenausschnitt) bevorzugt nahe Treffer.
// Nutzungsregeln von Nominatim: nur auf Knopfdruck suchen, nicht bei jedem Tastendruck.
export async function searchAddress(q, view) {
  const params = new URLSearchParams({
    format: 'jsonv2',
    q,
    limit: '8',
    'accept-language': 'de',
    addressdetails: '0',
  });
  if (view) params.set('viewbox', [view.west, view.north, view.east, view.south].map((v) => v.toFixed(4)).join(','));
  const res = await fetch(`https://nominatim.openstreetmap.org/search?${params}`, { headers: { Accept: 'application/json' } });
  if (!res.ok) throw new Error(`Suchdienst antwortet nicht (${res.status})`);
  const list = await res.json();
  return list.map((r) => ({
    name: r.display_name,
    lat: parseFloat(r.lat),
    lon: parseFloat(r.lon),
    bounds: r.boundingbox ? r.boundingbox.map(Number) : null, // [süd, nord, west, ost]
  }));
}
