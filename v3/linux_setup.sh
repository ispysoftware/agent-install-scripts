#!/bin/bash

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./linux_setup2.sh` then `./linux_setup2.sh`

. /etc/*-release
arch=`uname -m`

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If arm64 AND darwin (macOS)
  echo "Use use osx_setup2.sh instead"
  exit
fi

machine_has() {
    eval $invocation

    command -v "$1" > /dev/null 2>&1
    return $?
}

# Stop it if it's running
sudo systemctl stop AgentDVR.service

ABSOLUTE_PATH="${PWD}"
mkdir AgentDVR
cd $ABSOLUTE_PATH/AgentDVR/

if machine_has "apt-get"; then
	sudo apt-get update \
		&& sudo apt-get install --no-install-recommends -y unzip apt-transport-https alsa-utils libxext-dev fontconfig libva-drm2
else
	sudo yum update \
		&& sudo yum install -y bzip2 vlc libva fontconfig
fi


#download latest version

FILE=$ABSOLUTE_PATH/AgentDVR/Agent
if [ ! -f $FILE ]
then
	echo "Finding installer for $(arch)"
	purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=Linux64&fromVersion=0"
	
	case $(arch) in
		'aarch64' | 'arm64')
			purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=LinuxARM64&fromVersion=0"
		;;
		'arm' | 'armv6l' | 'armv7l')
      			purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=LinuxARM&fromVersion=0"
		;;
	esac

	URL=$(curl -s --fail "$purl" | tr -d '"')
	URL="https://ispyrtcdata.blob.core.windows.net/downloads/Agent_Linux64_5_8_1_0.zip"

	echo "Downloading $URL"
	curl --show-error --location "$URL" -o "AgentDVR.zip"
	
	if machine_has "apt-get"; then
		sudo apt-get install unzip
	else
		sudo yum install bzip2
	fi
	
	unzip AgentDVR.zip
	rm AgentDVR.zip
else
	echo "Found Agent in $ABSOLUTE_PATH/AgentDVR - delete it to reinstall"
fi

#for backward compat with existing service files

echo "Downloading start script for back compat"
curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/start_agent.sh" -o "start_agent.sh"
chmod a+x ./start_agent.sh

echo "Adding execute permissions"
chmod +x ./Agent
find . -name "*.sh" -exec chmod +x {} \;

cd $ABSOLUTE_PATH

name=$(whoami)
#add permissions for local device access
echo "Adding permission for local device access"
sudo adduser $name video
sudo usermod -a -G video $name

echo "To run Agent either call ./Agent from the terminal or install it as a system service."

read -p "Setup AgentDVR as system service (y/n)? " answer
if [ "$answer" != "${answer#[Yy]}" ] ;then 
	echo Yes
	echo "Installing service as $name"
	curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/AgentDVR.service" -o "AgentDVR.service"
	sed -i "s|AGENT_LOCATION|$ABSOLUTE_PATH/AgentDVR|" AgentDVR.service
	sed -i "s|YOUR_USERNAME|$name|" AgentDVR.service
	sudo chmod 644 ./AgentDVR.service
	
	sudo systemctl stop AgentDVR.service
  	sudo systemctl disable AgentDVR.service
	if [ -f /etc/systemd/system/AgentDVR.service ]; then
  		sudo rm /etc/systemd/system/AgentDVR.service
	fi
  
	sudo chown $name -R $ABSOLUTE_PATH/AgentDVR
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
	cd AgentDVR
	./Agent
fi

exit 0
