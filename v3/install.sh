#!/bin/bash

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./install.sh` then `./install.sh`

# Install script for AgentDVR/ Linux
# Usage: ./install.sh [-v version]

# Build an array of extra arguments to pass on.
ARGS=()
while getopts "v:" opt; do
  case "$opt" in
    v) ARGS+=("-v" "$OPTARG") ;;
    *) ;;
  esac
done

# Set a default value for USE_BETA if it's not already set.
USE_BETA=${USE_BETA:-false}

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If darwin (macOS)
  curl -H 'Cache-Control: no-cache, no-store' -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/macos_setup.sh" | USE_BETA=$USE_BETA bash -s -- "${ARGS[@]}"
  exit
fi

curl -H 'Cache-Control: no-cache, no-store' -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/linux_setup.sh" | sudo USE_BETA=$USE_BETA bash -s -- "${ARGS[@]}"
