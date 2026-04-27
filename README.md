# Zebra MC33 — IP Tagger & FTP Sync

Naming System for Zebra MC33 scanners: tags inventory files with the
scanner's IP and store number, then uploads them to a central FTP server.


---

## How it works (1-minute version)

```
+------------------+        ADB over USB         +-------------------+
|   Your laptop    |  ---------------------->    |   Zebra MC33      |
|   (Mac/Windows)  |    deploy_to_scanner        |   scanner         |
+------------------+                              +-------------------+
                                                          |
                                                  driver taps widget
                                                          |
                                                          v
                                                   +-------------+
                                                   | FTP server  |
                                                   +-------------+
```

**On the laptop (one-time):** install ADB, download two APKs, fill in
`config.json`. Done forever.

**On the laptop (per scanner):** plug it in, run one script, walk away.
~3 minutes per scanner.

**On the scanner (per use):** driver taps the **RFID Transfer** widget.
Confirms or types the store number. Sees a success message. Returns to home
screen. Done.

---

## What's in this folder

| File                       | Who uses it      | What it is                                                     |
|----------------------------|------------------|----------------------------------------------------------------|
| `deploy_to_scanner.sh`     | IT (Mac/Linux)   | The one-touch deploy script.                                   |
| `deploy_to_scanner.bat`    | IT (Windows)     | Double-click to deploy. Calls the PowerShell file below.       |
| `deploy_to_scanner.ps1`    | (called by .bat) | The actual Windows logic.                                      |
| `bootstrap_termux.sh`      | (auto-run)       | Runs on the scanner during setup. Don't run by hand.           |
| `sync_and_upload.py`       | (auto-run)       | The actual tag + upload logic. Runs on the scanner.            |
| `config_example.json`      | IT               | Template for your FTP credentials.                             |
| `config.json`              | IT               | Your real credentials. **You** create this. Git-ignored.       |
| `vendor/`                  | IT               | Where you place the Termux APKs. See `vendor/README.md`.       |
| `.gitignore`               | -                | Keeps secrets and APKs out of version control.                 |

---

#Instructions

## Part 1 — One-time setup (do this once, ever)

You do this once on the laptop you'll use for all deployments. It does not
need to be repeated for each scanner.

### 1.1 Install ADB

ADB (Android Debug Bridge) is the cable-side tool that lets your laptop talk
to the scanner. Without it, none of this works.

**Mac:**
```bash
brew install android-platform-tools
```
Verify by running this in terminal: `adb version`

**Linux:**
```bash
sudo apt install adb        # Debian/Ubuntu
sudo dnf install android-tools   # Fedora
```
Verify by running this in terminal: `adb version`

**Windows:**
1. Download Platform Tools: https://developer.android.com/studio/releases/platform-tools
2. Extract the zip somewhere (suggested: `C:\platform-tools`).
3. Add that folder to your PATH:
   - Press Start, type "Edit environment variables", open it.
   - Click **Environment Variables…**.
   - In **System variables**, select **Path** → **Edit** → **New** → paste
     `C:\platform-tools` → OK → OK → OK.
4. Open a **new** Command Prompt and verify: `adb version`.

### 1.2 Download the Termux APKs

The deploy script auto-installs Termux on each scanner — but it needs the
APK files in `vendor/`. Read `vendor/README.md` for the two F-Droid links
(it takes ~30 seconds).

### 1.3 Create your `config.json`

Copy the template:

**Mac/Linux:**
```bash
cp config_example.json config.json
```

**Windows:** copy `config_example.json` to `config.json` in File Explorer.

Open `config.json` in a text editor and fill in your real values:

```json
{
    "ftp_server": "192.168.10.50",
    "ftp_user": "rfid_uploader",
    "ftp_password": "your_password_here",
    "ftp_port": 21,
    "ftp_target_dir": "/rfidscan/autoscan/inventory",
    "scan_dir": "/sdcard/Inventory"
}
```

