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
}
