import test from 'node:test';
import assert from 'node:assert/strict';
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
  SAME_SESSION_GAP_MS,
  MAX_HISTORY,
} from '../web/logic.js';

test('uriType extracts type from URI', () => {
  assert.equal(uriType('spotify:track:123'), 'track');
  assert.equal(uriType('spotify:episode:456'), 'episode');
  assert.equal(uriType('spotify:audiobook:789'), 'audiobook');
  assert.equal(uriType(''), '');
  assert.equal(uriType(null), '');
});

test('uriId extracts ID from URI', () => {
  assert.equal(uriId('spotify:track:abc123'), 'abc123');
  assert.equal(uriId('spotify:episode:def456'), 'def456');
  assert.equal(uriId(''), '');
  assert.equal(uriId(null), '');
});

test('normalizePlayback returns null for empty playback', () => {
  assert.equal(normalizePlayback(null), null);
  assert.equal(normalizePlayback({}), null);
  assert.equal(normalizePlayback({ item: null }), null);
});

test('normalizePlayback handles track', () => {
  const pb = {
    item: {
      type: 'track',
      name: 'Song Title',
      uri: 'spotify:track:123',
      duration_ms: 180000,
      artists: [{ name: 'Artist 1' }, { name: 'Artist 2' }],
      album: {
        name: 'Album',
        images: [
          { width: 64, height: 64, url: 'small.jpg' },
          { width: 300, height: 300, url: 'medium.jpg' },
          { width: 640, height: 640, url: 'large.jpg' },
        ],
      },
      external_urls: { spotify: 'https://open.spotify.com/track/123' },
    },
    progress_ms: 90000,
    is_playing: true,
  };

  const result = normalizePlayback(pb);
  assert.equal(result.kind, 'music');
  assert.equal(result.spoken, false);
  assert.equal(result.title, 'Song Title');
  assert.equal(result.subtitle, 'Artist 1, Artist 2');
  assert.equal(result.durationMs, 180000);
  assert.equal(result.progressMs, 90000);
  assert.equal(result.isPlaying, true);
});

test('normalizePlayback handles episode with audiobook context', () => {
  const pb = {
    item: {
      type: 'episode',
      name: 'Chapter 1',
      uri: 'spotify:episode:123',
      duration_ms: 3600000,
      audiobook: {
        name: 'My Audiobook',
        uri: 'spotify:audiobook:456',
        images: [{ width: 300, height: 300, url: 'cover.jpg' }],
      },
      images: [{ width: 300, height: 300, url: 'ep.jpg' }],
      external_urls: { spotify: 'https://open.spotify.com/episode/123' },
    },
    progress_ms: 1800000,
    is_playing: true,
  };

  const result = normalizePlayback(pb);
  assert.equal(result.kind, 'audiobook');
  assert.equal(result.spoken, true);
  assert.equal(result.bookUri, 'spotify:audiobook:456');
  assert.equal(result.subtitle, 'My Audiobook');
});

test('normalizePlayback handles chapter type', () => {
  const pb = {
    item: {
      type: 'chapter',
      name: 'Chapter 1',
      uri: 'spotify:episode:123',
      duration_ms: 3600000,
      audiobook: {
        name: 'My Audiobook',
        uri: 'spotify:audiobook:456',
        images: [{ width: 300, height: 300, url: 'cover.jpg' }],
      },
      images: [],
      external_urls: { spotify: 'https://open.spotify.com/episode/123' },
    },
    progress_ms: 0,
    is_playing: false,
  };

  const result = normalizePlayback(pb);
  assert.equal(result.kind, 'audiobook');
  assert.equal(result.bookUri, 'spotify:audiobook:456');
});

