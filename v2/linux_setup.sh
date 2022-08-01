#!/bin/bash

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./linux_setup2.sh` then `./linux_setup2.sh`

. /etc/lsb-release
arch=`uname -m`

ffmpeg_installed=false

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If arm64 AND darwin (macOS)
  echo "Use use osx_setup.sh instead"
  exit
fi


ABSOLUTE_PATH="${PWD}"
mkdir AgentDVR
cd AgentDVR

#download latest version

FILE=$ABSOLUTE_PATH/AgentDVR/Agent
if [ ! -f $FILE ]
then
	echo "finding installer for $(arch)"
	purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=Linux"
	case $(arch) in
		'aarch64' | 'arm64')
			purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=ARM"
		;;
		'arm' | 'armv6l' | 'armv7l')
			purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=false&platform=ARM32"
		;;
	esac

	AGENTURL=$(curl -s --fail "$purl" | tr -d '"')
	echo "Downloading $AGENTURL"
	curl --show-error --location "$AGENTURL" -o "AgentDVR.zip"
	unzip AgentDVR.zip
	rm AgentDVR.zip
else
	echo "Found Agent in $ABSOLUTE_PATH/AgentDVR - delete it to reinstall"
fi

if [ "$DISTRIB_ID" = "Ubuntu" ] ; then
  sudo add-apt-repository ppa:savoury1/ffmpeg4 -y
  sudo add-apt-repository ppa:savoury1/ffmpeg5 -y
  sudo apt update
  sudo apt upgrade -y
  sudo apt install ffmpeg -y
  ffmpeg_installed=true
else
	echo "No default ffmpeg package option - build from source"
fi

if [ "$ffmpeg_installed" = false ]
then
	read -p "Build ffmpeg v5 for Agent (y/n)? " answer
	if [ "$answer" != "${answer#[Yy]}" ] ;then 
		echo Yes
		mkdir ffmpeg-build
		cd ffmpeg-build
		curl -s -L "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/ffmpeg_build.sh" | bash -s -- --build --enable-gpl-and-non-free
	fi
else
	echo "Found ffmpeg"
fi

cd $ABSOLUTE_PATH

name=$(whoami)
#add permissions for local device access
echo "Adding permission for local device access"
sudo adduser $name video
sudo usermod -a -G video $name

echo "Adding execute permissions"
sudo chmod +x ./Agent
sudo chmod +x ./agent-register.sh
sudo chmod +x ./agent-reset.sh
sudo chmod +x ./agent-reset-local-login.sh

read -p "Install AgentDVR as system service (y/n)? " answer
if [ "$answer" != "${answer#[Yy]}" ] ;then 
	echo Yes
	echo "Installing service as $name"
	curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/AgentDVR.service" -o "AgentDVR.service"
	sed -i "s|AGENT_LOCATION|$ABSOLUTE_PATH|" AgentDVR.service
	sed -i "s|YOUR_USERNAME|$name|" AgentDVR.service
	sudo chmod 644 ./AgentDVR.service
	
	sudo systemctl stop AgentDVR.service
  	sudo systemctl disable AgentDVR.service
  	sudo rm /etc/systemd/system/AgentDVR.service
  
	sudo chown $name -R $ABSOLUTE_PATH/AgentDVR
	sudo cp AgentDVR.service /etc/systemd/system/AgentDVR.service

	sudo systemctl daemon-reload
	sudo systemctl enable AgentDVR.service
	sudo systemctl start AgentDVR

	echo "started service"
	echo "go to http://localhost:8090 to configure"
	exit 0
else
	./Agent
fi

exit 0
