#!/bin/sh

# To execute: save and `chmod +x ./start_agent.sh` then `./start_agent.sh`

ABSOLUTE_PATH="${PWD}"
export PATH=$PATH:$ABSOLUTE_PATH/AgentDVR/.dotnet

LD_LIBRARY_PATH="$ABSOLUTE_PATH/AgentDVR/ffmpeg-build/workspace/lib"
export LD_LIBRARY_PATH

dotnet AgentDVR/Agent.dll

