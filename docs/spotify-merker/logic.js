// Reine Logik ohne Browser-/Netzwerkzugriff – wird von app.js genutzt und
// in test/logic.test.mjs getestet.

// Ab dieser Pause gilt dasselbe Stück als "neu gestartet" (neuer Verlaufseintrag).
export const SAME_SESSION_GAP_MS = 5 * 60 * 1000;
export const MAX_HISTORY = 2000;

// Kontexte, bei denen Spotify "offset.uri" beim Abspielen versteht.
const OFFSET_CONTEXTS = ['album', 'playlist', 'show', 'audiobook'];

export function uriType(uri) {
  return (uri || '').split(':')[1] || '';
}

export function uriId(uri) {
  const parts = (uri || '').split(':');
  return parts[parts.length - 1] || '';
}

// Spotify-Antwort von /me/player bzw. /me/player/currently-playing in ein
// schlankes Objekt umwandeln. Gibt null zurück, wenn nichts Brauchbares läuft.
export function normalizePlayback(pb) {
  if (!pb || !pb.item) return null;
  const item = pb.item;
  const contextUri = pb.context?.uri || null;
  const ctxType = uriType(contextUri);
  let title = item.name;
  let subtitle = '';
  let image = null;
  let spoken = false;
  let bookUri = null;

  if (item.type === 'track') {
    subtitle = (item.artists || []).map((a) => a.name).join(', ');
    image = pickImage(item.album?.images);
  } else if (item.type === 'episode' || item.type === 'chapter') {
    spoken = true;
    // Hörbuch-Kapitel kommen je nach Client als "chapter" oder als "episode"
    // mit einem Hörbuch als Kontext bzw. als "show".
    const book = item.audiobook || item.show || null;
    subtitle = book?.name || '';
    image = pickImage(item.images) || pickImage(book?.images);
    if (item.audiobook) bookUri = item.audiobook.uri;
    else if (ctxType === 'audiobook') bookUri = contextUri;
  } else {
    return null;
  }

  const kind = item.type === 'track' ? 'music' : bookUri || item.type === 'chapter' ? 'audiobook' : 'podcast';

  return {
    uri: item.uri,
    type: item.type,
    kind,
    spoken,
    title,
    subtitle,
    image,
    contextUri,
    bookUri,
    durationMs: item.duration_ms || 0,
    progressMs: pb.progress_ms || 0,
    isPlaying: !!pb.is_playing,
    webUrl: item.external_urls?.spotify || null,
  };
}

function pickImage(images) {
  if (!images || !images.length) return null;
  // mittlere Größe bevorzugen (~300px)
  const sorted = [...images].sort((a, b) => (a.width || 0) - (b.width || 0));
  return (sorted.find((i) => (i.width || 0) >= 200) || sorted[sorted.length - 1]).url;
}

// Eine Messung (normalisiert) in den Verlauf einarbeiten.
// Gibt einen NEUEN Verlauf zurück (neueste Einträge zuerst).
export function recordSample(history, sample, now) {
  if (!sample) return history;
  const last = history[0];
  if (last && last.uri === sample.uri && now - last.lastSeenAt <= SAME_SESSION_GAP_MS) {
    const updated = {
      ...last,
      progressMs: sample.progressMs,
      durationMs: sample.durationMs || last.durationMs,
      lastSeenAt: now,
      image: sample.image || last.image,
    };
    return [updated, ...history.slice(1)];
  }
  if (!sample.isPlaying && sample.progressMs === 0) return history;
  const entry = {
    id: `${now}-${Math.random().toString(36).slice(2, 8)}`,
    uri: sample.uri,
    type: sample.type,
    kind: sample.kind,
    spoken: sample.spoken,
    title: sample.title,
    subtitle: sample.subtitle,
    image: sample.image,
    contextUri: sample.contextUri,
    bookUri: sample.bookUri,
    webUrl: sample.webUrl,
    durationMs: sample.durationMs,
    startProgressMs: sample.progressMs,
    progressMs: sample.progressMs,
    startedAt: now,
    lastSeenAt: now,
    pinned: false,
    source: 'live',
  };
  return [entry, ...history].slice(0, MAX_HISTORY);
}

