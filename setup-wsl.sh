#!/bin/bash

# ============================================================================
# WSL Development Environment Setup Script (Universal)
# ============================================================================
#
# Description: Universal setup script for WSL (Windows Subsystem for Linux)
#              that works with multiple Linux distributions including Ubuntu
#              and Fedora. Automatically detects the distribution and applies
#              appropriate configurations.
#
# Author:      Gishant
# Version:     1.0
# Date:        July 2025
#
# Features:
# - Automatic Linux distribution detection (Ubuntu/Fedora/etc.)
# - WSL-specific optimizations and configurations
# - X11 forwarding setup for GUI applications
# - Container tools configuration for WSL
# - Git configuration for Windows/Linux interoperability
# - Development environment setup
# - Browser and VS Code integration
#
# Usage: ./setup-wsl.sh
#
# Prerequisites:
# - Running in WSL environment
# - Internet connection
# - Sudo privileges
#
# Supported Distributions:
# - Ubuntu 20.04, 22.04, 24.04
# - Fedora 39, 40, 41, 42
# - Debian (basic support)
#
# ============================================================================

# --- Script Configuration ---
set -e
set -u
set -o pipefail

# --- Color Codes for Output Formatting ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# --- Global Variables ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOGS_DIR="${SCRIPT_DIR}/logs"
readonly LOG_FILE="${LOGS_DIR}/wsl_setup_$(date +%Y%m%d_%H%M%S).log"
readonly BACKUP_DIR="${HOME}/.config_backup_$(date +%Y%m%d_%H%M%S)"

# Distribution detection
DISTRO=""
DISTRO_VERSION=""
PACKAGE_MANAGER=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Enhanced logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} ${timestamp}: $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} ${timestamp}: $message" | tee -a "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} ${timestamp}: $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${timestamp}: $message" | tee -a "$LOG_FILE"
            ;;
        "HEADER")
            echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║ $message${NC}"
            echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}\n"
            echo "$timestamp: HEADER: $message" >> "$LOG_FILE"
            ;;
    esac
}

# Interactive confirmation function
confirm() {
    local message="$1"
    local default="${2:-n}"
    local prompt

    if [[ "$default" == "y" ]]; then
        prompt=" (Y/n): "
    else
        prompt=" (y/N): "
    fi

    while true; do
        read -rp "$(echo -e "${YELLOW}${message}${prompt}${NC}")" response
        response=${response:-$default}
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo -e "${RED}Please answer yes or no.${NC}" ;;
        esac
    done
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# ============================================================================
# WSL DETECTION AND VALIDATION
# ============================================================================

check_wsl_environment() {
    log "HEADER" "WSL ENVIRONMENT VALIDATION"
    
    # Check if running in WSL
    if [[ ! -f "/proc/version" ]] || ! grep -qi "microsoft\|wsl" /proc/version; then
        if [[ "${WSL_DISTRO_NAME:-}" == "" ]]; then
            log "ERROR" "This script is designed to run in WSL (Windows Subsystem for Linux)."
            log "ERROR" "Current environment does not appear to be WSL."
            exit 1
        fi
    fi
    
    log "SUCCESS" "WSL environment detected."
    log "INFO" "WSL Distribution: ${WSL_DISTRO_NAME:-Unknown}"
    log "INFO" "WSL Version: $(cat /proc/version | grep -o 'WSL[0-9]*' || echo 'Unknown')"
}

# ============================================================================
# DISTRIBUTION DETECTION
# ============================================================================

detect_distribution() {
    log "HEADER" "LINUX DISTRIBUTION DETECTION"
    
    if [[ -f "/etc/os-release" ]]; then
        source /etc/os-release
        DISTRO="${ID}"
        DISTRO_VERSION="${VERSION_ID}"
        
        case "$DISTRO" in
            "ubuntu")
                PACKAGE_MANAGER="apt"
                log "INFO" "Detected Ubuntu ${DISTRO_VERSION}"
                ;;
            "fedora")
                PACKAGE_MANAGER="dnf"
                log "INFO" "Detected Fedora ${DISTRO_VERSION}"
                ;;
            "debian")
                PACKAGE_MANAGER="apt"
                log "INFO" "Detected Debian ${DISTRO_VERSION}"
                ;;
            *)
                log "WARNING" "Unsupported or unknown distribution: ${DISTRO}"
                log "WARNING" "Attempting to continue with best-effort support."
                # Try to detect package manager
                if command_exists apt; then
                    PACKAGE_MANAGER="apt"
                elif command_exists dnf; then
                    PACKAGE_MANAGER="dnf"
                elif command_exists yum; then
                    PACKAGE_MANAGER="yum"
                else
                    log "ERROR" "Unable to detect package manager."
                    exit 1
                fi
                ;;
        esac
    else
        log "ERROR" "Unable to detect Linux distribution. /etc/os-release not found."
        exit 1
    fi
    
    log "SUCCESS" "Distribution detection completed: ${DISTRO} ${DISTRO_VERSION} (${PACKAGE_MANAGER})"
}

