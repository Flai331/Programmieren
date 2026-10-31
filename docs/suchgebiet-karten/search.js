// Suche: Feldnamen („C4“), Koordinaten („50.12, 8.61“), Kreuzungen („Hauptstraße Ecke
// Bahnhofstraße, Celle“) oder Adressen über OpenStreetMap.
// Vorschläge beim Tippen über Photon (komoot), Ersatz bei Ausfall: Nominatim.
// Kreuzungen über die Overpass API (gemeinsame Punkte zweier Straßen).

import { parseCell } from './grid.js';
import { fetchT } from './net.js';

// -> {type: 'cell', c, r} | {type: 'coords', lat, lon} | {type: 'corner', a, b, place}
//    | {type: 'address', q} | null
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
  const corner = parseCorner(q);
  if (corner) return { type: 'corner', ...corner };
  return { type: 'address', q };
}

// Endungen, an denen man einen Straßennamen erkennt (für „A/B“ ohne das Wort „Ecke“,
// damit „Frankfurt/Main“ oder „Hauptstraße 12/14“ normale Adressen bleiben)
const STREETISH = /(stra(ss|ß)e|str\.?|weg|allee|platz|ring|gasse|damm|ufer|chaussee|pfad|steig|stieg|twiete|kamp|wall|graben|promenade|markt)$/i;

// „Hauptstraße Ecke Bahnhofstraße, Celle“, „Ecke Hauptstr./Bahnhofstr.“, „Kreuzung A und B in Celle“,
// „Lindenallee & Bahnhofstr.“ -> {a, b, place} oder null
export function parseCorner(text) {
  const parts = text.split(',').map((x) => x.trim()).filter(Boolean);
  for (let i = 0; i < parts.length; i++) {
    const s = parts[i].replace(/^(kreuzung|ecke)\s+/i, '');
    const keyword = s !== parts[i];
    let pair = /^(.+?)\s+ecke\s+(.+)$/i.exec(s);
    if (!pair) {
      const m = /^(.+?)\s*[/&+]\s*(.+)$/.exec(s);
      if (m && (keyword || STREETISH.test(m[1].trim()) || STREETISH.test(m[2].trim()))) pair = m;
    }
    if (!pair && keyword) pair = /^(.+?)\s+(?:und|u\.)\s+(.+)$/i.exec(s);
    if (!pair) continue;
    let [a, b] = [pair[1].trim(), pair[2].trim()];
    let place = parts.filter((_, k) => k !== i).join(', ');
    const inPlace = /^(.+?)\s+in\s+(.+)$/i.exec(b);
    if (inPlace && !place) [b, place] = [inPlace[1].trim(), inPlace[2].trim()];
    const word = (x) => x.length >= 2 && /[a-zäöüß]/i.test(x);
    if (!word(a) || !word(b)) return null;
    return { a, b, place };
  }
  return null;
}

