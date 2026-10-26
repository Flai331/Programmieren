@echo off
REM Baut eine einzelne Scan-Trenner.exe (ohne Python auf dem Zielrechner).
cd /d "%~dp0"
python -m pip install -q -r requirements.txt pyinstaller
python -m PyInstaller --noconsole --onefile --name Scan-Trenner scan_trenner_gui.py
echo.
echo Fertig: dist\Scan-Trenner.exe
pause
