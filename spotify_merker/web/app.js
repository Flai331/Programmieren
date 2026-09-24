// Main application logic
import {
  getStoredClientId,
  storeClientId,
  isLoggedIn,
  logout,
  initiateLogin,
  getRedirectUri,
  exchangeCode,
} from './auth.js';
import {
  getCurrentlyPlaying,
  getRecentlyPlayed,
  getDevices,
  playTrack,
  getAudiobooks,
  getAudiobookChapters,
} from './api.js';
import {
  normalizePlayback,
  recordSample,
  mergeRecentlyPlayed,
  findResumeCandidate,
  buildPlayBody,
  computeBookResume,
  filterHistory,
  formatMs,
  uriType,
  uriId,
  MAX_HISTORY,
} from './logic.js';

// Module state
let currentTab = 'now';
let pollInterval = null;
let pollTimerHandle = null;
let pendingResume = null;
let current = null; // Current playback (normalized + id from history if match)
let lastRecentlyPlayedMerge = 0;
let audiobooksList = null; // Cached list of audiobooks
let loadingBookIds = new Set(); // Track which books are being loaded

// Escaped für Text UND Attribute (inkl. Anführungszeichen).
const esc = (str) =>
  String(str ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

// Link zum Öffnen in Spotify (Web-Link öffnet auf dem Handy die App).
function spotifyLink(entry) {
  if (entry.webUrl && /^https:\/\/open\.spotify\.com\//.test(entry.webUrl)) return entry.webUrl;
  const type = uriType(entry.uri);
  const webType = type === 'chapter' ? 'episode' : type;
  return `https://open.spotify.com/${webType}/${uriId(entry.uri)}`;
}

// Date → Wert für <input type="datetime-local"> in lokaler Zeit.
function toLocalInputValue(ms) {
  const d = new Date(ms);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

// Format relative time in German
function dayLabel(dateStr) {
  const today = new Date();
  const yesterday = new Date(Date.now() - 864e5);
  if (dateStr === today.toLocaleDateString('de-DE')) return 'Heute';
  if (dateStr === yesterday.toLocaleDateString('de-DE')) return 'Gestern';
  return dateStr;
}

function formatRelativeTime(ms) {
  if (!ms || ms <= 0) return 'gerade eben';
  const seconds = Math.floor(ms / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (seconds < 60) return 'gerade eben';
  if (minutes < 60) return `vor ${minutes} Min.`;
  if (hours < 24) return `vor ${hours} Std.`;
  return `vor ${days} Tagen`;
}

// Unified resume function
async function playEntry(entry, positionMs = entry.progressMs) {
  if (!entry) return;

  const clientId = getStoredClientId();
  if (!clientId) {
    showToast('Client ID nicht gesetzt', 'error');
    return;
  }

  try {
    const body = buildPlayBody(entry, positionMs);

    // Try to play on active device first
    try {
      await playTrack(clientId, null, body);
      showToast(`Weiterhören bei ${formatMs(positionMs)}`, 'success');
      await poll(); // Trigger immediate poll
      return;
    } catch (err) {
      if (err.status === 404 || err.reason === 'NO_ACTIVE_DEVICE') {
        // No active device, try to get devices
        const devices = await getDevices(clientId);
        if (devices?.devices && devices.devices.length > 0) {
          const smartphone = devices.devices.find(d => d.type === 'Smartphone');
          const deviceId = smartphone ? smartphone.id : devices.devices[0].id;
          await playTrack(clientId, deviceId, body);
          showToast(`Weiterhören bei ${formatMs(positionMs)}`, 'success');
          await poll();
          return;
        } else {
          // No devices available, open Spotify and set pending resume
          pendingResume = { entry, positionMs };
          window.open(spotifyLink(entry), '_blank');
          showToast('Spotify wird geöffnet – komm danach zurück, dann springe ich zur Stelle.', 'info');
          return;
        }
      } else if (err.status === 403 && err.reason === 'PREMIUM_REQUIRED') {
        showToast('Fernsteuerung braucht Spotify Premium – öffne Spotify stattdessen', 'error');
        window.open(spotifyLink(entry), '_blank');
        return;
      }
      throw err;
    }
  } catch (err) {
    console.error('Resume error:', err);
    showToast(`Fehler: ${err.message}`, 'error');
  }
}

// Initialize the app
export async function initApp() {
  // Register service worker
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').catch(err => {
      console.error('SW registration failed:', err);
    });
  }

  // Check for OAuth callback
  const params = new URLSearchParams(location.search);
  const code = params.get('code');
  const state = params.get('state');
  const error = params.get('error');

  if (code) {
    const clientId = getStoredClientId();
    const storedState = sessionStorage.getItem('sm.state');

    if (!storedState || state !== storedState) {
      showToast('Sicherheitsfehler: state mismatch', 'error');
      history.replaceState({}, '', location.pathname);
    } else if (clientId) {
      try {
        await exchangeCode(code, clientId);
        showToast('Angemeldet!', 'success');
        history.replaceState({}, '', location.pathname);
        renderHeader();
        renderNow();
        renderHistory();
        renderBooks();
        await poll(); // Poll immediately after login
      } catch (err) {
        showToast(`Anmeldung fehlgeschlagen: ${err.message}`, 'error');
        history.replaceState({}, '', location.pathname);
      }
    }
  } else if (error) {
    showToast(`Anmeldung abgebrochen: ${error}`, 'error');
    history.replaceState({}, '', location.pathname);
  }

  // Render initial state
  renderHeader();
  renderTabs();
  renderNow();
  renderHistory();
  renderBooks();
  renderSettings();

  // Set up tab click listeners with event delegation
  setupEventDelegation();

  // Start polling and do initial poll
  startPolling();
  await poll();

  // Update on visibility change
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      clearInterval(pollTimerHandle);
      pollInterval = 30000;
      schedulePoll();
    } else {
      clearInterval(pollTimerHandle);
      pollInterval = 5000;
      schedulePoll();
      lastRecentlyPlayedMerge = 0;
      poll();

      // Retry pending resume if app becomes visible
      if (pendingResume) {
        const pr = pendingResume;
        pendingResume = null;
        playEntry(pr.entry, pr.positionMs);
      }
    }
  });
}

