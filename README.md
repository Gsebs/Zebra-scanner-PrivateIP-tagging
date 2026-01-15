# Zebra Scanner IP Tagger & FTP Sync

This project provides a "one-click" solution to tag files on a Zebra MC33 scanner with the device's Private IP address and upload them to an FTP server.

## Features
- **Auto-IP Detection**: Automatically finds the scanner's Private IP on the current network.
- **Smart Renaming**: Appends the IP to filenames (e.g., `scan.txt` -> `scan_192.168.1.50.txt`). Prevents double-tagging.
- **FTP Sync**: Uploads renamed files to your specified FTP server.
- **One-Click Widget**: Runs directly from the Android home screen via Termux:Widget.
- **Cross-Platform Deploy**: Easy setup scripts for Mac and Windows.

---

## Prerequisites (Scanner Side)
Before deploying, install these two apps on your Zebra MC33 (via Play Store, F-Droid, or ADB):

1.  **Termux** (The environment to run the script)
2.  **Termux:Widget** (To create the home screen shortcut)
3.  **Termux:API** (Optional, but good to have)

> **Note**: You do *not* need to open or configure them yet. The scripts handles the setup.

---

## 1. Setup Configuration
**IMPORTANT**: You must add your FTP credentials before deploying.

1.  **Duplicate the Template**: Copy `config_example.json` and name it `config.json`.
    ```bash
    cp config_example.json config.json
    ```
2.  Open `config.json` in a text editor.
3.  Fill in your `ftp_server`, `ftp_user`, and `ftp_password`.

```json
{
    "ftp_server": "ftp.example.com",  <-- Your FTP Server Name OR IP Address
    "ftp_user": "admin",            <-- Your Username
    "ftp_password": "securepass",   <-- Your Password
    "ftp_port": 21
}
```

---

## 2. Deploy to Scanner

### A. From Mac / Linux
1.  **Enable USB Debugging on Scanner** (Critical Step):
    *   Go to **Settings > About phone**.
    *   Tap **Build number** 7 times until it says "You are a developer".
    *   Go back to **Settings > System > Developer options**.
    *   Turn **ON** `USB debugging`.
2.  Connect the scanner via USB.
3.  **Verify Connection**:
    *   Run `adb devices` in Terminal.
    *   **Look at the scanner screen!** Tap **"Allow"** (Check "Always allow from this computer").
    *   Run `adb devices` again. It must say `device` (not `unauthorized`).
4.  Run the deployment script:
    ```bash
    cd /path/to/extracted/folder
    chmod +x deploy_to_scanner.sh
    ./deploy_to_scanner.sh
    ```

