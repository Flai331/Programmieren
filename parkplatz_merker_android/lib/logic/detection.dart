import 'models.dart';

// Konstanten
const minTripMs = 3 * 60 * 1000; // Fahrten < 3 min ignorieren
const shortHaltMs = 2 * 60 * 1000; // Halte < 2 min gehören zur Fahrt
const noWalkFinalizeMs =
    15 * 60 * 1000; // ohne Gehen: nach 15 min trotzdem Parkplatz
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

  TripResult({required this.trip, required this.spot, required this.status});
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
          final ev = _evidence(
            sorted,
            currentTrip.start - 2 * 60 * 1000,
            event.t,
            currentTrip.exit!,
          );
          final hasStrongHint = ev.chargerTime != null || ev.gone != null;
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
      results.add(TripResult(trip: trip, spot: null, status: 'läuft'));
      continue;
    }

    // Kurz?
    if (trip.exit! - trip.start < minTripMs) {
      results.add(TripResult(trip: trip, spot: null, status: 'zu kurz'));
      continue;
    }

    // Fertig?
    final isFinal = _isFinalizedTrip(trip, trips, sorted, now);
    if (!isFinal) {
      results.add(
        TripResult(trip: trip, spot: null, status: 'wartet auf Aussteigen'),
      );
      continue;
    }

    // Ereignisfenster
    final windowStart = trip.start - 2 * 60 * 1000;
    final nextTripStart = _nextTripStart(trip, trips);
    final windowEnd = nextTripStart != null
        ? (trip.exit! + afterExitMs < nextTripStart
              ? trip.exit! + afterExitMs
              : nextTripStart)
        : trip.exit! + afterExitMs;

    // Gerät und Ladekabel
    final deviceInfo = _evidence(sorted, windowStart, windowEnd, trip.exit!);
    if (deviceInfo.checked && !deviceInfo.seen) {
      results.add(
        TripResult(
          trip: trip,
          spot: null,
          status: 'Gerät nie gesehen – vermutlich nicht dein Auto',
        ),
      );
      continue;
    }
    final chargerTime = deviceInfo.chargerTime;

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
      sources.add(
        deviceInfo.deviceMode == 'transmitter'
            ? 'Transmitter weg'
            : 'Beacon weg',
      );
    }

    // Standort
    final locSample = pickLocation(allLocations, exitTime);
    if (locSample == null) {
      results.add(TripResult(trip: trip, spot: null, status: 'kein Standort'));
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

    results.add(TripResult(trip: trip, spot: spot, status: 'Parkplatz'));
  }

  return results;
}

bool _isFinalizedTrip(
  Trip trip,
  List<Trip> allTrips,
  List<RawEvent> events,
  int now,
) {
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

  // Starker Hinweis (Ladekabel ab / Gerät weg)?
  final end = trip.exit! + afterExitMs < now ? trip.exit! + afterExitMs : now;
  final ev = _evidence(events, trip.start - 2 * 60 * 1000, end, trip.exit!);
  if (ev.chargerTime != null || ev.gone != null) {
    return true;
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

class _Gone {
  final int lastSeen;
  final int firstMiss;
  _Gone({required this.lastSeen, required this.firstMiss});
}

/// Hinweise aus Gerätesuche und Ladekabel im Fenster [windowStart, windowEnd].
class _Evidence {
  /// Mindestens eine Suche lief erfolgreich (ok == true).
  bool checked = false;

  /// Gerät wurde mindestens einmal gesehen.
  bool seen = false;

  /// Gerät verschwunden: zuletzt gesehen / erste erfolglose Suche danach.
  _Gone? gone;

  /// Zeitpunkt „Ladekabel ab“ nahe am Aussteigen.
  int? chargerTime;

  String deviceMode = 'transmitter';
}

_Evidence _evidence(
  List<RawEvent> sorted,
  int windowStart,
  int windowEnd,
  int exit,
) {
  final ev = _Evidence();
  int? lastSeenT;
  int? firstMissT;
  final power = <RawEvent>[];

  for (final event in sorted) {
    if (event.t < windowStart || event.t > windowEnd) continue;
    if (event.type == 'scan') {
      final mode = event.str('mode');
      if (mode != null) ev.deviceMode = mode;
      if (event.boolean('ok') != true) continue;
      ev.checked = true;
      if (event.boolean('found') == true) {
        ev.seen = true;
        lastSeenT = event.t;
        firstMissT = null; // wieder gesehen → frühere Lücke zählt nicht
      } else if (lastSeenT != null && firstMissT == null) {
        firstMissT = event.t;
      }
    } else if (event.type == 'beacon_bg') {
      ev.seen = true;
    } else if (event.type == 'power') {
      power.add(event);
    }
  }
  if (lastSeenT != null && firstMissT != null) {
    ev.gone = _Gone(lastSeen: lastSeenT, firstMiss: firstMissT);
  }

  // Ladekabel: letztes Abziehen nahe am Aussteigen, vorher eingesteckt,
  // danach bis Fensterende nicht wieder eingesteckt.
  bool pluggedBefore = false;
  int? candidate;
  for (final event in power) {
    final plugged = event.boolean('plugged');
    if (plugged == true) {
      pluggedBefore = true;
      candidate = null;
    } else if (plugged == false) {
      if (event.str('reason') == 'change' &&
          pluggedBefore &&
          event.t >= exit - chargerBeforeExitMs &&
          event.t <= exit + afterExitMs) {
        candidate = event.t;
      }
      pluggedBefore = false;
    }
  }
  ev.chargerTime = candidate;
  return ev;
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

        spots.add(
          ParkingSpot(
            id: 'manual-${event.t}',
            time: event.t,
            lat: lat,
            lng: lng,
            acc: acc,
            sources: [sourceLabel],
            manual: true,
          ),
        );
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
  // Eine Fahrt ohne EXIT, die älter als 8 h ist, gilt nicht mehr als laufend
  // (EXIT verpasst; der Service beendet sich spätestens nach 8 h).
  const staleMs = 8 * 60 * 60 * 1000;
  for (final trip in trips) {
    if (trip.exit == null && now - trip.start < staleMs) {
      return true;
    }
  }
  return false;
}