# ============================================================================
# SYSTEM UPDATE
# ============================================================================

update_system() {
    log "HEADER" "SYSTEM UPDATE"
    
    case "$PACKAGE_MANAGER" in
        "apt")
            log "INFO" "Updating package lists and upgrading system (APT)..."
            sudo apt update && sudo apt upgrade -y
            ;;
        "dnf")
            log "INFO" "Updating system packages (DNF)..."
            sudo dnf upgrade --refresh -y
            ;;
        "yum")
            log "INFO" "Updating system packages (YUM)..."
            sudo yum update -y
            ;;
        *)
            log "ERROR" "Unsupported package manager: $PACKAGE_MANAGER"
            exit 1
            ;;
    esac
    
    log "SUCCESS" "System update completed."
}

# ============================================================================
# WSL-SPECIFIC CONFIGURATIONS
# ============================================================================

configure_wsl_basics() {
    log "HEADER" "WSL BASIC CONFIGURATION"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Configure Git for WSL (Windows/Linux interoperability)
    log "INFO" "Configuring Git for WSL..."
    if command_exists git; then
        git config --global core.autocrlf input
        git config --global core.filemode false
        git config --global init.defaultBranch main
    fi
    
    # Configure WSL display for X11 forwarding
    log "INFO" "Setting up X11 forwarding configuration..."
    local windows_host
    windows_host=$(ip route show | grep -i default | awk '{ print $3}')
    
    # Add DISPLAY configuration to shell profiles
    local display_config="# WSL Display Configuration for X11 Forwarding
export DISPLAY=\$(ip route show | grep -i default | awk '{ print \$3}'):0.0

# WSL-specific aliases and functions
alias explorer='explorer.exe'
alias code='code.exe'
alias winget='winget.exe'

# Function to open current directory in Windows Explorer
open() {
    if [[ \$# -eq 0 ]]; then
        explorer.exe .
    else
        explorer.exe \"\$1\"
    fi
}"
    
    # Add to .bashrc if it exists
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q "WSL Display Configuration" "$HOME/.bashrc"; then
            echo "$display_config" >> "$HOME/.bashrc"
            log "INFO" "Added WSL configuration to .bashrc"
        fi
    fi
    
    # Add to .zshrc if it exists
    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "WSL Display Configuration" "$HOME/.zshrc"; then
            echo "$display_config" >> "$HOME/.zshrc"
            log "INFO" "Added WSL configuration to .zshrc"
        fi
    fi
    
    log "SUCCESS" "WSL basic configuration completed."
}

# ============================================================================
# DEVELOPMENT TOOLS INSTALLATION
# ============================================================================

install_essential_tools() {
    log "HEADER" "ESSENTIAL DEVELOPMENT TOOLS"
    
    local tools_apt=(
        "curl"
        "wget"
        "git"
        "vim"
        "nano"
        "htop"
        "tree"
        "unzip"
        "zip"
        "jq"
        "build-essential"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
    )
    
    local tools_dnf=(
        "curl"
        "wget"
        "git"
        "vim"
        "nano"
        "htop"
        "tree"
        "unzip"
        "zip"
        "jq"
        "gcc"
        "make"
        "kernel-devel"
        "kernel-headers"
    )
    
    case "$PACKAGE_MANAGER" in
        "apt")
            log "INFO" "Installing essential tools via APT..."
            sudo apt install -y "${tools_apt[@]}"
            ;;
        "dnf")
            log "INFO" "Installing essential tools via DNF..."
            sudo dnf install -y "${tools_dnf[@]}"
            ;;
        *)
            log "WARNING" "Package manager not fully supported. Skipping essential tools."
            ;;
    esac
    
    log "SUCCESS" "Essential tools installation completed."
}

