#!/usr/bin/env python3
"""Erzeugt die Einbau-Anleitung als PDF (für andere Claude-Sitzungen)."""

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    HRFlowable,
    ListFlowable,
    ListItem,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

from pathlib import Path

ZIEL = str(Path(__file__).resolve().parent.parent / "Fehlermelde-Modul-einbauen.pdf")

AKZENT = colors.HexColor("#B44A1E")
GRAU = colors.HexColor("#555555")
CODE_BG = colors.HexColor("#F4F2EE")
CODE_RAHMEN = colors.HexColor("#DDD8D0")

s = getSampleStyleSheet()

titel = ParagraphStyle("titel", parent=s["Title"], fontName="Helvetica-Bold",
                       fontSize=21, leading=25, textColor=AKZENT, alignment=TA_LEFT,
                       spaceAfter=2)
untertitel = ParagraphStyle("untertitel", parent=s["Normal"], fontSize=10.5,
                            leading=14, textColor=GRAU, spaceAfter=14)
h1 = ParagraphStyle("h1", parent=s["Heading1"], fontName="Helvetica-Bold",
                    fontSize=13.5, leading=17, textColor=AKZENT,
                    spaceBefore=16, spaceAfter=6, keepWithNext=1)
h2 = ParagraphStyle("h2", parent=s["Heading2"], fontName="Helvetica-Bold",
                    fontSize=11, leading=14, textColor=colors.black,
                    spaceBefore=11, spaceAfter=4, keepWithNext=1)
text = ParagraphStyle("text", parent=s["Normal"], fontSize=10, leading=14.5,
                      spaceAfter=7)
klein = ParagraphStyle("klein", parent=text, fontSize=9, leading=12.5,
                       textColor=GRAU)
code = ParagraphStyle("code", parent=s["Code"], fontName="Courier", fontSize=8.4,
                      leading=11.5, textColor=colors.HexColor("#1A1A1A"),
                      leftIndent=0, spaceAfter=0, spaceBefore=0)


def codeblock(zeilen):
    """Codeblock mit hellem Hintergrund; hält als Einheit zusammen."""
    inhalt = [Paragraph(z.replace("&", "&amp;").replace("<", "&lt;") or "&nbsp;", code)
              for z in zeilen]
    t = Table([[inhalt]], colWidths=[165 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), CODE_BG),
        ("BOX", (0, 0), (-1, -1), 0.6, CODE_RAHMEN),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return [t, Spacer(1, 9)]


def punkte(eintraege):
    return ListFlowable(
        [ListItem(Paragraph(e, text), leftIndent=12) for e in eintraege],
        bulletType="bullet", bulletFontSize=7, leftIndent=14, bulletOffsetY=-1,
        spaceAfter=6,
    )


