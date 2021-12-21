#!/bin/sh

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./agent_setup.sh` then `./agent_setup.sh`

. /etc/lsb-release


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
		&& sudo apt-get install -y unzip python3 curl make g++ build-essential libvlc-dev vlc libx11-dev libtbb-dev libc6-dev gss-ntlmssp libusb-1.0-0-dev
else
	sudo yum update \
		&& sudo yum install -y autoconf automake bzip2 bzip2-devel cmake freetype-devel gcc gcc-c++ git libtool make pkgconfig zlib-devel libvlc-dev vlc libx11-dev
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

if [ ! -d $ABSOLUTE_PATH/AgentDVR/.dotnet ]
then
	echo "Installing dotnet 3.1.300"
	curl -s -L "https://dot.net/v1/dotnet-install.sh" | bash -s -- --version "3.1.300" --install-dir "$ABSOLUTE_PATH/AgentDVR/.dotnet"
else
	echo "Found dotnet in $ABSOLUTE_PATH/AgentDVR/.dotnet - delete it to reinstall"
fi

ffmpeg_installed=false

if [ $DISTRIB_ID == "Ubuntu" ] ;then
	if (( $(echo "$DISTRIB_RELEASE > 21" | bc -l) )); then
		echo "Installing ffmpeg from default package manager (Ubuntu 21+)"
		sudo apt install ffmpeg
		# ubuntu 20+ needs a symlink to libdl to run properly
		if [ ! -f /lib/x86_64-linux-gnu/libdl.so ]; then
			sudo ln -s /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so
		fi
	else
		echo "Installing ffmpeg from jonathonf repo"
		sudo apt-get update
		sudo add-apt-repository ppa:jonathonf/ffmpeg-4
		sudo apt-get update
		sudo apt-get install -y ffmpeg
	fi
	ffmpeg_installed=true
elif cat /etc/*release | grep ^NAME | grep Debian ; then
	sudo wget http://security.ubuntu.com/ubuntu/pool/main/libj/libjpeg-turbo/libjpeg-turbo8_1.5.2-0ubuntu5.18.04.4_amd64.deb
	sudo wget http://fr.archive.ubuntu.com/ubuntu/pool/main/libj/libjpeg8-empty/libjpeg8_8c-2ubuntu8_amd64.deb
	sudo apt install multiarch-support
	sudo dpkg -i libjpeg-turbo8_1.5.2-0ubuntu5.18.04.4_amd64.deb
	sudo dpkg -i libjpeg8_8c-2ubuntu8_amd64.deb
	
	sudo add-apt-repository ppa:savoury1/ffmpeg4
	sudo apt-get update
	sudo apt-get install -y ffmpeg	
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


FILE=/etc/systemd/system/AgentDVR.service
if [ ! -f $FILE ]
then
	read -p "Install AgentDVR as system service (y/n)? " answer
	if [ "$answer" != "${answer#[Yy]}" ] ;then 
		echo Yes
		echo "Installing service as [$(whoami)]"
		name=$(whoami)
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
		exit
	else
		./start_agent.sh
	fi
else
	echo "Found service definition in /etc/systemd/system/AgentDVR.service"
	echo "Go to http://localhost:8090"
fi

exit 0
