#!/bin/sh

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./install.sh` then `./install.sh`

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If darwin (macOS)
  bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/osx_setup.sh")
  exit
fi

bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/linux_setup.sh")
