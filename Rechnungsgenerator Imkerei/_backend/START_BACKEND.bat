@echo off
cd /d "%~dp0projekt\backend"

if not exist "venv\Scripts\python.exe" (
    echo [FEHLER] Virtual Environment nicht gefunden!
    echo.
    echo Bitte fuehren Sie BACKEND_REPARIEREN.bat aus.
    echo.
    pause
    exit /b 1
)

echo Aktiviere Virtual Environment...
call venv\Scripts\activate.bat

cls
echo ===============================================================
echo      Backend wird gestartet...
echo ===============================================================
echo.
echo Backend: http://localhost:8000
echo API Docs: http://localhost:8000/docs
echo.
echo Druecken Sie STRG+C zum Beenden
echo.

venv\Scripts\python.exe main.py

pause
