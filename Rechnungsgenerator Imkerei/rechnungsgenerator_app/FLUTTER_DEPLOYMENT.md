# Flutter-App auf Render Deployen

**Für:** Andere Claude-Sitzungen oder Entwickler  
**Ziel:** Die Flutter-App als Web-Version auf Render hosten

---

## 📋 Voraussetzungen

- Flutter SDK installiert (`flutter --version`)
- Git Zugriff auf `https://github.com/Flai331/Programmieren`
- Render.com Account

---

## 🚀 Schritt-für-Schritt Anleitung

### **1. Lokaler Build Test (optional)**

```bash
cd Rechnungsgenerator\ Imkerei/rechnungsgenerator_app
flutter pub get
flutter build web --release
```

Das erstellt: `build/web/` (ca. 50-100MB)

### **2. Git Update**

Stelle sicher, dass folgende Dateien im Repo existieren:
- `rechnungsgenerator_app/pubspec.yaml` (Flutter Config)
- `rechnungsgenerator_app/render.yaml` (Deployment Config)
- `rechnungsgenerator_app/package.json` (Node Server Config)

Falls nicht → folge **Schritt 3**

### **3. Deployment-Config erstellen**

**Datei:** `Rechnungsgenerator Imkerei/rechnungsgenerator_app/render.yaml`

```yaml
services:
  - type: web
    name: rechnungsgenerator-mobile-web
    env: node
    plan: free
    buildCommand: "cd 'Rechnungsgenerator Imkerei/rechnungsgenerator_app' && flutter pub get && flutter build web --release"
    startCommand: "cd 'Rechnungsgenerator Imkerei/rechnungsgenerator_app' && npx serve -s build/web -l 3000"
    envVars:
      - key: FLUTTER_WEB_API_URL
        value: "https://rechnungsgenerator-backend.onrender.com/api"
        scope: PROJECT
```

**Datei:** `Rechnungsgenerator Imkerei/rechnungsgenerator_app/package.json`

```json
{
  "name": "rechnungsgenerator-mobile-web",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "serve": "serve -s build/web -l 3000"
  },
  "dependencies": {
    "serve": "^14.0.0"
  }
}
```

### **4. Git Push**

```bash
git add Rechnungsgenerator\ Imkerei/rechnungsgenerator_app/render.yaml
git add Rechnungsgenerator\ Imkerei/rechnungsgenerator_app/package.json
git commit -m "Add Flutter web deployment configuration"
git push origin main
```

### **5. Render Deployment**

**Auf render.com:**

1. Dashboard → **+ New** → **Web Service**
2. **Repository wählen:** `Flai331/Programmieren`
3. **Settings:**
   - Name: `rechnungsgenerator-mobile-web`
   - Environment: `Node`
   - Build Command: `cd 'Rechnungsgenerator Imkerei/rechnungsgenerator_app' && flutter pub get && flutter build web --release`
   - Start Command: `cd 'Rechnungsgenerator Imkerei/rechnungsgenerator_app' && npx serve -s build/web -l 3000`
   - Plan: Free
   - Environment Variables:
     - `FLUTTER_WEB_API_URL` = `https://rechnungsgenerator-backend.onrender.com/api`

4. **Deploy** klicken → Warten (5-10 Minuten)

---

## ✅ Nach dem Deploy

**Test URLs:**
- App läuft auf: `https://rechnungsgenerator-mobile-web.onrender.com`
- Backend API: `https://rechnungsgenerator-backend.onrender.com/api`
- API Docs: `https://rechnungsgenerator-backend.onrender.com/docs`

---

## 🔧 Troubleshooting

| Problem | Lösung |
|---------|--------|
| **Build fehlt** | Render braucht 5-10 Min. Logs checken |
| **Flutter nicht gefunden** | Render Node-Image hat Flutter nicht - nutze `flutter build web --release` vor Deploy |
| **404 on App** | `build/web` Ordner existiert nicht - lokaler Build fehlgeschlagen |
| **API-Fehler** | Environment-Variable `FLUTTER_WEB_API_URL` kontrollieren |

---

## 📝 Alternative: Docker (für Production)

Falls Free Plan zu langsam ist, verwende Docker mit `Dockerfile`:

```dockerfile
FROM flutter:latest
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release
FROM node:20-alpine
RUN npm install -g serve
COPY --from=0 /app/build/web /app
EXPOSE 3000
CMD ["serve", "-s", "/app", "-l", "3000"]
```

---

**Fertig!** Die Flutter-App läuft jetzt auf Render. 🚀
