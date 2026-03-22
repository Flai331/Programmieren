// ═══════════════════════════════════════════════════════════════
//  STARTER MODELS
// ═══════════════════════════════════════════════════════════════

enum StarterDayActivity { morningCheck, feeding, eveningCheck, observation }

const kActivityLabels = {
  StarterDayActivity.morningCheck: 'Morgens kontrollieren',
  StarterDayActivity.feeding: 'Füttern (1:1:1 Verhältnis)',
  StarterDayActivity.eveningCheck: 'Abends kontrollieren',
  StarterDayActivity.observation: 'Beobachtungen notieren',
};

/// Tag-1-spezifische Labels: Ansatz vorbereiten statt Fütterungsroutine
const kDay1ActivityLabels = {
  StarterDayActivity.morningCheck: 'Ansatz vorbereiten (50g Mehl + 50g Wasser)',
  StarterDayActivity.feeding: 'Gut verrühren & in sauberes Glas füllen',
  StarterDayActivity.eveningCheck: 'Abends kurz nachschauen',
  StarterDayActivity.observation: 'Beobachtungen notieren',
};

Map<StarterDayActivity, String> kActivityLabelsForDay(int day) =>
    day == 1 ? kDay1ActivityLabels : kActivityLabels;

const kActivityEmojis = {
  StarterDayActivity.morningCheck: '🌅',
  StarterDayActivity.feeding: '🫙',
  StarterDayActivity.eveningCheck: '🌙',
  StarterDayActivity.observation: '🔍',
};

