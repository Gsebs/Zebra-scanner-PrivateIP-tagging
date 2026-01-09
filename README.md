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
1.  **Enable USB Debugging on Scanner** (Critical Step):
    *   Go to **Settings > About phone**.
    *   Tap **Build number** 7 times.
    *   Go back to **Settings > System > Developer options**.
    *   Turn **ON** `USB debugging`.
2.  Connect the scanner via USB.
3.  **Verify Connection**:
    *   Run `adb devices` in Command Prompt.
    *   **Look at the scanner screen!** Tap **"Allow"** (Check "Always allow from this computer").
    *   Ensure it says `device`.
4.  Double-click **`deploy_to_scanner.bat`**.

> **Success?** You should see "Deployment Files Transferred!" and instructions for the next step.

---

## 3. Finalize on Scanner
Perform these steps once on the device itself.

1.  Open the **Termux** app on the scanner.
2.  The deployment script output gave you a command block. allow file access if prompted.
3.  Run the bootstrap script by typing (or pasting):
    ```bash
    cp /sdcard/Download/ZebraTag/bootstrap_termux.sh ~/
    chmod +x ~/bootstrap_termux.sh
    ./bootstrap_termux.sh
    ```
    *(Note: You can type these 3 lines manually if copy-paste is hard).*

4.  Wait for it to finish. It will install Python and set up the shortcut.

---

## 4. Add the Widget (User Guide)
This is what the daily operator will do.

1.  Go to the Android Home Screen.
2.  **Long Press** on an empty space -> Select **Widgets**.
3.  Scroll down to **Termux:Widget**.
4.  Drag the widget to the home screen.
5.  A list will appear. Select **`ZebraSync`**.

**Done!** Now, whenever you want to sync:
1.  Scan your items.
2.  Tap the **ZebraSync** widget icon.
3.  A window will pop up, rename the files with the current IP, upload them, and close.

---

## Advanced: Changing the Target Directory
By default, the widget scans `/sdcard/TestScanDocument`. If you need to scan a different folder (e.g., for a specific department or scanner), follow these steps:

1.  **Edit the Script**:
    *   Open `bootstrap_termux.sh` on your computer.
    *   Find the line: `TARGET_SCAN_DIR="/sdcard/TestScanDocument"`
    *   Change it to your desired path.
        ```bash
        TARGET_SCAN_DIR="/sdcard/MyNewScanFolder"
        ```

2.  **Redeploy**:
    *   Run `./deploy_to_scanner.sh` (Mac) or `deploy_to_scanner.bat` (Windows).

3.  **Update the Widget**:
    *   Open **Termux** on the scanner.
    *   Run: `./bootstrap_termux.sh`
    *   Type `y` if asked to overwrite.

The widget will now point to the new folder!

## Troubleshooting
- **"ADB not found"**: Install Android Platform Tools.
    - Mac: `brew install android-platform-tools`
    - Windows: [Download here](https://developer.android.com/studio/releases/platform-tools)
- **Widget shows "Permission Denied"**: Open Termux and run `termux-setup-storage` again, then accept the popup.
- **Files not uploading**: Check `config.json` for typos in the password or server address. Check if the scanner has Wi-Fi.
