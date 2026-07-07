@echo off
rem Uppdaterar all data i Karlstad-analys: hamtar fran SCB + Kolada,
rem bygger om datalagret och skriver ny app\data.js.
rem Ladda om app\index.html i webblasaren efterat.
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "pipeline\hamta-scb-data.ps1"
echo.
echo Klart! Ladda om app\index.html i webblasaren for att se ny data.
pause