test('recordSample creates new entry', () => {
  const sample = {
    uri: 'spotify:track:123',
    type: 'track',
    kind: 'music',
    spoken: false,
    title: 'Song',
    subtitle: 'Artist',
    image: 'img.jpg',
    durationMs: 180000,
    progressMs: 45000,
    isPlaying: true,
  };

  const history = [];
  const now = Date.now();
  const result = recordSample(history, sample, now);

  assert.equal(result.length, 1);
  assert.equal(result[0].uri, 'spotify:track:123');
  assert.equal(result[0].source, 'live');
  assert.equal(result[0].pinned, false);
  assert.equal(result[0].startProgressMs, 45000);
});

test('recordSample updates existing entry within SAME_SESSION_GAP_MS', () => {
  const sample1 = {
    uri: 'spotify:track:123',
    type: 'track',
    kind: 'music',
    spoken: false,
    title: 'Song',
    subtitle: 'Artist',
    image: 'img.jpg',
    durationMs: 180000,
    progressMs: 45000,
    isPlaying: true,
  };

  let history = recordSample([], sample1, 1000);
  assert.equal(history.length, 1);
  const entryId = history[0].id;

  const sample2 = { ...sample1, progressMs: 50000 };
  history = recordSample(history, sample2, 1000 + 60000); // 60 seconds later
  assert.equal(history.length, 1);
  assert.equal(history[0].id, entryId);
  assert.equal(history[0].progressMs, 50000);
});

test('recordSample creates new entry after SAME_SESSION_GAP_MS', () => {
  const sample1 = {
    uri: 'spotify:track:123',
    type: 'track',
    kind: 'music',
    spoken: false,
    title: 'Song',
    subtitle: 'Artist',
    image: 'img.jpg',
    durationMs: 180000,
    progressMs: 45000,
    isPlaying: true,
  };

  let history = recordSample([], sample1, 1000);
  assert.equal(history.length, 1);
  const oldEntryId = history[0].id;

  const sample2 = { ...sample1, progressMs: 50000 };
  history = recordSample(history, sample2, 1000 + SAME_SESSION_GAP_MS + 1000);
  assert.equal(history.length, 2);
  assert.notEqual(history[0].id, oldEntryId);
});

test('recordSample ignores paused tracks at 0 progress', () => {
  const sample = {
    uri: 'spotify:track:123',
    type: 'track',
    kind: 'music',
    spoken: false,
    title: 'Song',
    subtitle: 'Artist',
    image: 'img.jpg',
    durationMs: 180000,
    progressMs: 0,
    isPlaying: false,
  };

  const history = [];
  const result = recordSample(history, sample, 1000);
  assert.equal(result.length, 0);
});

test('recordSample respects MAX_HISTORY limit', () => {
  let history = [];
  const sample = {
    uri: 'spotify:track:123',
    type: 'track',
    kind: 'music',
    spoken: false,
    title: 'Song',
    subtitle: 'Artist',
    image: 'img.jpg',
    durationMs: 180000,
    progressMs: 45000,
    isPlaying: true,
  };

  for (let i = 0; i < MAX_HISTORY + 100; i++) {
    sample.uri = `spotify:track:${i}`;
    history = recordSample(history, sample, i * 1000);
  }

  assert.equal(history.length, MAX_HISTORY);
});

test('mergeRecentlyPlayed deduplicates entries', () => {
  const now = Date.now();
  const playedAtTime = now - 30000; // 30 seconds ago
  const playedAtIso = new Date(playedAtTime).toISOString();

  const history = [
    {
      id: '1',
      uri: 'spotify:track:123',
      type: 'track',
      kind: 'music',
      title: 'Song',
      lastSeenAt: playedAtTime,
    },
  ];

  const recentlyPlayed = [
    {
      track: {
        uri: 'spotify:track:123',
        name: 'Song',
        artists: [],
        album: { images: [] },
        duration_ms: 180000,
        external_urls: { spotify: 'url' },
      },
      played_at: playedAtIso,
    },
  ];

  const result = mergeRecentlyPlayed(history, recentlyPlayed);
  assert.equal(result.length, 1); // Should not add duplicate
});

