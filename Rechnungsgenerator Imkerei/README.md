# Rechnungsgenerator Imkerei

Professionelle Rechnungsverwaltung für Imkereien.

## Projektstruktur

```
├── WebApp/          Browser-Version (standalone, ohne Backend)
├── DesktopApp/      Windows Desktop-Anwendung (Electron)
├── Backend/         FastAPI Server (Python)
├── MobileApp/       Android/iOS App (in Planung)
└── _archiv/         Alte Entwicklungsversionen
```

## Schnellstart

### Web-App (ohne Installation)
1. Öffne `WebApp/RECHNUNGSGENERATOR.html` im Browser
2. Fertig - funktioniert komplett offline

### Desktop-App (mit Datenbank)
1. Starte Backend: `Backend/start_backend.bat`
2. Starte Desktop-App: `DesktopApp/start_app.bat`

## Funktionen

- Rechnungen erstellen mit Live-Vorschau
- PDF-Export im DIN A4 Format
- Kundenverwaltung
- Artikelkatalog
- Rechnungsarchiv
- E-Mail-Versand mit PDF-Anhang
- Statistiken & Auswertungen
- Automatische Backups
- Mobile & Desktop optimiert

## Technologien

| Komponente | Technologie |
|------------|-------------|
| Web-App | HTML, CSS, JavaScript |
| Desktop-App | Electron |
| Backend | Python, FastAPI |
| Datenbank | PostgreSQL / SQLite |
| Mobile-App | (geplant) |

## Lizenz

Privates Projekt
