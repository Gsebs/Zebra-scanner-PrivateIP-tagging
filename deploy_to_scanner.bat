@echo off
REM ===========================================================================
REM Thin launcher that runs deploy_to_scanner.ps1 with execution policy bypass
REM so a Windows user can just double-click this .bat file and not deal with
REM PowerShell signing rules.
REM ===========================================================================

setlocal

where powershell >nul 2>nul
if errorlevel 1 (
    echo [X] PowerShell not found on this machine.
    echo     Install Windows PowerShell or PowerShell 7+ and try again.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_to_scanner.ps1"
set EXITCODE=%ERRORLEVEL%

echo.
echo Script finished. Press any key to close this window.
pause >nul
exit /b %EXITCODE%
