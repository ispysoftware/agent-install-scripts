#!/bin/bash

# Install script for AgentDVR/ Linux
# To execute: save and `chmod +x ./uninstall-linux.sh` then `./uninstall-linux.sh`

sudo systemctl stop AgentDVR.service
sudo systemctl disable AgentDVR.service
sudo rm /etc/systemd/system/AgentDVR.service
sudo systemctl daemon-reload
sudo systemctl reset-failed
