#!/bin/bash

# Install script for AgentDVR on Linux
# To execute: save and `chmod +x ./linux_setup2.sh` then `./linux_setup2.sh`

# Define constants
LOGFILE="/var/log/agentdvr_setup.log"  # Log file path
INSTALL_PATH="/opt/AgentDVR"

USE_VERSION=0
AUTO_YES=false
INTERACTIVE=true
USE_BETA=${USE_BETA:-false}   # Added to prevent undefined variable evaluation

# Safely identify the real user running the script, falling back to root if run directly
ACTUAL_USER="${SUDO_USER:-$(whoami)}"

# Array to collect any arguments to pass on to child scripts.
ARGS=()

# Parse command-line options.
while getopts "v:y" opt; do
    case "$opt" in
    v)
        USE_VERSION="$OPTARG"
        ARGS+=("-v" "$OPTARG")
        ;;
    y)
        AUTO_YES=true
        INTERACTIVE=false
        ;;
    *)
        ;;
    esac
done

# Ensure the log file exists and is writable
touch "$LOGFILE" || { echo "Cannot write to $LOGFILE. Please check permissions."; exit 1; }
chmod 644 "$LOGFILE"

# Try to redirect output to both terminal and logfile; fall back to file-only if it fails
if ! exec > >(tee -a "$LOGFILE") 2> >(tee -a "$LOGFILE" >&2); then
    echo "Warning: Process substitution failed. Logging only to $LOGFILE."
    exec > "$LOGFILE" 2>&1
fi

if [ "$USE_VERSION" -gt 0 ]; then
    echo "Installing v$USE_VERSION"
fi

# Function to print info messages with timestamp
info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO]: $1"
}

# Function to print error messages with timestamp
error_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR]: $1" >&2
}

# Function to check if a command exists
machine_has() {
    command -v "$1" > /dev/null 2>&1
    return $?
}

# Function to handle critical errors
critical_error() {
    error_log "$1"
    echo "check /var/log/agentdvr_setup.log"
    exit 1
}

# GitHub mirror for AgentDVR builds. The primary CDN (files.ispyconnect.com)
# sits behind Cloudflare, which some ISPs throttle (e.g. Russia, ~16KB/connection).
# The release uploader publishes every build to a release tagged v{version}
# with the same filenames as the CDN.
GITHUB_RELEASES="https://github.com/ispysoftware/agent-install-scripts/releases/download"

# Build the GitHub mirror URL for a CDN download URL.
# Agent_Linux64_6_5_3_0.zip → {GITHUB_RELEASES}/v6.5.3.0/Agent_Linux64_6_5_3_0.zip
# Returns 1 if the filename doesn't match the expected convention.
github_mirror_url() {
    local url="$1"
    local filename="${url##*/}"
    local version
    version=$(echo "$filename" | sed -nE 's#^Agent_[A-Za-z0-9]+_([0-9]+)_([0-9]+)_([0-9]+)_([0-9]+)\.zip$#\1.\2.\3.\4#p')
    if [ -z "$version" ]; then
        return 1
    fi
    echo "$GITHUB_RELEASES/v$version/$filename"
}

