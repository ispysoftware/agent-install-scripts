#!/bin/bash

# Homebrew Script for AgentDVR/ OSX
# To execute: save and `chmod +x ./osx_setup.sh` then `./osx_setup.sh`

set -e  # Exit on any command failure

arch=$(uname -m)

PLIST_NAME="com.ispy.agent.dvr.plist"
SYSTEM_LAUNCHDAEMONS_DIR="/Library/LaunchDaemons"
USER_LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"

# Function to install Homebrew if not present
install_homebrew() {
    FILE="/usr/local/bin/brew"
    if [[ "$arch" == "arm64" ]]; then
        FILE="/opt/homebrew/bin/brew"
    fi

    if [ -f "$FILE" ]; then
        echo "Using installed Homebrew at $FILE"
        brewcmd="$FILE"
    else
        echo "Installing Homebrew"
        bash <(curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh")
        if [[ "$arch" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        brewcmd="$(which brew)"
    fi
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
        echo "Installing FFmpeg"
        $brewcmd install curl ca-certificates
        $brewcmd install ffmpeg@7
    else
        echo "Found FFmpeg v7"
    fi
}

# Function to unload existing services
unload_services() {
    echo "Stopping services"

    # Unload any existing daemon
    if [ -f "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME" ]; then
        sudo launchctl unload -w "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME"
        sudo rm -f "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME"
    fi

    # Unload any existing agent
    if [ -f "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME" ]; then
        launchctl unload -w "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME"
        rm -f "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME"
    fi
}

# Function to download and install AgentDVR
install_agentdvr() {
    echo "Installing to $INSTALL_PATH/AgentDVR"

    sudo mkdir -p "$INSTALL_PATH/AgentDVR"
    cd "$INSTALL_PATH/AgentDVR"

    # Determine the download URL based on architecture
    if [[ "$arch" == "arm64" ]]; then
        URL=$(curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSXARM64&fromVersion=0&useBeta=${USE_BETA:-0}" | tr -d '"')
    else
        URL=$(curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSX64&fromVersion=0&useBeta=${USE_BETA:-0}" | tr -d '"')
    fi

    echo "Downloading $URL"
    curl --show-error --location "$URL" | tar -xf - -C "$INSTALL_PATH/AgentDVR"

    chmod +x "$INSTALL_PATH/AgentDVR/Agent"
    find "$INSTALL_PATH/AgentDVR" -name "*.sh" -exec chmod +x {} \;
}

# Function to set up as a launch daemon
setup_launch_daemon() {
    echo "Setting up AgentDVR as a launch daemon"
    # Download the plist file to a temporary location
    cd /tmp
    curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/launch_daemon.plist" -o "$PLIST_NAME"

    # Update plist paths and set to run as root
    sudo sed -i '' "s|AGENT_LOCATION|${INSTALL_PATH}/AgentDVR|" "$PLIST_NAME"
    echo "Creating service config"

    # Ensure correct permissions on the plist file
    sudo chmod 644 "$PLIST_NAME"

    # Move plist to LaunchDaemons and set permissions
    sudo cp "$PLIST_NAME" "$SYSTEM_LAUNCHDAEMONS_DIR/"
    sudo rm -f "$PLIST_NAME"
    sudo chmod 644 "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME"
    sudo chown root:wheel "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME"

    # Load the new daemon
    sudo launchctl load -w "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME"

    echo "Launch Daemon started successfully."
    echo "Visit http://localhost:8090 to configure"
    exit
}

# Function to set up as a launch agent
setup_launch_agent() {
    echo "Setting up AgentDVR as a launch agent"

    # Download the plist file to a temporary location
    cd /tmp
    curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/launch_agent.plist" -o "$PLIST_NAME"

    # Update plist paths
    sed -i '' "s|AGENT_LOCATION|${INSTALL_PATH}/AgentDVR|" "$PLIST_NAME"
    echo "Creating service config"

    # Ensure correct permissions on the plist file
    chmod 644 "$PLIST_NAME"

    # Move plist to LaunchAgents and set permissions
    mkdir -p "$USER_LAUNCHAGENTS_DIR"
    cp "$PLIST_NAME" "$USER_LAUNCHAGENTS_DIR/"
    rm -f "$PLIST_NAME"
    chmod 644 "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME"

    # Load the new agent
    launchctl load -w "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME"

    echo "Launch Agent started successfully."
    echo "Visit http://localhost:8090 to configure"
    exit
}

# Main script execution starts here

# Install Homebrew
install_homebrew

# Install FFmpeg
install_ffmpeg

# Unload any existing services
unload_services

# Ask user for setup choice
echo ""
echo "AgentDVR can be set up to start automatically in two ways:"
echo "1. As a launch daemon: Starts with the computer but does NOT have access to local devices (cameras/microphones)."
echo "2. As a launch agent: Starts when you log in and HAS access to local devices."
echo ""
echo -n "Would you like to set up AgentDVR as a launch daemon (1) or a launch agent (2)? Enter 1 or 2 (or any other key to skip): "
read -r choice

# Set installation path based on choice
if [[ "$choice" == "1" ]]; then
    INSTALL_PATH="/Applications"
elif [[ "$choice" == "2" ]]; then
    INSTALL_PATH="$HOME/Applications"
else
    INSTALL_PATH="$HOME/Applications"
fi

AGENT_FILE="$INSTALL_PATH/AgentDVR/Agent"
if [ -f "$AGENT_FILE" ]; then
    echo "Found Agent in $INSTALL_PATH/AgentDVR. Would you like to reinstall? (y/n)"
    read -r REINSTALL
    if [[ "$REINSTALL" != "y" ]]; then
        echo "Aborting installation."
        exit 1
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
    echo "Skipping launch setup. You can start AgentDVR manually from $INSTALL_PATH/AgentDVR/Agent"
    echo "Starting AgentDVR"
    cd "$INSTALL_PATH/AgentDVR"
    ./Agent
fi
