# API-Dokumentation

Die vollständige interaktive API-Dokumentation ist verfügbar unter:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Base URL

Lokal: `http://localhost:8000/api`
Produktion: `https://your-domain.de/api`

## Authentifizierung

Aktuell keine Authentifizierung implementiert. Für Produktionsumgebung sollte JWT-Auth hinzugefügt werden.

## Endpunkte

### Kunden (Customers)

#### GET /api/customers/
Liste alle Kunden

**Query Parameter:**
- `skip`: int (default: 0)
- `limit`: int (default: 100)
- `search`: string

**Response:** Liste von Customer-Objekten

#### POST /api/customers/
Erstelle neuen Kunden

**Request Body:**
```json
{
  "name": "Max Mustermann",
  "company": "Muster GmbH",
  "email": "max@example.com",
  "phone": "+49 123 456789",
  "street": "Musterstraße 1",
  "postal_code": "12345",
  "city": "Musterstadt",
  "country": "Deutschland"
}
```

#### GET /api/customers/{id}
Hole einen spezifischen Kunden

#### PUT /api/customers/{id}
Aktualisiere Kunden

#### DELETE /api/customers/{id}
Lösche Kunden

### Rechnungen (Invoices)

#### GET /api/invoices/
Liste alle Rechnungen

**Query Parameter:**
- `status`: InvoiceStatus (draft, sent, paid, overdue, cancelled)
- `customer_id`: int

#### POST /api/invoices/
Erstelle neue Rechnung

**Request Body:**
```json
{
  "customer_id": 1,
  "invoice_date": "2024-01-15T10:00:00",
  "payment_terms": 14,
  "tax_rate": 19.0,
  "template_id": 1,
  "customer_notes": "Vielen Dank für Ihren Einkauf!",
  "items": [
    {
      "description": "Waldhonig 500g",
      "quantity": 2,
      "unit": "Stück",
      "unit_price": 8.50,
      "article_id": 1
    }
  ]
}
```

#### GET /api/invoices/{id}
Hole eine spezifische Rechnung

#### PUT /api/invoices/{id}
Aktualisiere Rechnung

#### POST /api/invoices/{id}/mark-sent
Markiere Rechnung als versendet

#### POST /api/invoices/{id}/mark-paid
Markiere Rechnung als bezahlt

#### GET /api/invoices/{id}/pdf
Lade Rechnung als PDF herunter

### Artikel (Articles)

#### GET /api/articles/
Liste alle Artikel

**Query Parameter:**
- `category`: string
- `search`: string
- `active_only`: bool (default: true)

#### POST /api/articles/
Erstelle neuen Artikel

**Request Body:**
```json
{
  "name": "Waldhonig",
  "description": "Feiner Waldhonig aus regionaler Produktion",
  "article_number": "HON-001",
  "unit_price": 8.50,
  "unit": "Glas",
  "category": "Honig",
  "stock_quantity": 50
}
```

#### GET /api/articles/{id}
Hole einen spezifischen Artikel

#### PUT /api/articles/{id}
Aktualisiere Artikel

#### DELETE /api/articles/{id}
Lösche Artikel

### Vorlagen (Templates)

#### GET /api/templates/
Liste alle Vorlagen

#### POST /api/templates/
Erstelle neue Vorlage

**Request Body:**
```json
{
  "name": "Standard Vorlage",
  "sender_name": "Ihre Imkerei",
  "sender_company": "Imkerei Mustermann",
  "sender_email": "info@imkerei-mustermann.de",
  "sender_phone": "+49 123 456789",
  "sender_street": "Bienenweg 1",
  "sender_postal_code": "12345",
  "sender_city": "Honigstadt",
  "tax_id": "12/345/67890",
  "bank_name": "Sparkasse",
  "iban": "DE89370400440532013000",
  "is_default": 1
}
```

#### POST /api/templates/{id}/upload-pdf
Lade PDF-Vorlage hoch

**Form Data:**
- `file`: PDF-Datei

#### POST /api/templates/{id}/upload-logo
Lade Logo hoch

**Form Data:**
- `file`: Bild-Datei (PNG, JPG, SVG)

#### GET /api/templates/{id}
Hole eine spezifische Vorlage

#### PUT /api/templates/{id}
Aktualisiere Vorlage

#### DELETE /api/templates/{id}
Lösche Vorlage

### Statistiken (Statistics)

#### GET /api/statistics/invoices
Hole Rechnungsstatistiken

**Query Parameter:**
- `start_date`: datetime (ISO format)
- `end_date`: datetime (ISO format)

**Response:**
```json
{
  "total_invoices": 45,
  "total_revenue": 3850.50,
  "total_outstanding": 450.00,
  "paid_invoices": 40,
  "overdue_invoices": 2,
  "draft_invoices": 3,
  "average_invoice_value": 96.26,
  "average_payment_days": 12.5,
  "monthly_revenue": [
    {"month": "2024-01", "revenue": 1200.00},
    {"month": "2024-02", "revenue": 1350.50}
  ]
}
```

#### GET /api/statistics/customers/{id}
Hole Statistiken für spezifischen Kunden

#### GET /api/statistics/top-customers
Hole Top-Kunden nach Umsatz

**Query Parameter:**
- `limit`: int (default: 10, max: 50)

## Fehlerbehandlung

### Standard-Fehlerantworten

**404 Not Found:**
```json
{
  "detail": "Customer not found"
}
```

**422 Validation Error:**
```json
{
  "detail": [
    {
      "loc": ["body", "email"],
      "msg": "value is not a valid email address",
      "type": "value_error.email"
    }
  ]
}
```

**500 Internal Server Error:**
```json
{
  "detail": "Internal server error"
}
```

## Rate Limiting

Aktuell nicht implementiert. Für Produktionsumgebung empfohlen.

## Beispiel-Requests mit cURL

### Kunde erstellen

```bash
curl -X POST "http://localhost:8000/api/customers/" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Max Mustermann",
    "email": "max@example.com",
    "street": "Musterstraße 1",
    "postal_code": "12345",
    "city": "Musterstadt"
  }'
```

### Rechnung erstellen

```bash
curl -X POST "http://localhost:8000/api/invoices/" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": 1,
    "payment_terms": 14,
    "tax_rate": 19.0,
    "items": [
      {
        "description": "Waldhonig 500g",
        "quantity": 2,
        "unit": "Stück",
        "unit_price": 8.50
      }
    ]
  }'
```

### PDF herunterladen

```bash
curl -X GET "http://localhost:8000/api/invoices/1/pdf" \
  --output rechnung.pdf
```

## Websocket-Support

Aktuell nicht implementiert. Könnte für Echtzeit-Updates hinzugefügt werden.
