#!/usr/bin/env python3
"""Selbsttest für die Fehlerzentrale.

Prüft mit dem echten Notion-Token genau die HTTP-Aufrufe, die auch
`fehlerbericht.dart` macht — in derselben Reihenfolge:

  1. Token gültig?                          GET  /v1/users/me
  2. Registry erreichbar?                   POST /v1/databases/<registry>/query
  3. App unbekannt -> Seite anlegen         POST /v1/pages
  4. ... und Berichts-Datenbank anlegen     POST /v1/databases
  5. Registry-Zeile anlegen                 POST /v1/pages
  6. Bericht anlegen (Properties + Body)    POST /v1/pages
  7. Screenshot hochladen und anhängen      POST /v1/file_uploads (+ /send, PATCH /blocks)
  8. Registry-Zeile aktualisieren           PATCH /v1/pages/<id>

Aufruf:
    NOTION_TOKEN=ntn_… python3 notion_selbsttest.py            # Testlauf, räumt hinterher auf
    NOTION_TOKEN=ntn_… python3 notion_selbsttest.py --behalten # Test-App in Notion stehen lassen

Der Test legt eine Wegwerf-App `selbsttest` an und archiviert sie am Ende
wieder, sofern nicht --behalten gesetzt ist. Bestehende Apps und Berichte
werden nicht angefasst.
"""

import base64
import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone

API = "https://api.notion.com/v1"
VERSION = "2022-06-28"

WURZEL_SEITE_ID = "3d185584-dd12-81bb-9516-e34e03839fbc"  # 🐞 Fehlerzentrale
REGISTRY_DB_ID = "0f07715e-7f9b-4804-adb5-3d0f704febae"   # 📊 Apps

APP_KEY = "selbsttest"
APP_NAME = "Selbsttest (automatisch)"

# 1x1-PNG, damit der Upload-Pfad ohne externe Datei geprüft werden kann.
MINI_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)

TOKEN = os.environ.get("NOTION_TOKEN", "").strip()

schritte: list[tuple[str, bool, str]] = []


def melde(name: str, ok: bool, info: str = "") -> None:
    schritte.append((name, ok, info))
    zeichen = "✓" if ok else "✗"
    print(f"  {zeichen} {name}" + (f" — {info}" if info else ""), flush=True)