# Function to download AgentDVR with retry logic and GitHub mirror fallback
download_agentdvr() {
    local url="$1"
    local output="$2"
    local max_rounds=3

    local urls=("$url")
    local mirror
    if mirror=$(github_mirror_url "$url"); then
        urls+=("$mirror")
    fi

    local total_attempts=$((max_rounds * ${#urls[@]}))
    local n=0
    local round=1

    info "Starting download of AgentDVR..."
    while [ $round -le $max_rounds ]; do
        for u in "${urls[@]}"; do
            n=$((n + 1))

            # Abort if the average rate stays below 16KB/s for 10s — catches
            # ISP-level throttling that trickles instead of failing outright.
            # Skipped on the very last attempt so a genuinely slow connection
            # can still finish (slow success beats guaranteed failure).
            local speed_opts=(--speed-limit 16384 --speed-time 10)
            if [ $n -eq $total_attempts ]; then
                speed_opts=()
            fi

            info "Attempt $n of $total_attempts: Downloading from $u"

            # --fail prevents an HTML error page being saved as the zip.
            # Print progress bar to terminal, log output only for errors
            if curl --progress-bar --location --fail --connect-timeout 30 "${speed_opts[@]}" "$u" -o "$output" 2> >(tee -a "$LOGFILE" >&2) > /dev/tty; then
                info "AgentDVR downloaded successfully on attempt $n."
                return 0
            else
                error_log "Download attempt $n failed."
                sleep 2  # Wait before retrying
            fi
        done
        round=$((round + 1))
    done
    critical_error "Failed to download AgentDVR after $total_attempts attempts."
}

# Public key that signs AgentDVR update/install zips. MUST match
# SharedLogic SignatureVerifier.TrustedPublicKeysSpkiB64[0] (the update keyring).
AGENT_UPDATE_PUBKEY="-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEfDw9JHWE5hGBO35KjoaYXQCqog447U0a5jAmk9OJcIIZwP5RZAeT3hS2LmNgbK3JfReAxq2vdTwfJfkilXIqSg==
-----END PUBLIC KEY-----"

# When true, abort if the zip's signature is missing or can't be checked (openssl absent).
# Keep true once every published zip has its .sig; set REQUIRE_SIGNATURE=false (env override)
# only during rollout if older, unsigned builds must still install. A present-but-INVALID
# signature always aborts regardless of this flag.
REQUIRE_SIGNATURE="${REQUIRE_SIGNATURE:-true}"

# First Agent build that publishes a .sig, as the concatenated version the script already
# parses (e.g. 7.5.9.0 -> 7590). Anything older has no signature to check, so verification
# is skipped for those versions; 7590+ must verify.
SIG_MIN_VERSION=7590

# Verify the downloaded zip against its detached ECDSA signature — the SAME .sig the agent's
# auto-updater checks. The .sig is raw IEEE-P1363 r||s (64 bytes for P-256); openssl wants a
# DER signature, so we rebuild SEQUENCE{INTEGER r, INTEGER s} with its ASN.1 generator (which
# encodes the INTEGERs correctly), then verify. Returns: 0 = verified, 1 = signature present
# but INVALID (tampered/corrupt), 2 = could not verify (openssl missing, or no .sig published).
verify_agentdvr_zip() {
    local zip="$1" zip_url="$2"
    command -v openssl >/dev/null 2>&1 || return 3

    local tmp; tmp=$(mktemp -d) || return 3
    printf '%s\n' "$AGENT_UPDATE_PUBKEY" > "$tmp/update.pub"

    # Detached signature: CDN first, then the GitHub mirror (same sources as the zip).
    local sig="$tmp/sig.bin" mirror
    if ! curl -s --fail --location --connect-timeout 30 "${zip_url}.sig" -o "$sig"; then
        if mirror=$(github_mirror_url "$zip_url"); then
            curl -s --fail --location --connect-timeout 30 "${mirror}.sig" -o "$sig" || { rm -rf "$tmp"; return 2; }
        else
            rm -rf "$tmp"; return 2
        fi
    fi

    [ "$(wc -c < "$sig")" -eq 64 ] || { rm -rf "$tmp"; return 1; }
    local rhex shex
    rhex=$(dd if="$sig" bs=1 count=32 2>/dev/null | od -An -v -tx1 | tr -d ' \n')
    shex=$(dd if="$sig" bs=1 skip=32 count=32 2>/dev/null | od -An -v -tx1 | tr -d ' \n')
    printf 'asn1=SEQUENCE:seq\n[seq]\nf1=INTEGER:0x%s\nf2=INTEGER:0x%s\n' "$rhex" "$shex" > "$tmp/sig.asn1"
    openssl asn1parse -genconf "$tmp/sig.asn1" -out "$tmp/sig.der" >/dev/null 2>&1 || { rm -rf "$tmp"; return 1; }

    if openssl dgst -sha256 -verify "$tmp/update.pub" -signature "$tmp/sig.der" "$zip" >/dev/null 2>&1; then
        rm -rf "$tmp"; return 0
    fi
    rm -rf "$tmp"; return 1
}

find_port() {
    # Define the list of ports to check
    ports=(8090 8080 8100 8010 8123 8181 8222 8300 8400 8500 8600 8700 8800 8888 8899 8900 8989 9000 9080 9090 9100 9200 9300 9400 9500 9600 9700 9800 9900)

    # Function to check if a port is in use
    is_port_in_use() {
        local port=$1
        if command -v ss > /dev/null 2>&1; then
            ss -tuln | grep -E "LISTEN" | grep -qE "[: ]$port([^0-9]|$)"
        elif command -v netstat > /dev/null 2>&1; then
            netstat -tuln | grep -E "LISTEN" | grep -qE "[: ]$port([^0-9]|$)"
        else
            return 1 # Fallback: Assume port is free if we lack the tools to check
        fi
    }

    # Iterate over the list and find the first available port
    for port in "${ports[@]}"; do
        if ! is_port_in_use "$port"; then
            echo "$port"
            return 0
        fi
    done

   return 1
}

# Function to create desktop shortcuts
create_system_shortcut() {
    local install_path="$1"
    local username="$2"
    local port="$3"

    info "Creating system-wide application launcher..."
    
    # Dynamically find the user's home directory
    local user_home
    user_home=$(eval echo "~$username")
    
    # Create protected launcher script in user space
    local user_launcher_dir="$user_home/.local/bin"
    local user_launcher="$user_launcher_dir/agentdvr-launcher.sh"
    
    mkdir -p "$user_launcher_dir"
    
    if [ -f "$install_path/open_browser.sh" ]; then
        cp "$install_path/open_browser.sh" "$user_launcher"
        chown "$username:$username" "$user_launcher"
        chmod +x "$user_launcher"
        info "Created protected launcher at $user_launcher"
    else
        error_log "open_browser.sh not found at $install_path - desktop shortcut may not work"
        user_launcher="xdg-open http://localhost:$port"
    fi
    
    # Define path for system application file
    local desktop_browser_file="/usr/share/applications/agentdvr.desktop"
    
    # Create the browser desktop file
    sudo tee "$desktop_browser_file" > /dev/null << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Agent DVR
Comment=Open Agent DVR web interface
Exec=$user_launcher
Icon=$install_path/icon.png
Terminal=false
Categories=AudioVideo;Video;Security;
Keywords=surveillance;camera;security;dvr;
StartupNotify=true
EOF
    
    # Set permissions for system desktop file
    sudo chmod 644 "$desktop_browser_file"
    
    # Update desktop database
    if command -v update-desktop-database >/dev/null 2>&1; then
        sudo update-desktop-database /usr/share/applications/ 2>/dev/null || true
    fi
    
    info "Application launcher created successfully in the applications menu."
}

# Start of the script
info "===== AgentDVR Linux Setup Script Started ====="

# Find available port

# Source the release information
release_file=$(ls /etc/*-release 2>/dev/null | head -n 1)

if [ -n "$release_file" ]; then
    . "$release_file"
else
    critical_error "Failed to source /etc/*-release. No suitable release file found."
fi

# Determine system architecture
arch=$(uname -m)
info "System architecture detected: $arch"

# Check if the script is running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    error_log "This script is intended for Linux. Please use macos_setup.sh for macOS."
    exit 1
fi

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    error_log "This script must be run as root. Please use sudo or switch to the root user."
    exit 1
fi
info "Script is running with root privileges."

info "Setting UDP Buffer size defaults"
sysctl -w net.core.rmem_max=16777216 || true
sysctl -w net.core.rmem_default=8388608 || true

# Stop AgentDVR service if it's running
systemctl stop AgentDVR.service >> "$LOGFILE" 2>&1 || info "AgentDVR.service was not running."

# Create installation directory
mkdir -p "$INSTALL_PATH" || critical_error "Failed to create installation directory at $INSTALL_PATH."
info "Installation directory set to $INSTALL_PATH."

cd "$INSTALL_PATH" || critical_error "Failed to navigate to $INSTALL_PATH."

# Update package lists and install dependencies based on the package manager
if machine_has "apt-get"; then
    info "Detected apt-get package manager. Updating and installing dependencies..."
    apt-get update >> "$LOGFILE" 2>&1 || critical_error "apt-get update failed."
    apt-get install --no-install-recommends -y \
        unzip \
        xz-utils \
        apt-transport-https \
        alsa-utils \
        libxext-dev \
        fontconfig \
        libva-drm2 >> "$LOGFILE" 2>&1 || critical_error "apt-get install failed."
    info "Dependencies installed successfully using apt-get."

    # VAAPI GPU drivers (best-effort, non-fatal). FFmpeg ships its own libva;
    # the GPU-specific driver must come from the distro.
    info "Installing VAAPI GPU drivers..."
    apt-get install --no-install-recommends -y mesa-va-drivers >> "$LOGFILE" 2>&1 || info "mesa-va-drivers unavailable - AMD VAAPI acceleration disabled."
    apt-get install --no-install-recommends -y intel-media-va-driver-non-free >> "$LOGFILE" 2>&1 || \
        apt-get install --no-install-recommends -y intel-media-va-driver >> "$LOGFILE" 2>&1 || info "Intel media driver unavailable - Intel QuickSync disabled."
    apt-get install --no-install-recommends -y i965-va-driver >> "$LOGFILE" 2>&1 || true

elif machine_has "dnf" || machine_has "yum"; then
    info "Detected yum/dnf package manager. Updating and installing dependencies..."
    if machine_has "dnf"; then
        dnf update -y >> "$LOGFILE" 2>&1 || critical_error "dnf update failed."
        dnf install -y \
            unzip \
            xz \
            alsa-utils \
            libXext-devel \
            fontconfig \
            libva >> "$LOGFILE" 2>&1 || critical_error "dnf install failed."
        info "Installing VAAPI GPU drivers..."
        dnf install -y mesa-va-drivers intel-media-driver >> "$LOGFILE" 2>&1 || info "VAAPI drivers unavailable - on Fedora, H.264/HEVC VAAPI requires RPM Fusion (mesa-va-drivers-freeworld)."
        info "Installing optional math libraries for minimal systems..."
        dnf install -y lapack blas atlas >> "$LOGFILE" 2>&1 || info "Math libraries installation failed - may not be needed on this system."
    else
        yum update -y >> "$LOGFILE" 2>&1 || critical_error "yum update failed."
        yum install -y \
            unzip \
            xz \
            alsa-utils \
            libXext-devel \
            fontconfig \
            libva >> "$LOGFILE" 2>&1 || critical_error "yum install failed."
        info "Installing VAAPI GPU drivers..."
        yum install -y mesa-va-drivers intel-media-driver >> "$LOGFILE" 2>&1 || info "VAAPI drivers unavailable."
        info "Installing optional math libraries for minimal systems..."
        yum install -y lapack blas atlas >> "$LOGFILE" 2>&1 || info "Math libraries installation failed - may not be needed on this system."
    fi
    info "Dependencies installed successfully using yum/dnf."
elif machine_has "pacman"; then
    info "Detected pacman package manager. Updating and installing dependencies..."
    pacman -Syu --noconfirm >> "$LOGFILE" 2>&1 || critical_error "pacman update failed."
    pacman -S --noconfirm \
        unzip \
        xz \
        alsa-utils \
        libxext \
        fontconfig \
        libva >> "$LOGFILE" 2>&1 || critical_error "pacman install failed."
    info "Installing VAAPI GPU drivers..."
    pacman -S --noconfirm libva-mesa-driver intel-media-driver >> "$LOGFILE" 2>&1 || info "VAAPI drivers unavailable."
    info "Dependencies installed successfully using pacman."
    info "Installing optional math libraries for minimal systems..."
    pacman -S --noconfirm lapack blas >> "$LOGFILE" 2>&1 || info "Math libraries installation failed - may not be needed on this system."
elif machine_has "apk"; then
    info "Detected apk package manager. Updating and installing dependencies..."
    apk update >> "$LOGFILE" 2>&1 || critical_error "apk update failed."
    apk add --no-cache \
        unzip \
        xz \
        alsa-utils \
        libxext-dev \
        fontconfig \
        libva >> "$LOGFILE" 2>&1 || critical_error "apk install failed."
    info "Installing VAAPI GPU drivers..."
    apk add --no-cache mesa-va-gallium intel-media-driver >> "$LOGFILE" 2>&1 || info "VAAPI drivers unavailable."
    info "Dependencies installed successfully using apk."
    info "Installing optional math libraries for minimal systems..."
    apk add --no-cache lapack openblas >> "$LOGFILE" 2>&1 || info "Math libraries installation failed - may not be needed on this system."
else
    critical_error "Unsupported package manager. Please install dependencies manually."
fi

# openssl is needed to verify the downloaded zip's signature (below). Best-effort: if it
# can't be installed, verification is skipped rather than failing the install.
if ! machine_has openssl; then
    info "Installing openssl (needed to verify the download signature)..."
    if   machine_has apt-get; then apt-get install --no-install-recommends -y openssl >> "$LOGFILE" 2>&1 || true
    elif machine_has dnf;     then dnf install -y openssl >> "$LOGFILE" 2>&1 || true
    elif machine_has yum;     then yum install -y openssl >> "$LOGFILE" 2>&1 || true
    elif machine_has pacman;  then pacman -S --noconfirm openssl >> "$LOGFILE" 2>&1 || true
    elif machine_has apk;     then apk add --no-cache openssl >> "$LOGFILE" 2>&1 || true
    fi
    machine_has openssl || info "openssl still unavailable - zip signature verification will be skipped."
fi


# Check for existing AgentDVR installation
AGENT_FILE="$INSTALL_PATH/Agent"
if [ -f "$AGENT_FILE" ]; then
    if [ "$AUTO_YES" = true ]; then
        REINSTALL="y"
        info "Unattended mode: Auto-updating existing AgentDVR installation."
    else
        printf "\nFound Agent in %s. Would you like to update? (y/n): " "$INSTALL_PATH" >/dev/tty
        read -r REINSTALL </dev/tty || REINSTALL="n"
    fi
    
    REINSTALL=${REINSTALL,,}  # Convert to lowercase
    if [[ "$REINSTALL" != "y" ]]; then
        info "Aborting installation as per user request."
        exit 0
    else
        info "Proceeding with reinstallation of AgentDVR."
    fi
fi

# Determine the download URL based on architecture
info "Determining download URL for architecture: $arch"

PLATFORM="Linux64"
case "$arch" in
    'aarch64'|'arm64')
        PLATFORM="LinuxARM64"
        ;;
    'arm'|'armv6l'|'armv7l')
        PLATFORM="LinuxARM"
        ;;
esac

DOWNLOAD_URL_API="https://www.ispyconnect.com/api/Agent/DownloadLocation5?platform=${PLATFORM}&useVersion=${USE_VERSION}&useBeta=$( [ "$USE_BETA" = "true" ] && echo "True" || echo "False" )"

# Fetch the actual download URL
DOWNLOAD_URL=$(curl -s --fail --connect-timeout 30 --speed-limit 1024 --speed-time 10 "$DOWNLOAD_URL_API" | tr -d '"')

# The website is Cloudflare-fronted and may be unreachable where Cloudflare is
# throttled. Fall back to discovering the latest version from GitHub releases.
# Only possible for the default (latest) version — a specific -v version number
# can't be mapped to a release tag without the website API.
if [ -z "$DOWNLOAD_URL" ] && [ "$USE_VERSION" -eq 0 ]; then
    error_log "Website API unreachable - discovering latest version from GitHub releases..."
    latest_tag=$(curl -s --fail --connect-timeout 30 "https://api.github.com/repos/ispysoftware/agent-install-scripts/releases?per_page=20" \
        | grep -oE '"tag_name": *"v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' \
        | head -n 1 \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    if [ -n "$latest_tag" ]; then
        v_underscore=$(echo "${latest_tag#v}" | tr '.' '_')
        DOWNLOAD_URL="$GITHUB_RELEASES/$latest_tag/Agent_${PLATFORM}_${v_underscore}.zip"
        info "Using GitHub release $latest_tag"
        if [ "$USE_BETA" = "true" ]; then
            info "Note: GitHub fallback installs the latest release; beta selection requires the website API."
        fi
    fi
fi

[ -n "$DOWNLOAD_URL" ] || critical_error "Failed to fetch download URL from $DOWNLOAD_URL_API."

version=$(echo "$DOWNLOAD_URL" | sed -E 's#.*/[^/]*_([0-9]+)_([0-9]+)_([0-9]+)_([0-9]+)\.zip$#\1\2\3\4#')

info "Extracted version: $version"

info "Using download URL: $DOWNLOAD_URL"

# Download AgentDVR with retry logic
download_agentdvr "$DOWNLOAD_URL" "$INSTALL_PATH/AgentDVR.zip"

# Verify authenticity before extracting or running anything. Builds older than
# SIG_MIN_VERSION predate signed releases and have no .sig to check, so they're skipped.
if [[ "$version" =~ ^[0-9]+$ ]] && [ "$version" -lt "$SIG_MIN_VERSION" ]; then
    info "Skipping signature verification: version $version predates signed builds (< $SIG_MIN_VERSION)."
else
    verify_agentdvr_zip "$INSTALL_PATH/AgentDVR.zip" "$DOWNLOAD_URL"
    case $? in
        0) info "AgentDVR.zip signature verified." ;;
        3) info "Skipping signature verification: openssl is not available on this system." ;;
        2) if [ "$REQUIRE_SIGNATURE" = "true" ]; then
               rm -f "$INSTALL_PATH/AgentDVR.zip"
               critical_error "AgentDVR.zip has no signature to verify, but version $version should have one. Set REQUIRE_SIGNATURE=false to install anyway."
           else
               info "Skipping signature verification (signature not available; REQUIRE_SIGNATURE=false)."
           fi ;;
        *) rm -f "$INSTALL_PATH/AgentDVR.zip"
           critical_error "AgentDVR.zip FAILED signature verification - the download may be corrupted or tampered with. Aborting." ;;
    esac
