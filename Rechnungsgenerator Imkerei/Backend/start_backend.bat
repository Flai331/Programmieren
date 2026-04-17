@echo off
echo ========================================
echo   Rechnungsgenerator Backend Server
echo ========================================
echo.

cd /d "%~dp0"

REM Prüfe ob Python installiert ist
python --version >nul 2>&1
if errorlevel 1 (
    echo FEHLER: Python ist nicht installiert!
    echo Bitte Python von https://www.python.org/downloads/ installieren.
    pause
    exit /b 1
)

REM Prüfe ob Virtual Environment existiert
if not exist "venv" (
    echo Erstelle Virtual Environment...
    python -m venv venv
)

REM Aktiviere Virtual Environment
call venv\Scripts\activate.bat

REM Installiere Dependencies falls nötig
echo Prüfe Dependencies...
pip install -r requirements.txt -q

REM Starte Server
echo.
echo Server startet auf http://localhost:8000
echo API-Dokumentation: http://localhost:8000/docs
echo.
echo Drücke Strg+C zum Beenden
echo ========================================
echo.

python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

pause
