#!/bin/sh

# Homebrew Script for AgentDVR/ Linux
# To execute: save and `chmod +x ./agent_setup.sh` then `./agent_setup.sh`

ABSOLUTE_PATH="${PWD}"
echo "$ABSOLUTE_PATH"

#sudo apt-get update \
#	&& apt-get install -y unzip python3 curl make g++ build-essential

mkdir AgentDVR
cd AgentDVR
FILE=$ABSOLUTE_PATH/AgentDVR/Agent.dll
if [ ! -f $FILE ]
then
	purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=Linux"

	if [ $arch = 'aarch64' ] || [ $arch = 'arm64' ]
	then
		purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=ARM"
	fi
	if [ $arch = 'arm' ] || [ $arch = 'armv7l' ]
	then
		purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=false&platform=ARM32"
	fi
	AGENTURL=$(curl -s --fail "$purl" | tr -d '"')
	echo "Downloading $AGENTURL"
	curl --show-error --location "$AGENTURL" -o "AgentDVR.zip"
	unzip AgentDVR.zip && \ 
	rm AgentDVR.zip
fi

if [ ! -d $ABSOLUTE_PATH/.dotnet ]
then
	echo "Installing dotnet"
	curl -s "https://dot.net/v1/dotnet-install.sh" | bash -s -- --version "3.1.300" --install-dir "$ABSOLUTE_PATH/.dotnet"
fi

if [ ! -d $ABSOLUTE_PATH/ffmpeg-build ]
then
	mkdir ffmpeg-build
	cd ffmpeg-build
	curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/ffmpeg_build.sh" | bash -s -- --build --enable-gpl-and-non-free
fi

./start_agent.sh
exit
