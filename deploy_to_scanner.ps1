# =============================================================================
# Zebra MC33 - one-touch deploy (Windows / PowerShell).
#
# Connect a scanner via USB with USB Debugging on, then double-click
# deploy_to_scanner.bat (which calls this file). The script does everything
# else, including driving Termux on the scanner via ADB input events.
# The only manual step on the scanner is tapping "Allow" on the storage
# permission popup (Android 14 requirement, unavoidable).
# =============================================================================

# PowerShell's "Stop" mode is too aggressive when wrapping native commands like
# adb -- it converts ANY stderr output into a terminating error, even when the
# command itself succeeded. (Example: `monkey` always prints "args: [...]" to
# stderr.) We use "Continue" and check $LASTEXITCODE manually where we care.
$ErrorActionPreference = "Continue"

# Suppress non-terminating native-command errors from being printed to console.
# With Continue mode, stderr from native commands shows as red "NativeCommand"
# noise we don't want. Combined with 2>&1 | Out-Null below, this keeps the
# console clean.
$PSNativeCommandUseErrorActionPreference = $false

# ---------- Configuration ----------
$SOURCE_FILES = @("sync_and_upload.py", "config.json", "bootstrap_termux.sh")
$DEST_DIR = "/sdcard/Download/ZebraTag"
$SENTINEL = "/sdcard/Download/ZebraTag/.bootstrap_done"
$LOG_REMOTE = "/sdcard/Download/ZebraTag/bootstrap.log"
$APK_DIR = "vendor"
$TERMUX_PKG = "com.termux"
$WIDGET_PKG = "com.termux.widget"
$BOOTSTRAP_TIMEOUT = 300

# cd to the script's own folder so relative paths work regardless of where
# the user double-clicked from.
Set-Location -Path $PSScriptRoot

# If a `platform-tools` subfolder exists next to this script, prefer the adb
# from there. Lets Windows users avoid editing PATH - they can just extract
# platform-tools.zip into the project folder and go.
$localTools = Join-Path $PSScriptRoot "platform-tools"
if (Test-Path (Join-Path $localTools "adb.exe")) {
    $env:PATH = "$localTools;$env:PATH"
}

# ---------- Helpers ----------
function Write-Log  ($msg) { Write-Host "[*] $msg" }
function Write-Ok { Write-Host "    OK" -ForegroundColor Green }
function Write-Fail ($msg) {
    Write-Host ""
    Write-Host "[X] $msg" -ForegroundColor Red
    exit 1
}

function Find-Apk($pattern) {
    Get-ChildItem -Path $APK_DIR -Filter $pattern -ErrorAction SilentlyContinue |
    Select-Object -First 1
}

Write-Host "=============================================="
Write-Host "  Zebra MC33 Deployment (Windows)"
Write-Host "=============================================="

# ---------- 1. ADB present? ----------
Write-Log "Step 1/6: Checking ADB..."
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "[X] 'adb' not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Android Platform Tools:"
    Write-Host "  1. Download: https://developer.android.com/studio/releases/platform-tools"
    Write-Host "  2. Extract to e.g. C:\platform-tools"
    Write-Host "  3. Add that folder to your PATH:"
    Write-Host "       Start -> 'Edit environment variables' -> System variables"
    Write-Host "       -> Path -> New -> paste path -> OK -> OK."
    Write-Host "  4. Open a NEW Command Prompt and verify: adb version"
    Write-Host "  5. Re-run this script."
    exit 1
}
Write-Ok

# ---------- 2. Device detected & authorized? ----------
Write-Log "Step 2/6: Detecting scanner..."
& adb start-server 2>&1 | Out-Null

# Find ALL authorized devices, not just the first. Picking the first silently
# would break later adb calls if the user has e.g. their phone plugged in too.
$devLines = & adb devices 2>&1 | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" }
$authorized = @($devLines | Where-Object { $_ -match "\sdevice\s*$" } | ForEach-Object { ($_ -split '\s+')[0] })

if ($authorized.Count -eq 0) {
    $unauth = $devLines | Where-Object { $_ -match "unauthorized" } | Select-Object -First 1
    if ($unauth) {
        Write-Fail "Scanner is UNAUTHORIZED. Look at the scanner: tap 'Allow' on the USB-debugging prompt (and tick 'Always allow from this computer'), then re-run this script."
    }
    Write-Fail "No scanner detected. Verify: USB cable plugged in, USB Debugging enabled (Settings -> Developer Options -> USB Debugging ON), and 'Allow' tapped on the scanner."
}

