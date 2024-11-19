#!/bin/bash

# Install script for AgentDVR on Linux
# To execute: save and `chmod +x ./linux_setup2.sh` then `./linux_setup2.sh`

# Define constants
LOGFILE="/var/log/agentdvr_setup.log"  # Log file path
INSTALL_PATH="/opt/AgentDVR"

# Ensure the log file exists and is writable
touch "$LOGFILE" || { echo "Cannot write to $LOGFILE. Please check permissions."; exit 1; }
chmod 644 "$LOGFILE"

# Try to redirect output to both terminal and logfile; fall back to file-only if it fails
if ! exec > >(tee -a "$LOGFILE") 2> >(tee -a "$LOGFILE" >&2); then
    echo "Warning: Process substitution failed. Logging only to $LOGFILE."
    exec > "$LOGFILE" 2>&1
fi

# Function to print info messages with timestamp
info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO]: $1"
}

# Function to print error messages with timestamp
error_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR]: $1" >&2
}

# Function to check if a command exists
machine_has() {
    command -v "$1" > /dev/null 2>&1
    return $?
}

# Function to handle critical errors
critical_error() {
    error_log "$1"
    exit 1
}

# Function to download AgentDVR with retry logic
download_agentdvr() {
    local url="$1"
    local output="$2"
    local max_attempts=3
    local attempt=1

    info "Starting download of AgentDVR..."
    while [ $attempt -le $max_attempts ]; do
        info "Attempt $attempt of $max_attempts: Downloading from $url"
        if curl --show-error --location "$url" -o "$output" >> "$LOGFILE" 2>&1; then
            info "AgentDVR downloaded successfully on attempt $attempt."
            return 0
        else
            error_log "Download attempt $attempt failed."
            attempt=$((attempt + 1))
            sleep 2  # Wait before retrying
        fi
    done
    critical_error "Failed to download AgentDVR after $max_attempts attempts."
}

# Start of the script
info "===== AgentDVR Linux Setup Script Started ====="

