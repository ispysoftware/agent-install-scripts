#!/bin/sh

# Homebrew Script for AgentDVR/ OSX
# To execute: save and `chmod +x ./agent_setup.sh` then `./agent_setup.sh`

ABSOLUTE_PATH="${PWD}"
echo "$ABSOLUTE_PATH"

mkdir AgentDVR
cd AgentDVR


echo "Downloading brew..."
cd ~/Downloads
mkdir homebrew
curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew

mv homebrew "$ABSOLUTE_PATH/AgentDVR/homebrew"

echo "Setting brew alias"

alias axbrew='arch -x86_64 $ABSOLUTE_PATH/AgentDVR/homebrew/bin/brew'

echo "Installing dotnet"

axbrew tap isen-ng/dotnet-sdk-versions
axbrew install --cask dotnet-sdk3-1-300


echo "Installing ffmpeg"

axbrew install ffmpeg@4

FILE=$ABSOLUTE_PATH/AgentDVR/Agent.dll
if [ ! -f $FILE ]
then
    URL=$((curl -s "https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=OSX") | tr -d '"')
    echo "Downloading $URL"
    curl --show-error --location $URL | tar -xf - -C $ABSOLUTE_PATH/AgentDVR
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

echo "Starting AgentDVR"

cd $ABSOLUTE_PATH/AgentDVR
dotnet Agent.dll
