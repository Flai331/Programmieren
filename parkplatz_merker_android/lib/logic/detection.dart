import 'models.dart';

// Konstanten
const minTripMs = 3 * 60 * 1000; // Fahrten < 3 min ignorieren
const shortHaltMs = 2 * 60 * 1000; // Halte < 2 min gehören zur Fahrt
const noWalkFinalizeMs = 15 * 60 * 1000; // ohne Gehen: nach 15 min trotzdem Parkplatz
const chargerBeforeExitMs = 10 * 60 * 1000;
const afterExitMs = 5 * 60 * 1000;
const locWindowMs = 2 * 60 * 1000;
const locFallbackMs = 10 * 60 * 1000;

class Trip {
  late int start;
  int? exit;
  bool walkedAfterExit = false;
  int? walkT;
}

class TripResult {
  final Trip trip;
  final ParkingSpot? spot;
  final String status;

  TripResult({
    required this.trip,
    required this.spot,
    required this.status,
  });
}

/// Baut eine Liste von Fahrten aus Rohereignissen.
List<Trip> buildTrips(List<RawEvent> events) {
  // Nach Zeit sortieren
  final sorted = List<RawEvent>.from(events)
    ..sort((a, b) => a.t.compareTo(b.t));

  final trips = <Trip>[];
  Trip? currentTrip;

  for (final event in sorted) {
    if (event.type != 'activity') continue;

    final activity = event.str('activity');
    final transition = event.str('transition');

    if (activity == 'IN_VEHICLE' && transition == 'ENTER') {
      if (currentTrip == null) {
        // Erste Fahrt
        currentTrip = Trip()..start = event.t;
      } else if (currentTrip.exit != null) {
        // Fahrt mit exit - entscheiden, ob gleiche oder neue
        final timeSinceExit = event.t - currentTrip.exit!;

        if (timeSinceExit < shortHaltMs) {
          // Gleiche Fahrt (Ampel/Stau)
          currentTrip.exit = null;
          currentTrip.walkedAfterExit = false;
        } else if (!currentTrip.walkedAfterExit) {
          // Prüfe auf starken Hinweis
          final hasStrongHint = _hasStrongHint(sorted, currentTrip.exit!, event.t);
          if (!hasStrongHint) {
            // Gleiche Fahrt (langer Stau ohne Aussteigen)
            currentTrip.exit = null;
            currentTrip.walkedAfterExit = false;
          } else {
            // Fahrt abschließen, neue Fahrt
            trips.add(currentTrip);
            currentTrip = Trip()..start = event.t;
          }
        } else {
          // Fahrt abschließen, neue Fahrt
          trips.add(currentTrip);
          currentTrip = Trip()..start = event.t;
        }
      }
      // Wenn Fahrt offen (exit==null): ignorieren (doppeltes ENTER)
    } else if (activity == 'IN_VEHICLE' && transition == 'EXIT') {
      if (currentTrip != null && currentTrip.exit == null) {
        currentTrip.exit = event.t;
        currentTrip.walkedAfterExit = false;
      }
    } else if ((activity == 'WALKING' || activity == 'RUNNING') &&
        transition == 'ENTER') {
      if (currentTrip != null &&
          currentTrip.exit != null &&
          event.t >= currentTrip.exit! - 60 * 1000) {
        currentTrip.walkedAfterExit = true;
        currentTrip.walkT ??= event.t;
      }
    }
  }

  if (currentTrip != null) {
    trips.add(currentTrip);
  }

  return trips;
}

bool _hasStrongHint(List<RawEvent> events, int exitTime, int enterTime) {
  for (final event in events) {
    if (event.t < exitTime - chargerBeforeExitMs || event.t > enterTime) continue;

    if (event.type == 'power') {
      final plugged = event.boolean('plugged');
      final reason = event.str('reason');
      if (plugged == false && reason == 'change') return true;
    }

    if (event.type == 'scan') {
      final found = event.boolean('found');
      if (found == false && event.t > exitTime) return true;
    }
  }
  return false;
}

/// Wählt den besten Standort aus einer Liste von Proben.
LocSample? pickLocation(List<LocSample> samples, int targetT) {
  if (samples.isEmpty) return null;

  // Kandidaten: |s.t - t| <= locWindowMs
  LocSample? best;
  double bestScore = double.infinity;

  for (final s in samples) {
    if ((s.t - targetT).abs() <= locWindowMs) {
      final score = (s.t - targetT).abs() / 1000.0 + s.acc / 2.0;
      if (score < bestScore) {
        bestScore = score;
        best = s;
      }
    }
  }

  if (best != null) return best;

  // Fallback: nächster nach Zeit innerhalb locFallbackMs
  LocSample? fallback;
  int fallbackDist = locFallbackMs + 1;

  for (final s in samples) {
    final dist = (s.t - targetT).abs();
    if (dist < fallbackDist && dist <= locFallbackMs) {
      fallbackDist = dist;
      fallback = s;
    }
  }

  return fallback;
}

