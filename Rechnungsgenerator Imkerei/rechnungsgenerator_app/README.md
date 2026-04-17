# Rechnungsgenerator Pro - Flutter App

Vollständige Flutter-App für die Erstellung von professionellen Rechnungen mit Offline-Funktionalität und Cloud-Synchronisation.

## Features

✅ **Rechnungsverwaltung**
- Rechnungen erstellen, bearbeiten, löschen
- Automatische Rechnungsnummerierung
- Kundenadressbuch
- Artikel/Positionen hinzufügen

✅ **PDF-Export**
- Professionelle PDF-Generierung
- DIN 5008 konform für Fensterumschläge
- Design-Anpassung (Farben, Logos)
- Druck & Teilen

✅ **Offline-First**
- Lokale SQLite-Datenbank
- Automatische Synchronisation wenn online
- Keine Datenverluste bei Offline-Arbeit

✅ **Design & UX**
- Material Design 3
- Custom Peach/Orange Theme (#fda085)
- Responsive Layout

## Installation

### Voraussetzungen
- Flutter SDK 3.11.4+
- Android SDK 21+
- Xcode (für iOS, optional)

### Setup

```bash
# Abhängigkeiten installieren
flutter pub get

# App bauen
flutter build apk --release          # Android APK
flutter build appbundle --release    # Android App Bundle (Play Store)
flutter build ios --release          # iOS (benötigt Xcode)

# Im Entwicklungsmodus testen
flutter run
```

## Struktur

```
lib/
├── models/           # Datenmodelle (Invoice, Customer, Company, etc.)
├── services/         # Business Logic (Database, Sync, API, Connectivity)
├── screens/          # UI Screens (List, Edit, Settings, etc.)
├── widgets/          # Reusable Widgets
├── utils/            # Helper Functions
└── main.dart         # App Entry Point

test/
├── models/           # Model Unit Tests (41 Tests)
├── services/         # Service Unit Tests
└── utils/            # Utility Function Tests
```

## Testing

```bash
# Alle Tests ausführen
flutter test

# Mit Coverage
flutter test --coverage
```

## Deployment

### Google Play Store
```bash
# App Bundle erstellen
flutter build appbundle --release

# In Android Studio hochladen oder mit Google Play Console
```

### Render Backend (kommend)
PostgreSQL-Datenbank auf Render hostet zentrale Daten für Cloud-Sync.

### Cloudinary Images (kommend)
Bilder/Logos werden zu Cloudinary hochgeladen für Cloud-Storage.

## API Integration (Placeholder)

Die App hat Placeholder für Render API-Integration:
- `lib/services/api_service.dart` - REST API Client
- `lib/services/sync_service.dart` - Offline Sync Queue

## Bekannte Einschränkungen

- ⚠️ App Icons müssen noch individuell gestaltet werden
- ⚠️ Render Backend API noch nicht implementiert
- ⚠️ Cloudinary Integration noch nicht aktiv

## Lizenz

Privat

## Autor

Generiert mit Claude AI - Flutter App Generator (Session 1-6)

## Roadmap

- [ ] Render API Backend implementieren
- [ ] Cloudinary Image Upload integrieren
- [ ] iOS App Store Build
- [ ] Dark Mode erweitern
- [ ] Mehrsprachige UI (EN/DE)
- [ ] Zahlungsintegration (Stripe)
