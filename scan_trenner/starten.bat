@echo off
REM Startet den Scan-Trenner (Python muss installiert sein, https://www.python.org)
cd /d "%~dp0"
python -m pip install -q -r requirements.txt
python scan_trenner_gui.py
