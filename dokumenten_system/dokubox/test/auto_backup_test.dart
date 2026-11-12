import 'dart:io';

import 'package:dokubox/backup/auto_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('ab');
  });
  tearDown(() => tmp.delete(recursive: true));

  test('schreibt in erreichbare Ziele, holt fehlende nach, rotiert', () async {
    final laptop = p.join(tmp.path, 'laptop');
    final usb = p.join(tmp.path, 'usb', 'DokuBox'); // Laufwerk "usb" fehlt erst
    await Directory(laptop).create();
    await AutoBackup.save(AutoBackupConfig(
        enabled: true, password: 'pw', targets: [laptop, usb]));
    var t = DateTime(2026, 1, 1, 10);
    var made = 0;
    final ab = AutoBackup((pw) async {
      made++;
      final f = File(p.join(tmp.path, 'src$made.dokubak'));
      await f.writeAsString('x$pw');
      return f;
    }, now: () => t);

    // Ohne Laufwerksbuchstaben gilt "/": Ordner lässt sich anlegen. Für den
    // Test simulieren wir ein fehlendes Laufwerk über eine Datei im Weg.
    await File(p.join(tmp.path, 'usb')).writeAsString('kein Ordner');
    var r = await ab.runIfDue();
    expect(r.written, [laptop]);
    expect(r.missing, [usb]);

    // Gleicher Tag: nichts fällig fürs Laptop, USB fehlt weiter.
    r = await ab.runIfDue();
    expect(r.written, isEmpty);
    expect(made, 1);

    // Stick da → nachgeholt, Laptop noch nicht wieder fällig.
    await File(p.join(tmp.path, 'usb')).delete();
    t = t.add(const Duration(hours: 2));
    r = await ab.runIfDue();
    expect(r.written, [usb]);

    for (var i = 0; i < 7; i++) {
      t = t.add(const Duration(days: 1));
      await ab.runIfDue();
    }
    final files = Directory(laptop).listSync().whereType<File>().toList();
    expect(files.length, 5);
    expect(files.every((f) => f.path.endsWith('.dokubak')), isTrue);
    expect(Directory(tmp.path).listSync().where((e) => e.path.contains('src')), isEmpty);
    expect(await AutoBackup.reminder(at: t), isNull);
    expect(await AutoBackup.reminder(at: t.add(const Duration(days: 20))), isNotNull);
  });
}
