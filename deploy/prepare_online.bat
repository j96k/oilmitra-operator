@echo off
REM Builds the operator console and copies it into backend\admin_webapp.
cd /d "%~dp0..\mobile"
call "%~dp0..\env.bat"

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter is not installed - using the last build in backend\admin_webapp.
  if not exist "%~dp0..\backend\admin_webapp\index.html" (
    echo No operator build found. Install Flutter first.
    pause
    exit /b 1
  )
  goto done
)

echo Building the operator console...
call flutter pub get
call flutter build web --target lib/main_admin.dart --base-href /admin/ --output build/admin_web
if errorlevel 1 (
  echo Operator build failed.
  pause
  exit /b 1
)
if exist "%~dp0..\backend\admin_webapp" rmdir /s /q "%~dp0..\backend\admin_webapp"
xcopy /e /i /q "build\admin_web" "%~dp0..\backend\admin_webapp" >nul

:done
echo.
echo Done. Commit and push so Render can redeploy.
echo See deploy\ONLINE_GUIDE.md.
pause
