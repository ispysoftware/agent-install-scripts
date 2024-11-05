#!/bin/bash

# To execute: save and `chmod +x ./osx_setup.sh` then `sudo ./osx_setup.sh`
shopt -s expand_aliases

arch=`uname -m`
ABSOLUTE_PATH="/Library/Application Support/AgentDVR"
echo "Installing to $ABSOLUTE_PATH"

# Create the target directory in Application Support
sudo mkdir -p "$ABSOLUTE_PATH"
cd "$ABSOLUTE_PATH"	

FILE="$ABSOLUTE_PATH/Agent"
if [ -f "$FILE" ]; then
    echo "Found Agent in $ABSOLUTE_PATH - delete it to reinstall"
    sudo chmod +x "$FILE"
else
    if [[ "$arch" == "arm64" ]]; then
        URL=$((curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSXARM64&fromVersion=0") | tr -d '"')
    else
        URL=$((curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSX64&fromVersion=0") | tr -d '"')
    fi
    URL="https://ispyrtcdata.blob.core.windows.net/downloads/Agent_OSXARM64_5_8_1_0.zip"
    echo "Downloading $URL"
    curl --show-error --location $URL | sudo tar -xf - -C "$ABSOLUTE_PATH"
    sudo chmod +x Agent
    sudo find . -name "*.sh" -exec chmod +x {} \;
fi

echo -n "Setup AgentDVR as system service (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ]; then 
    echo "Setting up AgentDVR as a system service"
    
    # Download the plist file to a temporary location
    cd /tmp
    curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/com.ispy.agent.dvr.plist" -o "com.ispy.agent.dvr.plist"

    # Update plist paths and set to run as root
    sudo sed -i '' "s|AGENT_LOCATION|$ABSOLUTE_PATH|" com.ispy.agent.dvr.plist
    sudo sed -i '' "s|YOUR_USERNAME|root|" com.ispy.agent.dvr.plist

    echo "Creating service config"

    # Ensure correct permissions on the plist file
    sudo chmod 644 com.ispy.agent.dvr.plist

    # Unload any existing daemon
    if [ -f /Library/LaunchDaemons/com.ispy.agent.dvr.plist ]; then
        sudo launchctl unload -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist
        sudo rm -f /Library/LaunchDaemons/com.ispy.agent.dvr.plist
    fi

    # Move plist to LaunchDaemons and set permissions
    sudo cp com.ispy.agent.dvr.plist /Library/LaunchDaemons/
    rm -f com.ispy.agent.dvr.plist
    sudo chown root:wheel /Library/LaunchDaemons/com.ispy.agent.dvr.plist

    # Load the new daemon
    sudo launchctl load -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist

    echo "Service started"
    echo "Visit http://localhost:8090 to configure"
    exit
else
    echo "Starting AgentDVR"
    cd "$ABSOLUTE_PATH"
    sudo ./Agent
fi