fi

# Extract the downloaded archive
info "Extracting AgentDVR.zip..."
if unzip -o "AgentDVR.zip" -d "$INSTALL_PATH" >> "$LOGFILE" 2>&1; then
    info "AgentDVR extracted successfully."
    rm "AgentDVR.zip"
    info "Removed AgentDVR.zip after extraction."
else
    critical_error "Failed to extract AgentDVR.zip."
fi

# Download start script for backward compatibility
info "Downloading start script for backward compatibility..."
if curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/start_agent.sh" -o "start_agent.sh" >> "$LOGFILE" 2>&1; then
    chmod a+x ./start_agent.sh
    info "Start script downloaded and made executable."
else
    critical_error "Failed to download start_agent.sh."
fi

# Set executable permissions
info "Setting execute permissions for Agent and scripts..."
chmod +x ./Agent || critical_error "Failed to set execute permission for Agent."
chmod +x ./TURN/turnserver 2>/dev/null

# Fix line endings and remove BOM for all .sh files
find . -name "*.sh" -exec bash -c '
  # Create a temporary file
  temp_file=$(mktemp)
  # Remove BOM and CR characters, then write to temp file
  sed -e "1s/^\xEF\xBB\xBF//" -e "s/\r$//" "$1" > "$temp_file"
  # Move temp file back to original
  mv "$temp_file" "$1"
