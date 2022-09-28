# Scripted installs for Agent DVR on OSX, Linux and Raspberry Pi
Setup scripts for Agent DVR on macOS/ Linux
For Windows download the installer from the website
For Docker see the download page below

https://www.ispyconnect.com/download.aspx

To install on **OSX** (Requires: OSX >= 10.14) or **Linux** (x64, arm and raspberry pi) open a terminal and call:

    bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/install.sh")

# Updating Agent

If you have a license or a subscription you can update Agent to the latest version by clicking on the server menu and "Update Agent".

To update Agent manually follow the following steps:

Backup your configuration (just in case!) - copy the xml files in Agent/Media/XML somewhere

Stop the Agent Service

    #Linux:
        sudo systemctl stop AgentDVR.service
    #OSX:
        sudo launchctl unload -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist

Download the latest version (will detect your platform)

    bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/download.sh")
    
Unzip that over the existing install location to update (it won't erase your config). When it is unzipped, change to the Agent directory and run

    chmod +x Agent
    
... and restart the service:

    #Linux: 
        sudo systemctl start AgentDVR.service
    #OSX:
        sudo launchctl load -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist

You may need to install curl first:

    sudo apt-get install curl

When Agent is installed you can access it on the local computer at http://localhost:8090


If Agent doesn't start or you want to run Agent manually (provides console output for debugging):

./Agent

**Known Issues:**

On Raspberry Pi please ensure you are using a recent OS - older versions of Raspbian do not support modern SSL certificates.
