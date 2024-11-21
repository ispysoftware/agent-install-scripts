#!/bin/bash

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./install.sh` then `./install.sh`

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If darwin (macOS)
  curl -H 'Cache-Control: no-cache, no-store' -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/macos_setup.sh" | bash
  exit
fi

curl -H 'Cache-Control: no-cache, no-store' -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/linux_setup.sh" | sudo USE_BETA=$USE_BETA bash
