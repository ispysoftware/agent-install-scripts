#!/bin/bash

# Install script for AgentDVR on Linux
# To execute: save and `chmod +x ./linux_setup2.sh` then `./linux_setup.sh`

. /etc/*-release
arch=`uname -m`

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If arm64 AND darwin (macOS)
  echo "Use osx_setup_agent.sh instead"
  exit
fi

machine_has() {
    command -v "$1" > /dev/null 2>&1
    return $?
}

# Stop it if it's running
sudo systemctl stop AgentDVR.service || true

# Set installation path to /opt/AgentDVR
INSTALL_PATH="/opt/AgentDVR"
sudo mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"

if machine_has "apt-get"; then
	sudo apt-get update \
		&& sudo apt-get install --no-install-recommends -y unzip apt-transport-https alsa-utils libxext-dev fontconfig libva-drm2
else
	sudo yum update \
		&& sudo yum install -y unzip vlc libva fontconfig
fi

# Check for existing installation
FILE="$INSTALL_PATH/Agent"
if [ -f "$FILE" ]; then
    echo "Found Agent in $INSTALL_PATH. Would you like to reinstall? (y/n)"
    read -r REINSTALL
    if [[ "${REINSTALL,,}" != "y" ]]; then
        echo "Aborting installation."
        exit 1
    fi
fi

echo "Finding installer for $(arch)"
purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=Linux64&fromVersion=0&useBeta=${USE_BETA:-0}"
	
case $(arch) in
	'aarch64' | 'arm64')
		purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=LinuxARM64&fromVersion=0&useBeta=${USE_BETA:-0}"
	;;
	'arm' | 'armv6l' | 'armv7l')
      		purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=LinuxARM&fromVersion=0&useBeta=${USE_BETA:-0}"
	;;
esac

URL=$(curl -s --fail "$purl" | tr -d '"')

echo "Downloading $URL"
curl --show-error --location "$URL" -o "AgentDVR.zip"
	
if machine_has "apt-get"; then
	sudo apt-get install unzip
else
	sudo yum install bzip2
fi
	
sudo unzip AgentDVR.zip
rm AgentDVR.zip

# Download start script for backward compatibility
echo "Downloading start script for back compat"
curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/start_agent.sh" -o "start_agent.sh"
sudo chmod a+x ./start_agent.sh

echo "Adding execute permissions"
sudo chmod +x ./Agent
sudo find . -name "*.sh" -exec chmod +x {} \;

# Set permissions for the current user
name=$(whoami)
echo "Adding permission for local device access"
sudo adduser "$name" video
sudo usermod -a -G video "$name"

echo "To run Agent either call $INSTALL_PATH/Agent from the terminal or install it as a system service."

# Option to set up as a system service
read -p "Setup AgentDVR as system service (y/n)? " answer
if [ "$answer" != "${answer#[Yy]}" ] ;then 
	echo Yes
	echo "Installing service as $name"
	curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/AgentDVR.service" -o "AgentDVR.service"
	sed -i "s|AGENT_LOCATION|$INSTALL_PATH|" AgentDVR.service
	sed -i "s|YOUR_USERNAME|$name|" AgentDVR.service
	sudo chmod 644 ./AgentDVR.service
	
	sudo systemctl stop AgentDVR.service
  	sudo systemctl disable AgentDVR.service
	if [ -f /etc/systemd/system/AgentDVR.service ]; then
  		sudo rm /etc/systemd/system/AgentDVR.service
	fi
  
	sudo chown "$name" -R "$INSTALL_PATH"
	sudo cp AgentDVR.service /etc/systemd/system/AgentDVR.service
        sudo rm -f AgentDVR.service

	sudo systemctl daemon-reload
	sudo systemctl enable AgentDVR.service
	sudo systemctl start AgentDVR

	echo "Started service"
	echo "Go to http://localhost:8090 to configure"
	exit 0
else
	echo "Starting Agent DVR from the terminal.."
	cd "$INSTALL_PATH"
	./Agent
fi

exit 0
