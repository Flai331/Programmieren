@echo off 
cd /d "%~dp0projekt\frontend" 
cls 
echo Frontend wird gestartet... 
echo Frontend: http://localhost:3000 
echo. 
call npm run dev 
pause 
