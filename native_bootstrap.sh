#!/bin/bash

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/tmp/${SCRIPT_NAME}.log"

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" | tee -a "$LOG_FILE"
    fi
}

# Error handler
error_exit() {
    error "$1"
    error "Bootstrap failed. Check log file: $LOG_FILE"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root. Please run as a regular user."
    fi
}

# Check system requirements
check_system() {
    log "Checking system requirements..."
    
    # Check OS
    if ! command -v apt >/dev/null 2>&1; then
        error_exit "This script requires apt package manager (Debian/Ubuntu-based system)"
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        warn "This script requires sudo access. You may be prompted for your password."
    fi
    
    # Check internet connectivity
    if ! curl -s --connect-timeout 5 https://www.baidu.com >/dev/null; then
        error_exit "Internet connection required for package installation"
    fi
    
    log "System requirements check passed"
}

prepare_ppa_key() {
    log "Checking KiCad PPA repository..."
    if ! grep -q "kicad/kicad-9.0-releases" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        log "Adding KiCad PPA repository..."
        if ! sudo add-apt-repository -y ppa:kicad/kicad-9.0-releases; then
            error_exit "Failed to add KiCad PPA repository"
        fi
    else
        log "KiCad PPA repository already exists, skipping..."
    fi
}


# Update package lists
update_packages() {
    log "Updating package lists..."
    if ! sudo apt update; then
        error_exit "Failed to update package lists"
    fi
}

# Install a single package with retry logic
install_package() {
    local package="$1"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if sudo apt install -y "$package"; then
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        warn "Failed to install $package (attempt $retry_count/$max_retries)"
        
        if [[ $retry_count -lt $max_retries ]]; then
            log "Retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    error "Failed to install $package after $max_retries attempts"
    return 1
}

# Install Ubuntu/Debian dependencies
install_ubuntu_deps() {
    log "Installing Ubuntu/Debian dependencies..."
    
    local cad_packages=(
  		"kicad"
    )
	local all_packages=("${cad_packages[@]}")
	local failed_packages=()
	for package in "${all_packages[@]}"; do
        log "Installing $package..."
        if ! install_package "$package"; then
            failed_packages+=("$package")
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        error "Failed to install packages: ${failed_packages[*]}"
        return 1
    fi
	log "Ubuntu/Debian dependencies installed successfully"
}


# Main function
main() {
> "$LOG_FILE" # Clear log file
	log "Starting SLocks build system bootstrap..."
    log "Log file: $LOG_FILE"
    
    prepare_ppa_key
    update_packages
    install_ubuntu_deps
    
    log "KiCad installation completed!"
}

# Set up signal handlers
trap 'error_exit "Script interrupted by user"' INT TERM
# Run main function
main "$@"