const kDayDescriptions = {
  1: '🌱 Heute legst du den Grundstein!\n\n'
      'Mische je 50g Mehl und 50g Wasser (Raumtemperatur) in einem sauberen Glas. '
      'Vollkornmehl oder Roggenmehl eignet sich besonders gut, da es mehr natürliche Hefen enthält.\n\n'
      'Rühre alles gut durch, decke das Glas locker ab (kein luftdichter Verschluss!) '
      'und stelle es an einen warmen Ort (22–26°C). '
      'Neben dem Herd, oben auf dem Kühlschrank oder im Backofen mit eingeschaltetem Licht sind gute Plätze.\n\n'
      '💡 Noch keine sichtbare Reaktion – das ist völlig normal. '
      'Die wilden Hefen und Bakterien aus dem Mehl brauchen etwas Zeit zum Aktivieren.',
  2: '🔍 Erste Fütterung – und erste Zeichen des Lebens!\n\n'
      'Verwirf die Hälfte deines Ansatzes (ca. 50g wegwerfen). '
      'Das klingt verschwenderisch, aber es hält die Menge handhabbar und verhindert, '
      'dass Säure sich zu stark aufbaut.\n\n'
      'Gib frische 50g Mehl und 50g Wasser hinzu, rühre gut um und decke wieder locker ab.\n\n'
      '💡 Du könntest jetzt erste winzige Bläschen sehen – das sind die ersten Lebenszeichen! '
      'Ein leicht säuerlicher oder hefiger Geruch ist ebenfalls ein gutes Zeichen. '
      'Keine Bläschen? Kein Problem, manchmal dauert es bis Tag 3–4.',
  3: '🫧 Die Aktivität nimmt zu!\n\n'
      'Wieder die Hälfte verwerfen, dann mit 50g Mehl und 50g Wasser füttern.\n\n'
      'Jetzt solltest du deutlichere Bläschen sehen und einen angenehm säuerlichen, '
      'leicht hefigen Geruch wahrnehmen. Das sind deine wilden Hefen und Milchsäurebakterien, '
      'die fleißig arbeiten!\n\n'
      '💡 Markiere den Füllstand nach dem Füttern mit einem Gummiband oder einem Strich '
      'auf dem Glas. So siehst du wie stark sich der Starter ausdehnt.',
  4: '📈 Der Starter erwacht!\n\n'
      'Hälfte verwerfen, mit 50g Mehl + 50g Wasser füttern.\n\n'
      'Dein Starter sollte jetzt merklich aktiver werden. '
      'Beobachte ihn in den Stunden nach dem Füttern – er sollte sich sichtbar ausdehnen '
      'und viele Bläschen im Inneren zeigen.\n\n'
      '💡 Der Geruch verändert sich: von hefig zu angenehm säuerlich bis leicht joghurtartig. '
      'Das ist genau richtig! Falls er nach Nagellack oder Aceton riecht, '
      'hat er Hunger – öfter füttern hilft.',
  5: '🥄 Float-Test – ist dein Starter bereit?\n\n'
      'Hälfte verwerfen, mit 50g Mehl + 50g Wasser füttern.\n\n'
      'Heute führst du zum ersten Mal den Float-Test durch: '
      'Gib 2–3 Stunden nach dem Füttern einen Teelöffel Starter in ein Glas Wasser.\n\n'
      '✅ Schwimmt er → Der Starter ist voller CO₂-Bläschen und gut aktiv. Fast backbereit!\n'
      '❌ Sinkt er → Noch nicht ganz – kein Problem, weiter füttern.\n\n'
      '💡 Führe den Test auf dem Höhepunkt der Aktivität durch – das ist meist 4–6 Stunden '
      'nach dem Füttern, wenn der Starter am größten ist.',
  6: '🚀 Auf der Zielgeraden!\n\n'
      'Hälfte verwerfen, mit 50g Mehl + 50g Wasser füttern.\n\n'
      'Ein aktiver Starter verdoppelt sich jetzt innerhalb von 4–8 Stunden nach dem Füttern. '
      'Führe den Float-Test erneut durch – wenn er besteht, ist dein Starter fast fertig!\n\n'
      '💡 Achte auf den idealen Erntezeitpunkt: Kurz vor oder auf dem Höhepunkt '
      '(wenn der Starter am größten ist, bevor er wieder zusammenfällt). '
      'Dann ist er am stärksten für dein erstes Brot.',
  7: '🎉 Letzter Tag der Grundphase!\n\n'
      'Hälfte verwerfen, mit 50g Mehl + 50g Wasser füttern.\n\n'
      'Führe nach 4–6 Stunden den Float-Test durch:\n\n'
      '✅ Schwimmt er → Herzlichen Glückwunsch! Dein Starter ist backbereit. '
      'Du kannst dein erstes Sauerteig-Brot backen!\n'
      '❌ Sinkt er noch → Kein Stress! Füge einfach einen weiteren Tag hinzu '
      'und fütter weiter. Manche Starter brauchen 10–14 Tage.\n\n'
      '💡 Ab jetzt: Im Kühlschrank aufbewahren und nur 1× pro Woche füttern. '
      'Vor dem Backen 4–8 Stunden vorher aus dem Kühlschrank nehmen und füttern.',
};

// Problem-Tipps
class StarterTip {
  final String emoji;
  final String title;
  final String symptom;
  final String solution;

  const StarterTip({
    required this.emoji,
    required this.title,
    required this.symptom,
    required this.solution,
  });
}

