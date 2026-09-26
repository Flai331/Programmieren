import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_merker/logic.dart';

void main() {
  group('entryKey', () {
    test('prefers spotifyUri', () {
      final entry = Entry(
        id: '1',
        key: '',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        spotifyUri: 'spotify:track:123',
        mediaId: 'media123',
        artUri: '',
        kind: 'music',
        durationMs: 0,
        startPositionMs: 0,
        positionMs: 0,
        startedAt: 0,
        lastSeenAt: 0,
        pinned: false,
      );
      expect(entryKey(entry), 'spotify:track:123');
    });

    test('falls back to mediaId', () {
      final entry = Entry(
        id: '1',
        key: '',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        spotifyUri: null,
        mediaId: 'media123',
        artUri: '',
        kind: 'music',
        durationMs: 0,
        startPositionMs: 0,
        positionMs: 0,
        startedAt: 0,
        lastSeenAt: 0,
        pinned: false,
      );
      expect(entryKey(entry), 'media123');
    });

    test('uses title|artist as fallback', () {
      final entry = Entry(
        id: '1',
        key: '',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        spotifyUri: null,
        mediaId: '',
        artUri: '',
        kind: 'music',
        durationMs: 0,
        startPositionMs: 0,
        positionMs: 0,
        startedAt: 0,
        lastSeenAt: 0,
        pinned: false,
      );
      expect(entryKey(entry), 'title|artist');
    });
  });

  group('isSpoken', () {
    test('detects episode URIs', () {
      final entry = Entry(
        id: '1',
        key: '',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        spotifyUri: 'spotify:episode:123',
        mediaId: '',
        artUri: '',
        kind: 'music',
        durationMs: 0,
        startPositionMs: 0,
        positionMs: 0,
        startedAt: 0,
        lastSeenAt: 0,
        pinned: false,
      );
      expect(isSpoken(entry), true);
    });

    test('detects long duration', () {
      final entry = Entry(
        id: '1',
        key: '',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        spotifyUri: null,
        mediaId: '',
        artUri: '',
        kind: 'music',
        durationMs: 20 * 60 * 1000, // 20 minutes
        startPositionMs: 0,
        positionMs: 0,
        startedAt: 0,
        lastSeenAt: 0,
        pinned: false,
      );
      expect(isSpoken(entry), true);
    });

    test('returns false for short music', () {
      final entry = Entry(
        id: '1',
        key: '',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        spotifyUri: 'spotify:track:123',
        mediaId: '',
        artUri: '',
        kind: 'music',
        durationMs: 3 * 60 * 1000, // 3 minutes
        startPositionMs: 0,
        positionMs: 0,
        startedAt: 0,
        lastSeenAt: 0,
        pinned: false,
      );
      expect(isSpoken(entry), false);
    });
  });

  group('applyEvents', () {
    test('creates new entry from event', () {
      final event = RawEvent(
        ts: 1000,
        reason: 'start',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        durationMs: 180000,
        positionMs: 0,
        mediaId: '',
        mediaUri: '',
        artUri: '',
        state: 'PLAYING',
        actions: 0,
        spotifyUri: '',
      );

      final result = applyEvents([], [event]);
      expect(result.length, 1);
      expect(result[0].title, 'Song 1');
    });

    test('updates entry within 5 minutes', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = Entry(
        id: '1',
        key: 'song1|artist1',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        spotifyUri: null,
        mediaId: '',
        artUri: '',
        kind: 'music',
        durationMs: 180000,
        startPositionMs: 0,
        positionMs: 30000,
        startedAt: now - 60000,
        lastSeenAt: now - 60000,
        pinned: false,
      );

      final event = RawEvent(
        ts: now,
        reason: 'state',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        durationMs: 180000,
        positionMs: 60000,
        mediaId: '',
        mediaUri: '',
        artUri: '',
        state: 'PLAYING',
        actions: 0,
        spotifyUri: '',
      );

      final result = applyEvents([entry], [event]);
      expect(result.length, 1);
      expect(result[0].positionMs, 60000);
      expect(result[0].lastSeenAt, now);
    });

    test('ignores paused with zero position', () {
      final event = RawEvent(
        ts: 1000,
        reason: 'state',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        durationMs: 180000,
        positionMs: 0,
        mediaId: '',
        mediaUri: '',
        artUri: '',
        state: 'PAUSED',
        actions: 0,
        spotifyUri: '',
      );

      final result = applyEvents([], [event]);
      expect(result.length, 0);
    });

    test('ignores empty title', () {
      final event = RawEvent(
        ts: 1000,
        reason: 'start',
        title: '',
        artist: 'Artist 1',
        album: 'Album 1',
        durationMs: 180000,
        positionMs: 0,
        mediaId: '',
        mediaUri: '',
        artUri: '',
        state: 'PLAYING',
        actions: 0,
        spotifyUri: '',
      );

      final result = applyEvents([], [event]);
      expect(result.length, 0);
    });

    test('enforces max 3000 entries', () {
      final entries = List.generate(
        3500,
        (i) => Entry(
          id: '$i',
          key: 'key$i',
          title: 'Song $i',
          artist: 'Artist $i',
          album: 'Album $i',
          spotifyUri: null,
          mediaId: '',
          artUri: '',
          kind: 'music',
          durationMs: 180000,
          startPositionMs: 0,
          positionMs: 0,
          startedAt: i,
          lastSeenAt: i,
          pinned: false,
        ),
      );

      final result = applyEvents(entries, []);
      expect(result.length, 3000);
    });
  });

  group('findResumeCandidate', () {
    test('finds most recent spoken entry', () {
      final history = [
        Entry(
          id: '1',
          key: 'key1',
          title: 'Song 1',
          artist: 'Artist 1',
          album: 'Album 1',
          spotifyUri: 'spotify:track:123',
          mediaId: '',
          artUri: '',
          kind: 'music',
          durationMs: 180000,
          startPositionMs: 0,
          positionMs: 0,
          startedAt: 1000,
          lastSeenAt: 1000,
          pinned: false,
        ),
        Entry(
          id: '2',
          key: 'key2',
          title: 'Chapter 1',
          artist: 'Audiobook',
          album: 'Album 2',
          spotifyUri: 'spotify:episode:456',
          mediaId: '',
          artUri: '',
          kind: 'spoken',
          durationMs: 3600000,
          startPositionMs: 0,
          positionMs: 1800000,
          startedAt: 2000,
          lastSeenAt: 2000,
          pinned: false,
        ),
      ];

      final candidate = findResumeCandidate(history, null);
      expect(candidate?.id, '2');
    });

    test('skips currently playing entry', () {
      final current = Current(
        title: 'Chapter 1',
        artist: 'Audiobook',
        album: 'Album',
        durationMs: 3600000,
        positionMs: 1800000,
        state: 'PLAYING',
        mediaId: '',
        mediaUri: '',
        artUri: '',
      );

      final history = [
        Entry(
          id: '2',
          key: 'key2',
          title: 'Chapter 1',
          artist: 'Audiobook',
          album: 'Album 2',
          spotifyUri: 'spotify:episode:456',
          mediaId: '',
          artUri: '',
          kind: 'spoken',
          durationMs: 3600000,
          startPositionMs: 0,
          positionMs: 1800000,
          startedAt: 2000,
          lastSeenAt: 2000,
          pinned: false,
        ),
        Entry(
          id: '3',
          key: 'key3',
          title: 'Chapter 2',
          artist: 'Audiobook',
          album: 'Album 2',
          spotifyUri: 'spotify:episode:789',
          mediaId: '',
          artUri: '',
          kind: 'spoken',
          durationMs: 3600000,
          startPositionMs: 0,
          positionMs: 500000,
          startedAt: 1000,
          lastSeenAt: 1000,
          pinned: false,
        ),
      ];

      final candidate = findResumeCandidate(history, current);
      expect(candidate?.id, '3');
    });
  });

  group('filterHistory', () {
    test('filters by time range', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final history = [
        Entry(
          id: '1',
          key: 'key1',
          title: 'Song 1',
          artist: 'Artist 1',
          album: 'Album 1',
          spotifyUri: null,
          mediaId: '',
          artUri: '',
          kind: 'music',
          durationMs: 180000,
          startPositionMs: 0,
          positionMs: 0,
          startedAt: now - 2 * 24 * 60 * 60 * 1000, // 2 days ago
          lastSeenAt: now - 2 * 24 * 60 * 60 * 1000,
          pinned: false,
        ),
        Entry(
          id: '2',
          key: 'key2',
          title: 'Song 2',
          artist: 'Artist 2',
          album: 'Album 2',
          spotifyUri: null,
          mediaId: '',
          artUri: '',
          kind: 'music',
          durationMs: 180000,
          startPositionMs: 0,
          positionMs: 0,
          startedAt: now - 1000,
          lastSeenAt: now - 1000,
          pinned: false,
        ),
      ];

      final result = filterHistory(
        history,
        FilterRange.today,
        FilterKind.all,
        '',
        null,
        now,
      );
      expect(result.length, 1);
      expect(result[0].id, '2');
    });

    test('filters by kind', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final history = [
        Entry(
          id: '1',
          key: 'key1',
          title: 'Song 1',
          artist: 'Artist 1',
          album: 'Album 1',
          spotifyUri: null,
          mediaId: '',
          artUri: '',
          kind: 'music',
          durationMs: 180000,
          startPositionMs: 0,
          positionMs: 0,
          startedAt: now,
          lastSeenAt: now,
          pinned: false,
        ),
        Entry(
          id: '2',
          key: 'key2',
          title: 'Chapter 1',
          artist: 'Audiobook',
          album: 'Album 2',
          spotifyUri: 'spotify:episode:456',
          mediaId: '',
          artUri: '',
          kind: 'spoken',
          durationMs: 3600000,
          startPositionMs: 0,
          positionMs: 0,
          startedAt: now,
          lastSeenAt: now,
          pinned: false,
        ),
      ];

      final result = filterHistory(
        history,
        FilterRange.all,
        FilterKind.spoken,
        '',
        null,
        now,
      );
      expect(result.length, 1);
      expect(result[0].kind, 'spoken');
    });

    test('filters by search query', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final history = [
        Entry(
          id: '1',
          key: 'key1',
          title: 'Song 1',
          artist: 'Artist A',
          album: 'Album 1',
          spotifyUri: null,
          mediaId: '',
          artUri: '',
          kind: 'music',
          durationMs: 180000,
          startPositionMs: 0,
          positionMs: 0,
          startedAt: now,
          lastSeenAt: now,
          pinned: false,
        ),
        Entry(
          id: '2',
          key: 'key2',
          title: 'Song 2',
          artist: 'Artist B',
          album: 'Album 2',
          spotifyUri: null,
          mediaId: '',
          artUri: '',
          kind: 'music',
          durationMs: 180000,
          startPositionMs: 0,
          positionMs: 0,
          startedAt: now,
          lastSeenAt: now,
          pinned: false,
        ),
      ];

      final result = filterHistory(
        history,
        FilterRange.all,
        FilterKind.all,
        'Artist A',
        null,
        now,
      );
      expect(result.length, 1);
      expect(result[0].artist, 'Artist A');
    });
  });

  group('formatMs', () {
    test('formats milliseconds correctly', () {
      expect(formatMs(0), '0:00');
      expect(formatMs(60000), '1:00');
      expect(formatMs(125000), '2:05');
      expect(formatMs(3661000), '1:01:01');
    });
  });

  group('formatAgo', () {
    test('formats recent time', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(formatAgo(now - 500, now), 'gerade eben');
      expect(formatAgo(now - 30000, now), 'vor 30 s');
      expect(formatAgo(now - 300000, now), 'vor 5 Min.');
    });

    test('formats past time', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(formatAgo(now - 3600000, now), 'vor 1 Std.');
      expect(formatAgo(now - 86400000, now), 'vor 1 Tag');
      expect(formatAgo(now - 172800000, now), 'vor 2 Tagen');
    });
  });

  group('positionAt und entryAt', () {
    test('positionAt berechnet Position bei Zeit ts', () {
      final entry = Entry(
        id: '1',
        key: 'key1',
        title: 'Chapter 1',
        artist: 'Audiobook',
        album: 'Album 1',
        spotifyUri: null,
        mediaId: '',
        artUri: '',
        kind: 'spoken',
        durationMs: 3600000,
        startPositionMs: 1000000,
        positionMs: 1000000,
        startedAt: 1000,
        lastSeenAt: 5000,
        pinned: false,
      );
      // Bei ts=3000 (2000ms nach startedAt): 1000000 + 2000 = 1002000
      final pos = positionAt(entry, 3000);
      expect(pos, 1002000);
    });

    test('entryAt findet Eintrag mit startedAt <= ts <= lastSeenAt', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final history = [
        Entry(
          id: '1',
          key: 'key1',
          title: 'Chapter 1',
          artist: 'Audiobook',
          album: 'Album 1',
          spotifyUri: null,
          mediaId: '',
          artUri: '',
          kind: 'spoken',
          durationMs: 3600000,
          startPositionMs: 0,
          positionMs: 1800000,
          startedAt: now - 5000,
          lastSeenAt: now + 5000,
          pinned: false,
        ),
      ];
      final found = entryAt(history, now);
      expect(found?.id, '1');
    });

    test('entryAt gibt null zurück, wenn ts außerhalb liegt', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final history = [
        Entry(
          id: '1',
          key: 'key1',
          title: 'Chapter 1',
          artist: 'Audiobook',
          album: 'Album 1',
          spotifyUri: null,
          mediaId: '',
          artUri: '',
          kind: 'spoken',
          durationMs: 3600000,
          startPositionMs: 0,
          positionMs: 1800000,
          startedAt: now,
          lastSeenAt: now + 5000,
          pinned: false,
        ),
      ];
      final found = entryAt(history, now - 1000);
      expect(found, isNull);
    });
  });

  group('guessSleep – Bewegungs- und Bildschirm-Erkennung', () {
    test(
      'guessSleep mit nur Bildschirm: 15+ min Hörbuch danach → Vorschlag',
      () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final hourAgo = now - 60 * 60 * 1000;
        final twoHoursAgo = now - 2 * 60 * 60 * 1000;

        final history = [
          Entry(
            id: '1',
            key: 'audio1',
            title: 'Chapter 1',
            artist: 'Audiobook',
            album: 'Album 1',
            spotifyUri: null,
            mediaId: '',
            artUri: '',
            kind: 'spoken',
            durationMs: 3600000,
            startPositionMs: 0,
            positionMs: 2400000,
            startedAt: twoHoursAgo,
            lastSeenAt: now - 5 * 60 * 1000, // 5 min ago still playing
            pinned: false,
          ),
        ];

        final activity = [
          ActivityEvent(ts: hourAgo, type: 'screen', action: 'off'),
          // Hörbuch lief 55 min danach weiter
        ];

        final guess = guessSleep(history, activity, now);
        expect(guess, isNotNull);
        expect(guess!.at, hourAgo);
        expect(guess.playedAfterMin, greaterThanOrEqualTo(50)); // ≈55 min
      },
    );

    test('guessSleep: < 15 min → kein Vorschlag', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final minutesAgo = now - 5 * 60 * 1000; // 5 min ago

      final history = [
        Entry(
          id: '1',
          key: 'audio1',
          title: 'Chapter 1',
          artist: 'Audiobook',
          album: 'Album 1',
          spotifyUri: null,
          mediaId: '',
          artUri: '',
          kind: 'spoken',
          durationMs: 3600000,
          startPositionMs: 0,
          positionMs: 2400000,
          // nur 20 Min. Sitzung: 10 Min. bis zum Wachzeichen, 10 Min. danach
          startedAt: minutesAgo - 20 * 60 * 1000,
          lastSeenAt: minutesAgo,
          pinned: false,
        ),
      ];

      final activity = [
        ActivityEvent(
          ts: minutesAgo - 10 * 60 * 1000,
          type: 'screen',
          action: 'off',
        ),
        // Lief nur 10 min weiter
      ];

      final guess = guessSleep(history, activity, now);
      expect(guess, isNull);
    });

    test('guessSleep bevorzugt neuestes screen-/motion-Ereignis', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final screenOff = now - 30 * 60 * 1000;
      final motionLater = now - 20 * 60 * 1000; // neuester
      final twoHoursAgo = now - 2 * 60 * 60 * 1000;

      final history = [
        Entry(
          id: '1',
          key: 'audio1',
          title: 'Chapter 1',
          artist: 'Audiobook',
          album: 'Album 1',
          spotifyUri: null,
          mediaId: '',
          artUri: '',
          kind: 'spoken',
          durationMs: 3600000,
          startPositionMs: 0,
          positionMs: 2400000,
          startedAt: twoHoursAgo,
          lastSeenAt: now - 5 * 60 * 1000, // noch am Laufen
          pinned: false,
        ),
      ];

      final activity = [
        ActivityEvent(ts: screenOff, type: 'screen', action: 'off'),
        ActivityEvent(
          ts: motionLater,
          type: 'motion',
          action: null,
          level: 1.5,
        ),
      ];

      final guess = guessSleep(history, activity, now);
      expect(guess, isNotNull);
      expect(guess!.at, motionLater); // neuestes Event
      expect(guess.source, 'Bewegung');
    });
  });

  group('splitEvents', () {
    test('trennt Media- und Aktivitätsereignisse', () {
      final events = [
        {'ts': 1000, 'title': 'Song', 'artist': 'Artist'}, // Media (kein type)
        {'ts': 2000, 'type': 'screen', 'action': 'off'}, // Aktivität
        {'ts': 3000, 'type': 'motion', 'level': 1.5}, // Aktivität
      ];

      final split = splitEvents(events);
      expect(split.media.length, 1);
      expect(split.activity.length, 2);
      expect(split.media[0].title, 'Song');
      expect(split.activity[0].type, 'screen');
      expect(split.activity[1].type, 'motion');
    });
  });

  group('applyEvents – Wechsel Hörbuch → Musik', () {
    RawEvent ev(
      int ts,
      String title,
      String artist,
      int pos, {
      String state = 'PLAYING',
      String reason = 'tick',
      int dur = 1800000,
      String uri = '',
    }) => RawEvent(
      ts: ts,
      reason: reason,
      title: title,
      artist: artist,
      album: '',
      durationMs: dur,
      positionMs: pos,
      mediaId: '',
      mediaUri: '',
      artUri: '',
      state: state,
      actions: 0,
      spotifyUri: uri,
    );

    test(
      'Endposition des Hörbuchs bleibt erhalten, Musik wird eigener Eintrag',
      () {
        final h = applyEvents([], [
          ev(1000, 'Kapitel 7', 'Der Hobbit', 700000, reason: 'start'),
          ev(21000, 'Kapitel 7', 'Der Hobbit', 720000),
          ev(55000, 'Kapitel 7', 'Der Hobbit', 754000, reason: 'end'),
          ev(55100, 'Song A', 'Band', 0, reason: 'start', dur: 200000),
        ]);
        expect(h.length, 2);
        expect(h[0].title, 'Song A');
        expect(h[0].kind, 'music');
        expect(h[1].title, 'Kapitel 7');
        expect(h[1].kind, 'spoken');
        expect(h[1].positionMs, 754000);
        final r = findResumeCandidate(h, null);
        expect(r?.title, 'Kapitel 7');
      },
    );

    test('später bekannte Spotify-URI spaltet den Eintrag nicht auf', () {
      final h = applyEvents([], [
        ev(1000, 'Kapitel 7', 'Der Hobbit', 1000),
        ev(21000, 'Kapitel 7', 'Der Hobbit', 21000, uri: 'spotify:episode:abc'),
        ev(41000, 'Kapitel 7', 'Der Hobbit', 41000, uri: 'spotify:episode:abc'),
      ]);
      expect(h.length, 1);
      expect(h[0].spotifyUri, 'spotify:episode:abc');
      expect(h[0].positionMs, 41000);
    });

    test('pausiert bei 0:00 legt keinen Eintrag an', () {
      final h = applyEvents([], [ev(1000, 'Song', 'Band', 0, state: 'PAUSED')]);
      expect(h, isEmpty);
    });

    test('Art wird nachträglich erkannt, wenn die Dauer erst später kommt', () {
      final h = applyEvents([], [
        ev(1000, 'Kapitel 1', 'Buch', 5000, dur: 0),
        ev(21000, 'Kapitel 1', 'Buch', 25000, dur: 2400000),
      ]);
      expect(h.single.kind, 'spoken');
    });
  });

  group('isSpoken – Hörbuch als Album mit kurzen Kapiteln', () {
    Entry e({
      String title = '',
      String album = '',
      String artist = '',
      int dur = 200000,
      String mediaId = '',
      String ctx = '',
    }) => Entry(
      id: '1',
      key: '',
      title: title,
      artist: artist,
      album: album,
      spotifyUri: null,
      mediaId: mediaId,
      artUri: '',
      kind: 'music',
      durationMs: dur,
      startPositionMs: 0,
      positionMs: 0,
      startedAt: 0,
      lastSeenAt: 0,
      pinned: false,
      contextUri: ctx,
    );

    test('„Kapitel 67 …“ mit 3 Minuten gilt als Hörbuch', () {
      expect(
        isSpoken(
          e(
            title: 'Kapitel 67 - Der heilige Tod - Thriller ( John Milton 2 ) Hörbuch',
          ),
        ),
        isTrue,
      );
    });
    test('normales Lied bleibt Musik', () {
      expect(
        isSpoken(
          e(
            title: 'Second & Sebring',
            album: 'Of Mice & Men',
            mediaId: 'spotify:track:3bdq',
          ),
        ),
        isFalse,
      );
    });
    test('Kontext Hörbuch zählt', () {
      expect(
        isSpoken(e(title: 'Teil A', ctx: 'spotify:audiobook:xyz')),
        isTrue,
      );
    });
    test('groupTitle nimmt Kontexttitel, sonst Album', () {
      expect(
        e(title: 'Kapitel 1', album: 'Der Hobbit').groupTitle,
        'Der Hobbit',
      );
    });
  });

  group('guessSleep – realistische Nacht', () {
    Entry ch(String title, int start, int end, {int startPos = 0}) => Entry(
      id: title,
      key: '',
      title: title,
      artist: 'Mark Dawson',
      album: 'Der heilige Tod',
      spotifyUri: null,
      mediaId: 'spotify:track:$title',
      artUri: '',
      kind: 'spoken',
      durationMs: 200000,
      startPositionMs: startPos,
      positionMs: startPos + end - start,
      startedAt: start,
      lastSeenAt: end,
      pinned: false,
    );
    const min = 60 * 1000;
    final t0 = DateTime(2026, 9, 24, 23, 0).millisecondsSinceEpoch;
    // Kapitel à ~3 Min., 23:00 bis 00:00 durchgehend
    final history = [
      for (var i = 19; i >= 0; i--)
        ch(
          'Kapitel ${i + 1}',
          t0 + i * 3 * min,
          t0 + i * 3 * min + 3 * min - 1000,
        ),
    ];

    test(
      'Entsperren am Morgen zählt nicht, Stelle = Kapitel beim Weglegen',
      () {
        final activity = [
          ActivityEvent(
            ts: t0 + 10 * min,
            type: 'screen',
            action: 'off',
          ), // 23:10 weggelegt
          ActivityEvent(
            ts: t0 + 8 * 60 * min,
            type: 'screen',
            action: 'unlock',
          ), // 07:00
        ];
        final g = guessSleep(history, activity, t0 + 8 * 60 * min + 5 * min);
        expect(g, isNotNull);
        expect(g!.at, t0 + 10 * min);
        expect(g.entry.title, 'Kapitel 4'); // 23:09–23:12
        expect(g.entry.positionMs, 1 * min); // 1 Min. in Kapitel 4
        expect(g.playedAfterMin, 49);
      },
    );

    test('Bewegung nach dem Bildschirm-Aus verschiebt den Zeitpunkt', () {
      final activity = [
        ActivityEvent(ts: t0 + 10 * min, type: 'screen', action: 'off'),
        ActivityEvent(ts: t0 + 30 * min, type: 'motion', level: 2.0),
      ];
      final g = guessSleep(history, activity, t0 + 2 * 60 * min);
      expect(g!.at, t0 + 30 * min);
      expect(g.source, 'Bewegung');
      expect(g.entry.title, 'Kapitel 11');
    });
  });

  group('Wachzeichen lesbar', () {
    test('describeActivity', () {
      expect(
        describeActivity(
          ActivityEvent(ts: 0, type: 'screen', action: 'unlock'),
        ),
        'Entsperrt',
      );
      expect(
        describeActivity(ActivityEvent(ts: 0, type: 'screen', action: 'off')),
        'Bildschirm aus',
      );
      expect(
        describeActivity(ActivityEvent(ts: 0, type: 'motion', level: 2.3)),
        'Bewegung (Stärke 2.3)',
      );
    });
    test('formatClock', () {
      final ts = DateTime(2026, 9, 25, 0, 3, 23).millisecondsSinceEpoch;
      expect(formatClock(ts), '25.09. 00:03:23');
    });
    test('recentActivityLines: neueste zuerst, begrenzt', () {
      final base = DateTime(2026, 9, 25, 0, 0).millisecondsSinceEpoch;
      final events = [
        for (var i = 0; i < 15; i++)
          ActivityEvent(ts: base + i * 60000, type: 'motion'),
      ];
      final lines = recentActivityLines(events);
      expect(lines.length, 10);
      expect(lines.first, '25.09. 00:14:00 – Bewegung');
    });
  });

  group('Einschlaf-Stellen im Verlauf', () {
    Entry ch(String title, int start, int end) => Entry(
      id: title,
      key: '',
      title: title,
      artist: 'A',
      album: 'Buch',
      spotifyUri: null,
      mediaId: 'spotify:track:$title',
      artUri: '',
      kind: 'spoken',
      durationMs: 200000,
      startPositionMs: 0,
      positionMs: end - start,
      startedAt: start,
      lastSeenAt: end,
      pinned: false,
    );
    const min = 60 * 1000;
    final n1 = DateTime(2026, 9, 23, 23, 0).millisecondsSinceEpoch;
    final n2 = DateTime(2026, 9, 24, 23, 0).millisecondsSinceEpoch;
    // zwei Nächte, je 60 Min. am Stück in 3-Minuten-Kapiteln
    final history = [
      for (var i = 19; i >= 0; i--)
        ch('N2 K${i + 1}', n2 + i * 3 * min, n2 + (i + 1) * 3 * min - 1000),
      for (var i = 19; i >= 0; i--)
        ch('N1 K${i + 1}', n1 + i * 3 * min, n1 + (i + 1) * 3 * min - 1000),
    ];
    final activity = [
      ActivityEvent(ts: n1 + 5 * min, type: 'screen', action: 'off'),
      ActivityEvent(ts: n2 + 20 * min, type: 'motion', level: 1.5),
      ActivityEvent(ts: n2 + 9 * 60 * min, type: 'screen', action: 'unlock'),
    ];

    test('findet alle Stellen, neueste zuerst', () {
      final marks = findSleepMarks(history, activity);
      // Nacht 2: 20 Min. ohne Wachzeichen ab Wiedergabe-Start, dann ab der
      // Bewegung um +20 Min.; Nacht 1: ab Bildschirm aus um +5 Min.
      expect(marks.length, 3);
      expect(marks[0].at, n2 + 20 * min);
      expect(marks[0].entry.title, 'N2 K7');
      expect(marks[1].at, n2);
      expect(marks[1].source, 'Wiedergabe-Start');
      expect(marks[2].at, n1 + 5 * min);
      expect(marks[2].entry.title, 'N1 K2');
    });

    test('mergeSleepMarks entfernt Doppelte, JSON hin und zurück', () {
      final marks = findSleepMarks(history, activity);
      final back = [for (final m in marks) SleepGuess.fromJson(m.toJson())];
      final merged = mergeSleepMarks(back, marks, n2 + 10 * 60 * min);
      expect(merged.length, 3);
      expect(merged.first.entry.positionMs, marks.first.entry.positionMs);
    });

    test('filterSleepMarks: bei „Musik“ ausgeblendet, Suche greift', () {
      final marks = findSleepMarks(history, activity);
      final now = n2 + 10 * 60 * min;
      expect(
        filterSleepMarks(marks, FilterRange.all, FilterKind.music, '', now),
        isEmpty,
      );
      expect(
        filterSleepMarks(
          marks,
          FilterRange.all,
          FilterKind.all,
          'N1',
          now,
        ).length,
        1,
      );
    });
  });

  group('Aufwachen und Weiterhören überschreibt nichts', () {
    Entry ch(String title, int start, int end) => Entry(
      id: title,
      key: '',
      title: title,
      artist: 'A',
      album: 'Buch',
      spotifyUri: null,
      mediaId: 'spotify:track:$title',
      artUri: '',
      kind: 'spoken',
      durationMs: 180000,
      startPositionMs: 0,
      positionMs: end - start,
      startedAt: start,
      lastSeenAt: end,
      pinned: false,
    );
    const min = 60 * 1000;
    final t0 = DateTime(2026, 9, 26, 0, 0).millisecondsSinceEpoch;
    // 00:00–02:10 durchgehend, 3-Minuten-Kapitel
    final history = [
      for (var i = 42; i >= 0; i--)
        ch('K${i + 1}', t0 + i * 3 * min, t0 + (i + 1) * 3 * min - 1000),
    ];
    final activity = [
      ActivityEvent(
        ts: t0 + 10 * min,
        type: 'screen',
        action: 'off',
      ), // 00:10 weggelegt
      // 02:04 aufgewacht, Handy benutzt, weitergehört
      ActivityEvent(ts: t0 + 124 * min, type: 'screen', action: 'on'),
      ActivityEvent(ts: t0 + 125 * min, type: 'motion', level: 11.6),
    ];

    test('Stelle beim Weglegen bleibt, obwohl danach weitergehört wurde', () {
      final g = guessSleep(history, activity, t0 + 129 * min);
      expect(g, isNotNull);
      expect(g!.at, t0 + 10 * min);
      expect(g.entry.title, 'K4'); // 00:09–00:12
      expect(g.playedAfterMin, 114); // bis zum Aufwachen um 02:04
    });

    test('Start der Wiedergabe zählt als Wachzeichen', () {
      final g = findSleepMarks(history, const []);
      expect(g.length, 1);
      expect(g.first.at, t0);
      expect(g.first.source, 'Wiedergabe-Start');
    });

    test('Filter „Eingeschlafen“ zeigt nur Einschlaf-Stellen', () {
      final now = t0 + 129 * min;
      expect(
        filterHistory(
          history,
          FilterRange.all,
          FilterKind.sleep,
          '',
          null,
          now,
        ),
        isEmpty,
      );
      final marks = findSleepMarks(history, activity);
      expect(
        filterSleepMarks(
          marks,
          FilterRange.all,
          FilterKind.sleep,
          '',
          now,
        ).length,
        marks.length,
      );
    });
  });
}
