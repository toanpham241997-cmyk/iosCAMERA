@echo off
cd /d "%~dp0"
python scripts\builder_ui.py
if errorlevel 1 pause