function setupEventDelegation() {
  // History container delegation
  document.addEventListener('click', (e) => {
    if (e.target.closest('[data-action="resume"]')) {
      const entryId = e.target.closest('[data-action="resume"]').dataset.id;
      const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
      const entry = history.find(h => h.id === entryId);
      if (entry) playEntry(entry, entry.progressMs);
    }

    if (e.target.closest('[data-action="open-spotify"]')) {
      const entryId = e.target.closest('[data-action="open-spotify"]').dataset.id;
      const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
      const entry = history.find(h => h.id === entryId);
      if (entry) window.open(spotifyLink(entry), '_blank');
    }

    if (e.target.closest('[data-action="pin"]')) {
      const entryId = e.target.closest('[data-action="pin"]').dataset.id;
      const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
      const entry = history.find(h => h.id === entryId);
      if (entry) {
        entry.pinned = true;
        localStorage.setItem('sm.history', JSON.stringify(history));
        showToast('Gemerkt!', 'success');
      } else {
        showToast('Noch nicht im Verlauf – gleich nochmal versuchen', 'info');
      }
    }

    if (e.target.closest('[data-action="reload-books"]')) {
      fetchAudiobooksList();
    }

    if (e.target.closest('[data-action="toggle-pin"]')) {
      const entryId = e.target.closest('[data-action="toggle-pin"]').dataset.id;
      const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
      const entry = history.find(h => h.id === entryId);
      if (entry) {
        entry.pinned = !entry.pinned;
        localStorage.setItem('sm.history', JSON.stringify(history));
        renderHistory();
      }
    }

    if (e.target.closest('[data-action="delete-entry"]')) {
      const entryId = e.target.closest('[data-action="delete-entry"]').dataset.id;
      if (confirm('Wirklich löschen?')) {
        const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
        const filtered = history.filter(h => h.id !== entryId);
        localStorage.setItem('sm.history', JSON.stringify(filtered));
        renderHistory();
      }
    }

    if (e.target.closest('[data-action="load-book"]')) {
      const bookId = e.target.closest('[data-action="load-book"]').dataset.bookId;
      loadBook(bookId);
    }

    if (e.target.closest('[data-action="resume-book"]')) {
      const bookId = e.target.closest('[data-action="resume-book"]').dataset.bookId;
      resumeBook(bookId);
    }
  });

  // Tab clicks
  document.addEventListener('click', (e) => {
    const tabBtn = e.target.closest('[data-tab]');
    if (tabBtn) {
      switchTab(tabBtn.dataset.tab);
    }
  });

  // Settings form actions
  document.addEventListener('click', (e) => {
    if (e.target.matches('[data-action="save-client-id"]')) {
      const input = document.getElementById('clientId');
      const clientId = input.value.trim();
      if (!clientId) {
        showToast('Client ID erforderlich', 'error');
        return;
      }
      storeClientId(clientId);
      showToast('Client ID gespeichert', 'success');
    }

    if (e.target.matches('[data-action="do-login"]')) {
      const clientId = getStoredClientId();
      if (!clientId) {
        showToast('Client ID erforderlich', 'error');
        return;
      }
      initiateLogin(clientId);
    }

    if (e.target.matches('[data-action="do-logout"]')) {
      logout();
      renderHeader();
      renderNow();
      renderHistory();
      renderBooks();
      showToast('Abgemeldet', 'success');
    }

    if (e.target.matches('[data-action="copy-redirect-uri"]')) {
      const uri = getRedirectUri();
      navigator.clipboard.writeText(uri).then(() => {
        showToast('Kopiert!', 'success');
      });
    }

    if (e.target.matches('[data-action="export-history"]')) {
      const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
      const dataStr = JSON.stringify(history, null, 2);
      const dataBlob = new Blob([dataStr], { type: 'application/json' });
      const url = URL.createObjectURL(dataBlob);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'spotify-merker-verlauf.json';
      link.click();
      URL.revokeObjectURL(url);
      showToast('Exportiert!', 'success');
    }

    if (e.target.matches('[data-action="import-history"]')) {
      document.getElementById('importFile').click();
    }

    if (e.target.matches('[data-action="clear-history"]')) {
      if (confirm('Wirklich den gesamten Verlauf löschen?')) {
        localStorage.removeItem('sm.history');
        renderHistory();
        showToast('Verlauf gelöscht', 'success');
      }
    }
  });

  // Import file change
  document.addEventListener('change', (e) => {
    if (e.target.id === 'importFile') {
      handleImportFile(e);
    }
  });

  // Filter changes
  document.addEventListener('change', (e) => {
    if (e.target.id === 'around') {
      const value = e.target.value;
      if (value) {
        const filterState = JSON.parse(localStorage.getItem('sm.filterState') || '{"range":"all","query":"","kind":"all","around":null}');
        filterState.around = new Date(value).getTime();
        localStorage.setItem('sm.filterState', JSON.stringify(filterState));
      } else {
        const filterState = JSON.parse(localStorage.getItem('sm.filterState') || '{"range":"all","query":"","kind":"all","around":null}');
        filterState.around = null;
        localStorage.setItem('sm.filterState', JSON.stringify(filterState));
      }
      renderHistory();
    }

    if (e.target.id === 'search') {
      const filterState = JSON.parse(localStorage.getItem('sm.filterState') || '{"range":"all","query":"","kind":"all","around":null}');
      filterState.query = e.target.value;
      localStorage.setItem('sm.filterState', JSON.stringify(filterState));
      renderHistory();
    }
  });

  document.addEventListener('click', (e) => {
    const filterChip = e.target.closest('[data-filter]');
    if (filterChip) {
      const field = filterChip.dataset.filterField;
      const value = filterChip.dataset.filterValue;
      const filterState = JSON.parse(localStorage.getItem('sm.filterState') || '{"range":"all","query":"","kind":"all","around":null}');
      filterState[field] = value;
      localStorage.setItem('sm.filterState', JSON.stringify(filterState));
      renderHistory();
    }

    if (e.target.matches('[data-action="clear-around"]')) {
      const filterState = JSON.parse(localStorage.getItem('sm.filterState') || '{"range":"all","query":"","kind":"all","around":null}');
      filterState.around = null;
      localStorage.setItem('sm.filterState', JSON.stringify(filterState));
      renderHistory();
    }
  });
}

