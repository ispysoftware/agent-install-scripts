# agent-install-scripts
Setup scripts for Agent DVR on macos/ linux
For Windows download the installer from the website
For Docker see the download page below

https://www.ispyconnect.com/download.aspx

To install on mac osx (Requires: macOS >= 10.14) or linux (x64, arm and raspberry pi) open a terminal and call

    bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/install.sh")

You may need to install curl first:

    sudo apt-get install curl

When Agent is installed you can access it on the local computer at http://localhost:8090


If Agent doesn't start or you want to run Agent manually (provides console output for debugging):
On macOS in the AgentDVR folder run:
    dotnet Agent.dll
On Linux:
    ./start_agent.sh
   
