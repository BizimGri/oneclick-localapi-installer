@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oneclick-uninstall.ps1" %*
exit /b %errorlevel%
