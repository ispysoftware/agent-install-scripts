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
	if [ "$DISTRIB_RELEASE" = "22.10" ] ; then
		read -p "Install ffmpeg from apt for Ubuntu 22.10 (y/n)? " answer
		if [ "$answer" != "${answer#[Yy]}" ] ;then 
			sudo apt-get install -y ffmpeg
			ffmpeg_installed=true
		fi
	fi 
	if [ "$ffmpeg_installed" = false ] ; then
		read -p "Build ffmpeg v5 for Agent DVR (Ubuntu) (y/n)? " answer
		if [ "$answer" != "${answer#[Yy]}" ] ;then 
			sudo apt-get install -y alsa-utils build-essential xz-utils yasm cmake libtool libc6 libc6-dev unzip wget pkg-config libx264-dev libx265-dev libmp3lame-dev libopus-dev libvorbis-dev libfdk-aac-dev libvpx-dev libva-dev

			wget https://ffmpeg.org/releases/ffmpeg-5.1.2.tar.gz
			tar xf ffmpeg-5.1.2.tar.gz

	    		mkdir -p $ABSOLUTE_PATH/AgentDVR/ffmpeg-v5/workspace
			cd ffmpeg-5.1.2

			./configure --prefix=$ABSOLUTE_PATH/AgentDVR/ffmpeg-v5/workspace \
			  --target-os=linux \
			  --disable-debug \
			  --disable-doc \
			  --enable-shared \
			  --enable-pthreads \
			  --enable-hwaccels \
			  --enable-hardcoded-tables \
			  --enable-nonfree --disable-static --enable-gpl --enable-libx264 --enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libfdk-aac --enable-libx265 --enable-libvpx \
			  --enable-vaapi \


			make -j 8
			sudo make install
			rm -rf $ABSOLUTE_PATH/AgentDVR/ffmpeg-5.1.2
		fi
	fi
else
	read -p "Build ffmpeg v5 for Agent DVR (y/n)? " answer
	if [ "$answer" != "${answer#[Yy]}" ] ;then 
		echo Yes
		
		
		echo "Installing build tools"
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
fi

cd $ABSOLUTE_PATH/AgentDVR/
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

	AGENTURL=$(curl -s --fail "$purl" | tr -d '"')
	echo "Downloading $AGENTURL"
	curl --show-error --location "$AGENTURL" -o "AgentDVR.zip"
	
	if machine_has "apt-get"; then
		sudo apt-get unzip
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
