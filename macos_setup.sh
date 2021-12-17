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

if axbrew list dotnet-sdk3-1-300 &>/dev/null; then
	echo "dotnet installed"
else
	echo "Installing dotnet"
	axbrew tap isen-ng/dotnet-sdk-versions
	axbrew install --cask dotnet-sdk3-1-300
fi

if axbrew list ffmpeg@4 &>/dev/null; then
	echo "ffmpeg installed"
else
	echo "Installing ffmpeg"
	axbrew install ffmpeg@4
fi

FILE=$ABSOLUTE_PATH/AgentDVR/Agent.dll
if [ ! -f $FILE ]
then
    URL=$((curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=OSX") | tr -d '"')
    echo "Downloading $URL"
    curl --show-error --location $URL | tar -xf - -C $ABSOLUTE_PATH/AgentDVR
else
    echo "Found Agent in $ABSOLUTE_PATH/AgentDVR - delete it to reinstall"
fi

#this is needed for M1 compat
FILE=/usr/local/opt/openjpeg/lib/libopenjp2.7.dylib
if [ ! -f $FILE ]
then
	File=$ABSOLUTE_PATH/AgentDVR/homebrew/Cellar/openjpeg/2.4.0/lib/libopenjp2.7.dylib
	if [ -f $File ]
	then
        echo "I need to run as root to copy openjpeg library to /usr/local/opt/openjpeg/lib"
        sudo echo "Copying openjpeg to local lib"
        sudo mkdir -p /usr/local/opt/openjpeg/lib
		for file in $ABSOLUTE_PATH/AgentDVR/homebrew/Cellar/openjpeg/2.4.0/lib/*.dylib; do sudo cp "$file" "/usr/local/opt/openjpeg/lib";done
	else
		echo "Warning - could not find libopenjp2.7"
	fi
fi

FILE=/Library/LaunchDaemons/com.ispy.agent.dvr.plist
if [ ! -f $FILE ]
then
	echo -n "Install AgentDVR as system service (y/n)? "
	read answer
	if [ "$answer" != "${answer#[Yy]}" ] ;then 
		echo Yes
		read -p "Enter your username [$(whoami)]: " name
		name=${name:-$(whoami)}
		cd $ABSOLUTE_PATH/
		curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/com.ispy.agent.dvr.plist" -o "com.ispy.agent.dvr.plist"
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
		dotnet Agent.dll
	fi
else
	echo "Found service definition in /Library/LaunchDaemons/com.ispy.agent.dvr.plist"
	echo "To disable, run: sudo launchctl unload -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist"
	echo "Then delete the file /Library/LaunchDaemons/com.ispy.agent.dvr.plist"
fi


