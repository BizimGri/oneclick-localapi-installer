@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oneclick-install.ps1" %*
exit /b %errorlevel%
