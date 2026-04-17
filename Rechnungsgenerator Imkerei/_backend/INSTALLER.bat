@echo off
title Rechnungsgenerator Imkerei - Installation
color 0A

echo.
echo ===============================================================
echo      RECHNUNGSGENERATOR IMKEREI - INSTALLATION
echo ===============================================================
echo.

cd /d "%~dp0"

set LOGFILE=%~dp0installation.log
echo Installation gestartet am %date% %time% > "%LOGFILE%"

echo [1/7] Pruefe Python...
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [FEHLER] Python nicht gefunden!
    echo Installieren Sie Python von: https://www.python.org/downloads/
    pause
    exit /b 1
)
echo [OK] Python gefunden

echo.
echo [2/7] Pruefe Node.js...
node --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [FEHLER] Node.js nicht gefunden!
    echo Installieren Sie Node.js von: https://nodejs.org/
    pause
    exit /b 1
)
echo [OK] Node.js gefunden

echo.
echo [3/7] Pruefe PostgreSQL...
psql --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNUNG] PostgreSQL nicht gefunden!
    echo Installieren Sie PostgreSQL von: https://www.postgresql.org/
    echo Trotzdem fortfahren? (J/N)
    set /p CONTINUE=
    if /i not "%CONTINUE%"=="J" exit /b 1
)
echo [OK] PostgreSQL gefunden

echo.
echo [4/7] Organisiere Projektstruktur...
if not exist "projekt" (
    mkdir "projekt"
    if exist "backend" move /Y "backend" "projekt\" >nul
    if exist "frontend" move /Y "frontend" "projekt\" >nul
    if exist "docs" move /Y "docs" "projekt\" >nul
    if exist "README.md" move /Y "README.md" "projekt\" >nul
    if exist ".gitignore" move /Y ".gitignore" "projekt\" >nul
    echo [OK] Dateien verschoben
) else (
    echo [OK] Struktur bereits vorhanden
)

echo.
echo [5/7] Richte Backend ein...
cd projekt\backend
if not exist "venv" (
    python -m venv venv
    echo [OK] Virtual Environment erstellt
)
call venv\Scripts\activate.bat
pip install --upgrade pip >nul 2>&1
pip install -r requirements.txt >> "..\..\installation.log" 2>&1
echo [OK] Backend Dependencies installiert

if not exist ".env" (
    copy .env.example .env >nul
    echo [INFO] Bitte .env Datei bearbeiten!
)
cd ..\..

echo.
echo [6/7] Richte Frontend ein...
cd projekt\frontend
call npm install >> "..\..\installation.log" 2>&1
echo [OK] Frontend Dependencies installiert
cd ..\..

echo.
echo [7/7] Erstelle Start-Scripts...

echo @echo off > START_BACKEND.bat
echo cd /d "%%~dp0projekt\backend" >> START_BACKEND.bat
echo call venv\Scripts\activate.bat >> START_BACKEND.bat
echo cls >> START_BACKEND.bat
echo echo Backend wird gestartet... >> START_BACKEND.bat
echo echo Backend: http://localhost:8000 >> START_BACKEND.bat
echo echo API Docs: http://localhost:8000/docs >> START_BACKEND.bat
echo echo. >> START_BACKEND.bat
echo python main.py >> START_BACKEND.bat
echo pause >> START_BACKEND.bat

echo @echo off > START_FRONTEND.bat
echo cd /d "%%~dp0projekt\frontend" >> START_FRONTEND.bat
echo cls >> START_FRONTEND.bat
echo echo Frontend wird gestartet... >> START_FRONTEND.bat
echo echo Frontend: http://localhost:3000 >> START_FRONTEND.bat
echo echo. >> START_FRONTEND.bat
echo call npm run dev >> START_FRONTEND.bat
echo pause >> START_FRONTEND.bat

echo @echo off > START_ALLES.bat
echo cls >> START_ALLES.bat
echo echo Starte Backend und Frontend... >> START_ALLES.bat
echo echo. >> START_ALLES.bat
echo start "" "%%~dp0START_BACKEND.bat" >> START_ALLES.bat
echo timeout /t 5 /nobreak ^>nul >> START_ALLES.bat
echo start "" "%%~dp0START_FRONTEND.bat" >> START_ALLES.bat

echo [OK] Start-Scripts erstellt

echo.
echo ===============================================================
echo                  INSTALLATION ABGESCHLOSSEN
echo ===============================================================
echo.
echo NAECHSTE SCHRITTE:
echo.
echo 1. PostgreSQL Datenbank erstellen:
echo    CREATE DATABASE rechnungsgenerator;
echo.
echo 2. Backend konfigurieren:
echo    Bearbeiten Sie: projekt\backend\.env
echo.
echo 3. Anwendung starten:
echo    Doppelklick auf START_ALLES.bat
echo.
echo 4. Browser oeffnen:
echo    http://localhost:3000
echo.
echo Log-Datei: installation.log
echo.
pause
