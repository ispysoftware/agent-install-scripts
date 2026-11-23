#!/bin/bash

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./install.sh` then `./install.sh`

# Install script for AgentDVR/ Linux
# Usage: ./install.sh [-v version] [-y]
#   -v version  install a specific version, e.g. -v 8290 for 8.2.9.0
#   -y          unattended: answer yes to every question

# Build an array of extra arguments to pass on.
ARGS=()
while getopts "v:y" opt; do
  case "$opt" in
    v) ARGS+=("-v" "$OPTARG") ;;
    y) ARGS+=("-y") ;;
    *) ;;
  esac
done

# Set a default value for USE_BETA if it's not already set.
USE_BETA=${USE_BETA:-false}

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If darwin (macOS)
  echo "Use the MacOS installer on the download page - https://www.ispyconnect.com/download";
  exit
fi

curl -H 'Cache-Control: no-cache, no-store' -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/linux_setup2.sh" | sudo USE_BETA=$USE_BETA bash -s -- "${ARGS[@]}"
