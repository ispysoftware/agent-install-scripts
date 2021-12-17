#!/bin/sh

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./agent_setup.sh` then `./agent_setup.sh`

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If darwin (macOS)
  curl -L "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/macos_setup.sh" | bash
  exit
fi

curl -L "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/linux_setup.sh" | bash
