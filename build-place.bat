@echo off
rem Builds the game into MonsterGarden.rbxlx. Open that file in Roblox Studio to test.
rem Run this again after every code change, then reopen the file in Studio.
cd /d "%~dp0"
"%USERPROFILE%\rojo\rojo.exe" build -o MonsterGarden.rbxlx
echo.
if %errorlevel%==0 (echo Done: open MonsterGarden.rbxlx in Roblox Studio.) else (echo Build failed with exit code %errorlevel%)
pause
