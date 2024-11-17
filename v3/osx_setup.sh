#!/bin/bash

# Homebrew Script for AgentDVR/ OSX
# To execute: save and `chmod +x ./osx_setup.sh` then `./osx_setup.sh`

set -e  # Exit on any command failure

arch=$(uname -m)

ABSOLUTE_PATH="/Applications"
PLIST_NAME="com.ispy.agent.dvr.plist"
SYSTEM_LAUNCHDAEMONS_DIR="/Library/LaunchDaemons"
USER_LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"

# Create the Applications directory if it doesn't exist
mkdir -p "$ABSOLUTE_PATH/AgentDVR"
cd "$ABSOLUTE_PATH/AgentDVR"

FILE="/usr/local/bin/brew"
if [[ "$arch" == "arm64" ]]; then
    FILE="/opt/homebrew/bin/brew"
fi

if [ -f "$FILE" ]; then
    echo "Using installed homebrew at $FILE"
    brewcmd="$FILE"
else
    echo "Installing homebrew"
    bash <(curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh")
    brewcmd="$FILE"
fi

formula_installed() {
    $brewcmd list --formula --versions | grep -q "^$1 $2$"
}

if ! formula_installed "ffmpeg" "7"; then
    echo "Installing ffmpeg"
    $brewcmd install curl ca-certificates
    $brewcmd install ffmpeg@7
else
    echo "Found FFmpeg v7"
fi

AGENT_FILE="$ABSOLUTE_PATH/AgentDVR/Agent"
if [ -f "$AGENT_FILE" ]; then
    echo "Found Agent in $ABSOLUTE_PATH/AgentDVR. Would you like to reinstall? (y/n)"
    read -r REINSTALL
    if [[ "$REINSTALL" != "y" ]]; then
        echo "Aborting installation."
        exit 1
    fi
fi

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

echo "Installing to $ABSOLUTE_PATH/AgentDVR"

# Determine the download URL based on architecture
if [[ "$arch" == "arm64" ]]; then
    URL=$(curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSXARM64&fromVersion=0" | tr -d '"')
else
    URL=$(curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSX64&fromVersion=0" | tr -d '"')
fi

URL="https://ispyrtcdata.blob.core.windows.net/downloads/Agent_OSXARM64_5_8_1_0.zip"

echo "Downloading $URL"
curl --show-error --location "$URL" | tar -xf - -C "$ABSOLUTE_PATH/AgentDVR"

chmod +x "$ABSOLUTE_PATH/AgentDVR/Agent"
find "$ABSOLUTE_PATH/AgentDVR" -name "*.sh" -exec chmod +x {} \;

echo -n "Setup AgentDVR as a launch daemon (y/n)? "
read -r answer
if [[ "$answer" =~ ^[Yy]$ ]]; then 
    echo "Setting up AgentDVR as a launch daemon"
    read -p "Enter your username [$(whoami)]: " name
    name=${name:-$(whoami)}

    # Download the plist file to a temporary location
    cd /tmp
    curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/launch_daemon.plist" -o "$PLIST_NAME"

    # Update plist paths and set to run as root
    sudo sed -i '' "s|AGENT_LOCATION|${ABSOLUTE_PATH}/AgentDVR|" "$PLIST_NAME"
    sudo sed -i '' "s|YOUR_USERNAME|${name}|" "$PLIST_NAME"
    echo "Creating service config"

    # Ensure correct permissions on the plist file
    sudo chmod 644 "$PLIST_NAME"

    # Move plist to LaunchAgents and set permissions
    sudo cp "$PLIST_NAME" "$SYSTEM_LAUNCHDAEMONS_DIR/"
    rm -f "$PLIST_NAME"
    sudo chmod 644 "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME"
    sudo chown root:wheel "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME"

    # Load the new agent
    sudo launchctl load -w "$SYSTEM_LAUNCHDAEMONS_DIR/$PLIST_NAME"

    echo "Launch Daemon started successfully."
    echo "Visit http://localhost:8090 to configure"
    exit
else
    echo "Starting AgentDVR"
    cd "$ABSOLUTE_PATH/AgentDVR"
    ./Agent
fi
