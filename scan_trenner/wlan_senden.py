"""PDFs vorübergehend im WLAN fürs Handy bereitstellen (DokuBox scannt den QR-Code).

Ablauf: PC wählt Dateien → kleiner HTTP-Server im lokalen Netz → QR-Code mit
Link `http://<PC-IP>:<Port>/dokubox/<Schlüssel>/`. Die DokuBox-App liest daraus
die Dateiliste und lädt die PDFs. Der Link enthält einen Zufallsschlüssel,
gilt nur, solange das Fenster offen ist (höchstens [GUELTIG_MINUTEN]), und es
werden nur die ausgewählten Dateien ausgeliefert. Im Handy-Browser geöffnet,
zeigt derselbe Link eine einfache Download-Liste.
"""
from __future__ import annotations

import html
import json
import secrets
import socket
import threading
import time
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Callable
from urllib.parse import quote, unquote

GUELTIG_MINUTEN = 15


def lokale_ip() -> str:
    """IP-Adresse des PCs im WLAN/LAN (ohne dass ein Paket verschickt wird)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("192.168.255.255", 1))  # nur Routing-Abfrage, sendet nichts
        ip = s.getsockname()[0]
    except OSError:
        ip = "127.0.0.1"
    finally:
        s.close()
    if ip.startswith("127."):
        try:
            ip = socket.gethostbyname(socket.gethostname())
        except OSError:
            pass
    return ip


@dataclass
class Datei:
    id: str
    pfad: Path
    abgeholt: int = 0

    @property
    def name(self) -> str:
        return self.pfad.name


class Freigabe:
    """Stellt [dateien] unter einem geheimen Link im lokalen Netz bereit."""

    def __init__(self, dateien: list[Path], port: int = 0, ip: str | None = None,
                 minuten: int = GUELTIG_MINUTEN,
                 meldung: Callable[[str], None] | None = None) -> None:
        self.dateien = {f"{i + 1}": Datei(f"{i + 1}", Path(p)) for i, p in enumerate(dateien)}
        self.schluessel = secrets.token_urlsafe(18)
        self.ip = ip or lokale_ip()
        self.ablauf = time.time() + minuten * 60
        self.meldung = meldung or (lambda _t: None)
        freigabe = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_args) -> None:  # kein Konsolen-Spam
                pass

            def do_GET(self) -> None:  # noqa: N802 (http.server-API)
                freigabe._antworte(self)

        self.server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
        self.port = self.server.server_address[1]
        self._thread: threading.Thread | None = None

    @property
    def basis(self) -> str:
        return f"/dokubox/{self.schluessel}/"

    @property
    def link(self) -> str:
        return f"http://{self.ip}:{self.port}{self.basis}"

    @property
    def abgelaufen(self) -> bool:
        return time.time() > self.ablauf

    def starten(self) -> "Freigabe":
        self._thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self._thread.start()
        return self

    def stoppen(self) -> None:
        self.server.shutdown()
        self.server.server_close()

    # ------------------------------------------------------------------ HTTP

    def _antworte(self, h: BaseHTTPRequestHandler) -> None:
        pfad = unquote(h.path.split("?", 1)[0])
        if self.abgelaufen or not pfad.startswith(self.basis):
            return self._fehler(h, 404, "Link ungültig oder abgelaufen.")
        rest = pfad[len(self.basis):]
        if rest in ("", "index.html"):
            return self._seite(h)
        if rest == "liste":
            return self._liste(h)
        if rest.startswith("datei/"):
            return self._datei(h, rest[len("datei/"):].split("/", 1)[0])
        return self._fehler(h, 404, "Nicht gefunden.")

    def _senden(self, h: BaseHTTPRequestHandler, code: int, typ: str, daten: bytes,
                extra: dict[str, str] | None = None) -> None:
        h.send_response(code)
        h.send_header("Content-Type", typ)
        h.send_header("Content-Length", str(len(daten)))
        h.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            h.send_header(k, v)
        h.end_headers()
        h.wfile.write(daten)

    def _fehler(self, h: BaseHTTPRequestHandler, code: int, text: str) -> None:
        self._senden(h, code, "text/plain; charset=utf-8", text.encode("utf-8"))

    def _liste(self, h: BaseHTTPRequestHandler) -> None:
        eintraege = [
            {"id": d.id, "name": d.name, "groesse": d.pfad.stat().st_size}
            for d in self.dateien.values() if d.pfad.exists()
        ]
        daten = json.dumps({"app": "dokubox-wlan", "version": 1, "dateien": eintraege},
                           ensure_ascii=False).encode("utf-8")
        self.meldung(f"Handy verbunden ({h.client_address[0]}), {len(eintraege)} Datei(en) angeboten")
        self._senden(h, 200, "application/json; charset=utf-8", daten)

    def _datei(self, h: BaseHTTPRequestHandler, datei_id: str) -> None:
        d = self.dateien.get(datei_id)
        if d is None or not d.pfad.exists():
            return self._fehler(h, 404, "Datei nicht gefunden.")
        daten = d.pfad.read_bytes()
        d.abgeholt += 1
        self.meldung(f"→ {d.name} übertragen ({len(daten) // 1024} KB)")
        self._senden(h, 200, "application/pdf", daten, {
            "Content-Disposition": f"attachment; filename*=UTF-8''{quote(d.name)}",
        })

    def _seite(self, h: BaseHTTPRequestHandler) -> None:
        zeilen = "".join(
            f'<li><a href="datei/{d.id}">{html.escape(d.name)}</a></li>'
            for d in self.dateien.values()
        )
        seite = (
            "<!doctype html><meta charset='utf-8'>"
            "<meta name='viewport' content='width=device-width,initial-scale=1'>"
            "<title>Scan-Trenner → Handy</title>"
            "<body style='font-family:sans-serif;margin:16px'>"
            "<h2>Dateien vom PC</h2>"
            "<p>Am bequemsten in der DokuBox-App: <b>PDF importieren → Vom PC (WLAN)</b> "
            "und den QR-Code scannen. Hier gehen die Dateien auch einzeln:</p>"
            f"<ul>{zeilen}</ul></body>"
        ).encode("utf-8")
        self._senden(h, 200, "text/html; charset=utf-8", seite)


def qr_bild(text: str, groesse: int = 280):
    """QR-Code als PIL-Bild (für das Tk-Fenster)."""
    import qrcode  # erst hier, damit der Rest auch ohne das Paket läuft

    qr = qrcode.QRCode(border=2, box_size=10)
    qr.add_data(text)
    qr.make(fit=True)
    bild = qr.make_image(fill_color="black", back_color="white").convert("RGB")
    return bild.resize((groesse, groesse))
