# Zebra MC33 — IP Tagger & FTP Sync

Naming System for Zebra MC33 scanners: tags inventory files with the
scanner's IP and store number, then uploads them to a central FTP server.
Built so a delivery driver with zero technical experience can run the whole
flow with a single home-screen widget tap, and an IT person can deploy it to
a new scanner in about 3 minutes.

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
# Instructions

## Part 1 — One-time setup (do this once, ever)

You do this once on the laptop you'll use for all deployments. It does not
need to be repeated for each scanner.

### 1.0 Download this project to your laptop

Before doing anything else, you need this entire project folder on your laptop. 
- If you use Git, clone this repository: `git clone <your-repo-url>`
- If you don't use Git, click the **Code** button at the top of the GitHub page and select **Download ZIP**. Extract the ZIP file to your Desktop or Documents folder. 

### 1.1 Install ADB

ADB (Android Debug Bridge) is the cable-side tool that lets your laptop talk
to the scanner. Without it, none of this works.

#### Mac
```bash
brew install android-platform-tools
```
Then, in the same Terminal window, verify it's installed:
```bash
adb version
```
You should see something like `Android Debug Bridge version 1.0.41`. If you
see "command not found", install Homebrew first (https://brew.sh) and try
again.

#### Linux
```bash
sudo apt install adb              # Debian / Ubuntu / Mint
sudo dnf install android-tools    # Fedora
```
Verify: `adb version`.

#### Windows — pick ONE of these two options

**Option A — Easy, no PATH editing (recommended if you've never edited environment variables):**

1. Open this URL in a browser: **https://developer.android.com/studio/releases/platform-tools**
2. Scroll down to the "Downloads" section and click **"Download SDK Platform-Tools for Windows"**.
3. Read and accept the terms. The browser downloads a file called something like `platform-tools-latest-windows.zip`.
4. Open File Explorer and navigate to the **zebra-tag** folder where you extracted this project.
5. Move the downloaded zip file into the **zebra-tag** folder.
6. Right-click the zip file → **Extract All...** → click **Extract**.
7. After extraction, you should see a new subfolder called `platform-tools` containing files like `adb.exe`, `fastboot.exe`, etc. The folder layout should look like:
   ```
   zebra-tag\
     deploy_to_scanner.bat
     README.md
     platform-tools\          <-- the folder you just extracted
       adb.exe
       fastboot.exe
       ...
   ```
8. You're done. The deploy script will automatically find `adb.exe` inside this folder. **Skip to step 1.2.**

> Why this works: the deploy script checks for a `platform-tools` subfolder next to itself before falling back to the system PATH. No global setup needed.

**Option B — Standard, edit Windows PATH (if you'll use ADB for other things too):**

1. Open this URL in a browser: **https://developer.android.com/studio/releases/platform-tools**
2. Click **"Download SDK Platform-Tools for Windows"**, accept terms, save the zip.
3. Right-click the zip → **Extract All...** → change the destination to `C:\platform-tools` → click **Extract**.
4. After extraction you should have `C:\platform-tools\adb.exe`. Verify by opening File Explorer and navigating to `C:\platform-tools`.
5. Now add that folder to your PATH:
   - Press the **Windows key** (the key with the Windows logo).
   - Type: `env`
   - In the search results you'll see two similar-looking entries. Click **"Edit environment variables for your account"** (the one *without* "system" in the name — system requires admin and we don't need that).
   - The **Environment Variables** window opens. It has two sections: "User variables for [yourname]" on top and "System variables" on the bottom. **Use the top one.**
   - In the top section, click on the row labeled **Path** (just click it once to select it).
   - Click the **Edit...** button (NOT "Delete").
   - A new "Edit environment variable" window opens with a list of paths.
   - Click **New** (top-right of that window).
   - A blank line appears. Type or paste: `C:\platform-tools`
   - Click **OK**.
   - Click **OK** on the previous window too.
   - Click **OK** on the System Properties window if it's still open.
6. **Close any Command Prompt windows you have open.** PATH changes only take effect in NEW terminal windows.
7. Open a fresh Command Prompt:
   - Press the **Windows key**, type `cmd`, press Enter.
8. In the new Command Prompt window, type:
   ```
   adb version
   ```
   and press Enter.
9. You should see `Android Debug Bridge version 1.0.41` (or similar). If you see "'adb' is not recognized as an internal or external command", the PATH edit didn't take effect — close all Command Prompts again and open a brand new one. If still failing, use Option A instead.

### 1.2 Download the Termux APKs

The deploy script auto-installs Termux on each scanner — but it needs the
APK files in the `vendor/` folder. There is also a README in the `vendor/` folder that you can refer to. You're going to download two APKs from
F-Droid (the official Termux source) and drop them into that folder. This
takes about 2 minutes.

> **You only need TWO apps**, not three. There are several "Termux:..." apps
> on F-Droid (Termux:API, Termux:Boot, Termux:Float, etc.) — you do **not**
> need any of those. We only use **Termux** and **Termux:Widget**.

**Step 1 — Download Termux (the terminal itself):**

1. In your browser, open: **https://f-droid.org/packages/com.termux/**
2. Scroll down past the description and screenshots until you see a section called **"Versions"**.
3. The first version listed will be tagged with the word **"suggested"** — that's the stable release we want. (Other versions might be tagged "beta" — skip those.)
4. Right under the "suggested" version, click the bold **Download APK** link.
5. The file will download. **Heads up: it's about 110 MB**, so it'll take a moment on slower connections. The filename will look like `com.termux_1002.apk` (the number changes over time — that's fine).
6. Once downloaded, open File Explorer (Windows) or Finder (Mac), navigate to your Downloads folder, and **move** (or copy) the downloaded `com.termux_*.apk` file into the `vendor/` subfolder of this project.

**Step 2 — Download Termux:Widget (the home-screen shortcut launcher):**

1. In your browser, open: **https://f-droid.org/packages/com.termux.widget/**
2. Scroll down to the **"Versions"** section.
3. Click the bold **Download APK** link under the version tagged **"suggested"**.
4. This file is small — about 6 MB. Filename will look like `com.termux.widget_1001.apk`.
5. Move (or copy) the downloaded file into the `vendor/` subfolder of this project.

**Step 3 — Verify the `vendor/` folder looks right:**

Open the `vendor/` folder. It should now contain three things:
```
vendor/
  README.md
  com.termux_1002.apk            (~110 MB — Termux itself)
  com.termux.widget_1001.apk     (~6 MB — Termux:Widget)
```

The exact version numbers in the filenames will vary over time. The deploy
script finds the files by pattern (`com.termux_*.apk` and
`com.termux.widget_*.apk`), so you don't need to rename them.

> **Why F-Droid and not the Play Store?** The Play Store version of Termux
> has been unmaintained since 2020 and is broken on newer Android versions.
> F-Droid is the source the Termux maintainers themselves recommend. If a
> scanner already has Termux from the Play Store, the deploy script will
> tell you exactly what to do (uninstall it, then redeploy).

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

### 2.2 Connect

1. Plug the scanner into your laptop with a USB cable.
2. **Look at the scanner.** A "Allow USB Debugging?" prompt appears the
   first time. Tick **"Always allow from this computer"** and tap **Allow**.

### 2.3 Verify the connection (do this every time before deploying)

Before running the deploy script, run these three commands in your terminal
to confirm your laptop is actually talking to the scanner. This takes 10
seconds and saves you from chasing ghost problems later.

Open a terminal:
- **Mac:** open Terminal (Cmd+Space, type "terminal", Enter), then `cd` to
  this project folder.
- **Windows:** open Command Prompt (Win key, type `cmd`, Enter), then `cd`
  to this project folder. *(If you used Option A in section 1.1, also run:*
  `set PATH=%CD%\platform-tools;%PATH%` *first, so the temporary PATH
  picks up your local platform-tools folder.)*
- **Linux:** any terminal, `cd` into the project folder.

Then run, in this order:

**Check 1 — is ADB itself working?**
```
adb version
```
Expected output: a line like `Android Debug Bridge version 1.0.41`.
If you see "command not found" or "not recognized", revisit section 1.1 —
ADB isn't installed or isn't on your PATH yet.

**Check 2 — does ADB see the scanner?**
```
adb devices
```
Expected output:
```
List of devices attached
ABC123XYZ    device
```
The serial number will be different. The important word is **`device`** at
the end of the line.

| What you see                          | What it means                                                         |
|---------------------------------------|-----------------------------------------------------------------------|
| `device`                              | ✅ Connected and authorized. Good to go.                              |
| `unauthorized`                        | Look at the scanner — tap **Allow** on the USB-debugging prompt.       |
| `offline`                             | Unplug, plug back in. If it persists, try a different USB cable/port. |
| (empty list, only the header line)    | USB Debugging not enabled, or cable issue. Revisit section 2.1.       |

**Check 3 — is the scanner actually responding to commands?**
```
adb shell getprop ro.product.model
```
Expected output: the scanner's model name, e.g. `MC330L` or `MC33`. If this
prints the model, your laptop and the scanner are fully talking. You're
ready to deploy.

If check 3 hangs or times out, the connection is half-broken — unplug the
scanner, wait 5 seconds, plug it back in, and run all three checks again.

### 2.4 Run the deploy script

Once the three connection checks above pass:

   **Mac/Linux:**
   ```bash
   chmod +x deploy_to_scanner.sh
   ./deploy_to_scanner.sh
   ```

   **Windows:** double-click `deploy_to_scanner.bat`.

**Watch the scanner during step 5/6 of the script.** Termux will request
storage permission — **TAP "ALLOW"** on the scanner. This is the only
manual interaction with the scanner during setup. (Required by Android
14's scoped storage rules — there is no way to grant this from the
laptop.)

Wait. The script runs through 6 steps (~1-3 minutes). It ends with:
```
==============================================
  Scanner XXXX is ready.
==============================================
```

### 2.5 Add the home-screen widgets (one time per scanner)

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
