@echo off
powershell.exe -NoProfile -File "%~dp0..\..\Locations\Indexing\Roads\start-map.ps1"
if errorlevel 1 pause
