#!/bin/bash

# To execute: save and `chmod +x ./osx_setup.sh` then `./osx_setup.sh`
shopt -s expand_aliases

arch=`uname -m`

ABSOLUTE_PATH="${PWD}"
echo "$ABSOLUTE_PATH"

mkdir -p AgentDVR
cd AgentDVR	

FILE=$ABSOLUTE_PATH/AgentDVR/Agent
if [ -f $FILE ]; then
	echo "Found Agent in $ABSOLUTE_PATH/AgentDVR - delete it to reinstall"
    chmod +x "$FILE"
else
	if [[ ("$(arch)" == "arm64") ]]; then
	 	URL=$((curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSXARM64&fromVersion=0") | tr -d '"')
	else
		URL=$((curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSX64&fromVersion=0") | tr -d '"')
	fi

	echo "Downloading $URL"
	curl --show-error --location $URL | tar -xf - -C $ABSOLUTE_PATH/AgentDVR
	chmod +x Agent
	find . -name "*.sh" -exec chmod +x {} \;
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
	sudo chmod a+x ./com.ispy.agent.dvr.plist
 
	if [ -f /Library/LaunchDaemons/com.ispy.agent.dvr.plist ]; then
 		sudo launchctl unload -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist
		sudo rm -f /Library/LaunchDaemons/com.ispy.agent.dvr.plist
	fi
 
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
