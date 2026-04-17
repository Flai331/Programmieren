# Deployment-Anleitung für Hetzner VPS

Diese Anleitung zeigt, wie Sie den Rechnungsgenerator auf einem Hetzner VPS (CX21, ca. 4-5€/Monat) deployen.

## 1. Hetzner VPS einrichten

### Server bestellen

1. Gehen Sie zu https://www.hetzner.com/cloud
2. Wählen Sie CX21 (2 vCPU, 4 GB RAM)
3. Image: Ubuntu 22.04 LTS
4. SSH-Key hinzufügen (oder Root-Passwort notieren)
5. Server erstellen

### Ersten Login

```bash
ssh root@YOUR_SERVER_IP
```

### System aktualisieren

```bash
apt update && apt upgrade -y
```

## 2. Basis-Software installieren

### Python 3.10+

```bash
apt install -y python3.10 python3.10-venv python3-pip
```

### PostgreSQL

```bash
apt install -y postgresql postgresql-contrib
```

### Node.js & npm

```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
```

### Nginx

```bash
apt install -y nginx
```

### Git

```bash
apt install -y git
```

## 3. PostgreSQL konfigurieren

```bash
# Als postgres user
sudo -u postgres psql

# In psql:
CREATE DATABASE rechnungsgenerator;
CREATE USER rechnungen_user WITH PASSWORD 'SICHERES_PASSWORT_HIER';
GRANT ALL PRIVILEGES ON DATABASE rechnungsgenerator TO rechnungen_user;
\q
```

## 4. Anwendung deployen

### User erstellen

```bash
adduser --disabled-password rechnungen
su - rechnungen
```

### Code hochladen

Option 1: Git Repository (empfohlen)

```bash
git clone YOUR_REPOSITORY_URL app
cd app
```

Option 2: Manueller Upload

Auf lokalem PC:
```bash
# ZIP erstellen
zip -r rechnungsgenerator.zip .

# Mit SCP hochladen
scp rechnungsgenerator.zip rechnungen@YOUR_SERVER_IP:~/
```

Auf Server:
```bash
unzip rechnungsgenerator.zip -d app
cd app
```

### Backend einrichten

```bash
cd backend

# Virtual Environment
python3 -m venv venv
source venv/bin/activate

# Dependencies
pip install -r requirements.txt

# Environment-Datei
cp .env.example .env
nano .env
```

Bearbeiten Sie .env:

```env
DATABASE_URL=postgresql://rechnungen_user:PASSWORT@localhost:5432/rechnungsgenerator
API_SECRET_KEY=GENERIERTER_KEY
DEBUG=False
ALLOWED_ORIGINS=http://YOUR_DOMAIN,http://YOUR_SERVER_IP
```

Generieren Sie einen Secret Key:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

### Datenbank initialisieren

```bash
python3 -c "from app.database import engine, Base; from app.models import *; Base.metadata.create_all(bind=engine)"
```

### Frontend bauen

```bash
cd ../frontend

# Dependencies installieren
npm install

# Produktions-Build
npm run build

# Build-Ordner verschieben
mv dist ../backend/static
```

## 5. Systemd Services einrichten

### Backend Service

Als root:

```bash
nano /etc/systemd/system/rechnungen-backend.service
```

```ini
[Unit]
Description=Rechnungsgenerator Backend
After=network.target postgresql.service

[Service]
Type=simple
User=rechnungen
WorkingDirectory=/home/rechnungen/app/backend
Environment="PATH=/home/rechnungen/app/backend/venv/bin"
ExecStart=/home/rechnungen/app/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable rechnungen-backend
systemctl start rechnungen-backend
systemctl status rechnungen-backend
```

## 6. Nginx konfigurieren

```bash
nano /etc/nginx/sites-available/rechnungsgenerator
```

```nginx
server {
    listen 80;
    server_name YOUR_DOMAIN_OR_IP;

    # Frontend (React)
    location / {
        root /home/rechnungen/app/backend/static;
        try_files $uri $uri/ /index.html;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # PDFs
    location /pdfs {
        proxy_pass http://localhost:8000/pdfs;
    }

    # API Docs
    location /docs {
        proxy_pass http://localhost:8000/docs;
    }

    client_max_body_size 20M;
}
```

```bash
# Aktivieren
ln -s /etc/nginx/sites-available/rechnungsgenerator /etc/nginx/sites-enabled/

# Nginx testen und neustarten
nginx -t
systemctl restart nginx
```

## 7. SSL mit Let's Encrypt (optional, aber empfohlen)

```bash
apt install -y certbot python3-certbot-nginx

certbot --nginx -d your-domain.de

# Auto-Renewal testen
certbot renew --dry-run
```

## 8. Firewall einrichten

```bash
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable
```

## 9. Backup einrichten

```bash
# Backup-Script erstellen
nano /home/rechnungen/backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/home/rechnungen/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Datenbank Backup
pg_dump -U rechnungen_user rechnungsgenerator > $BACKUP_DIR/db_$DATE.sql

# PDFs und Uploads
tar -czf $BACKUP_DIR/files_$DATE.tar.gz /home/rechnungen/app/backend/pdfs /home/rechnungen/app/backend/uploads

# Alte Backups löschen (älter als 30 Tage)
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
```

```bash
chmod +x /home/rechnungen/backup.sh

# Cronjob für tägliches Backup (1 Uhr nachts)
crontab -e

# Hinzufügen:
0 1 * * * /home/rechnungen/backup.sh
```

## 10. Monitoring & Logs

### Logs anschauen

```bash
# Backend Logs
journalctl -u rechnungen-backend -f

# Nginx Logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

## 11. Updates deployen

```bash
su - rechnungen
cd app

# Code aktualisieren
git pull

# Backend
cd backend
source venv/bin/activate
pip install -r requirements.txt

# Frontend neu bauen
cd ../frontend
npm install
npm run build
rm -rf ../backend/static
mv dist ../backend/static

# Backend neu starten
sudo systemctl restart rechnungen-backend
```

## Kosten

- Hetzner CX21 VPS: ~4,50€/Monat
- Domain (optional): ~1€/Monat
- **Gesamt: ca. 5-6€/Monat**

## Sicherheit

1. Regelmäßige Updates: `apt update && apt upgrade`
2. Starke Passwörter verwenden
3. SSH-Key Authentication aktivieren
4. Fail2ban installieren: `apt install fail2ban`
5. Regelmäßige Backups

## Support

Bei Problemen:
- Backend-Logs prüfen: `journalctl -u rechnungen-backend -n 100`
- Nginx-Logs prüfen: `tail -f /var/log/nginx/error.log`
- Datenbank-Verbindung testen: `psql -U rechnungen_user -d rechnungsgenerator`
