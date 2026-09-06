#!/usr/bin/env python3
"""Selbsttest für einbauen.py — prüft die Verdrahtung von main.dart.

Aufruf:  python3 tools/test_einbauen.py

Der Anlass für diese Tests: Eine frühere Fassung suchte `MaterialApp(`
im rohen Quelltext und schrieb ihre Parameter prompt in einen Kommentar,
der das Wort nur erwähnte. Das Ergebnis war nicht übersetzbarer Dart-Code.
Seitdem läuft jede Suche über eine Maske ohne Kommentare und Zeichenketten.
"""

from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

HIER = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("einbauen", HIER / "einbauen.py")
einbauen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(einbauen)

fehlgeschlagen: list[str] = []


def verdrahte(quelltext: str) -> tuple[str, list[str]]:
    """Wendet die Verdrahtung auf einen main.dart-Text an.

    Gibt den neuen Text und die als offen gemeldeten Punkte zurück.
    """
    einbauen.schritte.clear()
    with tempfile.TemporaryDirectory() as ordner:
        app = Path(ordner)
        (app / "lib").mkdir()
        (app / "lib/main.dart").write_text(quelltext, encoding="utf-8")
        einbauen.main_verdrahten(app, "testapp", "Test App")
        neu = (app / "lib/main.dart").read_text(encoding="utf-8")
    offen = [t for zustand, t in einbauen.schritte if zustand == "offen"]
    return neu, offen


def pruefe(name: str, bedingung: bool, hinweis: str = "") -> None:
    if bedingung:
        print(f"  ok   {name}")
    else:
        fehlgeschlagen.append(name)
        print(f"  FEHL {name}" + (f"\n       {hinweis}" if hinweis else ""))


STANDARD = """import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo',
      home: const Scaffold(),
    );
  }
}
"""

MIT_KOMMENTAR = """import 'package:flutter/material.dart';

// Diese App baut ihre MaterialApp ( siehe unten ) selbst zusammen
// und ruft runApp( ... ) erst nach der Vorbereitung auf.
/* Auch hier steht MaterialApp( im Block-Kommentar. */
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const Scaffold());
  }
}
"""

MIT_BUILDER = """import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => child!,
      home: const Scaffold(),
    );
  }
}
"""

MIT_TEXT = """import 'package:flutter/material.dart';

const hinweis = 'Ruf runApp( auf und nutze MaterialApp( dafuer';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(home: const Scaffold());
}
"""


def main() -> int:
    print("\neinbauen.py — Selbsttest\n")

    # 1 ─ Standardfall
    neu, offen = verdrahte(STANDARD)
    pruefe("Standard: Import gesetzt", "import 'fehlerbericht.dart';" in neu)
    pruefe("Standard: runApp umgestellt",
           "Fehlerbericht.runApp(" in neu and "builder: () => const MyApp()," in neu)
    pruefe("Standard: alle drei MaterialApp-Parameter",
           all(t in neu for t in ("navigatorKey: Fehlerbericht.navigatorKey",
                                  "navigatorObservers: [Fehlerbericht.observer]",
                                  "builder: Fehlerbericht.wrap")))
    pruefe("Standard: nichts offen", not offen, "; ".join(offen))

    # 2 ─ Kommentare dürfen nicht angefasst werden
    neu, _ = verdrahte(MIT_KOMMENTAR)
    pruefe("Kommentar: Zeilenkommentar unverändert",
           "// Diese App baut ihre MaterialApp ( siehe unten ) selbst zusammen" in neu,
           "Parameter wurden in einen Kommentar geschrieben")
    pruefe("Kommentar: Block-Kommentar unverändert",
           "/* Auch hier steht MaterialApp( im Block-Kommentar. */" in neu)
    pruefe("Kommentar: echte MaterialApp trotzdem verdrahtet",
           "MaterialApp(\n      navigatorKey: Fehlerbericht.navigatorKey" in neu)
    pruefe("Kommentar: nur einmal eingefügt", neu.count("Fehlerbericht.navigatorKey") == 1)

    # 3 ─ Vorhandener builder wird gemeldet, nicht überschrieben
    neu, offen = verdrahte(MIT_BUILDER)
    pruefe("Eigener builder: bleibt erhalten", "builder: (context, child) => child!," in neu)
    pruefe("Eigener builder: kein zweiter builder eingefügt",
           neu.count("builder:") == 2,  # eigener + der in Fehlerbericht.runApp
           f"gefunden: {neu.count('builder:')}")
    pruefe("Eigener builder: wird als offen gemeldet",
           any("eigenen builder" in t for t in offen), "; ".join(offen))
    pruefe("Eigener builder: andere Parameter trotzdem gesetzt",
           "navigatorKey: Fehlerbericht.navigatorKey" in neu)

    # 4 ─ Zeichenketten sind kein Quellcode
    neu, _ = verdrahte(MIT_TEXT)
    pruefe("Zeichenkette: unverändert",
           "const hinweis = 'Ruf runApp( auf und nutze MaterialApp( dafuer';" in neu)
    pruefe("Zeichenkette: echtes runApp umgestellt", "Fehlerbericht.runApp(" in neu)

    # 5 ─ Wiederholter Aufruf ändert nichts mehr
    einmal, _ = verdrahte(STANDARD)
    zweimal, offen = verdrahte(einmal)
    pruefe("Wiederholung: bleibt unverändert", einmal == zweimal)
    pruefe("Wiederholung: nichts offen", not offen, "; ".join(offen))

    print()
    if fehlgeschlagen:
        print(f"FEHLGESCHLAGEN: {len(fehlgeschlagen)} — " + ", ".join(fehlgeschlagen))
        return 1
    print("Alle Prüfungen bestanden.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
