@echo off
title Membangun maki-land untuk Windows 10 / 11
echo ========================================================
echo   Membangun maki-land untuk Windows 10 / 11
echo   (Dynamic Island & Desktop Capybara Companion)
echo ========================================================
echo.

where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js belum terinstall!
    echo Silakan install Node.js (v18+) dari https://nodejs.org
    pause
    exit /b 1
)

echo [1/4] Memeriksa & Menginstall dependensi (npm install)...
call npm install
if %errorlevel% neq 0 (
    echo [ERROR] Gagal menginstall dependensi!
    pause
    exit /b 1
)

echo.
echo [2/4] Membuat icon & asset Windows (assets/icon.ico, tray.png)...
call npm run build:icons

echo.
echo [3/4] Melakukan build UI Vite & TypeScript main process...
call npm run build
if %errorlevel% neq 0 (
    echo [ERROR] Gagal melakukan compile build!
    pause
    exit /b 1
)

echo.
echo [4/4] Mengemas installer & file portable Windows (.exe)...
call npm run dist:win
if %errorlevel% neq 0 (
    echo [ERROR] Gagal mengemas aplikasi dengan electron-builder!
    pause
    exit /b 1
)

echo.
echo ========================================================
echo   SELESAI!
echo   File aplikasi siap di folder: release/
echo   - Installer: release/maki-land Setup 1.0.0.exe
echo   - Portable : release/maki-land-Windows-Portable.exe
echo ========================================================
echo.
pause
