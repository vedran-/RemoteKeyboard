@echo off
title RemoteKeyboard PC Server
cls
echo ============================================
echo    RemoteKeyboard PC Server
echo ============================================
echo.
echo Server is starting...
echo.
echo When you see "Ready to receive commands":
echo   1. Open mobile app
echo   2. Add PC manually with this IP:
echo      (run 'ipconfig' in another window to find it)
echo   3. Port: 8765
echo   4. Connect and use touchpad/keyboard/media
echo.
echo Press Ctrl+C to stop the server
echo ============================================
echo.

cd /d "%~dp0"
cargo run --release --bin remote_keyboard_pc

pause
