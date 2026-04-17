@echo off
echo =============================================
echo   Rechnungsgenerator Imkerei - Desktop App
echo =============================================
echo.

cd /d "%~dp0"

REM Check if node_modules exists
if not exist "node_modules" (
    echo Installiere Abhaengigkeiten...
    npm install
    echo.
)

echo Starte Desktop-App...
echo (Backend muss separat laufen!)
echo.
npm start

pause
