# Lese-Stadt

Flutter-App, die Lesen in den Aufbau einer eigenen Stadt verwandelt: gelesene Seiten eintragen, Material bekommen, Gebäude bauen. Konzept: „Lese-Stadt – App-Konzept“ (Claude Docs).

## Was drin ist

| Bereich | Umsetzung |
| --- | --- |
| Material | Jede Seite: 1 Holz + 1 Genre-Material. Mehrere Genres teilen das Genre-Material auf. |
| Bauen | Grund- (Haus, Straße, Baum, Bäckerei, Wassermühle), Genre- und Kombi-Gebäude im Baumenü, Platz in der Stadt antippen. Abreißen gibt das Material zurück, Verschieben geht auch. |
| Buch-Denkmal | Jedes Buch steht als Geister-Gebäude (Wunschliste), Baustelle (am Lesen) oder Denkmal (beendet) in der Stadt. Antippen zeigt Buch, Datum, Notiz. |
| Buchreihen | Eigenes Viertel östlich der Stadt, ein Bauplatz pro Band, Gerüst für laufende Reihen, Wahrzeichen + Materialbonus (50 Holz und 50 Genre-Material je Band) bei kompletter Reihe. Ab 10 Bänden quadratisch. |
| Stadtstufen | Dorf 10×10 → Kleinstadt 16×16 (2.000 S.) → Stadt 24×24 (10.000 S.) → Metropole 32×32 (30.000 S.). |
| Lebendige Stadt | Seiten der letzten 7 Tage: 1+ ein paar Leute, 80+ Licht in den Fenstern, 250+ Markt und Lichterkette. Tag/Nacht nach Handyzeit. |
| Nahziel | Banner „Noch X Seiten bis zum …“, automatisch passend zum aktuellen Buch oder im Baumenü angeheftet. |
| Jahresprojekt | Jahresziel = Bauabschnitte, Übererfüllung bringt Fahnen, Glocken, Beleuchtung. Bleibt als Denkmal mit Jahreszahl stehen. |
| Stadtchronik | Monatlicher Schnappschuss (Gebäudeliste als JSON), Jahresrückblick, Zeitraffer ab 1. Januar, als Bild teilbar. |
| Buchdaten | ISBN tippen oder scannen (`mobile_scanner`). Daten von Open Library, der Deutschen Nationalbibliothek (vor allem für deutsche Bücher) und Google Books. Das Genre ergibt sich aus den Schlagwörtern aller Quellen plus den Genre-Angaben von Wikidata. Titelsuche ohne ISBN über Open Library. |

## 3D-Stadt

Die Stadtansicht ist eine echte 3D-Szene (three.js in einer WebView, Quelltext in `web3d/src/main.js`, gebündelt nach `assets/city3d/app.js`). Die App liefert die Dateien über einen kleinen Server auf 127.0.0.1 aus und schickt den Stadtzustand als JSON (`lib/ui/city3d.dart`).

- Kamera drehen, neigen und zoomen mit den Fingern
- Sonne und Himmel folgen der Uhrzeit, Schatten wandern mit; nachts Mond, Laternenlicht und – bei viel Leseaktivität – hell erleuchtete Fenster
- Spaziergänger laufen animiert auf Wegen über freie Felder (Wegsuche auf dem Raster), nachts kaum jemand
- Werktags von 7 bis 18 Uhr hämmern Arbeiter an den Baustellen der Bücher, die gerade gelesen werden; vor Bäckerei, Mühle, Rathaus usw. steht jemand bei der Arbeit
- Gebäude sind in Blender gebaute Modelle mit eingebrannten Texturen (`assets/city3d/models/`, 61 Modelle, 13 MB)

Modelle neu erzeugen:

```bash
python tools/city3d/export_models.py /tmp/glb                # Gebäude (bpy)
python tools/city3d/export_mensch.py CesiumMan.glb /tmp/glb  # Figur mit Animationen
python tools/city3d/export_laterne.py Lantern.glb /tmp/glb
cd web3d && npm install && cd ..
sh tools/city3d/optimize.sh /tmp/glb assets/city3d/models   # Texturen verkleinern, Meshopt
cd web3d && npm run build                                   # main.js -> assets/city3d/app.js
```

Fremde Modelle: „Cesium Man“ (Khronos glTF-Sample-Assets, CC BY 4.0, neu eingefärbt, eigene Animationen „stehen“ und „haemmern“) und „Lantern“ (CC0). Die Namensnennung steht in der App unter dem Info-Symbol der Stadt.

## Technik

- Flutter, Datenbank lokal mit Drift (`lib/data/db.dart`, generiert: `db.g.dart`)
- Spiellogik als reine Funktionen in `lib/logic/`, getestet in `test/`
- Stadtansicht mit `CustomPainter` (isometrisch) statt Flame: weniger Abhängigkeiten, Zoomen/Verschieben über `InteractiveViewer`
- Gebäude und Boden sind mit Blender gerenderte 3D-Bilder (`assets/sprites/`, je Gebäude mit Fenstern auch eine Nachtversion mit erleuchteten Fenstern). Bäckerei, Wassermühle, die Baustellen gelesener Bücher und die Dorfbewohner sind gemalte Bilder aus `tools/sprites/vorlage_gemalt.jpg`, freigestellt mit `tools/sprites/cutout.py`. Fehlen die Bilder, wird die Stadt vereinfacht gezeichnet.
- Materialbestand, Stadtstufe, Aktivität und Nahziel werden berechnet, nicht gespeichert

Abweichungen vom Datenmodell im Konzept: `Book` hat zusätzlich `hinzugefuegtAm` und `beendetAm`, `Building` hat `jahr` und `gebautAm` (für Jahresprojekt und Zeitraffer). `Inventory` und `BuildingType` sind keine Tabellen: der Bestand wird berechnet, die Gebäudetypen stehen in `lib/model/catalog.dart`.

## Entwickeln

```bash
flutter pub get
dart run build_runner build   # nach Änderungen an lib/data/db.dart
flutter analyze
flutter test
```

Gebäudebilder neu rendern (braucht Python 3.11 mit `bpy` und `pillow`):

```bash
pip install "bpy==4.2.*" pillow
python tools/sprites/render_sprites.py /tmp/sprites          # alle, oder einzelne Namen anhängen
python tools/sprites/to_webp.py /tmp/sprites assets/sprites
python tools/sprites/cutout.py tools/sprites/vorlage_gemalt.jpg /tmp/gemalt
python tools/sprites/to_webp.py /tmp/gemalt assets/sprites
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
