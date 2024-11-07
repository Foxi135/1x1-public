@echo off
for /f "tokens=2" %%A in ('mode con ^| find "Lines"') do set "window_height=%%A"
for /f "tokens=2" %%A in ('mode con ^| find "Columns"') do set "window_width=%%A"
for /f "tokens=3" %%A in ('reg query HKCU\Console /v ScreenBufferSize') do set /a window_buffer=%%A/65535

echo %window_width%x%window_height%x%window_buffer%