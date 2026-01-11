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

def get_network_info():
    """
    Retrieves the device's Private IP and the Network Address (Subnet start).
    Returns tuple: (ip_address, subnet_network_address)
    """
    # 1. Get IP using socket trick (most reliable for "outgoing" interface)
    local_ip = "Unknown"
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception as e:
        print(f"Error: Could not determine Private IP address. Details: {e}")
        sys.exit(1)

    # 2. Get Subnet Network Address using system commands
    # We use 'ip' command which is standard on Android/Termux and Linux
    subnet_start = "Unknown"
    
    try:
        # Run 'ip -4 addr show' and look for the line associated with our IP
        output = subprocess.check_output("ip -4 addr show", shell=True).decode()
        for line in output.splitlines():
            if local_ip in line:
                # Example output line: "    inet 192.168.1.55/24 brd ..."
                parts = line.split()
                for part in parts:
                    # Look for the CIDR notation (e.g. 192.168.1.55/24)
                    if '/' in part and part.startswith(local_ip):
                        iface = ipaddress.IPv4Interface(part)
                        # .network gives 192.168.1.0/24, we want just 192.168.1.0
                        subnet_start = str(iface.network.network_address)
                        break
            if subnet_start != "Unknown":
                break
    except Exception as e:
        print(f"Warning: Could not determine subnet mask details: {e}")
    
    # Fallback if unknown: Assume standard class C (/24) if possible
    if subnet_start == "Unknown" and local_ip != "Unknown":
        try:
            # Simple assumption: 192.168.1.55 -> 192.168.1.0
            parts = local_ip.split('.')
            if len(parts) == 4:
                subnet_start = f"{parts[0]}.{parts[1]}.{parts[2]}.0"
                print(f"Notice: Using fallback subnet calculation (Assuming /24): {subnet_start}")
        except:
            pass

    return local_ip, subnet_start

def get_target_files(directory):
    """Returns a list of files in the directory, excluding hidden files."""
    try:
        return [f for f in os.listdir(directory) if os.path.isfile(os.path.join(directory, f)) and not f.startswith('.')]
    except OSError as e:
        print(f"Error: Could not access directory '{directory}'. Details: {e}")
        sys.exit(1)

def rename_files(directory, ip_address, subnet_start):
    """
    Renames files to: {IP}_SN_{Subnet}_{OriginalName}
    """
    # Regex to check if file already starts with IP pattern
    # Matches: 192.168.1.50_SN_... OR IP_192.168.1.50_SN_...
    tag_pattern = re.compile(r'^(IP_)?\d{1,3}(\.\d{1,3}){3}_SN_')
    
    renamed_files_info = []

    print(f"Scanning directory: {directory}")
    files = get_target_files(directory)
    
    if not files:
        print("No files found to process.")
        return []

    for filename in files:
        file_path = os.path.join(directory, filename)
        
        # Check if already tagged
        if tag_pattern.match(filename):
            # Special Case: If it was tagged with "Unknown" subnet, and we now KNOW the subnet, let's fix it.
            if "_SN_Unknown_" in filename and subnet_start != "Unknown":
                print(f"Retrying '{filename}': Found 'Unknown' subnet tag, updating to '{subnet_start}'...")
                # We proceed to rename logic below
                pass 
            else:
                print(f"Skipping '{filename}': Already appears to be tagged.")
                renamed_files_info.append(file_path) 
                continue

        # Construct new name
        # Construct new name
        # Format: IP_PrivateIPAddress_SN_SubnetAddress_original_filename.txt
        new_filename = f"IP_{ip_address}_SN_{subnet_start}_{filename}"
        new_file_path = os.path.join(directory, new_filename)
        
        try:
            os.rename(file_path, new_file_path)
            print(f"Renamed: '{filename}' -> '{new_filename}'")
            renamed_files_info.append(new_file_path)
        except OSError as e:
            print(f"Error renaming '{filename}': {e}")
    
    return renamed_files_info

    return local_ip, subnet_start

def upload_files_ftp(files_to_upload, config):
    """Uploads the specified files to the FTP server."""
    if not files_to_upload:
        print("No files to upload.")
        return

    server = config.get('ftp_server')
    user = config.get('ftp_user')
    password = config.get('ftp_password')
    port = config.get('ftp_port', 21)

    if not all([server, user, password]):
        print("Error: Missing FTP credentials in config.json.")
        sys.exit(1)

    print(f"\\nConnecting to FTP Server: {server}...")
    
    ftp = None
    try:
        ftp = ftplib.FTP()
        ftp.connect(server, port)
        ftp.login(user, password)
        print("Connected successfully.")
        
        print("\\nStarting Uploads:")
        for file_path in files_to_upload:
            filename = os.path.basename(file_path)
            try:
                with open(file_path, 'rb') as f:
                    print(f"Uploading '{filename}'...", end=' ')
                    ftp.storbinary(f"STOR {filename}", f)
                    print("Done.")
            except Exception as e:
                print(f"Failed to upload '{filename}': {e}")

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
    parser = argparse.ArgumentParser(description="Tag files with Private IP and upload via FTP.")
    parser.add_argument("directory", help="The directory containing files to process.")
    
    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(1)

    args = parser.parse_args()
    target_dir = args.directory

    if not os.path.isdir(target_dir):
        print(f"Error: The directory '{target_dir}' does not exist.")
        sys.exit(1)

    # 1. Load Configuration
    config = load_config()

    # 2. Get Network Info
    ip_address, subnet_start = get_network_info()
    print(f"Detected IP: {ip_address}")
    print(f"Detected Subnet Start: {subnet_start}")

    # 3. Rename Files
    processed_files = rename_files(target_dir, ip_address, subnet_start)

    # 4. Upload Files
    upload_files_ftp(processed_files, config)

    print("\nProcess Completed.")

if __name__ == "__main__":
    main()
