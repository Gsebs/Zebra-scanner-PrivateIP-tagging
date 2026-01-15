import os
import socket
import sys
import json
import ftplib
import re
import argparse

# --- Configuration ---
CONFIG_FILE = 'config.json'

def load_config():
    """Loads FTP credentials from config.json."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, CONFIG_FILE)
    
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Configuration file '{CONFIG_FILE}' not found at {config_path}.")
        print("Please ensure config.json is in the same directory as this script.")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: Failed to parse '{CONFIG_FILE}'. Please check the JSON syntax.")
        sys.exit(1)

import ipaddress
import subprocess

# ... (Previous config load code remains same, included implicitly or handled by diff)

# ... imports remain same ...

def get_network_info():
    """
    Retrieves the device's Private IP and the Network Address (Subnet start).
    Returns tuple: (ip_address, subnet_network_address)
    """
    # 1. Get IP using socket trick
    local_ip = "Unknown"
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception as e:
        # No Wi-Fi connection
        return "Unknown", "Unknown"

    # 2. Get Subnet Network Address
    subnet_start = "Unknown"
    
    try:
        output = subprocess.check_output("ip -4 addr show", shell=True).decode()
        for line in output.splitlines():
            if local_ip in line:
                parts = line.split()
                for part in parts:
                    if '/' in part and part.startswith(local_ip):
                        iface = ipaddress.IPv4Interface(part)
                        subnet_start = str(iface.network.network_address)
                        break
            if subnet_start != "Unknown":
                break
    except Exception:
        pass
    
    # Fallback
    if subnet_start == "Unknown" and local_ip != "Unknown":
        try:
            parts = local_ip.split('.')
            if len(parts) == 4:
                subnet_start = f"{parts[0]}.{parts[1]}.{parts[2]}.0"
        except:
            pass

    return local_ip, subnet_start

def get_store_number(subnet_start, ip_address):
    """
    Extracts Store Number from Subnet (2nd octet).
    INTERACTIVE: Asks user to confirm.
    """
    proposed_store = None
    
    # Try to extract from Subnet
    if subnet_start != "Unknown":
        try:
            # Subnet format: 10.345.33.0 -> Store is 345 (index 1)
            parts = subnet_start.split('.')
            if len(parts) == 4:
                proposed_store = parts[1]
        except:
            pass

    print("\\nConfiguration Check:")
    if ip_address == "Unknown":
        print("Status: [!] NO WIFI CONNECTION DETECTED")
        print("Action: You must enter the Store Number manually.")
        proposed_store = None
    else:
        print(f"Status: Wi-Fi Connected (IP: {ip_address})")
        print(f"Subnet: {subnet_start}")
        
    final_store = ""
    
    if proposed_store:
        while True:
            response = input(f"\\nIs Store Number '{proposed_store}' correct? (y/n): ").strip().lower()
            if response == 'y':
                final_store = proposed_store
                break
            elif response == 'n':
                final_store = input("Enter the correct Store Number: ").strip()
                if final_store:
                    break
            else:
                print("Please answer 'y' or 'n'.")
    else:
        while not final_store:
            final_store = input("\\nPlease enter the Store Number: ").strip()
            
    print(f"\\n-> Using Store Number: {final_store}")
    return final_store

def get_target_files(directory):
    """Returns a list of files in the directory, excluding hidden files."""
    try:
        if not os.path.isdir(directory):
             print(f"Error: Directory '{directory}' does not exist.")
             return []
        return [f for f in os.listdir(directory) if os.path.isfile(os.path.join(directory, f)) and not f.startswith('.')]
    except OSError as e:
        print(f"Error: Could not access directory '{directory}'. Details: {e}")
        return []

def rename_files(directory, ip_address, store_number):
    """
    Renames files to: STORE_{Store#}_IP_{IP}_{OriginalName}
    """
    # Regex to prevent re-tagging: match string starting with STORE_...
    tag_pattern = re.compile(r'^STORE_')
    
    renamed_files_info = []

    print(f"\\nScanning directory for renaming: {directory}")
    files = get_target_files(directory)
    
    if not files:
        print("No files found to process.")
        return []

    for filename in files:
        file_path = os.path.join(directory, filename)
        
        # Checking idempotency
        if tag_pattern.match(filename):
            print(f"Skipping '{filename}': Already tagged.")
            renamed_files_info.append(file_path) 
            continue

        # Construct new name
        # Format: STORE_store#_IP_ipadress_originalfilename.txt
        safe_ip = ip_address if ip_address != "Unknown" else "NoWiFi"
        new_filename = f"STORE_{store_number}_IP_{safe_ip}_{filename}"
        new_file_path = os.path.join(directory, new_filename)
        
        try:
            os.rename(file_path, new_file_path)
            print(f"Renamed: '{filename}' -> '{new_filename}'")
            renamed_files_info.append(new_file_path)
        except OSError as e:
            print(f"Error renaming '{filename}': {e}")
    
    return renamed_files_info

def reset_inventory(directory):
    """
    DELETES all files in the directory.
    Used by the 'Clear Inventory' widget.
    """
    print(f"\\n--- CLEARING INVENTORY in {directory} ---")
    files = get_target_files(directory)
    
    if not files:
        print("Directory is already empty.")
        return

    print(f"WARNING: This will permanently DELETE {len(files)} files.")
    
    confirm = input("Are you sure? (y/n): ").strip().lower()
    
    if confirm != 'y':
        print("Operation cancelled.")
        return

    count = 0
    for filename in files:
        file_path = os.path.join(directory, filename)
        try:
            os.remove(file_path)
            print(f"Deleted: '{filename}'")
            count += 1
        except OSError as e:
            print(f"Error deleting '{filename}': {e}")
                
    print(f"Cleanup complete. {count} files deleted.")

def upload_files_ftp(files_to_upload, config):
    """
    Uploads files to rfidscan/autoscan/inventory.
    DELETES local file after successful upload.
    """
    if not files_to_upload:
        print("No files to upload.")
        return

    server = config.get('ftp_server')
    user = config.get('ftp_user')
    password = config.get('ftp_password')
    port = config.get('ftp_port', 21)

    if not all([server, user, password]):
        print("Error: Missing FTP credentials in config.json.")
        return

    print(f"\\nConnecting to FTP Server: {server}...")
    
    ftp = None
    try:
        ftp = ftplib.FTP()
        ftp.connect(server, port)
        ftp.login(user, password)
        print("Connected successfully.")
        
        # Navigate Directories
        target_path = "/rfidscan/autoscan/inventory"
        try:
            # Try full path first
            ftp.cwd(target_path)
        except:
             # Try step by step creation if needed (simplified here for standard path)
             print(f"Warning: Remote path '{target_path}' might not exist. Attempting verification...")
             # For production safety we usually assume path exists or handle creation.
             # Let's try standard walk down for robustness
             ftp.cwd("/") 
             for folder in ["rfidscan", "autoscan", "inventory"]:
                 try: 
                     ftp.cwd(folder)
                 except: 
                     print(f"Creating remote folder: {folder}")
                     ftp.mkd(folder)
                     ftp.cwd(folder)

        print(f"Upload Target: {ftp.pwd()}")
        print("\\nStarting Uploads & Cleanup:")
        
        for file_path in files_to_upload:
            filename = os.path.basename(file_path)
            try:
                with open(file_path, 'rb') as f:
                    print(f"Uploading '{filename}'...", end=' ')
                    ftp.storbinary(f"STOR {filename}", f)
                    print("Done.", end=' ')
                
                # DELETE after success
                os.remove(file_path)
                print("[Deleted Local Copy]")
                
            except Exception as e:
                print(f"\\n[!] FAILED to upload '{filename}': {e}")
                print("    (File NOT deleted)")

    except ftplib.all_errors as e:
        print(f"\\nFTP Error: {e}")
    finally:
        if ftp:
            try:
                ftp.quit()
            except:
                pass
            print("\\nFTP Connection closed.")

def main():
    parser = argparse.ArgumentParser(description="Zebra Scanner Management Tool")
    parser.add_argument("directory", help="The directory containing files to process.")
    parser.add_argument("--action", choices=['sync', 'reset'], default='sync', help="Action to perform: 'sync' (default) or 'reset' (clear names).")
    
    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(1)

    args = parser.parse_args()
    target_dir = args.directory

    if not os.path.isdir(target_dir):
        print(f"Error: The directory '{target_dir}' does not exist.")
        sys.exit(1)
        
    # --- RESET MODE ---
    if args.action == 'reset':
        reset_inventory(target_dir)
        return

    # --- SYNC MODE (Default) ---
    
    # 1. Load Configuration
    config = load_config()

    # 2. Get Network Info & Interactive Store #
    ip_address, subnet_start = get_network_info()
    store_number = get_store_number(subnet_start, ip_address)

    # 3. Rename Files
    processed_files = rename_files(target_dir, ip_address, store_number)

    # 4. Upload & Delete
    # Only upload if we have files AND we have internet (IP is not Unknown)
    if ip_address != "Unknown":
        upload_files_ftp(processed_files, config)
    else:
        print("\\n[!] No Wi-Fi Connection. Files have been renamed but NOT uploaded.")
        print("    Please connect to Wi-Fi and run the tool again to upload.")

    print("\\nProcess Completed.")

if __name__ == "__main__":
    main()
