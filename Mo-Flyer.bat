@echo off
cd /d "%~dp0"
title Flyer gia khuyen mai - Kome
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
if errorlevel 1 pause
