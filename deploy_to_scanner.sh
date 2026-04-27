#!/bin/bash
# -----------------------------------------------------------------------------
# Zebra MC33 - one-touch deploy (Mac / Linux).
#
# Connect a scanner via USB with USB Debugging on, run this script. The
# script does everything else, including driving Termux on the scanner via
# ADB input events. The only manual step on the scanner is tapping "Allow"
# on the storage permission popup (Android 14 requirement - unavoidable).
# -----------------------------------------------------------------------------

set -u

# ---------- Configuration ----------
SOURCE_FILES=("sync_and_upload.py" "config.json" "bootstrap_termux.sh")
DEST_DIR="/sdcard/Download/ZebraTag"
SENTINEL="/sdcard/Download/ZebraTag/.bootstrap_done"
LOG_REMOTE="/sdcard/Download/ZebraTag/bootstrap.log"
APK_DIR="vendor"
TERMUX_PKG="com.termux"
WIDGET_PKG="com.termux.widget"
BOOTSTRAP_TIMEOUT=300   # seconds

# ---------- Helpers ----------
log()  { printf "[*] %s\n" "$1"; }
ok()   { printf "    OK\n"; }
fail() { printf "\n[X] %s\n" "$1" >&2; exit 1; }

# Find APK matching a glob in vendor/. Echoes path or empty string.
find_apk() {
    ls -1 "$APK_DIR"/$1 2>/dev/null | head -n1
}

# If a `platform-tools` subfolder exists next to this script, prefer the adb
# from there. This lets users avoid touching their system PATH - they can
# just extract platform-tools.zip into the project folder and go.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_TOOLS="$SCRIPT_DIR/platform-tools"
if [ -x "$LOCAL_TOOLS/adb" ]; then
    export PATH="$LOCAL_TOOLS:$PATH"
fi

echo "=============================================="
echo "  Zebra MC33 Deployment (Mac/Linux)"
echo "=============================================="

# ---------- 1. ADB present? ----------
log "Step 1/6: Checking ADB..."
if ! command -v adb >/dev/null 2>&1; then
    cat <<EOF >&2

[X] 'adb' not found.

Install Android Platform Tools:
  Mac:    brew install android-platform-tools
  Linux:  sudo apt install adb     (or: sudo dnf install android-tools)

Then re-run this script.
EOF
    exit 1
fi
ok

# ---------- 2. Device connected & authorized? ----------
log "Step 2/6: Detecting scanner..."
adb start-server >/dev/null 2>&1

# Find ALL authorized devices, not just the first one. If we silently picked
# the first when there are multiple (e.g. user's phone is also plugged in),
# every subsequent adb call would fail with "more than one device".
AUTHORIZED_DEVICES=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
DEVICE_COUNT=$(echo "$AUTHORIZED_DEVICES" | grep -c . || true)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    UNAUTH=$(adb devices | awk 'NR>1 && $2=="unauthorized" {print; exit}')
    if [ -n "$UNAUTH" ]; then
        fail "Scanner is UNAUTHORIZED. Look at the scanner: tap 'Allow' on the USB-debugging prompt (and tick 'Always allow from this computer'), then re-run this script."
    fi
    fail "No scanner detected. Verify: USB cable plugged in, USB Debugging enabled (Settings -> Developer Options -> USB Debugging ON), and 'Allow' tapped on the scanner."
fi

if [ "$DEVICE_COUNT" -gt 1 ]; then
    echo ""
    echo "[X] Multiple Android devices are connected:" >&2
    echo "$AUTHORIZED_DEVICES" | sed 's/^/      /' >&2
    echo "" >&2
    echo "    Unplug all other devices (phones, tablets, other scanners) and"  >&2
    echo "    leave only the scanner you want to deploy to. Then re-run."     >&2
    exit 1
fi

SERIAL="$AUTHORIZED_DEVICES"
# Pin every subsequent adb call to this exact device, so unrelated devices
# plugging in mid-run can't break things.
export ANDROID_SERIAL="$SERIAL"
printf "    Device: %s\n" "$SERIAL"
ok

# ---------- 3. Termux + Widget APKs ----------
log "Step 3/6: Verifying Termux installation..."

# pm list packages prints lines like 'package:com.termux'
PKG_LIST=$(adb shell pm list packages 2>/dev/null | tr -d '\r')
need_termux=true; need_widget=true
echo "$PKG_LIST" | grep -q "^package:$TERMUX_PKG\$" && need_termux=false
echo "$PKG_LIST" | grep -q "^package:$WIDGET_PKG\$" && need_widget=false

if $need_termux || $need_widget; then
    if [ ! -d "$APK_DIR" ]; then
        fail "APK folder '$APK_DIR/' not found. See vendor/README.md for the two F-Droid links to download from."
    fi

    if $need_termux; then
        APK=$(find_apk "com.termux_*.apk")
        [ -z "$APK" ] && fail "Termux APK not found in $APK_DIR/. See vendor/README.md."
        log "    Installing Termux: $APK"
        if ! adb install -r "$APK" >/dev/null 2>&1; then
            fail "Termux install failed. If Termux from Play Store is installed, uninstall it first (the F-Droid version uses a different signing key). On the scanner: Settings -> Apps -> Termux -> Uninstall."
        fi
    fi
    if $need_widget; then
        APK=$(find_apk "com.termux.widget_*.apk")
        [ -z "$APK" ] && fail "Termux:Widget APK not found in $APK_DIR/."
        log "    Installing Termux:Widget: $APK"
        if ! adb install -r "$APK" >/dev/null 2>&1; then
            fail "Termux:Widget install failed (likely a signing-key conflict - see Termux note above)."
        fi
    fi
