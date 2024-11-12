#!/bin/bash

# Homebrew Script for AgentDVR/ OSX
# To execute: save and `chmod +x ./osx_setup.sh` then `./osx_setup.sh`
shopt -s expand_aliases

arch=`uname -m`

ABSOLUTE_PATH="${PWD}"
PLIST_NAME="com.ispy.agent.dvr.plist"
SYSTEM_LAUNCHDAEMONS_DIR="/Library/LaunchDaemons"
USER_LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"

mkdir -p AgentDVR
cd AgentDVR

FILE=/usr/local/bin/brew
if [[ ("$(arch)" == "arm64") ]]; then
	FILE=/opt/homebrew/bin/brew
fi
if [ -f $FILE ]; then
	echo "Using installed homebrew at $FILE"
	alias brewcmd='$FILE'
else
	echo "Installing homebrew"
	bash <(curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh")
	alias brewcmd='$FILE'
fi

formula_installed() {
    [ "$(brew list --versions | grep "$1 $2")" ]
    return $?
}

formula_installed ffmpeg 7
if [ $? -eq 1 ]; then
	echo "Installing ffmpeg"
	brewcmd install curl ca-certificates
	brewcmd install ffmpeg@7
else
	echo "Found FFmpeg v7"
fi


FILE=$ABSOLUTE_PATH/AgentDVR/Agent
if [ -f $FILE ]; then
	echo "Found Agent in $ABSOLUTE_PATH/AgentDVR - delete it to reinstall"
else
  echo "Installing to $ABSOLUTE_PATH/AgentDVR"

  if [[ "$arch" == "arm64" ]]; then
      URL=$((curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSXARM64&fromVersion=0") | tr -d '"')
  else
      URL=$((curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSX64&fromVersion=0") | tr -d '"')
  fi
  URL="https://ispyrtcdata.blob.core.windows.net/downloads/Agent_OSXARM64_5_8_1_0.zip"
  echo "Downloading $URL"
  curl --show-error --location $URL | tar -xf - -C "$ABSOLUTE_PATH/AgentDVR"
  chmod +x Agent
  find . -name "*.sh" -exec chmod +x {} \;
fi

echo -n "Setup AgentDVR as launch agent (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ]; then 
    echo "Setting up AgentDVR as a launch agent"
    # Download the plist file to a temporary location
    cd /tmp
    curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/launchagent.plist" -o "$PLIST_NAME"

    # Update plist paths and set to run as root
    sudo sed -i '' "s|AGENT_LOCATION|${ABSOLUTE_PATH}/AgentDVR|" com.ispy.agent.dvr.plist

    echo "Creating service config"

    # Ensure correct permissions on the plist file
    sudo chmod a+x ./com.ispy.agent.dvr.plist

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
        
    # Move plist to LaunchAgents and set permissions
    cp "$PLIST_NAME" "$USER_LAUNCHAGENTS_DIR/"
    rm -f "$PLIST_NAME"
    chmod 644 "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME"
    chown "$(id -u):$(id -g)" "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME"
        
    # Load the new agent
    launchctl load -w "$USER_LAUNCHAGENTS_DIR/$PLIST_NAME"
        
    echo "Launch Agent started successfully."
    echo "Visit http://localhost:8090 to configure"
    exit
else
    echo "Starting AgentDVR"
    cd "$ABSOLUTE_PATH"
    ./Agent
fi
