import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/lock_status.dart';

void main() {
  Map<String, dynamic> stateMap({
    Map<String, dynamic>? chipLock,
    List<Map<String, dynamic>>? timeLocks,
    List<Map<String, dynamic>>? tags,
    bool hasMasterTag = true,
    bool hasCode = true,
  }) => {
    'profiles': [
      {
        'id': 'p1',
        'name': 'Arbeit',
        'blockedPackages': ['com.a'],
        'defaultMode': 'TIMER',
        'durationMinutes': 45,
        'untilAt': null,
        'pinCalendarEnd': false,
      },
      {
        'id': 'p2',
        'name': 'Nacht',
        'blockedPackages': ['com.b'],
        'defaultMode': 'UNTIL',
        'durationMinutes': 60,
        'untilAt': null,
        'pinCalendarEnd': false,
      },
    ],
    'tags': tags ??
        [
          {'uid': '04AA', 'label': 'Schreibtisch', 'profileId': 'p1', 'isMaster': true},
        ],
    'chipLock': chipLock,
    'timeLocks': timeLocks ?? <Map<String, dynamic>>[],
    'hasMasterTag': hasMasterTag,
    'hasCode': hasCode,
  };

  test('liest Profile und Chips', () {
    final status = LockStatus.fromMap(stateMap());

    expect(status.profiles.first.name, 'Arbeit');
    expect(status.profiles.first.durationMinutes, 45);
    expect(status.profiles.first.mode, LockMode.timer);
    expect(status.tags.single.label, 'Schreibtisch');
    expect(status.tags.single.isMaster, isTrue);
  });

  test('ohne Sperre ist nichts gesperrt', () {
    final status = LockStatus.fromMap(stateMap());

    expect(status.locked, isFalse);
    expect(status.earliestEnd, isNull);
    expect(status.lockedProfileIds, isEmpty);
  });

  test('Chipsperre sperrt ihr Profil ohne Endzeit', () {
    final status = LockStatus.fromMap(stateMap(chipLock: {'profileId': 'p1'}));

    expect(status.locked, isTrue);
    expect(status.isProfileLocked('p1'), isTrue);
    expect(status.isProfileLocked('p2'), isFalse);
    expect(status.earliestEnd, isNull);
  });

  test('liest Chipsperre und Zeitsperre getrennt', () {
    final status = LockStatus.fromMap(stateMap(
      chipLock: {'profileId': 'p1'},
      timeLocks: [
        {'profileId': 'p2', 'mode': 'TIMER', 'endsAt': 1700000000000},
      ],
    ));

    expect(status.isProfileLocked('p1'), isTrue);
    expect(status.isProfileLocked('p2'), isTrue);
    expect(status.timeLocks.length, 1);
    expect(status.timeLockFor('p2')!.mode, LockMode.timer);
    expect(status.timeLockFor('p1'), isNull);
  });

  test('frueheste Endzeit stammt aus der frueher endenden Zeitsperre', () {
    final status = LockStatus.fromMap(stateMap(
      timeLocks: [
        {'profileId': 'p1', 'mode': 'TIMER', 'endsAt': 2000},
        {'profileId': 'p2', 'mode': 'UNTIL', 'endsAt': 1000},
      ],
    ));

    expect(status.earliestEnd, DateTime.fromMillisecondsSinceEpoch(1000));
  });

  test('hasMasterTag wird durchgereicht', () {
    expect(LockStatus.fromMap(stateMap()).hasMasterTag, isTrue);
    expect(LockStatus.fromMap(stateMap(hasMasterTag: false)).hasMasterTag, isFalse);
  });

  test('Einrichtung braucht Chip, Code und mindestens eine App', () {
    expect(LockStatus.fromMap(stateMap()).setupComplete, isTrue);
    expect(LockStatus.fromMap(stateMap(tags: [])).setupComplete, isFalse);
    expect(LockStatus.fromMap(stateMap(hasCode: false)).setupComplete, isFalse);
  });

  test('Kalendereinstellungen werden gelesen', () {
    final status = LockStatus.fromMap({
      'profiles': <dynamic>[],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
      'calendar': {
        'enabled': true,
        'calendarRules': {
          'cal1': {'profileId': 'p1', 'match': 'ALL'},
          'cal2': {'profileId': 'p2', 'match': 'KEYWORD'},
        },
        'keywordMarker': '[Fokus]',
        'keywordProfileId': 'p2',
        'keywordCalendarIds': ['cal3'],
        'permissionGranted': true,
        'windows': <dynamic>[],
        'activeWindows': <dynamic>[],
      },
    });

    expect(status.calendar.enabled, isTrue);
    expect(status.calendar.calendarRules['cal1']!.profileId, 'p1');
    expect(status.calendar.calendarRules['cal1']!.match, CalendarMatch.all);
    expect(status.calendar.calendarRules['cal2']!.match, CalendarMatch.keyword);
    expect(status.calendar.keywordMarker, '[Fokus]');
    expect(status.calendar.keywordCalendarIds, {'cal3'});
    expect(status.calendar.permissionGranted, isTrue);
  });

  test('leere Stichwort-Kalenderliste heisst alle', () {
    final status = LockStatus.fromMap({
      'profiles': <dynamic>[],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
      'calendar': {'enabled': true},
    });

    expect(status.calendar.keywordCalendarIds, isEmpty);
  });

  test('fehlender Kalenderblock ergibt die Vorgaben', () {
    final status = LockStatus.fromMap({
      'profiles': <dynamic>[],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
    });

    expect(status.calendar.enabled, isFalse);
    expect(status.calendar.keywordMarker, '[Riegel]');
  });

  test('laufendes Terminfenster gilt als Sperre', () {
    final status = LockStatus.fromMap({
      'profiles': <dynamic>[],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
      'calendar': {
        'enabled': true,
        'activeWindows': [
          {
            'eventId': 'e1',
            'title': 'Konzept',
            'startsAt': 1000,
            'endsAt': 2000,
            'profileId': 'p1',
          },
        ],
      },
    });

    expect(status.locked, isTrue);
    expect(status.isProfileLocked('p1'), isTrue);
    expect(status.calendar.activeWindows.first.title, 'Konzept');
  });

  test('Atempause-Einstellungen werden gelesen', () {
    final status = LockStatus.fromMap({
      'profiles': [
        {
          'id': 'p1',
          'name': 'Arbeit',
          'blockedPackages': <dynamic>[],
          'defaultMode': 'TIMER',
          'durationMinutes': 60,
          'pinCalendarEnd': false,
          'pauseEnabled': true,
          'pauseStepMinutes': 20,
          'pauseBaseSeconds': 8,
        },
      ],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
    });

    expect(status.profiles.first.pauseEnabled, isTrue);
    expect(status.profiles.first.pauseStepMinutes, 20);
    expect(status.profiles.first.pauseBaseSeconds, 8);
  });

  test('fehlende Atempause-Angaben ergeben die Vorgaben', () {
    final status = LockStatus.fromMap({
      'profiles': [
        {
          'id': 'p1',
          'name': 'Arbeit',
          'blockedPackages': <dynamic>[],
          'defaultMode': 'TIMER',
          'durationMinutes': 60,
          'pinCalendarEnd': false,
        },
      ],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
    });

    expect(status.profiles.first.pauseEnabled, isFalse);
    expect(status.profiles.first.pauseStepMinutes, 15);
    expect(status.profiles.first.pauseBaseSeconds, 5);
  });
}
