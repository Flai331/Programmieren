"""Rechnungen erkennen und verwalten: Betrag, Fälligkeit, Zahlungsstatus,
Einreichung bei Krankenkasse/Beihilfe/Heilfürsorge, Erinnerungen.

Die Erkennungsregeln entsprechen denen der DokuBox-App
(dokumenten_system/dokubox/lib/extract/payment_extractors.dart).
Ohne Oberfläche, damit GUI, Kommandozeile und Tests sie gleich nutzen.
"""
from __future__ import annotations

import json
import re
import uuid
from dataclasses import asdict, dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

# ---------------------------------------------------------------- Konstanten

ZU_BEZAHLEN = "zu bezahlen"
WIRD_ABGEBUCHT = "wird abgebucht"
BEZAHLT = "bezahlt"
GUTSCHRIFT = "Gutschrift"
ZAHLUNGSSTATUS = [ZU_BEZAHLEN, WIRD_ABGEBUCHT, BEZAHLT, GUTSCHRIFT]

EINZUREICHEN = "einzureichen"
EINGEREICHT = "eingereicht"
ERSTATTET = "erstattet"
TEILWEISE = "teilweise erstattet"
ABGELEHNT = "abgelehnt"
ERSTATTUNGSSTATUS = [EINZUREICHEN, EINGEREICHT, ERSTATTET, TEILWEISE, ABGELEHNT]

STEUER = "Steuererklärung"
ERSTATTUNGSSTELLEN = [
    "Krankenkasse",
    "Private Krankenversicherung",
    "Beihilfe",
    "Heilfürsorge",
    "Zusatzversicherung",
    "Pflegekasse",
    "Unfallversicherung / BG",
    "Arbeitgeber",
    STEUER,
]

I = re.IGNORECASE

# --------------------------------------------------------------------- Datum

_MONATE = {
    "januar": 1, "jan": 1, "februar": 2, "feb": 2, "märz": 3, "maerz": 3, "mrz": 3,
    "april": 4, "apr": 4, "mai": 5, "juni": 6, "jun": 6, "juli": 7, "jul": 7,
    "august": 8, "aug": 8, "september": 9, "sep": 9, "sept": 9, "oktober": 10,
    "okt": 10, "november": 11, "nov": 11, "dezember": 12, "dez": 12,
}
_DATUM_ZAHL = re.compile(r"\b(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{4}|\d{2})\b")
_DATUM_TEXT = re.compile(
    r"\b(\d{1,2})\.?\s(Januar|Februar|März|Maerz|April|Mai|Juni|Juli|August|September|"
    r"Oktober|November|Dezember|Jan|Feb|Mrz|Apr|Jun|Jul|Aug|Sep|Sept|Okt|Nov|Dez)\.?\s(\d{4})\b", I)
_DATUM_ISO = re.compile(r"\b(\d{4})-(\d{2})-(\d{2})\b")


def daten_im_text(text: str, heute: date | None = None) -> list[date]:
    """Alle plausiblen Datumsangaben in Reihenfolge des Auftretens."""
    heute = heute or date.today()
    funde: list[tuple[int, date]] = []

    def neu(pos: int, j: int, m: int, t: int) -> None:
        if j < 100:
            j += 1900 if j >= 70 else 2000
        try:
            d = date(j, m, t)
        except ValueError:
            return
        if d.year < heute.year - 30 or d > heute + timedelta(days=730):
            return
        funde.append((pos, d))

    for m in _DATUM_ZAHL.finditer(text):
        neu(m.start(), int(m[3]), int(m[2]), int(m[1]))
    for m in _DATUM_TEXT.finditer(text):
        monat = _MONATE.get(m[2].lower().rstrip("."))
        if monat:
            neu(m.start(), int(m[3]), monat, int(m[1]))
    for m in _DATUM_ISO.finditer(text):
        neu(m.start(), int(m[1]), int(m[2]), int(m[3]))
    return [d for _, d in sorted(funde, key=lambda f: f[0])]


def dokumentdatum(text: str, heute: date | None = None) -> date | None:
    """Briefe tragen ihr Datum im Kopf: die erste Datumsangabe gewinnt."""
    daten = daten_im_text(text, heute)
    return daten[0] if daten else None

# -------------------------------------------------------------------- Betrag

