import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import wlan_senden as ws


@pytest.fixture
def freigabe(tmp_path):
    a = tmp_path / "Rechnung enviaM.pdf"
    a.write_bytes(b"%PDF-1.4 a")
    b = tmp_path / "Depot.pdf"
    b.write_bytes(b"%PDF-1.4 bb")
    (tmp_path / "geheim.pdf").write_bytes(b"nicht freigegeben")
    meldungen = []
    f = ws.Freigabe([a, b], ip="127.0.0.1", meldung=meldungen.append).starten()
    f.meldungen = meldungen
    yield f
    f.stoppen()


def holen(url):
    with urllib.request.urlopen(url, timeout=5) as r:
        return r.status, r.headers, r.read()


def test_liste_und_download(freigabe):
    status, _, daten = holen(freigabe.link + "liste")
    liste = json.loads(daten)
    assert status == 200 and liste["app"] == "dokubox-wlan"
    assert [d["name"] for d in liste["dateien"]] == ["Rechnung enviaM.pdf", "Depot.pdf"]
    assert liste["dateien"][1]["groesse"] == len(b"%PDF-1.4 bb")

    status, kopf, daten = holen(freigabe.link + "datei/1")
    assert status == 200 and daten == b"%PDF-1.4 a"
    assert kopf["Content-Type"] == "application/pdf"
    assert freigabe.dateien["1"].abgeholt == 1
    assert any("übertragen" in m for m in freigabe.meldungen)


def test_browser_seite_listet_dateien(freigabe):
    _, kopf, daten = holen(freigabe.link)
    assert kopf["Content-Type"].startswith("text/html")
    assert "Rechnung enviaM.pdf" in daten.decode("utf-8")


@pytest.mark.parametrize("pfad", [
    "/dokubox/falscherschluessel/liste",
    "/liste",
    "/dokubox/{s}/datei/3",
    "/dokubox/{s}/datei/../geheim.pdf",
    "/dokubox/{s}/irgendwas",
])
def test_nur_mit_schluessel_und_nur_freigegebene_dateien(freigabe, pfad):
    url = f"http://127.0.0.1:{freigabe.port}" + pfad.format(s=freigabe.schluessel)
    with pytest.raises(urllib.error.HTTPError) as e:
        holen(url)
    assert e.value.code == 404


def test_link_laeuft_ab(freigabe):
    freigabe.ablauf = time.time() - 1
    with pytest.raises(urllib.error.HTTPError) as e:
        holen(freigabe.link + "liste")
    assert e.value.code == 404


def test_link_format_und_schluessel_zufaellig(tmp_path):
    p = tmp_path / "x.pdf"
    p.write_bytes(b"x")
    f1 = ws.Freigabe([p], ip="192.168.1.20")
    f2 = ws.Freigabe([p], ip="192.168.1.20")
    try:
        assert f1.link.startswith("http://192.168.1.20:")
        assert f1.link.endswith(f"/dokubox/{f1.schluessel}/")
        assert f1.schluessel != f2.schluessel and len(f1.schluessel) >= 20
    finally:
        f1.server.server_close()
        f2.server.server_close()


def test_qr_bild():
    bild = ws.qr_bild("http://192.168.1.20:5000/dokubox/abc/", groesse=200)
    assert bild.size == (200, 200)
