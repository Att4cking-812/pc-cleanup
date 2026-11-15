@echo off
chcp 65001 >nul
title Cleanup
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cleanup.ps1"
