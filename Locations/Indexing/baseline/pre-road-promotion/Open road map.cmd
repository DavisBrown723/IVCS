@echo off
powershell.exe -NoProfile -File "%~dp0start-map.ps1"
if errorlevel 1 pause