function startPolling() {
  if (!isLoggedIn()) return;
  pollInterval = document.hidden ? 30000 : 5000;
  schedulePoll();
}

function schedulePoll() {
  if (pollTimerHandle) clearInterval(pollTimerHandle);
  pollTimerHandle = setInterval(poll, pollInterval);
}

async function poll() {
  if (!isLoggedIn()) return;

  const clientId = getStoredClientId();
  if (!clientId) return;

  try {
    const playback = await getCurrentlyPlaying(clientId);
    const sample = normalizePlayback(playback);

    // Get history
    let history = JSON.parse(localStorage.getItem('sm.history') || '[]');

    // Record sample and update current
    if (sample) {
      history = recordSample(history, sample, Date.now());
      const id = history[0] && history[0].uri === sample.uri ? history[0].id : null;
      current = { ...sample, id, lastSeenAt: Date.now() };
    } else {
      current = null;
    }

    localStorage.setItem('sm.history', JSON.stringify(history));

    // Merge recently played only on app start, on visibilitychange→visible, or every 5 minutes
    const now = Date.now();
    if (now - lastRecentlyPlayedMerge > 5 * 60 * 1000) {
      try {
        const recentlyPlayed = await getRecentlyPlayed(clientId, 50);
        if (recentlyPlayed?.items) {
          history = mergeRecentlyPlayed(history, recentlyPlayed.items);
          localStorage.setItem('sm.history', JSON.stringify(history));
          lastRecentlyPlayedMerge = now;
        }
      } catch (err) {
        console.error('Recently played error:', err);
      }
    }

    // Only re-render if active and not interacting with input
    if (currentTab === 'now') {
      renderNow();
    } else if (currentTab === 'history' && !document.getElementById('history-content').contains(document.activeElement)) {
      renderHistory();
    }
  } catch (err) {
    console.error('Polling error:', err);
    if (err.status === 401) {
      logout();
      renderHeader();
      showToast('Sitzung abgelaufen, bitte erneut anmelden', 'error');
    }
  }
}