if ($authorized.Count -gt 1) {
    Write-Host ""
    Write-Host "[X] Multiple Android devices are connected:" -ForegroundColor Red
    foreach ($d in $authorized) { Write-Host "      $d" }
    Write-Host ""
    Write-Host "    Unplug all other devices (phones, tablets, other scanners) and"
    Write-Host "    leave only the scanner you want to deploy to. Then re-run."
    exit 1
}

$serial = $authorized[0]
# Pin every subsequent adb call to this exact device.
$env:ANDROID_SERIAL = $serial
Write-Host "    Device: $serial"
Write-Ok

# ---------- 3. Termux + Widget APKs ----------
Write-Log "Step 3/6: Verifying Termux installation..."
$pkgList = & adb shell pm list packages 2>&1
$needTermux = -not ($pkgList -match "^package:$TERMUX_PKG\s*$")
$needWidget = -not ($pkgList -match "^package:$WIDGET_PKG\s*$")

if ($needTermux -or $needWidget) {
    if (-not (Test-Path $APK_DIR)) {
        Write-Fail "APK folder '$APK_DIR\' not found. See vendor\README.md for the two F-Droid links to download from."
    }

    if ($needTermux) {
        $apk = Find-Apk "com.termux_*.apk"
        if (-not $apk) { Write-Fail "Termux APK not found in $APK_DIR\. See vendor\README.md." }
        Write-Log "    Installing Termux: $($apk.Name)"
        & adb install -r $apk.FullName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Termux install failed. If Termux from Play Store is installed, uninstall it first (signing-key conflict). On the scanner: Settings -> Apps -> Termux -> Uninstall."
        }
    }
    if ($needWidget) {
        $apk = Find-Apk "com.termux.widget_*.apk"
        if (-not $apk) { Write-Fail "Termux:Widget APK not found in $APK_DIR\." }
        Write-Log "    Installing Termux:Widget: $($apk.Name)"
        & adb install -r $apk.FullName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Termux:Widget install failed (likely a signing-key conflict - see Termux note above)."
        }
    }
}
Write-Ok



# ---------- 4. Push project files ----------
Write-Log "Step 4/6: Pushing project files..."

if (-not (Test-Path "config.json")) {
    Write-Fail "config.json missing. Copy config_example.json to config.json and fill in your FTP credentials before running this script."
}
try {
    # -ErrorAction Stop forces this to throw even though the global preference
    # is "Continue". The try/catch needs a real exception to catch.
    Get-Content "config.json" -Raw | ConvertFrom-Json -ErrorAction Stop | Out-Null
}
catch {
    Write-Fail "config.json is not valid JSON. Fix the syntax and re-run."
}

& adb shell mkdir -p $DEST_DIR 2>&1 | Out-Null
foreach ($f in $SOURCE_FILES) {
    if (-not (Test-Path $f)) { Write-Fail "Missing source file: $f" }
    & adb push $f "$DEST_DIR/" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Fail "Push failed: $f" }
}
& adb shell rm -f $SENTINEL 2>&1 | Out-Null

# Push the deploy wrapper to /data/local/tmp/. This is the script Termux
# will actually execute first. It lives outside /sdcard so Termux can read
# it WITHOUT storage permission (breaking the chicken-and-egg cycle).
if (-not (Test-Path "_deploy_wrapper.sh")) { Write-Fail "Missing file: _deploy_wrapper.sh" }
& adb push "_deploy_wrapper.sh" "/data/local/tmp/_deploy_wrapper.sh" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Fail "Push failed: _deploy_wrapper.sh" }
& adb shell chmod 755 /data/local/tmp/_deploy_wrapper.sh 2>&1 | Out-Null
Write-Ok

# ---------- 5. Launch Termux + run bootstrap ----------
Write-Log "Step 5/6: Running bootstrap on the scanner..."
Write-Host ""
Write-Host "    -------------------------------------------------------" -ForegroundColor Yellow
Write-Host "    LOOK AT THE SCANNER NOW."                               -ForegroundColor Yellow
Write-Host ""                                                            -ForegroundColor Yellow
Write-Host "    Termux is being launched. A storage-permission popup"    -ForegroundColor Yellow
Write-Host "    may appear - TAP 'ALLOW' on the scanner if it does."     -ForegroundColor Yellow
Write-Host "    (Only needed once per scanner.)"                          -ForegroundColor Yellow
Write-Host "    -------------------------------------------------------" -ForegroundColor Yellow
Write-Host ""