_BETRAG = r"(\d{1,3}(?:[. ]\d{3})+|\d+),(\d{2})(?!\d)"
_BETRAG_STARK = re.compile(
    r"(zu zahlender (?:gesamt)?betrag|zahlbetrag|rechnungsbetrag|gesamtbetrag|endbetrag|"
    r"gesamtsumme|rechnungssumme|bruttobetrag|summe brutto|brutto ?summe|offener betrag|"
    r"forderungsbetrag|zu zahlen|ihr (?:eigen)?anteil|eigenanteil)[^\d\n]{0,40}" + _BETRAG, I)
_BETRAG_SCHWACH = re.compile(r"\b(summe|betrag|total|gesamt)\b[^\d\n]{0,30}" + _BETRAG, I)
_BETRAG_EURO = re.compile(r"(?:(?:€|EUR)\s?" + _BETRAG + r")|(?:" + _BETRAG + r"\s?(?:€|EUR))")


def _cent(euro: str, cent: str) -> int:
    return int(re.sub(r"[. ]", "", euro)) * 100 + int(cent)


def betrag_cent(text: str) -> int | None:
    """Endbetrag in Cent: beschriftete Endbeträge → "Summe/Betrag" → irgendein
    Euro-Betrag. Je Stufe gewinnt der größte Wert (Endbetrag ≥ Positionen)."""
    stark = [_cent(m[2], m[3]) for m in _BETRAG_STARK.finditer(text)]
    if stark and max(stark) > 0:
        return max(stark)
    schwach = [_cent(m[2], m[3]) for m in _BETRAG_SCHWACH.finditer(text)]
    if schwach and max(schwach) > 0:
        return max(schwach)
    alle = [_cent(m[1], m[2]) if m[1] else _cent(m[3], m[4]) for m in _BETRAG_EURO.finditer(text)]
    return max(alle) if alle and max(alle) > 0 else None


def euro(cent: int | None) -> str:
    """12345 → "123,45 €"."""
    if cent is None:
        return ""
    s = f"{cent / 100:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return f"{s} €"


def euro_lesen(eingabe: str) -> int | None:
    """"1.234,56", "12 €" → Cent; None bei ungültiger Eingabe."""
    s = re.sub(r"[€\sEUReur]", "", eingabe)
    if not s:
        return None
    if "," in s:
        s = s.replace(".", "").replace(",", ".")
    elif re.fullmatch(r"\d{1,3}(\.\d{3})+", s):
        s = s.replace(".", "")
    try:
        wert = float(s)
    except ValueError:
        return None
    return round(wert * 100) if wert >= 0 else None

# --------------------------------------------------------------- Fälligkeit

_FAELLIG_LABEL = re.compile(
    r"(zahlbar bis|fällig (?:am|bis|zum)|fälligkeit(?:sdatum)?|zahlungsziel|zahlungsfrist|"
    r"zahlungstermin|spätestens (?:am|bis)|bis spätestens|"
    r"(?:zahlen|überweisen|begleichen) sie[^.\n]{0,40}?bis(?: zum)?|"
    r"(?:zahlung|überweisung|ausgleich)[^.\n]{0,30}?bis(?: zum)?|"
    r"abbuchung (?:am|erfolgt am)|abgebucht am|einzug am)", I)
_FAELLIG_RELATIV = re.compile(
    r"(?:(?:innerhalb|binnen)\s+(?:von\s+)?(\d{1,3})\s+(?:kalender)?tag|"
    r"(\d{1,3})\s+tage?n?\s+(?:netto|ohne abzug|nach (?:erhalt|rechnungs))|"
    r"zahlungsziel[:\s]+(\d{1,3})\s+tag)", I)
_SOFORT = re.compile(r"sofort (?:fällig|zahlbar|nach erhalt)|ohne abzug sofort|zahlbar sofort", I)


def faelligkeit(text: str, rechnungsdatum: date | None = None, heute: date | None = None) -> date | None:
    """Ausdrückliches Datum hinter einer Beschriftung ("zahlbar bis …"), sonst
    Frist in Tagen ab Rechnungsdatum. Bei Skonto gewinnt das Netto-Ziel."""
    heute = heute or date.today()
    for m in _FAELLIG_LABEL.finditer(text):
        daten = daten_im_text(text[m.end(): m.end() + 60], heute)
        if daten:
            return daten[0]
    basis = rechnungsdatum or heute
    tage = [int(m[1] or m[2] or m[3]) for m in _FAELLIG_RELATIV.finditer(text)]
    tage = [t for t in tage if 0 < t <= 120]
    if tage:
        return basis + timedelta(days=max(tage))
    if _SOFORT.search(text):
        return basis
    return None