const kStarterTips = [
  StarterTip(
    emoji: '😴',
    title: 'Noch keine Bläschen – ist das normal?',
    symptom: 'Nach 2–3 Tagen siehst du noch gar nichts. Keine Bläschen, kein Geruch, nichts.',
    solution:
        'Völlig normal! Wilder Sauerteig braucht manchmal 3–5 Tage bis er anspringt. '
        'Stelle das Glas an einen wärmeren Ort (22–26°C, z.B. neben den Herd oder ins Backrohr mit eingeschaltetem Licht). '
        'Vollkornmehl hilft – es enthält mehr natürliche Hefen als weißes Mehl.',
  ),
  StarterTip(
    emoji: '🧴',
    title: 'Riecht seltsam – nach Nagellack oder Kleber',
    symptom: 'Der Starter riecht unangenehm stechend, scharf oder nach Alkohol.',
    solution:
        'Keine Panik – das ist ein Hungerzeichen! Dein Starter hat alles Futter verbraucht. '
        'Wirf die Hälfte weg und füttere ihn sofort mit frischem Mehl und Wasser. '
        'Füttere ab jetzt 2× täglich (morgens und abends). Der Geruch verschwindet nach 1–2 Fütterungen.',
  ),
  StarterTip(
    emoji: '🟢',
    title: 'Farbige Flecken – Schimmel?',
    symptom: 'Du siehst grüne, blaue, schwarze oder rosafarbene Flecken auf dem Starter.',
    solution:
        'Leider ja – das ist Schimmel. Dieser Starter muss komplett entsorgt werden. '
        'Bitte nicht versuchen den Schimmel wegzulöffeln – er hat unsichtbare Wurzeln. '
        'Für den nächsten Versuch: Glas vorher gründlich mit kochendem Wasser spülen, '
        'kein feuchtes Tuch als Abdeckung verwenden.',
  ),
  StarterTip(
    emoji: '🐢',
    title: 'Kaum Fortschritt nach 5+ Tagen',
    symptom: 'Dein Starter macht nach einer Woche immer noch kaum etwas.',
    solution:
        'Wärme ist das Wichtigste: Ideal sind 24–26°C. Ein kühles Zimmer (unter 20°C) macht den Starter sehr träge. '
        'Probiere Bio-Roggenmehl für ein paar Tage – es enthält besonders viele wilde Hefen. '
        'Gib dem Starter etwas mehr Geduld – manche brauchen 10–14 Tage.',
  ),
  StarterTip(
    emoji: '💧',
    title: 'Flüssigkeit oben drauf – was ist das?',
    symptom: 'Eine graue oder braune Flüssigkeit hat sich oben auf dem Starter abgesetzt.',
    solution:
        'Das nennt man "Hooch" – eine alkoholhaltige Flüssigkeit, die entsteht wenn der Starter Hunger hat. '
        'Sie ist harmlos! Einfach abgießen oder einrühren. '
        'Danach sofort füttern und ab jetzt öfter (2× täglich) füttern.',
  ),
  StarterTip(
    emoji: '📉',
    title: 'Starter aufgegangen und wieder zusammengefallen',
    symptom: 'Du hast gesehen wie er schön aufgeht – aber jetzt ist er wieder flach.',
    solution:
        'Das ist eigentlich ein gutes Zeichen! Dein Starter ist aktiv. '
        'Wenn er zusammenfällt, hat er seinen Höhepunkt überschritten und ist wieder "hungrig". '
        'Zum Backen ist er am besten auf dem Höhepunkt (wenn er gerade am größten ist). '
        'Für die Zukunft: Füttere ihn, wenn er zu etwa zwei Dritteln aufgegangen ist.',
  ),
];

// ── Datenklassen ────────────────────────────────────────────────

class StarterDayLog {
  final int dayNumber;
  final DateTime date;
  final Map<StarterDayActivity, bool> checks;
  final String notes;
  final double? temperature;
  final bool floatTestDone;
  final bool floatTestPassed;

  StarterDayLog({
    required this.dayNumber,
    required this.date,
    Map<StarterDayActivity, bool>? checks,
    this.notes = '',
    this.temperature,
    this.floatTestDone = false,
    this.floatTestPassed = false,
  }) : checks = checks ??
            {for (var a in StarterDayActivity.values) a: false};

  bool get isComplete =>
      checks.values.every((v) => v);

