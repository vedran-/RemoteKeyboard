@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM RemoteKeyboard - Build and Run Script
REM ============================================================================
REM Usage:
REM   build_run.bat              - Show this help
REM   build_run.bat build-all    - Build PC server + Windows client + Android APK
REM   build_run.bat build-pc     - Build PC server only
REM   build_run.bat build-win    - Build Windows client only
REM   build_run.bat build-android - Build Android APK only
REM   build_run.bat run-pc       - Run PC server
REM   build_run.bat run-win      - Run Windows client
REM   build_run.bat run-both     - Run PC server + Windows client
REM   build_run.bat build-run-all - Build all + Run both (PC + Windows)
REM   build_run.bat debug-client - Run Windows client in debug mode (flutter run -d windows)
REM   build_run.bat test-server  - Run Python test server (for debugging)
REM   build_run.bat clean        - Clean all builds
REM   build_run.bat install-android - Install APK to Android device via ADB
REM ============================================================================

cd /d "%~dp0"

if "%1"=="" goto :help
if "%1"=="help" goto :help
if "%1"=="build-all" goto :build_all
if "%1"=="build-pc" goto :build_pc
if "%1"=="build-win" goto :build_win
if "%1"=="build-android" goto :build_android
if "%1"=="run-pc" goto :run_pc
if "%1"=="run-win" goto :run_win
if "%1"=="run-both" goto :run_both
if "%1"=="build-run-all" goto :build_and_run_all
if "%1"=="debug-client" goto :debug_client
if "%1"=="test-server" goto :test_server
if "%1"=="clean" goto :clean
if "%1"=="install-android" goto :install_android

echo Unknown command: %1
echo Run 'build_run.bat' for usage.
goto :eof

:help
echo.
echo RemoteKeyboard - Build and Run Script
echo ======================================
echo.
echo Usage:
echo   build_run.bat              - Show this help
echo   build_run.bat build-all    - Build PC server + Windows client + Android APK
echo   build_run.bat build-pc     - Build PC server only
echo   build_run.bat build-win    - Build Windows client only
echo   build_run.bat build-android - Build Android APK only
echo   build_run.bat run-pc       - Run PC server
echo   build_run.bat run-win      - Run Windows client
echo   build_run.bat run-both     - Run PC server + Windows client
echo   build_run.bat build-run-all - Build all + Run both (PC + Windows)
echo   build_run.bat debug-client - Run Windows client in debug mode (flutter run -d windows)
echo   build_run.bat test-server  - Run Python test server (for debugging)
echo   build_run.bat clean        - Clean all builds
echo   build_run.bat install-android - Install APK to Android device via ADB
echo.
goto :eof

:build_all
echo.
echo ============================================
echo Building ALL components...
echo ============================================
echo.
call :build_pc
call :build_win
call :build_android
echo.
echo ============================================
echo BUILD ALL COMPLETE
echo ============================================
echo.
echo Outputs:
echo   PC Server:     pc\target\release\remote_keyboard_pc.exe
echo   Windows Client: mobile\build\windows\x64\runner\Debug\remote_keyboard_mobile.exe
echo   Android APK:   mobile\build\app\outputs\flutter-apk\app-debug.apk
echo.
goto :eof

:build_pc
echo.
echo [1/3] Building PC Server...
echo ============================================
cd pc
call cargo build --release
if errorlevel 1 (
    echo ERROR: PC build failed!
    cd ..
    exit /b 1
)
cd ..
echo PC Server built successfully!
goto :eof

:build_win
echo.
echo [2/3] Building Windows Client...
echo ============================================
cd mobile
call flutter build windows --debug
if errorlevel 1 (
    echo ERROR: Windows build failed!
    cd ..
    exit /b 1
)
cd ..
echo Windows Client built successfully!
goto :eof

:build_android
echo.
echo [3/3] Building Android APK...
echo ============================================
cd mobile
call flutter build apk --debug --android-skip-build-dependency-validation
if errorlevel 1 (
    echo ERROR: Android build failed!
    cd ..
    exit /b 1
)
cd ..
echo Android APK built successfully!
goto :eof

:install_android
echo.
echo Installing APK to Android Device...
echo ============================================
adb install -r mobile\build\app\outputs\flutter-apk\app-debug.apk
if errorlevel 1 (
    echo ERROR: Installation failed!
    exit /b 1
)
echo APK installed successfully!
goto :eof

:build_and_run_all
call :build_all
call :run_both
goto :eof

:debug_client
echo.
echo Starting Windows Client in Debug Mode...
echo ============================================
echo Running Flutter with hot reload enabled.
echo Press 'r' to restart, 'q' to quit.
echo ============================================
echo.
cd mobile
call flutter run -d windows
cd ..
goto :eof

:run_pc
echo.
echo Starting PC Server...
echo Press Ctrl+C in the new window to stop the server.
echo.
start "RemoteKeyboard PC Server" cmd /k "cd pc && cargo run --release"
echo PC Server started in new window.
goto :eof

:run_win
echo.
echo Starting Windows Client...
echo.
start "" "mobile\build\windows\x64\runner\Debug\remote_keyboard_mobile.exe"
echo Windows Client started.
goto :eof

:run_both
echo.
echo Starting PC Server and Windows Client...
echo.
call :run_pc
call :timeout_win 2
call :run_win
echo.
echo Both applications started.
echo.
echo To test connection:
echo   1. In Windows Client, click "Connect" tab
echo   2. Click "Add PC Manually"
echo   3. Enter: IP=127.0.0.1, Port=8765
echo   4. Click "Add" then click connect icon
echo   5. Should see green "Connected" bar
echo.
goto :eof

:timeout_win
timeout /t %1 >nul 2>&1
goto :eof

:test_server
echo.
echo Starting Python Test Server...
echo This is a simple WebSocket server for testing the client.
echo.
echo To test:
echo   1. Connect from Windows Client to 127.0.0.1:8765
echo   2. You should see connection messages in this window
echo.
echo Press Ctrl+C to stop.
echo.
start "WebSocket Test Server" cmd /k "cd pc && python test_server.py"
echo Test server started in new window.
goto :eof

:clean
echo.
echo Cleaning all builds...
echo.
echo [1/3] Cleaning PC...
cd pc
call cargo clean
cd ..

echo [2/3] Cleaning Mobile...
cd mobile
call flutter clean
cd ..

echo [3/3] Removing build folders...
if exist mobile\build rmdir /s /q mobile\build
if exist pc\target rmdir /s /q pc\target

echo.
echo Clean complete!
echo.
goto :eof
