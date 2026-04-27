#!/data/data/com.termux/files/usr/bin/bash
# -----------------------------------------------------------------------------
# Deploy wrapper - "trampoline" script that runs INSIDE Termux.
#
# Pushed to /data/local/tmp/ by the deploy script so Termux can read it
# WITHOUT storage permission (solving the chicken-and-egg problem).
#
# This script:
#   1. Removes stale ~/storage to prevent y/n prompt
#   2. Runs termux-setup-storage (shows Android permission popup)
#   3. Waits for the user to tap "Allow"
#   4. Hands off to the main bootstrap script on /sdcard
# -----------------------------------------------------------------------------

BOOTSTRAP="/sdcard/Download/ZebraTag/bootstrap_termux.sh"

echo ""
echo "=============================================="
echo "  Deploy Wrapper"
echo "=============================================="
echo ""

# Remove stale storage symlinks to prevent the
# "Do you want to continue? (y/n)" interactive prompt
rm -rf ~/storage 2>/dev/null

# Request storage permission.
# If already granted: creates symlinks instantly, no popup.
# If not granted: shows the Android permission popup.
echo "[*] Requesting storage permission..."
echo "    If a popup appeared, tap ALLOW on the screen."
echo ""
termux-setup-storage

# Wait for the user to tap Allow (or for instant grant)
WAIT=0
while [ ! -d "$HOME/storage/shared" ] && [ "$WAIT" -lt 120 ]; do
    sleep 2
    WAIT=$((WAIT + 2))
done

if [ ! -d "$HOME/storage/shared" ]; then
    echo ""
    echo "[X] ERROR: Storage permission was not granted within 120 seconds."
    echo "    Please re-run the deploy script and tap ALLOW when prompted."
    exit 1
fi

echo "    Storage access OK."
echo ""

# Verify the bootstrap script is actually readable
if [ ! -f "$BOOTSTRAP" ]; then
    echo "[X] ERROR: Cannot find $BOOTSTRAP"
    echo "    The deploy script should have pushed it. Re-run deploy."
    exit 1
fi

echo "[*] Launching bootstrap..."
echo ""
# exec replaces this process with the bootstrap, so output stays clean
exec bash "$BOOTSTRAP"
