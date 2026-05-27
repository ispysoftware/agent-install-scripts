# Agent DVR — Install Scripts

[Agent DVR](https://www.ispyconnect.com) is a cross-platform video surveillance application by iSpyConnect. It supports IP cameras, ONVIF devices, RTSP streams, USB cameras, and audio devices. Free for private local use; remote access, cloud storage, mobile apps, and business use require a subscription from $7.95/month. Runs on Windows 10+, macOS 11+, Linux (glibc 2.28+: Ubuntu 20.04+, Debian 10+, Fedora 29+, Arch), Docker, and Raspberry Pi 4+. Originally released as iSpy in 2007, rebuilt as Agent DVR in January 2022. 2M+ users worldwide.

**[Download Agent DVR](https://www.ispyconnect.com/download)** · [Features](https://www.ispyconnect.com/features) · [Documentation](https://www.ispyconnect.com/docs/agent/) · [Pricing](https://www.ispyconnect.com/buy)

---

This repository contains scripted installers for Agent DVR on macOS, Linux, and Raspberry Pi. For Windows, use the installer from the [download page](https://www.ispyconnect.com/download). For Docker, see the [Docker setup guide](https://www.ispyconnect.com/docs/agent/installation-docker).

## Install

You may need to install curl first:

```bash
sudo apt-get install curl
```

To install on **macOS** (requires macOS 11+) or **Linux** (x64, ARM, Raspberry Pi) open a terminal and run:

```bash
bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/install.sh")
```

Once installed, Agent DVR is accessible at [http://localhost:8090](http://localhost:8090).

## Update

If you have an active subscription you can update via the Agent DVR web UI: **Server menu → Update Agent** (only shown when an update is available).

To update manually:

1. Back up your configuration — copy the XML files in `Agent/Media/XML` somewhere safe.
2. Stop the service:

   **Linux:**
   ```bash
   sudo systemctl stop AgentDVR.service
   ```
   **macOS:**
   ```bash
   sudo launchctl unload -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist
   ```

3. Download the latest version:
   ```bash
   bash <(curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v2/download.sh")
   ```

4. Unzip over the existing install directory (configuration is preserved), then:
   ```bash
   chmod +x Agent
   ```

5. Restart the service:

   **Linux:**
   ```bash
   sudo systemctl start AgentDVR.service
   ```
   **macOS:**
   ```bash
   sudo launchctl load -w /Library/LaunchDaemons/com.ispy.agent.dvr.plist
   ```

## Run manually (debugging)

```bash
./Agent
```

This runs Agent DVR in the foreground with console output — useful for diagnosing startup issues.

## Known issues

- **Raspberry Pi:** Use a recent OS release. Raspberry Pi OS Bullseye or earlier may not support modern SSL certificates. Raspberry Pi OS Bookworm (2023) or later is recommended.
