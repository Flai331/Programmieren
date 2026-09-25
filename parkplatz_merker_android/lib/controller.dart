import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'logic/models.dart';
import 'logic/detection.dart';
import 'logic/spots.dart';
import 'native.dart';
import 'storage.dart';

class AppController extends ChangeNotifier {
  final Storage _storage;
  Future<void>? _refreshing;
  bool _ready = false;

  List<RawEvent> _events = [];
  List<ParkingSpot> _spots = [];
  Set<String> _deletedIds = {};
  Map<String, dynamic> _config = {};
  ParkingSpot? _myLocation;
  Timer? _refreshTimer;
  Timer? _statusTimer;
  String? _lastWidgetJson;

  AppController({Storage? storage}) : _storage = storage ?? Storage();

  Storage get storage => _storage;
  bool get ready => _ready;

  ParkingSpot? spotById(String id) {
    for (final s in _spots) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Einstellungen neu von der nativen Seite laden.
  Future<void> reloadConfig() async {
    _config = await NativeBridge.getConfig();
    notifyListeners();
  }

  /// Einstellungen ändern (nur übergebene Werte) und neu laden.
  Future<void> updateConfig({
    bool? activityEnabled,
    bool? chargerEnabled,
    String? deviceMode,
    String? deviceAddress,
    String? deviceName,
    String? launchPackage,
    String? launchLabel,
    bool? closeOnGone,
    String? closeActionTitle,
    int? closeActionIndex,
    bool? forceStopFallback,
    List<Map<String, dynamic>>? launchApps,
    bool? volumeEnabled,
    int? volMusic,
    int? volRing,
    int? volNotification,
    String? ringerMode,
    bool? volumeRestore,
  }) async {
    await NativeBridge.setConfig(
      activityEnabled: activityEnabled,
      chargerEnabled: chargerEnabled,
      deviceMode: deviceMode,
      deviceAddress: deviceAddress,
      deviceName: deviceName,
      launchPackage: launchPackage,
      launchLabel: launchLabel,
      closeOnGone: closeOnGone,
      closeActionTitle: closeActionTitle,
      closeActionIndex: closeActionIndex,
      forceStopFallback: forceStopFallback,
      launchApps: launchApps,
      volumeEnabled: volumeEnabled,
      volMusic: volMusic,
      volRing: volRing,
      volNotification: volNotification,
      ringerMode: ringerMode,
      volumeRestore: volumeRestore,
    );
    await reloadConfig();
  }

  List<RawEvent> get events => _events;
  List<ParkingSpot> get spots => _spots;
  ParkingSpot? get latest => _spots.isNotEmpty ? _spots.first : null;
  LocSample? get myLocation {
    if (_myLocation == null) return null;
    return LocSample(
      t: _myLocation!.time,
      lat: _myLocation!.lat,
      lng: _myLocation!.lng,
      acc: _myLocation!.acc,
    );
  }

  bool get tripRunning {
    final now = DateTime.now().millisecondsSinceEpoch;
    return tripInProgress(_events, now);
  }

  Map<String, dynamic> get config => _config;

  Future<void> initialize({bool background = false}) async {
    await _storage.initialize();
    _events = await _storage.loadEvents();
    _spots = await _storage.loadSpots();
    _deletedIds = await _storage.loadDeletedIds();
    _config = await NativeBridge.getConfig();
    _ready = true;
    notifyListeners();

    if (!background) {
      // Bei jedem Start (neu) registrieren – die Registrierung kann nach
      // Updates von Play-Diensten oder „Beenden erzwingen” verloren gehen.
      await NativeBridge.registerTransitions();

      // Regelmäßig auffrischen: alle 15 s
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        await refresh();
      });
    }

    await refresh();

