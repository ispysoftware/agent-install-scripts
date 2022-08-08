#!/bin/bash

# Homebrew Script for AgentDVR/ OSX
# To execute: save and `chmod +x ./osx_setup.sh` then `./osx_setup.sh`
shopt -s expand_aliases

arch=`uname -m`

ABSOLUTE_PATH="${PWD}"
echo "$ABSOLUTE_PATH"

mkdir AgentDVR
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

needFFmpeg=$(formula_installed ffmpeg 5)
echo "need = $(needFFmpeg)"
if [ needFFMpeg -eq 1 ]; then
	echo "Installing ffmpeg v5"
	brewcmd install ffmpeg@5
else
	echo "Found FFmpeg v5+"
fi

FILE=$ABSOLUTE_PATH/AgentDVR/Agent
if [ -f $FILE ]; then
	echo "Found Agent in $ABSOLUTE_PATH/AgentDVR - delete it to reinstall"
else
	if [[ ("$(arch)" == "arm64") ]]; then
		URL="https://ispyfiles.azureedge.net/downloads/Agent_OSXARM64_4_1_2_0.zip" #$((curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=OSXARM") | tr -d '"')
	else
		URL="https://ispyfiles.azureedge.net/downloads/Agent_OSX64_4_1_2_0.zip" #$((curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=OSXARM") | tr -d '"')
	fi

	echo "Downloading $URL"
	curl --show-error --location $URL | tar -xf - -C $ABSOLUTE_PATH/AgentDVR
	sudo chmod +x Agent
	sudo chmod +x ./agent-register.sh
	sudo chmod +x ./agent-reset.sh
	sudo chmod +x ./agent-reset-local-login.sh
fi



echo -n "Setup AgentDVR as system service (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ]; then 
	echo Yes
	read -p "Enter your username [$(whoami)]: " name
	name=${name:-$(whoami)}
	cd $ABSOLUTE_PATH/
	curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/com.ispy.agent.dvr.plist" -o "com.ispy.agent.dvr.plist"
	sed -i '' "s|AGENT_LOCATION|${ABSOLUTE_PATH}/AgentDVR|" com.ispy.agent.dvr.plist
	sed -i '' "s|YOUR_USERNAME|${name}|" com.ispy.agent.dvr.plist
	echo "Creating service config"
	sudo launchctl unload -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist
	sudo chmod a+x ./com.ispy.agent.dvr.plist
	sudo cp com.ispy.agent.dvr.plist /Library/LaunchDaemons/
	rm -f com.ispy.agent.dvr.plist
	sudo chown root:wheel /Library/LaunchDaemons/com.ispy.agent.dvr.plist
	sudo launchctl load -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist

	echo "Started service"
	echo "go to http://localhost:8090 to configure"
	exit
else
	echo "Starting AgentDVR"
	cd $ABSOLUTE_PATH/AgentDVR
	./Agent
fi
