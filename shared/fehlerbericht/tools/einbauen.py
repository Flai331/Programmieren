#!/usr/bin/env python3
"""Baut das Fehlermelde-Modul vollautomatisch in eine Flutter-App ein.

Erledigt alle mechanischen Schritte:

  1. lib/fehlerbericht.dart hineinkopieren (bzw. aktualisieren)
  2. http und url_launcher in die pubspec.yaml eintragen
  3. INTERNET-Berechtigung ins main-Manifest setzen (Android)
  4. lib/main.dart verdrahten: Import, Fehlerbericht.runApp,
     navigatorKey / navigatorObservers / builder an der MaterialApp

Aufruf:

    python3 tools/einbauen.py <app-ordner>
    python3 tools/einbauen.py <app-ordner> --key meine_app --name "Meine App"

Ohne --key/--name werden beide aus dem Paketnamen der pubspec.yaml
abgeleitet. Der Aufruf ist gefahrlos wiederholbar: was schon sitzt, wird
nicht erneut eingefügt. Vor jeder Änderung an main.dart und pubspec.yaml
wird eine .bak-Kopie angelegt.

Danach prüfen mit:  python3 tools/app_pruefen.py <app-ordner>
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

MODUL = Path(__file__).resolve().parent.parent / "lib" / "fehlerbericht.dart"

schritte: list[tuple[str, str]] = []  # (zustand, text)


def getan(text: str) -> None:
    schritte.append(("getan", text))


def schon_da(text: str) -> None:
    schritte.append(("schon", text))


def offen(text: str) -> None:
    schritte.append(("offen", text))


def sichern(pfad: Path) -> None:
    kopie = pfad.with_suffix(pfad.suffix + ".bak")
    if not kopie.exists():
        shutil.copy2(pfad, kopie)


# ── 1. Moduldatei ──────────────────────────────────────────────────────


def modul_kopieren(app: Path) -> None:
    ziel = app / "lib" / "fehlerbericht.dart"
    quelle = MODUL.read_text(encoding="utf-8")
    if ziel.exists() and ziel.read_text(encoding="utf-8") == quelle:
        schon_da("lib/fehlerbericht.dart ist aktuell")
        return
    ziel.parent.mkdir(parents=True, exist_ok=True)
    war_da = ziel.exists()
    ziel.write_text(quelle, encoding="utf-8", newline="\n")
    getan(f"lib/fehlerbericht.dart {'aktualisiert' if war_da else 'angelegt'}")


# ── 2. Abhängigkeiten ──────────────────────────────────────────────────

PAKETE = {"http": "^1.2.0", "url_launcher": "^6.2.5"}


def pubspec_ergaenzen(app: Path) -> str:
    pubspec = app / "pubspec.yaml"
    text = pubspec.read_text(encoding="utf-8")

    paketname = ""
    treffer = re.search(r"^name:\s*(\S+)", text, re.M)
    if treffer:
        paketname = treffer.group(1)

    fehlend = {p: v for p, v in PAKETE.items() if not re.search(rf"^  {p}:", text, re.M)}
    if not fehlend:
        schon_da("http und url_launcher stehen in der pubspec.yaml")
        return paketname

    # Direkt hinter dem flutter-sdk-Eintrag einfügen, damit die Einrückung
    # sicher stimmt; sonst ans Ende des dependencies-Blocks.
    anker = re.search(r"^dependencies:\n(?:.*\n)*?  flutter:\n    sdk: flutter\n", text, re.M)
    einschub = "".join(f"  {p}: {v}\n" for p, v in fehlend.items())
    einschub = "  # Fehlerberichte (siehe lib/fehlerbericht.dart)\n" + einschub
    if anker:
        stelle = anker.end()
    else:
        anker2 = re.search(r"^dependencies:\n", text, re.M)
        if not anker2:
            offen("Kein dependencies-Block in der pubspec.yaml gefunden — "
                  f"bitte von Hand ergänzen: {', '.join(fehlend)}")
            return paketname
        stelle = anker2.end()
    sichern(pubspec)
    pubspec.write_text(text[:stelle] + einschub + text[stelle:], encoding="utf-8")
    getan("pubspec.yaml ergänzt: " + ", ".join(fehlend))
    return paketname


# ── 3. Android-Manifest ────────────────────────────────────────────────

BERECHTIGUNG = '    <uses-permission android:name="android.permission.INTERNET"/>\n'


def manifest_ergaenzen(app: Path) -> None:
    haupt = app / "android/app/src/main/AndroidManifest.xml"
    if not haupt.exists():
        schon_da("Kein Android-Projekt vorhanden — Manifest übersprungen")
        return
    text = haupt.read_text(encoding="utf-8")
    if "android.permission.INTERNET" in text:
        schon_da("INTERNET-Berechtigung steht im main-Manifest")
        return
    treffer = re.search(r"<manifest\b[^>]*>\n", text)
    if not treffer:
        offen("Manifest hat kein <manifest>-Element — bitte von Hand ergänzen: "
              + BERECHTIGUNG.strip())
        return
    sichern(haupt)
    kommentar = (
        "    <!-- Netzwerkzugriff für Fehlerberichte. Muss hier stehen und\n"
        "         nicht nur in src/debug/, sonst schlagen alle Aufrufe im\n"
        "         Release-Build fehl. -->\n"
    )
    stelle = treffer.end()
    haupt.write_text(text[:stelle] + kommentar + BERECHTIGUNG + text[stelle:], encoding="utf-8")
    getan("INTERNET-Berechtigung ins main-Manifest eingefügt")


# ── 4. main.dart verdrahten ────────────────────────────────────────────


def maskieren(text: str, zeichenketten: bool = True) -> str:
    """Kopie gleicher Länge, in der Kommentare und Zeichenketten durch
    Leerzeichen ersetzt sind.

    Alle Suchen laufen über diese Maske, alle Einfügungen über das
    Original — weil beide gleich lang sind, stimmen die Indizes überein.
    Ohne das trifft eine Suche nach `MaterialApp(` auch einen Kommentar,
    der das Wort nur erwähnt, und das Ergebnis ist zerstörter Quellcode.
    """
    aus = list(text)
    i, n = 0, len(text)
    dreifach_zeichen = ("'''", '"""')
    while i < n:
        z = text[i]
        if z == "/" and text[i + 1 : i + 2] == "/":
            while i < n and text[i] != "\n":
                aus[i] = " "
                i += 1
        elif z == "/" and text[i + 1 : i + 2] == "*":
            while i < n and text[i : i + 2] != "*/":
                if text[i] != "\n":
                    aus[i] = " "
                i += 1
            for k in range(i, min(i + 2, n)):
                aus[k] = " "
            i += 2
        elif z in "'\"" and zeichenketten:
            ende = text[i : i + 3] if text[i : i + 3] in dreifach_zeichen else z
            for k in range(i, i + len(ende)):
                aus[k] = " "
            i += len(ende)
            while i < n:
                if text[i] == "\\":
                    for k in range(i, min(i + 2, n)):
                        if text[k] != "\n":
                            aus[k] = " "
                    i += 2
                    continue
                if text[i : i + len(ende)] == ende:
                    for k in range(i, i + len(ende)):
                        aus[k] = " "
                    i += len(ende)
                    break
                if text[i] != "\n":
                    aus[i] = " "
                i += 1
        else:
            i += 1
    return "".join(aus)