/// Bewertet alle Fahrten und gibt Erkennungs-Ergebnisse zurück.
List<TripResult> evaluateTrips(List<RawEvent> events, int now) {
  // Nach Zeit sortieren
  final sorted = List<RawEvent>.from(events)
    ..sort((a, b) => a.t.compareTo(b.t));

  // Standorte sammeln
  final allLocations = <LocSample>[];
  for (final event in sorted) {
    if (event.type == 'loc') {
      final lat = event.dbl('lat');
      final lng = event.dbl('lng');
      final acc = event.dbl('acc');
      if (lat != null && lng != null && acc != null) {
        allLocations.add(LocSample(t: event.t, lat: lat, lng: lng, acc: acc));
      }
    }
  }

  final trips = buildTrips(sorted);
  final results = <TripResult>[];

  for (final trip in trips) {
    if (trip.exit == null) {
      // Laufende Fahrt
      results.add(TripResult(
        trip: trip,
        spot: null,
        status: 'läuft',
      ));
      continue;
    }

    // Kurz?
    if (trip.exit! - trip.start < minTripMs) {
      results.add(TripResult(
        trip: trip,
        spot: null,
        status: 'zu kurz',
      ));
      continue;
    }

    // Fertig?
    final isFinal = _isFinalizedTrip(trip, trips, sorted, now);
    if (!isFinal) {
      results.add(TripResult(
        trip: trip,
        spot: null,
        status: 'wartet auf Aussteigen',
      ));
      continue;
    }

    // Ereignisfenster
    final windowStart = trip.start - 2 * 60 * 1000;
    final nextTripStart = _nextTripStart(trip, trips);
    final windowEnd = nextTripStart != null
        ? (trip.exit! + afterExitMs < nextTripStart ? trip.exit! + afterExitMs : nextTripStart)
        : trip.exit! + afterExitMs;

    // Gerät-Status
    final deviceInfo = _analyzeDevice(sorted, windowStart, windowEnd);
    if (deviceInfo.rejected != null) {
      results.add(TripResult(
        trip: trip,
        spot: null,
        status: deviceInfo.rejected!,
      ));
      continue;
    }

    // Ladekabel
    final chargerTime = _findChargerTime(sorted, trip.exit!, windowEnd);

    // Ausstiegszeitpunkt
    int exitTime = trip.exit!;
    if (chargerTime != null) {
      exitTime = chargerTime;
    } else if (deviceInfo.gone != null) {
      if (trip.exit! > deviceInfo.gone!.lastSeen &&
          trip.exit! <= deviceInfo.gone!.firstMiss) {
        exitTime = trip.exit!;
      } else {
        exitTime = deviceInfo.gone!.firstMiss;
      }
    }

    // Quellen
    final sources = <String>['Aussteigen'];
    if (chargerTime != null) sources.add('Ladekabel ab');
    if (deviceInfo.gone != null) {
      sources.add(deviceInfo.deviceMode == 'transmitter'
          ? 'Transmitter weg'
          : 'Beacon weg');
    }

    // Standort
    final locSample = pickLocation(allLocations, exitTime);
    if (locSample == null) {
      results.add(TripResult(
        trip: trip,
        spot: null,
        status: 'kein Standort',
      ));
      continue;
    }

    // Parkplatz erstellt
    final spot = ParkingSpot(
      id: 'auto-${trip.start}',
      time: exitTime,
      lat: locSample.lat,
      lng: locSample.lng,
      acc: locSample.acc,
      sources: sources,
      manual: false,
    );

    results.add(TripResult(
      trip: trip,
      spot: spot,
      status: 'Parkplatz',
    ));
  }

  return results;
}

bool _isFinalizedTrip(Trip trip, List<Trip> allTrips, List<RawEvent> events, int now) {
  final nextTrip = allTrips.firstWhere(
    (t) => t.start > trip.exit!,
    orElse: () => Trip()..start = now + 1000000,
  );

  if (nextTrip.start <= now) {
    // Es folgt eine neue Fahrt: Trip ist fertig
    return true;
  }

  if (now - trip.exit! < shortHaltMs) {
    return false;
  }

  if (trip.walkedAfterExit) {
    return true;
  }

  // Starker Hinweis?
  for (final event in events) {
    if (event.t < trip.exit! - chargerBeforeExitMs || event.t > now) continue;
    if (event.type == 'power' && event.boolean('plugged') == false && event.str('reason') == 'change') {
      return true;
    }
    if (event.type == 'scan' && event.t > trip.exit! && event.boolean('found') == false) {
      return true;
    }
  }

  if (now - trip.exit! >= noWalkFinalizeMs) {
    return true;
  }

  return false;
}

