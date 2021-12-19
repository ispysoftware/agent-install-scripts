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

AGENTURL=$(curl -s --fail "$purl" | tr -d '"')
Filename=${AGENTURL##*/}

if [ -f $Filename ]; then
  echo "Latest file already downloaded ($Filename)"
  exit
fi

echo "Downloading $AGENTURL"

curl --show-error --location "$AGENTURL" -o "$Filename"
echo "Saved to $Filename"
