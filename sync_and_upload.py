"""
Zebra MC33 — IP tagger and FTP uploader.

Run modes:
    python sync_and_upload.py                  # uses scan_dir from config.json
    python sync_and_upload.py /sdcard/Custom   # explicit override
    python sync_and_upload.py --action reset   # delete everything in scan_dir

The widget shortcuts on the scanner call this with no positional argument,
so scan_dir is read from config.json — that's the single source of truth.
"""

import argparse
import ftplib
import ipaddress
import json
import os
import re
import socket
import subprocess
import sys

# ----- Defaults (only used if config.json omits the fields) -----
CONFIG_FILE = "config.json"
DEFAULT_FTP_TARGET = "/rfidscan/autoscan/inventory"
DEFAULT_SCAN_DIR = "/sdcard/Inventory"

# Files that are already tagged start with "STORE_". We won't re-tag them.
TAG_PATTERN = re.compile(r"^STORE_")


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
def load_config():
    """Load config.json from the same directory as this script."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, CONFIG_FILE)
    try:
        with open(config_path, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: '{CONFIG_FILE}' not found at {config_path}.")
        print("Copy config_example.json to config.json and fill it in.")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: '{CONFIG_FILE}' is not valid JSON. Details: {e}")
        sys.exit(1)


# ---------------------------------------------------------------------------
# Network detection
# ---------------------------------------------------------------------------
def get_network_info():
    """
    Return (ip_address, subnet_network_address).
    Returns ("Unknown", "Unknown") if there's no Wi-Fi connectivity.
    """
    # IP via the standard "open a UDP socket to a public address" trick.
    # No packets are actually sent — we just ask the kernel which interface
    # would be used, then read its source IP.
    local_ip = "Unknown"
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(2)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        return "Unknown", "Unknown"

    # Subnet network address — parse `ip -4 addr show` for the interface
    # that owns local_ip, then compute the network address.
    subnet_start = "Unknown"
    try:
        output = subprocess.check_output(
            ["ip", "-4", "addr", "show"], stderr=subprocess.DEVNULL
        ).decode()
        for line in output.splitlines():
            if local_ip in line:
                for part in line.split():
                    if "/" in part and part.startswith(local_ip):
                        iface = ipaddress.IPv4Interface(part)
                        subnet_start = str(iface.network.network_address)
                        break
            if subnet_start != "Unknown":
                break
    except Exception:
        pass

    # Fallback: assume /24 if `ip` wasn't available or didn't match.
    if subnet_start == "Unknown" and local_ip != "Unknown":
        parts = local_ip.split(".")
        if len(parts) == 4:
            subnet_start = f"{parts[0]}.{parts[1]}.{parts[2]}.0"

    return local_ip, subnet_start


# ---------------------------------------------------------------------------
# Store-number prompt
# ---------------------------------------------------------------------------
def prompt_store_number(subnet_start, ip_address):
    """
    Confirm or override the store number (the 2nd octet of the subnet).
    Example: subnet 10.345.33.0  ->  store 345.

    No Wi-Fi  ->  user must type the store number manually.
    Wi-Fi OK  ->  ask y/n; on 'n' the user types it manually.
    """
    proposed = None
    if subnet_start != "Unknown":
        parts = subnet_start.split(".")
        if len(parts) == 4 and parts[1].isdigit():
            proposed = parts[1]

    print("\nNetwork status:")
    if ip_address == "Unknown":
        print("  [!] NO WI-FI CONNECTION DETECTED")
        print("      You must enter the Store Number manually.")
        proposed = None
    else:
        print(f"  IP:     {ip_address}")
        print(f"  Subnet: {subnet_start}")

    final = ""
    if proposed:
        while True:
            ans = input(f"\nIs Store Number '{proposed}' correct? (y/n): ").strip().lower()
            if ans == "y":
                final = proposed
                break
            if ans == "n":
                entry = input("Enter the correct Store Number: ").strip()
                if entry.isdigit():
                    final = entry
                    break
                print("  Store Number must be digits only.")
            else:
                print("  Please answer 'y' or 'n'.")
    else:
        while not final:
            entry = input("\nPlease enter the Store Number: ").strip()
            if entry.isdigit():
                final = entry
            else:
                print("  Store Number must be digits only.")

    print(f"\n  -> Using Store Number: {final}")
    return final


# ---------------------------------------------------------------------------
# Filesystem helpers
# ---------------------------------------------------------------------------
def list_files(directory):
    """Return non-hidden regular files in `directory`."""
    if not os.path.isdir(directory):
        print(f"Error: directory '{directory}' does not exist.")
        return []
    try:
        return [
            f for f in os.listdir(directory)
            if os.path.isfile(os.path.join(directory, f)) and not f.startswith(".")
        ]
    except OSError as e:
        print(f"Error: cannot access '{directory}': {e}")
        return []


def rename_files(directory, ip_address, store_number):
    """
    Rename files to: STORE_{store#}_IP_{ip}_{originalname}
    Idempotent — files starting with 'STORE_' are skipped.
    Returns the list of full paths ready for upload.
    """
    processed = []
    print(f"\nScanning: {directory}")
    files = list_files(directory)
    if not files:
        print("  (no files to process)")
        return []

    safe_ip = ip_address if ip_address != "Unknown" else "NoWiFi"

    for filename in files:
        full = os.path.join(directory, filename)
        if TAG_PATTERN.match(filename):
            print(f"  Skipping '{filename}' (already tagged).")
            processed.append(full)
            continue

        new_name = f"STORE_{store_number}_IP_{safe_ip}_{filename}"
        new_full = os.path.join(directory, new_name)
        try:
            os.rename(full, new_full)
            print(f"  Renamed: {filename}  ->  {new_name}")
            processed.append(new_full)
        except OSError as e:
            print(f"  [!] Rename failed for '{filename}': {e}")

    return processed


def reset_inventory(directory):
    """Delete every (non-hidden) file in `directory`. Asks y/n first."""
    print(f"\n--- CLEAR INVENTORY in {directory} ---")
    files = list_files(directory)
    if not files:
        print("Directory is already empty.")
        return

    print(f"WARNING: this will permanently DELETE {len(files)} file(s).")
    if input("Are you sure? (y/n): ").strip().lower() != "y":
        print("Cancelled.")
        return

    deleted = 0
    for filename in files:
        full = os.path.join(directory, filename)
        try:
            os.remove(full)
            print(f"  Deleted: {filename}")
            deleted += 1
        except OSError as e:
            print(f"  [!] Delete failed for '{filename}': {e}")
    print(f"\nDone. {deleted} file(s) deleted.")


# ---------------------------------------------------------------------------
# FTP
# ---------------------------------------------------------------------------
def ensure_remote_dir(ftp, target_dir):
    """
    Walk `target_dir` one segment at a time, creating any missing folders.
    Leaves the FTP cwd at target_dir on success.
    """
    ftp.cwd("/")
    parts = [p for p in target_dir.strip("/").split("/") if p]
    for part in parts:
        try:
            ftp.cwd(part)
        except ftplib.error_perm:
            print(f"  (creating remote folder: {part})")
            ftp.mkd(part)
            ftp.cwd(part)


def upload_files(files_to_upload, config):
    """Upload each file, then delete its local copy on success."""
    if not files_to_upload:
        print("\nNo files to upload.")
        return

    server = config.get("ftp_server")
    user = config.get("ftp_user")
    password = config.get("ftp_password")
    port = int(config.get("ftp_port", 21))
    target_dir = config.get("ftp_target_dir", DEFAULT_FTP_TARGET)

    if not all([server, user, password]):
        print("Error: FTP credentials missing in config.json.")
        return

    print(f"\nConnecting to FTP {server}:{port} ...")
    ftp = None
    try:
        ftp = ftplib.FTP()
        ftp.connect(server, port, timeout=30)
        ftp.login(user, password)
        print("Connected.")

        ensure_remote_dir(ftp, target_dir)
        print(f"Upload target: {ftp.pwd()}")
        print("\nUploading:")

        for path in files_to_upload:
            name = os.path.basename(path)
            try:
                with open(path, "rb") as f:
                    print(f"  {name} ...", end=" ", flush=True)
                    ftp.storbinary(f"STOR {name}", f)
                    print("done.", end=" ")
                os.remove(path)
                print("[local copy removed]")
            except Exception as e:
                # One file failing shouldn't kill the rest.
                print(f"\n  [!] FAILED for '{name}': {e}")
                print("      Local copy kept so you can retry.")

    except ftplib.all_errors as e:
        print(f"\nFTP error: {e}")
    finally:
        if ftp is not None:
            try:
                ftp.quit()
            except Exception:
                pass
            print("\nFTP connection closed.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Zebra Scanner Management Tool")
    parser.add_argument(
        "directory",
        nargs="?",
        default=None,
        help="Directory to process. Defaults to scan_dir from config.json.",
    )
    parser.add_argument(
        "--action",
        choices=["sync", "reset"],
        default="sync",
        help="'sync' (default) tags + uploads. 'reset' deletes everything.",
    )
    args = parser.parse_args()

    config = load_config()
    target_dir = args.directory or config.get("scan_dir", DEFAULT_SCAN_DIR)

    if not os.path.isdir(target_dir):
        print(f"Error: directory '{target_dir}' does not exist.")
        sys.exit(1)

    if args.action == "reset":
        reset_inventory(target_dir)
        return

    # --- sync ---
    ip_address, subnet_start = get_network_info()
    store_number = prompt_store_number(subnet_start, ip_address)
    processed = rename_files(target_dir, ip_address, store_number)

    if ip_address != "Unknown":
        upload_files(processed, config)
    else:
        print("\n[!] No Wi-Fi. Files renamed locally but NOT uploaded.")
        print("    Connect to Wi-Fi and run the widget again to upload.")

    print("\nProcess complete.")


if __name__ == "__main__":
    main()
