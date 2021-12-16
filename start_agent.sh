#!/bin/sh

# To execute: save and `chmod +x ./start_agent.sh` then `./start_agent.sh`

ABSOLUTE_PATH="${PWD}"
export PATH="$PATH:$ABSOLUTE_PATH/.dotnet:$ABSOLUTE_PATH/ffmpeg-build/workspace/lib"

dotnet Agent.dll

