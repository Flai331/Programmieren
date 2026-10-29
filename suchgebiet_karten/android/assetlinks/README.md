# Links direkt in der App öffnen (Android App Links)

Android öffnet `https://flai331.github.io/Programmieren/suchgebiet-karten/#a=…` nur dann direkt in der App,
wenn unter `https://flai331.github.io/.well-known/assetlinks.json` diese Datei liegt. Sie muss im
öffentlichen Repo **Flai331.github.io** (GitHub-Pages-Startseite) liegen, zusammen mit der leeren Datei
`.nojekyll` (sonst veröffentlicht GitHub Pages den Ordner `.well-known` nicht).

Der Fingerabdruck ist der SHA-256 des Release-Schlüssels der APK (`merker-release.p12`).
Nach dem Einrichten die APK einmal neu installieren bzw. aktualisieren – Android prüft die Datei bei der Installation.
