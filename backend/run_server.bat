@echo off
REM Starts the OilMitra operator API on port 8000.
cd /d "%~dp0"
if not exist .venv (
  echo Creating Python virtual environment...
  python -m venv .venv
  .venv\Scripts\pip install -r requirements.txt
)
if not exist .env (
  copy .env.example .env
  echo Created backend\.env - uses SQLite by default.
)
echo.
echo  Operator console: http://localhost:8000/admin/
echo  API docs:         http://localhost:8000/docs
echo.
echo  For shared live data, set DB_TYPE=postgres and DATABASE_URL in .env.
echo.
.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
echo.
echo  The server has stopped.
pause
