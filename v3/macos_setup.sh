#!/bin/bash

# Update Script for AgentDVR/ OSX
# To execute: save and `chmod +x ./macos_setup.sh` then `./macos_setup.sh`

# Enable alias expansion
shopt -s expand_aliases

# Determine system architecture
arch=$(uname -m)

# Define constants
PLIST_NAME="com.ispy.agent.dvr.plist"
SYSTEM_LAUNCHDAEMONS_DIR="/Library/LaunchDaemons"
USER_LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"
LOGFILE="$HOME/agentdvr_setup.log"


# Redirect all stdout and stderr to the log file and to the terminal
exec > >(tee -a "$LOGFILE") 2> >(tee -a "$LOGFILE" >&2)

# Function to print info messages with timestamp
info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO]: $1"
}

# Function to print error messages with timestamp
error_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR]: $1" >&2
}

# Function to install Homebrew if not present
install_homebrew() {
    FILE="/usr/local/bin/brew"
    if [[ "$arch" == "arm64" ]]; then
        FILE="/opt/homebrew/bin/brew"
    fi

    if [ -f "$FILE" ]; then
        info "Using installed Homebrew at $FILE"
        brewcmd="$FILE"
    else
        info "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ "$arch" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        brewcmd="$(which brew)"
        if [ -z "$brewcmd" ]; then
            error_log "Homebrew installation failed."
            exit 1
        fi
        info "Homebrew installed successfully at $brewcmd"
    fi
}

# Function to run Agent manually
run_agent() {
    info "Running Agent manually..."
    "$INSTALL_PATH/Agent" &
    sleep 2  # Give it a moment to start
    if pgrep -f "Agent" > /dev/null; then
        info "Agent is running manually."
    else
        error_log "Failed to run Agent manually."
    fi
}

# Function to handle errors and attempt to restart Agent
handle_error() {
    error_log "$1"
    info "Attempting to restart Agent..."
    run_agent
}

# Function to check if a formula is installed
formula_installed() {
    if $brewcmd list --formula --versions | grep -q "^$1 $2"; then
        return 0  # Formula with version is installed
    else
        return 1  # Formula with version is not installed
    fi
}

# Function to install FFmpeg
install_ffmpeg() {
    if ! formula_installed "ffmpeg" "7"; then
        info "Installing FFmpeg and dependencies..."
        $brewcmd install curl ca-certificates
        if $brewcmd install ffmpeg@7; then
            info "FFmpeg v7 installed successfully."
        else
            handle_error "Failed to install FFmpeg v7."
        fi
    else
        info "FFmpeg v7 is already installed."
    fi
}

