@echo off
title Backend Reparieren
color 0E

echo.
echo ===============================================================
echo      BACKEND WIRD REPARIERT
echo ===============================================================
echo.

cd /d "%~dp0projekt\backend"

echo [1/3] Aktiviere Virtual Environment...
call venv\Scripts\activate.bat
echo [OK] Aktiviert

echo.
echo [2/3] Installiere Python Pakete...
echo (Dies kann einige Minuten dauern)
echo.

pip install --upgrade pip
pip install fastapi==0.109.0
pip install uvicorn[standard]==0.27.0
pip install sqlalchemy==2.0.25
pip install psycopg2-binary==2.9.9
pip install pydantic==2.5.3
pip install pydantic-settings==2.1.0
pip install python-dotenv==1.0.0
pip install reportlab==4.0.9
pip install PyPDF2==3.0.1
pip install Pillow==10.2.0
pip install python-multipart==0.0.6
pip install alembic==1.13.1
pip install email-validator==2.1.0

echo.
echo [3/3] Teste Installation...
python -c "import fastapi; print('[OK] FastAPI importiert')"
python -c "import uvicorn; print('[OK] Uvicorn importiert')"
python -c "import sqlalchemy; print('[OK] SQLAlchemy importiert')"

echo.
echo ===============================================================
echo      BACKEND REPARATUR ABGESCHLOSSEN
echo ===============================================================
echo.
echo Das Backend sollte jetzt funktionieren!
echo.
echo Starten Sie START_BACKEND.bat erneut.
echo.
pause
