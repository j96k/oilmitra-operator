@echo off
REM Builds the operator console and copies it to backend\admin_webapp (served at /admin/).
cd /d "%~dp0"
call "%~dp0..\env.bat"

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found on PATH.
  echo The prebuilt app in ..\backend\admin_webapp still works.
  echo To rebuild, install Flutter or set FLUTTER_HOME in ..\env.bat.
  pause
  exit /b 1
)

echo Building the operator console for the browser...
call flutter pub get
call flutter build web --target lib/main_admin.dart --base-href /admin/ --output build/admin_web
if errorlevel 1 (
  echo Build failed.
  pause
  exit /b 1
)

echo Copying to ..\backend\admin_webapp ...
if exist "..\backend\admin_webapp" rmdir /s /q "..\backend\admin_webapp"
xcopy /e /i /q "build\admin_web" "..\backend\admin_webapp" >nul

echo.
echo Done. Start backend\run_server.bat, then open http://localhost:8000/admin/
start "" http://localhost:8000/admin/
pause
