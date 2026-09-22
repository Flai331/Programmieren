import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/lock_status.dart';

void main() {
  Map<String, dynamic> stateMap({
    Map<String, dynamic>? chipLock,
    List<Map<String, dynamic>>? timeLocks,
    List<Map<String, dynamic>>? tags,
    bool hasCode = true,
    Map<String, dynamic>? release,
    bool timedRelease = false,
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
        'timedRelease': timedRelease,
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
          {'uid': '04AA', 'label': 'Schreibtisch', 'profileId': 'p1'},
        ],
    'chipLock': chipLock,
    'release': release,
    'timeLocks': timeLocks ?? <Map<String, dynamic>>[],
    'hasCode': hasCode,
  };

  test('liest Profile und Chips', () {
    final status = LockStatus.fromMap(stateMap());

    expect(status.profiles.first.name, 'Arbeit');
    expect(status.profiles.first.durationMinutes, 45);
    expect(status.profiles.first.mode, LockMode.timer);
    expect(status.tags.single.label, 'Schreibtisch');
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
        'keywordMarker': '[Fokus]',
        'permissionGranted': true,
        'windows': <dynamic>[],
        'activeWindows': <dynamic>[],
      },
    });

    expect(status.calendar.enabled, isTrue);
    expect(status.calendar.keywordMarker, '[Fokus]');
    expect(status.calendar.permissionGranted, isTrue);
  });

  test('Profil liest seine Kalenderauswahl', () {
    final status = LockStatus.fromMap({
      'profiles': [
        {
          'id': 'p1',
          'name': 'Arbeit',
          'calendars': {'cal1': 'ALL', 'cal2': 'KEYWORD'},
          'keywordEverywhere': true,
        },
        {'id': 'p2', 'name': 'Nacht'},
      ],
      'tags': <dynamic>[],
      'timeLocks': <dynamic>[],
    });

    final arbeit = status.profiles.first;
    expect(arbeit.calendars, {
      'cal1': CalendarMatch.all,
      'cal2': CalendarMatch.keyword,
    });
    expect(arbeit.keywordEverywhere, isTrue);
    expect(arbeit.usesCalendar, isTrue);
    expect(status.profiles.last.calendars, isEmpty);
    expect(status.profiles.last.usesCalendar, isFalse);
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

  test('Freigabe auf Zeit kommt am Profil an', () {
    final status = LockStatus.fromMap(stateMap(timedRelease: true));

    expect(status.profiles.first.timedRelease, isTrue);
  });

  test('ohne Freigabe sperrt die Chipsperre', () {
    final status = LockStatus.fromMap(stateMap(chipLock: {'profileId': 'p1'}));

    expect(status.locked, isTrue);
    expect(status.isProfileLocked('p1'), isTrue);
    expect(status.releaseEndsAt, isNull);
  });

  test('mit laufender Freigabe gilt das Profil als offen', () {
    final ende = DateTime.now().add(const Duration(minutes: 10));

    final status = LockStatus.fromMap(
      stateMap(
        chipLock: {'profileId': 'p1'},
        release: {'profileId': 'p1', 'endsAt': ende.millisecondsSinceEpoch},
      ),
    );

    expect(status.isProfileLocked('p1'), isFalse);
    expect(status.locked, isFalse);
    expect(status.releaseProfileId, 'p1');
    expect(status.releaseEndsAt, isNotNull);
  });

  test('eine Freigabe oeffnet keine fremde Zeitsperre', () {
    final ende = DateTime.now().add(const Duration(minutes: 10));

    final status = LockStatus.fromMap(
      stateMap(
        chipLock: {'profileId': 'p1'},
        release: {'profileId': 'p1', 'endsAt': ende.millisecondsSinceEpoch},
        timeLocks: [
          {
            'profileId': 'p2',
            'mode': 'TIMER',
            'endsAt': ende.millisecondsSinceEpoch,
          },
        ],
      ),
    );

    expect(status.isProfileLocked('p1'), isFalse);
    expect(status.isProfileLocked('p2'), isTrue);
    expect(status.locked, isTrue);
  });

  test('der Klingelmodus kommt aus der Kanal-Antwort', () {
    final profil = ProfileInfo.fromMap({
      'id': 'p1',
      'name': 'Nacht',
      'quietRinger': 'VIBRIEREN',
    });

    expect(profil.quietRinger, RingerMode.vibrieren);
  });

  test('ohne Angabe bleibt der Klingelmodus unveraendert', () {
    final profil = ProfileInfo.fromMap({'id': 'p1', 'name': 'Nacht'});

    expect(profil.quietRinger, RingerMode.unveraendert);
  });

  test('ein unbekannter Klingelmodus faellt auf unveraendert zurueck', () {
    final profil = ProfileInfo.fromMap({
      'id': 'p1',
      'name': 'Nacht',
      'quietRinger': 'FLUESTERN',
    });

    expect(profil.quietRinger, RingerMode.unveraendert);
  });

  // withBlockedPackages ist eine eigene Methode statt Feld-fuer-Feld-Kopie
  // beim Aufrufer (Setup-Wizard): dort ging jedes neue Feld still verloren,
  // etwa die Kalenderauswahl und der Klingelmodus.
  test('withBlockedPackages behaelt alle anderen Felder des Profils', () {
    const voll = ProfileInfo(
      id: 'p1',
      name: 'Arbeit',
      blockedPackages: ['com.a'],
      mode: LockMode.until,
      durationMinutes: 77,
      untilAt: null,
      pinCalendarEnd: true,
      timedRelease: true,
      pauseEnabled: true,
      pauseStepMinutes: 33,
      pauseBaseSeconds: 9,
      pauseResetMinutes: 44,
      quietEnabled: true,
      quietScope: QuietScope.ausgewaehlte,
      quietNumbers: ['0176123'],
      quietAfterEventMinutes: 12,
      quietWhileLocked: false,
      quietSchedules: [
        QuietScheduleInfo(days: {2, 3}, startMinute: 60, endMinute: 120),
      ],
      quietRinger: RingerMode.vibrieren,
      calendars: {'cal1': CalendarMatch.keyword},
      keywordEverywhere: true,
    );

    final neu = voll.withBlockedPackages(['x']);

    expect(neu.blockedPackages, ['x']);
    expect(neu.id, voll.id);
    expect(neu.name, voll.name);
    expect(neu.mode, voll.mode);
    expect(neu.durationMinutes, voll.durationMinutes);
    expect(neu.untilAt, voll.untilAt);
    expect(neu.pinCalendarEnd, voll.pinCalendarEnd);
    expect(neu.timedRelease, voll.timedRelease);
    expect(neu.pauseEnabled, voll.pauseEnabled);
    expect(neu.pauseStepMinutes, voll.pauseStepMinutes);
    expect(neu.pauseBaseSeconds, voll.pauseBaseSeconds);
    expect(neu.pauseResetMinutes, voll.pauseResetMinutes);
    expect(neu.quietEnabled, voll.quietEnabled);
    expect(neu.quietScope, voll.quietScope);
    expect(neu.quietNumbers, voll.quietNumbers);
    expect(neu.quietAfterEventMinutes, voll.quietAfterEventMinutes);
    expect(neu.quietWhileLocked, voll.quietWhileLocked);
    expect(neu.quietSchedules, voll.quietSchedules);
    expect(neu.quietRinger, voll.quietRinger);
    expect(neu.calendars, voll.calendars);
    expect(neu.keywordEverywhere, voll.keywordEverywhere);
  });
}
