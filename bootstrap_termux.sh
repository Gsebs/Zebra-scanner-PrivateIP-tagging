#!/data/data/com.termux/files/usr/bin/bash

# Configuration
SOURCE_DIR="/sdcard/Download/ZebraTag"
INSTALL_DIR="$HOME/ZebraTag"
SHORTCUT_DIR="$HOME/.shortcuts"
SHORTCUT_SCRIPT="$SHORTCUT_DIR/RFID Transfer.sh"

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

# 5. Create Widget Shortcuts
echo "[*] Creating Home Screen Widget Shortcuts..."
mkdir -p "$SHORTCUT_DIR"

# --- WIDGET 1: RFID Transfer (Sync) ---
SYNC_SHORTCUT="$SHORTCUT_DIR/RFID Transfer.sh"
cat <<EOF > "$SYNC_SHORTCUT"
#!/data/data/com.termux/files/usr/bin/bash
# Enable access to shared storage (Already done in setup, but kept commented just in case)
# termux-setup-storage

# Clear screen for readability
clear

echo "================================="
echo "   Zebra Scanner Sync"
echo "================================="

# Navigate to script folder
cd "$INSTALL_DIR"

# CHANGE THIS IF YOUR SCAN FOLDER IS DIFFERENT
TARGET_SCAN_DIR="/sdcard/Inventory" 

echo "[*] Target Directory: \$TARGET_SCAN_DIR"
echo "[*] Running Sync..."

# Run without arguments first, script handles interaction
python sync_and_upload.py "\$TARGET_SCAN_DIR"

echo ""
echo "================================="
echo "Done. Press Enter to close and return to Home Screen."
read

# Return to Android Home Screen
am start -a android.intent.action.MAIN -c android.intent.category.HOME > /dev/null 2>&1
exit
EOF

# --- WIDGET 2: Clear Inventory (Reset) ---
RESET_SHORTCUT="$SHORTCUT_DIR/Clear Inventory.sh"
cat <<EOF > "$RESET_SHORTCUT"
#!/data/data/com.termux/files/usr/bin/bash

clear
echo "================================="
echo "   CLEAR INVENTORY"
echo "================================="
echo "This will DELETE ALL FILES in the inventory folder."

cd "$INSTALL_DIR"
TARGET_SCAN_DIR="/sdcard/Inventory" 

echo "[*] Directory: \$TARGET_SCAN_DIR"
echo "[*] Cleaning up..."

python sync_and_upload.py "\$TARGET_SCAN_DIR" --action reset

echo ""
echo "================================="
echo "Done. Press Enter to return."
read

am start -a android.intent.action.MAIN -c android.intent.category.HOME > /dev/null 2>&1
exit
EOF

# Make executable
chmod +x "$SYNC_SHORTCUT"
chmod +x "$RESET_SHORTCUT"
chmod +x "$INSTALL_DIR/sync_and_upload.py"

echo "    -> Shortcut 1 created: $SYNC_SHORTCUT"
echo "    -> Shortcut 2 created: $RESET_SHORTCUT"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo "Instructions:"
echo "1. Go to your Android Home Screen."
echo "2. LONG PRESS on empty space -> Widgets."
echo "3. Add 'Termux:Widget' -> Select 'RFID Transfer'."
echo "4. Add 'Termux:Widget' -> Select 'Clear Inventory'."
echo "=========================================="
