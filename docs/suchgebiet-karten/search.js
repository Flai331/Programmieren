// Suche: Feldnamen („C4“), Koordinaten („50.12, 8.61“) oder Adressen über OpenStreetMap.
// Vorschläge beim Tippen über Photon (komoot), Ersatz bei Ausfall: Nominatim.

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
  return list.map((r) => {
    const parts = r.display_name.split(', ');
    return {
      name: parts.slice(0, 2).join(', '),
      sub: parts.slice(2).join(', '),
      lat: parseFloat(r.lat),
      lon: parseFloat(r.lon),
      bounds: r.boundingbox ? r.boundingbox.map(Number) : null, // [süd, nord, west, ost]
    };
  });
}

const KIND = {
  parking: 'Parkplatz', shelter: 'Schutzhütte', wilderness_hut: 'Hütte', alpine_hut: 'Hütte', peak: 'Gipfel',
  forest: 'Wald', wood: 'Wald', village: 'Dorf', town: 'Stadt', city: 'Stadt', hamlet: 'Weiler', suburb: 'Ortsteil',
  locality: 'Flurname', farm: 'Hof', water: 'Gewässer', stream: 'Bach', lake: 'See', track: 'Wirtschaftsweg',
  path: 'Weg', footway: 'Fußweg', residential: 'Straße', bus_stop: 'Haltestelle',
};

// Ein Photon-Treffer (GeoJSON) -> {name, sub, lat, lon, bounds}
export function photonPlace(f) {
  const p = f.properties || {};
  const [lon, lat] = f.geometry.coordinates;
  const street = [p.street, p.housenumber].filter(Boolean).join(' ');
  const name = p.name || street || p.city || 'Ort';
  const place = [p.postcode, p.city || p.town || p.village || p.district].filter(Boolean).join(' ');
  const sub = [
    p.name && street ? street : '',
    place,
    p.state && p.country !== 'Deutschland' ? p.country : p.state,
  ].filter(Boolean).join(', ');
  const kind = KIND[p.osm_value];
  return {
    name,
    sub: kind ? `${kind} · ${sub}` : sub,
    lat,
    lon,
    // Photon: extent = [west, nord, ost, süd] -> wie Nominatim [süd, nord, west, ost]
    bounds: p.extent ? [p.extent[3], p.extent[1], p.extent[0], p.extent[2]] : null,
  };
}

// Vorschläge beim Tippen (Photon erlaubt das ausdrücklich); nahe Treffer zuerst
export async function suggestPlaces(q, center, signal) {
  const params = new URLSearchParams({ q, lang: 'de', limit: '7' });
  if (center) {
    params.set('lat', center.lat.toFixed(4));
    params.set('lon', center.lon.toFixed(4));
  }
  const res = await fetch(`https://photon.komoot.io/api/?${params}`, { signal });
  if (!res.ok) throw new Error(`Suchdienst antwortet nicht (${res.status})`);
  const data = await res.json();
  return (data.features || []).map(photonPlace);
}