// Straßenname (wie getippt) -> Suchmuster, das auch Schreibvarianten findet:
// „Hauptstr.“ = „Hauptstraße“ = „Haupt-Straße“, ss = ß, ae = ä, Groß/klein egal.
// Nur einfache Bausteine, die sowohl JavaScript als auch die Overpass API verstehen.
export function streetPattern(name) {
  let s = name.toLowerCase().replace(/ß/g, 'ss').replace(/['’]/g, '').replace(/\s+/g, ' ').trim();
  s = s.replace(/strasse/g, '\u0001').replace(/str\.?(?=$|[ -])/g, '\u0001').replace(/pl\.(?=$|[ -])/g, 'platz');
  const ALT = { ä: '(ä|Ä|ae)', ö: '(ö|Ö|oe)', ü: '(ü|Ü|ue)', ae: '(ae|ä|Ä)', oe: '(oe|ö|Ö)', ue: '(ue|ü|Ü)', ss: '(ss|ß)' };
  let out = '';
  for (let i = 0; i < s.length; i++) {
    const two = s.slice(i, i + 2);
    const ch = s[i];
    if (ALT[two]) { out += ALT[two]; i++; } else if (ch === '\u0001') out += '[- ]?stra(ss|ß)e';
    else if (ALT[ch]) out += ALT[ch];
    else if (ch === ' ' || ch === '-') out += '[- ]?';
    else if (ch === '.') out += '[.]?';
    else if (/[a-z0-9]/.test(ch)) out += ch;
  }
  return out.replace(/(\[- \]\?)+/g, '[- ]?');
}

// Suchbereich um den Bezugspunkt: Ortsgrenzen (+ etwa 1 km) oder rund 10 km Umkreis
export function cornerBox(ref, bounds) {
  if (bounds) {
    const [s, n, w, e] = bounds;
    const lat = Math.min(0.15, (n - s) / 2 + 0.01);
    const lon = Math.min(0.25, (e - w) / 2 + 0.015);
    return { south: (s + n) / 2 - lat, north: (s + n) / 2 + lat, west: (w + e) / 2 - lon, east: (w + e) / 2 + lon };
  }
  return { south: ref.lat - 0.09, north: ref.lat + 0.09, west: ref.lon - 0.14, east: ref.lon + 0.14 };
}

export function cornerQuery(pa, pb, box) {
  const bb = [box.south, box.west, box.north, box.east].map((v) => v.toFixed(5)).join(',');
  return `[out:json][timeout:25];
way[highway][name~"${pa}",i](${bb})->.a;
way[highway][name~"${pb}",i](${bb})->.b;
node(w.a)(w.b)->.x;
foreach.x->.n(
  .n out;
  way(bn.n)[highway][name];
  out tags;
  .n is_in->.ar;
  area.ar[boundary=administrative][admin_level~"^(6|7|8|9|10)$"][name];
  out tags;
);`;
}

function distM(a, b) {
  const k = Math.PI / 180;
  const x = (b.lon - a.lon) * k * Math.cos(((a.lat + b.lat) / 2) * k);
  return Math.hypot(x, (b.lat - a.lat) * k) * 6371000;
}

// Antwort der Overpass API -> Kreuzungen [{name, sub, lat, lon}], nahe Punkte (zweispurige
// Straßen, Kreisel) zusammengefasst, genaue Namen und Nähe zum Bezugspunkt zuerst
export function cornerResults(json, a, b, ref) {
  const reA = new RegExp(streetPattern(a), 'i');
  const reB = new RegExp(streetPattern(b), 'i');
  const exactA = new RegExp(`^(${streetPattern(a)})$`, 'i');
  const exactB = new RegExp(`^(${streetPattern(b)})$`, 'i');
  const groups = [];
  let cur = null;
  for (const el of json.elements || []) {
    if (el.type === 'node') {
      cur = { lat: el.lat, lon: el.lon, n: 1, names: [], areas: [] };
      const near = groups.find((g) => distM(g, cur) < 80);
      if (near) {
        near.lat = (near.lat * near.n + cur.lat) / (near.n + 1);
        near.lon = (near.lon * near.n + cur.lon) / (near.n + 1);
        near.n++;
        cur = near;
      } else groups.push(cur);
    } else if (cur && el.tags && el.tags.name) {
      if (el.type === 'way') cur.names.push(el.tags.name);
      else if (el.type === 'area') cur.areas.push({ name: el.tags.name, level: Number(el.tags.admin_level) || 0 });
    }
  }
  return groups.map((g) => {
    const na = g.names.find((x) => exactA.test(x)) || g.names.find((x) => reA.test(x)) || a;
    const nb = g.names.find((x) => x !== na && exactB.test(x)) || g.names.find((x) => x !== na && reB.test(x)) || b;
    // Ortsteil (Ebene 10/9) und Gemeinde (8; sonst Samtgemeinde 7 oder Kreis 6)
    const lv = (k) => (g.areas.find((x) => x.level === k) || {}).name;
    const place = [...new Set([lv(10) || lv(9), lv(8) || lv(7) || lv(6)].filter(Boolean))].join(', ');
    return {
      name: `${na} / ${nb}`,
      sub: ['Kreuzung', place].filter(Boolean).join(' · '),
      lat: g.lat,
      lon: g.lon,
      exact: exactA.test(na) && exactB.test(nb),
      dist: ref ? distM(ref, g) : 0,
    };
  }).sort((x, y) => (y.exact - x.exact) || (x.dist - y.dist)).slice(0, 8);
}

const OVERPASS = ['https://overpass-api.de/api/interpreter', 'https://overpass.kumi.systems/api/interpreter'];

async function overpass(query, signal) {
  let last = null;
  for (const url of OVERPASS) {
    try {
      const res = await fetchT(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `data=${encodeURIComponent(query)}`,
        signal,
      }, 30000); // Server-Limit 25 s
      if (res.ok) {
        const json = await res.json();
        // Zeitüberschreitung o. Ä. kommt als leere Antwort mit Hinweis -> nächster Server
        if (!/error/i.test(json.remark || '')) return json;
        last = new Error('Kreuzungssuche gerade überlastet – gleich nochmal versuchen');
        continue;
      }
      last = new Error(res.status === 429 ? 'Kreuzungssuche gerade überlastet – gleich nochmal versuchen' : `Kreuzungssuche antwortet nicht (${res.status})`);
    } catch (err) {
      if (signal && signal.aborted) throw err; // Zeitlimit eines Servers: nächster Server
      last = err;
    }
  }
  throw last;
}

// Kreuzung zweier Straßen im Suchbereich; erst genaue Namen, dann Namensanfänge („Bahnhof“)
export async function searchCorner(a, b, box, ref, signal) {
  const pa = streetPattern(a);
  const pb = streetPattern(b);
  let list = cornerResults(await overpass(cornerQuery(`^(${pa})$`, `^(${pb})$`, box), signal), a, b, ref);
  if (!list.length) {
    list = cornerResults(await overpass(cornerQuery(`(^|[- ])(${pa})`, `(^|[- ])(${pb})`, box), signal), a, b, ref);
  }
  return list;
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
  const res = await fetchT(`https://nominatim.openstreetmap.org/search?${params}`, { headers: { Accept: 'application/json' } });
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
  const res = await fetchT(`https://photon.komoot.io/api/?${params}`, { signal });
  if (!res.ok) throw new Error(`Suchdienst antwortet nicht (${res.status})`);
  const data = await res.json();
  return (data.features || []).map(photonPlace);
}
