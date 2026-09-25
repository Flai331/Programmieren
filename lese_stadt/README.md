# Lese-Stadt

Flutter-App, die Lesen in den Aufbau einer eigenen Stadt verwandelt: gelesene Seiten eintragen, Material bekommen, Gebäude bauen. Konzept: „Lese-Stadt – App-Konzept“ (Claude Docs).

## Was drin ist

| Bereich | Umsetzung |
| --- | --- |
| Material | Jede Seite: 1 Holz + 1 Genre-Material. Mehrere Genres teilen das Genre-Material auf. |
| Bauen | Grund-, Genre- und Kombi-Gebäude im Baumenü, Platz in der Stadt antippen. Abreißen gibt das Material zurück, Verschieben geht auch. |
| Buch-Denkmal | Jedes Buch steht als Geister-Gebäude (Wunschliste), Baustelle (am Lesen) oder Denkmal (beendet) in der Stadt. Antippen zeigt Buch, Datum, Notiz. |
| Buchreihen | Eigenes Viertel östlich der Stadt, ein Bauplatz pro Band, Gerüst für laufende Reihen, Wahrzeichen + Materialbonus (50 Holz und 50 Genre-Material je Band) bei kompletter Reihe. Ab 10 Bänden quadratisch. |
| Stadtstufen | Dorf 10×10 → Kleinstadt 16×16 (2.000 S.) → Stadt 24×24 (10.000 S.) → Metropole 32×32 (30.000 S.). |
| Lebendige Stadt | Seiten der letzten 7 Tage: 1+ ein paar Leute, 80+ Licht in den Fenstern, 250+ Markt und Lichterkette. Tag/Nacht nach Handyzeit. |
| Nahziel | Banner „Noch X Seiten bis zum …“, automatisch passend zum aktuellen Buch oder im Baumenü angeheftet. |
| Jahresprojekt | Jahresziel = Bauabschnitte, Übererfüllung bringt Fahnen, Glocken, Beleuchtung. Bleibt als Denkmal mit Jahreszahl stehen. |
| Stadtchronik | Monatlicher Schnappschuss (Gebäudeliste als JSON), Jahresrückblick, Zeitraffer ab 1. Januar, als Bild teilbar. |
| Buchdaten | ISBN tippen oder scannen (`mobile_scanner`). Daten von Open Library, der Deutschen Nationalbibliothek (vor allem für deutsche Bücher) und Google Books. Das Genre ergibt sich aus den Schlagwörtern aller Quellen plus den Genre-Angaben von Wikidata. Titelsuche ohne ISBN über Open Library. |

## Technik

- Flutter, Datenbank lokal mit Drift (`lib/data/db.dart`, generiert: `db.g.dart`)
- Spiellogik als reine Funktionen in `lib/logic/`, getestet in `test/`
- Stadtansicht mit `CustomPainter` (isometrisch) statt Flame: weniger Abhängigkeiten, Zoomen/Verschieben über `InteractiveViewer`
- Materialbestand, Stadtstufe, Aktivität und Nahziel werden berechnet, nicht gespeichert

Abweichungen vom Datenmodell im Konzept: `Book` hat zusätzlich `hinzugefuegtAm` und `beendetAm`, `Building` hat `jahr` und `gebautAm` (für Jahresprojekt und Zeitraffer). `Inventory` und `BuildingType` sind keine Tabellen: der Bestand wird berechnet, die Gebäudetypen stehen in `lib/model/catalog.dart`.

## Entwickeln

```bash
flutter pub get
dart run build_runner build   # nach Änderungen an lib/data/db.dart
flutter analyze
flutter test
```

Die APK baut der Workflow `.github/workflows/lese-stadt-apk.yml` und hängt sie als Artifact an den Lauf.

## Signaturschlüssel

Damit sich jede neue APK als Update installieren lässt (ohne Deinstallieren, also ohne Datenverlust), braucht es einen festen Schlüssel. Einmalig anlegen, auf einem Rechner mit Java (`keytool` gehört zu jedem JDK und zu Android Studio):

```bash
keytool -genkeypair -storetype pkcs12 \
  -keystore lese_stadt/android/app/lese-stadt-release.p12 \
  -alias lesestadt -keyalg RSA -keysize 4096 -validity 36500 \
  -dname "CN=Lese-Stadt"
```

`keytool` fragt nach einem Passwort. Dann:

1. Die Datei `lese-stadt-release.p12` committen und pushen (sie ist passwortgeschützt).
2. Auf GitHub unter Settings → Secrets and variables → Actions das Secret `LESE_STADT_KEYSTORE_PASSWORD` mit genau diesem Passwort anlegen.

Ab dem nächsten Build ist die APK mit diesem Schlüssel signiert. Fehlt Datei oder Secret, signiert der Build mit einem Test-Schlüssel, der sich bei jedem Lauf ändert. Schlüssel und Passwort nicht verlieren: ohne sie lässt sich keine Update-APK mehr bauen.
