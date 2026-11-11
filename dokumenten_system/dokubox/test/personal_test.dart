import 'package:dokubox/data/database.dart';
import 'package:dokubox/data/document_repository.dart';
import 'package:dokubox/data/personal.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Meine Daten: Personen, Werte, Kombis, Maske, eigene IBAN', () async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final repo = DocumentRepository(db);
    await repo.setPersonalValue('Ich', 'vorname', 'Max');
    await repo.setPersonalValue('Ich', 'nachname', 'Müller');
    await repo.setPersonalValue('Ich', 'strasse', 'Hauptstr. 1');
    await repo.setPersonalValue('Ich', 'plz_ort', '04109 Leipzig');
    await repo.setPersonalValue('Ich', 'iban', 'DE02 1203 0000 0000 2020 51');
    await repo.setPersonalValue('Ich', 'vorname', 'Maximilian');
    await repo.addPerson('Anna');
    expect(await repo.watchPersons().first, ['Ich', 'Anna']);
    final v = await repo.personalValues('Ich');
    expect(v['vorname'], 'Maximilian');
    final combos = personalCombos(v);
    expect(combos.first.text, 'Maximilian Müller');
    expect(combos[1].text, 'Maximilian Müller\nHauptstr. 1\n04109 Leipzig');
    expect(maskValue('iban', v['iban']!), '•••• 2051');
    expect(await repo.ownIbans(), {'DE02120300000000202051'});
    await repo.renamePerson('Anna', 'Anna M.');
    await repo.deletePerson('Ich');
    expect(await repo.watchPersons().first, ['Anna M.']);
    await db.close();
  });
}