def klammer_ende(text: str, auf: int) -> int:
    """Index der schließenden Klammer zu der bei `auf` geöffneten.

    Erwartet maskierten Text — Klammern in Kommentaren und Zeichenketten
    sind dort bereits entfernt.
    """
    tiefe = 0
    for i in range(auf, len(text)):
        if text[i] == "(":
            tiefe += 1
        elif text[i] == ")":
            tiefe -= 1
            if tiefe == 0:
                return i
    return -1


def main_verdrahten(app: Path, app_key: str, app_name: str) -> None:
    main = app / "lib/main.dart"
    if not main.exists():
        offen("lib/main.dart nicht gefunden — Verdrahtung übersprungen")
        return
    text = main.read_text(encoding="utf-8")
    original = text

    # Gesucht wird stets in der Maske, eingefügt im Original.
    maske = maskieren(text)

    # -- Import --
    # Hier wird nur der Kommentar ausgeblendet, nicht die Zeichenketten:
    # der Import-Pfad steht selbst in Anführungszeichen und wäre sonst
    # bei jedem Lauf erneut "fehlend".
    ohne_kommentare = maskieren(text, zeichenketten=False)
    if "fehlerbericht.dart" not in ohne_kommentare:
        importe = list(re.finditer(r"^import .*;\n", ohne_kommentare, re.M))
        if importe:
            stelle = importe[-1].end()
            text = text[:stelle] + "import 'fehlerbericht.dart';\n" + text[stelle:]
        else:
            text = "import 'fehlerbericht.dart';\n\n" + text
        maske = maskieren(text)

    # -- runApp -> Fehlerbericht.runApp --
    if "Fehlerbericht.runApp" not in maske:
        treffer = re.search(r"(?<![\w.])runApp\s*\(", maske)
        if not treffer:
            offen("Kein runApp(...) in main.dart gefunden — bitte von Hand auf "
                  "Fehlerbericht.runApp(...) umstellen")
        else:
            auf = treffer.end() - 1
            zu = klammer_ende(maske, auf)
            if zu < 0:
                offen("runApp(...) nicht auswertbar — bitte von Hand umstellen")
            else:
                inhalt = text[auf + 1 : zu].strip().rstrip(",").strip()
                ersatz = (
                    "Fehlerbericht.runApp(\n"
                    f"    appKey: '{app_key}',\n"
                    f"    appName: '{app_name}',\n"
                    f"    builder: () => {inhalt},\n"
                    "  )"
                )
                text = text[: treffer.start()] + ersatz + text[zu + 1 :]
                maske = maskieren(text)

    # -- MaterialApp-Parameter --
    fehlend = [
        (schl, wert)
        for schl, wert in (
            ("navigatorKey", "Fehlerbericht.navigatorKey"),
            ("navigatorObservers", "[Fehlerbericht.observer]"),
            ("builder", "Fehlerbericht.wrap"),
        )
        if wert not in maske
    ]
    if fehlend:
        stellen = list(re.finditer(r"(?<![\w.])(?:Material|Cupertino)App\s*\(", maske))
        if not stellen:
            offen("Keine MaterialApp gefunden — bitte navigatorKey, "
                  "navigatorObservers und builder von Hand ergänzen")
        else:
            if len(stellen) > 1:
                offen(f"{len(stellen)} MaterialApp-Stellen gefunden — nur die erste "
                      "wurde verdrahtet, bitte die übrigen prüfen")
            auf = stellen[0].end()
            zu = klammer_ende(maske, auf - 1)
            rumpf = maske[auf:zu] if zu > auf else maske[auf:]

            einschub = ""
            for schl, wert in fehlend:
                if re.search(rf"[\s(]{schl}\s*:", rumpf):
                    # Der Parameter ist schon belegt — überschreiben wäre
                    # Datenverlust, ein zweiter Eintrag wäre ein Syntaxfehler.
                    if schl == "builder":
                        offen(
                            "Die MaterialApp hat bereits einen eigenen builder. "
                            "Fehlerbericht.wrap muss ihn umschließen, damit "
                            "Button und Screenshot funktionieren:  "
                            "builder: (context, child) => Fehlerbericht.wrap("
                            "context, <dein bisheriger Ausdruck>)"
                        )
                    else:
                        offen(f"Die MaterialApp hat bereits ein eigenes {schl} — "
                              f"bitte von Hand auf {wert} umstellen oder zusammenführen")
                    continue
                einschub += f"\n      {schl}: {wert},"
            if einschub:
                text = text[:auf] + einschub + text[auf:]

    if text == original:
        schon_da("main.dart ist bereits verdrahtet")
        return
    sichern(main)
    main.write_text(text, encoding="utf-8")
    getan("main.dart verdrahtet (Import, runApp, MaterialApp)")


