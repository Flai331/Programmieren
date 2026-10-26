import sys
from datetime import date, datetime
from pathlib import Path

import pymupdf as fitz

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import rechnungen as rg
import scan_trenner_cli

JETZT = datetime(2026, 10, 22, 12)
HEUTE = JETZT.date()

STADTWERKE = """Stadtwerke Musterstadt GmbH · Hauptstr. 1 · 12345 Musterstadt
Rechnung Nr. 2026-4711
Datum: 15.10.2026
Position 1  Strom Oktober           80,00 €
MwSt 19 %                            15,20 €
Rechnungsbetrag                      95,20 €
Bitte überweisen Sie den Betrag bis zum 05.11.2026 auf unser Konto.
"""

GOAE = """Dr. med. Anna Beispiel · Fachärztin für Innere Medizin · 54321 Ort
Privatliquidation
Rechnungsdatum 01.10.2026
Leistungen nach GOÄ
Ziffer 1  Beratung     10,72
Gesamtbetrag: 1.234,56 EUR
Zahlbar innerhalb von 30 Tagen nach Rechnungsdatum.
"""


def test_betrag():
    assert rg.betrag_cent(STADTWERKE) == 9520
    assert rg.betrag_cent(GOAE) == 123456
    assert rg.betrag_cent("Kosten insgesamt EUR 42,10 netto") == 4210
    assert rg.betrag_cent("Sehr geehrte Damen und Herren") is None


def test_faelligkeit():
    assert rg.faelligkeit(STADTWERKE, heute=HEUTE) == date(2026, 11, 5)
    assert rg.faelligkeit("Zahlbar bis 3. Dezember 2026", heute=HEUTE) == date(2026, 12, 3)
    assert rg.faelligkeit(GOAE, date(2026, 10, 1), HEUTE) == date(2026, 10, 31)
    skonto = "Zahlbar innerhalb von 10 Tagen mit 2 % Skonto, 30 Tage netto."
    assert rg.faelligkeit(skonto, date(2026, 10, 1), HEUTE) == date(2026, 10, 31)
    assert rg.faelligkeit("Der Betrag ist sofort fällig.", date(2026, 10, 1), HEUTE) == date(2026, 10, 1)
    assert rg.faelligkeit("Vielen Dank für Ihren Einkauf", heute=HEUTE) is None


def test_status():
    assert rg.zahlungsstatus(STADTWERKE) == rg.ZU_BEZAHLEN
    assert rg.zahlungsstatus("Rechnung 12,00 €. Der Betrag wird am 01.11.2026 von Ihrem Konto abgebucht.") == rg.WIRD_ABGEBUCHT
    assert rg.zahlungsstatus("Summe 12,40 EUR\nGegeben bar 20,00\nRückgeld 7,60") == rg.BEZAHLT
    assert rg.zahlungsstatus("Ihre Jahresabrechnung: Ihr Guthaben von 84,00 € überweisen wir Ihnen.") == rg.GUTSCHRIFT
    assert rg.zahlungsstatus("Wir informieren Sie über neue AGB.") is None


def test_erstattung():
    assert rg.ist_arztrechnung(GOAE)
    assert not rg.ist_arztrechnung(STADTWERKE)
    assert rg.vorgeschlagene_stellen(GOAE, ["Heilfürsorge"]) == ["Heilfürsorge"]
    assert rg.vorgeschlagene_stellen(GOAE, ["Beihilfe", "Private Krankenversicherung"]) == [
        "Beihilfe", "Private Krankenversicherung"]
    handwerker = "Rechnung Malerarbeiten\nArbeitskosten 400,00 €\nGesamtbetrag 650,00 €"
    assert rg.vorgeschlagene_stellen(handwerker, ["Krankenkasse"]) == [rg.STEUER]


def test_euro():
    assert rg.euro(123456) == "1.234,56 €"
    assert rg.euro_lesen("1.234,56") == 123456
    assert rg.euro_lesen("12 €") == 1200
    assert rg.euro_lesen("abc") is None


def test_analyse_und_erinnerung():
    r = rg.analysiere(STADTWERKE, "x.pdf", rg.Rechnungseinstellungen(vorlauf_tage=2), JETZT)
    assert (r.status, r.betrag_cent, r.faellig) == (rg.ZU_BEZAHLEN, 9520, "2026-11-05")
    assert r.erinnerung_am == "2026-11-03T09:00"
    assert rg.analysiere("Ihre neue Versichertenkarte", "y.pdf", jetzt=JETZT) is None
    spaet = rg.zahlungserinnerung(date(2026, 10, 23), 3, JETZT)
    assert spaet == datetime(2026, 10, 22, 14)


def test_rechnungsbuch(tmp_path):
    buch = rg.Rechnungsbuch.im_ordner(tmp_path)
    r = rg.analysiere(GOAE, "arzt.pdf", rg.Rechnungseinstellungen(stellen=["Beihilfe"]), JETZT)
    buch.hinzufuegen(r)
    buch2 = rg.Rechnungsbuch.im_ordner(tmp_path)  # neu laden
    assert [x.id for x in buch2.offene()] == [r.id]
    assert [x.stelle for _, x in buch2.offene_erstattungen()] == ["Beihilfe"]

    buch2.erstattung_setzen(r.id, "Beihilfe", rg.EINGEREICHT, nachfassen_wochen=6, jetzt=JETZT)
    x = buch2.finden(r.id).erstattungen[0]
    assert x.eingereicht_am == "2026-10-22" and x.nachfassen_am == "2026-12-03T09:00"

    # Erinnerungen: Zahlung (30.10. - 3 Tage) und Nachfassen
    texte = buch2.faellige_erinnerungen(datetime(2026, 12, 4))
    assert len(texte) == 2 and texte[0].startswith("Rechnung bezahlen")
    assert buch2.faellige_erinnerungen(datetime(2026, 12, 5)) == []  # nur einmal

    buch2.als_bezahlt(r.id, date(2026, 10, 25))
    assert buch2.offene() == []
    buch2.erstattung_setzen(r.id, "Beihilfe", rg.TEILWEISE, erstattet_cent=50000)
    assert buch2.offene_erstattungen() == []


def test_ics():
    r = rg.analysiere(STADTWERKE, "strom.pdf", jetzt=JETZT)
    text = rg.ics_text(r)
    assert "DTSTART;VALUE=DATE:20261105" in text
    assert "TRIGGER:-PT3780M" in text  # 02.11. 9:00 → 05.11. 0:00
    assert "95\\,20 €" in text


def _pdf_mit_text(pfad: Path, seiten: list[str]) -> Path:
    doc = fitz.open()
    for inhalt in seiten:
        seite = doc.new_page()
        if inhalt:
            seite.insert_textbox(fitz.Rect(50, 50, 550, 800), inhalt, fontsize=11)
    doc.save(str(pfad))
    doc.close()
    return pfad


def test_cli_erkennt_rechnungen(tmp_path):
    eingang = tmp_path / "eingang"
    eingang.mkdir()
    _pdf_mit_text(eingang / "stapel.pdf", [STADTWERKE, "", "Ihre neue Versichertenkarte\n" * 5])
    assert scan_trenner_cli.main([str(eingang), "--rechnungen"]) == 0
    buch = rg.Rechnungsbuch.im_ordner(eingang / "fertig")
    assert len(buch.rechnungen) == 1
    r = buch.rechnungen[0]
    assert r.betrag_cent == 9520 and r.faellig == "2026-11-05"
    assert list((eingang / "fertig" / "Erinnerungen").glob("*.ics"))
