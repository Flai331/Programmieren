@echo off
REM ============================================================
REM  DokuBox - APK bauen (Windows)
REM  Doppelklick genuegt.
REM  Ergebnis: C:\Users\klaas\Desktop\Programmieren\APKs\Android\DokuBox.apk
REM ============================================================

REM In den Ordner dieses Skripts wechseln (dokumenten_system\dokubox)
cd /d "%~dp0"

echo.
echo [1/4] Neuesten Stand holen ...
git pull
if errorlevel 1 goto :fehler

echo.
echo [2/4] Abhaengigkeiten aufloesen ...
call flutter pub get
if errorlevel 1 goto :fehler

echo.
echo [3/4] APK bauen (das dauert ein paar Minuten) ...
call flutter build apk --release
if errorlevel 1 goto :fehler

echo.
echo [4/4] APK in den APK-Ordner kopieren ...
set "APKORDNER=C:\Users\klaas\Desktop\Programmieren\APKs\Android"
if not exist "%APKORDNER%" mkdir "%APKORDNER%"
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%APKORDNER%\DokuBox.apk" >nul
if errorlevel 1 goto :fehler

echo.
echo ============================================================
echo  FERTIG!  Die App liegt hier:
for %%I in ("%APKORDNER%\DokuBox.apk") do echo  %%~fI
echo  Datei aufs Handy uebertragen und antippen zum Installieren.
echo ============================================================
echo.
pause
exit /b 0

:fehler
echo.
echo ############################################################
echo  FEHLER - siehe Meldung oben.
echo ############################################################
echo.
pause
exit /b 1
