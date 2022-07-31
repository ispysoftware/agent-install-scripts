#!/bin/bash

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./agent_setup.sh` then `./agent_setup.sh`

. /etc/lsb-release
arch=`uname -m`

ffmpeg_installed=false

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If arm64 AND darwin (macOS)
  echo "Use use macos_setup.sh instead"
  exit
fi


ABSOLUTE_PATH="${PWD}"
machine_has() {
    eval $invocation

    command -v "$1" > /dev/null 2>&1
    return $?
}
echo "installing build tools"
if machine_has "apt-get"; then
	sudo apt-get update \
		&& sudo apt-get install --no-install-recommends -y unzip python3 curl make g++ build-essential libvlc-dev vlc libx11-dev libtbb-dev libc6-dev gss-ntlmssp libusb-1.0-0-dev apt-transport-https libatlas-base-dev alsa-utils libxext-dev
else
	sudo yum update \
		&& sudo yum install -y autoconf automake bzip2 bzip2-devel cmake freetype-devel gcc gcc-c++ git libtool make pkgconfig zlib-devel libvlc-dev vlc libx11-dev libxext-dev
fi


FILE=$ABSOLUTE_PATH/start_agent.sh
if [ ! -f $FILE ]
then
	echo "downloading start script"
	curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/start_agent.sh" -o "start_agent.sh"
	chmod a+x ./start_agent.sh
fi

mkdir AgentDVR
cd AgentDVR

FILE=$ABSOLUTE_PATH/AgentDVR/Agent.dll
if [ ! -f $FILE ]
then
	echo "finding installer for $(arch)"
	purl="https://ispyfiles.azureedge.net/downloads/Agent_Linux64_4_1_1_0.zip"
	case $(arch) in
		'aarch64' | 'arm64')
			purl="https://ispyfiles.azureedge.net/downloads/Agent_ARM64_4_1_1_0.zip"
			# Install ffmpeg for arm from default package manager
			echo "installing ffmpeg for aarch64/arm64"
			sudo apt-get install -y ffmpeg
			ffmpeg_installed=true
		;;
		'arm' | 'armv6l' | 'armv7l')
			purl="https://ispyfiles.azureedge.net/downloads/Agent_ARM32_4_1_1_0.zip"
			# Install ffmpeg for arm from default package manager
			echo "installing ffmpeg for arm"
			sudo apt-get install -y ffmpeg
			ffmpeg_installed=true
		;;
	esac

	AGENTURL=$purl
	echo "Downloading $AGENTURL"
	curl --show-error --location "$AGENTURL" -o "AgentDVR.zip"
	unzip AgentDVR.zip
	rm AgentDVR.zip
else
	echo "Found Agent in $ABSOLUTE_PATH/AgentDVR - delete it to reinstall"
fi

if [ ! -d $ABSOLUTE_PATH/AgentDVR/.dotnet ]
then
	echo "Installing dotnet 3.1.300"
	curl -s -L "https://dot.net/v1/dotnet-install.sh" | bash -s -- --version "3.1.300" --install-dir "$ABSOLUTE_PATH/AgentDVR/.dotnet"
else
	echo "Found dotnet in $ABSOLUTE_PATH/AgentDVR/.dotnet - delete it to reinstall"
fi

if [ "$DISTRIB_ID" = "Ubuntu" ] ; then
	if (( $(echo "$DISTRIB_RELEASE > 21" | bc -l) )); then
		echo "Installing ffmpeg from default package manager (Ubuntu 21+)"
		sudo apt install ffmpeg
		# ubuntu 20+ needs a symlink to libdl to run properly
		if [ ! -f /lib/$(arch)-linux-gnu/libdl.so ]; then
			sudo ln -s /lib/$(arch)-linux-gnu/libdl.so.2 /lib/$(arch)-linux-gnu/libdl.so
		fi
		ffmpeg_installed=true
	elif [ "$DISTRIB_RELEASE" == "18.04" -o "$DISTRIB_RELEASE" == "16.04" ]; then
		echo "Installing ffmpeg from jonathonf repo (Ubuntu 18/16)"
		sudo apt-get update
		sudo add-apt-repository ppa:jonathonf/ffmpeg-4
		sudo apt-get update
		sudo apt-get install -y ffmpeg
		ffmpeg_installed=true
	else
		echo "No default ffmpeg package option - build from source (Ubuntu $DISTRIB_RELEASE)"
	fi
elif cat /etc/*release | grep ^NAME | grep Debian ; then
	read -d . debver < /etc/debian_version
	if (( $(echo "$debver > 8" | bc -l) )); then
		echo "Installing ffmpeg from default package manager (Debian 9+)"
		sudo apt-get install -y ffmpeg
		ffmpeg_installed=true
	else
		sudo apt-get install -y libxext-dev
		echo "No default ffmpeg package option - build from source"
	fi
else
	echo "No default ffmpeg package option - build from source"
fi

if [ "$ffmpeg_installed" = false ] && ! [ -d $ABSOLUTE_PATH/AgentDVR/ffmpeg-build ]
then
	read -p "Build ffmpeg for Agent (y/n)? " answer
	if [ "$answer" != "${answer#[Yy]}" ] ;then 
		echo Yes
		mkdir ffmpeg-build
		cd ffmpeg-build
		curl -s -L "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/ffmpeg_build.sh" | bash -s -- --build --enable-gpl-and-non-free
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

FILE=/etc/systemd/system/AgentDVR.service
if [ ! -f $FILE ]
then
	

	read -p "Install AgentDVR as system service (y/n)? " answer
	if [ "$answer" != "${answer#[Yy]}" ] ;then 
		echo Yes
		echo "Installing service as $name"
		curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/AgentDVR.service" -o "AgentDVR.service"
		sed -i "s|AGENT_LOCATION|$ABSOLUTE_PATH|" AgentDVR.service
		sed -i "s|YOUR_USERNAME|$name|" AgentDVR.service
		sudo chmod 644 ./AgentDVR.service
		sudo chown $name -R $ABSOLUTE_PATH/AgentDVR
		sudo cp AgentDVR.service /etc/systemd/system/AgentDVR.service
		
		sudo systemctl daemon-reload
		sudo systemctl enable AgentDVR.service
		sudo systemctl start AgentDVR
		
		echo "started service"
		echo "go to http://localhost:8090 to configure"
		exit 0
	else
		./start_agent.sh
	fi
else
	echo "Found service definition in /etc/systemd/system/AgentDVR.service"
	echo "Go to http://localhost:8090"
fi

exit 0