  StarterDayLog copyWith({
    Map<StarterDayActivity, bool>? checks,
    String? notes,
    double? temperature,
    bool? floatTestDone,
    bool? floatTestPassed,
  }) {
    return StarterDayLog(
      dayNumber: dayNumber,
      date: date,
      checks: checks ?? Map.from(this.checks),
      notes: notes ?? this.notes,
      temperature: temperature ?? this.temperature,
      floatTestDone: floatTestDone ?? this.floatTestDone,
      floatTestPassed: floatTestPassed ?? this.floatTestPassed,
    );
  }

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'date': date.toIso8601String(),
        'checks':
            checks.map((k, v) => MapEntry(k.name, v)),
        'notes': notes,
        'temperature': temperature,
        'floatTestDone': floatTestDone,
        'floatTestPassed': floatTestPassed,
      };

  factory StarterDayLog.fromJson(Map<String, dynamic> j) {
    final rawChecks = (j['checks'] as Map<String, dynamic>?) ?? {};
    final checks = <StarterDayActivity, bool>{};
    for (final a in StarterDayActivity.values) {
      checks[a] = rawChecks[a.name] as bool? ?? false;
    }
    return StarterDayLog(
      dayNumber: j['dayNumber'] as int,
      date: DateTime.parse(j['date'] as String),
      checks: checks,
      notes: j['notes'] as String? ?? '',
      temperature: (j['temperature'] as num?)?.toDouble(),
      floatTestDone: j['floatTestDone'] as bool? ?? false,
      floatTestPassed: j['floatTestPassed'] as bool? ?? false,
    );
  }
}

class StarterJourney {
  final String id;
  final String starterName;
  final DateTime startedAt;
  final List<StarterDayLog> days;
  final bool isCompleted;
  final DateTime? completedAt;

  StarterJourney({
    required this.id,
    required this.starterName,
    required this.startedAt,
    required this.days,
    this.isCompleted = false,
    this.completedAt,
  });

  int get currentDayNumber {
    final diff = DateTime.now().difference(startedAt).inDays + 1;
    return diff.clamp(1, days.length);
  }

  StarterDayLog? get todayLog {
    final dayNum = currentDayNumber;
    try {
      return days.firstWhere((d) => d.dayNumber == dayNum);
    } catch (_) {
      return null;
    }
  }

  StarterJourney addExtensionDay() {
    final nextNum = days.length + 1;
    final nextDate = startedAt.add(Duration(days: nextNum - 1));
    final newDay = StarterDayLog(dayNumber: nextNum, date: nextDate);
    return copyWith(days: [...days, newDay]);
  }

  StarterJourney copyWith({
    List<StarterDayLog>? days,
    bool? isCompleted,
    DateTime? completedAt,
    String? starterName,
  }) {
    return StarterJourney(
      id: id,
      starterName: starterName ?? this.starterName,
      startedAt: startedAt,
      days: days ?? this.days,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'starterName': starterName,
        'startedAt': startedAt.toIso8601String(),
        'days': days.map((d) => d.toJson()).toList(),
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory StarterJourney.fromJson(Map<String, dynamic> j) {
    return StarterJourney(
      id: j['id'] as String,
      starterName: j['starterName'] as String? ?? 'Mein Sauerteig',
      startedAt: DateTime.parse(j['startedAt'] as String),
      days: (j['days'] as List<dynamic>)
          .map((d) => StarterDayLog.fromJson(d as Map<String, dynamic>))
          .toList(),
      isCompleted: j['isCompleted'] as bool? ?? false,
      completedAt: j['completedAt'] != null
          ? DateTime.parse(j['completedAt'] as String)
          : null,
    );
  }

  /// Erstellt einen neuen Journey mit 7 Tagen
  factory StarterJourney.create(String name) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return StarterJourney(
      id: now.millisecondsSinceEpoch.toString(),
      starterName: name.isEmpty ? 'Mein Sauerteig' : name,
      startedAt: today,
      days: List.generate(
        7,
        (i) => StarterDayLog(
          dayNumber: i + 1,
          date: today.add(Duration(days: i)),
        ),
      ),
    );
  }
}
