#!/bin/bash

# Uninstall script for AgentDVR/ Linux/ OSX
# To execute: save and `chmod +x ./agent-uninstall-service.sh` then `./agent-uninstall-service.sh`

if [[ ("$OSTYPE" == "darwin"*) ]]; then
  # Current installs run as a per-user LaunchAgent; older installs as a system LaunchDaemon.
  # Remove whichever exists (both, if somehow both are present).
  if [ -f ~/Library/LaunchAgents/com.ispy.agent.dvr.plist ]; then
    echo "Removing user agent"
    launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.ispy.agent.dvr.plist 2>/dev/null || launchctl unload ~/Library/LaunchAgents/com.ispy.agent.dvr.plist 2>/dev/null
    rm -f ~/Library/LaunchAgents/com.ispy.agent.dvr.plist
  fi
  if [ -f /Library/LaunchDaemons/com.ispy.agent.dvr.plist ]; then
    echo "Removing system daemon"
    sudo launchctl bootout system /Library/LaunchDaemons/com.ispy.agent.dvr.plist 2>/dev/null || sudo launchctl unload -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist 2>/dev/null
    sudo rm -f /Library/LaunchDaemons/com.ispy.agent.dvr.plist
  fi
else
  sudo systemctl stop AgentDVR.service
  sudo systemctl disable AgentDVR.service
  sudo rm /etc/systemd/system/AgentDVR.service
  sudo systemctl daemon-reload
  sudo systemctl reset-failed
fi

echo "stopped and removed service"
