#!/bin/bash

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./uninstall.sh` then `./uninstall.sh`

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  sudo launchctl unload -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist
  sudo rm -f /Library/LaunchDaemons/com.ispy.agent.dvr.plist
else
  sudo systemctl stop AgentDVR.service
  sudo systemctl disable AgentDVR.service
  sudo rm /etc/systemd/system/AgentDVR.service
  sudo systemctl daemon-reload
  sudo systemctl reset-failed
fi
