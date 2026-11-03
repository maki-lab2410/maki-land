@echo off
title Menjalankan maki-land (Windows 10 / 11)
echo ========================================================
echo   Menjalankan maki-land (Windows 10 / 11)
echo   Dynamic Island & Floating Desktop Capybara Companion
echo ========================================================
echo.

where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js belum terinstall!
    echo Silakan install Node.js (v18+) dari https://nodejs.org
    pause
    exit /b 1
)

if not exist node_modules (
    echo Menginstall dependensi pertama kali...
    call npm install
)

if not exist dist (
    echo Melakukan build pertama kali...
    call npm run build
)

echo Membuka maki-land...
npx electron .
