@echo off
echo ============================================================
echo Full Integration Test
echo ============================================================
echo.
echo This test will:
echo   1. Connect to PC server
echo   2. Send media commands
echo   3. Log everything to test_output.txt
echo.
echo After this completes, check test_output.txt for results.
echo.

cd /d "%~dp0"

python test_commands.py > test_output.txt 2>&1

echo.
echo Test completed!
echo Results saved to: test_output.txt
echo.
echo Opening results file...
notepad test_output.txt
