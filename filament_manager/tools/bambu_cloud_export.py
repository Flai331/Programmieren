#!/usr/bin/env python3
"""
Lädt die Druckhistorie aus der Bambu-Cloud als JSON herunter.
Die Datei bambu_history.json dann im Filament-Manager unter „Drucke“ importieren.

Nur Python 3 nötig (keine Zusatzpakete). Aufruf:

    python bambu_cloud_export.py                 # fragt E-Mail, Passwort, ggf. Code
    python bambu_cloud_export.py --token XYZ     # mit vorhandenem Access-Token
    python bambu_cloud_export.py --china         # für Konten auf bambulab.cn

Zugangsdaten werden nirgends gespeichert; das Token wird nur auf Wunsch
(--save-token) in bambu_token.txt neben dem Skript abgelegt.

Hinweis: Bambu dokumentiert diese Schnittstelle nicht offiziell. Wenn Bambu
sie ändert, kann das Skript fehlschlagen – die Import-Varianten mit
.gcode.3mf-Dateien funktionieren unabhängig davon.
"""
import argparse
import getpass
import json
import os
import sys
import urllib.error
import urllib.request

HEADERS = {
    "Content-Type": "application/json",
    "User-Agent": "filament-manager-export/1.0",
}


def call(base, method, path, body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, method=method, headers=dict(HEADERS))
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode() or "{}"
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        text = e.read().decode(errors="replace")
        raise SystemExit(f"Fehler {e.code} bei {path}: {text[:300]}")


def login(base):
    email = input("Bambu-Konto E-Mail: ").strip()
    password = getpass.getpass("Passwort (wird nicht angezeigt): ")
    res = call(base, "POST", "/v1/user-service/user/login", {"account": email, "password": password})
    if res.get("accessToken"):
        return res["accessToken"]
    login_type = res.get("loginType")
    if login_type == "verifyCode":
        call(base, "POST", "/v1/user-service/user/sendemail/code", {"email": email, "type": "codeLogin"})
        code = input("Bambu hat dir einen Code per E-Mail geschickt. Code: ").strip()
        res = call(base, "POST", "/v1/user-service/user/login", {"account": email, "code": code})
        if res.get("accessToken"):
            return res["accessToken"]
    if login_type == "tfa":
        raise SystemExit(
            "Dein Konto nutzt Zwei-Faktor-Login (Authenticator-App). Das unterstützt das Skript nicht direkt.\n"
            "Nutze stattdessen die .gcode.3mf-Dateien oder starte das Skript mit --token <Access-Token>."
        )
    raise SystemExit("Login fehlgeschlagen: " + json.dumps(res)[:300])


def main():
    ap = argparse.ArgumentParser(description="Bambu-Cloud-Druckhistorie exportieren")
    ap.add_argument("--token", help="vorhandenes Access-Token verwenden")
    ap.add_argument("--china", action="store_true", help="Server api.bambulab.cn verwenden")
    ap.add_argument("--limit", type=int, default=500, help="max. Anzahl Drucke (Standard 500)")
    ap.add_argument("--out", default="bambu_history.json", help="Ausgabedatei")
    ap.add_argument("--save-token", action="store_true", help="Token in bambu_token.txt speichern")
    args = ap.parse_args()

    base = "https://api.bambulab.cn" if args.china else "https://api.bambulab.com"
    token_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bambu_token.txt")
    token = args.token
    if not token and os.path.exists(token_file):
        token = open(token_file, encoding="utf-8").read().strip()
    if not token:
        token = login(base)
        if args.save_token:
            with open(token_file, "w", encoding="utf-8") as f:
                f.write(token)

    res = call(base, "GET", f"/v1/user-service/my/tasks?limit={args.limit}", token=token)
    hits = res.get("hits") or []
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump({"hits": hits, "total": res.get("total", len(hits))}, f, ensure_ascii=False, indent=1)
    print(f"{len(hits)} Drucke gespeichert in {os.path.abspath(args.out)}")
    print("→ Im Filament-Manager unter „Drucke“ importieren.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(1)
