# Setup-Anleitung

Diese Anleitung erklärt, wie Sie den Rechnungsgenerator auf Ihrem lokalen System und später auf einem Hetzner VPS einrichten.

## Voraussetzungen

### Lokal
- Python 3.10 oder höher
- Node.js 18 oder höher
- PostgreSQL 14 oder höher
- Git

### Für Deployment
- Hetzner VPS (empfohlen: CX21 für 4-5€/Monat)
- Domain (optional)

## Lokale Installation

### 1. Repository klonen

```bash
cd "C:\Users\klaas\Desktop\Programmieren\Rechnungsgenerator Imkerei"
```

### 2. Backend Setup

```bash
cd backend

# Virtuelle Umgebung erstellen
python -m venv venv

# Aktivieren
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Dependencies installieren
pip install -r requirements.txt

# Environment-Datei erstellen
copy .env.example .env

# .env bearbeiten und folgende Werte anpassen:
# - DATABASE_URL
# - API_SECRET_KEY (generieren mit: openssl rand -hex 32)
```

### 3. PostgreSQL Datenbank einrichten

```sql
-- PostgreSQL öffnen
psql -U postgres

-- Datenbank erstellen
CREATE DATABASE rechnungsgenerator;

-- Benutzer erstellen (optional)
CREATE USER rechnungen_user WITH PASSWORD 'sicheres_passwort';
GRANT ALL PRIVILEGES ON DATABASE rechnungsgenerator TO rechnungen_user;
```

### 4. Datenbank migrieren

```bash
# Im backend Verzeichnis
python -c "from app.database import engine, Base; from app.models import *; Base.metadata.create_all(bind=engine)"
```

### 5. Backend starten

```bash
# Im backend Verzeichnis
python main.py

# Oder mit Uvicorn direkt:
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Backend läuft nun auf http://localhost:8000
API-Dokumentation: http://localhost:8000/docs

### 6. Frontend Setup

Neues Terminal öffnen:

```bash
cd frontend

# Dependencies installieren
npm install

# Development Server starten
npm run dev
```

Frontend läuft nun auf http://localhost:3000

## Erste Schritte

### 1. PDF-Vorlage erstellen

1. Öffnen Sie http://localhost:3000/templates
2. Klicken Sie auf "Neue Vorlage"
3. Geben Sie Ihre Firmendaten ein:
   - Name
   - Adresse
   - Steuernummer
   - Bankverbindung
4. Laden Sie ein PDF-Design hoch (optional)
5. Speichern und als Standard festlegen

### 2. Ersten Kunden anlegen

1. Öffnen Sie http://localhost:3000/customers
2. Klicken Sie auf "Neuer Kunde"
3. Geben Sie Kundendaten ein
4. Speichern

### 3. Artikel anlegen

1. Öffnen Sie http://localhost:3000/articles
2. Klicken Sie auf "Neuer Artikel"
3. Fügen Sie Ihre Produkte hinzu (z.B. verschiedene Honigsorten)
4. Speichern

### 4. Erste Rechnung erstellen

1. Öffnen Sie http://localhost:3000/invoices/new
2. Wählen Sie einen Kunden
3. Fügen Sie Positionen hinzu
4. Klicken Sie auf "Erstellen"
5. PDF herunterladen und teilen

## Troubleshooting

### Backend startet nicht

- Prüfen Sie, ob PostgreSQL läuft
- Überprüfen Sie die DATABASE_URL in der .env
- Stellen Sie sicher, dass Port 8000 frei ist

### Frontend startet nicht

- Prüfen Sie, ob Node.js installiert ist
- Löschen Sie node_modules und führen Sie `npm install` erneut aus
- Stellen Sie sicher, dass Port 3000 frei ist

### Datenbank-Verbindungsfehler

```
# .env Beispiel für lokale PostgreSQL:
DATABASE_URL=postgresql://postgres:passwort@localhost:5432/rechnungsgenerator
```

### PDF-Generierung schlägt fehl

- Stellen Sie sicher, dass ReportLab installiert ist
- Überprüfen Sie die Verzeichnisse uploads/, pdfs/, logos/
- Prüfen Sie Schreibrechte

## Nächste Schritte

Siehe [deployment.md](./deployment.md) für Deployment auf Hetzner VPS.
