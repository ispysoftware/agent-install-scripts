#!/bin/bash

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./linux_setup2.sh` then `./linux_setup2.sh`

. /etc/*-release
arch=`uname -m`

ffmpeg_installed=false

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If arm64 AND darwin (macOS)
  echo "Use use osx_setup.sh instead"
  exit
fi

machine_has() {
    eval $invocation

    command -v "$1" > /dev/null 2>&1
    return $?
}

ABSOLUTE_PATH="${PWD}"
mkdir AgentDVR
cd AgentDVR

if [ "$DISTRIB_ID" = "Ubuntu" ] ; then
	read -p "Install ffmpeg v5 from package manager (y/n)? " answer
	if [ "$answer" != "${answer#[Yy]}" ] ;then 
	  echo Yes
	  sudo apt-get install -y software-properties-common alsa-utils
	  sudo add-apt-repository ppa:savoury1/ffmpeg4 -y
	  sudo add-apt-repository ppa:savoury1/ffmpeg5 -y
	  sudo apt update
	  sudo apt upgrade -y
	  sudo apt install ffmpeg -y
	  ffmpeg_installed=true
	fi
else
	echo "No default ffmpeg package option - build from source"
fi

if [ "$ffmpeg_installed" = false ]
then
	read -p "Build ffmpeg v5 for Agent DVR (y/n)? " answer
	if [ "$answer" != "${answer#[Yy]}" ] ;then 
		echo Yes
		
		
		echo "installing build tools"
		if machine_has "apt-get"; then
			sudo apt-get update \
				&& sudo apt-get install --no-install-recommends -y unzip python3 curl make g++ build-essential libvlc-dev vlc libx11-dev libtbb-dev libc6-dev gss-ntlmssp libusb-1.0-0-dev apt-transport-https libatlas-base-dev alsa-utils libxext-dev
		else
			sudo yum update \
				&& sudo yum install -y autoconf automake bzip2 bzip2-devel freetype-devel gcc gcc-c++ git libtool make pkgconfig zlib-devel libvlc-dev vlc libx11-dev libxext-dev
		fi

		
		mkdir -p ffmpeg-v5
		cd ffmpeg-v5
		curl -H 'Cache-Control: no-cache, no-store' -s -L "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/ffmpeg_build.sh" | bash -s -- --build --enable-gpl-and-non-free
		
		subScriptExitCode="$?"
		if [ "$subScriptExitCode" -ne 0 ]; then
		    exit 1
		fi
	fi
else
	echo "Found ffmpeg"
fi

cd $ABSOLUTE_PATH/AgentDVR/
#download latest version

FILE=$ABSOLUTE_PATH/AgentDVR/Agent
if [ ! -f $FILE ]
then
	echo "finding installer for $(arch)"
	purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=Linux64&fromVersion=0"
	#AGENTURL="https://ispyfiles.azureedge.net/downloads/Agent_Linux64_4_1_2_0.zip"
	
	case $(arch) in
		'aarch64' | 'arm64')
			purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=LinuxARM64&fromVersion=0"
			#AGENTURL="https://ispyfiles.azureedge.net/downloads/Agent_ARM64_4_1_2_0.zip"
		;;
		'arm' | 'armv6l' | 'armv7l')
			purl="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=LinuxARM&fromVersion=0"
			#AGENTURL="https://ispyfiles.azureedge.net/downloads/Agent_ARM32_4_1_2_0.zip"
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

#for backward compat with existing service files

echo "downloading start script for back compat"
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

	sudo systemctl daemon-reload
	sudo systemctl enable AgentDVR.service
	sudo systemctl start AgentDVR

	echo "started service"
	echo "go to http://localhost:8090 to configure"
	exit 0
else
	cd AgentDVR
	./Agent
fi

exit 0