# Source the release information
if ! . /etc/*-release 2>/dev/null; then
    critical_error "Failed to source /etc/*-release."
fi

# Determine system architecture
arch=$(uname -m)
info "System architecture detected: $arch"

# Check if the script is running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    error_log "This script is intended for Linux. Please use macos_setup.sh for macOS."
    exit 1
fi

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    error_log "This script must be run as root. Please use sudo or switch to the root user."
    exit 1
fi
info "Script is running with root privileges."

# Stop AgentDVR service if it's running
if systemctl stop AgentDVR.service; then
    info "Stopped existing AgentDVR service."
else
    info "AgentDVR service was not running or failed to stop. Continuing..."
fi

# Create installation directory
mkdir -p "$INSTALL_PATH" || critical_error "Failed to create installation directory at $INSTALL_PATH."
info "Installation directory set to $INSTALL_PATH."

cd "$INSTALL_PATH" || critical_error "Failed to navigate to $INSTALL_PATH."

# Update package lists and install dependencies based on the package manager
if machine_has "apt-get"; then
    info "Detected apt-get package manager. Updating and installing dependencies..."
    apt-get update >> "$LOGFILE" 2>&1 || critical_error "apt-get update failed."
    apt-get install --no-install-recommends -y unzip apt-transport-https alsa-utils libxext-dev fontconfig libva-drm2 >> "$LOGFILE" 2>&1 || critical_error "apt-get install failed."
    info "Dependencies installed successfully using apt-get."
elif machine_has "yum"; then
    info "Detected yum package manager. Updating and installing dependencies..."
    yum update -y >> "$LOGFILE" 2>&1 || critical_error "yum update failed."
    yum install -y unzip vlc libva fontconfig >> "$LOGFILE" 2>&1 || critical_error "yum install failed."
    info "Dependencies installed successfully using yum."
else
    critical_error "Unsupported package manager. Please install dependencies manually."
fi

# Check for existing AgentDVR installation
AGENT_FILE="$INSTALL_PATH/Agent"
if [ -f "$AGENT_FILE" ]; then
    read -rp "Found Agent in $INSTALL_PATH. Would you like to reinstall? (y/n): " REINSTALL </dev/tty
    REINSTALL=${REINSTALL,,}  # Convert to lowercase
    if [[ "$REINSTALL" != "y" ]]; then
        info "Aborting installation as per user request."
        exit 0
    else
        info "Proceeding with reinstallation of AgentDVR."
    fi
fi

# Determine the download URL based on architecture
info "Determining download URL for architecture: $arch"
purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=Linux64&fromVersion=0&useBeta=${USE_BETA:-0}"

case "$arch" in
    'aarch64'|'arm64')
        purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=LinuxARM64&fromVersion=0&useBeta=${USE_BETA:-0}"
        ;;
    'arm'|'armv6l'|'armv7l')
        purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=LinuxARM&fromVersion=0&useBeta=${USE_BETA:-0}"
        ;;
esac

# Fetch the actual download URL
URL=$(curl -s --fail "$purl" | tr -d '"') || critical_error "Failed to fetch download URL from $purl."

#override for testing
info "Overriding URL for testing"
URL="https://ispyrtcdata.blob.core.windows.net/downloads/Agent_Linux64_5_8_1_0.zip"

info "Actual download URL obtained: $URL"

# Download AgentDVR with retry logic
download_agentdvr "$URL" "AgentDVR.zip"

# Extract the downloaded archive
info "Extracting AgentDVR.zip..."
if unzip AgentDVR.zip >> "$LOGFILE" 2>&1; then
    info "AgentDVR extracted successfully."
    rm AgentDVR.zip
    info "Removed AgentDVR.zip after extraction."
else
    critical_error "Failed to extract AgentDVR.zip."
fi

# Download start script for backward compatibility
info "Downloading start script for backward compatibility..."
if curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/start_agent.sh" -o "start_agent.sh" >> "$LOGFILE" 2>&1; then
    chmod a+x ./start_agent.sh
    info "Start script downloaded and made executable."
else
    critical_error "Failed to download start_agent.sh."
fi

# Set executable permissions
info "Setting execute permissions for Agent and scripts..."
chmod +x ./Agent || critical_error "Failed to set execute permission for Agent."
find . -name "*.sh" -exec chmod +x {} \; || critical_error "Failed to set execute permissions for scripts."
info "Execute permissions set successfully."

# Add user to 'video' group for device access
name=$(whoami)
info "Adding user '$name' to 'video' group for local device access..."
if machine_has "usermod"; then
    usermod -a -G video "$name" >> "$LOGFILE" 2>&1 || critical_error "Failed to append user '$name' to 'video' group."
elif machine_has "adduser"; then
    adduser "$name" video >> "$LOGFILE" 2>&1 || critical_error "Failed to add user '$name' to 'video' group."
else
    error_log "Neither 'usermod' nor 'adduser' command is available to modify user groups."
fi
info "User '$name' added to 'video' group successfully."

echo "To run AgentDVR either call $INSTALL_PATH/Agent from the terminal or install it as a system service."

# Option to set up as a system service
read -rp "Setup AgentDVR as a system service (y/n)? " answer </dev/tty
answer=${answer,,}  # Convert to lowercase

if [[ "$answer" == "y" || "$answer" == "yes" ]]; then 
    info "User opted to set up AgentDVR as a system service."

    info "Downloading AgentDVR.service file..."
    if curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/AgentDVR.service" -o "AgentDVR.service" >> "$LOGFILE" 2>&1; then
        info "AgentDVR.service downloaded successfully."
    else
        critical_error "Failed to download AgentDVR.service."
    fi

    # Update the service file with installation path and username
    info "Configuring AgentDVR.service file with installation path and username..."
    sed -i "s|AGENT_LOCATION|$INSTALL_PATH|g" AgentDVR.service || critical_error "Failed to update AGENT_LOCATION in AgentDVR.service."
    sed -i "s|YOUR_USERNAME|$name|g" AgentDVR.service || critical_error "Failed to update YOUR_USERNAME in AgentDVR.service."

    chmod 644 ./AgentDVR.service
    info "Set permissions for AgentDVR.service."

    # Stop and disable existing service if it exists
    systemctl stop AgentDVR.service >> "$LOGFILE" 2>&1 || info "AgentDVR.service was not running."
    systemctl disable AgentDVR.service >> "$LOGFILE" 2>&1 || info "AgentDVR.service was not enabled."

    # Remove existing service file if it exists
    if [ -f /etc/systemd/system/AgentDVR.service ]; then
        rm /etc/systemd/system/AgentDVR.service
        info "Removed existing /etc/systemd/system/AgentDVR.service."
    fi

    # Change ownership of installation directory
    chown "$name" -R "$INSTALL_PATH" || critical_error "Failed to change ownership of $INSTALL_PATH to $name."

    # Copy the service file to systemd directory
    cp AgentDVR.service /etc/systemd/system/AgentDVR.service || critical_error "Failed to copy AgentDVR.service to /etc/systemd/system/."
    rm -f AgentDVR.service
    info "AgentDVR.service copied to /etc/systemd/system and local copy removed."

    # Reload systemd daemon to recognize the new service
    systemctl daemon-reload >> "$LOGFILE" 2>&1 || critical_error "Failed to reload systemd daemon."

    # Enable and start the AgentDVR service
    systemctl enable AgentDVR.service >> "$LOGFILE" 2>&1 || critical_error "Failed to enable AgentDVR.service."
    systemctl start AgentDVR.service >> "$LOGFILE" 2>&1 || critical_error "Failed to start AgentDVR.service."
    info "AgentDVR service enabled and started successfully."

    echo "Started AgentDVR service."
    echo "Go to http://localhost:8090 to configure AgentDVR."
    exit 0
else
    info "User opted not to set up AgentDVR as a system service."
    echo "Starting Agent DVR from the terminal..."
    cd "$INSTALL_PATH" || critical_error "Failed to navigate to $INSTALL_PATH."
    ./Agent &
    sleep 2  # Give it a moment to start
    if pgrep -f "AgentDVR" > /dev/null; then
        info "AgentDVR started successfully."
        echo "AgentDVR is running. Visit http://localhost:8090 to configure."
    else
        error_log "Failed to start AgentDVR."
    fi
fi

info "===== AgentDVR Linux Setup Script Completed ====="
exit 0
