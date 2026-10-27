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
    id: 'sat',
    name: 'Luftbild (Esri)',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    maxNative: 19,
    attribution: 'Luftbild © Esri, Maxar, Earthstar Geographics',
  },
];

export function layerById(id) {
  return LAYERS.find((l) => l.id === id) || LAYERS[0];
}

export function tileUrl(layer, z, x, y) {
  const n = 2 ** z;
  const wx = ((x % n) + n) % n;
  const sub = layer.subdomains ? layer.subdomains[Math.abs(wx + y) % layer.subdomains.length] : '';
  return layer.url
    .replace('{s}', sub)
    .replace('{z}', z)
    .replace('{x}', wx)
    .replace('{y}', y);
}
