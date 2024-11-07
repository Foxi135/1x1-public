@echo off
for /f %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
echo %ESC%[6n