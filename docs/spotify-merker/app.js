// Main application logic
import {
  getStoredClientId,
  storeClientId,
  getStoredToken,
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
} from './logic.js';

// DOM Elements
let currentTab = 'now';
let pollInterval = null;
let pollTimerHandle = null;
let pendingResume = null;

const esc = (str) => {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
};

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
  const error = params.get('error');

  if (code) {
    const clientId = getStoredClientId();
    if (clientId) {
      try {
        await exchangeCode(code, clientId);
        showToast('Angemeldet!', 'success');
      } catch (err) {
        showToast(`Anmeldung fehlgeschlagen: ${err.message}`, 'error');
      }
    }
    // Clean up URL
    history.replaceState({}, '', location.pathname);
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

  // Start polling
  startPolling();

  // Update on visibility change
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      // Reduce polling interval when hidden
      clearInterval(pollTimerHandle);
      pollInterval = 30000;
      schedulePoll();
    } else {
      // Resume normal polling and do a refresh
      clearInterval(pollTimerHandle);
      pollInterval = 5000;
      schedulePoll();
      poll();
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

    // Record sample
    history = recordSample(history, sample, Date.now());

    // Merge recently played periodically (when returning to app, every 5 minutes)
    const lastMerge = parseInt(localStorage.getItem('sm.lastMerge') || '0');
    if (Date.now() - lastMerge > 5 * 60 * 1000 || !document.hidden) {
      const recentlyPlayed = await getRecentlyPlayed(clientId, 50);
      if (recentlyPlayed?.items) {
        history = mergeRecentlyPlayed(history, recentlyPlayed.items);
        localStorage.setItem('sm.lastMerge', String(Date.now()));
      }
    }

    localStorage.setItem('sm.history', JSON.stringify(history));

    // Update UI
    renderNow();
    renderHistory();
    renderBooks();
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
  const isConnected = isLoggedIn();
  header.innerHTML = `
    <h1>Spotify-Merker</h1>
    <div class="status">${isConnected ? '✓ Verbunden' : '✗ Nicht verbunden'}</div>
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

  document.querySelectorAll('.tab-button').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });
}

function switchTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab-button').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
  document.querySelectorAll('[data-tab-content]').forEach(el => {
    el.style.display = el.dataset.tabContent === tab ? 'block' : 'none';
  });
}

function renderNow() {
  const content = document.getElementById('now-content');
  if (!isLoggedIn()) {
    content.innerHTML = '<p>Bitte melden Sie sich in den Einstellungen an.</p>';
    return;
  }

  const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
  const current = JSON.parse(localStorage.getItem('sm.current') || 'null');

  let html = '';

  // Resume banner
  const resume = findResumeCandidate(history, current);
  if (resume) {
    const ago = formatAgo(Date.now() - resume.lastSeenAt);
    html += `
      <div class="banner">
        <h3>Zurück zu ${esc(resume.title)}</h3>
        <p>${esc(resume.subtitle)} – ${formatMs(resume.progressMs)} vor ${ago}</p>
        <button onclick="app.resume('${resume.id}', ${resume.progressMs})">▶ Weiterhören</button>
        <button onclick="app.openInSpotify('${resume.webUrl}')">↗ In Spotify öffnen</button>
      </div>
    `;
  }

  // Current playback
  if (current && current.isPlaying) {
    const progress = current.progressMs + (Date.now() - current.lastSeenAt);
    const percent = current.durationMs > 0 ? (progress / current.durationMs) * 100 : 0;
    html += `
      <div class="card now-card">
        ${current.image ? `<img src="${current.image}" alt="" class="cover">` : ''}
        <div class="card-content">
          <h2>${esc(current.title)}</h2>
          <p>${esc(current.subtitle)}</p>
          <p class="progress">${formatMs(progress)} / ${formatMs(current.durationMs)}</p>
          <div class="progress-bar">
            <div class="progress-fill" style="width: ${percent}%"></div>
          </div>
          <button onclick="app.pin('${current.id}')">📌 Merken</button>
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
    content.innerHTML = '<p>Bitte melden Sie sich in den Einstellungen an.</p>';
    return;
  }

  const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
  const filterState = JSON.parse(localStorage.getItem('sm.filterState') || '{"range":"all","query":"","kind":"all","around":null}');

  let html = `
    <div class="filters">
      <div class="filter-group">
        <label>Zeitraum:</label>
        <button class="filter-chip ${filterState.range === 'hour' ? 'active' : ''}" onclick="app.setFilter('range', 'hour')">Letzte Stunde</button>
        <button class="filter-chip ${filterState.range === 'today' ? 'active' : ''}" onclick="app.setFilter('range', 'today')">Heute</button>
        <button class="filter-chip ${filterState.range === 'yesterday' ? 'active' : ''}" onclick="app.setFilter('range', 'yesterday')">Gestern</button>
        <button class="filter-chip ${filterState.range === 'week' ? 'active' : ''}" onclick="app.setFilter('range', 'week')">7 Tage</button>
        <button class="filter-chip ${filterState.range === 'all' ? 'active' : ''}" onclick="app.setFilter('range', 'all')">Alle</button>
      </div>
      <div class="filter-group">
        <label>Art:</label>
        <button class="filter-chip ${filterState.kind === 'all' ? 'active' : ''}" onclick="app.setFilter('kind', 'all')">Alle</button>
        <button class="filter-chip ${filterState.kind === 'spoken' ? 'active' : ''}" onclick="app.setFilter('kind', 'spoken')">Hörbücher/Podcasts</button>
        <button class="filter-chip ${filterState.kind === 'music' ? 'active' : ''}" onclick="app.setFilter('kind', 'music')">Musik</button>
        <button class="filter-chip ${filterState.kind === 'pinned' ? 'active' : ''}" onclick="app.setFilter('kind', 'pinned')">Gemerkt</button>
      </div>
      <div class="filter-group">
        <input type="search" id="search" placeholder="Suchen..." value="${esc(filterState.query)}" onchange="app.setFilter('query', this.value)">
      </div>
      <div class="filter-group">
        <input type="datetime-local" id="around" onchange="app.setAround(this.value)">
        ${filterState.around ? `<button onclick="app.clearAround()">✕</button>` : ''}
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
    html += `<h3>${dateStr}</h3>`;
    entries.forEach(entry => {
      const startTime = new Date(entry.startedAt).toLocaleTimeString('de-DE', {
        hour: '2-digit',
        minute: '2-digit',
      });
      const endTime = new Date(entry.lastSeenAt).toLocaleTimeString('de-DE', {
        hour: '2-digit',
        minute: '2-digit',
      });
      const positionStr = entry.source === 'recent'
        ? 'ohne Minute'
        : formatMs(entry.progressMs);

      html += `
        <div class="history-entry">
          ${entry.image ? `<img src="${entry.image}" alt="" class="cover">` : ''}
          <div class="entry-content">
            <h4>${esc(entry.title)}</h4>
            <p>${esc(entry.subtitle)}</p>
            <p class="time">${startTime}–${endTime} · ${positionStr}</p>
          </div>
          <div class="entry-buttons">
            <button onclick="app.resume('${entry.id}', ${entry.progressMs})" title="Weiterhören">▶</button>
            <button onclick="app.openInSpotify('${entry.webUrl}')" title="In Spotify öffnen">↗</button>
            <button onclick="app.togglePin('${entry.id}')" title="Pin">${entry.pinned ? '📌' : '📍'}</button>
            <button onclick="app.deleteEntry('${entry.id}')" title="Löschen">🗑</button>
          </div>
        </div>
      `;
    });
  });

  html += '</div>';
  content.innerHTML = html;
}

function renderBooks() {
  const content = document.getElementById('books-content');
  if (!isLoggedIn()) {
    content.innerHTML = '<p>Bitte melden Sie sich in den Einstellungen an.</p>';
    return;
  }

  content.innerHTML = '<p>Lädt Hörbücher...</p>';

  const clientId = getStoredClientId();
  if (!clientId) {
    content.innerHTML = '<p>Client ID nicht gesetzt.</p>';
    return;
  }

  getAudiobooks(clientId)
    .then(data => {
      if (!data?.items || data.items.length === 0) {
        content.innerHTML = '<p>Keine Hörbücher gefunden.</p>';
        return;
      }

      let html = '<div class="books-list">';
      const booksState = JSON.parse(localStorage.getItem('sm.booksState') || '{}');

      data.items.forEach(book => {
        const bookId = uriId(book.uri);
        const loading = booksState[bookId]?.loading;
        const resume = booksState[bookId]?.resume;
        const finished = booksState[bookId]?.finished;

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
            <button onclick="app.resumeBook('${bookId}')">▶ Weiterhören</button>
          `;
        }

        html += `
          <div class="book-card">
            ${book.images && book.images[0] ? `<img src="${book.images[0].url}" alt="" class="cover">` : ''}
            <h3>${esc(book.name)}</h3>
            ${statusHtml}
            <button onclick="app.loadBook('${bookId}')">Stand laden</button>
          </div>
        `;
      });

      html += '</div>';
      content.innerHTML = html;
    })
    .catch(err => {
      content.innerHTML = `<p class="error">Fehler beim Laden: ${esc(err.message)}</p>`;
    });
}