int? _nextTripStart(Trip trip, List<Trip> allTrips) {
  for (final t in allTrips) {
    if (t.start > trip.exit!) {
      return t.start;
    }
  }
  return null;
}

class _DeviceInfo {
  bool deviceChecked = false;
  bool seen = false;
  _Gone? gone;
  String? rejected;
  String deviceMode = 'transmitter';
}

class _Gone {
  int lastSeen;
  int firstMiss;
  _Gone({required this.lastSeen, required this.firstMiss});
}

_DeviceInfo _analyzeDevice(List<RawEvent> events, int windowStart, int windowEnd) {
  final info = _DeviceInfo();
  int? lastSeenT;
  int? firstMissT;
  bool foundInWindow = false;

  for (final event in events) {
    if (event.t < windowStart || event.t > windowEnd) continue;

    if (event.type == 'scan') {
      final ok = event.boolean('ok');
      final found = event.boolean('found');

      if (ok == true) {
        info.deviceChecked = true;
        if (found == true) {
          foundInWindow = true;
          lastSeenT = event.t;
        } else if (found == false && lastSeenT != null && firstMissT == null) {
          firstMissT = event.t;
        }
      }

      final mode = event.str('mode');
      if (mode != null) info.deviceMode = mode;
    }

    if (event.type == 'beacon_bg') {
      foundInWindow = true;
    }
  }

  info.seen = foundInWindow;

  if (info.deviceChecked && !info.seen) {
    info.rejected = 'Gerät nie gesehen – vermutlich nicht dein Auto';
    return info;
  }

  if (lastSeenT != null && firstMissT != null) {
    info.gone = _Gone(lastSeen: lastSeenT, firstMiss: firstMissT);
  }

  return info;
}

int? _findChargerTime(List<RawEvent> events, int exitTime, int windowEnd) {
  int? lastPluggedTrueTime;
  int? candidateTime;

  for (final event in events) {
    if (event.type != 'power') continue;

    final plugged = event.boolean('plugged');
    final reason = event.str('reason');

    if (plugged == true) {
      lastPluggedTrueTime = event.t;
    } else if (plugged == false && reason == 'change') {
      if (event.t >= exitTime - chargerBeforeExitMs &&
          event.t <= exitTime + afterExitMs &&
          lastPluggedTrueTime != null) {
        candidateTime = event.t;
      }
    }
  }

  if (candidateTime != null) {
    // Prüfe, ob kein plugged==true nach candidateTime kommt bis windowEnd
    for (final event in events) {
      if (event.type != 'power') continue;
      if (event.t <= candidateTime || event.t > windowEnd) continue;
      if (event.boolean('plugged') == true) {
        return null;
      }
    }
    return candidateTime;
  }

  return null;
}

/// Erkennt Parkplätze aus Rohereignissen.
List<ParkingSpot> detectParkings(List<RawEvent> events, int now) {
  final results = evaluateTrips(events, now);
  final spots = <ParkingSpot>[];

  for (final result in results) {
    if (result.spot != null) {
      spots.add(result.spot!);
    }
  }

  // Manuelle Ereignisse hinzufügen
  for (final event in events) {
    if (event.type == 'manual') {
      final lat = event.dbl('lat');
      final lng = event.dbl('lng');
      final acc = event.dbl('acc');

      if (lat != null && lng != null && acc != null) {
        final source = event.str('source');
        final sourceLabel = _manualSourceLabel(source);

        spots.add(ParkingSpot(
          id: 'manual-${event.t}',
          time: event.t,
          lat: lat,
          lng: lng,
          acc: acc,
          sources: [sourceLabel],
          manual: true,
        ));
      }
    }
  }

  return spots;
}

String _manualSourceLabel(String? source) {
  return switch (source) {
    'widget' => 'Manuell (Widget)',
    'tile' => 'Manuell (Kachel)',
    'app' => 'Manuell (App)',
    _ => 'Manuell',
  };
}

/// Prüft, ob eine Fahrt läuft.
bool tripInProgress(List<RawEvent> events, int now) {
  final trips = buildTrips(events);
  for (final trip in trips) {
    if (trip.exit == null) {
      return true;
    }
  }
  return false;
}
