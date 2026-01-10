#!/data/data/com.termux/files/usr/bin/bash

# Configuration
SOURCE_DIR="/sdcard/Download/ZebraTag"
INSTALL_DIR="$HOME/ZebraTag"
SHORTCUT_DIR="$HOME/.shortcuts"
SHORTCUT_SCRIPT="$SHORTCUT_DIR/ZebraSync.sh"

echo "=========================================="
echo "      Zebra Scanner Setup (Termux)"
echo "=========================================="

# 1. Setup Storage
echo "[*] Setting up storage access..."
termux-setup-storage
echo "    -> Please tap 'Allow' on the permission popup if it appears."
echo "    -> Sleeping for 5 seconds to allow permission propagation..."
sleep 5

# 2. Install Dependencies
echo "[*] Installing Python..."
pkg update -y && pkg install python -y
if [ $? -ne 0 ]; then
    echo "Error: Failed to install Python. Check your internet connection."
    exit 1
fi

# 3. Create Install Directory
echo "[*] Setting up installation folder: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# 4. Copy Files
echo "[*] Copying files..."
if [ -d "$SOURCE_DIR" ]; then
    cp "$SOURCE_DIR/sync_and_upload.py" "$INSTALL_DIR/"
    cp "$SOURCE_DIR/config.json" "$INSTALL_DIR/"
    echo "    -> Files copied to $INSTALL_DIR"
else
    echo "Error: Source directory $SOURCE_DIR not found. Did you run the deploy script from your computer?"
    exit 1
fi

# 5. Create Widget Shortcut
echo "[*] Creating Home Screen Widget Shortcut..."
mkdir -p "$SHORTCUT_DIR"

# Write the launcher script
cat <<EOF > "$SHORTCUT_SCRIPT"
#!/data/data/com.termux/files/usr/bin/bash
# Enable access to shared storage
# Enable access to shared storage (Already done in setup, but kept commented just in case)
# termux-setup-storage

# Clear screen for readability
clear

echo "================================="
echo "   Zebra Scanner Sync"
echo "================================="

# Navigate to script folder
cd "$INSTALL_DIR"

# Run the python script
# Change '/sdcard/ScanDocuments' to your actual target directory
TARGET_SCAN_DIR="/sdcard/TestScanDocument" 

echo "[*] Target Directory: \$TARGET_SCAN_DIR"
echo "[*] Running Sync..."

python sync_and_upload.py "\$TARGET_SCAN_DIR"

echo ""
echo "================================="
echo "Done. Press Enter to close."
read
EOF

# Make executable
chmod +x "$SHORTCUT_SCRIPT"
chmod +x "$INSTALL_DIR/sync_and_upload.py"

echo "    -> Shortcut created at $SHORTCUT_SCRIPT"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo "Instructions:"
echo "1. Go to your Android Home Screen."
echo "2. LONG PRESS on empty space -> Widgets."
echo "3. Find 'Termux:Widget' and drag it to the screen."
echo "4. You should see 'ZebraSync' in the list."
echo "5. Tap it to test!"
echo "=========================================="
