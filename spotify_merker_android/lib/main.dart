import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:spotify_merker/logic.dart';
import 'package:spotify_merker/storage.dart';
import 'package:spotify_merker/native.dart';

import 'dart:async';

const spotifyGreen = Color(0xFF1DB954);

/// Weiterhören mit sichtbarer Rückmeldung: Start-Hinweis, Fehler sofort,
/// nach einigen Sekunden der letzte Schritt aus dem Protokoll.
Future<void> startResume(BuildContext context, Entry e) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Spotify wird gestartet – springe zu ${formatMs(e.positionMs)} …',
      ),
      duration: const Duration(seconds: 3),
    ),
  );
  final r = await Native.resume(
    title: e.title,
    artist: e.artist,
    album: e.album,
    spotifyUri: e.spotifyUri,
    mediaId: e.mediaId,
    positionMs: e.positionMs,
  );
  if (r['started'] != true) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          r['error']?.toString() ?? 'Weiterhören konnte nicht starten.',
        ),
      ),
    );
    return;
  }
  await Future<void>.delayed(const Duration(seconds: 8));
  final d = await Native.getDiagnostics();
  final log = d['lastResumeLog'];
  if (log is List && log.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Status: ${log.last}'),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify-Merker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: spotifyGreen),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: spotifyGreen,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool _permissionGranted = false;
  List<Entry> _history = [];
  Current? _current;
  Timer? _updateTimer;
  int _selectedTab = 0;
  List<ActivityEvent> _activity = [];
  SleepGuess? _sleepGuess;
  List<SleepGuess> _sleepMarks = [];
  int? _lastDismissedSleepAt;

  FilterRange _filterRange = FilterRange.all;
  FilterKind _filterKind = FilterKind.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _startUpdateTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  bool _loadRunning = false;

  /// Das gerade laufende Stück im Verlauf als „gemerkt“ markieren.
  Future<bool> _pinCurrent() async {
    await _loadData(); // neueste Ereignisse zuerst einarbeiten
    final cur = _current;
    if (cur == null) return false;
    final idx = _history.indexWhere(
      (e) =>
          e.title.toLowerCase().trim() == cur.title.toLowerCase().trim() &&
          e.artist.toLowerCase().trim() == cur.artist.toLowerCase().trim(),
    );
    if (idx < 0) return false;
    final updated = List<Entry>.from(_history);
    updated[idx] = updated[idx].copyWith(pinned: true);
    await Storage.saveHistory(updated);
    if (mounted) setState(() => _history = updated);
    return true;
  }

  /// Rohereignisse abholen, in den Verlauf einarbeiten, speichern.
  /// Nie zwei Durchläufe gleichzeitig – sonst überschreibt einer den anderen.
  Future<void> _loadData() async {
    if (_loadRunning) return;
    _loadRunning = true;
    try {
      final permission = await Native.isPermissionGranted();
      final current = await Native.getCurrent();
      if (!mounted) return;
      setState(() {
        _permissionGranted = permission;
        _current = current;
      });
      var history = reclassify(await Storage.loadHistory());
      var activity = await Storage.loadActivity();
      final eventMaps = await Native.drainEvents();

      if (eventMaps.isNotEmpty) {
        final split = splitEvents(eventMaps);
        history = applyEvents(history, split.media);
        activity = [...activity, ...split.activity];

        // Nur letzte 14 Tage behalten
        final cutoff =
            DateTime.now().millisecondsSinceEpoch - 14 * 24 * 60 * 60 * 1000;
        activity = activity.where((a) => a.ts >= cutoff).toList();

        await Storage.saveHistory(history);
        await Storage.saveActivity(activity);
      }

      // Sleep-Vorschlag berechnen
      final now = DateTime.now().millisecondsSinceEpoch;
      final guess = guessSleep(history, activity, now);
      final stored = await Storage.loadSleepMarks();
      final marks = mergeSleepMarks(
        stored,
        findSleepMarks(history, activity),
        now,
      );
      if (marks.length != stored.length ||
          (marks.isNotEmpty && marks.first.at != stored.first.at)) {
        await Storage.saveSleepMarks(marks);
      }
      _lastDismissedSleepAt ??= await Storage.loadDismissedSleepAt();

      if (!mounted) return;
      setState(() {
        _history = history;
        _activity = activity;
        _sleepMarks = marks;
        _sleepGuess = (guess != null && guess.at != _lastDismissedSleepAt)
            ? guess
            : null;
      });
    } finally {
      _loadRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionGranted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Spotify-Merker'),
          backgroundColor: spotifyGreen,
          foregroundColor: Colors.white,
        ),
        body: SetupScreen(
          onPermissionGranted: () {
            _loadData();
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify-Merker'),
        backgroundColor: spotifyGreen,
        foregroundColor: Colors.white,
      ),
      body: [
        NowScreen(
          current: _current,
          history: _history,
          activity: _activity,
          sleepGuess: _sleepGuess,
          onDismissSleep: (at) {
            Storage.saveDismissedSleepAt(at);
            setState(() {
              _lastDismissedSleepAt = at;
              _sleepGuess = null;
            });
          },
          onResume: () {
            _loadData();
          },
          onPinCurrent: _pinCurrent,
          onReload: () {
            _loadData();
          },
        ),
        HistoryScreen(
          history: _history,
          sleepMarks: _sleepMarks,
          filterRange: _filterRange,
          filterKind: _filterKind,
          searchQuery: _searchQuery,
          onFilterRangeChanged: (range) {
            setState(() {
              _filterRange = range;
            });
          },
          onFilterKindChanged: (kind) {
            setState(() {
              _filterKind = kind;
            });
          },
          onSearchChanged: (query) {
            setState(() {
              _searchQuery = query;
            });
          },
          onPinChanged: (entry, pinned) {
            final updated = _history.map((e) {
              if (e.id == entry.id) {
                return e.copyWith(pinned: pinned);
              }
              return e;
            }).toList();
            Storage.saveHistory(updated);
            setState(() {
              _history = updated;
            });
          },
          onDelete: (entry) {
            final updated = _history.where((e) => e.id != entry.id).toList();
            Storage.saveHistory(updated);
            setState(() {
              _history = updated;
            });
          },
        ),
        SettingsScreen(
          history: _history,
          onExport: () {
            Storage.exportHistory(_history);
          },
          onClear: () {
            Storage.clearHistory();
            setState(() {
              _history = [];
            });
          },
        ),
      ][_selectedTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle),
            label: 'Jetzt',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Verlauf'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}

class SetupScreen extends StatelessWidget {
  final VoidCallback onPermissionGranted;

  const SetupScreen({super.key, required this.onPermissionGranted});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.notifications, size: 64, color: spotifyGreen),
        const SizedBox(height: 24),
        const Text(
          'Benachrichtigungszugriff erforderlich',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Spotify-Merker braucht Zugriff auf Benachrichtigungen, um zu sehen, was in der Spotify-App läuft.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () async {
            await Native.openPermissionSettings();
          },
          style: FilledButton.styleFrom(
            backgroundColor: spotifyGreen,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Benachrichtigungszugriff erlauben'),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Schalter ist ausgegraut oder „Eingeschränkte Einstellung“?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Android sperrt diesen Zugriff für Apps, die nicht aus dem Play Store kommen. '
                  'So gibst du ihn frei:\n'
                  '1. Unten auf „App-Info öffnen“ tippen\n'
                  '2. Oben rechts auf ⋮ (drei Punkte) tippen\n'
                  '3. „Eingeschränkte Einstellungen zulassen“ wählen und bestätigen\n'
                  '4. Zurück und nochmal „Benachrichtigungszugriff erlauben“',
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: Native.openAppDetails,
                  child: const Text('App-Info öffnen'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        const Text(
          'Optionale Einstellung in Spotify:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'In Spotify: Einstellungen (Zahnrad) → Schalter „Geräte-Broadcast-Status“ einschalten '
          '(je nach Version unter „Wiedergabe“ oder „Apps und Geräte“).',
        ),
        const Text(
          'Dies verbessert das Zurückspringen zu einer Stelle im Hörbuch.',
        ),
        const SizedBox(height: 24),
        const Text(
          'Akku-Optimierung deaktivieren:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Einstellungen → Apps → Spotify-Merker → Akku → „Nicht eingeschränkt“',
        ),
        const Text(
          '(Vor allem bei Samsung und Xiaomi wichtig, sonst wird die App im Hintergrund beendet.)',
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final granted = await Native.isPermissionGranted();
            if (granted) {
              onPermissionGranted();
            } else {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Berechtigung noch nicht erteilt'),
                ),
              );
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: spotifyGreen,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Weiter'),
        ),
      ],
    );
  }
}

class NowScreen extends StatefulWidget {
  final Current? current;
  final List<Entry> history;
  final List<ActivityEvent> activity;
  final SleepGuess? sleepGuess;
  final void Function(int at) onDismissSleep;
  final VoidCallback onResume;
  final Future<bool> Function() onPinCurrent;
  final VoidCallback onReload;

  const NowScreen({
    super.key,
    required this.current,
    required this.history,
    required this.activity,
    required this.sleepGuess,
    required this.onDismissSleep,
    required this.onResume,
    required this.onPinCurrent,
    required this.onReload,
  });

  @override
  State<NowScreen> createState() => _NowScreenState();
}

class _NowScreenState extends State<NowScreen> {
  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final resumeCandidate = findResumeCandidate(widget.history, widget.current);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sleep guess card
        if (widget.sleepGuess != null) ...[
          Card(
            color: Colors.orange.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '😴 Eingeschlafen?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vermutlich eingeschlafen um ${_formatTime(widget.sleepGuess!.at)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Letzte ${widget.sleepGuess!.source} um ${_formatTime(widget.sleepGuess!.at)}, danach lief es noch ${widget.sleepGuess!.playedAfterMin} Min.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.sleepGuess!.entry.groupTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.sleepGuess!.entry.title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'bei ${formatMs(widget.sleepGuess!.entry.positionMs)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await startResume(
                              context,
                              widget.sleepGuess!.entry,
                            );
                            widget.onResume();
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Dort weiterhören'),
                          style: FilledButton.styleFrom(
                            backgroundColor: spotifyGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () =>
                            widget.onDismissSleep(widget.sleepGuess!.at),
                        child: const Text('Ausblenden'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (resumeCandidate != null) ...[
          Card(
            color: spotifyGreen.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zurück zu:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resumeCandidate.groupTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resumeCandidate.title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'bei ${formatMs(resumeCandidate.positionMs)} · ${formatAgo(resumeCandidate.lastSeenAt, DateTime.now().millisecondsSinceEpoch)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await startResume(context, resumeCandidate);
                        widget.onResume();
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Weiterhören'),
                      style: FilledButton.styleFrom(
                        backgroundColor: spotifyGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (widget.current != null) ...[
          const Text(
            'Jetzt läuft:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.current!.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.current!.artist,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.current!.durationMs > 0
                          ? widget.current!.positionMs /
                                widget.current!.durationMs
                          : 0,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatMs(widget.current!.positionMs),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        formatMs(widget.current!.durationMs),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await widget.onPinCurrent();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Gemerkt – zu finden unter Verlauf → Gemerkt'
                                  : 'Noch nicht im Verlauf – gleich nochmal versuchen',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bookmark),
                      label: const Text('Merken'),
                      style: FilledButton.styleFrom(
                        backgroundColor: spotifyGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nichts läuft gerade',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class HistoryScreen extends StatefulWidget {
  final List<Entry> history;
  final List<SleepGuess> sleepMarks;
  final FilterRange filterRange;
  final FilterKind filterKind;
  final String searchQuery;
  final Function(FilterRange) onFilterRangeChanged;
  final Function(FilterKind) onFilterKindChanged;
  final Function(String) onSearchChanged;
  final Function(Entry, bool) onPinChanged;
  final Function(Entry) onDelete;

  const HistoryScreen({
    super.key,
    required this.history,
    this.sleepMarks = const [],
    required this.filterRange,
    required this.filterKind,
    required this.searchQuery,
    required this.onFilterRangeChanged,
    required this.onFilterKindChanged,
    required this.onSearchChanged,
    required this.onPinChanged,
    required this.onDelete,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final filtered = filterHistory(
      widget.history,
      widget.filterRange,
      widget.filterKind,
      widget.searchQuery,
      null,
      DateTime.now().millisecondsSinceEpoch,
    );
    final marks = filterSleepMarks(
      widget.sleepMarks,
      widget.filterRange,
      widget.filterKind,
      widget.searchQuery,
      DateTime.now().millisecondsSinceEpoch,
    );
    // Einträge und Einschlaf-Stellen zeitlich gemischt, neueste zuerst.
    int timeOf(Object o) => o is SleepGuess ? o.at : (o as Entry).startedAt;
    final items = <Object>[...filtered, ...marks]
      ..sort((a, b) => timeOf(b).compareTo(timeOf(a)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time filter chips
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Alle'),
                    selected: widget.filterRange == FilterRange.all,
                    onSelected: (_) {
                      widget.onFilterRangeChanged(FilterRange.all);
                    },
                  ),
                  FilterChip(
                    label: const Text('Diese Woche'),
                    selected: widget.filterRange == FilterRange.week,
                    onSelected: (_) {
                      widget.onFilterRangeChanged(FilterRange.week);
                    },
                  ),
                  FilterChip(
                    label: const Text('Heute'),
                    selected: widget.filterRange == FilterRange.today,
                    onSelected: (_) {
                      widget.onFilterRangeChanged(FilterRange.today);
                    },
                  ),
                  FilterChip(
                    label: const Text('Gestern'),
                    selected: widget.filterRange == FilterRange.yesterday,
                    onSelected: (_) {
                      widget.onFilterRangeChanged(FilterRange.yesterday);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Kind filter chips
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Alle'),
                    selected: widget.filterKind == FilterKind.all,
                    onSelected: (_) {
                      widget.onFilterKindChanged(FilterKind.all);
                    },
                  ),
                  FilterChip(
                    label: const Text('Hörbücher'),
                    selected: widget.filterKind == FilterKind.spoken,
                    onSelected: (_) {
                      widget.onFilterKindChanged(FilterKind.spoken);
                    },
                  ),
                  FilterChip(
                    label: const Text('Musik'),
                    selected: widget.filterKind == FilterKind.music,
                    onSelected: (_) {
                      widget.onFilterKindChanged(FilterKind.music);
                    },
                  ),
                  FilterChip(
                    label: const Text('📌'),
                    selected: widget.filterKind == FilterKind.pinned,
                    onSelected: (_) {
                      widget.onFilterKindChanged(FilterKind.pinned);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search field
              TextField(
                decoration: InputDecoration(
                  hintText: 'Suchen',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (query) {
                  widget.onSearchChanged(query);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Kein Verlauf',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is SleepGuess) return SleepMarkCard(mark: item);
                    final entry = item as Entry;
                    return HistoryEntryCard(
                      entry: entry,
                      onPin: (pinned) {
                        widget.onPinChanged(entry, pinned);
                      },
                      onDelete: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Löschen?'),
                              content: Text('${entry.title} wirklich löschen?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Abbrechen'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    widget.onDelete(entry);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Löschen'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class HistoryEntryCard extends StatelessWidget {
  final Entry entry;
  final Function(bool) onPin;
  final VoidCallback onDelete;

  const HistoryEntryCard({
    super.key,
    required this.entry,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.artist,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.kind == 'spoken' ? '📖' : '🎵',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${formatAgo(entry.startedAt, DateTime.now().millisecondsSinceEpoch)} · ${formatMs(entry.positionMs)} / ${formatMs(entry.durationMs)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => startResume(context, entry),
                  iconSize: 20,
                ),
                IconButton(
                  icon: Icon(
                    entry.pinned ? Icons.bookmark : Icons.bookmark_outline,
                    color: entry.pinned ? spotifyGreen : null,
                  ),
                  onPressed: () {
                    onPin(!entry.pinned);
                  },
                  iconSize: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                  iconSize: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final List<Entry> history;
  final VoidCallback onExport;
  final VoidCallback onClear;

  const SettingsScreen({
    super.key,
    required this.history,
    required this.onExport,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Berechtigung',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Benachrichtigungszugriff erforderlich'),
                const SizedBox(height: 8),
                const Text(
                  'Spotify-Einstellung: Geräte-Broadcast-Status einschalten',
                ),
                const SizedBox(height: 8),
                const Text('Akku-Optimierung: App nicht beschränken'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await Native.openPermissionSettings();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: spotifyGreen,
                    ),
                    child: const Text('Einstellungen öffnen'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Verlauf',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onExport,
          style: FilledButton.styleFrom(backgroundColor: spotifyGreen),
          child: const Text('Verlauf exportieren'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Verlauf löschen?'),
                  content: const Text(
                    'Alle Einträge werden gelöscht. Dies kann nicht rückgängig gemacht werden.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                    ),
                    TextButton(
                      onPressed: () {
                        onClear();
                        Navigator.pop(context);
                      },
                      child: const Text('Löschen'),
                    ),
                  ],
                );
              },
            );
          },
          child: const Text('Verlauf löschen'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Diagnose',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        DiagnosticsCard(),
      ],
    );
  }
}

class DiagnosticsCard extends StatefulWidget {
  const DiagnosticsCard({super.key});

  @override
  State<DiagnosticsCard> createState() => _DiagnosticsCardState();
}

/// Diagnose vom Handy plus lesbare Zeiten und die letzten Wachzeichen.
Future<Map<String, dynamic>> collectDiagnostics() async {
  final diag = Map<String, dynamic>.from(await Native.getDiagnostics());
  for (final key in ['lastMotionAt', 'lastScreenAt']) {
    final v = diag[key];
    if (v is int) diag['${key}Lesbar'] = formatClock(v);
  }
  diag['letzteWachzeichen'] = recentActivityLines(await Storage.loadActivity());
  return diag;
}

class _DiagnosticsCardState extends State<DiagnosticsCard> {
  Map<String, dynamic> _diagnostics = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    final diag = await collectDiagnostics();
    if (!mounted) return;
    setState(() {
      _diagnostics = diag;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Letzte Wachzeichen',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if ((_diagnostics['letzteWachzeichen'] as List?)?.isEmpty ?? true)
              const Text('Noch keine aufgezeichnet.')
            else
              for (final line in _diagnostics['letzteWachzeichen'] as List)
                Text('$line', style: const TextStyle(fontSize: 13)),
            const Divider(height: 24),
            ..._diagnostics.entries
                .where((e) => e.key != 'letzteWachzeichen')
                .map((e) {
                  final key = e.key;
                  final value = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '$key: $value',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final fresh = await collectDiagnostics();
                  final text = const JsonEncoder.withIndent('  ')
                      .convert(fresh);
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!mounted) return;
                  setState(() => _diagnostics = fresh);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Diagnose kopiert – schick sie mir einfach',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.content_copy),
                label: const Text('Kopieren'),
                style: FilledButton.styleFrom(backgroundColor: spotifyGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eintrag „😴 Eingeschlafen um …“ im Verlauf – antippen = dort weiterhören.
class SleepMarkCard extends StatelessWidget {
  final SleepGuess mark;

  const SleepMarkCard({super.key, required this.mark});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.fromMillisecondsSinceEpoch(mark.at);
    String two(int n) => n.toString().padLeft(2, '0');
    const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final when =
        '${days[d.weekday - 1]} ${two(d.day)}.${two(d.month)}. um ${two(d.hour)}:${two(d.minute)}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.indigo.withValues(alpha: 0.12),
      child: ListTile(
        leading: const Text('😴', style: TextStyle(fontSize: 28)),
        title: Text('Eingeschlafen $when'),
        subtitle: Text(
          '${mark.entry.groupTitle}\n'
          '${mark.entry.title} · bei ${formatMs(mark.entry.positionMs)}\n'
          'danach lief es noch ${mark.playedAfterMin} Min. · erkannt über ${mark.source}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.play_arrow),
          tooltip: 'Dort weiterhören',
          onPressed: () => startResume(context, mark.entry),
        ),
        onTap: () => startResume(context, mark.entry),
      ),
    );
  }
}
