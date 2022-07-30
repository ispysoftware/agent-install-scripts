#!/bin/sh

# Homebrew Script for AgentDVR/ OSX
# To execute: save and `chmod +x ./agent_setup.sh` then `./agent_setup.sh`
shopt -s expand_aliases

ABSOLUTE_PATH="${PWD}"
echo "$ABSOLUTE_PATH"

mkdir AgentDVR
cd AgentDVR


FILE=$ABSOLUTE_PATH/AgentDVR/homebrew
if [ ! -d $FILE ]
then
	echo "Downloading brew..."
	cd ~/Downloads
	mkdir homebrew
	curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew

	mv homebrew "$ABSOLUTE_PATH/AgentDVR/homebrew"
else
	echo "Found homebrew in $ABSOLUTE_PATH/AgentDVR/homebrew"
fi

echo "Setting brew alias"
alias axbrew='arch -x86_64 $ABSOLUTE_PATH/AgentDVR/homebrew/bin/brew'

echo "Installing ffmpeg v5"
axbrew install ffmpeg

FILE=$ABSOLUTE_PATH/AgentDVR/Agent
if [ ! -f $FILE ]
then
    URL=$((curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=OSX") | tr -d '"')
    echo "Downloading $URL"
    curl --show-error --location $URL | tar -xf - -C $ABSOLUTE_PATH/AgentDVR
    sudo chmod +x Agent
else
    echo "Found Agent in $ABSOLUTE_PATH/AgentDVR - delete it to reinstall"
fi


echo -n "Install AgentDVR as system service (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then 
	echo Yes
	read -p "Enter your username [$(whoami)]: " name
	name=${name:-$(whoami)}
	cd $ABSOLUTE_PATH/
	curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/com.ispy.agent.dvr.plist" -o "com.ispy.agent.dvr.plist"
	sed -i '' "s|AGENT_LOCATION|${ABSOLUTE_PATH}/AgentDVR|" com.ispy.agent.dvr.plist
	sed -i '' "s|YOUR_USERNAME|${name}|" com.ispy.agent.dvr.plist
	echo "Creating service config"
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