& adb shell am force-stop com.termux 2>&1 | Out-Null
Start-Sleep -Seconds 1
& adb shell input keyevent KEYCODE_WAKEUP 2>&1 | Out-Null
# monkey is noisy on stderr ("args: [...]") even on success - must merge streams.
& adb shell monkey -p com.termux -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
# Give Termux time to fully start and show the $ prompt.
Start-Sleep -Seconds 5

# Type ONLY a simple, safe command — no special chars (;, >, &, !).
# Previous attempts used a complex one-liner that the Android shell inside
# `adb shell` interpreted as multiple commands, silently eating everything
# after the first semicolon. The wrapper script in /data/local/tmp/ has
# the real logic.
& adb shell input text "bash%s/data/local/tmp/_deploy_wrapper.sh" 2>&1 | Out-Null
& adb shell input keyevent 66 2>&1 | Out-Null

# ---------- 6. Wait for sentinel ----------
Write-Log "Step 6/6: Waiting for bootstrap to finish (this takes ~1-3 min)..."
$elapsed = 0
$status = $null
while ($elapsed -lt $BOOTSTRAP_TIMEOUT) {
    # Inner 2>/dev/null is the Android shell side. Outer 2>&1 then filtered
    # is the PowerShell side -- stderr from `cat` (when sentinel doesn't exist
    # yet) won't reach us this way.
    $content = & adb shell "cat $SENTINEL 2>/dev/null" 2>&1
    # Filter out ErrorRecord objects in case any leaked through.
    $content = $content | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
    if ($content) {
        $status = ($content | Out-String).Trim()
        if ($status) { break }
    }
    Start-Sleep -Seconds 5
    $elapsed += 5
    Write-Host "    ...$elapsed sec elapsed"
}

if (-not $status) {
    Write-Host ""
    Write-Host "[X] Bootstrap timed out after $BOOTSTRAP_TIMEOUT seconds." -ForegroundColor Red
    Write-Host "    Pulling log..."
    & adb pull $LOG_REMOTE .\bootstrap.log 2>&1 | Out-Null
    if (Test-Path .\bootstrap.log) { Write-Host "    See bootstrap.log in this folder." }
    exit 1
}

if ($status -notlike "OK*") {
    Write-Host ""
    Write-Host "[X] Bootstrap reported failure: $status" -ForegroundColor Red
    & adb pull $LOG_REMOTE .\bootstrap.log 2>&1 | Out-Null
    if (Test-Path .\bootstrap.log) { Write-Host "    See bootstrap.log in this folder." }
    exit 1
}
Write-Ok

# ---------- Restart Termux so Widget can access $PREFIX ----------
# After bootstrap (especially after a previous pm clear), Termux:Widget needs
# Termux to have been cleanly launched at least once. We restart it here so
# the user never hits the "$PREFIX directory not accessible" error.
Write-Log "Finalizing Termux (restarting for Widget compatibility)..."
& adb shell am force-stop com.termux 2>&1 | Out-Null
Start-Sleep -Seconds 2
& adb shell monkey -p com.termux -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Start-Sleep -Seconds 5
& adb shell am force-stop com.termux 2>&1 | Out-Null
Write-Ok

# ---------- All done ----------
Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "  Scanner $serial is ready!"                     -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  ONE last step on the scanner (~30 seconds):" -ForegroundColor Cyan
Write-Host ""
Write-Host "    1. Long-press an empty area of the home screen."
Write-Host "    2. Tap 'Widgets'."
Write-Host "    3. Scroll until you find 'Termux:Widget'."
Write-Host "       (There may be several sizes - pick the WIDEST one.)"
Write-Host "    4. Drag it onto the home screen."
Write-Host "    5. You should see 'RFID Transfer' and 'Clear Inventory'"
Write-Host "       listed inside the widget. Tap to use them."
Write-Host ""
Write-Host "  If the widget shows an error, just re-run this script."
Write-Host ""
Write-Host "  Then unplug. Hand the scanner off to the driver."
Write-Host ""
exit 0
