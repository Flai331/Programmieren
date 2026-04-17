# Rechnungsgenerator Imkerei

Eine moderne Rechnungs-App für Imkereibetriebe mit Flutter Frontend und FastAPI Backend.

## Features

### ✅ MVP (Version 1.0)
- 📝 Rechnungen erstellen mit Kunden & Positionen
- 📄 PDF-Generierung mit ReportLab
- 📤 Teilen über beliebige Apps (WhatsApp, E-Mail, etc.)
- 👥 Kunden-Datenbank mit Historie
- 🏷️ Artikel-Katalog
- 📊 Status-Tracking (Gestellt, Bezahlt, Überfällig, Storniert)
- 📈 Statistiken & Reports
- 🎨 Personalisierte Rechnungsköpfe

### 🔮 Geplant
- 🔄 Wiederkehrende Rechnungen
- 📋 Angebote & Lieferscheine
- 💳 Gutschriften
- 🔔 Automatisches Mahnwesen

## Technologie-Stack

### Backend
- **Framework:** FastAPI (Python)
- **Datenbank:** PostgreSQL
- **PDF:** ReportLab
- **E-Mail:** Gmail API (OAuth2)
- **Hosting:** Hetzner VPS

### Frontend
- **Framework:** Flutter
- **Local Storage:** SQLite (Cache)
- **Share:** Flutter Share Plugin

## Projektstruktur

```
rechnungsgenerator-imkerei/
├── backend/                  # FastAPI Backend
│   ├── app/
│   │   ├── api/             # API Endpunkte
│   │   ├── models/          # Datenbank Modelle
│   │   ├── schemas/         # Pydantic Schemas
│   │   ├── services/        # Business Logic
│   │   └── utils/           # Hilfsfunktionen
│   ├── tests/               # Backend Tests
│   ├── requirements.txt
│   └── main.py
├── frontend/                # Flutter App
│   ├── lib/
│   │   ├── models/          # Datenmodelle
│   │   ├── screens/         # UI Screens
│   │   ├── widgets/         # Wiederverwendbare Widgets
│   │   ├── services/        # API Client
│   │   └── utils/           # Hilfsfunktionen
│   └── pubspec.yaml
└── docs/                    # Dokumentation
    ├── api.md
    ├── deployment.md
    └── user-guide.md
```

## Quick Start

### 1. Backend starten

```bash
cd backend

# Virtual Environment erstellen
python -m venv venv

# Aktivieren (Windows)
venv\Scripts\activate

# Aktivieren (Linux/Mac)
source venv/bin/activate

# Dependencies installieren
pip install -r requirements.txt

# Environment-Datei erstellen
copy .env.example .env  # Windows
cp .env.example .env     # Linux/Mac

# .env bearbeiten und DATABASE_URL + API_SECRET_KEY setzen

# Server starten
python main.py
```

Backend läuft auf http://localhost:8000
API-Docs: http://localhost:8000/docs

### 2. PostgreSQL Datenbank einrichten

```sql
CREATE DATABASE rechnungsgenerator;
CREATE USER rechnungen_user WITH PASSWORD 'sicheres_passwort';
GRANT ALL PRIVILEGES ON DATABASE rechnungsgenerator TO rechnungen_user;
```

### 3. Frontend starten

```bash
cd frontend

# Dependencies installieren
npm install

# Development Server starten
npm run dev
```

Frontend läuft auf http://localhost:3000

## Deployment

Siehe [docs/deployment.md](docs/deployment.md) für detaillierte Anleitung.

## Lizenz

Private Nutzung für Imkereibetrieb
