import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/lock_status.dart';

void main() {
  test('liest die Map aus dem Channel', () {
    final status = LockStatus.fromMap(const {
      'locked': true,
      'mode': 'TIMER',
      'endsAt': 1700000000000,
      'durationMinutes': 45,
      'blockedPackages': ['com.a', 'com.b'],
      'hasTag': true,
      'hasCode': false,
    });

    expect(status.locked, isTrue);
    expect(status.mode, LockMode.timer);
    expect(status.durationMinutes, 45);
    expect(status.blockedPackages, ['com.a', 'com.b']);
    expect(status.hasTag, isTrue);
    expect(status.hasCode, isFalse);
    expect(status.endsAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });

  test('endsAt null bleibt null', () {
    final status = LockStatus.fromMap(const {
      'locked': false,
      'mode': 'OPEN',
      'endsAt': null,
      'durationMinutes': 60,
      'blockedPackages': <String>[],
      'hasTag': false,
      'hasCode': false,
    });

    expect(status.endsAt, isNull);
    expect(status.mode, LockMode.open);
  });

  test('Einrichtung ist erst mit Chip und Code abgeschlossen', () {
    LockStatus build({required bool tag, required bool code, required List<String> pkgs}) =>
        LockStatus.fromMap({
          'locked': false,
          'mode': 'TIMER',
          'endsAt': null,
          'durationMinutes': 60,
          'blockedPackages': pkgs,
          'hasTag': tag,
          'hasCode': code,
        });

    expect(build(tag: true, code: true, pkgs: ['com.a']).setupComplete, isTrue);
    expect(build(tag: false, code: true, pkgs: ['com.a']).setupComplete, isFalse);
    expect(build(tag: true, code: false, pkgs: ['com.a']).setupComplete, isFalse);
    expect(build(tag: true, code: true, pkgs: []).setupComplete, isFalse);
  });
}