function renderSettings() {
  const content = document.getElementById('settings-content');
  const clientId = getStoredClientId() || '';
  const isConnected = isLoggedIn();
  const redirectUri = getRedirectUri();

  let html = `
    <div class="settings-form">
      <h3>Spotify App</h3>
      <div class="form-group">
        <label for="clientId">Client ID:</label>
        <input type="text" id="clientId" value="${esc(clientId)}" placeholder="Von Spotify Developer Dashboard">
        <button onclick="app.saveClientId()">Speichern</button>
      </div>

      <h3>Anmeldung</h3>
      <div class="form-group">
        <label>Redirect URI:</label>
        <code>${esc(redirectUri)}</code>
        <button onclick="app.copyRedirectUri()">Kopieren</button>
      </div>

      ${isConnected
        ? `<button onclick="app.doLogout()">Abmelden</button>`
        : `<button onclick="app.doLogin()">Anmelden</button>`
      }

      <h3>Daten</h3>
      <div class="form-group">
        <button onclick="app.exportHistory()">Verlauf exportieren</button>
        <button onclick="app.importHistory()">Verlauf importieren</button>
      </div>
      <input type="file" id="importFile" style="display:none" accept=".json">

      <h3>Anleitung</h3>
      <ol>
        <li>Erstelle eine App im <a href="https://developer.spotify.com/dashboard" target="_blank">Spotify Developer Dashboard</a></li>
        <li>Kopiere die Client ID oben ein</li>
        <li>Gehe zu "Edit Settings" und setze die Redirect URI (siehe oben)</li>
        <li>Klicke auf "Anmelden"</li>
        <li>Die App speichert lokal, was du hörst. Premium ist erforderlich zum Steuern von Spotify.</li>
      </ol>

      <h3>Datenschutz</h3>
      <button onclick="app.clearHistory()">Verlauf löschen</button>
    </div>
  `;

  content.innerHTML = html;
  document.getElementById('importFile').addEventListener('change', app.handleImportFile);
}