function renderHeader() {
  const header = document.getElementById('header');
  const connected = isLoggedIn();
  header.innerHTML = `
    <h1>Spotify-Merker</h1>
    <div class="status">${connected ? '✓ Verbunden' : '✗ Nicht verbunden'}</div>
  `;
}

function renderTabs() {
  const tabsContainer = document.getElementById('tabs');
  tabsContainer.innerHTML = `
    <button class="tab-button active" data-tab="now">Jetzt</button>
    <button class="tab-button" data-tab="history">Verlauf</button>
    <button class="tab-button" data-tab="books">Hörbücher</button>
    <button class="tab-button" data-tab="settings">Einstellungen</button>
  `;
}

function switchTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab-button').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
  document.querySelectorAll('[data-tab-content]').forEach(el => {
    el.style.display = el.dataset.tabContent === tab ? 'block' : 'none';
  });

  if (tab === 'now') renderNow();
  if (tab === 'history') renderHistory();
  // Fetch audiobooks list when Hörbücher tab opened for the first time
  if (tab === 'books' && !audiobooksList && isLoggedIn()) {
    fetchAudiobooksList();
  }
}

function renderNow() {
  const content = document.getElementById('now-content');
  if (!isLoggedIn()) {
    content.innerHTML = '<p>Bitte melde dich in den Einstellungen an.</p>';
    return;
  }

  const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
  let html = '';

  // Show resume banner only if current is not the last spoken entry
  const resume = findResumeCandidate(history, current);
  if (resume) {
    const ago = formatRelativeTime(Date.now() - resume.lastSeenAt);
    const resumeSubtitle = resume.subtitle || resume.title;
    html += `
      <div class="banner">
        <h3>Zurück zu: ${esc(resumeSubtitle)}</h3>
        <p>${esc(resume.title)} · bei ${formatMs(resume.progressMs)} · ${ago}</p>
        <button data-action="resume" data-id="${esc(resume.id)}">▶ Weiterhören</button>
        <button data-action="open-spotify" data-id="${esc(resume.id)}">↗ In Spotify öffnen</button>
      </div>
    `;
  }

  // Current playback card
  if (current) {
    const elapsed = current.isPlaying ? Date.now() - current.lastSeenAt : 0;
    const progress = Math.min(current.progressMs + elapsed, current.durationMs || Infinity);
    const percent = current.durationMs > 0 ? (progress / current.durationMs) * 100 : 0;
    const imgAttr = current.image ? ` src="${esc(current.image)}" alt=""` : '';
    html += `
      <div class="card now-card">
        ${current.image ? `<img${imgAttr} class="cover">` : ''}
        <div class="card-content">
          <h2>${esc(current.title)}</h2>
          <p>${esc(current.subtitle)}</p>
          <p class="progress">${formatMs(progress)} / ${formatMs(current.durationMs)}</p>
          <div class="progress-bar">
            <div class="progress-fill" style="width: ${percent}%"></div>
          </div>
          ${current.isPlaying ? '' : '<p class="muted">Pausiert</p>'}
          ${current.id ? `<button data-action="pin" data-id="${esc(current.id)}">📌 Merken</button>` : ''}
        </div>
      </div>
    `;
  } else {
    html += '<p>Nichts läuft gerade.</p>';
  }

  content.innerHTML = html;
}