fi
ok


# ---------- 3.5 Cleanup bad Android 14 storage state ----------
# If a previous run tried to grant permissions silently via `pm grant`,
# Android 14 can get stuck in a "half-granted" state where termux-setup-storage
# won't prompt the user, but access is still secretly denied by the OS.
# Revoking it forces the permission dialog to appear properly.
log "Step 3.5/6: Resetting Termux permission state..."
adb shell pm revoke com.termux android.permission.READ_EXTERNAL_STORAGE >/dev/null 2>&1 || true
adb shell pm revoke com.termux android.permission.WRITE_EXTERNAL_STORAGE >/dev/null 2>&1 || true
ok

# ---------- 4. Push project files ----------
log "Step 4/6: Pushing project files..."

[ -f "config.json" ] || fail "config.json missing. Copy config_example.json to config.json and fill in your FTP credentials before running this script."

# Validate JSON. Use python3 if available, fall back to a basic check.
if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys; json.load(open('config.json'))" 2>/dev/null \
        || fail "config.json is not valid JSON. Fix the syntax and re-run."
fi

adb shell mkdir -p "$DEST_DIR" >/dev/null
for f in "${SOURCE_FILES[@]}"; do
    [ -f "$f" ] || fail "Missing source file: $f"
    adb push "$f" "$DEST_DIR/" >/dev/null || fail "Push failed: $f"
done
# Wipe any stale sentinel from a previous run before we kick off bootstrap.
adb shell rm -f "$SENTINEL" >/dev/null 2>&1
ok

# ---------- 5. Launch Termux + run bootstrap ----------
log "Step 5/6: Running bootstrap on the scanner..."
cat <<'EOF'

    -------------------------------------------------------------
    LOOK AT THE SCANNER NOW.

    Termux is being launched. An Android storage-permission
    popup will appear - TAP "ALLOW" on the scanner.
    (This is unavoidable on Android 14 and only needed once
     per scanner.)
    -------------------------------------------------------------

EOF

# Force-stop Termux so we get a clean shell prompt and `input text` lands
# in the right place. monkey is a reliable way to launch the launcher
# activity without knowing its exact name.
adb shell am force-stop com.termux >/dev/null 2>&1 || true
sleep 1
adb shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
adb shell monkey -p com.termux -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 4

# Type the bootstrap command. Note: `input text` interprets %s as space;
# our path has no other special characters so this is safe.
adb shell input text "termux-setup-storage;%swhile%s!%sls%s$DEST_DIR%s>%s/dev/null%s2>&1;%sdo%ssleep%s1;%sdone;%sbash%s$DEST_DIR/bootstrap_termux.sh" >/dev/null
adb shell input keyevent 66 >/dev/null   # 66 = ENTER

# ---------- 6. Wait for sentinel ----------
log "Step 6/6: Waiting for bootstrap to finish (this takes ~1-3 min)..."
ELAPSED=0
STATUS=""
while [ "$ELAPSED" -lt "$BOOTSTRAP_TIMEOUT" ]; do
    # Check the sentinel exists AND is non-empty (file is created empty for
    # a brief moment by `> $SENTINEL`, so we wait until it has content).
    SENTINEL_CONTENT=$(adb shell "cat $SENTINEL 2>/dev/null" 2>/dev/null | tr -d '\r\n')
    if [ -n "$SENTINEL_CONTENT" ]; then
        STATUS="$SENTINEL_CONTENT"
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    printf "    ...%ds elapsed\n" "$ELAPSED"
done

if [ -z "$STATUS" ]; then
    echo ""
    echo "[X] Bootstrap timed out after ${BOOTSTRAP_TIMEOUT}s."
    echo "    Pulling log so you can see what happened..."
    adb pull "$LOG_REMOTE" ./bootstrap.log >/dev/null 2>&1 || true
    [ -f bootstrap.log ] && echo "    See bootstrap.log in this folder."
    exit 1
fi

if [[ "$STATUS" != OK* ]]; then
    echo ""
    echo "[X] Bootstrap reported failure: $STATUS"
    adb pull "$LOG_REMOTE" ./bootstrap.log >/dev/null 2>&1 || true
    [ -f bootstrap.log ] && echo "    See bootstrap.log in this folder."
    exit 1
fi
ok

# ---------- All done ----------
echo ""
echo "=============================================="
echo "  Scanner $SERIAL is ready."
echo "=============================================="
echo ""
echo "  ONE last manual step on the scanner (~30 seconds):"
echo "    1. Long-press an empty area of the home screen."
echo "    2. Tap 'Widgets'."
echo "    3. Find 'Termux:Widget'."
echo "    4. Drag 'RFID Transfer' onto the home screen."
echo "    5. (Optional) Drag 'Clear Inventory' too."
echo ""
echo "  Then unplug. Hand the scanner off to the driver."
echo ""
exit 0