# ============================================================================
# CONTAINER TOOLS (WSL-OPTIMIZED)
# ============================================================================

install_container_tools() {
    log "HEADER" "CONTAINER TOOLS (WSL OPTIMIZED)"
    
    if ! confirm "Install Docker for WSL?"; then
        log "INFO" "Skipping container tools installation."
        return
    fi
    
    log "INFO" "Installing Docker for WSL..."
    log "INFO" "Note: For the best WSL experience, use Docker Desktop for Windows."
    
    case "$PACKAGE_MANAGER" in
        "apt")
            # Remove old versions
            sudo apt remove -y docker docker-engine docker.io containerd runc || true
            
            # Add Docker's official GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/${DISTRO}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Add Docker repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO} $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        "dnf")
            sudo dnf install -y dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        *)
            log "ERROR" "Docker installation not supported for this package manager."
            return
            ;;
    esac
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
    
    log "WARNING" "Docker installed successfully."
    log "WARNING" "In WSL, start Docker with: sudo dockerd &"
    log "WARNING" "Or use Docker Desktop for Windows for automatic integration."
    log "WARNING" "You need to log out and back in for group changes to take effect."
    
    log "SUCCESS" "Container tools installation completed."
}

# ============================================================================
# PROGRAMMING LANGUAGES
# ============================================================================

install_programming_languages() {
    log "HEADER" "PROGRAMMING LANGUAGES SETUP"
    
    # Node.js via NodeSource
    if confirm "Install Node.js (LTS)?"; then
        log "INFO" "Installing Node.js LTS..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        case "$PACKAGE_MANAGER" in
            "apt")
                sudo apt install -y nodejs
                ;;
            "dnf")
                sudo dnf install -y nodejs npm
                ;;
        esac
        log "SUCCESS" "Node.js installed: $(node --version)"
    fi
    
    # Python development tools
    if confirm "Install Python development tools?"; then
        log "INFO" "Installing Python development tools..."
        case "$PACKAGE_MANAGER" in
            "apt")
                sudo apt install -y python3 python3-pip python3-venv python3-dev
                ;;
            "dnf")
                sudo dnf install -y python3 python3-pip python3-devel
                ;;
        esac
        
        # Install pipx for isolated Python applications
        python3 -m pip install --user pipx
        python3 -m pipx ensurepath
        
        log "SUCCESS" "Python development tools installed."
    fi
    
    # Go
    if confirm "Install Go programming language?"; then
        log "INFO" "Installing Go..."
        case "$PACKAGE_MANAGER" in
            "apt")
                sudo apt install -y golang-go
                ;;
            "dnf")
                sudo dnf install -y golang
                ;;
        esac
        
        # Set up Go workspace
        mkdir -p "$HOME/go"
        echo 'export GOPATH=$HOME/go' >> "$HOME/.profile"
        echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> "$HOME/.profile"
        
        log "SUCCESS" "Go installed and configured."
    fi
    
    # Rust
    if confirm "Install Rust programming language?"; then
        log "INFO" "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        rustup component add rustfmt clippy rust-analyzer
        log "SUCCESS" "Rust installed and configured."
    fi
}

# ============================================================================
# WSL INTEGRATION TOOLS
# ============================================================================

