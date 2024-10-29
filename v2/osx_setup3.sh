#!/bin/bash

# Homebrew Script for AgentDVR/ OSX
# To execute: save and `chmod +x ./osx_setup.sh` then `./osx_setup.sh`
shopt -s expand_aliases

arch=`uname -m`

ABSOLUTE_PATH="${PWD}"
echo "$ABSOLUTE_PATH"

mkdir -p AgentDVR
cd AgentDVR

FILE=/usr/local/bin/brew
if [[ ("$(arch)" == "arm64") ]]; then
	FILE=/opt/homebrew/bin/brew
fi
if [ -f $FILE ]; then
	echo "Using installed homebrew at $FILE"
	brewcmd="$FILE"
else
	echo "Installing Homebrew"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	if [[ ("$(arch)" == "arm64") ]]; then
		FILE=/opt/homebrew/bin/brew
	else
		FILE=/usr/local/bin/brew
	fi
	brewcmd="$FILE"
fi

# Install supervisor
echo "Installing supervisor"
"$brewcmd" install supervisor

# Download AgentDVR if not already present
FILE=$ABSOLUTE_PATH/AgentDVR/Agent
if [ -f $FILE ]; then
	echo "Found Agent in $ABSOLUTE_PATH/AgentDVR - delete it to reinstall"
else
	if [[ ("$(arch)" == "arm64") ]]; then
	 	URL=$(curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSXARM64&fromVersion=0" | tr -d '"')
	else
		URL=$(curl -s -L "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=OSX64&fromVersion=0" | tr -d '"')
	fi

	echo "Downloading $URL"
	curl --show-error --location $URL | tar -xf - -C $ABSOLUTE_PATH/AgentDVR
	chmod +x Agent
	find . -name "*.sh" -exec chmod +x {} \;
fi

echo -n "Setup AgentDVR as system service using supervisor (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ]; then 
	echo "Setting up AgentDVR as a service using supervisor"

	# Define variables
	CONFIG_FILE="/usr/local/etc/supervisord.ini"
	SUPERVISOR_DIR="/usr/local/etc/supervisor.d"
	AGENT_CONF="$SUPERVISOR_DIR/agentdvr.ini"
	AGENT_DIR="$ABSOLUTE_PATH/AgentDVR"
	AGENT_COMMAND="$AGENT_DIR/Agent"

	# Create supervisord.ini if it doesn't exist
	if [ ! -f $CONFIG_FILE ]; then
	    echo "Creating default supervisord configuration file at $CONFIG_FILE"
	    mkdir -p $(dirname $CONFIG_FILE)
	    cat <<EOL > $CONFIG_FILE
[unix_http_server]
file=/usr/local/var/run/supervisor.sock   ; path to your socket file

[supervisord]
logfile=/usr/local/var/log/supervisord.log ; supervisord log file
pidfile=/usr/local/var/run/supervisord.pid ; supervisord pidfile

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///usr/local/var/run/supervisor.sock ; use a unix:// URL  for a unix socket

[include]
files = $SUPERVISOR_DIR/*.ini
EOL
	fi

	# Create supervisor.d directory if it doesn't exist
	mkdir -p $SUPERVISOR_DIR

	# Create agentdvr.ini
	cat <<EOL > $AGENT_CONF
[program:agentdvr]
command=$AGENT_COMMAND
directory=$AGENT_DIR
autostart=true
autorestart=true
stderr_logfile=/usr/local/var/log/agentdvr.err.log
stdout_logfile=/usr/local/var/log/agentdvr.out.log
EOL

	# Start supervisor service
	echo "Starting supervisord service"
	"$brewcmd" services restart supervisor

	echo "Started AgentDVR service under supervisor"
	echo "Go to http://localhost:8090 to configure"
	exit
else
	echo "Starting AgentDVR"
	cd $ABSOLUTE_PATH/AgentDVR
	./Agent
fi

