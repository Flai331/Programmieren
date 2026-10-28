// Service Worker: App offline verfügbar machen und angesehene Kartenkacheln
// zwischenspeichern (hilft bei schlechtem Empfang im Gelände).
const VERSION = 'v15';
const APP_CACHE = `suchgebiet-app-${VERSION}`;
const TILE_CACHE = 'suchgebiet-tiles';
const MAX_TILES = 4000;

const APP_FILES = [
  './', './index.html', './style.css', './app.js', './grid.js', './render.js', './pdf.js', './layers.js', './utm.js', './store.js', './gpx.js', './kmz.js', './zip.js', './search.js',
  './manifest.json', './icon.svg', './icon-192.png', './icon-512.png',
  './lib/leaflet.js', './lib/leaflet.css', './lib/jspdf.umd.min.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(APP_CACHE).then((c) => c.addAll(APP_FILES)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(
    keys.filter((k) => k.startsWith('suchgebiet-app-') && k !== APP_CACHE).map((k) => caches.delete(k)),
  )));
  self.clients.claim();
});

const TILE_HOSTS = ['geodatenzentrum.de', 'lgln.niedersachsen.de', 'wms.nrw.de'];

async function trimTiles() {
  const cache = await caches.open(TILE_CACHE);
  const keys = await cache.keys();
  for (let i = 0; i < keys.length - MAX_TILES; i++) await cache.delete(keys[i]);
}

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET') return;

  if (TILE_HOSTS.some((h) => url.hostname.endsWith(h))) {
    // Kacheln: erst Netz, bei Fehler aus dem Zwischenspeicher
    e.respondWith((async () => {
      const cache = await caches.open(TILE_CACHE);
      try {
        const res = await fetch(e.request);
        if (res.ok) {
          cache.put(e.request, res.clone());
          if (Math.random() < 0.02) trimTiles();
        }
        return res;
      } catch (err) {
        const hit = await cache.match(e.request);
        if (hit) return hit;
        throw err;
      }
    })());
    return;
  }

  if (url.origin === location.origin) {
    // App-Dateien: Netz zuerst (Updates), offline aus dem Cache
    e.respondWith(fetch(e.request).then((res) => {
      if (res.ok) caches.open(APP_CACHE).then((c) => c.put(e.request, res.clone()));
      return res;
    }).catch(() => caches.match(e.request, { ignoreSearch: true })));
  }
});