def tabelle(kopf, zeilen, breiten):
    daten = [[Paragraph(f"<b>{k}</b>", klein) for k in kopf]]
    daten += [[Paragraph(z, klein) for z in zeile] for zeile in zeilen]
    t = Table(daten, colWidths=breiten, repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#EFEAE3")),
        ("LINEBELOW", (0, 0), (-1, 0), 0.7, CODE_RAHMEN),
        ("LINEBELOW", (0, 1), (-1, -2), 0.3, colors.HexColor("#E8E4DE")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    return [t, Spacer(1, 10)]


def fusszeile(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(GRAU)
    canvas.drawString(22 * mm, 12 * mm,
                      "Fehlermelde-Modul  -  Flai331/Programmieren, shared/fehlerbericht")
    canvas.drawRightString(188 * mm, 12 * mm, f"Seite {doc.page}")
    canvas.restoreState()


d = []

d += [Paragraph("Fehlermelde-Modul einbauen", titel)]
d += [Paragraph("Anleitung für eine Claude-Sitzung, die eine Flutter-App um "
                "Fehlerberichte erweitern soll", untertitel)]
d += [HRFlowable(width="100%", thickness=0.8, color=CODE_RAHMEN,
                 spaceBefore=0, spaceAfter=12)]

d += [Paragraph("Worum es geht", h1)]
d += [Paragraph(
    "Das Modul ist eine einzige Dart-Datei. Eingebaut blendet es auf jedem "
    "Bildschirm einen kleinen Fehler-Button ein, fängt Abstürze selbsttätig "
    "ab und legt jeden Bericht samt Protokoll und Bildschirmfoto in Notion ab. "
    "Es braucht nur zwei Pakete: <b>http</b> und <b>url_launcher</b>.", text)]
d += [Paragraph(
    "In Notion ist nichts vorzubereiten. Beim ersten Bericht sucht sich die App "
    "über ihren App-Key in der Registry <b>Apps</b> unter der Seite "
    "<b>Fehlerzentrale</b>. Findet sie sich dort nicht, legt sie sich selbst eine "
    "Unterseite mit eigener Datenbank an und trägt sich ein.", text)]

d += [Paragraph("Schritt 1 - Dateien holen", h1)]
d += [Paragraph(
    "Liegt das Repo <b>Flai331/Programmieren</b> vor, sind die Dateien schon da, "
    "unter <font face='Courier'>shared/fehlerbericht/</font>. Andernfalls "
    "herunterladen - das Repo ist öffentlich lesbar:", text)]
d += codeblock([
    "REPO=https://raw.githubusercontent.com/Flai331/Programmieren",
    "ZWEIG=claude/fehlerberichte-programm-cleanup-1cvy8n",
    "BASE=$REPO/$ZWEIG/shared/fehlerbericht",
    "",
    "curl -sSO $BASE/tools/einbauen.py",
    "curl -sSO $BASE/tools/app_pruefen.py",
    "mkdir -p lib",
    "curl -sS -o lib/fehlerbericht.dart $BASE/lib/fehlerbericht.dart",
])
d += [Paragraph(
    "Wichtig ist die Ablage: <font face='Courier'>einbauen.py</font> sucht die "
    "Moduldatei relativ zu sich selbst unter "
    "<font face='Courier'>../lib/fehlerbericht.dart</font>. Die Befehle oben "
    "legen genau diese Struktur an.", klein)]

d += [Paragraph("Schritt 2 - Einbauen", h1)]
d += [Paragraph("Ein Befehl erledigt alles Mechanische:", text)]
d += codeblock([
    'python3 einbauen.py <app-ordner> --key <schluessel> --name "<App-Name>"',
])
d += [Paragraph("Das Skript", h2)]
d += [punkte([
    "kopiert <font face='Courier'>lib/fehlerbericht.dart</font> in die App,",
    "trägt <font face='Courier'>http</font> und "
    "<font face='Courier'>url_launcher</font> in die "
    "<font face='Courier'>pubspec.yaml</font> ein,",
    "setzt die INTERNET-Berechtigung ins Android-Manifest,",
    "verdrahtet <font face='Courier'>lib/main.dart</font>: Import, "
    "<font face='Courier'>Fehlerbericht.runApp</font> und die drei Parameter "
    "an der <font face='Courier'>MaterialApp</font>.",
])]
d += [Paragraph(
    "Es ist gefahrlos wiederholbar und legt vor jeder Änderung eine "
    "<font face='Courier'>.bak</font>-Kopie an. Zeilen, die es mit "
    "<b>!</b> ausweist, brauchen Handarbeit - dort steht jeweils, was zu tun ist.",
    text)]

d += [Paragraph("Schritt 3 - Prüfen", h1)]
d += codeblock([
    "flutter pub get",
    "python3 app_pruefen.py <app-ordner>",
    "flutter analyze",
])
d += [Paragraph(
    "Das Prüfskript muss mit Rückgabewert <b>0</b> enden und "
    "<font face='Courier'>flutter analyze</font> ohne Befund durchlaufen. "
    "Erst dann ist der Einbau fertig.", text)]

d += [Paragraph("Schritt 4 - Bauen", h1)]
d += [Paragraph(
    "Das Notion-Token wird beim Bauen gesetzt, niemals in den Quellcode "
    "geschrieben. Ein Token gilt für alle Apps.", text)]
d += codeblock([
    "flutter build apk --release --dart-define=NOTION_TOKEN=<token>",
])
d += [Paragraph(
    "Wer das Token nicht hat, baut einfach ohne. Die App läuft dann völlig "
    "normal und öffnet für Berichte die E-Mail-App statt Notion. Das Token "
    "gehört dem Besitzer des Notion-Bereichs und muss nicht in der "
    "einbauenden Sitzung bekannt sein.", text)]

d += [Paragraph("Falls der Einbau von Hand nötig ist", h1)]
d += [Paragraph("Es sind genau vier Dinge.", text)]

d += [Paragraph("1. Moduldatei", h2)]
d += [Paragraph("<font face='Courier'>fehlerbericht.dart</font> unverändert "
                "nach <font face='Courier'>lib/</font> der App kopieren.", text)]

d += [Paragraph("2. pubspec.yaml", h2)]
d += codeblock([
    "dependencies:",
    "  http: ^1.2.0",
    "  url_launcher: ^6.2.5",
])

d += [Paragraph("3. Android-Manifest", h2)]
d += [Paragraph("In <font face='Courier'>android/app/src/main/"
                "AndroidManifest.xml</font> direkt unter "
                "<font face='Courier'>&lt;manifest ...&gt;</font>:", text)]
d += codeblock([
    '<uses-permission android:name="android.permission.INTERNET"/>',
])
d += [Paragraph(
    "<b>Nicht überspringen</b>, auch wenn die Zeile schon in "
    "<font face='Courier'>src/debug/</font> steht: Release-Builds erben sie von "
    "dort nicht. Ohne sie scheitert jeder Notion-Aufruf mit "
    "<font face='Courier'>Failed host lookup ... errno = 7</font>, und die App "
    "weicht still auf E-Mail aus. Das ist die häufigste Stolperfalle "
    "überhaupt, weil im Debug-Betrieb alles zu funktionieren scheint.", text)]

d += [Paragraph("4. main.dart", h2)]
d += codeblock([
    "import 'fehlerbericht.dart';",
    "",
    "void main() => Fehlerbericht.runApp(",
    "      appKey: 'meine_app',",
    "      appName: 'Meine App',",
    "      version: '1.0.0',",
    "      builder: () => const MyApp(),",
    "    );",
])
d += [Paragraph("und an der <font face='Courier'>MaterialApp</font>:", text)]
d += codeblock([
    "MaterialApp(",
    "  navigatorKey: Fehlerbericht.navigatorKey,",
    "  navigatorObservers: [Fehlerbericht.observer],",
    "  builder: Fehlerbericht.wrap,",
    "  // alles Übrige unverändert",
    ")",
])

d += [Paragraph("Regeln, die nicht verhandelbar sind", h1)]
d += tabelle(
    ["Regel", "Warum"],
    [
        ["Der <b>App-Key</b> ist klein geschrieben, ohne Leerzeichen, und "
         "ändert sich nie mehr.",
         "Er ist der Schlüssel in der Notion-Registry. Wird er geändert, "
         "legt die App eine zweite Datenbank an und die bisherigen Berichte "
         "sind abgehängt."],
        ["Das <b>Token</b> steht nie im Quellcode, nur in "
         "<font face='Courier'>--dart-define</font>.",
         "Sonst landet es im Repo und in jeder ausgelieferten App."],
        ["Die <b>Moduldatei</b> wird nicht angepasst.",
         "Sie ist in allen Apps identisch. Wer sie ändert, verliert künftige "
         "Verbesserungen; das Prüfskript meldet Abweichungen."],
        ["Auf <b>Web</b> ist der E-Mail-Weg das erwartete Verhalten.",
         "Notion beantwortet keine Anfragen aus dem Browser (CORS). Das Modul "
         "erkennt das und wechselt selbsttätig."],
    ],
    [62 * mm, 103 * mm],
)

d += [Paragraph("Wenn kein Bericht in Notion ankommt", h1)]
d += [Paragraph(
    "Das Protokoll nennt die Ursache im Klartext - es steht im geöffneten "
    "E-Mail-Entwurf und in der Debug-Ausgabe:", text)]
d += tabelle(
    ["Meldung im Protokoll", "Ursache"],
    [
        ["Kein NOTION_TOKEN gesetzt",
         "Beim Bauen fehlte <font face='Courier'>--dart-define</font>."],
        ["Failed host lookup ... errno = 7",
         "INTERNET-Berechtigung fehlt im main-Manifest (siehe Punkt 3)."],
        ["Registry-Abfrage HTTP 401",
         "Token falsch oder abgelaufen."],
        ["HTTP 404",
         "Die Integration hat keinen Zugriff auf die Fehlerzentrale. Der "
         "Besitzer teilt die Seite einmalig über "
         "<font face='Courier'>... -&gt; Verbindungen</font>."],
        ["CORS-Blockade / Web nicht erreichbar",
         "Erwartet im Browser, siehe oben."],
    ],
    [62 * mm, 103 * mm],
)

d += [Paragraph("Fertig ist der Einbau, wenn", h1)]
d += [punkte([
    "<font face='Courier'>app_pruefen.py</font> mit Rückgabewert 0 endet,",
    "<font face='Courier'>flutter analyze</font> keinen Befund meldet,",
    "die App startet und unten rechts der Fehler-Button sichtbar ist,",
    "ein abgeschickter Testbericht in Notion unter der Fehlerzentrale auftaucht "
    "(nur mit Token prüfbar).",
])]
d += [Spacer(1, 6)]
d += [Paragraph(
    "Ausführliche Fassung samt vollständiger API: "
    "<font face='Courier'>shared/fehlerbericht/README.md</font> und "
    "<font face='Courier'>EINBAU.md</font> im selben Ordner.", klein)]

doc = SimpleDocTemplate(
    ZIEL, pagesize=A4,
    leftMargin=22 * mm, rightMargin=22 * mm,
    topMargin=20 * mm, bottomMargin=20 * mm,
    title="Fehlermelde-Modul einbauen",
    author="Fehlerzentrale",
    subject="Einbau-Anleitung für Flutter-Apps",
)
doc.build(d, onFirstPage=fusszeile, onLaterPages=fusszeile)
print(f"geschrieben: {ZIEL}")