| Field            | What it is                                                                                |
|------------------|-------------------------------------------------------------------------------------------|
| `ftp_server`     | Hostname or IP of the FTP server. Prefer a numeric IP — `.local` mDNS hostnames often fail. |
| `ftp_user`       | FTP username                                                                              |
| `ftp_password`   | FTP password                                                                              |
| `ftp_port`       | FTP port (almost always 21)                                                               |
| `ftp_target_dir` | The remote folder. Default `/rfidscan/autoscan/inventory`. Missing folders are auto-created. |
| `scan_dir`       | The folder on the scanner that holds files to be tagged & uploaded. Default `/sdcard/Inventory`. |

> **`config.json` is git-ignored.** Don't commit it. Treat it like a password file.

> **Need to change `scan_dir` or `ftp_target_dir` later?** Edit
> `config.json` once on your laptop, then re-run the deploy script for each
> scanner. You never edit code.

That's it for one-time setup. Move on to Part 2.

---

## Part 2 — Per-scanner setup (~3 min each)

Repeat this for every scanner you want to deploy to.

### 2.1 Enable USB Debugging on the scanner (one time per scanner)

1. Open **Settings** → **About phone**.
2. Tap **Build number** seven times. You'll see "You are now a developer."
3. Go back → **System** → **Developer options**.
4. Toggle **USB debugging** ON.

### 2.2 Connect & deploy

1. Plug the scanner into your laptop with a USB cable.
2. **Look at the scanner.** A "Allow USB Debugging?" prompt appears the
   first time. Tick **"Always allow from this computer"** and tap **Allow**.
3. Run the deploy script:

   **Mac/Linux:**
   ```bash
   chmod +x deploy_to_scanner.sh
   ./deploy_to_scanner.sh
   ```

   **Windows:** double-click `deploy_to_scanner.bat`.

4. **Watch the scanner during step 5/6 of the script.** Termux will request
   storage permission — **TAP "ALLOW"** on the scanner. This is the only
   manual interaction with the scanner during setup. (Required by Android
   14's scoped storage rules — there is no way to grant this from the
   laptop.)

5. Wait. The script runs through 6 steps (~1-3 minutes). It ends with:
   ```
   ==============================================
     Scanner XXXX is ready.
   ==============================================
   ```

### 2.3 Add the home-screen widgets (one time per scanner)

After the script prints "Scanner ready", do this on the scanner:

1. Long-press an empty area of the home screen.
2. Tap **Widgets**.
3. Find **Termux:Widget**.
4. Drag **RFID Transfer** onto the home screen.
5. (Optional but recommended) Drag **Clear Inventory** onto the home screen
   too.

> Why is this step manual? Android does not let an app place its own widget
> on the home screen — that has to be a user gesture. It's a 30-second job.

Unplug the scanner. It's ready for the driver.

---

## Part 3 — Driver guide

Print this paragraph and tape it to the scanner cradle if you want:

> **To upload your scans:** Tap the **RFID Transfer** widget. The scanner
> figures out your store number from the Wi-Fi automatically. If the store
> number it shows is correct, type **y** and press Enter. If it's wrong (or
> there's no Wi-Fi), type **n** and enter the store number yourself. Wait
> for "Process complete." Press Enter to return to the home screen.
>
> **To wipe the inventory folder:** Tap the **Clear Inventory** widget. It
> will ask "Are you sure?". Type **y** to confirm.

That's the entire driver-side experience.

---

## Updating an already-deployed scanner

Need to change the FTP server, change the scan folder, or push a code fix
out to scanners that already have the widget on them?

1. Edit `config.json` (or the relevant code file) on your laptop.
2. Run the deploy script for each scanner just like Part 2.

The deploy script is idempotent — re-running on an already-deployed scanner
just overwrites the files and re-runs the bootstrap. The widget shortcuts
will use the new config the next time the driver taps them. (You **do not**
need to remove and re-add the home-screen widget.)

---

## Security notes

This project uses **plain (unencrypted) FTP**. Be aware:

