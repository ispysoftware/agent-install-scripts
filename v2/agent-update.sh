#!/bin/bash

isOSX=0
if [[ ("$OSTYPE" == "darwin"*) ]]; then
	isOSX=1
fi

svc=0

if [ $isOSX -eq 1 ]; then
	launchctl list "com.ispy.agent.dvr"
	if [ $? -eq 0 ]; then
		echo "Service found"
		svc=0
	else
		echo "Service not found"
		svc=1
	fi
else
	if [ $(systemctl list-units --all -t service --full --no-legend "AgentDVR.service" | sed 's/^\s*//g' | cut -f1 -d' ') == AgentDVR.service ]; then
		svc=0
		echo "Service found"
	else
		svc=1
		echo "Service not found"
	fi
fi

if [ "$1" == "-update" ]; then
	if [ -f AgentDVR.zip ]; then
		echo "Installing update"
		unzip -o AgentDVR.zip
		rm -f AgentDVR.zip

		chmod +x Agent
		chmod +x agent-update.sh
	fi

	
fi

if [ "$1" == "-plugins" ]; then 
	echo "Installing $2"
	cd Plugins
	cd "$2"
	if [ -f plugin.zip ]; then
		unzip -o plugin.zip
		echo "Unzipped";
		rm -f plugin.zip
		echo "Removed archive";
		cd ..
	fi
	cd ..
fi

if [ $svc -eq 1 ]; then
	echo "Restarting Agent"
	./Agent
else
	echo "Restart service"
	if [ $isOSX -eq 1 ]; then
		sudo launchctl load -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist
	else
		sudo systemctl start AgentDVR
	fi
	
fi
