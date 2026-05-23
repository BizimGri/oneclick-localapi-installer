@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "EXITCODE=%errorlevel%"
echo.
if "%EXITCODE%"=="0" (
  echo [OK] Islem tamamlandi.
) else (
  echo [ERROR] Islem hata ile tamamlandi. Kod: %EXITCODE%
)
set /p _="Kapatmak icin Enter tusuna basin..."
exit /b %EXITCODE%
