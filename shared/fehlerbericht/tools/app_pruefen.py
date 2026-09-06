#!/usr/bin/env python3
"""Prüft, ob eine Flutter-App korrekt an die Fehlerzentrale angeschlossen ist.

Fängt genau die Fehler ab, die man sonst erst merkt, wenn eine fertige
Release-APK schweigend auf den E-Mail-Fallback ausweicht:

  * fehlerbericht.dart fehlt oder ist eine veraltete Kopie
  * INTERNET-Berechtigung fehlt im main-Manifest (Debug läuft, Release nicht)
  * http / url_launcher fehlen in der pubspec.yaml
  * main.dart ist nicht verdrahtet (runApp / navigatorKey / observer / wrap)
  * NOTION_TOKEN ist beim Bauen nicht gesetzt

Aufruf aus dem Ordner shared/fehlerbericht:

    python3 tools/app_pruefen.py ../../sauerteig_planer

Rückgabewert 0 = alles in Ordnung, 1 = mindestens ein Problem.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

MODUL = Path(__file__).resolve().parent.parent / "lib" / "fehlerbericht.dart"

befunde: list[tuple[str, str, str]] = []  # (schwere, titel, hinweis)


def ok(titel: str) -> None:
    befunde.append(("ok", titel, ""))


def fehler(titel: str, hinweis: str) -> None:
    befunde.append(("fehler", titel, hinweis))


def warnung(titel: str, hinweis: str) -> None:
    befunde.append(("warnung", titel, hinweis))


def pruefe_modul(app: Path) -> None:
    kopien = list(app.glob("lib/**/fehlerbericht.dart"))
    if not kopien:
        fehler(
            "fehlerbericht.dart fehlt",
            f"Datei aus {MODUL} nach {app / 'lib'} kopieren.",
        )
        return
    if len(kopien) > 1:
        warnung(
            "Mehrere Kopien von fehlerbericht.dart",
            "Nur eine behalten: " + ", ".join(str(k.relative_to(app)) for k in kopien),
        )
    kopie = kopien[0]
    if not MODUL.exists():
        warnung("Modul-Original nicht gefunden", f"Erwartet unter {MODUL}.")
        return
    if kopie.read_text(encoding="utf-8") == MODUL.read_text(encoding="utf-8"):
        ok(f"fehlerbericht.dart aktuell ({kopie.relative_to(app)})")
    else:
        fehler(
            "fehlerbericht.dart weicht vom Original ab",
            f"Neu kopieren: {MODUL} -> {kopie}",
        )


def pruefe_manifest(app: Path) -> None:
    haupt = app / "android/app/src/main/AndroidManifest.xml"
    if not haupt.exists():
        warnung(
            "Kein Android-Manifest gefunden",
            f"Erwartet unter {haupt.relative_to(app)} — bei reinen Web-/Desktop-Apps in Ordnung.",
        )
        return
    text = haupt.read_text(encoding="utf-8")
    if "android.permission.INTERNET" in text:
        ok("INTERNET-Berechtigung im main-Manifest")
        return

    nur_debug = [
        p.parent.name  # Variantenname (debug, profile), nicht der Dateiname
        for p in (app / "android/app/src").glob("*/AndroidManifest.xml")
        if p.parent.name != "main"
        and "android.permission.INTERNET" in p.read_text(encoding="utf-8")
    ]
    zusatz = (
        " Sie steht nur in den Varianten: "
        + ", ".join(sorted(p for p in nur_debug))
        + " — dadurch funktioniert der Debug-Build und der Release-Build nicht."
        if nur_debug
        else ""
    )
    fehler(
        "INTERNET-Berechtigung fehlt im main-Manifest",
        'In android/app/src/main/AndroidManifest.xml direkt unter <manifest ...> einfügen: '
        '<uses-permission android:name="android.permission.INTERNET"/>.' + zusatz,
    )


def pruefe_pubspec(app: Path) -> None:
    pubspec = app / "pubspec.yaml"
    if not pubspec.exists():
        fehler("pubspec.yaml fehlt", f"{app} ist kein Flutter-Projekt.")
        return
    text = pubspec.read_text(encoding="utf-8")
    fehlend = [p for p in ("http", "url_launcher") if not re.search(rf"^\s+{p}:", text, re.M)]
    if fehlend:
        fehler(
            "Abhängigkeiten fehlen: " + ", ".join(fehlend),
            "In pubspec.yaml unter dependencies ergänzen, dann flutter pub get.",
        )
    else:
        ok("http und url_launcher vorhanden")


def pruefe_verdrahtung(app: Path) -> None:
    main = app / "lib/main.dart"
    if not main.exists():
        fehler("lib/main.dart fehlt", f"{app} ist kein Flutter-Projekt.")
        return
    text = main.read_text(encoding="utf-8")

    if "Fehlerbericht.runApp" in text:
        ok("main() nutzt Fehlerbericht.runApp")
        treffer = re.search(r"appKey:\s*'([^']+)'", text)
        if treffer:
            schluessel = treffer.group(1)
            if schluessel != schluessel.lower() or " " in schluessel:
                warnung(
                    f"appKey '{schluessel}' ist ungewöhnlich",
                    "Klein geschrieben und ohne Leerzeichen halten — er ist der "
                    "Schlüssel in der Notion-Registry und darf sich nie ändern.",
                )
            else:
                ok(f"appKey: {schluessel}")
        else:
            warnung("appKey nicht gefunden", "In Fehlerbericht.runApp(appKey: '...') setzen.")
    else:
        fehler(
            "main() ruft Fehlerbericht.runApp nicht auf",
            "runApp(...) durch Fehlerbericht.runApp(appKey: ..., appName: ..., "
            "builder: () => const MyApp()) ersetzen.",
        )

    for teil, wo in (
        ("Fehlerbericht.navigatorKey", "navigatorKey:"),
        ("Fehlerbericht.observer", "navigatorObservers:"),
        ("Fehlerbericht.wrap", "builder:"),
    ):
        if teil in text:
            ok(f"MaterialApp: {teil} gesetzt")
        else:
            fehler(
                f"MaterialApp: {teil} fehlt",
                f"In der MaterialApp ergänzen: {wo} {teil}"
                + (" — ohne wrap gibt es keinen Fehler-Button und keinen Screenshot."
                   if teil.endswith("wrap") else ""),
            )


def pruefe_token() -> None:
    token = os.environ.get("NOTION_TOKEN", "").strip()
    if not token:
        warnung(
            "NOTION_TOKEN ist gerade nicht gesetzt",
            "Nur beim Bauen nötig: flutter build apk --dart-define=NOTION_TOKEN=... "
            "Ohne Token laufen Berichte über den E-Mail-Fallback.",
        )
    elif not token.isascii() or not token.startswith(("ntn_", "secret_")):
        fehler(
            "NOTION_TOKEN sieht nicht nach einem Notion-Token aus",
            "Erwartet wird ein Wert, der mit ntn_ beginnt (notion.so/my-integrations).",
        )
    else:
        ok("NOTION_TOKEN gesetzt")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    app = Path(sys.argv[1]).resolve()
    if not app.is_dir():
        print(f"Ordner nicht gefunden: {app}")
        return 2

    print(f"\nFehlerzentrale — App-Prüfung: {app.name}\n")
    pruefe_modul(app)
    pruefe_pubspec(app)
    pruefe_verdrahtung(app)
    pruefe_manifest(app)
    pruefe_token()

    zeichen = {"ok": "✓", "warnung": "!", "fehler": "✗"}
    for schwere, titel, hinweis in befunde:
        print(f"  {zeichen[schwere]} {titel}")
        if hinweis:
            print(f"      {hinweis}")

    fehlerzahl = sum(1 for s, _, _ in befunde if s == "fehler")
    warnzahl = sum(1 for s, _, _ in befunde if s == "warnung")
    print()
    if fehlerzahl:
        print(f"✗ {fehlerzahl} Problem(e), {warnzahl} Hinweis(e) — bitte vor dem Bauen beheben.")
        return 1
    print(f"✓ Alles in Ordnung ({warnzahl} Hinweis(e)).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
