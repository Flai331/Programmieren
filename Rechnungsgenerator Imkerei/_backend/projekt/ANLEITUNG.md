# 📖 Komplette Anleitung - Rechnungsgenerator Imkerei

## 🚀 Schnellstart (3 Schritte)

### Schritt 1: Voraussetzungen installieren

Bevor Sie den INSTALLER.bat ausführen, benötigen Sie:

#### Python 3.10 oder höher
1. Gehen Sie zu https://www.python.org/downloads/
2. Laden Sie die neueste Version herunter
3. **WICHTIG**: Aktivieren Sie bei der Installation "Add Python to PATH"
4. Installieren Sie Python

Prüfen: Öffnen Sie CMD und tippen Sie `python --version`

#### Node.js 18 oder höher
1. Gehen Sie zu https://nodejs.org/
2. Laden Sie die LTS-Version herunter
3. Installieren Sie Node.js mit Standardeinstellungen

Prüfen: Öffnen Sie CMD und tippen Sie `node --version`

#### PostgreSQL 14 oder höher
1. Gehen Sie zu https://www.postgresql.org/download/windows/
2. Laden Sie den Installer herunter
3. Installieren Sie PostgreSQL
4. **Merken Sie sich das Passwort für den postgres-User!**
5. Port: 5432 (Standard)

Prüfen: Öffnen Sie CMD und tippen Sie `psql --version`

### Schritt 2: Installation ausführen

1. Doppelklick auf **INSTALLER.bat** (im Hauptordner)
2. Das Script prüft automatisch alle Voraussetzungen
3. Installiert alle benötigten Pakete
4. Organisiert die Projektstruktur
5. Erstellt Start-Scripts

### Schritt 3: Datenbank einrichten

#### Option A: Mit pgAdmin (grafische Oberfläche)
1. Öffnen Sie pgAdmin (wurde mit PostgreSQL installiert)
2. Verbinden Sie sich mit dem Server (postgres-Passwort eingeben)
3. Rechtsklick auf "Databases" → "Create" → "Database..."
4. Name: `rechnungsgenerator`
5. Klicken Sie "Save"

#### Option B: Mit Kommandozeile
```bash
# CMD öffnen
psql -U postgres

# In psql eingeben:
CREATE DATABASE rechnungsgenerator;

# Optional: Separaten User erstellen
CREATE USER rechnungen_user WITH PASSWORD 'sicheres_passwort';
GRANT ALL PRIVILEGES ON DATABASE rechnungsgenerator TO rechnungen_user;

# Beenden mit:
\q
```

### Schritt 4: Backend konfigurieren

1. Öffnen Sie die Datei: `backend\.env` mit einem Texteditor
2. Ändern Sie folgende Zeilen:

```env
# Wenn Sie den postgres-User verwenden:
DATABASE_URL=postgresql://postgres:IHR_POSTGRES_PASSWORT@localhost:5432/rechnungsgenerator

# Wenn Sie einen separaten User erstellt haben:
DATABASE_URL=postgresql://rechnungen_user:sicheres_passwort@localhost:5432/rechnungsgenerator

# API Secret Key generieren
```

3. API Secret Key generieren:
   - Öffnen Sie CMD
   - Navigieren Sie zu: `cd backend`
   - Aktivieren Sie die Virtual Environment: `venv\Scripts\activate`
   - Führen Sie aus: `python -c "import secrets; print(secrets.token_hex(32))"`
   - Kopieren Sie den generierten Key
   - Fügen Sie ihn in .env ein: `API_SECRET_KEY=HIER_DER_GENERIERTE_KEY`

### Schritt 5: Anwendung starten

#### Beide gleichzeitig starten (empfohlen)
Doppelklick auf **START_ALLES.bat** im Hauptordner

#### Einzeln starten
- Backend: Doppelklick auf **START_BACKEND.bat**
- Frontend: Doppelklick auf **START_FRONTEND.bat**

### Schritt 6: Anwendung öffnen

Öffnen Sie Ihren Browser und gehen Sie zu:
- **Web-App**: http://localhost:3000
- **API Dokumentation**: http://localhost:8000/docs

---

## 📱 Erste Schritte in der Anwendung

### 1. PDF-Vorlage erstellen (Optional aber empfohlen)