function renderHistory() {
  const content = document.getElementById('history-content');
  if (!isLoggedIn()) {
    content.innerHTML = '<p>Bitte melde dich in den Einstellungen an.</p>';
    return;
  }

  const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
  const filterState = JSON.parse(localStorage.getItem('sm.filterState') || '{"range":"all","query":"","kind":"all","around":null}');

  let html = `
    <div class="filters">
      <div class="filter-group">
        <label>Zeitraum:</label>
        <button class="filter-chip ${filterState.range === 'hour' ? 'active' : ''}" data-filter data-filter-field="range" data-filter-value="hour">Letzte Stunde</button>
        <button class="filter-chip ${filterState.range === 'today' ? 'active' : ''}" data-filter data-filter-field="range" data-filter-value="today">Heute</button>
        <button class="filter-chip ${filterState.range === 'yesterday' ? 'active' : ''}" data-filter data-filter-field="range" data-filter-value="yesterday">Gestern</button>
        <button class="filter-chip ${filterState.range === 'week' ? 'active' : ''}" data-filter data-filter-field="range" data-filter-value="week">7 Tage</button>
        <button class="filter-chip ${filterState.range === 'all' ? 'active' : ''}" data-filter data-filter-field="range" data-filter-value="all">Alle</button>
      </div>
      <div class="filter-group">
        <label>Art:</label>
        <button class="filter-chip ${filterState.kind === 'all' ? 'active' : ''}" data-filter data-filter-field="kind" data-filter-value="all">Alle</button>
        <button class="filter-chip ${filterState.kind === 'spoken' ? 'active' : ''}" data-filter data-filter-field="kind" data-filter-value="spoken">Hörbücher/Podcasts</button>
        <button class="filter-chip ${filterState.kind === 'music' ? 'active' : ''}" data-filter data-filter-field="kind" data-filter-value="music">Musik</button>
        <button class="filter-chip ${filterState.kind === 'pinned' ? 'active' : ''}" data-filter data-filter-field="kind" data-filter-value="pinned">Gemerkt</button>
      </div>
      <div class="filter-group">
        <input type="search" id="search" placeholder="Suchen..." value="${esc(filterState.query)}">
      </div>
      <div class="filter-group">
        <label for="around">Was lief um …?</label>
        <input type="datetime-local" id="around" value="${filterState.around ? toLocalInputValue(filterState.around) : ''}">
        ${filterState.around ? `<button data-action="clear-around">✕</button>` : ''}
      </div>
    </div>
    <div class="history-list">
  `;

  const filtered = filterHistory(history, filterState, Date.now());

  // Group by day
  const grouped = {};
  filtered.forEach(entry => {
    const date = new Date(entry.startedAt);
    const key = date.toLocaleDateString('de-DE');
    if (!grouped[key]) grouped[key] = [];
    grouped[key].push(entry);
  });

  Object.entries(grouped).forEach(([dateStr, entries]) => {
    html += `<h3>${esc(dayLabel(dateStr))}</h3>`;
    entries.forEach(entry => {
      const startTime = new Date(entry.startedAt).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
      const endTime = new Date(entry.lastSeenAt).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
      const positionStr = entry.source === 'recent' ? 'ohne Minute' : formatMs(entry.progressMs);
      const kindLabel = entry.kind === 'music' ? 'Musik' : entry.kind === 'podcast' ? 'Podcast' : 'Hörbuch';
      const imgAttr = entry.image ? ` src="${esc(entry.image)}" alt=""` : '';

      html += `
        <div class="history-entry">
          ${entry.image ? `<img${imgAttr} class="cover">` : ''}
          <div class="entry-content">
            <h4>${esc(entry.title)}</h4>
            <p>${esc(entry.subtitle)}</p>
            <p class="time">${startTime}–${endTime} · ${positionStr} · <span class="kind">${kindLabel}</span></p>
          </div>
          <div class="entry-buttons">
            <button data-action="resume" data-id="${esc(entry.id)}" title="Weiterhören">▶</button>
            <button data-action="open-spotify" data-id="${esc(entry.id)}" title="In Spotify öffnen">↗</button>
            <button data-action="toggle-pin" data-id="${esc(entry.id)}" title="Pin">${entry.pinned ? '📌' : '📍'}</button>
            <button data-action="delete-entry" data-id="${esc(entry.id)}" title="Löschen">🗑</button>
          </div>
        </div>
      `;
    });
  });

  if (filtered.length === 0) html += '<p class="muted">Keine Einträge für diesen Filter.</p>';
  html += '</div>';
  content.innerHTML = html;
}

