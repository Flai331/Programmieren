// Kartengrundlagen – nur Dienste, die auch bei kommerzieller Nutzung (Verkauf der App)
// kostenlos sind: amtliche Geodaten von BKG und Ländern (Lizenzen CC BY 4.0,
// dl-de/by-2-0, dl-de/zero-2-0). Namensnennung steht auf dem Bildschirm und im PDF.
// Alle liefern Kacheln mit CORS-Freigabe, sonst kämen sie nicht ins PDF.
// Nicht verwendet: Google Maps (Export verboten), OSM-/OpenTopoMap-Kachelserver
// (Nutzungsregeln verbieten Massenabruf, z. B. für PDF), Esri (Konto/Lizenz nötig).

const YEAR = new Date().getFullYear();
const TOPPLUS = 'https://sgx.geodatenzentrum.de/wmts_topplus_open/tile/1.0.0';
const TOPPLUS_ATTR = `TopPlusOpen © BKG (${YEAR}) dl-de/by-2-0, Datenquellen: sgx.geodatenzentrum.de/web_public/Datenquellen_TopPlus_Open.pdf`;

export const LAYERS = [
  {
    id: 'topplus',
    name: 'Topografisch (TopPlusOpen, mit Waldwegen)',
    url: `${TOPPLUS}/web/default/WEBMERCATOR/{z}/{y}/{x}.png`,
    maxNative: 18,
    attribution: TOPPLUS_ATTR,
  },
  {
    id: 'basemapde',
    name: 'basemap.de farbig (nur DE)',
    url: 'https://sgx.geodatenzentrum.de/wmts_basemapde/tile/1.0.0/de_basemapde_web_raster_farbe/default/GLOBAL_WEBMERCATOR/{z}/{y}/{x}.png',
    maxNative: 18,
    attribution: `© GeoBasis-DE / BKG (${YEAR}) CC BY 4.0`,
  },
  {
    id: 'basemapde-grau',
    name: 'basemap.de grau (gut zum Einzeichnen)',
    url: 'https://sgx.geodatenzentrum.de/wmts_basemapde/tile/1.0.0/de_basemapde_web_raster_grau/default/GLOBAL_WEBMERCATOR/{z}/{y}/{x}.png',
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
];

// Ebenen über Luftbildern: TopPlusOpen hell, „multipliziert“ – Weiß wird durchsichtig,
// Wege, Straßen und Namen liegen dann auf dem Luftbild.
export const OVERLAYS = [
  {
    id: 'paths',
    name: 'Wege, Straßen und Ortsnamen',
    url: `${TOPPLUS}/web_light/default/WEBMERCATOR/{z}/{y}/{x}.png`,
    maxNative: 18,
    blend: 'multiply',
    opacity: 0.85,
    attribution: TOPPLUS_ATTR,
  },
];

export const DEFAULT_OVERLAYS = ['paths'];

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
