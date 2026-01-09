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

def get_private_ip():
    """
    Retrieves the device's private IP address by connecting to a public DNS.
    This method is reliable across different platforms and Android versions.
    """
    try:
        # Create a dummy socket connection to a public DNS server (Google DNS)
        # We don't actually send data, just use it to determine the local interface IP.
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip_address = s.getsockname()[0]
        s.close()
        return ip_address
    except Exception as e:
        print(f"Error: Could not determine Private IP address. Details: {e}")
        sys.exit(1)

def get_target_files(directory):
    """Returns a list of files in the directory, excluding hidden files."""
    try:
        return [f for f in os.listdir(directory) if os.path.isfile(os.path.join(directory, f)) and not f.startswith('.')]
    except OSError as e:
        print(f"Error: Could not access directory '{directory}'. Details: {e}")
        sys.exit(1)

def rename_files(directory, ip_address):
    """
    Renames files in the directory by appending the IP address.
    Skipped if the file is already tagged with an IP.
    Returns a list of (new_full_path, original_filename) tuples for uploaded files.
    """
    
    # Regex to check if a file already ends with an IP address pattern (e.g., _192.168.1.5.txt)
    # Pattern: _(1-3 digits).(1-3 digits).(1-3 digits).(1-3 digits) before the extension
    ip_pattern = re.compile(r'_(\d{1,3}\.){3}\d{1,3}(\.[^.]+)?$')
    
    renamed_files_info = []

    print(f"Scanning directory: {directory}")
    files = get_target_files(directory)
    
    if not files:
        print("No files found to process.")
        return []

    for filename in files:
        file_path = os.path.join(directory, filename)
        name, ext = os.path.splitext(filename)
        
        # Check if already tagged
        if ip_pattern.search(filename):
            print(f"Skipping '{filename}': Already appears to be tagged.")
            renamed_files_info.append(file_path) # Add to list to upload even if not renamed
            continue

        # Construct new name
        new_filename = f"{name}_{ip_address}{ext}"
        new_file_path = os.path.join(directory, new_filename)
        
        try:
            os.rename(file_path, new_file_path)
            print(f"Renamed: '{filename}' -> '{new_filename}'")
            renamed_files_info.append(new_file_path)
        except OSError as e:
            print(f"Error renaming '{filename}': {e}")
    
    return renamed_files_info

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

    print(f"\nConnecting to FTP Server: {server}...")
    
    ftp = None
    try:
        ftp = ftplib.FTP()
        ftp.connect(server, port)
        ftp.login(user, password)
        print("Connected successfully.")

        # Optional: Switch to specific directory if needed, e.g., ftp.cwd('/upload')
        
        print("\nStarting Uploads:")
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
        print(f"\nFTP Error: {e}")
    finally:
        if ftp:
            try:
                ftp.quit()
            except:
                pass
            print("\nFTP Connection closed.")

def main():
    parser = argparse.ArgumentParser(description="Tag files with Private IP and upload via FTP.")
    parser.add_argument("directory", help="The directory containing files to process.")
    
    # If run without arguments, print help
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

    # 2. Get Private IP
    ip_address = get_private_ip()
    print(f"Detected Private IP: {ip_address}")

    # 3. Rename Files
    processed_files = rename_files(target_dir, ip_address)

    # 4. Upload Files
    upload_files_ftp(processed_files, config)

    print("\nProcess Completed.")

if __name__ == "__main__":
    main()