test('mergeRecentlyPlayed adds new entries', () => {
  const history = [];

  const recentlyPlayed = [
    {
      track: {
        uri: 'spotify:track:123',
        name: 'Song',
        artists: [{ name: 'Artist' }],
        album: { images: [] },
        duration_ms: 180000,
        external_urls: { spotify: 'https://open.spotify.com/track/123' },
      },
      played_at: '2024-01-01T01:23:20Z',
    },
  ];

  const result = mergeRecentlyPlayed(history, recentlyPlayed);
  assert.equal(result.length, 1);
  assert.equal(result[0].source, 'recent');
  assert.equal(result[0].uri, 'spotify:track:123');
});

test('findResumeCandidate returns null if no spoken content', () => {
  const history = [
    { uri: 'spotify:track:1', kind: 'music', spoken: false },
  ];
  const current = null;

  const result = findResumeCandidate(history, current);
  assert.equal(result, null);
});

test('findResumeCandidate returns most recent spoken entry', () => {
  const history = [
    { uri: 'spotify:track:1', kind: 'music', spoken: false, lastSeenAt: 1000 },
    { uri: 'spotify:episode:2', kind: 'podcast', spoken: true, lastSeenAt: 3000 },
    { uri: 'spotify:episode:3', kind: 'audiobook', spoken: true, lastSeenAt: 2000 },
  ];
  const current = null;

  const result = findResumeCandidate(history, current);
  assert.equal(result.uri, 'spotify:episode:2');
});

test('findResumeCandidate returns null if current playing same spoken track', () => {
  const history = [
    { uri: 'spotify:episode:2', kind: 'podcast', spoken: true, lastSeenAt: 3000 },
  ];
  const current = {
    uri: 'spotify:episode:2',
    isPlaying: true,
  };

  const result = findResumeCandidate(history, current);
  assert.equal(result, null);
});

test('buildPlayBody with audiobook context', () => {
  const entry = {
    uri: 'spotify:episode:123',
    contextUri: 'spotify:audiobook:456',
    bookUri: 'spotify:audiobook:456',
    progressMs: 1800000,
  };

  const result = buildPlayBody(entry, 1800000);
  assert.deepEqual(result, {
    context_uri: 'spotify:audiobook:456',
    offset: { uri: 'spotify:episode:123' },
    position_ms: 1800000,
  });
});

test('buildPlayBody with playlist context', () => {
  const entry = {
    uri: 'spotify:track:123',
    contextUri: 'spotify:playlist:456',
    progressMs: 45000,
  };

  const result = buildPlayBody(entry);
  assert.deepEqual(result, {
    context_uri: 'spotify:playlist:456',
    offset: { uri: 'spotify:track:123' },
    position_ms: 45000,
  });
});

test('buildPlayBody without context', () => {
  const entry = {
    uri: 'spotify:track:123',
    contextUri: null,
    progressMs: 45000,
  };

  const result = buildPlayBody(entry);
  assert.deepEqual(result, {
    uris: ['spotify:track:123'],
    position_ms: 45000,
  });
});

test('computeBookResume with no progress', () => {
  const chapters = [
    { name: 'Ch 1', uri: 'ep:1', resume_point: { fully_played: false, resume_position_ms: 0 } },
    { name: 'Ch 2', uri: 'ep:2', resume_point: { fully_played: false, resume_position_ms: 0 } },
  ];

  const result = computeBookResume(chapters);
  assert.equal(result, null);
});

test('computeBookResume in middle of chapter', () => {
  const chapters = [
    { name: 'Ch 1', uri: 'ep:1', resume_point: { fully_played: true, resume_position_ms: 0 } },
    { name: 'Ch 2', uri: 'ep:2', resume_point: { fully_played: false, resume_position_ms: 500000 } },
  ];

  const result = computeBookResume(chapters);
  assert.equal(result.index, 1);
  assert.equal(result.positionMs, 500000);
  assert.equal(result.finished, false);
});

