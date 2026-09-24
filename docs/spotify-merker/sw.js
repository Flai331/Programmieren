// Service Worker for Spotify-Merker
const CACHE_VERSION = 'v3';
const CACHE_NAME = `spotify-merker-${CACHE_VERSION}`;

const ASSETS_TO_CACHE = [
  './index.html',
  './style.css',
  './app.js',
  './auth.js',
  './api.js',
  './logic.js',
  './manifest.json',
  './icon.svg',
];

// Install event: cache app shell
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    })
  );
  self.skipWaiting();
});

// Activate event: clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name.startsWith('spotify-merker-') && name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      );
    })
  );
  self.clients.claim();
});

// Fetch event: network-first for same-origin GET, ignore cross-origin
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Never cache Spotify API or auth requests - pass through
  // (kein respondWith → der Browser lädt sie ganz normal, ohne Cache)
  if (url.hostname === 'api.spotify.com' || url.hostname === 'accounts.spotify.com') {
    return;
  }

  // Same-origin GET: network-first, fall back to cache
  if (event.request.method === 'GET' && url.origin === self.location.origin) {
    event.respondWith(
      fetch(event.request).then((response) => {
        // Cache successful responses
        if (response && response.status === 200) {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
        }
        return response;
      }).catch(() => {
        // Fall back to cache on network error
        return caches.match(event.request, { ignoreSearch: true });
      })
    );
    return;
  }

  // Cross-origin requests: ignore (don't call respondWith)
  // For non-GET same-origin: pass through
  if (event.request.method !== 'GET' && url.origin === self.location.origin) {
    event.respondWith(fetch(event.request));
  }
});
