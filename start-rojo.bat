@echo off
rem Starts the Rojo server for Roblox Studio. Leave this window open while testing.
cd /d "%~dp0"
echo Starting Rojo... (leave this window open)
"%USERPROFILE%\rojo\rojo.exe" serve --address 127.0.0.1 --port 34872
echo.
echo Rojo stopped with exit code %errorlevel%
pause