test('computeBookResume when chapter fully played, go to next', () => {
  const chapters = [
    { name: 'Ch 1', uri: 'ep:1', resume_point: { fully_played: true, resume_position_ms: 0 } },
    { name: 'Ch 2', uri: 'ep:2', resume_point: { fully_played: true, resume_position_ms: 0 } },
  ];

  const result = computeBookResume(chapters);
  assert.equal(result.index, 1);
  assert.equal(result.finished, true);
});

test('filterHistory by time range', () => {
  const now = Date.now();
  const history = [
    {
      title: 'Song',
      subtitle: 'Artist',
      kind: 'music',
      spoken: false,
      pinned: false,
      startedAt: now - 10000,
      lastSeenAt: now,
    },
    {
      title: 'Song 2',
      subtitle: 'Artist 2',
      kind: 'music',
      spoken: false,
      pinned: false,
      startedAt: now - 3600000 * 2,
      lastSeenAt: now - 3600000 * 2 + 1000,
    },
  ];

  const resultHour = filterHistory(history, { range: 'hour', query: '', kind: 'all', around: null }, now);
  assert.equal(resultHour.length, 1);

  const resultAll = filterHistory(history, { range: 'all', query: '', kind: 'all', around: null }, now);
  assert.equal(resultAll.length, 2);
});

test('filterHistory by kind (spoken/music)', () => {
  const now = Date.now();
  const history = [
    {
      title: 'Song',
      subtitle: 'Artist',
      kind: 'music',
      spoken: false,
      pinned: false,
      startedAt: now - 10000,
      lastSeenAt: now,
    },
    {
      title: 'Podcast',
      subtitle: 'Show',
      kind: 'podcast',
      spoken: true,
      pinned: false,
      startedAt: now - 10000,
      lastSeenAt: now,
    },
  ];

  const resultMusic = filterHistory(history, { range: 'all', query: '', kind: 'music', around: null }, now);
  assert.equal(resultMusic.length, 1);
  assert.equal(resultMusic[0].kind, 'music');

  const resultSpoken = filterHistory(history, { range: 'all', query: '', kind: 'spoken', around: null }, now);
  assert.equal(resultSpoken.length, 1);
  assert.equal(resultSpoken[0].spoken, true);
});

test('filterHistory by search query', () => {
  const now = Date.now();
  const history = [
    {
      title: 'My Favorite Song',
      subtitle: 'The Artists',
      kind: 'music',
      spoken: false,
      pinned: false,
      startedAt: now - 10000,
      lastSeenAt: now,
    },
    {
      title: 'Another Track',
      subtitle: 'Different People',
      kind: 'music',
      spoken: false,
      pinned: false,
      startedAt: now - 10000,
      lastSeenAt: now,
    },
  ];

  const result = filterHistory(history, { range: 'all', query: 'favorite', kind: 'all', around: null }, now);
  assert.equal(result.length, 1);
  assert.equal(result[0].title, 'My Favorite Song');
});

test('filterHistory by pinned', () => {
  const now = Date.now();
  const history = [
    {
      title: 'Pinned Song',
      subtitle: 'Artist',
      kind: 'music',
      spoken: false,
      pinned: true,
      startedAt: now - 10000,
      lastSeenAt: now,
    },
    {
      title: 'Unpinned Song',
      subtitle: 'Artist',
      kind: 'music',
      spoken: false,
      pinned: false,
      startedAt: now - 10000,
      lastSeenAt: now,
    },
  ];

  const result = filterHistory(history, { range: 'all', query: '', kind: 'pinned', around: null }, now);
  assert.equal(result.length, 1);
  assert.equal(result[0].pinned, true);
});

test('formatMs formats milliseconds correctly', () => {
  assert.equal(formatMs(0), '0:00');
  assert.equal(formatMs(5000), '0:05');
  assert.equal(formatMs(60000), '1:00');
  assert.equal(formatMs(65000), '1:05');
  assert.equal(formatMs(3600000), '1:00:00');
  assert.equal(formatMs(3665000), '1:01:05');
  assert.equal(formatMs(null), '0:00');
});
