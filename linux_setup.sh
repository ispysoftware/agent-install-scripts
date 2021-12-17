#!/bin/sh

# Homebrew Script for AgentDVR/ Linux
# To execute: save and `chmod +x ./linux_setup.sh` then `./linux_setup.sh`

ABSOLUTE_PATH="${PWD}"
echo "$ABSOLUTE_PATH"

sudo apt-get update \
	&& apt-get install -y unzip python3 curl make g++ build-essential


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
	purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=Linux"

	if [ $arch = 'aarch64' ] || [ $arch = 'arm64' ]
	then
		purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=ARM"
	fi
	if [ $arch = 'arm' ] || [ $arch = 'armv7l' || [ $arch = 'armv6l' ]
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

if [ ! -d $ABSOLUTE_PATH/AgentDVR/ffmpeg-build ]
then
	mkdir ffmpeg-build
	cd ffmpeg-build
	curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/ffmpeg_build.sh" | bash -s -- --build --enable-gpl-and-non-free
fi

cd $ABSOLUTE_PATH

echo -n "Install AgentDVR as system service (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then 
	echo Yes
	read -p "Enter your username [$(whoami)]: " name
	name=${name:-$(whoami)}
	curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/AgentDVR.service" -o "AgentDVR.service"
	sed -i "s|AGENT_LOCATION|$ABSOLUTE_PATH|" AgentDVR.service
	sed -i "s|YOUR_USERNAME|$name|" AgentDVR.service
	sudo chmod a+x ./AgentDVR.service
	sudo chown $name -R $ABSOLUTE_PATH/AgentDVR
	sudo cp AgentDVR.service /etc/systemd/system/AgentDVR.service
	sudo systemctl daemon-reload
	sudo systemctl start AgentDVR
	echo "started service"
	echo "go to http://localhost:8090 to configure"
else
	./start_agent.sh
fi

exit
