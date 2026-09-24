import 'dart:math';

import 'models.dart';

/// Berechnet die Entfernung in Metern zwischen zwei Koordinaten (Haversine).
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371000; // Erdradius in Metern
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLng / 2) *
          sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _toRadians(double degrees) => degrees * pi / 180.0;

/// Formatiert eine Entfernung in Metern zu einem Text.
String formatDistance(double m) {
  if (m < 1000) {
    // Auf 10 m gerundet, unter 100 m auf 5 m
    int rounded;
    if (m < 100) {
      rounded = ((m + 2.5) ~/ 5) * 5;
    } else {
      rounded = ((m + 5) ~/ 10) * 10;
    }
    return '$rounded m';
  } else {
    // In Kilometer mit Komma (deutsches Format)
    final km = m / 1000;
    final formatted = km.toStringAsFixed(1).replaceAll('.', ',');
    return '$formatted km';
  }
}

/// Formatiert eine DateTime zu „HH:MM".
String formatClock(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Gibt "seit HH:MM", "seit gestern, HH:MM" oder "seit Mo., TT.MM., HH:MM" zurück.
String sinceText(DateTime parked, DateTime now) {
  final clock = formatClock(parked);

  if (_isSameDay(parked, now)) {
    return 'seit $clock';
  }

  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(parked, yesterday)) {
    return 'seit gestern, $clock';
  }

  // Älter: „seit Mo., 22.09., 14:32"
  const weekdays = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
  final weekday = weekdays[parked.weekday - 1]; // DateTime.monday == 1
  final day = parked.day.toString().padLeft(2, '0');
  final month = parked.month.toString().padLeft(2, '0');

  return 'seit $weekday, $day.$month., $clock';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Gibt die Überschrift „Dein Auto steht seit HH:MM hier" zurück.
String headline(ParkingSpot s, DateTime now) {
  final parked = DateTime.fromMillisecondsSinceEpoch(s.time);
  return 'Dein Auto steht ${sinceText(parked, now)} hier';
}

/// Formatiert die Genauigkeit.
String accuracyText(double acc) {
  final rounded = (acc + 0.5).toInt();
  return 'Genauigkeit ± $rounded m';
}

/// Formatiert DateTime zu „TT.MM. HH:MM".
String formatDateTime(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');

  return '$day.$month. $hour:$minute';
}