def anfrage(methode: str, pfad: str, body=None, roh=None, content_type=None):
    url = pfad if pfad.startswith("http") else f"{API}{pfad}"
    kopf = {"Authorization": f"Bearer {TOKEN}", "Notion-Version": VERSION}
    daten = None
    if roh is not None:
        daten = roh
        if content_type:
            kopf["Content-Type"] = content_type
    elif body is not None:
        daten = json.dumps(body).encode()
        kopf["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=daten, headers=kopf, method=methode)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        text = e.read().decode()
        try:
            return e.code, json.loads(text)
        except json.JSONDecodeError:
            return e.code, {"message": text[:300]}
    except Exception as e:  # Netzwerk, DNS, TLS
        return 0, {"message": str(e)}


def text_bloecke(inhalt: str, grenze: int = 1900):
    """Lange Texte auf mehrere rich_text-Objekte verteilen (Notion-Limit 2000)."""
    return [
        {"type": "text", "text": {"content": inhalt[i : i + grenze]}}
        for i in range(0, max(len(inhalt), 1), grenze)
    ] or [{"type": "text", "text": {"content": ""}}]


def main() -> int:
    behalten = "--behalten" in sys.argv
    if not TOKEN:
        print("NOTION_TOKEN ist nicht gesetzt.\n")
        print("  NOTION_TOKEN=ntn_… python3 notion_selbsttest.py")
        return 2

    print("\nFehlerzentrale — Selbsttest\n")

    # 1 ─ Token
    code, daten = anfrage("GET", "/users/me")
    if code != 200:
        melde("Token gültig", False, f"HTTP {code}: {daten.get('message', '')}")
        print("\n  -> Token prüfen: notion.so/my-integrations")
        return 1
    melde("Token gültig", True, f"Integration: {daten.get('name', '?')}")

    # 2 ─ Zugriff auf Wurzelseite (der eine manuelle Schritt in Notion)
    code, daten = anfrage("GET", f"/pages/{WURZEL_SEITE_ID}")
    if code != 200:
        melde("Zugriff auf 🐞 Fehlerzentrale", False, f"HTTP {code}: {daten.get('message', '')}")
        print(
            "\n  -> In Notion die Seite '🐞 Fehlerzentrale' öffnen,\n"
            "     ••• → 'Verbindungen' → die Integration hinzufügen.\n"
            "     Alle Unterseiten erben den Zugriff automatisch."
        )
        return 1
    melde("Zugriff auf 🐞 Fehlerzentrale", True)

    # 3 ─ Registry abfragen (Weg, den jede App bei jedem Kaltstart geht)
    code, daten = anfrage(
        "POST",
        f"/databases/{REGISTRY_DB_ID}/query",
        {"filter": {"property": "App-Key", "rich_text": {"equals": APP_KEY}}, "page_size": 1},
    )
    if code != 200:
        melde("Registry '📊 Apps' abfragbar", False, f"HTTP {code}: {daten.get('message', '')}")
        return 1
    treffer = daten.get("results", [])
    melde("Registry '📊 Apps' abfragbar", True, f"{len(treffer)} Treffer für '{APP_KEY}'")

    seiten_id = None
    db_id = None
    registry_id = None

    if treffer:
        eintrag = treffer[0]
        registry_id = eintrag["id"]
        props = eintrag["properties"]
        db_id = "".join(t["plain_text"] for t in props["Datenbank-ID"]["rich_text"])
        melde("Bestehende Test-App wiederverwendet", True, db_id)
    else:
        # 4 ─ App-Seite anlegen
        code, daten = anfrage(
            "POST",
            "/pages",
            {
                "parent": {"page_id": WURZEL_SEITE_ID},
                "icon": {"emoji": "🐛"},
                "properties": {"title": {"title": [{"text": {"content": APP_NAME}}]}},
                "children": [
                    {
                        "object": "block",
                        "type": "paragraph",
                        "paragraph": {
                            "rich_text": [
                                {
                                    "type": "text",
                                    "text": {"content": f"App-Key: {APP_KEY} — automatisch erzeugt."},
                                }
                            ]
                        },
                    }
                ],
            },
        )
        if code != 200:
            melde("App-Seite anlegen", False, f"HTTP {code}: {daten.get('message', '')}")
            return 1
        seiten_id = daten["id"]
        melde("App-Seite anlegen", True, seiten_id)

        # 5 ─ Berichts-Datenbank anlegen
        schema = {
            "Titel": {"title": {}},
            "Status": {
                "select": {
                    "options": [
                        {"name": "Neu", "color": "red"},
                        {"name": "In Arbeit", "color": "yellow"},
                        {"name": "Behoben", "color": "green"},
                        {"name": "Ignoriert", "color": "gray"},
                    ]
                }
            },
            "Art": {
                "select": {
                    "options": [
                        {"name": "Absturz", "color": "red"},
                        {"name": "Auto-Fehler", "color": "orange"},
                        {"name": "Manuelle Meldung", "color": "blue"},
                    ]
                }
            },
            "Beschreibung": {"rich_text": {}},
            "Fehler": {"rich_text": {}},
            "Seite": {"rich_text": {}},
            "Version": {"rich_text": {}},
            "Plattform": {
                "select": {
                    "options": [
                        {"name": n} for n in ["Android", "iOS", "Web", "Windows", "macOS", "Linux"]
                    ]
                }
            },
            "OS": {"rich_text": {}},
            "Gerät": {"rich_text": {}},
            "Zeitstempel": {"date": {}},
            "Fingerprint": {"rich_text": {}},
        }
        code, daten = anfrage(
            "POST",
            "/databases",
            {
                "parent": {"type": "page_id", "page_id": seiten_id},
                "is_inline": True,
                "icon": {"emoji": "🐛"},
                "title": [{"type": "text", "text": {"content": f"🐛 {APP_NAME}"}}],
                "properties": schema,
            },
        )
        if code != 200:
            melde("Berichts-Datenbank anlegen", False, f"HTTP {code}: {daten.get('message', '')}")
            return 1
        db_id = daten["id"]
        melde("Berichts-Datenbank anlegen", True, db_id)

        # 6 ─ Registry-Zeile anlegen
        jetzt = datetime.now(timezone.utc).isoformat()
        code, daten = anfrage(
            "POST",
            "/pages",
            {
                "parent": {"database_id": REGISTRY_DB_ID},
                "properties": {
                    "App": {"title": [{"text": {"content": APP_NAME}}]},
                    "App-Key": {"rich_text": [{"text": {"content": APP_KEY}}]},
                    "Datenbank-ID": {"rich_text": [{"text": {"content": db_id}}]},
                    "Seiten-ID": {"rich_text": [{"text": {"content": seiten_id}}]},
                    "Plattform": {"rich_text": [{"text": {"content": "Selbsttest"}}]},
                    "Version": {"rich_text": [{"text": {"content": "0.0.0"}}]},
                    "Erste Meldung": {"date": {"start": jetzt}},
                    "Letzte Meldung": {"date": {"start": jetzt}},
                    "Berichte": {"number": 1},
                    "Status": {"select": {"name": "Aktiv"}},
                },
            },
        )
        if code != 200:
            melde("Registry-Zeile anlegen", False, f"HTTP {code}: {daten.get('message', '')}")
            return 1
        registry_id = daten["id"]
        melde("Registry-Zeile anlegen", True, registry_id)

    # 7 ─ Bericht anlegen (Properties + Protokoll/Stack im Seitentext)
    jetzt = datetime.now(timezone.utc)
    # Bewusst > 2000 Zeichen, damit die Aufteilung auf mehrere
    # rich_text-Objekte (Notion-Limit) mitgeprüft wird.
    protokoll = "\n".join(
        f"[{i:02d}:00:00] Protokollzeile {i} — " + "x" * 60 for i in range(1, 60)
    )
    assert len(protokoll) > 2000
    code, daten = anfrage(
        "POST",
        "/pages",
        {
            "parent": {"database_id": db_id},
            "properties": {
                "Titel": {"title": [{"text": {"content": f"Selbsttest {jetzt:%d.%m.%Y %H:%M}"}}]},
                "Status": {"select": {"name": "Neu"}},
                "Art": {"select": {"name": "Manuelle Meldung"}},
                "Beschreibung": {"rich_text": [{"text": {"content": "Automatischer Selbsttest."}}]},
                "Fehler": {"rich_text": [{"text": {"content": "kein Fehler"}}]},
                "Seite": {"rich_text": [{"text": {"content": "Selbsttest"}}]},
                "Version": {"rich_text": [{"text": {"content": "0.0.0"}}]},
                "Plattform": {"select": {"name": "Linux"}},
                "OS": {"rich_text": [{"text": {"content": "Prüfskript"}}]},
                "Gerät": {"rich_text": [{"text": {"content": "CI"}}]},
                "Zeitstempel": {"date": {"start": jetzt.isoformat()}},
                "Fingerprint": {"rich_text": [{"text": {"content": uuid.uuid4().hex[:12]}}]},
            },
            "children": [
                {
                    "object": "block",
                    "type": "heading_3",
                    "heading_3": {"rich_text": [{"type": "text", "text": {"content": "Protokoll"}}]},
                },
                {
                    "object": "block",
                    "type": "code",
                    "code": {"language": "plain text", "rich_text": text_bloecke(protokoll)},
                },
            ],
        },
    )
    if code != 200:
        melde("Bericht anlegen", False, f"HTTP {code}: {daten.get('message', '')}")
        return 1
    bericht_id = daten["id"]
    melde("Bericht anlegen", True, daten.get("url", bericht_id))

    # 8 ─ Screenshot hochladen und anhängen
    code, daten = anfrage(
        "POST", "/file_uploads", {"filename": "screenshot.png", "content_type": "image/png"}
    )
    if code != 200:
        melde("Screenshot-Upload anlegen", False, f"HTTP {code}: {daten.get('message', '')}")
    else:
        upload_id = daten["id"]
        grenze = uuid.uuid4().hex
        koerper = (
            f"--{grenze}\r\n"
            'Content-Disposition: form-data; name="file"; filename="screenshot.png"\r\n'
            "Content-Type: image/png\r\n\r\n"
        ).encode() + MINI_PNG + f"\r\n--{grenze}--\r\n".encode()
        code, daten = anfrage(
            "POST",
            f"/file_uploads/{upload_id}/send",
            roh=koerper,
            content_type=f"multipart/form-data; boundary={grenze}",
        )
        if code != 200:
            melde("Screenshot hochladen", False, f"HTTP {code}: {daten.get('message', '')}")
        else:
            melde("Screenshot hochladen", True, upload_id)
            code, daten = anfrage(
                "PATCH",
                f"/blocks/{bericht_id}/children",
                {
                    "children": [
                        {
                            "object": "block",
                            "type": "image",
                            "image": {"type": "file_upload", "file_upload": {"id": upload_id}},
                        }
                    ]
                },
            )
            melde(
                "Screenshot an Bericht anhängen",
                code == 200,
                "" if code == 200 else f"HTTP {code}: {daten.get('message', '')}",
            )

    # 9 ─ Registry aktualisieren
    if registry_id:
        code, daten = anfrage(
            "PATCH",
            f"/pages/{registry_id}",
            {"properties": {"Letzte Meldung": {"date": {"start": jetzt.isoformat()}}}},
        )
        melde(
            "Registry aktualisieren",
            code == 200,
            "" if code == 200 else f"HTTP {code}: {daten.get('message', '')}",
        )

    # 10 ─ Aufräumen
    if not behalten and seiten_id:
        a, _ = anfrage("PATCH", f"/pages/{seiten_id}", {"archived": True})
        b = 200
        if registry_id:
            b, _ = anfrage("PATCH", f"/pages/{registry_id}", {"archived": True})
        melde("Testdaten aufgeräumt", a == 200 and b == 200)
    elif behalten:
        print("\n  (Testdaten bleiben stehen — --behalten)")

    fehler = [n for n, ok, _ in schritte if not ok]
    print()
    if fehler:
        print(f"✗ {len(fehler)} von {len(schritte)} Schritten fehlgeschlagen: {', '.join(fehler)}")
        return 1
    print(f"✓ Alle {len(schritte)} Schritte erfolgreich — die Fehlerzentrale ist einsatzbereit.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
