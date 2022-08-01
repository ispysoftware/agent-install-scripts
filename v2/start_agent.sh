#!/bin/sh

# To execute: save and `chmod +x ./start_agent.sh` then `./start_agent.sh`

LD_LIBRARY_PATH="$ABSOLUTE_PATH/AgentDVR/ffmpeg-build/workspace/lib"
export LD_LIBRARY_PATH

./Agent