' _ {} \; || critical_error "Failed to fix line endings and BOM for scripts."
info "Line endings and BOM fixed successfully."

find . -name "*.sh" -exec chmod +x {} \; || critical_error "Failed to set execute permissions for scripts."
info "Execute permissions set successfully."

# Add user to 'video' group for device access
info "Adding user '$ACTUAL_USER' to 'video' group for local device access..."
if machine_has "usermod"; then
    usermod -a -G video "$ACTUAL_USER" >> "$LOGFILE" 2>&1 || critical_error "Failed to append user '$ACTUAL_USER' to 'video' group."
elif machine_has "adduser"; then
    adduser "$ACTUAL_USER" video >> "$LOGFILE" 2>&1 || critical_error "Failed to add user '$ACTUAL_USER' to 'video' group."
else
    error_log "Neither 'usermod' nor 'adduser' command is available to modify user groups."
fi
info "User '$ACTUAL_USER' added to 'video' group successfully."

# Add user to 'render' group for GPU render node access (/dev/dri/renderD*)
if getent group render > /dev/null 2>&1; then
    if machine_has "usermod"; then
        usermod -a -G render "$ACTUAL_USER" >> "$LOGFILE" 2>&1 || error_log "Failed to append user '$ACTUAL_USER' to 'render' group."
    elif machine_has "adduser"; then
        adduser "$ACTUAL_USER" render >> "$LOGFILE" 2>&1 || error_log "Failed to add user '$ACTUAL_USER' to 'render' group."
    fi
    info "User '$ACTUAL_USER' added to 'render' group."
