#!/data/data/com.termux/files/usr/bin/bash
# -----------------------------------------------------------------------------
# Zebra MC33 - bootstrap (runs ON the scanner inside Termux).
#
# This script is launched by the computer-side deploy script via `adb shell
# input text`. It must run completely non-interactively.
#
# When it finishes (success OR failure) it writes a one-line status to
# /sdcard/Download/ZebraTag/.bootstrap_done. The deploy script polls for that
# file to know the work is finished.
# -----------------------------------------------------------------------------

set -u

SOURCE_DIR="/sdcard/Download/ZebraTag"
INSTALL_DIR="$HOME/ZebraTag"
SHORTCUT_DIR="$HOME/.shortcuts"
SENTINEL="/sdcard/Download/ZebraTag/.bootstrap_done"
LOG="/sdcard/Download/ZebraTag/bootstrap.log"

# Reset sentinel + log so we don't read a stale value on rerun
rm -f "$SENTINEL" "$LOG" 2>/dev/null

# Tee everything to the log file. The computer-side deploy script will pull
# this if anything goes wrong.
exec > >(tee -a "$LOG") 2>&1

write_status() { echo "$1" > "$SENTINEL"; }

echo "=============================================="
echo "      Zebra Scanner Bootstrap"
echo "      $(date)"
echo "=============================================="

# -----------------------------------------------------------------------------
# 1. Storage permission. The deploy wrapper (_deploy_wrapper.sh) handles the
#    initial permission request. This step just verifies storage is accessible.
#    If it's already set up, we skip termux-setup-storage entirely to avoid
#    the interactive "Do you want to continue? (y/n)" prompt.
# -----------------------------------------------------------------------------
echo "[1/5] Verifying storage access..."
if [ -d "$HOME/storage/shared" ]; then
    echo "      Storage already configured."
else
    echo "      Requesting storage permission..."
    termux-setup-storage
    WAIT=0
    while [ ! -d "$HOME/storage/shared" ] && [ "$WAIT" -lt 60 ]; do
        sleep 2
        WAIT=$((WAIT + 2))
    done
    if [ ! -d "$HOME/storage/shared" ]; then
        echo "ERROR: storage permission was not granted within 60s."
        echo "       Tap Allow on the popup and re-run the deploy script."
        write_status "FAIL: storage permission not granted"
        exit 1
    fi
fi
echo "      OK"

# -----------------------------------------------------------------------------
# 2. Enable Termux external-app control. After this, future updates can be
#    pushed by the computer via `am broadcast` instead of input-event hacks.
# -----------------------------------------------------------------------------
echo "[2/5] Configuring termux.properties..."
mkdir -p "$HOME/.termux"
PROPS="$HOME/.termux/termux.properties"
touch "$PROPS"
if ! grep -q "^allow-external-apps" "$PROPS"; then
    echo "allow-external-apps = true" >> "$PROPS"
fi
echo "      OK"

# -----------------------------------------------------------------------------
# 3. Install Python. `yes |` answers any prompts; `pkg` rarely asks but it
#    has been known to ask about config files on update.
# -----------------------------------------------------------------------------
echo "[3/5] Installing Python (this can take a minute)..."
yes | pkg update -y >/dev/null 2>&1 || true
if ! yes | pkg install python -y; then
    echo "ERROR: pkg install python failed. Check Wi-Fi on the scanner."
    write_status "FAIL: python install"
    exit 1
fi
if ! command -v python >/dev/null; then
    echo "ERROR: python not found on PATH after install."
    write_status "FAIL: python missing"
    exit 1
fi
echo "      OK ($(python --version 2>&1))"

# -----------------------------------------------------------------------------
# 4. Copy code + config into the install dir. config.json is chmod 600 so
#    other apps on the device can't read the FTP password.
# -----------------------------------------------------------------------------
echo "[4/5] Installing files to $INSTALL_DIR..."
if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: source dir '$SOURCE_DIR' missing."
    echo "       The deploy script should have pushed files here first."
    write_status "FAIL: source dir missing"
    exit 1
fi
mkdir -p "$INSTALL_DIR"
cp -f "$SOURCE_DIR/sync_and_upload.py" "$INSTALL_DIR/"
cp -f "$SOURCE_DIR/config.json"        "$INSTALL_DIR/"
chmod 600 "$INSTALL_DIR/config.json"
chmod +x "$INSTALL_DIR/sync_and_upload.py"
echo "      OK"

# -----------------------------------------------------------------------------
# 5. Create the home-screen widget shortcuts. Termux:Widget reads from
#    ~/.shortcuts/ and shows every .sh file there as a tappable widget.
#
#    Inside the heredoc:
#      $INSTALL_DIR  -> expanded NOW (so the literal path is baked into the
#                       shortcut script).
#      No \$VAR references - we don't need any runtime expansion.
# -----------------------------------------------------------------------------
echo "[5/5] Creating widget shortcuts..."
mkdir -p "$SHORTCUT_DIR"

# --- RFID Transfer ---
cat > "$SHORTCUT_DIR/RFID Transfer.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
clear
echo "================================="
echo "        RFID Transfer"
echo "================================="
if [ ! -d "$INSTALL_DIR" ]; then
    echo ""
    echo "ERROR: Install directory not found."
    echo "       ($INSTALL_DIR)"
    echo ""
    echo "Re-run the deploy script from the computer"
    echo "to fix this."
    echo ""
    read -t 30 -r _ || true
    exit 1
fi
cd "$INSTALL_DIR"
python sync_and_upload.py
echo
echo "================================="
echo "Done. Press Enter to return to home screen."
echo "(Auto-returns in 60 seconds.)"
read -t 60 -r _ || true
am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null 2>&1
exit 0
EOF

# --- Clear Inventory ---
cat > "$SHORTCUT_DIR/Clear Inventory.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
clear
echo "================================="
echo "       CLEAR INVENTORY"
echo "================================="
if [ ! -d "$INSTALL_DIR" ]; then
    echo ""
    echo "ERROR: Install directory not found."
    echo "       ($INSTALL_DIR)"
    echo ""
    echo "Re-run the deploy script from the computer"
    echo "to fix this."
    echo ""
    read -t 30 -r _ || true
    exit 1
fi
echo "This will DELETE ALL FILES in the inventory folder."
cd "$INSTALL_DIR"
python sync_and_upload.py --action reset
echo
echo "================================="
echo "Done. Press Enter to return to home screen."
echo "(Auto-returns in 60 seconds.)"
read -t 60 -r _ || true
am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null 2>&1
exit 0
EOF

chmod +x "$SHORTCUT_DIR"/*.sh
echo "      OK"

# -----------------------------------------------------------------------------
# Done.
# -----------------------------------------------------------------------------
write_status "OK"

echo ""
echo "=============================================="
echo "  Bootstrap complete."
echo "=============================================="
echo "  On the scanner:"
echo "    1. Long-press home screen -> Widgets"
echo "    2. Find 'Termux:Widget'"
echo "    3. Drag 'RFID Transfer' onto the home screen"
echo "    4. (Optional) Drag 'Clear Inventory' too"
echo "=============================================="
exit 0
