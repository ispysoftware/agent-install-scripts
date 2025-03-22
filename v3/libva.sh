#!/bin/bash

# Check if libva is installed and get its version
check_libva_installation() {
    echo "Checking for libva installation..."
    
    # Try different methods to find libva
    if command -v vainfo &> /dev/null; then
        echo "vainfo command found, checking version..."
        VAINFO_OUTPUT=$(vainfo --version 2>&1)
        echo "vainfo output: $VAINFO_OUTPUT"
        LIBVA_VERSION=$(echo "$VAINFO_OUTPUT" | grep -oP "libva \K[0-9]+\.[0-9]+(\.[0-9]+)?" || echo "")
    elif pkg-config --exists libva 2>/dev/null; then
        echo "libva found via pkg-config, checking version..."
        PKG_OUTPUT=$(pkg-config --modversion libva 2>&1)
        echo "pkg-config output: $PKG_OUTPUT"
        LIBVA_VERSION="$PKG_OUTPUT"
    elif ldconfig -p 2>/dev/null | grep -q libva; then
        echo "libva found in system libraries, attempting to determine version..."
        # This is a fallback and might not be accurate
        LDCONFIG_OUTPUT=$(ldconfig -v 2>/dev/null | grep libva)
        echo "ldconfig relevant output: $LDCONFIG_OUTPUT"
        LIBVA_MAJOR=$(echo "$LDCONFIG_OUTPUT" | grep -oP "libva\.so\.\K[0-9]+" | sort -nr | head -1 || echo "0")
        LIBVA_MINOR=$(echo "$LDCONFIG_OUTPUT" | grep -oP "libva\.so\.[0-9]+\.\K[0-9]+" | sort -nr | head -1 || echo "0")
        LIBVA_VERSION="$LIBVA_MAJOR.$LIBVA_MINOR.0"
    else
        echo "libva not found on the system"
        LIBVA_VERSION="0.0.0"
    fi
    
    echo "Detected libva version: $LIBVA_VERSION"
    
    # Check if version is 2.21 or higher
    if [ -n "$LIBVA_VERSION" ]; then
        # Extract just the major and minor version components
        # This handles quirky version strings like "2.1700.0" by normalizing them
        MAJOR=$(echo $LIBVA_VERSION | grep -oP "^[0-9]+" || echo "0")
        MINOR=$(echo $LIBVA_VERSION | grep -oP "^[0-9]+\.\K[0-9]+" || echo "0")
        
        # Trim minor version to its first two digits to handle cases like "1700" -> "17"
        if [ ${#MINOR} -gt 2 ]; then
            echo "Trimming long minor version: $MINOR -> ${MINOR:0:2}"
            MINOR=${MINOR:0:2}
        fi
        
        echo "Normalized version: $MAJOR.$MINOR.x"
        
        # Convert to integers for proper comparison
        MAJOR_INT=$((MAJOR))
        MINOR_INT=$((MINOR))
        
        if [ "$MAJOR_INT" -gt 2 ] || ([ "$MAJOR_INT" -eq 2 ] && [ "$MINOR_INT" -ge 21 ]); then
            echo "Suitable libva version detected (≥ 2.21)"
            return 0
        else
            echo "libva version is too old (< 2.21)"
            return 1
        fi
    else
        echo "Could not determine libva version"
        return 1
    fi
}

# Download and run the libva installation script
install_libva() {
    echo "Downloading libva installation script..."
    TEMP_SCRIPT=$(mktemp)
    
    if command -v curl &> /dev/null; then
        # Bypass cache by adding a timestamp parameter
        curl -s "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/libva.sh?$(date +%s)" -o "$TEMP_SCRIPT"
    elif command -v wget &> /dev/null; then
        wget -q "https://raw.githubusercontent.com/ispysoftware/agent-install-scripts/main/v3/libva.sh" -O "$TEMP_SCRIPT"
    else
        echo "Error: Neither curl nor wget is installed. Cannot download the script."
        return 1
    fi
    
    if [ ! -s "$TEMP_SCRIPT" ]; then
        echo "Error: Failed to download the script or the downloaded file is empty."
        return 1
    fi
    
    echo "Making the script executable..."
    chmod +x "$TEMP_SCRIPT"
    
    echo "Running libva installation script..."
    bash "$TEMP_SCRIPT"
    
    # Clean up
    rm -f "$TEMP_SCRIPT"
    
    echo "libva installation completed"
    return 0
}

# Main function to check and potentially install libva
setup_libva() {
    if check_libva_installation; then
        echo "libva ≥ 2.21 is already installed on the system."
        echo "Continuing with installation..."
        return 0
    else
        echo "--------------------------------------------------------------"
        echo "GPU hardware acceleration support requires libva ≥ 2.21"
        echo "This is needed for FFmpeg v7 to properly utilize your GPU for"
        echo "video encoding/decoding, which can significantly improve"
        echo "performance and reduce CPU usage."
        echo "--------------------------------------------------------------"
        
        # Check if we're running in a non-interactive mode
        if [ -z "$INTERACTIVE" ] || [ "$INTERACTIVE" = "true" ]; then
            read -p "Would you like to install libva 2.22.0? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                install_libva
                # Verify installation was successful
                if check_libva_installation; then
                    echo "libva ≥ 2.21 was successfully installed."
                    return 0
                else
                    echo "Warning: libva installation may not have completed successfully."
                    echo "Continuing with installation, but GPU acceleration may not work."
                    return 1
                fi
            else
                echo "Skipping libva installation."
                echo "Note: GPU hardware acceleration will not be available."
                return 1
            fi
        else
            # In non-interactive mode, automatically install
            echo "Running in non-interactive mode. Automatically installing libva..."
            install_libva
            
            # Verify installation was successful
            if check_libva_installation; then
                echo "libva ≥ 2.21 was successfully installed."
                return 0
            else
                echo "Warning: libva installation may not have completed successfully."
                echo "Continuing with installation, but GPU acceleration may not work."
                return 1
            fi
        fi
    fi
}

# Call the function in your main installation script
setup_libva