@echo off 
cls 
echo Starte Backend und Frontend... 
echo. 
start "" "%~dp0START_BACKEND.bat" 
timeout /t 5 /nobreak >nul 
start "" "%~dp0START_FRONTEND.bat" 