1. Öffnen Sie http://localhost:3000/templates
2. Klicken Sie auf "Neue Vorlage"
3. Füllen Sie Ihre Firmendaten aus:
   ```
   Name: Ihre Imkerei
   Firma: Imkerei Mustermann
   E-Mail: info@ihre-imkerei.de
   Telefon: +49 123 456789
   Straße: Bienenweg 1
   PLZ: 12345
   Stadt: Honigstadt
   Steuernummer: 12/345/67890
   Bank: Ihre Bank
   IBAN: DE89370400440532013000
   ```
4. PDF-Design hochladen (optional):
   - Erstellen Sie ein PDF mit Ihrem Logo und Design
   - Laden Sie es hoch
   - Das PDF wird als Hintergrund für Rechnungen verwendet
5. Als Standard-Vorlage markieren
6. Speichern

### 2. Kunden anlegen

1. Öffnen Sie http://localhost:3000/customers
2. Klicken Sie auf "Neuer Kunde"
3. Geben Sie Kundendaten ein:
   ```
   Name: Max Mustermann
   Firma: Bäckerei Müller (optional)
   E-Mail: max@example.com
   Telefon: +49 987 654321
   Straße: Hauptstraße 10
   PLZ: 54321
   Stadt: Kundenstadt
   ```
4. Speichern

### 3. Artikel anlegen

1. Öffnen Sie http://localhost:3000/articles
2. Klicken Sie auf "Neuer Artikel"
3. Fügen Sie Ihre Produkte hinzu:
   ```
   Name: Waldhonig
   Beschreibung: Feiner Waldhonig aus regionaler Produktion
   Artikelnummer: HON-001
   Preis: 8.50
   Einheit: Glas (500g)
   Kategorie: Honig
   Bestand: 50
   ```
4. Wiederholen Sie für alle Ihre Produkte
5. Speichern

### 4. Erste Rechnung erstellen

1. Öffnen Sie http://localhost:3000/invoices/new
2. Wählen Sie einen Kunden aus der Liste
3. Fügen Sie Positionen hinzu:
   - Wählen Sie Artikel aus dem Katalog ODER
   - Geben Sie manuell ein
4. Die Berechnung erfolgt automatisch:
   - Netto
   - MwSt. (19%)
   - Brutto
5. Setzen Sie das Zahlungsziel (z.B. 14 Tage)
6. Fügen Sie optional Notizen hinzu
7. Klicken Sie auf "Rechnung erstellen"
8. PDF herunterladen
9. Teilen Sie das PDF über WhatsApp, E-Mail, etc.

---

## 🔧 Problemlösung

### Backend startet nicht

**Problem**: "ModuleNotFoundError" oder ähnliche Fehler

**Lösung**:
```bash
cd backend
venv\Scripts\activate
pip install -r requirements.txt
```

**Problem**: "Database connection failed"

**Lösung**:
1. Prüfen Sie, ob PostgreSQL läuft
2. Überprüfen Sie die DATABASE_URL in backend\.env
3. Testen Sie die Verbindung: `psql -U postgres`

### Frontend startet nicht

**Problem**: "Cannot find module" oder Fehler beim Start

**Lösung**:
```bash
cd frontend
del /s /q node_modules
npm install
npm run dev
```

**Problem**: Port 3000 bereits belegt

**Lösung**: Ein anderes Programm nutzt Port 3000
- Schließen Sie andere Programme
- Oder ändern Sie den Port in frontend\vite.config.js

### Datenbank-Probleme

**Problem**: "Database does not exist"

**Lösung**: Datenbank wurde nicht erstellt
```sql
psql -U postgres
CREATE DATABASE rechnungsgenerator;
\q
```

**Problem**: "Authentication failed"

**Lösung**: Falsches Passwort in .env
- Überprüfen Sie DATABASE_URL in backend\.env
- Format: `postgresql://USER:PASSWORT@localhost:5432/rechnungsgenerator`

### PDF-Generierung funktioniert nicht

**Problem**: Fehler beim PDF-Download

**Lösung**:
1. Prüfen Sie, ob die Ordner existieren:
   - backend\pdfs
   - backend\uploads
   - backend\logos
