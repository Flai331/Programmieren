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
  if (diff < 24 * 60 * 60 * 1000) {
    return 'vor ${(diff ~/ (60 * 60 * 1000))} Std.';
  }

  final days = diff ~/ (24 * 60 * 60 * 1000);
  if (days == 1) return 'vor 1 Tag';
  return 'vor $days Tagen';
}

/// Art aller Einträge neu bestimmen (z. B. nach verbesserter Erkennung).
List<Entry> reclassify(List<Entry> history) => [
  for (final e in history) e.copyWith(kind: isSpoken(e) ? 'spoken' : 'music'),
];

/// Aktivitätsereignis (Bildschirm oder Bewegung).
class ActivityEvent {
  final int ts;
  final String type; // 'screen', 'motion'
  final String? action; // 'on', 'off', 'unlock' (für screen)
  final double? level; // Bewegungsmagnitude (für motion)

  ActivityEvent({
    required this.ts,
    required this.type,
    this.action,
    this.level,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      ts: json['ts'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      action: json['action'] as String?,
      level: (json['level'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ts': ts,
    'type': type,
    if (action != null) 'action': action,
    if (level != null) 'level': level,
  };
}

/// Splittet Ereignisse in Medien- und Aktivitätsereignisse.
({List<RawEvent> media, List<ActivityEvent> activity}) splitEvents(
  List<Map<String, dynamic>> rawMaps,
) {
  final media = <RawEvent>[];
  final activity = <ActivityEvent>[];

  for (final map in rawMaps) {
    final type = map['type'] as String?;
    if (type == null || type.isEmpty) {
      // Media-Ereignis (kein type-Feld)
      final json = Map<String, dynamic>.from(map);
      media.add(RawEvent.fromJson(json));
    } else {
      // Aktivitätsereignis
      activity.add(ActivityEvent.fromJson(map));
    }
  }

  return (media: media, activity: activity);
}

/// Position eines Eintrags zum Zeitpunkt ts.
int positionAt(Entry e, int ts) {
  final elapsed = ts - e.startedAt;
  final pos = e.startPositionMs + elapsed;
  return pos.clamp(0, e.durationMs > 0 ? e.durationMs : 0x7FFFFFFFFFFFFFFF);
}

/// Eintrag mit startedAt <= ts <= lastSeenAt, neuester zuerst.
Entry? entryAt(List<Entry> history, int ts) {
  for (final e in history) {
    if (e.startedAt <= ts && ts <= e.lastSeenAt) {
      return e;
    }
  }
  return null;
}

/// Vermutete Einschlafstelle.
class SleepGuess {
  final Entry entry;
  final int at; // Zeitpunkt des letzten Vorzeichens
  final String source; // Beschreibung z.B. "Handy-Nutzung" oder "Bewegung"
  final int playedAfterMin; // Minuten, die danach noch liefen

  SleepGuess({
    required this.entry,
    required this.at,
    required this.source,
    required this.playedAfterMin,
  });
}

/// Rät die Einschlafstelle aus Verlauf und Handy-Aktivität.
///
/// Betrachtet wird die jüngste Hörbuch-Sitzung der letzten 18 h. Letztes
/// Wachzeichen = jüngstes Bildschirm- oder Bewegungsereignis **vor dem Ende**
/// dieser Sitzung (spätere – etwa das Entsperren am Morgen – zählen nicht).
/// Lief das Hörbuch danach noch ≥ 15 min, ist die Stelle zum Zeitpunkt des
/// letzten Wachzeichens der Vorschlag.
SleepGuess? guessSleep(
  List<Entry> history,
  List<ActivityEvent> activity,
  int now,
) {
  const window = 18 * 60 * 60 * 1000;
  const minPlayedAfter = 15 * 60 * 1000;

  final spoken =
      history
          .where((e) => e.kind == 'spoken' && now - e.lastSeenAt < window)
          .toList()
        ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
  if (spoken.isEmpty) return null;
  final sessionEnd = spoken.first.lastSeenAt;

  ActivityEvent? sign;
  for (final a in activity) {
    final relevant =
        a.type == 'motion' || (a.type == 'screen' && a.action != null);
    if (!relevant || a.ts > sessionEnd || now - a.ts >= window) continue;
    if (sign == null || a.ts > sign.ts) sign = a;
  }
  if (sign == null) return null;
  final lastSign = sign.ts;
  if (sessionEnd - lastSign < minPlayedAfter) return null;

  // Kapitel, das beim letzten Wachzeichen lief; lag das Zeichen in einer
  // Lücke zwischen zwei Kapiteln, das nächste danach ab seinem Anfang.
  var entry = entryAt(spoken, lastSign);
  var pos = entry == null ? 0 : positionAt(entry, lastSign);
  if (entry == null) {
    final after = spoken.where((e) => e.startedAt >= lastSign).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    if (after.isEmpty) return null;
    entry = after.first;
    pos = entry.startPositionMs;
  }

  return SleepGuess(
    entry: entry.copyWith(positionMs: pos),
    at: lastSign,
    source: sign.type == 'screen' ? 'Handy-Nutzung' : 'Bewegung',
    playedAfterMin: (sessionEnd - lastSign) ~/ (60 * 1000),
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Uhrzeit lesbar, z. B. „25.09. 00:03:23“.
String formatClock(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${_two(d.day)}.${_two(d.month)}. '
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
}

/// Wachzeichen in Worten, z. B. „Entsperrt“ oder „Bewegung (2.3)“.
String describeActivity(ActivityEvent a) {
  if (a.type == 'motion') {
    return a.level != null ? 'Bewegung (Stärke ${a.level})' : 'Bewegung';
  }
  if (a.type == 'screen') {
    switch (a.action) {
      case 'on':
        return 'Bildschirm an';
      case 'off':
        return 'Bildschirm aus';
      case 'unlock':
        return 'Entsperrt';
    }
  }
  return '${a.type} ${a.action ?? ''}'.trim();
}

/// Die letzten [count] Wachzeichen, neueste zuerst, als lesbare Zeilen.
List<String> recentActivityLines(
  List<ActivityEvent> activity, {
  int count = 10,
}) {
  final sorted = List<ActivityEvent>.from(activity)
    ..sort((a, b) => b.ts.compareTo(a.ts));
  return [
    for (final a in sorted.take(count))
      '${formatClock(a.ts)} – ${describeActivity(a)}',
  ];
}
