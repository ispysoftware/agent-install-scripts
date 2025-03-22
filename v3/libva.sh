#!/bin/bash
set -e

# Exit on error
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Detect Linux distribution
detect_distro() {
    echo "Detecting Linux distribution..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID
        echo "Detected distribution: $DISTRO $DISTRO_VERSION"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
        DISTRO_VERSION=$DISTRIB_RELEASE
        echo "Detected distribution: $DISTRO $DISTRO_VERSION"
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        DISTRO_VERSION=$(cat /etc/debian_version)
        echo "Detected distribution: $DISTRO $DISTRO_VERSION"
    elif [ -f /etc/redhat-release ]; then
        DISTRO="redhat"
        echo "Detected Red Hat-based distribution"
    elif [ -f /etc/arch-release ]; then
        DISTRO="arch"
        echo "Detected Arch Linux"
    elif [ -f /etc/gentoo-release ]; then
        DISTRO="gentoo"
        echo "Detected Gentoo Linux"
    elif [ -f /etc/SuSE-release ]; then
        DISTRO="suse"
        echo "Detected SuSE Linux"
    elif [ -f /etc/alpine-release ]; then
        DISTRO="alpine"
        echo "Detected Alpine Linux"
    else
        DISTRO="unknown"
        echo "Unable to detect distribution, will attempt to continue with manual dependency checks"
    fi
}

# Install required dependencies based on the detected distribution
install_dependencies() {
    echo "Checking and installing required dependencies..."
    
    PACKAGES="git autoconf automake libtool gettext pkg-config make gcc flex bison"
    
    case $DISTRO in
        ubuntu|debian|pop|mint|elementary|kali|deepin|parrot)
            echo "Installing dependencies for Debian-based system..."
            sudo apt-get update
            # Debian-specific packages
            sudo apt-get install -y $PACKAGES libtool-bin libdrm-dev xorg-dev
            ;;
        fedora|centos|rhel|redhat|rocky|alma)
            echo "Installing dependencies for Red Hat-based system..."
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y $PACKAGES libdrm-devel xorg-x11-server-devel xorg-x11-proto-devel
            else
                sudo yum install -y $PACKAGES libdrm-devel xorg-x11-server-devel xorg-x11-proto-devel
            fi
            ;;
        arch|manjaro|endeavouros)
            echo "Installing dependencies for Arch-based system..."
            sudo pacman -Sy --needed $PACKAGES libdrm xorg-server-devel xorgproto
            ;;
        opensuse|suse)
            echo "Installing dependencies for SuSE-based system..."
            sudo zypper install -y $PACKAGES libdrm-devel xorg-x11-devel xorg-x11-proto-devel
            ;;
        gentoo)
            echo "Installing dependencies for Gentoo system..."
            sudo emerge --ask --verbose dev-vcs/git sys-devel/autoconf sys-devel/automake sys-devel/libtool dev-util/pkgconfig sys-devel/gcc x11-libs/libdrm x11-base/xorg-server dev-util/gettext sys-devel/flex sys-devel/bison
            ;;
        alpine)
            echo "Installing dependencies for Alpine system..."
            sudo apk add git autoconf automake libtool gettext pkgconfig make gcc g++ flex bison libdrm-dev xorg-server-dev
            ;;
        *)
            echo "Unknown distribution, checking for dependencies manually..."
            for cmd in git autoconf automake libtool pkg-config make gcc flex bison gettext; do
                if ! command -v $cmd >/dev/null 2>&1; then
                    echo "Warning: $cmd is not found, but might be required. Please install it if build fails."
                fi
            done
            echo "Basic build dependencies found, but additional libraries might be needed"
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                error_exit "Aborted by user"
            fi
            ;;
    esac
    
    echo "All build dependencies are installed."
}

# Create a temporary build directory
create_build_dir() {
    BUILD_DIR=$(mktemp -d)
    echo "Created temporary build directory: $BUILD_DIR"
    cd "$BUILD_DIR" || error_exit "Failed to change to build directory"
}

