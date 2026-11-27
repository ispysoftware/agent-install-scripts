#!/bin/bash

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./install.sh` then `./install.sh`

# Install script for AgentDVR/ Linux
# Usage: ./install.sh [-v version] [-y] [-z zip]
#   -v version  install a specific version, e.g. -v 8290 for 8.2.9.0
#   -y          unattended: answer yes to every question
#   -z zip      install from a local Agent_<platform>_<version>.zip instead of downloading
#               (testing a build before it's published; its signature is not checked)

# Build an array of extra arguments to pass on.
ARGS=()
while getopts "v:yz:" opt; do
  case "$opt" in
    v) ARGS+=("-v" "$OPTARG") ;;
    y) ARGS+=("-y") ;;
    z) ARGS+=("-z" "$(readlink -f -- "$OPTARG" 2>/dev/null || echo "$OPTARG")") ;;
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

SETUP_URL="https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/linux_setup2.sh"
SETUP_FILE=$(mktemp /tmp/agentdvr_setup.XXXXXX) || { echo "Could not create a temporary file."; exit 1; }
trap 'rm -f "$SETUP_FILE"' EXIT

if ! curl -H 'Cache-Control: no-cache, no-store' -sfL "$SETUP_URL" -o "$SETUP_FILE"; then
  echo "Failed to download the setup script from $SETUP_URL"
  exit 1
fi

# Run the setup from a file, never piped into sudo: under sudo-rs (Ubuntu 25.10+) a
# piped stdin gets the script's output stopped after the first prompt, so the user
# never sees the download progress or the final "open a browser at" message.
# Skip sudo when already root (the documented command runs this script with sudo).
# stdin is /dev/null, as non-interactive as the old pipe, so no apt/dpkg step can sit
# waiting on the keyboard (its output goes to the log); prompts read /dev/tty directly.
#
# Service account: when already root, SUDO_USER is cleared so the setup runs Agent as
# root. That is what installs from the download page (`sudo bash install_agent.sh`) have
# always done - the old nested sudo set SUDO_USER=root - and changing it would change
# device access and file ownership for new installs. Run without sudo, the sudo below
# sets SUDO_USER to the caller, so Agent runs as that user, as before.
if [ "$EUID" -eq 0 ]; then
  env -u SUDO_USER USE_BETA="$USE_BETA" bash "$SETUP_FILE" "${ARGS[@]}" </dev/null
else
  sudo env USE_BETA="$USE_BETA" bash -c 'exec bash "$@" </dev/null' _ "$SETUP_FILE" "${ARGS[@]}"
fi
