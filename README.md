# Scripted installs for Agent DVR on macOS, Linux and Raspberry Pi
Setup scripts for Agent DVR on macOS/ Linux
For Windows download the installer from the website
For Docker see the download page below

https://www.ispyconnect.com/download.aspx

To install on **macOS** (Requires: macOS >= 10.14) or **Linux** (x64, arm and raspberry pi) open a terminal and call:

    bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/install.sh")

To download the latest Agent DVR zip file for your platform:

    bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/download.sh")
    
Unzip that over the existing install location to update Agent

You may need to install curl first:

    sudo apt-get install curl

When Agent is installed you can access it on the local computer at http://localhost:8090


If Agent doesn't start or you want to run Agent manually (provides console output for debugging):

./Agent

**Known Issues:**

On Raspberry Pi please ensure you are using a recent OS - older versions of Raspbian do not support modern SSL certificates.
