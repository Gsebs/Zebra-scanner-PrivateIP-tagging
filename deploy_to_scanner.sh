#!/bin/bash

# Configuration
SOURCE_FILES=("sync_and_upload.py" "config.json" "bootstrap_termux.sh")
DEST_DIR="/sdcard/Download/ZebraTag"

echo "=========================================="
echo "Zebra Scanner Deployment Script (Mac/Linux)"
echo "=========================================="

# Check for ADB
if ! command -v adb &> /dev/null; then
    echo "Error: 'adb' command not found."
    echo "Please install Android Platform Tools."
    echo "  Mac: brew install android-platform-tools"
    echo "  Linux: sudo apt install adb"
    exit 1
fi

# Check for connected devices
echo "[*] Checking for connected devices..."
ADB_DEVICES=$(adb devices | grep -v "List of devices attached" | grep "device")

if [ -z "$ADB_DEVICES" ]; then
    echo "Error: No ADB devices found."
    echo "Please ensure:"
    echo "  1. USB Debugging is enabled on the scanner."
    echo "  2. The scanner is connected via USB."
    echo "  3. You have accepted the authorization prompt on the scanner screen."
    exit 1
fi

echo "[*] Device found."

# Create destination directory
echo "[*] Creating target directory on scanner: $DEST_DIR"
adb shell mkdir -p "$DEST_DIR"

# Push files
echo "[*] Pushing files to scanner..."
for file in "${SOURCE_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "    -> Pushing $file"
        adb push "$file" "$DEST_DIR/"
    else
        echo "    ! Warning: Source file '$file' not found in current directory."
    fi
done

echo ""
echo "=========================================="
echo "Deployment Files Transferred!"
echo "=========================================="
echo "Next Steps on the Scanner:"
echo "1. Open Termux."
echo "2. Run the bootstrap commands. You can copy-paste this block:"
echo ""
echo "   cp /sdcard/Download/ZebraTag/bootstrap_termux.sh ~/"
echo "   chmod +x ~/bootstrap_termux.sh"
echo "   ./bootstrap_termux.sh"
echo ""
echo "=========================================="
