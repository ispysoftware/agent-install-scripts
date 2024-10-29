#!/bin/bash

# Script for AgentDVR/ OSX
# To execute: save and `chmod +x ./osx_setup.sh` then `./osx_setup.sh`

ABSOLUTE_PATH="${PWD}"
echo "$ABSOLUTE_PATH"

mkdir -p AgentDVR
cd AgentDVR

# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Install supervisord if not installed
if ! command -v supervisord &> /dev/null; then
    echo "supervisord not found. Installing it using pip..."
    # Ensure pip3 is available
    if ! command -v pip3 &> /dev/null; then
        echo "pip3 not found. Installing it first..."
        /usr/bin/python3 -m ensurepip --upgrade
    fi
    # Install supervisor using pip3
    pip3 install --user supervisor
fi

# Define the full path for supervisord and supervisorctl
SUPERVISORD_BIN="$HOME/.local/bin/supervisord"
SUPERVISORCTL_BIN="$HOME/.local/bin/supervisorctl"

# Verify installation of supervisord
if [ ! -f "$SUPERVISORD_BIN" ]; then
    echo "Failed to install supervisord. Ensure that $HOME/.local/bin is in your PATH."
    exit 1
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
    SUPERVISOR_DIR="$HOME/.config/supervisor"
    SUPERVISOR_CONF="$SUPERVISOR_DIR/supervisord.conf"
    SUPERVISOR_PROGRAM_CONF="$SUPERVISOR_DIR/agentdvr.ini"
    AGENT_DIR="$ABSOLUTE_PATH/AgentDVR"
    AGENT_COMMAND="$AGENT_DIR/Agent"

    # Create supervisor config directory
    mkdir -p $SUPERVISOR_DIR

    # Create supervisord.conf if not exists
    if [ ! -f $SUPERVISOR_CONF ]; then
        cat <<EOL > $SUPERVISOR_CONF
[unix_http_server]
file=$HOME/.config/supervisor/supervisor.sock   ; path to the socket file

[supervisord]
logfile=$HOME/.config/supervisor/supervisord.log ; main log file
pidfile=$HOME/.config/supervisor/supervisord.pid ; pid file
childlogdir=$HOME/.config/supervisor/           ; child log directory

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix://$HOME/.config/supervisor/supervisor.sock

[include]
files = $HOME/.config/supervisor/*.ini
EOL
        echo "Created supervisord configuration."
    fi

    # Create agentdvr.ini for the service
    cat <<EOL > $SUPERVISOR_PROGRAM_CONF
[program:agentdvr]
command=$AGENT_COMMAND
directory=$AGENT_DIR
autostart=true
au
