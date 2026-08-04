import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/lock_status.dart';

void main() {
  Map<String, dynamic> stateMap({
    Map<String, dynamic>? activeLock,
    List<Map<String, dynamic>>? tags,
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
    ],
    'tags': tags ??
        [
          {'uid': '04AA', 'label': 'Schreibtisch', 'profileId': 'p1', 'isMaster': true},
        ],
    'activeLock': activeLock,
    'hasCode': hasCode,
  };

  test('liest Profile und Chips', () {
    final status = LockStatus.fromMap(stateMap());

    expect(status.profiles.single.name, 'Arbeit');
    expect(status.profiles.single.durationMinutes, 45);
    expect(status.profiles.single.mode, LockMode.timer);
    expect(status.tags.single.label, 'Schreibtisch');
    expect(status.tags.single.isMaster, isTrue);
  });

  test('ohne aktive Sperre ist locked false', () {
    final status = LockStatus.fromMap(stateMap());

    expect(status.locked, isFalse);
    expect(status.activeProfile, isNull);
  });

  test('aktive Sperre liefert Profil und Ende', () {
    final status = LockStatus.fromMap(
      stateMap(
        activeLock: {'profileId': 'p1', 'mode': 'UNTIL', 'endsAt': 1700000000000},
      ),
    );

    expect(status.locked, isTrue);
    expect(status.activeProfile!.name, 'Arbeit');
    expect(status.endsAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });

  test('Profil gilt als gesperrt, wenn es gerade sperrt', () {
    final status = LockStatus.fromMap(
      stateMap(activeLock: {'profileId': 'p1', 'mode': 'OPEN', 'endsAt': null}),
    );

    expect(status.isProfileLocked('p1'), isTrue);
    expect(status.isProfileLocked('p2'), isFalse);
  });

  test('Einrichtung braucht Chip, Code und mindestens eine App', () {
    expect(LockStatus.fromMap(stateMap()).setupComplete, isTrue);
    expect(LockStatus.fromMap(stateMap(tags: [])).setupComplete, isFalse);
    expect(LockStatus.fromMap(stateMap(hasCode: false)).setupComplete, isFalse);
  });
}