# ------------------------------------------------------------ Zahlungsstatus

_BEZAHLT = re.compile(
    r"betrag (?:dankend )?erhalten|bereits (?:bezahlt|beglichen|überwiesen)|"
    r"(?:bar|per karte|mit karte) bezahlt|zahlung (?:dankend )?erhalten|"
    r"rechnung (?:ist )?beglichen|betrag wurde[^.\n]{0,30}beglichen|\bquittiert\b|"
    r"zahlungsart:? ?(?:bar|ec|girocard|kreditkarte|paypal)|\bgirocard\b|\bec-karte\b|"
    r"kartenzahlung|gegeben\s+bar|rückgeld", I)
_LASTSCHRIFT = re.compile(
    r"(?:per|mittels|im) (?:sepa-)?lastschrift|lastschriftverfahren|sepa-lastschrift|"
    r"wird[^\n]{0,60}?(?:abgebucht|eingezogen)|"
    r"(?:buchen|ziehen) (?:wir )?den (?:rechnungs)?betrag[^.\n]{0,40}(?:ab|ein)\b|"
    r"abbuchung (?:am|erfolgt)|bankeinzug", I)
_GUTSCHRIFT = re.compile(
    r"\bgutschrift\b|ihr guthaben|guthaben (?:von|in höhe)|(?:erstatten|überweisen) (?:wir )?ihnen|"
    r"rückerstattung an sie", I)
_SCHULDET = re.compile(
    r"nachzahlung|zahlbar|fällig|zu zahlen|überweisen sie|zahlungserinnerung|mahnung|offener betrag", I)
_RECHNUNG = re.compile(
    r"rechnung|liquidation|zahlbar|fällig|zahlungsziel|zu zahlen|überweisen sie|"
    r"zahlungserinnerung|mahnung|invoice|beitragsrechnung|nachzahlung|forderung", I)


def zahlungsstatus(text: str) -> str | None:
    """bezahlt / wird abgebucht / Gutschrift / zu bezahlen; None = keine Rechnung."""
    if _BEZAHLT.search(text):
        return BEZAHLT
    if _LASTSCHRIFT.search(text):
        return WIRD_ABGEBUCHT
    if _GUTSCHRIFT.search(text) and not _SCHULDET.search(text):
        return GUTSCHRIFT
    if _RECHNUNG.search(text) and betrag_cent(text) is not None:
        return ZU_BEZAHLEN
    return None

# ----------------------------------------------------------- Erstattungen

_MEDIZIN = re.compile(
    r"(?<![a-z])GO(?:Ä|AE)(?![a-z])|\bGOZ\b|\bGebüH\b|gebührenordnung für (?:ärzte|zahnärzte)|"
    r"\bliquidation\b|privatrechnung|arztrechnung|privatliquidation|zahnarzt|kieferorthopäd|"
    r"heilpraktiker|physiotherap|krankengymnastik|ergotherap|logopäd|osteopath|psychotherap|"
    r"heilmittel|hilfsmittel|apotheke|\brezept\b|\bpzn\b|krankenhaus|klinik|\bpraxis\b|facharzt|"
    r"ärztin|\barzt\b|\bdr\. med|optiker|brillengläser|hörgerät|diagnose|behandlung|"
    r"wahlleistung|chefarzt", I)
_MEDIZIN_STARK = re.compile(r"(?<![a-z])GO(?:Ä|AE)(?![a-z])|\bGOZ\b|\bliquidation\b|arztrechnung", I)
_STEUER = re.compile(
    r"§\s?35a|haushaltsnahe|handwerkerleistung|arbeitskosten|lohnanteil|lohnkosten|"
    r"anteil (?:der )?arbeitsleistung|spendenbescheinigung|zuwendungsbestätigung", I)


def ist_arztrechnung(text: str) -> bool:
    return len(_MEDIZIN.findall(text)) >= 2 or bool(_MEDIZIN_STARK.search(text))