setup_wsl_integration() {
    log "HEADER" "WSL INTEGRATION SETUP"
    
    # Windows Path integration check
    if echo "$PATH" | grep -q "/mnt/c/"; then
        log "INFO" "Windows PATH integration detected."
    else
        log "WARNING" "Windows PATH integration not detected."
        log "INFO" "You may need to enable it in WSL configuration."
    fi
    
    # Create symbolic links to common Windows directories
    log "INFO" "Creating convenient symbolic links..."
    
    mkdir -p "$HOME/windows"
    
    # Link to common Windows directories if they exist
    if [[ -d "/mnt/c/Users/$USER" ]]; then
        ln -sf "/mnt/c/Users/$USER" "$HOME/windows/profile" 2>/dev/null || true
        ln -sf "/mnt/c/Users/$USER/Desktop" "$HOME/windows/desktop" 2>/dev/null || true
        ln -sf "/mnt/c/Users/$USER/Documents" "$HOME/windows/documents" 2>/dev/null || true
        ln -sf "/mnt/c/Users/$USER/Downloads" "$HOME/windows/downloads" 2>/dev/null || true
        log "INFO" "Created symbolic links to Windows user directories."
    fi
    
    # Link to Windows drives
    ln -sf "/mnt/c" "$HOME/windows/c_drive" 2>/dev/null || true
    [[ -d "/mnt/d" ]] && ln -sf "/mnt/d" "$HOME/windows/d_drive" 2>/dev/null || true
    
    log "SUCCESS" "WSL integration setup completed."
}

# ============================================================================
# FINALIZATION
# ============================================================================

finalize_setup() {
    log "HEADER" "SETUP FINALIZATION"
    
    # Create a WSL-specific configuration file
    cat > "$HOME/.wsl_config" << 'EOF'
# WSL Configuration File
# This file contains WSL-specific settings and information

# Generated by WSL Setup Script
SETUP_DATE="$(date)"
DISTRO="'"$DISTRO"'"
DISTRO_VERSION="'"$DISTRO_VERSION"'"
PACKAGE_MANAGER="'"$PACKAGE_MANAGER"'"

# WSL-specific aliases and functions are in your shell configuration files
# Common Windows integration paths are available in ~/windows/

# To start Docker manually: sudo dockerd &
# To access Windows files: cd ~/windows/
# To open current directory in Windows Explorer: explorer.exe .
# To open VS Code: code.exe .
EOF
    
    log "INFO" "Created WSL configuration file at ~/.wsl_config"
    
    # Display summary
    log "SUCCESS" "WSL Development Environment Setup Complete!"
    echo -e "\n${BOLD}${GREEN}Setup Summary:${NC}"
    echo -e "${BLUE}• Distribution:${NC} $DISTRO $DISTRO_VERSION"
    echo -e "${BLUE}• Package Manager:${NC} $PACKAGE_MANAGER"
    echo -e "${BLUE}• Log File:${NC} $LOG_FILE"
    echo -e "${BLUE}• Backup Directory:${NC} $BACKUP_DIR"
    echo -e "${BLUE}• Windows Integration:${NC} ~/windows/ directory created"
    
    echo -e "\n${BOLD}${YELLOW}Next Steps:${NC}"
    echo -e "${YELLOW}1.${NC} Log out and log back in to apply group changes"
    echo -e "${YELLOW}2.${NC} Source your shell configuration: ${BOLD}source ~/.bashrc${NC} or ${BOLD}source ~/.zshrc${NC}"
    echo -e "${YELLOW}3.${NC} Test Windows integration: ${BOLD}explorer.exe .${NC}"
    echo -e "${YELLOW}4.${NC} If using Docker, start it manually: ${BOLD}sudo dockerd &${NC}"
    echo -e "${YELLOW}5.${NC} Consider installing Docker Desktop for Windows for better integration"
    
    log "INFO" "Setup completed successfully. Enjoy your WSL development environment!"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Create logs directory if it doesn't exist
    mkdir -p "$LOGS_DIR"
    
    log "HEADER" "WSL DEVELOPMENT ENVIRONMENT SETUP"
    log "INFO" "Starting WSL setup script..."
    
    # Core setup steps
    check_wsl_environment
    detect_distribution
    update_system
    configure_wsl_basics
    install_essential_tools
    
    # Optional components
    install_container_tools
    install_programming_languages
    setup_wsl_integration
    
    # Finalize
    finalize_setup
}

# Start the script
main "$@"