else
    info "No 'render' group on this system - skipping."
fi

echo "To run AgentDVR either call $INSTALL_PATH/Agent from the terminal or install it as a system service."

# Write the port for the server
available_port=$(find_port)

if [[ $? -ne 0 ]]; then
    error_log "No available ports found. Exiting."
    exit 1
fi

# Write port to file WITHOUT using `cd` so we don't break subsequent relative file paths
mkdir -p "$INSTALL_PATH/Media/XML"
echo "$available_port" > "$INSTALL_PATH/Media/XML/port.txt"
info "Port saved to $INSTALL_PATH/Media/XML/port.txt"

# Apply ownership to the actual user before any services or manual starts are triggered
chown "$ACTUAL_USER" -R "$INSTALL_PATH" || critical_error "Failed to change ownership of $INSTALL_PATH to $ACTUAL_USER."

# Option to set up as a system service
if [ "$AUTO_YES" = true ]; then
    answer="y"
    info "Unattended mode: Auto-setting up AgentDVR as a system service."
else
    printf "\nSetup AgentDVR as a system service (y/n)? " >/dev/tty
    read -r answer </dev/tty || answer="n"
fi
answer=${answer,,}  # Convert to lowercase

if [[ "$answer" == "y" || "$answer" == "yes" ]]; then
    info "User opted to set up AgentDVR as a system service."

    info "Downloading AgentDVR.service file..."
    if curl --show-error --location "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/AgentDVR.service" -o "AgentDVR.service" >> "$LOGFILE" 2>&1; then
        info "AgentDVR.service downloaded successfully."
    else
        critical_error "Failed to download AgentDVR.service."
    fi

    # Update the service file with installation path and actual username
    info "Configuring AgentDVR.service file with installation path and username..."
    sed -i "s|AGENT_LOCATION|$INSTALL_PATH|g" AgentDVR.service || critical_error "Failed to update AGENT_LOCATION in AgentDVR.service."
    sed -i "s|YOUR_USERNAME|$ACTUAL_USER|g" AgentDVR.service || critical_error "Failed to update YOUR_USERNAME in AgentDVR.service."

    chmod 644 ./AgentDVR.service
    info "Set permissions for AgentDVR.service."

    # Stop and disable existing service if it exists
    systemctl stop AgentDVR.service >> "$LOGFILE" 2>&1 || info "AgentDVR.service was not running."
    systemctl disable AgentDVR.service >> "$LOGFILE" 2>&1 || info "AgentDVR.service was not enabled."

    # Remove existing service file if it exists
    if [ -f /etc/systemd/system/AgentDVR.service ]; then
        rm /etc/systemd/system/AgentDVR.service
        info "Removed existing /etc/systemd/system/AgentDVR.service."
    fi

    # Copy the service file to systemd directory
    cp AgentDVR.service /etc/systemd/system/AgentDVR.service || critical_error "Failed to copy AgentDVR.service to /etc/systemd/system/."
    rm -f AgentDVR.service
    info "AgentDVR.service copied to /etc/systemd/system and local copy removed."

    # The unit's network-online.target dependency is a no-op unless the distro's
    # wait-online service is enabled. Enable whichever network manager is active
    # (best-effort - not fatal if neither exists, e.g. WSL or containers).
    if systemctl list-unit-files NetworkManager-wait-online.service --no-legend 2>/dev/null | grep -q .; then
        systemctl enable NetworkManager-wait-online.service >> "$LOGFILE" 2>&1 || info "Warning: Failed to enable NetworkManager-wait-online."
    elif systemctl list-unit-files systemd-networkd-wait-online.service --no-legend 2>/dev/null | grep -q .; then
        systemctl enable systemd-networkd-wait-online.service >> "$LOGFILE" 2>&1 || info "Warning: Failed to enable systemd-networkd-wait-online."
    else
        info "No wait-online service found; network-online.target may not delay startup."
    fi

    # Reload systemd daemon to recognize the new service
    systemctl daemon-reload >> "$LOGFILE" 2>&1 || info "Warning: Failed to reload systemd daemon."

    # Enable and start the AgentDVR service
    systemctl enable AgentDVR.service >> "$LOGFILE" 2>&1 || critical_error "Failed to enable AgentDVR.service."
    systemctl start AgentDVR.service >> "$LOGFILE" 2>&1 || critical_error "Failed to start AgentDVR.service."
    info "AgentDVR service enabled and started successfully."

    # Create desktop shortcut using ACTUAL_USER
    create_system_shortcut "$INSTALL_PATH" "$ACTUAL_USER" "$available_port"

    echo "Started AgentDVR service."
    echo "Use the application shortcuts or go to http://localhost:$available_port to configure AgentDVR."
    exit 0
else
    info "User opted not to set up AgentDVR as a system service."
    echo "Starting Agent DVR from the terminal..."
    cd "$INSTALL_PATH" || critical_error "Failed to navigate to $INSTALL_PATH."
    ./Agent &
    sleep 2  # Give it a moment to start
    if pgrep -f "Agent" > /dev/null; then
        info "AgentDVR started successfully."
        echo "AgentDVR is running. Visit http://localhost:$available_port to configure."
    else
        error_log "Failed to start AgentDVR."
    fi
fi

info "===== AgentDVR Linux Setup Script Completed ====="
exit 0