def ist_steuerrelevant(text: str) -> bool:
    return bool(_STEUER.search(text))


def vorgeschlagene_stellen(text: str, meine_stellen: list[str]) -> list[str]:
    """Arztrechnungen → die eingestellten Stellen; Handwerker/Spenden → Steuer."""
    stellen: list[str] = []
    arzt = ist_arztrechnung(text)
    if arzt:
        stellen += [s for s in meine_stellen if s != STEUER]
    if ist_steuerrelevant(text) or (arzt and STEUER in meine_stellen):
        stellen.append(STEUER)
    return stellen

# ---------------------------------------------------------- Erinnerungen

def zahlungserinnerung(faellig: date, vorlauf_tage: int, jetzt: datetime | None = None) -> datetime:
    """Vorlauf-Tage vor Fälligkeit um 9 Uhr; liegt das zurück: in 2 Stunden."""
    jetzt = jetzt or datetime.now()
    tag = faellig - timedelta(days=vorlauf_tage)
    kandidat = datetime(tag.year, tag.month, tag.day, 9)
    return kandidat if kandidat > jetzt else jetzt + timedelta(hours=2)


def nachfassen(eingereicht: datetime, wochen: int) -> datetime:
    tag = eingereicht + timedelta(weeks=wochen)
    return datetime(tag.year, tag.month, tag.day, 9)

# ------------------------------------------------------------ Datenmodell

@dataclass
class Erstattung:
    stelle: str
    status: str = EINZUREICHEN
    eingereicht_am: str | None = None  # ISO-Datum
    erstattet_cent: int | None = None
    erledigt_am: str | None = None
    nachfassen_am: str | None = None  # ISO-Zeitpunkt


@dataclass
class Rechnung:
    datei: str
    id: str = field(default_factory=lambda: uuid.uuid4().hex)
    titel: str = ""
    erkannt_am: str = field(default_factory=lambda: date.today().isoformat())
    rechnungsdatum: str | None = None
    betrag_cent: int | None = None
    status: str | None = None
    faellig: str | None = None
    bezahlt_am: str | None = None
    erinnerung_am: str | None = None  # ISO-Zeitpunkt
    erinnert: bool = False
    erstattungen: list[Erstattung] = field(default_factory=list)

    @property
    def offen(self) -> bool:
        return self.status == ZU_BEZAHLEN

    def ueberfaellig(self, heute: date | None = None) -> bool:
        return self.offen and self.faellig is not None and date.fromisoformat(self.faellig) < (heute or date.today())


@dataclass
class Rechnungseinstellungen:
    vorlauf_tage: int = 3
    nachfassen_wochen: int = 6
    stellen: list[str] = field(default_factory=lambda: ["Krankenkasse"])


def analysiere(text: str, datei: str, e: Rechnungseinstellungen | None = None,
               jetzt: datetime | None = None) -> Rechnung | None:
    """Rechnungsdaten aus dem Text; None, wenn es keine Rechnung ist."""
    e = e or Rechnungseinstellungen()
    jetzt = jetzt or datetime.now()
    status = zahlungsstatus(text)
    stellen = vorgeschlagene_stellen(text, e.stellen)
    if status is None and not stellen:
        return None
    datum = dokumentdatum(text, jetzt.date())
    r = Rechnung(datei=datei, titel=Path(datei).stem, rechnungsdatum=datum.isoformat() if datum else None,
                 betrag_cent=betrag_cent(text), status=status)
    if status in (ZU_BEZAHLEN, WIRD_ABGEBUCHT):
        f = faelligkeit(text, datum, jetzt.date())
        r.faellig = f.isoformat() if f else None
    if status == BEZAHLT and datum:
        r.bezahlt_am = datum.isoformat()
    if status == ZU_BEZAHLEN and r.faellig:
        r.erinnerung_am = zahlungserinnerung(date.fromisoformat(r.faellig), e.vorlauf_tage, jetzt).isoformat(timespec="minutes")
    r.erstattungen = [Erstattung(stelle=s) for s in stellen]
    return r

# --------------------------------------------------------- Rechnungsbuch