    // Status wird in der UI aktualisiert
  }

  /// Holt neue Rohereignisse ab und berechnet die Parkplätze neu.
  /// Gleichzeitige Aufrufe teilen sich einen Durchlauf.
  Future<void> refresh() {
    if (!_ready) return Future.value();
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _doRefresh() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Ereignisse holen
      final newLines = await NativeBridge.drainEvents();
      if (newLines.isNotEmpty) {
        // Duplikate vermeiden über die JSON-Zeichenkette
        final known = _events.map((e) => jsonEncode(e.toJson())).toSet();
        for (final line in newLines) {
          final event = RawEvent.tryParse(line);
          if (event != null && known.add(jsonEncode(event.toJson()))) {
            _events.add(event);
          }
        }
      }

      // Nach Zeit sortieren
      _events.sort((a, b) => a.t.compareTo(b.t));

      // Rohereignisse älter als 3 Tage und über 5000 verwerfen
      final threeDaysAgo = now - (3 * 24 * 60 * 60 * 1000);
      _events = _events.where((e) => e.t > threeDaysAgo).toList();
      if (_events.length > 5000) {
        _events = _events.sublist(_events.length - 5000);
      }

      await _storage.saveEvents(_events);

      // Parkplätze erkennen
      final detected = detectParkings(_events, now);
      _spots = mergeSpots(_spots, detected, _deletedIds);
      await _storage.saveSpots(_spots);

      // Adresse für den neuesten Parkplatz abholen
      if (_spots.isNotEmpty && _spots.first.address == null) {
        final first = _spots.first;
        final addr = await NativeBridge.reverseGeocode(first.lat, first.lng);
        final idx = _spots.indexWhere((s) => s.id == first.id);
        if (addr != null &&
            idx != -1 &&
            _spots[idx].lat == first.lat &&
            _spots[idx].lng == first.lng) {
          _spots[idx] = _spots[idx].copyWith(address: addr);
          await _storage.saveSpots(_spots);
        }
      }

      // Eigener Standort
      final lastLoc = await NativeBridge.getLastLocation();
      if (lastLoc != null) {
        final lat = (lastLoc['lat'] as num?)?.toDouble();
        final lng = (lastLoc['lng'] as num?)?.toDouble();
        final acc = (lastLoc['acc'] as num?)?.toDouble();
        final t = (lastLoc['t'] as num?)?.toInt() ?? 0;
        if (lat != null && lng != null && acc != null) {
          _myLocation = ParkingSpot(
            id: 'my-location',
            time: t,
            lat: lat,
            lng: lng,
            acc: acc,
            sources: [],
            manual: false,
          );
        }
      }

      // Widget aktualisieren
      await _syncWidget();

      notifyListeners();
    } catch (e) {
      debugPrint('refresh error: $e');
    }
  }

  Future<void> _syncWidget() async {
    final latest = _spots.isNotEmpty ? _spots.first : null;
    final widgetData = latest != null
        ? {
            'time': latest.time,
            'lat': latest.lat,
            'lng': latest.lng,
            'acc': latest.acc,
            'address': latest.address,
            'note': latest.note,
            'source': latest.sourceLabel,
          }
        : null;
    final json = jsonEncode(widgetData);
    if (json != _lastWidgetJson) {
      _lastWidgetJson = json;
      await NativeBridge.updateWidget(widgetData);
    }
  }

  Future<void> pausedRefresh() {
    // Cleanup wenn die App in den Hintergrund geht
    _refreshTimer?.cancel();
    _statusTimer?.cancel();
    return Future.value();
  }

  Future<void> resumedRefresh() async {
    // Neu von der Platte laden (der Hintergrund-Lauf kann sie inzwischen geändert haben)
    _events = await _storage.loadEvents();
    _spots = await _storage.loadSpots();
    _deletedIds = await _storage.loadDeletedIds();

    await refresh();
    // Timer neu starten
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await refresh();
    });

    // Status wird in der UI aktualisiert
  }

  Future<String?> parkHere() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final loc = await NativeBridge.getCurrentLocation();

      if (loc == null) {
        return 'Standort nicht verfügbar – ist GPS an?';
      }

      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      final acc = (loc['acc'] as num?)?.toDouble();

      if (lat == null || lng == null || acc == null) {
        return 'Standort nicht verfügbar – ist GPS an?';
      }

      // Manuelles Ereignis
      final event = RawEvent(
        type: 'manual',
        t: now,
        data: {
          'type': 'manual',
          't': now,
          'source': 'app',
          'lat': lat,
          'lng': lng,
          'acc': acc,
          'error': null,
        },
      );

      // Nach einem evtl. laufenden Abholen einfügen, dann neu berechnen.
      await refresh();
      _events.add(event);
      await _storage.saveEvents(_events);
      await refresh();
      return null; // Kein Fehler
    } catch (e) {
      return 'Fehler: $e';
    }
  }

  Future<void> deleteSpot(String id) async {
    _deletedIds.add(id);
    await _storage.saveDeletedIds(_deletedIds);

    final spot = _spots.firstWhere(
      (s) => s.id == id,
      orElse: () {
        return ParkingSpot(
          id: '',
          time: 0,
          lat: 0,
          lng: 0,
          acc: 0,
          sources: [],
          manual: false,
        );
      },
    );

    if (spot.id.isNotEmpty && spot.photoPath != null) {
      await _storage.deletePhoto(spot.photoPath);
    }

    if (spot.reminderAt != null) {
      await NativeBridge.cancelReminder();
    }

    _spots.removeWhere((s) => s.id == id);
    await _storage.saveSpots(_spots);
    await _syncWidget();
    notifyListeners();
  }

  Future<void> setNote(String spotId, String note) async {
    final idx = _spots.indexWhere((s) => s.id == spotId);
    if (idx != -1) {
      _spots[idx] = _spots[idx].copyWith(note: note);
      await _storage.saveSpots(_spots);
      await _syncWidget();
      notifyListeners();
    }
  }

  Future<void> setPhoto(String spotId, String photoPath) async {
    final idx = _spots.indexWhere((s) => s.id == spotId);
    if (idx != -1) {
      _spots[idx] = _spots[idx].copyWith(photoPath: photoPath);
      await _storage.saveSpots(_spots);
      notifyListeners();
    }
  }

  Future<void> removePhoto(String spotId) async {
    final idx = _spots.indexWhere((s) => s.id == spotId);
    if (idx != -1) {
      if (_spots[idx].photoPath != null) {
        await _storage.deletePhoto(_spots[idx].photoPath);
      }
      _spots[idx] = _spots[idx].copyWith(clearPhoto: true);
      await _storage.saveSpots(_spots);
      notifyListeners();
    }
  }

  Future<String?> setReminder(String spotId, DateTime until) async {
    final atMs = until.millisecondsSinceEpoch - (15 * 60 * 1000);
    if (atMs < DateTime.now().millisecondsSinceEpoch) {
      return 'Das ist in weniger als 15 Minuten – keine Erinnerung möglich.';
    }

    final text =
        'Dein Parkschein läuft um ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')} ab.';
    final ok = await NativeBridge.scheduleReminder(atMs, text);
    if (!ok) return 'Erinnerung konnte nicht gestellt werden.';

    // Es gibt nur eine Erinnerung: bei allen anderen Einträgen entfernen.
    for (var i = 0; i < _spots.length; i++) {
      if (_spots[i].id == spotId) {
        _spots[i] = _spots[i].copyWith(
          reminderAt: until.millisecondsSinceEpoch,
        );
      } else if (_spots[i].reminderAt != null) {
        _spots[i] = _spots[i].copyWith(clearReminder: true);
      }
    }
    await _storage.saveSpots(_spots);
    notifyListeners();
    return null;
  }

  Future<void> clearReminder(String spotId) async {
    await NativeBridge.cancelReminder();
    final idx = _spots.indexWhere((s) => s.id == spotId);
    if (idx != -1) {
      _spots[idx] = _spots[idx].copyWith(clearReminder: true);
      await _storage.saveSpots(_spots);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }
}
