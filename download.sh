#!/bin/sh

# Download script for AgentDVR/ Linux
# This will download the latest Agent DVR zip file for your platform. Unzip the files over the existing installation to update. 

machine_has() {
    eval $invocation

    command -v "$1" > /dev/null 2>&1
    return $?
}

echo "finding installer for $(arch)"
purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=Linux"


if [[ ("$OSTYPE" == "darwin"*) ]]; then
  purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=OSX"
else
  case $(arch) in
    'aarch64' | 'arm64')
      purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=true&platform=ARM"
    ;;
    'arm' | 'armv6l' | 'armv7l')
      purl="https://www.ispyconnect.com/api/Agent/DownloadLocation2?productID=24&is64=false&platform=ARM32"
    ;;
  esac
fi

if [ ! machine_has "unzip" ]; then
  echo "installing unzip"
  if machine_has "apt-get"; then
    sudo apt-get install unzip
  else
    sudo yum install unzip
  fi
fi

if [ -f AgentDVR.zip ]; then
  echo "Removing old AgentDVR.zip"
  rm -y AgentDVR.zip
fi
AGENTURL=$(curl -s --fail "$purl" | tr -d '"')
echo "Downloading $AGENTURL"
curl --show-error --location "$AGENTURL" -o "AgentDVR.zip"
echo "Saved to AgentDVR.zip"
