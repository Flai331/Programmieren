import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'logic/models.dart';
import 'logic/detection.dart';
import 'logic/spots.dart';
import 'native.dart';
import 'storage.dart';

class AppController extends ChangeNotifier {
  final NativeBridge _native;
  final Storage _storage;

  List<RawEvent> _events = [];
  List<ParkingSpot> _spots = [];
  Set<String> _deletedIds = {};
  Map<String, dynamic> _config = {};
  ParkingSpot? _myLocation;
  Timer? _refreshTimer;
  Timer? _statusTimer;

  AppController({
    NativeBridge? native,
    Storage? storage,
  })  : _native = native ?? NativeBridge(),
        _storage = storage ?? Storage();

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

  Future<void> initialize() async {
    await _storage.initialize();
    _events = await _storage.loadEvents();
    _spots = await _storage.loadSpots();
    _deletedIds = await _storage.loadDeletedIds();
    _config = await NativeBridge.getConfig();

    await refresh();

    // Regelmäßig auffrischen: alle 15 s
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await refresh();
    });

    // Status wird in der UI aktualisiert
  }

  Future<void> refresh() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Ereignisse holen
      final newLines = await NativeBridge.drainEvents();
      for (final line in newLines) {
        final event = RawEvent.tryParse(line);
        if (event != null) {
          // Duplikate vermeiden über JSON-String
          final existsAlready =
              _events.any((e) => jsonEncode(e.toJson()) == jsonEncode(event.toJson()));
          if (!existsAlready) {
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
        final addr =
            await NativeBridge.reverseGeocode(_spots.first.lat, _spots.first.lng);
        if (addr != null) {
          _spots[0] = _spots[0].copyWith(address: addr);
          await _storage.saveSpots(_spots);
        }
      }

      // Eigener Standort
      final lastLoc = await NativeBridge.getLastLocation();
      if (lastLoc != null) {
        final lat = (lastLoc['lat'] as num?)?.toDouble();
        final lng = (lastLoc['lng'] as num?)?.toDouble();
        final acc = (lastLoc['acc'] as num?)?.toDouble();
        final t = lastLoc['t'] as int? ?? 0;
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

      notifyListeners();
    } catch (e) {
      print('refresh error: $e');
    }
  }

  Future<void> pausedRefresh() {
    // Cleanup wenn die App in den Hintergrund geht
    _refreshTimer?.cancel();
    _statusTimer?.cancel();
    return Future.value();
  }

  Future<void> resumedRefresh() async {
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

      _events.add(event);
      await _storage.saveEvents(_events);

      // Neu berechnen
      await refresh();
      return null; // Kein Fehler
    } catch (e) {
      return 'Fehler: $e';
    }
  }

  Future<void> deleteSpot(String id) async {
    _deletedIds.add(id);
    await _storage.saveDeletedIds(_deletedIds);

    final spot = _spots.firstWhere((s) => s.id == id, orElse: () {
      return ParkingSpot(
        id: '',
        time: 0,
        lat: 0,
        lng: 0,
        acc: 0,
        sources: [],
        manual: false,
      );
    });

    if (spot.id.isNotEmpty && spot.photoPath != null) {
      await _storage.deletePhoto(spot.photoPath);
    }

    if (spot.reminderAt != null) {
      await NativeBridge.cancelReminder();
    }

    _spots.removeWhere((s) => s.id == id);
    await _storage.saveSpots(_spots);
    notifyListeners();
  }

  Future<void> setNote(String spotId, String note) async {
    final idx = _spots.indexWhere((s) => s.id == spotId);
    if (idx != -1) {
      _spots[idx] = _spots[idx].copyWith(note: note);
      await _storage.saveSpots(_spots);
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

    if (ok) {
      final idx = _spots.indexWhere((s) => s.id == spotId);
      if (idx != -1) {
        _spots[idx] = _spots[idx].copyWith(reminderAt: until.millisecondsSinceEpoch);
        await _storage.saveSpots(_spots);
        notifyListeners();
      }
    }

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
