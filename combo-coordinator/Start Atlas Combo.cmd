@echo off
title Atlas+ Coconut Coordinator
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-AtlasCombo.ps1"
if errorlevel 1 pause
