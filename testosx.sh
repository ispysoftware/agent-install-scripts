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