// Einträge aus /me/player/recently-played ergänzen (nur Musik, ohne Minutenstand),
// damit auch Lieder auftauchen, die gehört wurden, während die App zu war.
export function mergeRecentlyPlayed(history, items) {
  const result = [...history];
  for (const it of items || []) {
    const track = it.track;
    if (!track || !it.played_at) continue;
    const playedAt = Date.parse(it.played_at);
    const dup = result.some(
      (h) => h.uri === track.uri && Math.abs(h.lastSeenAt - playedAt) < 10 * 60 * 1000,
    );
    if (dup) continue;
    result.push({
      id: `r-${playedAt}-${uriId(track.uri)}`,
      uri: track.uri,
      type: 'track',
      kind: 'music',
      spoken: false,
      title: track.name,
      subtitle: (track.artists || []).map((a) => a.name).join(', '),
      image: pickImage(track.album?.images),
      contextUri: it.context?.uri || null,
      bookUri: null,
      webUrl: track.external_urls?.spotify || null,
      durationMs: track.duration_ms || 0,
      startProgressMs: 0,
      progressMs: 0,
      startedAt: playedAt - (track.duration_ms || 0),
      lastSeenAt: playedAt,
      pinned: false,
      source: 'recent',
    });
  }
  result.sort((a, b) => b.lastSeenAt - a.lastSeenAt);
  return result.slice(0, MAX_HISTORY);
}

// Der zuletzt gehörte Hörbuch-/Podcast-Eintrag, zu dem man zurückspringen
// möchte – aber nur, wenn gerade etwas anderes (oder nichts) läuft.
export function findResumeCandidate(history, current) {
  const spoken = history.find((h) => h.spoken);
  if (!spoken) return null;
  if (current && current.isPlaying && current.uri === spoken.uri) return null;
  return spoken;
}

// Request-Body für PUT /me/player/play, um genau diesen Eintrag an der
// gespeicherten Stelle fortzusetzen.
export function buildPlayBody(entry, positionMs = entry.progressMs) {
  const position_ms = Math.max(0, Math.floor(positionMs || 0));
  const ctx = entry.bookUri || entry.contextUri;
  if (ctx && OFFSET_CONTEXTS.includes(uriType(ctx))) {
    return { context_uri: ctx, offset: { uri: entry.uri }, position_ms };
  }
  return { uris: [entry.uri], position_ms };
}

// Aus der Kapitelliste eines Hörbuchs (mit resume_point) die Stelle bestimmen,
// an der man weiterhören sollte.
export function computeBookResume(chapters) {
  let lastIdx = -1;
  chapters.forEach((c, i) => {
    const rp = c.resume_point;
    if (rp && (rp.fully_played || rp.resume_position_ms > 0)) lastIdx = i;
  });
  if (lastIdx === -1) return null;
  let idx = lastIdx;
  let pos = chapters[idx].resume_point.resume_position_ms || 0;
  if (chapters[idx].resume_point.fully_played) {
    if (idx + 1 >= chapters.length) return { chapter: chapters[idx], index: idx, positionMs: 0, finished: true };
    idx += 1;
    pos = chapters[idx].resume_point?.resume_position_ms || 0;
  }
  return { chapter: chapters[idx], index: idx, positionMs: pos, finished: false };
}

// Zeitfilter für den Verlauf.
export function filterHistory(history, { range = 'all', query = '', kind = 'all', around = null }, now) {
  const q = query.trim().toLowerCase();
  const startOfToday = new Date(now);
  startOfToday.setHours(0, 0, 0, 0);
  const today = startOfToday.getTime();
  const bounds = {
    hour: [now - 3600e3, Infinity],
    today: [today, Infinity],
    yesterday: [today - 864e5, today],
    week: [now - 7 * 864e5, Infinity],
    all: [-Infinity, Infinity],
  }[range] || [-Infinity, Infinity];
  let [from, to] = bounds;
  if (around != null) {
    from = around - 30 * 60e3;
    to = around + 30 * 60e3;
  }
  return history.filter((h) => {
    if (kind === 'spoken' && !h.spoken) return false;
    if (kind === 'music' && h.spoken) return false;
    if (kind === 'pinned' && !h.pinned) return false;
    // Eintrag überlappt mit dem Zeitfenster?
    if (h.lastSeenAt < from || h.startedAt > to) return false;
    if (q && !`${h.title} ${h.subtitle}`.toLowerCase().includes(q)) return false;
    return true;
  });
}

export function formatMs(ms) {
  const total = Math.max(0, Math.floor((ms || 0) / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = (n) => String(n).padStart(2, '0');
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}