### B. From Windows
1.  **Install ADB (One-time setup)**:
    *   Download [SDK Platform-Tools for Windows](https://developer.android.com/studio/releases/platform-tools).
    *   Extract the zip file to a folder (e.g., `C:\platform-tools`).
    *   **Crucial**: Copy `deploy_to_scanner.bat` and all project files INTO that `platform-tools` folder (so they are next to `adb.exe`).
2.  **Enable USB Debugging on Scanner** (Critical Step):
    *   Go to **Settings > About phone**.
    *   Tap **Build number** 7 times.
    *   Go back to **Settings > System > Developer options**.
    *   Turn **ON** `USB debugging`.
3.  Connect the scanner via USB.
4.  **Run the Script**:
    *   Open the folder in File Explorer.
    *   **Double-click** the file named `deploy_to_scanner.bat`.
    *   A black window will appear and transfer the files. It will pause at the end to show you the result.

> **Success?** You should see "Deployment Files Transferred!" and instructions for the next step.

---

## 3. Finalize on Scanner
Perform these steps once on the device itself.

1.  Open the **Termux** app on the scanner.
2.  The deployment script output gave you a command block. allow file access if prompted.
3.  Run the bootstrap script by typing (or pasting) (login to Gmail on scanner and send this code snippet to the scanner via email. Then copy the code snippet from the email and paste it into Termux on the scanner):
    ```bash
    cp /sdcard/Download/ZebraTag/bootstrap_termux.sh ~/
    chmod +x ~/bootstrap_termux.sh
    ./bootstrap_termux.sh
    ```
    *(Note: You can type these 3 lines manually if copy-paste is hard).*

4.  Wait for it to finish. It will install Python and set up the shortcut.

---

## 4. Add the Widgets (User Guide)
You now have **TWO** widgets available:

### Widget 1: RFID Transfer
Used to tag and upload files.
1.  **Long Press** Home Screen -> Widgets -> **Termux:Widget**.
2.  Select **`RFID Transfer`**.
3.  **Flow**:
    *   It detects your IP and Subnet.
    *   It identifies the **Store Number** (from the Subnet's 2nd number).
    *   It asks: *"Is Store Number 345 correct? (y/n)"*.
        *   **Yes (y)**: Uses 345.
        *   **No (n)**: You type the correct number manually.
    *   **No Wi-Fi?**: It forces you to type the Store Number.
    *   **Result**: Files are renamed to `STORE_345_IP_10.345..._File.txt`.
    *   **Upload**: Files are uploaded to `/rfidscan/autoscan/inventory`.
    *   **Cleanup**: Local files are **deleted** after a successful upload.

### Widget 2: Clear Inventory
Used to **EMPTY** the scan folder.
1.  Add another **Termux:Widget** to the screen.
2.  Select **`Clear Inventory`**.
3.  It will prompt: *"Are you sure?"*
4.  If you type `y`, it **PERMANENTLY DELETES** all files in the folder.

---

## Changing the Target Directory
By default, the widget scans `/sdcard/TestScanDocument`. If you need to scan a different folder (e.g., for a specific department or scanner), follow these steps:

1.  **Edit the Script**:
    *   Open `bootstrap_termux.sh` on your computer.
    *   Find the line: `TARGET_SCAN_DIR="/sdcard/TestScanDocument"`
    *   Change it to your desired path.
        ```bash
        TARGET_SCAN_DIR="/sdcard/MyNewScanFolder"
        ```


2.  **Push the Update (From Computer)**:
    *   Connect the scanner via USB.
    *   Run the deployment script again to push the new file:
    *   **Mac/Linux**:
        ```bash
        ./deploy_to_scanner.sh
        ```
    *   **Windows**: Double-click `deploy_to_scanner.bat`

3.  **Apply the Update (On Scanner)**:
    *   Open the **Termux** app on the scanner.
    *   Run the installer again to update the widget:
        ```bash
        ./bootstrap_termux.sh
        ```
    *   **Important**: If it asks "Overwrite?", type `y` and press Enter.

The widget is now updated! You do **not** need to delete or re-add the widget icon; it will automatically use the new path next time you tap it.


## Renaming the Widget
By default, the widget is named `ZebraSync`. To change it to something custom like **"RFID Transfer"**, you have two options:

### Option A: Edit the source code (Permanent)
1.  Open `bootstrap_termux.sh` on your computer.
2.  Find the line: `SHORTCUT_SCRIPT="$SHORTCUT_DIR/ZebraSync.sh"`
3.  Change it to: `SHORTCUT_SCRIPT="$SHORTCUT_DIR/RFID Transfer.sh"`
4.  Run the deployment steps again (Redeploy -> Update Widget).

### Option B: Rename on the Scanner (Quick)
1.  Open the **Termux** app.
2.  Type this command to move the file:
    ```bash
    mv ~/.shortcuts/ZebraSync.sh "~/.shortcuts/RFID Transfer.sh"
    ```
3.  Go to the Home Screen, remove the old widget, and add the new one. Use quotes if there are spaces in the name!

## Troubleshooting
- **"ADB not found"**: Install Android Platform Tools.
    - Mac: `brew install android-platform-tools`
    - Windows: [Download here](https://developer.android.com/studio/releases/platform-tools)
- **Widget shows "Permission Denied"**: Open Termux and run `termux-setup-storage` again, then accept the popup.
- **Files not uploading**: Check `config.json` for typos in the password or server address. Check if the scanner has Wi-Fi.
- **FTP Error: "No address associated with hostname"**:
    *   This happens if you use a `.local` domain (like `server.local`) and the scanner's Android version doesn't support mDNS.
    *   **Fix**: Use the **IP Address** of the server instead (e.g., `192.168.1.50`).
    *   Ask your IT admin for the static IP of the server.
- **FTP Timeout Error**:
    *   **Firewall**: The server might be blocking the connection. Ask IT to allow the scanner's IP or subnet.
    *   **Passive Mode**: Python uses Passive Mode by default. If your server requires Active Mode, IT needs to open the passive port range on the server side.
    *   **Wi-Fi Strength**: Weak signal can cause timeouts during large uploads. Verify signal strength.
