@echo off
echo =============================================
echo   Rechnungsgenerator Imkerei - Build Windows EXE
echo =============================================
echo.

cd /d "%~dp0"

REM Check if node_modules exists
if not exist "node_modules" (
    echo Installiere Abhaengigkeiten...
    npm install
    echo.
)

echo Erstelle Windows-Executable...
echo Dies kann einige Minuten dauern...
echo.

npm run build

echo.
echo =============================================
echo Build abgeschlossen!
echo Die EXE-Datei befindet sich im Ordner: dist\
echo =============================================
echo.

pause
