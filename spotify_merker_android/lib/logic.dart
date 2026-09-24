class RawEvent {
  final int ts;
  final String reason;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int positionMs;
  final String mediaId;
  final String mediaUri;
  final String artUri;
  final String state;
  final int actions;
  final String spotifyUri;
  final String contextUri;
  final String contextTitle;

  RawEvent({
    required this.ts,
    required this.reason,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.positionMs,
    required this.mediaId,
    required this.mediaUri,
    required this.artUri,
    required this.state,
    required this.actions,
    required this.spotifyUri,
    this.contextUri = '',
    this.contextTitle = '',
  });

  factory RawEvent.fromJson(Map<String, dynamic> json) {
    return RawEvent(
      ts: json['ts'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      durationMs: json['durationMs'] as int? ?? 0,
      positionMs: json['positionMs'] as int? ?? 0,
      mediaId: json['mediaId'] as String? ?? '',
      mediaUri: json['mediaUri'] as String? ?? '',
      artUri: json['artUri'] as String? ?? '',
      state: json['state'] as String? ?? 'UNKNOWN',
      actions: json['actions'] as int? ?? 0,
      spotifyUri: json['spotifyUri'] as String? ?? '',
      contextUri: json['contextUri'] as String? ?? '',
      contextTitle: json['contextTitle'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'ts': ts,
    'reason': reason,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'positionMs': positionMs,
    'mediaId': mediaId,
    'mediaUri': mediaUri,
    'artUri': artUri,
    'state': state,
    'actions': actions,
    'spotifyUri': spotifyUri,
    'contextUri': contextUri,
    'contextTitle': contextTitle,
  };
}

class Entry {
  final String id;
  final String key;
  final String title;
  final String artist;
  final String album;
  final String? spotifyUri;
  final String mediaId;
  final String artUri;
  final String kind; // 'music' | 'spoken'
  final int durationMs;
  final int startPositionMs;
  final int positionMs;
  final int startedAt;
  final int lastSeenAt;
  final bool pinned;
  final String contextUri;
  final String contextTitle;

  Entry({
    required this.id,
    required this.key,
    required this.title,
    required this.artist,
    required this.album,
    required this.spotifyUri,
    required this.mediaId,
    required this.artUri,
    required this.kind,
    required this.durationMs,
    required this.startPositionMs,
    required this.positionMs,
    required this.startedAt,
    required this.lastSeenAt,
    required this.pinned,
    this.contextUri = '',
    this.contextTitle = '',
  });

  /// Wozu gehört das Stück? Hörbuch/Album/Playlist-Name, sonst Interpret.
  String get groupTitle => contextTitle.isNotEmpty
      ? contextTitle
      : (album.isNotEmpty && album != title ? album : artist);

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String? ?? '',
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      spotifyUri: json['spotifyUri'] as String?,
      mediaId: json['mediaId'] as String? ?? '',
      artUri: json['artUri'] as String? ?? '',
      kind: json['kind'] as String? ?? 'music',
      durationMs: json['durationMs'] as int? ?? 0,
      startPositionMs: json['startPositionMs'] as int? ?? 0,
      positionMs: json['positionMs'] as int? ?? 0,
      startedAt: json['startedAt'] as int? ?? 0,
      lastSeenAt: json['lastSeenAt'] as int? ?? 0,
      pinned: json['pinned'] as bool? ?? false,
      contextUri: json['contextUri'] as String? ?? '',
      contextTitle: json['contextTitle'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'title': title,
    'artist': artist,
    'album': album,
    'spotifyUri': spotifyUri,
    'mediaId': mediaId,
    'artUri': artUri,
    'kind': kind,
    'durationMs': durationMs,
    'startPositionMs': startPositionMs,
    'positionMs': positionMs,
    'startedAt': startedAt,
    'lastSeenAt': lastSeenAt,
    'pinned': pinned,
    'contextUri': contextUri,
    'contextTitle': contextTitle,
  };

  Entry copyWith({
    String? title,
    String? artist,
    String? album,
    String? spotifyUri,
    String? mediaId,
    String? artUri,
    String? kind,
    int? durationMs,
    int? startPositionMs,
    int? positionMs,
    int? lastSeenAt,
    bool? pinned,
    String? contextUri,
    String? contextTitle,
  }) {
    return Entry(
      id: id,
      key: key,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      spotifyUri: spotifyUri ?? this.spotifyUri,
      mediaId: mediaId ?? this.mediaId,
      artUri: artUri ?? this.artUri,
      kind: kind ?? this.kind,
      durationMs: durationMs ?? this.durationMs,
      startPositionMs: startPositionMs ?? this.startPositionMs,
      positionMs: positionMs ?? this.positionMs,
      startedAt: startedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      pinned: pinned ?? this.pinned,
      contextUri: contextUri ?? this.contextUri,
      contextTitle: contextTitle ?? this.contextTitle,
    );
  }
}

String entryKey(Entry e) {
  final uri = e.spotifyUri?.toLowerCase().trim();
  if (uri != null && uri.isNotEmpty) return uri;
  final mid = e.mediaId.toLowerCase().trim();
  if (mid.isNotEmpty) return mid;
  return "${e.title.toLowerCase().trim()}|${e.artist.toLowerCase().trim()}";
}

final RegExp _spokenWords = RegExp(
  r'\b(kapitel|chapter|hörbuch|hoerbuch|audiobook|hörspiel|folge|episode|teil \d+)\b',
  caseSensitive: false,
);

/// Hörbuch/Podcast oder Musik? Spotify-URIs zuerst, dann Kontext, dann
/// typische Wörter („Kapitel 67“, „Hörbuch“), zuletzt die Länge.
bool isSpoken(Entry e) {
  final uris = '${e.spotifyUri ?? ''} ${e.mediaId} ${e.contextUri}';
  for (final t in const [':episode:', ':chapter:', ':audiobook:', ':show:']) {
    if (uris.contains(t)) return true;
  }
  final text = '${e.title} ${e.album} ${e.artist} ${e.contextTitle}';
  if (_spokenWords.hasMatch(text)) return true;
  return e.durationMs >= 15 * 60 * 1000;
}

const int _sameSessionGapMs = 5 * 60 * 1000;
const int maxHistory = 3000;
int _idCounter = 0;

String _norm(String? s) => (s ?? '').toLowerCase().trim();

/// Gehört das Ereignis zum selben Stück wie der Eintrag?
bool _sameItem(Entry e, RawEvent ev) {
  final eu = _norm(e.spotifyUri), vu = _norm(ev.spotifyUri);
  if (eu.isNotEmpty && vu.isNotEmpty) return eu == vu;
  final em = _norm(e.mediaId), vm = _norm(ev.mediaId);
  if (em.isNotEmpty && vm.isNotEmpty) return em == vm;
  return _norm(e.title) == _norm(ev.title) &&
      _norm(e.artist) == _norm(ev.artist);
}

List<Entry> applyEvents(List<Entry> history, List<RawEvent> events) {
  var updated = List<Entry>.from(history);
  final sortedEvents = List<RawEvent>.from(events)
    ..sort((a, b) => a.ts.compareTo(b.ts));

  for (final event in sortedEvents) {
    if (event.title.trim().isEmpty) continue;

    if (updated.isNotEmpty &&
        _sameItem(updated[0], event) &&
        event.ts - updated[0].lastSeenAt <= _sameSessionGapMs) {
      final e = updated[0];
      final merged = e.copyWith(
        positionMs: event.positionMs,
        lastSeenAt: event.ts > e.lastSeenAt ? event.ts : e.lastSeenAt,
        album: event.album.isNotEmpty ? event.album : e.album,
        durationMs: event.durationMs > 0 ? event.durationMs : e.durationMs,
        artUri: event.artUri.isNotEmpty ? event.artUri : e.artUri,
        mediaId: event.mediaId.isNotEmpty ? event.mediaId : e.mediaId,
        spotifyUri: event.spotifyUri.isNotEmpty
            ? event.spotifyUri
            : e.spotifyUri,
        contextUri: event.contextUri.isNotEmpty
            ? event.contextUri
            : e.contextUri,
        contextTitle: event.contextTitle.isNotEmpty
            ? event.contextTitle
            : e.contextTitle,
      );
      // Art neu bestimmen, falls Dauer oder URI erst jetzt bekannt sind.
      updated[0] = merged.copyWith(kind: isSpoken(merged) ? 'spoken' : 'music');
      continue;
    }

    // Kein neuer Eintrag für "pausiert bei 0:00" (z. B. frisch geöffnetes Spotify).
    if (event.state != 'PLAYING' && event.positionMs <= 0) continue;

    final draft = Entry(
      id: '${event.ts}-${_idCounter++}',
      key: '',
      title: event.title,
      artist: event.artist,
      album: event.album,
      spotifyUri: event.spotifyUri.isNotEmpty ? event.spotifyUri : null,
      mediaId: event.mediaId,
      artUri: event.artUri,
      kind: 'music',
      durationMs: event.durationMs,
      startPositionMs: event.positionMs,
      positionMs: event.positionMs,
      startedAt: event.ts,
      lastSeenAt: event.ts,
      pinned: false,
      contextUri: event.contextUri,
      contextTitle: event.contextTitle,
    );
    updated.insert(
      0,
      draft.copyWith(kind: isSpoken(draft) ? 'spoken' : 'music'),
    );
  }

  if (updated.length > maxHistory) updated = updated.sublist(0, maxHistory);
  return updated;
}

class Current {
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int positionMs;
  final String state;
  final String mediaId;
  final String mediaUri;
  final String artUri;

  Current({
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.positionMs,
    required this.state,
    required this.mediaId,
    required this.mediaUri,
    required this.artUri,
  });

  factory Current.fromJson(Map<String, dynamic> json) {
    return Current(
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      durationMs: json['durationMs'] as int? ?? 0,
      positionMs: json['positionMs'] as int? ?? 0,
      state: json['state'] as String? ?? 'UNKNOWN',
      mediaId: json['mediaId'] as String? ?? '',
      mediaUri: json['mediaUri'] as String? ?? '',
      artUri: json['artUri'] as String? ?? '',
    );
  }
}

Entry? findResumeCandidate(List<Entry> history, Current? current) {
  // Find most recent spoken entry
  for (final entry in history) {
    if (entry.kind == 'spoken') {
      // Skip if it's currently playing
      if (current != null &&
          entry.title.toLowerCase().trim() ==
              current.title.toLowerCase().trim() &&
          current.state == 'PLAYING') {
        continue;
      }
      return entry;
    }
  }
  return null;
}

enum FilterRange { hour, today, yesterday, week, all }

enum FilterKind { all, spoken, music, pinned }

List<Entry> filterHistory(
  List<Entry> history,
  FilterRange range,
  FilterKind kind,
  String query,
  int? around,
  int now,
) {
  var filtered = List<Entry>.from(history);

  // Time filter
  if (range == FilterRange.today) {
    final startOfDay = DateTime.now()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .millisecondsSinceEpoch;
    filtered = filtered.where((e) => e.startedAt >= startOfDay).toList();
  } else if (range == FilterRange.yesterday) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final startOfYesterday = yesterday
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .millisecondsSinceEpoch;
    final endOfYesterday = now
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .millisecondsSinceEpoch;
    filtered = filtered
        .where(
          (e) =>
              e.startedAt >= startOfYesterday && e.startedAt < endOfYesterday,
        )
        .toList();
  } else if (range == FilterRange.week) {
    final cutoff = now - 7 * 24 * 60 * 60 * 1000;
    filtered = filtered.where((e) => e.startedAt >= cutoff).toList();
  } else if (range == FilterRange.hour) {
    final cutoff = now - 60 * 60 * 1000;
    filtered = filtered.where((e) => e.startedAt >= cutoff).toList();
  }

  // Kind filter
  if (kind == FilterKind.spoken) {
    filtered = filtered.where((e) => e.kind == 'spoken').toList();
  } else if (kind == FilterKind.music) {
    filtered = filtered.where((e) => e.kind == 'music').toList();
  } else if (kind == FilterKind.pinned) {
    filtered = filtered.where((e) => e.pinned).toList();
  }

  // Query filter
  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    filtered = filtered.where((e) {
      return e.title.toLowerCase().contains(q) ||
          e.artist.toLowerCase().contains(q) ||
          e.album.toLowerCase().contains(q);
    }).toList();
  }

  // Around filter (±30 min)
  if (around != null) {
    final min = around - 30 * 60 * 1000;
    final max = around + 30 * 60 * 1000;
    filtered = filtered
        .where((e) => e.lastSeenAt >= min && e.startedAt <= max)
        .toList();
  }

  return filtered;
}

String formatMs(int ms) {
  final totalSeconds = (ms < 0 ? 0 : ms) ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  return '$minutes:$ss';
}

String formatAgo(int ts, int now) {
  final diff = now - ts;

  if (diff < 1000) return 'gerade eben';
  if (diff < 60 * 1000) return 'vor ${(diff ~/ 1000)} s';
  if (diff < 60 * 60 * 1000) return 'vor ${(diff ~/ (60 * 1000))} Min.';
  if (diff < 24 * 60 * 60 * 1000)
    return 'vor ${(diff ~/ (60 * 60 * 1000))} Std.';

  final days = diff ~/ (24 * 60 * 60 * 1000);
  if (days == 1) return 'vor 1 Tag';
  return 'vor $days Tagen';
}

/// Art aller Einträge neu bestimmen (z. B. nach verbesserter Erkennung).
List<Entry> reclassify(List<Entry> history) => [
  for (final e in history) e.copyWith(kind: isSpoken(e) ? 'spoken' : 'music'),
];