// Export functions for onclick handlers
window.app = {
  setFilter(field, value) {
    const filterState = JSON.parse(localStorage.getItem('sm.filterState') || '{"range":"all","query":"","kind":"all","around":null}');
    filterState[field] = value;
    localStorage.setItem('sm.filterState', JSON.stringify(filterState));
    renderHistory();
  },

  setAround(value) {
    if (!value) return;
    const filterState = JSON.parse(localStorage.getItem('sm.filterState') || '{"range":"all","query":"","kind":"all","around":null}');
    filterState.around = new Date(value).getTime();
    localStorage.setItem('sm.filterState', JSON.stringify(filterState));
    renderHistory();
  },

  clearAround() {
    const filterState = JSON.parse(localStorage.getItem('sm.filterState') || '{"range":"all","query":"","kind":"all","around":null}');
    filterState.around = null;
    localStorage.setItem('sm.filterState', JSON.stringify(filterState));
    renderHistory();
  },

  pin(entryId) {
    const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
    const entry = history.find(e => e.id === entryId);
    if (entry) {
      entry.pinned = true;
      localStorage.setItem('sm.history', JSON.stringify(history));
      renderHistory();
      showToast('Gemerkt!', 'success');
    }
  },

  togglePin(entryId) {
    const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
    const entry = history.find(e => e.id === entryId);
    if (entry) {
      entry.pinned = !entry.pinned;
      localStorage.setItem('sm.history', JSON.stringify(history));
      renderHistory();
    }
  },

  async resume(entryId, positionMs) {
    const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
    const entry = history.find(e => e.id === entryId);
    if (!entry) return;

    const clientId = getStoredClientId();
    if (!clientId) {
      showToast('Client ID nicht gesetzt', 'error');
      return;
    }

    try {
      const body = buildPlayBody(entry, positionMs);
      const devices = await getDevices(clientId);

      let deviceId = null;
      if (devices?.devices && devices.devices.length > 0) {
        // Prefer Smartphone
        const smartphone = devices.devices.find(d => d.type === 'Smartphone');
        deviceId = smartphone ? smartphone.id : devices.devices[0].id;
        await playTrack(clientId, deviceId, body);
        showToast(`Weiterhören bei ${formatMs(positionMs)}`, 'success');
        // Trigger immediate poll
        poll();
      } else {
        // No device active, open in Spotify
        pendingResume = { entry, positionMs };
        const type = entry.type === 'episode' || entry.type === 'chapter' ? 'episode' : entry.type;
        const url = entry.webUrl || `https://open.spotify.com/${type}/${uriId(entry.uri)}`;
        window.open(url, '_blank');
        showToast('Spotify wird geöffnet – komm danach zurück, dann springe ich zur Stelle.', 'info');
      }
    } catch (err) {
      console.error('Resume error:', err);
      if (err.status === 403 && err.reason === 'PREMIUM_REQUIRED') {
        showToast('Fernsteuerung braucht Spotify Premium – öffne Spotify stattdessen', 'error');
        const url = entry.webUrl || `https://open.spotify.com/${entry.type}/${uriId(entry.uri)}`;
        window.open(url, '_blank');
      } else {
        showToast(`Fehler: ${err.message}`, 'error');
      }
    }
  },

  openInSpotify(url) {
    if (url) {
      window.open(url, '_blank');
    }
  },

  deleteEntry(entryId) {
    if (!confirm('Wirklich löschen?')) return;
    const history = JSON.parse(localStorage.getItem('sm.history') || '[]');
    const filtered = history.filter(e => e.id !== entryId);
    localStorage.setItem('sm.history', JSON.stringify(filtered));
    renderHistory();
  },

  async loadBook(bookId) {
    const clientId = getStoredClientId();
    if (!clientId) {
      showToast('Client ID nicht gesetzt', 'error');
      return;
    }

    // Mark as loading
    const booksState = JSON.parse(localStorage.getItem('sm.booksState') || '{}');
    booksState[bookId] = { ...booksState[bookId], loading: true };
    localStorage.setItem('sm.booksState', JSON.stringify(booksState));
    renderBooks();

    try {
      let allChapters = [];
      let offset = 0;
      const limit = 50;

      // Fetch all chapters
      while (true) {
        const response = await getAudiobookChapters(clientId, bookId, limit, offset);
        if (!response?.items) break;
        allChapters = allChapters.concat(response.items);
        if (response.items.length < limit) break;
        offset += limit;
      }

      const resume = computeBookResume(allChapters);
      booksState[bookId] = {
        chapters: allChapters,
        resume,
        finished: !resume,
        loading: false,
      };
      localStorage.setItem('sm.booksState', JSON.stringify(booksState));
      renderBooks();
    } catch (err) {
      console.error('Load book error:', err);
      showToast(`Fehler beim Laden: ${err.message}`, 'error');
      booksState[bookId] = { ...booksState[bookId], loading: false };
      localStorage.setItem('sm.booksState', JSON.stringify(booksState));
      renderBooks();
    }
  },

  async resumeBook(bookId) {
    const booksState = JSON.parse(localStorage.getItem('sm.booksState') || '{}');
    const bookData = booksState[bookId];
    if (!bookData || !bookData.resume) {
      showToast('Keine Wiederaufnahmeposition gefunden', 'error');
      return;
    }

    const { chapter, positionMs } = bookData.resume;
    const clientId = getStoredClientId();

    try {
      const body = buildPlayBody(
        {
          uri: chapter.uri,
          bookUri: `spotify:audiobook:${bookId}`,
        },
        positionMs
      );

      const devices = await getDevices(clientId);
      let deviceId = null;
      if (devices?.devices && devices.devices.length > 0) {
        const smartphone = devices.devices.find(d => d.type === 'Smartphone');
        deviceId = smartphone ? smartphone.id : devices.devices[0].id;
        await playTrack(clientId, deviceId, body);
        showToast(`Weiterhören bei ${formatMs(positionMs)}`, 'success');
        poll();
      } else {
        showToast('Kein aktives Gerät. Öffne Spotify und versuche es erneut.', 'error');
      }
    } catch (err) {
      console.error('Resume book error:', err);
      showToast(`Fehler: ${err.message}`, 'error');
    }
  },

  saveClientId() {
    const input = document.getElementById('clientId');
    const clientId = input.value.trim();
    if (!clientId) {
      showToast('Client ID erforderlich', 'error');
      return;
    }
    storeClientId(clientId);
    showToast('Client ID gespeichert', 'success');
  },

  doLogin() {
    const clientId = getStoredClientId();
    if (!clientId) {
      showToast('Client ID erforderlich', 'error');
      return;
    }
    initiateLogin(clientId);
  },

  doLogout() {
    logout();
    renderHeader();
    renderNow();
    renderHistory();
    renderBooks();
    showToast('Abgemeldet', 'success');
  },

  copyRedirectUri() {
    const uri = getRedirectUri();
    navigator.clipboard.writeText(uri).then(() => {
      showToast('Kopiert!', 'success');
    });
  },

  exportHistory() {
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
  },

  importHistory() {
    document.getElementById('importFile').click();
  },

  handleImportFile(event) {
    const file = event.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const imported = JSON.parse(e.target.result);
        if (!Array.isArray(imported)) throw new Error('Ungültiges Format');

        let history = JSON.parse(localStorage.getItem('sm.history') || '[]');
        const existing = new Set(history.map(h => h.id));

        imported.forEach(entry => {
          if (!existing.has(entry.id)) {
            history.push(entry);
          }
        });

        history.sort((a, b) => b.lastSeenAt - a.lastSeenAt);
        history = history.slice(0, 2000);
        localStorage.setItem('sm.history', JSON.stringify(history));

        renderHistory();
        showToast('Importiert!', 'success');
      } catch (err) {
        showToast(`Fehler beim Importieren: ${err.message}`, 'error');
      }
    };
    reader.readAsText(file);
  },

  clearHistory() {
    if (!confirm('Wirklich den gesamten Verlauf löschen?')) return;
    localStorage.removeItem('sm.history');
    renderHistory();
    showToast('Verlauf gelöscht', 'success');
  },
};

function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 3000);
}

function formatAgo(ms) {
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  return `${days}d`;
}

// Start the app when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initApp);
} else {
  initApp();
}
