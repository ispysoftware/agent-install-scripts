#!/bin/sh

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./install.sh` then `./install.sh`

echo "Warning, this install script is capped at v4.1.1.0 due to the project upgraded to .net 6. See the download page at https://www.ispyconnect.com/download.aspx for instructions"

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # If darwin (macOS)
  bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/macos_setup.sh")
  exit
fi

bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/linux_setup.sh")
