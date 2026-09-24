// Service Worker for Spotify-Merker
const CACHE_VERSION = 'v1';
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

// Fetch event: serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Never cache Spotify API or auth requests
  if (url.hostname === 'api.spotify.com' || url.hostname === 'accounts.spotify.com') {
    event.respondWith(fetch(event.request));
    return;
  }

  // For app assets, try cache first
  if (event.request.method === 'GET') {
    event.respondWith(
      caches.match(event.request).then((response) => {
        if (response) {
          return response;
        }
        return fetch(event.request).then((response) => {
          // Don't cache if not successful
          if (!response || response.status !== 200 || response.type === 'error') {
            return response;
          }
          // Cache successful responses for future use
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
          return response;
        });
      })
    );
  } else {
    // For non-GET requests, just pass through
    event.respondWith(fetch(event.request));
  }
});
