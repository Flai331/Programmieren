// Wetter für das Suchgebiet: Daten des Deutschen Wetterdienstes (DWD, amtlich, frei nutzbar)
// über den kostenlosen Dienst Bright Sky (brightsky.dev, ohne Anmeldung). Dazu der von Hand
// gemessene Wind (Kompass + leicht/mittel/stark), der immer Vorrang hat.

const API = 'https://api.brightsky.dev';

const DIR16 = ['N', 'NNO', 'NO', 'ONO', 'O', 'OSO', 'SO', 'SSO', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
export const dirName = (deg) => DIR16[Math.round((((deg % 360) + 360) % 360) / 22.5) % 16];
const SIDE8 = ['Nord', 'Nordost', 'Ost', 'Südost', 'Süd', 'Südwest', 'West', 'Nordwest'];
const side8 = (deg) => SIDE8[Math.round((((deg % 360) + 360) % 360) / 45) % 8];

// Beaufort aus km/h
const BFT = [1, 6, 12, 20, 29, 39, 50, 62, 75, 89, 103, 118];
export const beaufort = (kmh) => { const i = BFT.findIndex((v) => kmh < v); return i < 0 ? 12 : i; };

// gemessene Stärke (Puder): leicht / mittel / stark
export const STRENGTHS = {
  light: { label: 'leicht', hint: 'Puder treibt langsam, Blätter bewegen sich kaum (bis ca. 12 km/h, Bft 1–2)' },
  medium: { label: 'mittel', hint: 'Puder zieht deutlich weg, Zweige bewegen sich (ca. 12–28 km/h, Bft 3–4)' },
  strong: { label: 'stark', hint: 'Puder reißt sofort weg, Äste bewegen sich (ab ca. 29 km/h, Bft 5+)' },
};

// Ansatz gegen den Wind: Teams beginnen auf der Seite, zu der der Wind hinweht (Lee),
// und arbeiten sich gegen den Wind vor – der Hund bekommt die Witterung zugetragen.
export function approach(fromDeg) {
  return `Start an der ${side8(fromDeg + 180)}-Seite des Gebiets, gegen den Wind Richtung ${side8(fromDeg)} arbeiten`;
}

const first = (o, keys) => { for (const k of keys) if (o[k] != null) return o[k]; return null; };

// Bright Sky /current_weather -> { t, from, kmh, gust, temp, rain, cond, icon, station, km }
export function parseCurrent(j) {
  const w = j && j.weather;
  if (!w) return null;
  const src = (j.sources || []).find((s) => s.id === w.source_id) || (j.sources || [])[0] || {};
  return {
    t: Date.parse(w.timestamp) || Date.now(),
    from: first(w, ['wind_direction_10', 'wind_direction_30', 'wind_direction_60', 'wind_direction']),
    kmh: first(w, ['wind_speed_10', 'wind_speed_30', 'wind_speed_60', 'wind_speed']),
    gust: first(w, ['wind_gust_speed_10', 'wind_gust_speed_30', 'wind_gust_speed_60', 'wind_gust_speed']),
    temp: w.temperature ?? null,
    rain: first(w, ['precipitation_60', 'precipitation_30', 'precipitation_10', 'precipitation']),
    cond: w.condition || '',
    icon: w.icon || '',
    station: src.station_name || '',
    km: src.distance != null ? src.distance / 1000 : null,
  };
}

// Bright Sky /weather -> stündlich [{ t, from, kmh, gust, temp, rain, prob, icon }]
export function parseForecast(j) {
  return ((j && j.weather) || []).map((w) => ({
    t: Date.parse(w.timestamp),
    from: w.wind_direction ?? null,
    kmh: w.wind_speed ?? null,
    gust: w.wind_gust_speed ?? null,
    temp: w.temperature ?? null,
    rain: w.precipitation ?? null,
    prob: w.precipitation_probability ?? null,
    icon: w.icon || '',
  })).filter((h) => Number.isFinite(h.t));
}

export const ICONS = {
  'clear-day': '☀️', 'clear-night': '🌙', 'partly-cloudy-day': '⛅', 'partly-cloudy-night': '☁️', cloudy: '☁️',
  fog: '🌫️', wind: '💨', rain: '🌧️', sleet: '🌨️', snow: '❄️', hail: '🌨️', thunderstorm: '⛈️',
};

export async function fetchWeather(lat, lon, now = new Date()) {
  const q = `lat=${lat.toFixed(4)}&lon=${lon.toFixed(4)}`;
  const from = new Date(now.getTime() - 3600e3).toISOString();
  const to = new Date(now.getTime() + 12 * 3600e3).toISOString();
  const [cur, fc] = await Promise.all([
    fetch(`${API}/current_weather?${q}`).then((r) => (r.ok ? r.json() : null)),
    fetch(`${API}/weather?${q}&date=${encodeURIComponent(from)}&last_date=${encodeURIComponent(to)}`).then((r) => (r.ok ? r.json() : null)).catch(() => null),
  ]);
  const current = parseCurrent(cur);
  if (!current) throw new Error('keine Wetterdaten');
  return { current, hours: parseForecast(fc).filter((h) => h.t > now.getTime()).slice(0, 8), fetched: now.getTime(), lat, lon };
}

// DWD-Messstationen im Umkreis (Bright Sky /sources): nur Stationen mit aktuellen Messungen,
// je Station einmal, die nächsten zuerst -> [{ id, name, lat, lon, km }]
export function parseStations(j, max = 6) {
  const seen = new Set();
  const out = [];
  const list = ((j && j.sources) || []).filter((s) => ['synop', 'current'].includes(s.observation_type) && s.dwd_station_id)
    .sort((a, b) => (a.distance ?? 0) - (b.distance ?? 0));
  for (const s of list) {
    if (seen.has(s.dwd_station_id)) continue;
    seen.add(s.dwd_station_id);
    out.push({ id: s.dwd_station_id, name: s.station_name || s.dwd_station_id, lat: s.lat, lon: s.lon, km: (s.distance || 0) / 1000 });
    if (out.length >= max) break;
  }
  return out;
}

// Aktueller Wind an den Stationen rund um einen Punkt (Umkreis in km)
export async function fetchStations(lat, lon, radiusKm = 40) {
  const res = await fetch(`${API}/sources?lat=${lat.toFixed(4)}&lon=${lon.toFixed(4)}&max_dist=${radiusKm * 1000}`);
  if (!res.ok) throw new Error('keine Stationen');
  const stations = parseStations(await res.json());
  await Promise.all(stations.map(async (st) => {
    try {
      const r = await fetch(`${API}/current_weather?dwd_station_id=${encodeURIComponent(st.id)}`);
      const c = r.ok ? parseCurrent(await r.json()) : null;
      if (c) Object.assign(st, { from: c.from, kmh: c.kmh, gust: c.gust, t: c.t });
    } catch { /* Station ohne aktuelle Daten */ }
  }));
  return { lat, lon, fetched: Date.now(), list: stations.filter((s) => s.from != null && s.kmh != null) };
}

// Kompass: mehrere Messwerte zu einer Richtung mitteln (über 0°/360° hinweg richtig)
export function circularMean(degs) {
  if (!degs.length) return null;
  let x = 0;
  let y = 0;
  for (const d of degs) { x += Math.cos((d * Math.PI) / 180); y += Math.sin((d * Math.PI) / 180); }
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

// Sonnenauf-/-untergang (NOAA-Näherung, auf wenige Minuten genau) als Zeitstempel
export function sunTimes(date, lat, lon) {
  const rad = Math.PI / 180;
  const day = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
  const n = Math.floor((day - Date.UTC(2000, 0, 1, 12)) / 864e5) + 1;
  const J = n - lon / 360;
  const M = (357.5291 + 0.98560028 * J) % 360;
  const C = 1.9148 * Math.sin(M * rad) + 0.02 * Math.sin(2 * M * rad) + 0.0003 * Math.sin(3 * M * rad);
  const L = (M + C + 180 + 102.9372) % 360;
  const Jt = 2451545 + J + 0.0053 * Math.sin(M * rad) - 0.0069 * Math.sin(2 * L * rad);
  const dec = Math.asin(Math.sin(L * rad) * Math.sin(23.44 * rad));
  const cosH = (Math.sin(-0.833 * rad) - Math.sin(lat * rad) * Math.sin(dec)) / (Math.cos(lat * rad) * Math.cos(dec));
  if (cosH < -1 || cosH > 1) return null;
  const H = Math.acos(cosH) / rad / 360;
  const toMs = (jd) => (jd - 2440587.5) * 864e5;
  return { rise: toMs(Jt - H), set: toMs(Jt + H) };
}

const hhmm = (t) => new Date(t).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });

// Windprotokoll eines Einsatzes (m.wind) als Zeilen für Bericht und Mail
export function windLines(m) {
  return (m.wind || []).map((w) => {
    const d = w.from != null ? `aus ${dirName(w.from)} (${Math.round(w.from)}°)` : '';
    if (w.src === 'gemessen') return `${hhmm(w.t)} gemessen${w.by ? ` (${w.by})` : ''}: ${d}, ${STRENGTHS[w.strength]?.label || ''}`;
    return `${hhmm(w.t)} DWD${w.station ? ` ${w.station}` : ''}: ${d}, ${Math.round(w.kmh)} km/h${w.gust ? `, Böen ${Math.round(w.gust)}` : ''} (Bft ${beaufort(w.kmh)})`;
  });
}

// Neuen DWD-Wert ins Protokoll? Nur bei deutlicher Änderung (Drehung ≥ 45° oder ±2 Bft)
export function windChanged(last, cur) {
  if (!last) return true;
  const turn = Math.abs(((cur.from - last.from + 540) % 360) - 180);
  return turn >= 45 || Math.abs(beaufort(cur.kmh) - beaufort(last.kmh)) >= 2;
}