- The FTP password and all uploaded file contents travel across your store
  Wi-Fi as cleartext. Anyone on the same Wi-Fi with a packet sniffer
  (Wireshark, tcpdump, etc.) can read both.
- This is acceptable **only if** your store Wi-Fi is fully isolated from
  guest/customer traffic and you trust everyone on the IT network.
- **If you control the FTP server, switch it to FTPS (FTP over TLS).**
  It's a small code change in `sync_and_upload.py` (`ftplib.FTP` →
  `ftplib.FTP_TLS`) and a server-side config to enable TLS.

Other things this project does to limit blast radius:

- `config.json` is `chmod 600` after deployment, so on the scanner only
  Termux can read the FTP password (other apps can't).
- `config.json` and `vendor/*.apk` are in `.gitignore` so credentials and
  vendor binaries never end up in version control.
- Filenames are constructed from validated inputs only (digits-only store
  number, IP from the kernel, original filename) — no shell interpolation.
- The bootstrap is fully non-interactive and writes a sentinel + log file,
  so partial-success states are visible from the laptop.

---

## Troubleshooting

| Symptom                                            | Fix                                                                                                                |
|----------------------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| `adb: command not found`                           | Install Platform Tools (Part 1.1).                                                                                 |
| Windows: `adb` not recognized                      | You added it to PATH but didn't open a new Command Prompt. Open a fresh one.                                       |
| "No scanner detected"                              | Cable, USB Debugging on (Part 2.1), and "Allow" tapped on the scanner.                                             |
| "Scanner detected but UNAUTHORIZED"                | Look at the scanner. Tap **Allow** on the USB-debugging prompt. Tick "Always allow from this computer".            |
| "APKs not found in vendor/"                        | Download Termux + Termux:Widget per `vendor/README.md`.                                                            |
| "Termux install failed"                            | The Play Store version of Termux is installed (different signing key). Settings → Apps → Termux → Uninstall, then redeploy. |
| Bootstrap times out after 5 min                    | Storage popup wasn't accepted on the scanner. Watch the scanner during step 5/6 and tap Allow.                     |
| Bootstrap reports "FAIL: …"                        | `bootstrap.log` is auto-pulled to your laptop's working directory. Open it.                                        |
| Widget shows "Permission Denied" on the scanner    | Open Termux on the scanner, run `termux-setup-storage`, tap Allow, then tap the widget again.                      |
| Files renamed but not uploaded                     | No Wi-Fi during the run. Connect to Wi-Fi and tap the widget again — already-renamed files are skipped, not re-tagged. |
| FTP error: "No address associated with hostname"   | You used a `.local` hostname in `config.json`. Change to a numeric IP.                                             |
| FTP timeout                                        | Server firewall blocking the scanner's IP, weak Wi-Fi, or the server requires Active mode (Python uses Passive).   |
| Scanner already has Termux from Play Store         | Settings → Apps → Termux → Uninstall, then redeploy. The F-Droid APK will install cleanly afterward.               |

---

## File-naming convention (reference)

Files in `scan_dir` are renamed to:
```
STORE_{store#}_IP_{ip}_{originalfilename}
```

Examples:
- `scan_001.txt` → `STORE_345_IP_10.345.33.78_scan_001.txt`
- `pallet.csv`   → `STORE_345_IP_10.345.33.78_pallet.csv`
- `STORE_345_IP_10.345.33.78_scan_001.txt` → unchanged (already tagged)

The store number is the second octet of the subnet network address (e.g.,
subnet `10.345.33.0` → store `345`). The widget asks the user to confirm
this; if wrong (or no Wi-Fi), the user types it manually.

---

## Scanner Android requirements

- **Android 14:** fully supported. The Termux storage permission popup must
  be tapped once during setup; everything else is automated.
- **Android 11–13:** should work the same way. Untested.
- **Android 10 and below:** likely works. The storage popup may not appear
  (legacy storage), but the script handles both cases.
