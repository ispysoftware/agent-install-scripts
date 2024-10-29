#!/bin/bash

# Debug output
set -x

ABSOLUTE_PATH="${PWD}"
echo "Current directory: $ABSOLUTE_PATH"

mkdir -p AgentDVR
cd AgentDVR

# Define where supervisord is expected
SUPERVISORD_BIN="$HOME/Library/Python/3.9/bin/supervisord"
SUPERVISORCTL_BIN="$HOME/Library/Python/3.9/bin/supervisorctl"

# Install supervisord if not found
if [ ! -f "$SUPERVISORD_BIN" ]; then
    echo "supervisord not found. Installing it using pip..."
    if ! command -v pip3 &> /dev/null; then
        echo "pip3 not found. Installing it..."
        /usr/bin/python3 -m ensurepip --upgrade
    fi
    pip3 install --user supervisor
fi

# Verify installation of supervisord
if [ ! -f "$SUPERVISORD_BIN" ]; then
    echo "Failed to install supervisord."
    exit 1
fi

# Debug output: supervisord path
echo "Using supervisord at: $SUPERVISORD_BIN"

# Check if AgentDVR is already present
FILE="$ABSOLUTE_PATH/AgentDVR/Agent"
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
fi

echo -n "Setup AgentDVR as system service using supervisor (y/n)? "
read answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Setting up AgentDVR as a service using supervisor"

    SUPERVISOR_DIR="$HOME/.config/supervisor"
    SUPERVISOR_CONF="$SUPERVISOR_DIR/supervisord.conf"
    SUPERVISOR_PROGRAM_CONF="$SUPERVISOR_DIR/agentdvr.ini"

    mkdir -p $SUPERVISOR_DIR

    # Create supervisord.conf
    cat > "$SUPERVISOR_CONF" <<EOL
[unix_http_server]
file=$HOME/.config/supervisor/supervisor.sock

[supervisord]
logfile=$HOME/.config/supervisor/supervisord.log
pidfile=$HOME/.config/supervisor/supervisord.pid
childlogdir=$HOME/.config/supervisor/

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix://$HOME/.config/supervisor/supervisor.sock

[include]
files = $HOME/.config/supervisor/*.ini
EOL

    echo "Created supervisord configuration at $SUPERVISOR_CONF"

    # Create agentdvr.ini
    cat > "$SUPERVISOR_PROGRAM_CONF" <<EOL
[program:agentdvr]
command=$ABSOLUTE_PATH/AgentDVR/Agent
directory=$ABSOLUTE_PATH/AgentDVR
autostart=true
autorestart=true
user=$(whoami)
stderr_logfile=$HOME/.config/supervisor/agentdvr.err.log
stdout_logfile=$HOME/.config/supervisor/agentdvr.out.log
EOL

    echo "Created AgentDVR configuration for supervisor at $SUPERVISOR_PROGRAM_CONF"

    echo "Starting supervisord..."
    $SUPERVISORD_BIN -c $SUPERVISOR_CONF

    echo "Reloading supervisor configuration..."
    $SUPERVISORCTL_BIN -c $SUPERVISOR_CONF reread
    $SUPERVISORCTL_BIN -c $SUPERVISOR_CONF update

    echo "AgentDVR service started under supervisor"
    echo "Go to http://localhost:8090 to configure"
else
    echo "Starting AgentDVR directly..."
    cd $ABSOLUTE_PATH/AgentDVR
    ./Agent
fi

# Debug output
set +x
