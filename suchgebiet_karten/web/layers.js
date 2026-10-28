// Kartengrundlagen. Alle Dienste liefern Kacheln mit CORS-Freigabe, sonst
// könnten sie nicht ins PDF übernommen werden. (Google Maps erlaubt das
// Abfotografieren/Exportieren seiner Karten nicht und ist deshalb nicht dabei.)

const YEAR = new Date().getFullYear();

export const LAYERS = [
  {
    id: 'osm',
    name: 'OpenStreetMap',
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    maxNative: 19,
    attribution: '© OpenStreetMap-Mitwirkende (ODbL)',
  },
  {
    id: 'topo',
    name: 'Topografisch (OpenTopoMap)',
    url: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    subdomains: 'abc',
    maxNative: 17,
    attribution: '© OpenStreetMap-Mitwirkende, SRTM | Darstellung © OpenTopoMap (CC-BY-SA)',
  },
  {
    id: 'basemapde',
    name: 'basemap.de (amtlich, nur DE)',
    url: 'https://sgx.geodatenzentrum.de/wmts_basemapde/tile/1.0.0/de_basemapde_web_raster_farbe/default/GLOBAL_WEBMERCATOR/{z}/{y}/{x}.png',
    maxNative: 18,
    attribution: `© GeoBasis-DE / BKG (${YEAR}) CC BY 4.0`,
  },
  {
    id: 'dop-ni',
    aerial: true,
    name: 'Luftbild Niedersachsen (LGLN, amtlich)',
    wms: 'https://opendata.lgln.niedersachsen.de/doorman/noauth/dop_wms',
    wmsLayer: 'ni_dop20',
    maxNative: 19,
    attribution: `Luftbild © LGLN (${YEAR}) CC BY 4.0`,
  },
  {
    id: 'dop-nw',
    aerial: true,
    name: 'Luftbild NRW (Geobasis NRW, amtlich)',
    wms: 'https://www.wms.nrw.de/geobasis/wms_nw_dop',
    wmsLayer: 'nw_dop_rgb',
    maxNative: 19,
    attribution: `Luftbild © Geobasis NRW (${YEAR}) dl-de/zero-2-0`,
  },
  {
    id: 'sat',
    aerial: true,
    name: 'Luftbild (Esri)',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    maxNative: 19,
    attribution: 'Luftbild © Esri, Maxar, Earthstar Geographics',
  },
];

// Durchsichtige Ebenen über Luftbildern
export const OVERLAYS = [
  {
    id: 'roads',
    name: 'Straßen',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
    maxNative: 19,
    attribution: 'Straßen © Esri',
  },
  {
    id: 'places',
    name: 'Ortsnamen und Grenzen',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    maxNative: 19,
    attribution: 'Namen © Esri',
  },
  {
    id: 'hiking',
    name: 'Wanderwege (markierte Routen)',
    url: 'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png',
    maxNative: 18,
    attribution: 'Wanderwege © waymarkedtrails.org, OpenStreetMap-Mitwirkende (CC BY-SA)',
  },
];

export const DEFAULT_OVERLAYS = ['roads', 'places', 'hiking'];

// Grundkarte + gewählte Overlays (nur bei Luftbildern) als ein Objekt für PDF/KMZ
export function layerStack(id, overlayIds = DEFAULT_OVERLAYS) {
  const base = layerById(id);
  if (!base.aerial) return base;
  const overlays = OVERLAYS.filter((o) => overlayIds.includes(o.id));
  if (!overlays.length) return base;
  return { ...base, overlays, attribution: [base.attribution, ...overlays.map((o) => o.attribution)].join(' · ') };
}

export function layerById(id) {
  return LAYERS.find((l) => l.id === id) || LAYERS[0];
}

const HALF = 20037508.342789244; // halbe Weltbreite in EPSG:3857-Metern

export function tileUrl(layer, z, x, y) {
  const n = 2 ** z;
  const wx = ((x % n) + n) % n;
  if (layer.wms) {
    // WMS-Dienste liefern keine Kacheln: Kachel als Kartenausschnitt (BBOX) anfragen
    const size = (2 * HALF) / n;
    const minx = -HALF + wx * size;
    const maxy = HALF - y * size;
    const bbox = [minx, maxy - size, minx + size, maxy].map((v) => v.toFixed(2)).join(',');
    return `${layer.wms}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=${layer.wmsLayer}&STYLES=`
      + `&CRS=EPSG:3857&WIDTH=256&HEIGHT=256&FORMAT=image/jpeg&BBOX=${bbox}`;
  }
  const sub = layer.subdomains ? layer.subdomains[Math.abs(wx + y) % layer.subdomains.length] : '';
  return layer.url
    .replace('{s}', sub)
    .replace('{z}', z)
    .replace('{x}', wx)
    .replace('{y}', y);
}
