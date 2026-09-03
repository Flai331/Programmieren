import 'package:feedback/feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_riegel/lock_status.dart';
import 'package:nfc_riegel/riegel_channel.dart';

/// Das Protokoll geht in eine Notion-Datenbank. Was dort nicht landen darf,
/// steht in [RiegelChannel] — diese Prüfungen halten es fest.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/riegel');
  final kanal = const RiegelChannel(channel);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'generateCode':
              return 'ABCD-2345';
            case 'deleteTag':
            case 'updateProfile':
              return true;
            case 'startLock':
              return 'STARTED';
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  bool protokolliert(String teil) =>
      FeedbackService.logEntries.any((e) => e.contains(teil));

  test('geloeschter Chip steht ohne seine Kennung im Protokoll', () async {
    await kanal.deleteTag('04A1B2C3D4E5F6');

    expect(protokolliert('Chip gelöscht'), isTrue);
    expect(protokolliert('04A1B2C3D4E5F6'), isFalse);
  });

  test('erzeugter Code steht nie im Protokoll', () async {
    final code = await kanal.generateCode();

    expect(code, 'ABCD-2345');
    expect(protokolliert('Notfall-Code erzeugt'), isTrue);
    expect(protokolliert('ABCD-2345'), isFalse);
  });

  test('gespeichertes Profil steht mit Anzahl und Modus im Protokoll', () async {
    await kanal.updateProfile(
      const ProfileInfo(
        id: 'p1',
        name: 'Arbeit',
        blockedPackages: ['com.a', 'com.b'],
        mode: LockMode.timer,
        durationMinutes: 60,
        untilAt: null,
        pinCalendarEnd: false,
        pauseEnabled: true,
        pauseStepMinutes: 15,
        pauseBaseSeconds: 5,
        pauseResetMinutes: 15,
        quietEnabled: false,
        quietScope: QuietScope.alle,
        quietNumbers: [],
        quietAfterEventMinutes: 0,
        quietWhileLocked: true,
        quietSchedules: [],
      ),
    );

    expect(protokolliert('Profil gespeichert: Arbeit, 2 Apps'), isTrue);
    expect(protokolliert('Atempause an'), isTrue);
  });

  test('Sperrstart steht mit seinem Ausgang im Protokoll', () async {
    await kanal.startLock('p1');

    expect(protokolliert('Sperre ohne Chip gestartet: STARTED'), isTrue);
  });
}
