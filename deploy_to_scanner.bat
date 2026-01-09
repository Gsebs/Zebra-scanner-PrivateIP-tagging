@echo off
setlocal

:: Configuration
set "SOURCE_FILES=sync_and_upload.py,config.json,bootstrap_termux.sh"
set "DEST_DIR=/sdcard/Download/ZebraTag"

echo ==========================================
echo Zebra Scanner Deployment Script (Windows)
echo ==========================================

:: Check for ADB
where adb >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Error: 'adb' command not found.
    echo Please install Android Platform Tools and add it to your PATH.
    echo Download: https://developer.android.com/studio/releases/platform-tools
    pause
    exit /b 1
)

:: Check for connected devices
echo [*] Checking for connected devices...
for /f "tokens=*" %%i in ('adb devices ^| find "device" ^| find /v "List of"') do set DEVICE_FOUND=%%i

if "%DEVICE_FOUND%"=="" (
    echo Error: No ADB devices found.
    echo Please ensure:
    echo   1. USB Debugging is enabled on the scanner.
    echo   2. The scanner is connected via USB.
    echo   3. You have accepted the authorization prompt on the scanner screen.
    pause
    exit /b 1
)

echo [*] Device found.

:: Create destination directory
echo [*] Creating target directory on scanner: %DEST_DIR%
adb shell mkdir -p %DEST_DIR%

:: Push files
echo [*] Pushing files to scanner...
for %%f in (%SOURCE_FILES%) do (
    if exist "%%f" (
        echo     -^> Pushing %%f
        adb push "%%f" "%DEST_DIR%/"
    ) else (
        echo     ! Warning: Source file '%%f' not found in current directory.
    )
)

echo.
echo ==========================================
echo Deployment Files Transferred!
echo ==========================================
echo Next Steps on the Scanner:
echo 1. Open Termux.
echo 2. Run the bootstrap commands. You can copy-paste this block:
echo.
echo    cp /sdcard/Download/ZebraTag/bootstrap_termux.sh ~/
echo    chmod +x ~/bootstrap_termux.sh
echo    ./bootstrap_termux.sh
echo.
echo ==========================================
pause