async function fetchAudiobooksList() {
  const content = document.getElementById('books-content');
  const clientId = getStoredClientId();
  if (!clientId) {
    content.innerHTML = '<p>Client ID nicht gesetzt.</p>';
    return;
  }

  content.innerHTML = '<p>Lädt Hörbücher...</p>';

  try {
    const data = await getAudiobooks(clientId);
    if (!data?.items || data.items.length === 0) {
      content.innerHTML = '<p>Keine Hörbücher gefunden.</p>';
      return;
    }

    audiobooksList = data.items;
    renderBooksFromList();
  } catch (err) {
    content.innerHTML = `<p class="error">Fehler beim Laden: ${esc(err.message)}</p>`;
  }
}

function renderBooks() {
  const content = document.getElementById('books-content');
  if (!isLoggedIn()) {
    content.innerHTML = '<p>Bitte melde dich in den Einstellungen an.</p>';
    return;
  }

  if (audiobooksList) {
    renderBooksFromList();
  } else {
    content.innerHTML = '<p>Hörbücher werden beim Öffnen dieses Tabs geladen.</p>';
  }
}

function renderBooksFromList() {
  const content = document.getElementById('books-content');
  if (!audiobooksList) return;

  let html = '<button data-action="reload-books">↻ Aktualisieren</button><div class="books-list">';
  const booksState = JSON.parse(localStorage.getItem('sm.booksState') || '{}');

  audiobooksList.forEach(book => {
    const bookId = uriId(book.uri);
    const loading = loadingBookIds.has(bookId);
    const bookData = booksState[bookId];
    const resume = bookData?.resume;
    const finished = bookData?.finished;

    let statusHtml = '';
    if (loading) {
      statusHtml = '<p class="loading">Kapitel werden geladen...</p>';
    } else if (finished) {
      statusHtml = '<p class="finished">✓ Fertig</p>';
    } else if (resume) {
      statusHtml = `
        <p class="resume">
          Kapitel ${resume.index + 1}: ${esc(resume.chapter.name)} – ${formatMs(resume.positionMs)}
        </p>
        <button data-action="resume-book" data-book-id="${esc(bookId)}">▶ Weiterhören</button>
      `;
    }

    const imgAttr = book.images && book.images[0] ? ` src="${esc(book.images[0].url)}" alt=""` : '';
    html += `
      <div class="book-card">
        ${book.images && book.images[0] ? `<img${imgAttr} class="cover">` : ''}
        <h3>${esc(book.name)}</h3>
        ${statusHtml}
        <button data-action="load-book" data-book-id="${esc(bookId)}">Stand laden</button>
      </div>
    `;
  });

  html += '</div>';
  content.innerHTML = html;
}

async function loadBook(bookId) {
  const clientId = getStoredClientId();
  if (!clientId) {
    showToast('Client ID nicht gesetzt', 'error');
    return;
  }

  loadingBookIds.add(bookId);
  renderBooksFromList();

  try {
    let allChapters = [];
    let offset = 0;
    const limit = 50;

    while (true) {
      const response = await getAudiobookChapters(clientId, bookId, limit, offset);
      if (!response?.items) break;
      allChapters = allChapters.concat(response.items);
      if (response.items.length < limit) break;
      offset += limit;
    }

    const resume = computeBookResume(allChapters);
    const booksState = JSON.parse(localStorage.getItem('sm.booksState') || '{}');
    booksState[bookId] = {
      resume,
      finished: !resume,
      loadedAt: Date.now(),
    };
    localStorage.setItem('sm.booksState', JSON.stringify(booksState));

    loadingBookIds.delete(bookId);
    renderBooksFromList();
  } catch (err) {
    console.error('Load book error:', err);
    showToast(`Fehler beim Laden: ${err.message}`, 'error');
    loadingBookIds.delete(bookId);
    renderBooksFromList();
  }
}