class Rechnungsbuch:
    """Alle erkannten Rechnungen als JSON-Datei (im Ausgabeordner)."""

    DATEINAME = "rechnungen.json"

    def __init__(self, pfad: Path) -> None:
        self.pfad = pfad
        self.rechnungen: list[Rechnung] = []
        self.laden()

    @classmethod
    def im_ordner(cls, ordner: Path) -> "Rechnungsbuch":
        return cls(ordner / cls.DATEINAME)

    def laden(self) -> None:
        try:
            daten = json.loads(self.pfad.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            self.rechnungen = []
            return
        self.rechnungen = []
        for d in daten:
            erst = [Erstattung(**x) for x in d.pop("erstattungen", [])]
            self.rechnungen.append(Rechnung(**d, erstattungen=erst))

    def speichern(self) -> None:
        self.pfad.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.pfad.with_suffix(".tmp")
        tmp.write_text(json.dumps([asdict(r) for r in self.rechnungen], indent=2, ensure_ascii=False),
                       encoding="utf-8")
        tmp.replace(self.pfad)

    def hinzufuegen(self, r: Rechnung) -> None:
        self.rechnungen = [x for x in self.rechnungen if x.datei != r.datei]
        self.rechnungen.append(r)
        self.speichern()

    def finden(self, rid: str) -> Rechnung | None:
        return next((r for r in self.rechnungen if r.id == rid), None)

    def offene(self) -> list[Rechnung]:
        return sorted((r for r in self.rechnungen if r.offen), key=lambda r: (r.faellig is None, r.faellig or ""))

    def offene_erstattungen(self) -> list[tuple[Rechnung, Erstattung]]:
        return [(r, x) for r in self.rechnungen for x in r.erstattungen if x.status in (EINZUREICHEN, EINGEREICHT)]

    def als_bezahlt(self, rid: str, am: date | None = None) -> None:
        r = self.finden(rid)
        if r:
            r.status = BEZAHLT
            r.bezahlt_am = (am or date.today()).isoformat()
            r.erinnerung_am = None
            self.speichern()

    def erstattung_setzen(self, rid: str, stelle: str, status: str, nachfassen_wochen: int = 6,
                          erstattet_cent: int | None = None, jetzt: datetime | None = None) -> None:
        r = self.finden(rid)
        x = next((x for x in r.erstattungen if x.stelle == stelle), None) if r else None
        if x is None:
            return
        jetzt = jetzt or datetime.now()
        x.status = status
        if status == EINGEREICHT:
            x.eingereicht_am = jetzt.date().isoformat()
            x.nachfassen_am = nachfassen(jetzt, nachfassen_wochen).isoformat(timespec="minutes")
        elif status in (ERSTATTET, TEILWEISE, ABGELEHNT):
            x.erledigt_am = jetzt.date().isoformat()
            x.nachfassen_am = None
            if erstattet_cent is not None:
                x.erstattet_cent = erstattet_cent
        else:
            x.nachfassen_am = None
        self.speichern()

    def faellige_erinnerungen(self, jetzt: datetime | None = None) -> list[str]:
        """Texte aller fälligen, noch nicht gezeigten Erinnerungen; markiert sie."""
        jetzt = jetzt or datetime.now()
        texte: list[str] = []
        for r in self.rechnungen:
            if r.offen and r.erinnerung_am and not r.erinnert and datetime.fromisoformat(r.erinnerung_am) <= jetzt:
                texte.append(f"Rechnung bezahlen: {r.titel} {euro(r.betrag_cent)}"
                             + (f" – fällig am {_de(r.faellig)}" if r.faellig else ""))
                r.erinnert = True
            for x in r.erstattungen:
                if x.status == EINGEREICHT and x.nachfassen_am and datetime.fromisoformat(x.nachfassen_am) <= jetzt:
                    texte.append(f"Erstattung noch offen: {x.stelle} – {r.titel} "
                                 f"(eingereicht am {_de(x.eingereicht_am)})")
                    x.nachfassen_am = None
        if texte:
            self.speichern()
        return texte


def _de(iso: str | None) -> str:
    return date.fromisoformat(iso[:10]).strftime("%d.%m.%Y") if iso else ""

# ------------------------------------------------------- Kalender (.ics)

def ics_text(r: Rechnung) -> str | None:
    """Kalendereintrag am Fälligkeitstag mit Alarm zur Erinnerungszeit.
    Doppelklick öffnet ihn in Outlook/Kalender; erinnert auch, wenn das
    Programm geschlossen ist."""
    if not r.faellig:
        return None
    tag = date.fromisoformat(r.faellig)
    alarm = ""
    if r.erinnerung_am:
        vorher = datetime(tag.year, tag.month, tag.day) - datetime.fromisoformat(r.erinnerung_am)
        minuten = max(0, int(vorher.total_seconds() // 60))
        alarm = ("BEGIN:VALARM\r\nACTION:DISPLAY\r\nDESCRIPTION:Rechnung bezahlen\r\n"
                 f"TRIGGER:-PT{minuten}M\r\nEND:VALARM\r\n")

    def esc(s: str) -> str:
        return s.replace("\\", "\\\\").replace(",", "\\,").replace(";", "\\;").replace("\n", "\\n")

    titel = esc(f"Rechnung bezahlen: {r.titel} {euro(r.betrag_cent)}".strip())
    return ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Scan-Trenner//Rechnungen//DE\r\n"
            "BEGIN:VEVENT\r\n"
            f"UID:{r.id}@scan-trenner\r\n"
            f"DTSTAMP:{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}\r\n"
            f"DTSTART;VALUE=DATE:{tag.strftime('%Y%m%d')}\r\n"
            f"DTEND;VALUE=DATE:{(tag + timedelta(days=1)).strftime('%Y%m%d')}\r\n"
            f"SUMMARY:{titel}\r\n"
            f"DESCRIPTION:{esc('Datei: ' + r.datei)}\r\n"
            f"{alarm}END:VEVENT\r\nEND:VCALENDAR\r\n")


def ics_schreiben(r: Rechnung, ordner: Path) -> Path | None:
    text = ics_text(r)
    if text is None:
        return None
    ordner.mkdir(parents=True, exist_ok=True)
    ziel = ordner / f"{Path(r.datei).stem}_faellig_{r.faellig}.ics"
    ziel.write_text(text, encoding="utf-8")
    return ziel

# ------------------------------------------------------ Text aus der PDF

_ocr_hinweis_gezeigt = False


def text_aus_pdf(pfad: Path, max_seiten: int = 3) -> tuple[str, str | None]:
    """Text der ersten Seiten. Hat die PDF keine Textebene, wird – falls
    Tesseract installiert ist – per OCR gelesen. Liefert (text, hinweis)."""
    global _ocr_hinweis_gezeigt
    import pymupdf as fitz

    with fitz.open(str(pfad)) as doc:
        seiten = [doc[i] for i in range(min(max_seiten, doc.page_count))]
        text = "\n".join(s.get_text() for s in seiten)
        if text.strip():
            return text, None
        try:
            text = "\n".join(s.get_textpage_ocr(language="deu", dpi=200, full=True).extractText()
                             for s in seiten)
            return text, None
        except Exception:  # Tesseract fehlt oder Sprachpaket nicht installiert
            if _ocr_hinweis_gezeigt:
                return "", None
            _ocr_hinweis_gezeigt = True
            return "", ("Scan ohne Text – für die Rechnungserkennung bitte im Scanner-Programm "
                        "„durchsuchbare PDF (OCR)“ einstellen oder Tesseract (mit Deutsch) installieren.")


def erfasse(pdf: Path, buch: Rechnungsbuch, e: Rechnungseinstellungen,
            kalender_ordner: Path | None = None) -> tuple[Rechnung | None, str | None]:
    """PDF lesen, als Rechnung erkennen, ins Rechnungsbuch eintragen und für
    offene Rechnungen einen Kalendereintrag anlegen."""
    text, hinweis = text_aus_pdf(pdf)
    r = analysiere(text, str(pdf), e) if text else None
    if r is None:
        return None, hinweis
    buch.hinzufuegen(r)
    if r.offen and kalender_ordner is not None:
        ics_schreiben(r, kalender_ordner)
    return r, hinweis


def kurzbericht(r: Rechnung) -> str:
    teile = [r.status or "Rechnung", euro(r.betrag_cent)]
    if r.faellig and r.offen:
        teile.append(f"fällig {_de(r.faellig)}")
    if r.erstattungen:
        teile.append("einreichen: " + ", ".join(x.stelle for x in r.erstattungen))
    return " · ".join(t for t in teile if t)