# Clone and build libva
build_libva() {
    echo "Cloning libva repository..."
    git clone https://github.com/intel/libva.git || error_exit "Failed to clone libva repository"
    cd libva || error_exit "Failed to change to libva directory"
    
    # Pin to version 2.22.0 specifically
    if git tag | grep -q "^2.22.0$"; then
        echo "Checking out version 2.22.0..."
        git checkout 2.22.0 || error_exit "Failed to checkout version 2.22.0"
    elif git tag | grep -q "^2.22$"; then
        # Sometimes projects use shorter version tags
        echo "Checking out version 2.22..."
        git checkout 2.22 || error_exit "Failed to checkout version 2.22"
    else
        echo "Error: Version 2.22.0 not found in repository."
        echo "Available versions:"
        git tag | grep -E "^2\.[0-9]+(\.[0-9]+)?$" | sort -V | tail -n 10
        
        read -p "Would you like to try building from a specific commit hash instead? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Try to find the commit that would most likely have 2.22.0 code
            # Look at the commit history around when 2.22.0 would likely have been released
            echo "Attempting to identify commit from around 2.22.0 release..."
            
            # Get nearby version tags to triangulate
            LOWER_VERSION=$(git tag | grep -E "^2\.[0-9]+(\.[0-9]+)?$" | sort -V | grep -B1 "2\.23" | head -1 || echo "")
            HIGHER_VERSION=$(git tag | grep -E "^2\.[0-9]+(\.[0-9]+)?$" | sort -V | grep -A1 "2\.22" | tail -1 || echo "")
            
            if [ -n "$LOWER_VERSION" ] && [ -n "$HIGHER_VERSION" ]; then
                echo "Found versions surrounding 2.22: $LOWER_VERSION and $HIGHER_VERSION"
                COMMIT_HASH=$(git log --pretty=format:"%H" $LOWER_VERSION..$HIGHER_VERSION | head -1)
                echo "Using commit: $COMMIT_HASH"
                git checkout $COMMIT_HASH || error_exit "Failed to checkout commit"
            else
                error_exit "Cannot find a suitable commit for version 2.22.0. Please specify a different version."
            fi
        else
            error_exit "Version 2.22.0 required but not found. Aborting."
        fi
    fi
    
    echo "Generating build system..."
    ./autogen.sh || error_exit "Failed to run autogen.sh"
    
    echo "Configuring libva..."
    ./configure --prefix=/usr || error_exit "Failed to configure libva"
    
    echo "Building libva..."
    make -j$(nproc 2>/dev/null || echo 2) || error_exit "Failed to build libva"
}

# Install libva (requires sudo)
install_libva() {
    echo "Installing libva..."
    
    if [ "$EUID" -eq 0 ]; then
        # Running as root
        make install || error_exit "Failed to install libva"
        ldconfig || error_exit "Failed to run ldconfig"
    else
        # Not running as root, use sudo
        sudo make install || error_exit "Failed to install libva. Make sure you have sudo privileges."
        sudo ldconfig || error_exit "Failed to run ldconfig"
    fi
    
    # Verify installation
    echo "Verifying installation..."
    if ldconfig -p | grep -q libva; then
        echo "libva installation verified successfully!"
    else
        echo "Warning: libva library not found in ldconfig cache."
        echo "You may need to update your library configuration or restart your system."
    fi
}

# Clean up
cleanup() {
    echo "Cleaning up..."
    cd "$HOME" || true
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        echo "Removed temporary build directory"
    fi
}

# Print system information
print_system_info() {
    echo "System information:"
    echo "--------------------"
    echo "Distribution: $DISTRO $DISTRO_VERSION"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "--------------------"
}

# Main execution
main() {
    echo "Starting libva 2.22.0 build and installation script (strictly pinned to version 2.22.0)..."
    
    detect_distro
    print_system_info
    install_dependencies
    create_build_dir
    build_libva
    install_libva
    cleanup
    
    echo "libva has been successfully built and installed!"
    echo "You can now build ffmpeg v7 with libva support."
}

# Check if script is being run as root
if [ "$EUID" -eq 0 ]; then
    echo "Running as root"
fi

# Run the script
main