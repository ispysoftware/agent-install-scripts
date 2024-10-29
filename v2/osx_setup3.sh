#!/bin/bash

# Script for AgentDVR/ OSX
# To execute: save and `chmod +x ./osx_setup.sh` then `./osx_setup.sh`

ABSOLUTE_PATH="${PWD}"
echo "$ABSOLUTE_PATH"

mkdir -p AgentDVR
cd AgentDVR

# Check if supervisord is installed
if ! command -v supervisord &> /dev/null; then
    echo "supervisord not found. Installing it using pip..."
    # Install pip if not present
    if ! command -v pip3 &> /dev/null; then
        echo "pip3 not found. Installing it first..."
        /usr/bin/python3 -m ensurepip --upgrade
    fi
    pip3 install --user supervisor
    # Add local bin to PATH
    export PATH=$HOME/.local/bin:$PATH
else
    echo "supervisord is already installed."
fi

# Download AgentDVR if not already present
FILE=$ABSOLUTE_PATH/AgentDVR/Agent
if [ -f $FILE ]; then
    echo "Found Agent in $ABSOLUTE_PATH/AgentDVR - delete it to reinstall"
else
    if [[ "$(uname -m)" == "arm64" ]]; then
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
    SUPERVISOR_DIR="$HOME/.local/etc/supervisor"
    AGENT_CONF="$SUPERVISOR_DIR/agentdvr.ini"
    AGENT_DIR="$ABSOLUTE_PATH/AgentDVR"
    AGENT_COMMAND="$AGENT_DIR/Agent"

    # Get the current user
    CURRENT_USER=$(whoami)

    # Create supervisor directory if it doesn't exist
    mkdir -p $SUPERVISOR_DIR

    # Create agentdvr.ini if it doesn't exist
    if [ ! -f $AGENT_CONF ]; then
        cat <<EOL > $AGENT_CONF
[program:agentdvr]
command=$AGENT_COMMAND
directory=$AGENT_DIR
user=$CURRENT_USER
autostart=true
autorestart=true
stderr_logfile=$HOME/.local/var/log/agentdvr.err.log
stdout_logfile=$HOME/.local/var/log/agentdvr.out.log
EOL
        echo "Created AgentDVR configuration in supervisor."
    else
        echo "AgentDVR configuration already exists in supervisor."
    fi

    # Start supervisord if not running
    if ! pgrep -x "supervisord" > /dev/null; then
        echo "Starting supervisord..."
        supervisord -c $HOME/.local/etc/supervisord.conf
    fi

    # Reload supervisor configuration
    supervisorctl -c $HOME/.local/etc/supervisord.conf reread
    supervisorctl -c $HOME/.local/etc/supervisord.conf update

    echo "Started AgentDVR service under supervisor"
    echo "Go to http://localhost:8090 to configure"
    exit
else
    echo "Starting AgentDVR"
    cd $ABSOLUTE_PATH/AgentDVR
    ./Agent
fi