async function resumeBook(bookId) {
  const booksState = JSON.parse(localStorage.getItem('sm.booksState') || '{}');
  const bookData = booksState[bookId];
  if (!bookData || !bookData.resume) {
    showToast('Keine Wiederaufnahmeposition gefunden', 'error');
    return;
  }

  const { chapter, positionMs } = bookData.resume;
  const entry = {
    uri: chapter.uri,
    bookUri: `spotify:audiobook:${bookId}`,
    progressMs: positionMs,
    type: 'chapter',
  };

  await playEntry(entry, positionMs);
}

function handleImportFile(event) {
  const file = event.target.files?.[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const imported = JSON.parse(e.target.result);
      if (!Array.isArray(imported)) throw new Error('Ungültiges Format');

      // Validate and filter entries
      const valid = imported.filter(entry => {
        if (typeof entry !== 'object' || entry === null) return false;
        if (typeof entry.id !== 'string' || typeof entry.uri !== 'string') return false;
        if (typeof entry.title !== 'string') return false;
        if (!Number.isFinite(entry.startedAt) || !Number.isFinite(entry.lastSeenAt)) return false;
        return true;
      });

      let history = JSON.parse(localStorage.getItem('sm.history') || '[]');
      const existing = new Set(history.map(h => h.id));

      valid.forEach(entry => {
        if (!existing.has(entry.id)) {
          history.push(entry);
        }
      });

      history.sort((a, b) => b.lastSeenAt - a.lastSeenAt);
      history = history.slice(0, MAX_HISTORY);
      localStorage.setItem('sm.history', JSON.stringify(history));

      renderHistory();
      showToast('Importiert!', 'success');
    } catch (err) {
      showToast(`Fehler beim Importieren: ${err.message}`, 'error');
    }
  };
  reader.readAsText(file);
  event.target.value = '';
}

function renderSettings() {
  const content = document.getElementById('settings-content');
  const clientId = getStoredClientId() || '';
  const connected = isLoggedIn();
  const redirectUri = getRedirectUri();

  let html = `
    <div class="settings-form">
      <h3>Spotify App</h3>
      <div class="form-group">
        <label for="clientId">Client ID:</label>
        <input type="text" id="clientId" value="${esc(clientId)}" placeholder="Von Spotify Developer Dashboard">
        <button data-action="save-client-id">Speichern</button>
      </div>

      <h3>Anmeldung</h3>
      <div class="form-group">
        <label>Redirect URI:</label>
        <code>${esc(redirectUri)}</code>
        <button data-action="copy-redirect-uri">Kopieren</button>
      </div>

      ${connected ? `<button data-action="do-logout">Abmelden</button>` : `<button data-action="do-login">Anmelden</button>`}

      <h3>Daten</h3>
      <div class="form-group">
        <button data-action="export-history">Verlauf exportieren</button>
        <button data-action="import-history">Verlauf importieren</button>
      </div>
      <input type="file" id="importFile" style="display:none" accept=".json">

      <h3>Anleitung</h3>
      <ol>
        <li>Erstelle eine App im <a href="https://developer.spotify.com/dashboard" target="_blank">Spotify Developer Dashboard</a></li>
        <li>Füge dein Spotify-Konto unter "User Management" hinzu und aktiviere "Web API"</li>
        <li>Kopiere die Client ID oben ein</li>
        <li>Gehe zu "Edit Settings" und setze die Redirect URI (siehe oben)</li>
        <li>Klicke auf "Anmelden"</li>
        <li>Die App speichert lokal, was du hörst. Premium ist erforderlich zum Steuern von Spotify.</li>
      </ol>

      <h3>Grenzen</h3>
      <ul>
        <li>Minutenstände für Musik werden nur erfasst, solange die App offen ist (Browser-Tab oder PWA können im Hintergrund gedrosselt werden)</li>
        <li>Für Hörbücher und Podcasts nutzt die App Spotifys eigene Positionen – Kapitel im Tab "Hörbücher" laden</li>
      </ul>

      <h3>Datenschutz</h3>
      <button data-action="clear-history">Verlauf löschen</button>
    </div>
  `;

  content.innerHTML = html;
}

function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 3000);
}

// Start the app when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initApp);
} else {
  initApp();
}