# ── Ablauf ─────────────────────────────────────────────────────────────


def main() -> int:
    ap = argparse.ArgumentParser(add_help=True, description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("app", help="Ordner der Flutter-App")
    ap.add_argument("--key", help="App-Key für Notion (klein, ohne Leerzeichen)")
    ap.add_argument("--name", help="Anzeigename in Notion")
    args = ap.parse_args()

    app = Path(args.app).resolve()
    if not (app / "pubspec.yaml").exists():
        print(f"Kein Flutter-Projekt: {app}")
        return 2
    if not MODUL.exists():
        print(f"Moduldatei nicht gefunden: {MODUL}")
        return 2

    print(f"\nFehlerzentrale — Einbau in {app.name}\n")

    modul_kopieren(app)
    paketname = pubspec_ergaenzen(app)

    app_key = args.key or re.sub(r"[^a-z0-9_]", "", (paketname or app.name).lower())
    app_name = args.name or (paketname or app.name).replace("_", " ").title()

    main_verdrahten(app, app_key, app_name)
    manifest_ergaenzen(app)

    zeichen = {"getan": "+", "schon": "=", "offen": "!"}
    for zustand, text in schritte:
        print(f"  {zeichen[zustand]} {text}")

    offene = [t for z, t in schritte if z == "offen"]
    print()
    print(f"  App-Key:  {app_key}")
    print(f"  App-Name: {app_name}")
    print()
    if offene:
        print(f"! {len(offene)} Schritt(e) brauchen Handarbeit (siehe oben).")
    print("Nächste Schritte:")
    print("  flutter pub get")
    print(f"  python3 {Path(__file__).parent / 'app_pruefen.py'} {args.app}")
    print("  flutter build apk --release --dart-define=NOTION_TOKEN=…")
    return 1 if offene else 0


if __name__ == "__main__":
    sys.exit(main())