2. Falls nicht, erstellen Sie sie manuell
3. Stellen Sie sicher, dass Schreibrechte vorhanden sind

---

## 📊 Features im Detail

### Rechnungsverwaltung
- ✅ Automatische Rechnungsnummern (RE-1000, RE-1001, ...)
- ✅ Status-Tracking (Entwurf, Versendet, Bezahlt, Überfällig, Storniert)
- ✅ Zahlungsziele setzen
- ✅ Notizen für interne Verwendung
- ✅ Notizen die auf der Rechnung erscheinen

### Kundenverwaltung
- ✅ Vollständige Kontaktdaten
- ✅ Rechnungshistorie pro Kunde
- ✅ Suchfunktion
- ✅ Firmen und Privatkunden

### Artikel-Katalog
- ✅ Artikel mit Preisen speichern
- ✅ Kategorien (Honig, Bienenwachs, Propolis, etc.)
- ✅ Lagerbestand-Tracking
- ✅ Schnellauswahl bei Rechnungserstellung

### PDF-Vorlagen
- ✅ Eigenes PDF-Design hochladen
- ✅ Mehrere Vorlagen für verschiedene Geschäftsbereiche
- ✅ Logo-Upload
- ✅ Anpassbare Positionen auf der Rechnung

### Statistiken
- ✅ Gesamtumsatz
- ✅ Offene Posten
- ✅ Durchschnittliche Zahlungsdauer
- ✅ Monatliche Umsatz-Übersicht
- ✅ Top-Kunden nach Umsatz
- ✅ Überfällige Rechnungen

---

## 🌐 Deployment auf Server (Optional)

Wenn Sie die Anwendung auf einem Server hosten möchten (von überall erreichbar):

1. Siehe detaillierte Anleitung: `docs\deployment.md`
2. Empfohlener Anbieter: Hetzner VPS
3. Kosten: ca. 4-5€/Monat
4. Inklusive SSL-Zertifikat (kostenlos mit Let's Encrypt)

---

## 💡 Tipps & Tricks

### Effiziente Arbeitsweise
1. Legen Sie häufig verwendete Artikel im Katalog an
2. Nutzen Sie Kategorien zur Organisation
3. Erstellen Sie Vorlagen für verschiedene Kundengruppen
4. Verwenden Sie die Suchfunktion bei vielen Kunden

### Rechnungen schneller erstellen
1. Nutzen Sie die Artikel-Schnellauswahl
2. Kopieren Sie ähnliche Rechnungen (Feature geplant)
3. Speichern Sie häufige Notizen als Textbausteine

### Finanzübersicht behalten
1. Markieren Sie bezahlte Rechnungen zeitnah
2. Prüfen Sie regelmäßig überfällige Rechnungen
3. Nutzen Sie die Statistik-Seite
4. Exportieren Sie Daten für Ihren Steuerberater

### Backup nicht vergessen!
Die Datenbank enthält alle Ihre Daten. Erstellen Sie regelmäßig Backups:
```bash
pg_dump -U postgres rechnungsgenerator > backup_2024_01_12.sql
```

---

## 📞 Support & Weitere Hilfe

### Dokumentation
- **Setup**: docs\setup.md
- **Deployment**: docs\deployment.md
- **API**: docs\api.md

### Logs prüfen
Bei Problemen schauen Sie in:
- `installation.log` (im Hauptordner)
- Backend-Logs (im Terminal wo Backend läuft)

### Häufige Fragen
**F: Kann ich die Anwendung auf mehreren PCs nutzen?**
A: Ja, wenn Sie sie auf einem Server deployen (siehe Deployment-Anleitung)

**F: Werden meine Daten in der Cloud gespeichert?**
A: Nein, alles läuft lokal auf Ihrem PC (oder Ihrem eigenen Server)

**F: Kann ich mehrere Benutzer haben?**
A: Aktuell nicht implementiert, kann aber hinzugefügt werden

**F: Wie sichere ich meine Daten?**
A: Regelmäßige PostgreSQL Backups mit pg_dump

**F: Funktioniert es auf Mac/Linux?**
A: Das Backend ja, aber Sie müssen die .bat Dateien durch .sh Scripts ersetzen

---

**Viel Erfolg mit Ihrem Rechnungsgenerator!** 🐝🍯
