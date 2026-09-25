# Parkplatz-Merker Android – Hinweise für Claude

- Plan und Aufbau: `PLAN.md` (+ `PLAN_APPSTART.md`, `PLAN_BEENDEN.md`, `PLAN_WIDGET.md`).
- Arbeitsweise des Nutzers: Planer plant und prüft (Kotlin Zeile für Zeile), ein Haiku-Agent programmiert;
  PRs nach `main` selbst mergen.
- **Jede neue Funktion bekommt ihre Anleitung auch in der App** (`lib/pages/help_page.dart`,
  Abschnitt + ggf. `HelpTopic`, Verlinkung aus den Einstellungen) und kurz im README.
- Texte Deutsch, Anrede „du“. In Kotlin/XML nur gerade ASCII-Anführungszeichen als Begrenzer.
- Kein Android-SDK im Container: Kotlin kompiliert erst GitHub Actions (`parkplatz-merker-apk.yml`).