# Function to unload existing services
unload_services() {
    info "Stopping existing services..."

    # Unload any existing daemon
    if [ -f "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME" ]; then
        sudo launchctl unload -w "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME" && \
        info "Unloaded existing launch daemon." || \
        error_log "Failed to unload existing launch daemon."
        sudo rm -f "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME" && \
        info "Removed existing launch daemon plist." || \
        error_log "Failed to remove existing launch daemon plist."
    fi

    # Unload any existing agent
    if [ -f "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME" ]; then
        launchctl unload -w "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME" && \
        info "Unloaded existing launch agent." || \
        error_log "Failed to unload existing launch agent."
        rm -f "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME" && \
        info "Removed existing launch agent plist." || \
        error_log "Failed to remove existing launch agent plist."
    fi
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
        
        # Print progress bar to terminal, log output only for errors
        if curl --progress-bar --location "$url" -o "$output" 2> >(tee -a "$LOGFILE" >&2) > /dev/tty; then
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

# Function to download and install AgentDVR
install_agentdvr() {
    info "Installing AgentDVR to $INSTALL_PATH..."

    sudo mkdir -p "$INSTALL_PATH"
    cd "$INSTALL_PATH" || { error_log "Failed to navigate to $INSTALL_PATH."; exit 1; }

    # Determine the download URL based on architecture
    if [[ "$arch" == "arm64" ]]; then
        DOWNLOAD_URL_API="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSXARM64&fromVersion=0&useBeta=$( [ "$USE_BETA" = "true" ] && echo "True" || echo "False" )"
    else
        DOWNLOAD_URL_API="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSX64&fromVersion=0&useBeta=$( [ "$USE_BETA" = "true" ] && echo "True" || echo "False" )"
    fi

    # Fetch the actual download URL
    DOWNLOAD_URL=$(curl -s --fail -L "$DOWNLOAD_URL_API" | tr -d '"') || handle_error "Failed to fetch download URL from $DOWNLOAD_URL_API."

    info "Using download URL: $DOWNLOAD_URL"

    # Download AgentDVR with retry logic
    download_agentdvr "$DOWNLOAD_URL" "$INSTALL_PATH/AgentDVR.zip"

    # Extract the downloaded archive
    info "Extracting AgentDVR.zip..."
    if unzip -o "AgentDVR.zip" >> "$LOGFILE" 2>&1; then
        info "AgentDVR extracted successfully."
        rm "AgentDVR.zip"
        info "Removed AgentDVR.zip after extraction."
    else
        critical_error "Failed to extract AgentDVR.zip."
    fi

    # Check if Agent was successfully extracted
    if [ ! -f "$INSTALL_PATH/Agent" ]; then
        handle_error "Failed to download and extract AgentDVR after multiple attempts."
        exit 1
    fi

    # Set executable permissions
    chmod +x "$INSTALL_PATH/Agent"
    find "$INSTALL_PATH" -name "*.sh" -exec chmod +x {} \;
    info "Set executable permissions for AgentDVR."
}

# Function to set up as a launch daemon
setup_launch_daemon() {
    info "Setting up AgentDVR as a launch daemon..."

    # Download the plist file to a temporary location
    cd /tmp || { error_log "Failed to navigate to /tmp."; exit 1; }
    curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/launch_daemon.plist" -o "$PLIST_NAME" || handle_error "Failed to download launch daemon plist."

    # Update plist paths and set to run as root
    sudo sed -i '' "s|AGENT_LOCATION|${INSTALL_PATH}|" "$PLIST_NAME" || handle_error "Failed to update plist with install path."

    info "Creating service configuration..."

    # Ensure correct permissions on the plist file
    sudo chmod 644 "$PLIST_NAME"

    # Move plist to LaunchDaemons and set ownership
    sudo cp "$PLIST_NAME" "$SYSTEM_LAUNCHDAEMONS_DIR/" || handle_error "Failed to copy plist to LaunchDaemons."
    sudo rm -f "$PLIST_NAME"
    sudo chmod 644 "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME"
    sudo chown root:wheel "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME"

    # Load the new daemon
    sudo launchctl load -w "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME" || handle_error "Failed to load the launch daemon."

    info "Launch Daemon started successfully."
    info "Visit http://localhost:8090 to configure AgentDVR."
    exit 0
}

# Function to set up as a launch agent
setup_launch_agent() {
    info "Setting up AgentDVR as a launch agent..."

    # Download the plist file to a temporary location
    cd /tmp || { error_log "Failed to navigate to /tmp."; exit 1; }
    curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/launch_agent.plist" -o "$PLIST_NAME" || handle_error "Failed to download launch agent plist."

    # Update plist paths
    sed -i '' "s|AGENT_LOCATION|${INSTALL_PATH}|" "$PLIST_NAME" || handle_error "Failed to update plist with install path."

    info "Creating service configuration..."

    # Ensure correct permissions on the plist file
    chmod 644 "$PLIST_NAME"

    # Move plist to LaunchAgents and set permissions
    mkdir -p "$USER_LAUNCHAGENTS_DIR"
    cp "$PLIST_NAME" "$USER_LAUNCHAGENTS_DIR/" || handle_error "Failed to copy plist to LaunchAgents."
    rm -f "$PLIST_NAME"
    chmod 644 "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME"

    # Load the new agent
    launchctl load -w "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME" || handle_error "Failed to load the launch agent."

    info "Launch Agent started successfully."
    info "Visit http://localhost:8090 to configure AgentDVR."
    exit 0
}

# Main script execution starts here

info "===== AgentDVR macOS Setup Script Started ====="

# Check if the script is running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    error_log "This script is intended for macOS. Please use linux_setup.sh for Linux."
    exit 1
fi

# Install Homebrew
install_homebrew

# Install FFmpeg
install_ffmpeg

# Unload any existing services
unload_services

# Prompt user for setup choice
info ""
info "AgentDVR can be set up to start automatically in two ways:"
info "1. As a launch daemon: Starts with the computer but does NOT have access to local devices (cameras/microphones)."
info "2. As a launch agent: Starts when you log in and HAS access to local devices."
info ""
read -rp "Would you like to set up AgentDVR as a launch daemon (1) or a launch agent (2)? Enter 1 or 2 (or any other key to skip): " choice </dev/tty

# Set installation path based on choice
if [[ "$choice" == "1" ]]; then
    INSTALL_PATH="/Applications/AgentDVR"
    info "Selected setup as Launch Daemon."
elif [[ "$choice" == "2" ]]; then
    INSTALL_PATH="$HOME/Applications/AgentDVR"
    info "Selected setup as Launch Agent."
else
    INSTALL_PATH="$HOME/Applications/AgentDVR"
    info "No automatic launch setup selected. AgentDVR will be installed to $INSTALL_PATH."
fi

AGENT_FILE="$INSTALL_PATH/Agent"
if [ -f "$AGENT_FILE" ]; then
    read -rp "Found Agent in $INSTALL_PATH. Would you like to update? (y/n): " REINSTALL </dev/tty
    if [[ "$REINSTALL" != "y" && "$REINSTALL" != "Y" ]]; then
        info "Aborting installation as per user request."
        exit 0
    else
        info "Proceeding with reinstallation of AgentDVR."
    fi
fi

# Install AgentDVR
install_agentdvr

# Set up launch daemon or agent based on user choice
if [[ "$choice" == "1" ]]; then
    setup_launch_daemon
elif [[ "$choice" == "2" ]]; then
    setup_launch_agent
else
    info "Skipping automatic launch setup."
    info "You can start AgentDVR manually from $INSTALL_PATH/Agent."
    info "Starting AgentDVR..."
    run_agent
    info "AgentDVR started successfully."
fi

info "===== AgentDVR macOS Setup Script Completed ====="
