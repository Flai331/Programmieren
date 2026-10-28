// UTM (WGS84/ETRS89) und UTMREF/MGRS, wie bei Feuerwehr, THW und Polizei.

const A = 6378137;
const F = 1 / 298.257223563;
const K0 = 0.9996;
const E2 = F * (2 - F);
const EP2 = E2 / (1 - E2);
const RAD = Math.PI / 180;

export function utmZone(lat, lon) {
  let z = Math.floor((lon + 180) / 6) + 1;
  // Sonderzonen Norwegen/Spitzbergen
  if (lat >= 56 && lat < 64 && lon >= 3 && lon < 12) z = 32;
  if (lat >= 72 && lat < 84) {
    if (lon >= 0 && lon < 9) z = 31;
    else if (lon >= 9 && lon < 21) z = 33;
    else if (lon >= 21 && lon < 33) z = 35;
    else if (lon >= 33 && lon < 42) z = 37;
  }
  return Math.min(60, Math.max(1, z));
}

function meridianArc(phi) {
  const e4 = E2 * E2;
  const e6 = e4 * E2;
  return A * ((1 - E2 / 4 - (3 * e4) / 64 - (5 * e6) / 256) * phi
    - ((3 * E2) / 8 + (3 * e4) / 32 + (45 * e6) / 1024) * Math.sin(2 * phi)
    + ((15 * e4) / 256 + (45 * e6) / 1024) * Math.sin(4 * phi)
    - ((35 * e6) / 3072) * Math.sin(6 * phi));
}

// lat/lon -> {zone, easting, northing, south}; zone kann erzwungen werden
export function toUtm(lat, lon, zone = utmZone(lat, lon)) {
  const phi = lat * RAD;
  const lon0 = ((zone - 1) * 6 - 180 + 3) * RAD;
  const sin = Math.sin(phi);
  const cos = Math.cos(phi);
  const tan = Math.tan(phi);
  const N = A / Math.sqrt(1 - E2 * sin * sin);
  const T = tan * tan;
  const C = EP2 * cos * cos;
  const a = cos * (lon * RAD - lon0);
  const M = meridianArc(phi);
  const easting = K0 * N * (a + ((1 - T + C) * a ** 3) / 6
    + ((5 - 18 * T + T * T + 72 * C - 58 * EP2) * a ** 5) / 120) + 500000;
  let northing = K0 * (M + N * tan * ((a * a) / 2 + ((5 - T + 9 * C + 4 * C * C) * a ** 4) / 24
    + ((61 - 58 * T + T * T + 600 * C - 330 * EP2) * a ** 6) / 720));
  const south = lat < 0;
  if (south) northing += 10000000;
  return { zone, easting, northing, south };
}

export function fromUtm(zone, easting, northing, south = false) {
  const x = easting - 500000;
  const y = south ? northing - 10000000 : northing;
  const lon0 = ((zone - 1) * 6 - 180 + 3) * RAD;
  const M = y / K0;
  const mu = M / (A * (1 - E2 / 4 - (3 * E2 * E2) / 64 - (5 * E2 ** 3) / 256));
  const e1 = (1 - Math.sqrt(1 - E2)) / (1 + Math.sqrt(1 - E2));
  const phi1 = mu + ((3 * e1) / 2 - (27 * e1 ** 3) / 32) * Math.sin(2 * mu)
    + ((21 * e1 * e1) / 16 - (55 * e1 ** 4) / 32) * Math.sin(4 * mu)
    + ((151 * e1 ** 3) / 96) * Math.sin(6 * mu)
    + ((1097 * e1 ** 4) / 512) * Math.sin(8 * mu);
  const sin = Math.sin(phi1);
  const cos = Math.cos(phi1);
  const tan = Math.tan(phi1);
  const N1 = A / Math.sqrt(1 - E2 * sin * sin);
  const T1 = tan * tan;
  const C1 = EP2 * cos * cos;
  const R1 = (A * (1 - E2)) / (1 - E2 * sin * sin) ** 1.5;
  const D = x / (N1 * K0);
  const lat = phi1 - ((N1 * tan) / R1) * ((D * D) / 2
    - ((5 + 3 * T1 + 10 * C1 - 4 * C1 * C1 - 9 * EP2) * D ** 4) / 24
    + ((61 + 90 * T1 + 298 * C1 + 45 * T1 * T1 - 252 * EP2 - 3 * C1 * C1) * D ** 6) / 720);
  const lon = lon0 + (D - ((1 + 2 * T1 + C1) * D ** 3) / 6
    + ((5 - 2 * C1 + 28 * T1 - 3 * C1 * C1 + 8 * EP2 + 24 * T1 * T1) * D ** 5) / 120) / cos;
  return { lat: lat / RAD, lon: lon / RAD };
}

export function latBand(lat) {
  return 'CDEFGHJKLMNPQRSTUVWXX'[Math.max(0, Math.min(20, Math.floor((lat + 80) / 8)))];
}

// "32U 476543 5551234"
export function formatUtm(lat, lon) {
  const u = toUtm(lat, lon);
  return `${u.zone}${latBand(lat)} ${Math.round(u.easting)} ${Math.round(u.northing)}`;
}

// UTMREF/MGRS, z. B. "32U MA 7654 5123" (digits je Achse: 4 = 10 m, 5 = 1 m)
export function formatMgrs(lat, lon, digits = 4) {
  const u = toUtm(lat, lon);
  const setCol = ['STUVWXYZ', 'ABCDEFGH', 'JKLMNPQR'][u.zone % 3];
  const col = setCol[Math.floor(u.easting / 100000) - 1] || '?';
  const rows = 'ABCDEFGHJKLMNPQRSTUV';
  const row = rows[(Math.floor(u.northing / 100000) + (u.zone % 2 === 0 ? 5 : 0)) % 20];
  const div = 10 ** (5 - digits);
  const e = String(Math.floor((u.easting % 100000) / div)).padStart(digits, '0');
  const n = String(Math.floor((u.northing % 100000) / div)).padStart(digits, '0');
  return `${u.zone}${latBand(lat)} ${col}${row} ${e} ${n}`;
}
