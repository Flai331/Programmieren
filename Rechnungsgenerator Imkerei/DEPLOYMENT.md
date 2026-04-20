# Deployment - Rechnungsgenerator Imkerei

Das Projekt wird auf zwei verschiedenen Plattformen gehostet (kostenlos):

## Backend auf Render.com

1. Gehe zu [render.com](https://render.com) und melde dich an
2. Klicke **New** → **Web Service**
3. Wähle das GitHub-Repository: `Programmieren`
4. Konfiguriere:
   - **Name**: `rechnungsgenerator-backend`
   - **Build Command**: `cd Backend && pip install -r requirements.txt`
   - **Start Command**: `cd Backend && uvicorn main:app --host 0.0.0.0 --port 10000`
   - **Plan**: Free

5. Setze **Environment-Variablen** im Dashboard:
   - `DATABASE_URL`: Wird automatisch von der PostgreSQL-Datenbank bereitgestellt
   - `SECRET_KEY`: Generiere einen zufälligen String (z.B. mit `python -c "import secrets; print(secrets.token_urlsafe(32))"`)
   - `CORS_ORIGINS`: `https://rechnungsgenerator-frontend.vercel.app,http://localhost:3000`

6. Erstelle die **PostgreSQL-Datenbank**:
   - Klicke **New** → **PostgreSQL**
   - Name: `rechnungsgenerator-db`
   - Verknüpfe sie mit dem Backend-Service

## Frontend auf Vercel

1. Gehe zu [vercel.com](https://vercel.com) und melde dich mit GitHub an
2. Klicke **Add New** → **Project**
3. Wähle das GitHub-Repository: `Flai331/Programmieren`
4. Konfiguriere:
   - **Framework**: `Vite`
   - **Root Directory**: `Rechnungsgenerator Imkerei/_backend/projekt/frontend`
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`

5. Setze **Environment-Variablen**:
   - `VITE_API_URL`: `https://rechnungsgenerator-backend.onrender.com/api`

6. Deploye!

## Lokal entwickeln

### Backend
```bash
cd Backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env       # Bearbeite die Datei mit lokalen Werten
uvicorn main:app --reload
```

### Frontend
```bash
cd _backend/projekt/frontend
npm install
npm run dev
```

Backend läuft dann auf `http://localhost:8000`  
Frontend läuft dann auf `http://localhost:5173`

## URLs nach Deployment

- **Backend API**: `https://rechnungsgenerator-backend.onrender.com/api`
- **Frontend**: `https://rechnungsgenerator-frontend.vercel.app`
- **API Docs**: `https://rechnungsgenerator-backend.onrender.com/docs`
