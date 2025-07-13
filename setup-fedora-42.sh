#!/bin/bash

# ============================================================================
# Fedora 42 KDE Plasma Wayland Development Environment Setup Script
# ============================================================================
#
# Description: Complete installation and configuration script for a modern
#              development environment on Fedora 42 KDE Plasma with Wayland.
#              Also supports WSL (Windows Subsystem for Linux) environments.
#
# Author:      Gishant
# Version:     1.1
# Date:        July 2025
#
# Features:
# - Colorful verbose logging with progress indicators.
# - Interactive prompts for user choices.
# - Proper installation order and dependency management.
# - Comprehensive error handling.
# - Modular design with categorized installations.
# - Detailed documentation and comments.
# - Creates a backup of existing configuration files.
# - WSL environment detection and optimization.
#
# Usage: ./setup-fedora-42.sh
#
# Prerequisites:
# - A fresh installation of Fedora 42 KDE Plasma (Wayland session) OR Fedora on WSL.
# - An active internet connection.
# - Sudo privileges for the current user.
# - At least 10GB of free disk space is recommended.
#
# WSL Notes:
# - Automatically detects WSL environment and adjusts configurations.
# - Skips desktop environment and GPU driver installations.
# - Configures container tools for WSL compatibility.
# - Sets up X11 forwarding for GUI applications.
#
# ============================================================================

# --- Script Configuration ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipe commands return the exit status of the last command in the pipe.
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
TOTAL_STEPS=18
CURRENT_STEP=0
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOGS_DIR="${SCRIPT_DIR}/logs"
readonly LOG_FILE="${LOGS_DIR}/fedora_setup_$(date +%Y%m%d_%H%M%S).log"
readonly BACKUP_DIR="${HOME}/.config_backup_$(date +%Y%m%d_%H%M%S)"

# WSL Detection
IS_WSL=false

# Installation tracking
INSTALL_START_TIME=$(date +%s)
STEP_START_TIME=$(date +%s)
INSTALLED_TOOLS=()
SKIPPED_TOOLS=()
FAILED_TOOLS=()

# ============================================================================
# WSL DETECTION FUNCTION
# ============================================================================

# Check if running in WSL environment
detect_wsl() {
    if [[ -f "/proc/version" ]] && grep -qi "microsoft\|wsl" /proc/version; then
        IS_WSL=true
        return 0
    elif [[ -f "/proc/sys/kernel/osrelease" ]] && grep -qi "microsoft\|wsl" /proc/sys/kernel/osrelease; then
        IS_WSL=true
        return 0
    elif [[ "${WSL_DISTRO_NAME:-}" != "" ]]; then
        IS_WSL=true
        return 0
    else
        IS_WSL=false
        return 1
    fi
}

# WSL-specific configuration function
configure_wsl_environment() {
    if [[ "$IS_WSL" == "true" ]]; then
        log "INFO" "Configuring WSL-specific environment settings..."
        
        # Set DISPLAY for X11 forwarding (WSL2)
        if [[ ! -f "$HOME/.wslconfig" ]]; then
            log "INFO" "Creating WSL display configuration..."
            # Get Windows host IP for WSL2
            local windows_host
            windows_host=$(ip route show | grep -i default | awk '{ print $3}')
            export DISPLAY="${windows_host}:0.0"
            
            # Add to shell configuration
            if [[ -f "$HOME/.zshrc" ]]; then
                echo "# WSL Display Configuration" >> "$HOME/.zshrc"
                echo "export DISPLAY=\$(ip route show | grep -i default | awk '{ print \$3}'):0.0" >> "$HOME/.zshrc"
            fi
        fi
        
        # Configure WSL-specific Git settings
        if command_exists git; then
            log "INFO" "Configuring Git for WSL..."
            git config --global core.autocrlf input
            git config --global core.filemode false
        fi
        
        log "INFO" "WSL environment configuration completed."
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Enhanced logging function with timestamps, log levels, and visual indicators
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "INFO")
            echo -e "${BLUE}ℹ️  [INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ [SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  [WARNING]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}❌ [ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "PROGRESS")
            echo -e "${MAGENTA}🔄 [PROGRESS]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "INSTALL")
            echo -e "${CYAN}📦 [INSTALL]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "SKIP")
            echo -e "${YELLOW}⏭️  [SKIP]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "HEADER")
            echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║ 🚀 $message${NC}"
            echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}\n"
            echo "$timestamp: HEADER: $message" >> "$LOG_FILE"
            ;;
    esac
    
    # Also log to file with timestamp
    echo "$timestamp: [$level] $message" >> "$LOG_FILE"
}

# Spinner function for long operations
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    local message="${2:-Processing}"
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${CYAN}[%c]${NC} %s..." "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r"
}

# Enhanced progress bar function with time estimation
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    # Calculate time estimates
    local elapsed_time=$(($(date +%s) - INSTALL_START_TIME))
    local estimated_total_time=$((elapsed_time * total / current))
    local remaining_time=$((estimated_total_time - elapsed_time))
    
    # Format time
    local elapsed_formatted=$(format_time $elapsed_time)
    local remaining_formatted=$(format_time $remaining_time)

    printf "\r${BLUE}["
    for ((i=0; i<completed; i++)); do printf "█"; done
    for ((i=completed; i<width; i++)); do printf "░"; done
    printf "] %d%% (%d/%d) ${NC}" "$percentage" "$current" "$total"
    
    if [[ $current -gt 1 ]]; then
        printf " ${YELLOW}⏱️  Elapsed: %s | ETA: %s${NC}" "$elapsed_formatted" "$remaining_formatted"
    fi
}

# Format time function
format_time() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local hours=$((minutes / 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $((minutes % 60)) $((seconds % 60))
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $((seconds % 60))
    else
        printf "%ds" $seconds
    fi
}

# Step progress function with timing
next_step() {
    local step_end_time=$(date +%s)
    local step_duration=$((step_end_time - STEP_START_TIME))
    
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS
    
    if [[ $CURRENT_STEP -gt 1 ]]; then
        echo -e " ${GREEN}✓${NC} Step completed in $(format_time $step_duration)"
    else
        echo ""
    fi
    
    STEP_START_TIME=$(date +%s)
}

# Error handling function
handle_error() {
    local exit_code=$1
    local command="$2"
    local line_number=$3

    if [[ $exit_code -ne 0 ]]; then
        log "ERROR" "Command failed: '$command' (line $line_number, exit code: $exit_code)"
        echo -e "\n${RED}${BOLD}💥 An error occurred. The script cannot continue.${NC}"
        echo -e "${YELLOW}📋 Please check the log file for details: ${LOG_FILE}${NC}"
        
        # Generate partial summary before exiting
        echo -e "\n${BOLD}${YELLOW}📊 PARTIAL INSTALLATION SUMMARY:${NC}"
        if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
            echo -e "${GREEN}✅ Successfully installed: ${#INSTALLED_TOOLS[@]} items${NC}"
        fi
        if [[ ${#SKIPPED_TOOLS[@]} -gt 0 ]]; then
            echo -e "${YELLOW}⏭️  Skipped: ${#SKIPPED_TOOLS[@]} items${NC}"
        fi
        if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
            echo -e "${RED}❌ Failed: ${#FAILED_TOOLS[@]} items${NC}"
        fi
        
        echo -e "\n${CYAN}💡 You can re-run this script after fixing the issue.${NC}"
        echo -e "${CYAN}   The script will skip already installed components.${NC}"
        
        exit $exit_code
    fi
}

# Trap errors for better debugging
trap 'handle_error $? "$BASH_COMMAND" $LINENO' ERR

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

# Create backup directory
create_backup_dir() {
    log "INFO" "Creating backup directory at ${BACKUP_DIR}"
    mkdir -p "$BACKUP_DIR"
}

# Backup a file if it exists
backup_file() {
    if [[ -f "$1" ]]; then
        log "INFO" "Backing up $1 to ${BACKUP_DIR}/"
        cp "$1" "${BACKUP_DIR}/"
    fi
}

# Track installed tools
track_installed() {
    local tool="$1"
    INSTALLED_TOOLS+=("$tool")
    log "SUCCESS" "$tool has been installed successfully"
}

# Track skipped tools
track_skipped() {
    local tool="$1"
    SKIPPED_TOOLS+=("$tool")
    log "SKIP" "$tool is already installed"
}

# Track failed tools
track_failed() {
    local tool="$1"
    FAILED_TOOLS+=("$tool")
    log "ERROR" "$tool installation failed"
}

# Run command with enhanced feedback
run_with_feedback() {
    local command="$1"
    local description="$2"
    local log_level="${3:-INFO}"
    
    log "$log_level" "Running: $description"
    
    # Run command in background to show spinner
    eval "$command" &
    local pid=$!
    
    # Show spinner while command runs
    show_spinner "$pid" "$description"
    
    # Wait for command to complete and check exit code
    wait "$pid"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "SUCCESS" "$description completed successfully"
    else
        log "ERROR" "$description failed with exit code $exit_code"
        return $exit_code
    fi
}

# Enhanced DNF installation with progress
install_dnf_packages() {
    local packages=("$@")
    local description="Installing packages: ${packages[*]}"
    
    log "INSTALL" "$description"
    
    # Use dnf with progress output
    sudo dnf install -y "${packages[@]}" 2>&1 | while IFS= read -r line; do
        if [[ "$line" == *"Installing"* ]] || [[ "$line" == *"Downloading"* ]]; then
            printf "\r${CYAN}📦 $line${NC}"
        elif [[ "$line" == *"Complete!"* ]]; then
            printf "\r${GREEN}✅ Installation completed successfully${NC}\n"
        fi
    done
    
    return ${PIPESTATUS[0]}
}

# ============================================================================
# PRE-INSTALLATION CHECKS
# ============================================================================

check_requirements() {
    log "HEADER" "STEP 1/$TOTAL_STEPS: CHECKING SYSTEM REQUIREMENTS"

    # Detect WSL environment
    detect_wsl
    if [[ "$IS_WSL" == "true" ]]; then
        log "INFO" "WSL environment detected. Adjusting configuration for WSL compatibility."
        log "INFO" "WSL Distro: ${WSL_DISTRO_NAME:-Unknown}"
    fi

    # Check if running on Fedora
    if ! grep -q -i "fedora" /etc/os-release; then
        log "ERROR" "This script is designed for Fedora Linux."
        exit 1
    fi

    # Check Fedora version
    local fedora_version
    fedora_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2)
    if [[ "$fedora_version" != "42" ]]; then
        log "WARNING" "This script is optimized for Fedora 42. You are on version $fedora_version."
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
    fi

    # Check for KDE Plasma and Wayland (skip in WSL)
    if [[ "$IS_WSL" == "false" ]]; then
        if [[ "${XDG_CURRENT_DESKTOP:-}" != "KDE" ]] || [[ "${XDG_SESSION_TYPE:-}" != "wayland" ]]; then
            log "WARNING" "This script is optimized for KDE Plasma on Wayland."
            log "WARNING" "Current Desktop: ${XDG_CURRENT_DESKTOP:-Not Set}, Session: ${XDG_SESSION_TYPE:-Not Set}"
            if ! confirm "Some settings might not apply correctly. Continue?"; then
                exit 1
            fi
        fi
    else
        log "INFO" "Skipping desktop environment checks in WSL."
    fi

    # Check sudo privileges
    log "INFO" "Checking for sudo privileges..."
    if ! sudo -v; then
        log "ERROR" "Sudo privileges are required to run this script."
        exit 1
    fi

    # Check internet connection
    log "INFO" "Checking internet connection..."
    if ! ping -c 1 -W 3 google.com &>/dev/null; then
        log "ERROR" "No internet connection detected. Please connect to the internet and try again."
        exit 1
    fi

    log "SUCCESS" "System requirements check passed."
    
    # Configure WSL environment if detected
    configure_wsl_environment
    
    next_step
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

# 2. System Update
update_system() {
    log "HEADER" "STEP 2/$TOTAL_STEPS: SYSTEM UPDATE"
    log "INFO" "Checking for system updates..."
    
    # Check if updates are available
    local updates_available
    updates_available=$(sudo dnf check-update --quiet 2>/dev/null | wc -l)
    
    if [[ $updates_available -eq 0 ]]; then
        log "SUCCESS" "System is already up to date"
        track_skipped "System Updates"
    else
        log "INFO" "Found $updates_available package updates available"
        log "PROGRESS" "Updating and upgrading system packages. This may take a while..."
        
        if run_with_feedback "sudo dnf upgrade --refresh -y" "System package update" "INSTALL"; then
            track_installed "System Updates"
        else
            track_failed "System Updates"
        fi
    fi
    
    next_step
}

# 3. Essential Packages Installation
install_essential_packages() {
    log "HEADER" "STEP 3/$TOTAL_STEPS: ESSENTIAL PACKAGES"
    log "INFO" "Installing essential packages required for other installations..."
    
    # Essential packages that other installations depend on (Fedora-specific names)
    local essential_packages=(
        "curl"
        "wget"
        "git"
        "vim"
        "nano"
        "tree"
        "unzip"
        "zip"
        "tar"
        "gzip"
        "which"
        "ca-certificates"
        "gnupg2"
        "dnf-plugins-core"
        "gcc"
        "make"
        "kernel-devel"
        "kernel-headers"
    )
    
    # Package name mapping for alternatives
    declare -A package_alternatives=(
        ["wget"]="wget wget2"
        ["gnupg"]="gnupg2"
        ["gnupg2"]="gnupg2"
    )
    
    local packages_to_install=()
    local installed_count=0
    local failed_packages=()
    
    log "INFO" "Checking essential packages individually..."
    
    for package in "${essential_packages[@]}"; do
        # Check if package is already installed
        if rpm -q "$package" &>/dev/null; then
            track_skipped "$package"
            installed_count=$((installed_count + 1))
            continue
        fi
        
        # Check for alternative packages if the main one isn't found
        local found_alternative=false
        if [[ -n "${package_alternatives[$package]:-}" ]]; then
            for alt_package in ${package_alternatives[$package]}; do
                if rpm -q "$alt_package" &>/dev/null; then
                    track_skipped "$package (via $alt_package)"
                    found_alternative=true
                    installed_count=$((installed_count + 1))
                    break
                fi
            done
        fi
        
        if [[ "$found_alternative" == "false" ]]; then
            # Check if command exists (in case installed via different package name)
            local cmd_name="$package"
            if [[ "$package" == "gnupg2" ]]; then
                cmd_name="gpg"
            elif [[ "$package" == "ca-certificates" ]]; then
                # ca-certificates doesn't have a direct command, check for cert files
                if [[ -d "/etc/ssl/certs" && -n "$(ls -A /etc/ssl/certs 2>/dev/null)" ]]; then
                    track_skipped "$package"
                    installed_count=$((installed_count + 1))
                    continue
                fi
            fi
            
            if command_exists "$cmd_name"; then
                track_skipped "$package"
                installed_count=$((installed_count + 1))
            else
                packages_to_install+=("$package")
            fi
        fi
    done
    
    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        log "PROGRESS" "Installing ${#packages_to_install[@]} essential packages: ${packages_to_install[*]}"
        
        # Install packages individually for better error handling
        for package in "${packages_to_install[@]}"; do
            log "INSTALL" "Installing $package..."
            
            # Use --skip-unavailable and --best to handle package conflicts
            if sudo dnf install -y --skip-unavailable --best "$package" 2>/dev/null; then
                track_installed "$package"
            else
                # Try alternative installation methods for specific packages
                case "$package" in
                    "wget")
                        # Try wget2 as an alternative
                        if sudo dnf install -y --skip-unavailable wget2 2>/dev/null; then
                            track_installed "wget (via wget2)"
                        else
                            log "WARNING" "Failed to install wget, but it might already be available as wget2"
                            track_skipped "wget (system default)"
                        fi
                        ;;
                    "gnupg2")
                        # gnupg2 might already be installed as part of base system
                        if command_exists gpg; then
                            track_skipped "gnupg2 (system default)"
                        else
                            failed_packages+=("$package")
                            track_failed "$package"
                        fi
                        ;;
                    "ca-certificates")
                        # ca-certificates might be part of base system
                        if [[ -d "/etc/ssl/certs" ]]; then
                            track_skipped "ca-certificates (system default)"
                        else
                            failed_packages+=("$package")
                            track_failed "$package"
                        fi
                        ;;
                    *)
                        failed_packages+=("$package")
                        track_failed "$package"
                        ;;
                esac
            fi
        done
        
        if [[ ${#failed_packages[@]} -eq 0 ]]; then
            log "SUCCESS" "All essential packages installed successfully"
        else
            log "WARNING" "Some packages failed to install: ${failed_packages[*]}"
            log "INFO" "This might not affect the overall installation"
        fi
    else
        log "SUCCESS" "All essential packages are already available"
        track_skipped "Essential Packages (All available)"
    fi
    
    log "INFO" "Essential packages summary: $installed_count already available, ${#packages_to_install[@]} needed installation"
    next_step
}

# 4. NVIDIA Graphics Driver
install_nvidia_driver() {
    log "HEADER" "STEP 4/$TOTAL_STEPS: NVIDIA GRAPHICS DRIVER"

    # Skip NVIDIA drivers in WSL
    if [[ "$IS_WSL" == "true" ]]; then
        log "INFO" "Skipping NVIDIA driver installation in WSL environment."
        next_step
        return
    fi

    if ! lspci | grep -iq 'VGA.*NVIDIA'; then
        log "INFO" "No NVIDIA GPU detected. Skipping this step."
        track_skipped "NVIDIA Drivers (No GPU)"
        next_step
        return
    fi

    if command_exists nvidia-smi; then
        log "SUCCESS" "NVIDIA drivers are already installed. Skipping."
        track_skipped "NVIDIA Drivers"
        next_step
        return
    fi

    if confirm "NVIDIA GPU detected. Do you want to install the proprietary drivers?"; then
        log "INFO" "Adding RPM Fusion repositories (free and non-free)."
        sudo dnf install -y \
            "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

        log "INFO" "Installing NVIDIA drivers. This will take some time..."
        sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

        log "SUCCESS" "NVIDIA driver installation initiated."
        log "WARNING" "A system reboot is REQUIRED to complete the installation."
        log "WARNING" "After rebooting, please run this script again to continue."

        if confirm "Reboot now?"; then
            sudo reboot
        else
            log "INFO" "Please reboot manually and re-run this script to continue."
            exit 0
        fi
    else
        log "INFO" "Skipping NVIDIA driver installation."
        next_step
    fi
}

# 5. ZSH, Oh My ZSH, and Plugins
install_zsh_ohmyzsh() {
    log "HEADER" "STEP 5/$TOTAL_STEPS: ZSH & OH MY ZSH"

    log "INFO" "Installing ZSH..."
    sudo dnf install -y zsh

    if [[ "$SHELL" != "/bin/zsh" ]] && [[ "$SHELL" != "/usr/bin/zsh" ]]; then
        log "INFO" "Changing default shell to ZSH for user $USER."
        sudo chsh -s "$(which zsh)" "$USER"
        log "WARNING" "You will need to log out and log back in for the shell change to take effect."
    else
        log "INFO" "ZSH is already the default shell."
    fi

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log "INFO" "Oh My Zsh is already installed. Skipping."
    else
        log "INFO" "Installing Oh My Zsh..."
        # The --unattended flag will not change the default shell or run zsh.
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    log "INFO" "Installing Oh My ZSH plugins..."
    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" || true
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" || true
    git clone --depth=1 https://github.com/zsh-users/zsh-completions "${ZSH_CUSTOM}/plugins/zsh-completions" || true
    git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search "${ZSH_CUSTOM}/plugins/zsh-history-substring-search" || true
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab "${ZSH_CUSTOM}/plugins/fzf-tab" || true

    log "INFO" "Configuring .zshrc..."
    backup_file "$HOME/.zshrc"

    # Create completion directories
    mkdir -p "$HOME/.zfunc"
    mkdir -p "$HOME/.zsh/cache"

    cat > "$HOME/.zshrc" << 'EOF'
# =============================================================================
# ZSH Configuration for Modern Development Environment
# Generated by Fedora Setup Script
# =============================================================================

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load.
# Note: Starship will override this if installed
ZSH_THEME="robbyrussell"

# List of plugins to load.
plugins=(
    git
    sudo
    history
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    zsh-history-substring-search
    fzf-tab
    docker
    rust
    golang
    python
)

source "$ZSH/oh-my-zsh.sh"

# =============================================================================
# USER CONFIGURATION
# =============================================================================

# Set preferred editor
export EDITOR='code'
export VISUAL='code'
export LANG=en_US.UTF-8

# =============================================================================
# PATH CONFIGURATION
# =============================================================================

# Ensure local bin directories are in PATH
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# Rust/Cargo Path
export PATH="$HOME/.cargo/bin:$PATH"

# GoLang Path
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"

# Poetry
export PATH="$HOME/.local/bin:$PATH"

# uv (Python package installer)
export PATH="$HOME/.local/bin:$PATH"

# =============================================================================
# DEVELOPMENT TOOLS INITIALIZATION
# =============================================================================

# Starship Prompt (Modern prompt)
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# Zoxide (Smarter cd with frecency)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Pyenv (Python version manager)
if command -v pyenv &> /dev/null; then
    eval "$(pyenv init -)"
fi

# Poetry (Python dependency manager)
if command -v poetry &> /dev/null; then
    poetry completions zsh > ~/.zfunc/_poetry
    fpath+=~/.zfunc
fi

# Atuin (Shell history replacement)
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi

# FZF (Fuzzy finder)
if command -v fzf &> /dev/null; then
    eval "$(fzf --zsh)"
fi

# GitHub CLI (gh)
if command -v gh &> /dev/null; then
    eval "$(gh completion -s zsh)"
fi

# Docker completion
if command -v docker &> /dev/null; then
    # Docker completion is usually provided by Oh My ZSH docker plugin
    # But we can add manual completion if needed
    autoload -U +X bashcompinit && bashcompinit
    if [[ -f /usr/share/bash-completion/completions/docker ]]; then
        source /usr/share/bash-completion/completions/docker
    fi
fi

# Podman completion
if command -v podman &> /dev/null; then
    autoload -U +X bashcompinit && bashcompinit
    if [[ -f /usr/share/bash-completion/completions/podman ]]; then
        source /usr/share/bash-completion/completions/podman
    fi
fi

# Rust tools completion
if command -v rustup &> /dev/null; then
    # Rustup completion
    mkdir -p ~/.zfunc
    rustup completions zsh > ~/.zfunc/_rustup
    fpath+=~/.zfunc
fi

if command -v cargo &> /dev/null; then
    # Cargo completion
    mkdir -p ~/.zfunc
    rustup completions zsh cargo > ~/.zfunc/_cargo
    fpath+=~/.zfunc
fi

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================

# History configuration
HISTSIZE=50000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS

# Directory options
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_MINUS

# Key bindings for history substring search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Additional key bindings
bindkey '^P' history-search-backward
bindkey '^N' history-search-forward

# =============================================================================
# CUSTOM ALIASES AND FUNCTIONS
# =============================================================================

# Load custom aliases from a separate file for better organization.
if [[ -f ~/.aliases ]]; then
    source ~/.aliases
fi

# =============================================================================
# COMPLETION SYSTEM
# =============================================================================

# Initialize completions
autoload -U compinit
compinit

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Completion caching
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# Better completion for processes
zstyle ':completion:*:processes' command 'ps -u $USER -o pid,user,comm -w -w'

# Completion colors
zstyle ':completion:*' list-colors ''

# =============================================================================
# WSL SPECIFIC CONFIGURATION
# =============================================================================

# WSL Display Configuration (if in WSL)
if [[ -n "${WSL_DISTRO_NAME}" ]]; then
    export DISPLAY=$(ip route show | grep -i default | awk '{ print $3}'):0.0
    export LIBGL_ALWAYS_INDIRECT=1
fi

# =============================================================================
# FINAL SETUP
# =============================================================================

# Ensure completion functions are loaded
autoload -U +X bashcompinit && bashcompinit

# Source local configuration if it exists
if [[ -f ~/.zshrc.local ]]; then
    source ~/.zshrc.local
fi

# Welcome message (only for interactive shells)
if [[ $- == *i* ]]; then
    echo "🚀 Development environment loaded successfully!"
    echo "✨ Run 'alias' to see available shortcuts"
    echo "📚 Run 'tldr <command>' for quick help"
fi
EOF

    log "SUCCESS" "ZSH, Oh My ZSH, and plugins installed and configured."
    next_step
}

# 6. Starship Terminal Prompt
install_starship() {
    log "HEADER" "STEP 6/$TOTAL_STEPS: STARSHIP TERMINAL PROMPT"

    if command_exists starship; then
        log "INFO" "Starship is already installed. Skipping."
    else
        log "INFO" "Installing Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi

    log "INFO" "Creating Starship configuration..."
    mkdir -p "$HOME/.config"
    backup_file "$HOME/.config/starship.toml"
    cat > "$HOME/.config/starship.toml" << 'EOF'
# Get editor completions based on the config schema
"$schema" = 'https://starship.rs/config-schema.json'

format = """
[](#9A348E)\
$os\
$username\
[](bg:#DA627D fg:#9A348E)\
$directory\
[](fg:#DA627D bg:#FCA17D)\
$git_branch\
$git_status\
[](fg:#FCA17D bg:#86BBD8)\
$c\
$rust\
$golang\
$python\
[](fg:#86BBD8 bg:#06969A)\
$docker_context\
[](fg:#06969A bg:#33658A)\
$time\
[ ](fg:#33658A)\
$line_break$character"""

[os]
style = "bg:#9A348E"
disabled = false
format = '[ $symbol ]($style)'

[os.symbols]
Fedora = ""
Windows = "󰍲"
Macos = "󰀵"
Linux = "󰌽"

[username]
show_always = true
style_user = "bg:#9A348E"
style_root = "bg:#9A348E"
format = '[$user]($style)'

[directory]
style = "bg:#DA627D"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[git_branch]
symbol = ""
style = "bg:#FCA17D"
format = '[[ $symbol $branch ](fg:#090c0c bg:#FCA17D)]($style)'

[git_status]
style = "bg:#FCA17D"
format = '[[($all_status$ahead_behind )](fg:#090c0c bg:#FCA17D)]($style)'

[c]
symbol = " "
style = "bg:#86BBD8"
format = '[[ $symbol ($version) ](fg:#090c0c bg:#86BBD8)]($style)'

[rust]
symbol = ""
style = "bg:#86BBD8"
format = '[[ $symbol ($version) ](fg:#090c0c bg:#86BBD8)]($style)'

[golang]
symbol = ""
style = "bg:#86BBD8"
format = '[[ $symbol ($version) ](fg:#090c0c bg:#86BBD8)]($style)'

[python]
symbol = ""
style = "bg:#86BBD8"
format = '[[ $symbol ($version) ](fg:#090c0c bg:#86BBD8)]($style)'

[docker_context]
symbol = ""
style = "bg:#06969A"
format = '[[ $symbol $context ](fg:#090c0c bg:#06969A)]($style)'

[time]
disabled = false
time_format = "%R"
style = "bg:#33658A"
format = '[[  $time ](fg:#fcfcfc bg:#33658A)]($style)'

[line_break]
disabled = false

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[➜](bold red)"
vimcmd_symbol = "[❮](bold green)"
EOF

    log "SUCCESS" "Starship installed and configured."
    next_step
}

# 7. Python Development (Pyenv, Poetry, uv)
install_python_tools() {
    log "HEADER" "STEP 7/$TOTAL_STEPS: PYTHON DEVELOPMENT TOOLS"

    log "INFO" "Installing Python build dependencies..."
    sudo dnf install -y gcc make patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel

    log "INFO" "Installing pyenv..."
    if [[ ! -d "$HOME/.pyenv" ]]; then
        curl -fsSL https://pyenv.run | bash
    else
        log "INFO" "pyenv already installed. Skipping."
    fi

    # Set up pyenv environment for this script session
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"

    log "INFO" "Installing latest stable Python version with pyenv. This might take a while..."
    local latest_python
    latest_python=$(pyenv install --list | grep -v - | grep -v b | grep -v rc | grep -E "^\s*3\.[0-9]+\.[0-9]+$" | tail -1 | xargs)
    if pyenv versions --bare | grep -q "^${latest_python}$"; then
        log "INFO" "Python ${latest_python} is already installed."
    else
        pyenv install "$latest_python"
    fi
    pyenv global "$latest_python"

    log "INFO" "Installing Poetry (package manager)..."
    if ! command_exists poetry; then
        curl -sSL https://install.python-poetry.org | python3 -
    else
        log "INFO" "Poetry already installed. Skipping."
    fi

    log "INFO" "Installing uv (fast package installer)..."
    if ! command_exists uv; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    else
        log "INFO" "uv already installed. Skipping."
    fi

    log "SUCCESS" "Python development tools installed."
    next_step
}

# 8. Rust Development Environment
install_rust() {
    log "HEADER" "STEP 8/$TOTAL_STEPS: RUST DEVELOPMENT ENVIRONMENT"

    if command_exists rustc; then
        log "INFO" "Rust is already installed. Updating..."
        rustup update
    else
        log "INFO" "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi

    # Source Rust environment for the current session
    source "$HOME/.cargo/env"

    log "INFO" "Installing essential Rust components..."
    rustup component add rustfmt clippy rust-analyzer

    log "SUCCESS" "Rust development environment is ready."
    next_step
}

# 9. Go Development Environment
install_golang() {
    log "HEADER" "STEP 9/$TOTAL_STEPS: GO DEVELOPMENT ENVIRONMENT"

    if command_exists go; then
        log "INFO" "Go is already installed. Skipping."
    else
        log "INFO" "Installing Go..."
        sudo dnf install -y golang
    fi

    log "INFO" "Setting up Go workspace directory..."
    mkdir -p "$HOME/go"

    log "SUCCESS" "Go development environment installed."
    next_step
}

# 10. C++ Development Environment
install_cpp_tools() {
    log "HEADER" "STEP 10/$TOTAL_STEPS: C++ DEVELOPMENT ENVIRONMENT"

    # Check if key C++ tools are already installed
    local tools_to_check=(
        "cmake"
        "gdb"
        "valgrind"
        "clang"
        "lldb"
        "gcc"
        "g++"
    )

    local missing_tools=()
    for tool in "${tools_to_check[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        else
            track_skipped "$tool"
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log "PROGRESS" "Installing C++ build essentials and tools. Missing: ${missing_tools[*]}"
        if run_with_feedback "sudo dnf group install -y kde-software-development c-development" "C++ development groups" "INSTALL" &&
           run_with_feedback "sudo dnf install -y cmake gdb valgrind clang lldb" "C++ development tools" "INSTALL"; then
            for tool in "${missing_tools[@]}"; do
                track_installed "$tool"
            done
        else
            for tool in "${missing_tools[@]}"; do
                track_failed "$tool"
            done
        fi
    else
        log "SUCCESS" "All C++ development tools are already installed. Skipping."
        track_skipped "C++ Development Environment"
    fi

    next_step
}

# 11. Modern Tools via DNF
install_modern_tools_dnf() {
    log "HEADER" "STEP 11/$TOTAL_STEPS: MODERN TOOLS (DNF)"

    local tools=(
        atuin
        ripgrep
        bat
        fd-find
        duf
        jq
        fzf
        htop
    )

    # Check which tools are already installed
    local tools_to_install=()
    for tool in "${tools[@]}"; do
        # Check if package is already installed
        if rpm -q "$tool" &>/dev/null; then
            track_skipped "$tool"
        else
            # For some tools, check if command exists (in case installed differently)
            local cmd_name="$tool"
            if [[ "$tool" == "fd-find" ]]; then
                cmd_name="fd"
            elif [[ "$tool" == "ripgrep" ]]; then
                cmd_name="rg"
            fi
            
            if command_exists "$cmd_name"; then
                track_skipped "$tool ($cmd_name)"
            else
                tools_to_install+=("$tool")
            fi
        fi
    done

    if [[ ${#tools_to_install[@]} -gt 0 ]]; then
        log "PROGRESS" "Installing ${#tools_to_install[@]} modern CLI tools via DNF: ${tools_to_install[*]}"
        if run_with_feedback "sudo dnf install -y ${tools_to_install[*]}" "Modern CLI tools installation" "INSTALL"; then
            for tool in "${tools_to_install[@]}"; do
                track_installed "$tool"
            done
        else
            for tool in "${tools_to_install[@]}"; do
                track_failed "$tool"
            done
        fi
    else
        log "SUCCESS" "All modern CLI tools are already installed. Skipping."
        track_skipped "Modern CLI Tools (DNF)"
    fi

    next_step
}

# 12. Modern Tools via Cargo
install_modern_tools_cargo() {
    log "HEADER" "STEP 12/$TOTAL_STEPS: MODERN TOOLS (CARGO)"

    # Ensure cargo is available
    source "$HOME/.cargo/env"

    local tools=(
        eza
        zoxide
        du-dust
        broot
        sd
        hexyl
        git-delta
        bottom
        procs
        gping
        hyperfine
        tealdeer
    )

    log "PROGRESS" "Installing modern CLI tools via Cargo..."
    local installed_count=0
    local skipped_count=0
    
    for tool in "${tools[@]}"; do
        if ! command_exists "$tool"; then
            log "INSTALL" "Installing $tool via Cargo..."
            if cargo install "$tool" &>/dev/null; then
                track_installed "$tool"
                installed_count=$((installed_count + 1))
            else
                track_failed "$tool"
            fi
        else
            track_skipped "$tool"
            skipped_count=$((skipped_count + 1))
        fi
    done

    if [[ $installed_count -gt 0 ]]; then
        log "SUCCESS" "Installed $installed_count modern CLI tools via Cargo"
    fi
    
    if [[ $skipped_count -gt 0 ]]; then
        log "INFO" "Skipped $skipped_count tools already installed"
    fi
    next_step
}

# 13. Container Tools (Docker, Podman)
install_container_tools() {
    log "HEADER" "STEP 13/$TOTAL_STEPS: CONTAINER TOOLS"

    # Check if Docker and Podman are already installed
    local docker_installed=false
    local podman_installed=false
    
    if command_exists docker; then
        docker_installed=true
        track_skipped "Docker"
    fi
    
    if command_exists podman; then
        podman_installed=true
        track_skipped "Podman"
    fi

    # WSL-specific container setup - Skip Docker, install only Podman
    if [[ "$IS_WSL" == "true" ]]; then
        log "INFO" "WSL environment detected. Configuring container tools for WSL..."
        
        echo -e "\n${BOLD}${YELLOW}📋 WSL Container Strategy:${NC}"
        echo -e "   ${YELLOW}•${NC} ${BOLD}Docker:${NC} Automatically skipped in WSL"
        echo -e "   ${YELLOW}•${NC} ${BOLD}Podman:${NC} Installing lightweight container engine"
        echo -e "   ${CYAN}•${NC} ${BOLD}Recommendation:${NC} Use Docker Desktop for Windows for full Docker support"
        echo ""
        
        # Automatically skip Docker installation in WSL
        if [[ "$docker_installed" == "false" ]]; then
            log "INFO" "Skipping Docker installation in WSL environment"
            log "INFO" "Docker Desktop for Windows is the recommended solution for WSL"
            log "INFO" "Benefits of Docker Desktop:"
            log "INFO" "  • Seamless Windows-WSL integration"
            log "INFO" "  • Automatic daemon management"
            log "INFO" "  • GUI management interface"
            log "INFO" "  • Better resource management"
            track_skipped "Docker (WSL - Use Docker Desktop for Windows)"
        fi
        
        # Install Podman if not present
        if [[ "$podman_installed" == "false" ]]; then
            if confirm "Install Podman (lightweight container engine)?"; then
                log "PROGRESS" "Installing Podman for WSL..."
                                 if run_with_feedback "sudo dnf install -y podman podman-compose" "Podman installation" "INSTALL"; then
                     track_installed "Podman"
                     track_installed "Podman Compose"
                     
                     log "SUCCESS" "Podman installed successfully"
                     log "INFO" "Podman works great in WSL for lightweight containerization"
                     log "INFO" "Use 'podman' commands just like Docker: podman run, podman build, etc."
                 else
                     track_failed "Podman"
                 fi
             else
                 track_skipped "Podman (User declined)"
             fi
        fi
        
        echo -e "\n${BOLD}${CYAN}💡 Container Usage in WSL:${NC}"
        echo -e "   ${GREEN}•${NC} For Docker: Install Docker Desktop for Windows"
        echo -e "   ${GREEN}•${NC} For Podman: Use installed Podman directly"
        echo -e "   ${GREEN}•${NC} Both tools share similar command syntax"
        echo ""
        
    else
        # Regular Linux installation - Ask user for both Docker and Podman
        if [[ "$docker_installed" == "true" && "$podman_installed" == "true" ]]; then
            log "SUCCESS" "Both Docker and Podman are already installed. Skipping."
                         track_skipped "Container Tools (All installed)"
             next_step
             return
         fi

                 if ! confirm "Install container tools (Docker and Podman)?"; then
             log "INFO" "Skipping container tools installation."
             track_skipped "Container Tools (User declined)"
             next_step
             return
         fi

         # Install Podman (Fedora's native container engine)
         if [[ "$podman_installed" == "false" ]]; then
             log "PROGRESS" "Installing Podman (Fedora's native container engine)..."
             if run_with_feedback "sudo dnf install -y podman podman-compose" "Podman installation" "INSTALL"; then
                 track_installed "Podman"
                 track_installed "Podman Compose"
             else
                 track_failed "Podman"
             fi
         fi

        # Install Docker
        if [[ "$docker_installed" == "false" ]]; then
            log "PROGRESS" "Installing Docker..."
            if run_with_feedback "sudo dnf install -y dnf-plugins-core" "Docker prerequisites" "INSTALL" &&
               run_with_feedback "sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo" "Docker repository setup" "INSTALL" &&
               run_with_feedback "sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" "Docker installation" "INSTALL"; then
                
                log "INFO" "Starting and enabling Docker service..."
                if run_with_feedback "sudo systemctl start docker && sudo systemctl enable docker" "Docker service setup" "INSTALL"; then
                    log "INFO" "Adding current user ($USER) to the 'docker' group..."
                    sudo usermod -aG docker "$USER"
                    
                                         track_installed "Docker Engine"
                     track_installed "Docker Compose"
                     track_installed "Docker Buildx"
                     
                     log "WARNING" "You must log out and log back in for Docker group changes to take effect."
                 else
                     track_failed "Docker Service Setup"
                 fi
             else
                 track_failed "Docker Installation"
             fi
        fi
    fi

    log "SUCCESS" "Container tools setup completed."
    next_step
}

# 14. Fonts Installation (FiraCode and JetBrains Mono Nerd Fonts)
install_fonts() {
    log "HEADER" "STEP 14/$TOTAL_STEPS: NERD FONTS INSTALLATION"

    local font_dir="$HOME/.local/share/fonts"
    log "INFO" "Creating fonts directory at $font_dir"
    mkdir -p "$font_dir"

    # Enhanced font checking with multiple patterns
    local firacode_installed=false
    local jetbrains_installed=false
    
    log "INFO" "Checking for existing font installations..."
    
    # Check for FiraCode Nerd Font with multiple patterns
    if fc-list | grep -qi "FiraCode.*Nerd" || \
       fc-list | grep -qi "FiraCode.*NF" || \
       fc-list | grep -qi "FiraCodeNerdFont" || \
       ls "$font_dir" | grep -qi "FiraCode.*Nerd" 2>/dev/null; then
        firacode_installed=true
        track_skipped "FiraCode Nerd Font"
    fi
    
    # Check for JetBrainsMono Nerd Font with multiple patterns
    if fc-list | grep -qi "JetBrainsMono.*Nerd" || \
       fc-list | grep -qi "JetBrainsMono.*NF" || \
       fc-list | grep -qi "JetBrainsMonoNerdFont" || \
       ls "$font_dir" | grep -qi "JetBrainsMono.*Nerd" 2>/dev/null; then
        jetbrains_installed=true
        track_skipped "JetBrainsMono Nerd Font"
    fi

    # If both fonts are already installed, skip entirely
    if [[ "$firacode_installed" == "true" && "$jetbrains_installed" == "true" ]]; then
        log "SUCCESS" "Both FiraCode and JetBrainsMono Nerd Fonts are already installed. Skipping."
        track_skipped "Nerd Fonts Installation"
        next_step
        return
    fi

    # Create temporary directory for downloads
    local tmp_dir
    tmp_dir=$(mktemp -d)
    log "INFO" "Created temporary directory: $tmp_dir"

    # Track what needs to be installed
    local fonts_to_install=()
    local installed_fonts=()
    local failed_fonts=()

    # Install FiraCode Nerd Font if not present
    if [[ "$firacode_installed" == "false" ]]; then
        fonts_to_install+=("FiraCode")
        log "PROGRESS" "Downloading FiraCode Nerd Font..."
        
        if wget -q --show-progress -P "$tmp_dir" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip; then
            log "SUCCESS" "FiraCode Nerd Font downloaded successfully"
            
            log "INSTALL" "Extracting FiraCode Nerd Font..."
            if unzip -o "$tmp_dir/FiraCode.zip" -d "$font_dir" >/dev/null 2>&1; then
                log "SUCCESS" "FiraCode Nerd Font extracted successfully"
                installed_fonts+=("FiraCode Nerd Font")
                track_installed "FiraCode Nerd Font"
            else
                log "ERROR" "Failed to extract FiraCode Nerd Font"
                failed_fonts+=("FiraCode Nerd Font")
                track_failed "FiraCode Nerd Font"
            fi
            
            # Clean up the specific zip file
            log "INFO" "Removing FiraCode.zip..."
            rm -f "$tmp_dir/FiraCode.zip"
        else
            log "ERROR" "Failed to download FiraCode Nerd Font"
            failed_fonts+=("FiraCode Nerd Font")
            track_failed "FiraCode Nerd Font"
        fi
    fi

    # Install JetBrainsMono Nerd Font if not present
    if [[ "$jetbrains_installed" == "false" ]]; then
        fonts_to_install+=("JetBrainsMono")
        log "PROGRESS" "Downloading JetBrainsMono Nerd Font..."
        
        if wget -q --show-progress -P "$tmp_dir" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip; then
            log "SUCCESS" "JetBrainsMono Nerd Font downloaded successfully"
            
            log "INSTALL" "Extracting JetBrainsMono Nerd Font..."
            if unzip -o "$tmp_dir/JetBrainsMono.zip" -d "$font_dir" >/dev/null 2>&1; then
                log "SUCCESS" "JetBrainsMono Nerd Font extracted successfully"
                installed_fonts+=("JetBrainsMono Nerd Font")
                track_installed "JetBrainsMono Nerd Font"
            else
                log "ERROR" "Failed to extract JetBrainsMono Nerd Font"
                failed_fonts+=("JetBrainsMono Nerd Font")
                track_failed "JetBrainsMono Nerd Font"
            fi
            
            # Clean up the specific zip file
            log "INFO" "Removing JetBrainsMono.zip..."
            rm -f "$tmp_dir/JetBrainsMono.zip"
        else
            log "ERROR" "Failed to download JetBrainsMono Nerd Font"
            failed_fonts+=("JetBrainsMono Nerd Font")
            track_failed "JetBrainsMono Nerd Font"
        fi
    fi

    # Final cleanup - remove temporary directory and any remaining files
    log "INFO" "Cleaning up temporary files and directories..."
    rm -rf "$tmp_dir"

    # Update font cache only if fonts were installed
    if [[ ${#installed_fonts[@]} -gt 0 ]]; then
        log "PROGRESS" "Updating font cache..."
        if fc-cache -fv >/dev/null 2>&1; then
            log "SUCCESS" "Font cache updated successfully"
            track_installed "Font Cache Update"
        else
            log "WARNING" "Font cache update failed, but fonts should still work"
            track_failed "Font Cache Update"
        fi
    fi

    # Summary of font installation
    if [[ ${#installed_fonts[@]} -gt 0 ]]; then
        log "SUCCESS" "Successfully installed ${#installed_fonts[@]} font(s): ${installed_fonts[*]}"
        log "INFO" "You may need to set the font in your terminal emulator's settings."
        log "INFO" "Recommended: FiraCode Nerd Font or JetBrainsMono Nerd Font"
    fi

    if [[ ${#failed_fonts[@]} -gt 0 ]]; then
        log "WARNING" "Failed to install ${#failed_fonts[@]} font(s): ${failed_fonts[*]}"
        log "INFO" "You can manually install these fonts later from: https://github.com/ryanoasis/nerd-fonts"
    fi

    next_step
}

# 15. Development IDEs and Editors
install_development_ides() {
    log "HEADER" "STEP 15/$TOTAL_STEPS: DEVELOPMENT IDEs & EDITORS"

    # VSCode Installation
    local vscode_installed=false
    if command_exists code; then
        vscode_installed=true
        track_skipped "Visual Studio Code"
    fi

    if [[ "$vscode_installed" == "false" ]]; then
        if confirm "Install Visual Studio Code?"; then
            log "PROGRESS" "Installing Visual Studio Code..."
            
            # Add Microsoft's official repository
            log "INFO" "Adding Microsoft's GPG key and repository..."
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            
            # Create repository file
            cat > /tmp/vscode.repo << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
            sudo mv /tmp/vscode.repo /etc/yum.repos.d/vscode.repo
            
            # Install VSCode
            if run_with_feedback "sudo dnf install -y code" "VSCode installation" "INSTALL"; then
                track_installed "Visual Studio Code"
                
                log "INFO" "Installing useful VSCode extensions..."
                # Install essential extensions
                if command_exists code; then
                    local extensions=(
                        "ms-python.python"
                        "rust-lang.rust-analyzer"
                        "golang.go"
                        "ms-vscode.cpptools"
                        "bradlc.vscode-tailwindcss"
                        "esbenp.prettier-vscode"
                        "ms-vscode.vscode-json"
                        "redhat.vscode-yaml"
                        "ms-vscode-remote.remote-containers"
                        "GitHub.copilot"
                    )
                    
                    for extension in "${extensions[@]}"; do
                        log "INFO" "Installing VSCode extension: $extension"
                        code --install-extension "$extension" --force >/dev/null 2>&1 || true
                    done
                    
                    track_installed "VSCode Extensions"
                fi
            else
                track_failed "Visual Studio Code"
            fi
        else
            track_skipped "Visual Studio Code (User declined)"
        fi
    fi
    
    # Alternative IDEs information
    echo -e "\n${BOLD}${CYAN}💡 Other IDEs Available:${NC}"
    echo -e "   ${GREEN}•${NC} JetBrains IDEs: Install via Toolbox or Flatpak"
    echo -e "   ${GREEN}•${NC} Neovim: Advanced text editor (run 'sudo dnf install neovim')"
    echo -e "   ${GREEN}•${NC} Emacs: Extensible text editor (run 'sudo dnf install emacs')"
    echo -e "   ${GREEN}•${NC} Qt Creator: For Qt/C++ development"
    echo -e "   ${GREEN}•${NC} KDevelop: KDE's integrated development environment"
    echo ""
    
    next_step
}

# 16. GitHub CLI Installation
install_github_cli() {
    log "HEADER" "STEP 16/$TOTAL_STEPS: GITHUB CLI INSTALLATION"

    if command_exists gh; then
        track_skipped "GitHub CLI"
    else
        log "PROGRESS" "Installing GitHub CLI..."
        if run_with_feedback "sudo dnf install -y gh" "GitHub CLI installation" "INSTALL"; then
            track_installed "GitHub CLI"
        else
            track_failed "GitHub CLI"
        fi
    fi

    next_step
}

# 17. Create Comprehensive Aliases File
create_aliases() {
    log "HEADER" "STEP 17/$TOTAL_STEPS: CREATING ALIASES FILE"

    log "INFO" "Creating comprehensive aliases file at ~/.aliases..."
    backup_file "$HOME/.aliases"
    cat > "$HOME/.aliases" << 'EOF'
# ============================================================================
# Comprehensive Aliases for a Modern Development Environment
# Source this file from your .zshrc: `source ~/.aliases`
# ============================================================================

# --- Navigation & File Management ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ls='exa --icons'
alias ll='exa -l --icons'
alias la='exa -la --icons'
alias llt='exa -l --icons --sort=modified'
alias tree='exa --tree'
alias cat='bat --paging=never'
alias find='fd'
alias grep='rg'
alias hg='history | rg'
alias top='btm'
alias du='dust'
alias df='duf'
alias ps='procs'
alias ping='gping'
alias z='zoxide init zsh' # zoxide is handled by .zshrc eval

# --- System & Package Management ---
alias update='sudo dnf upgrade --refresh -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'
alias search='dnf search'

# --- Git ---
alias g='git'
alias gs='git status -s'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit -m'
alias gca='git commit --amend --no-edit'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpl='git pull'
alias gd='git-delta' # Use delta for diffs
alias gl='git log --oneline --graph --decorate'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gbr='git branch'
alias gcl='git clone'
alias gsta='git stash'
alias gstp='git stash pop'
alias lg='lazygit'

# --- Docker & Podman ---
# Use 'd' for Docker, 'p' for Podman
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dlogs='docker logs -f'
alias dexec='docker exec -it'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
alias pps='podman ps'
alias ppsa='podman ps -a'
alias pi='podman images'

# --- Python ---
alias py='python'
alias po='poetry'
alias poa='poetry add'
alias por='poetry remove'
alias poi='poetry install'
alias pou='poetry update'
alias porun='poetry run'
alias poshell='poetry shell'
alias uv='uv'
alias uvi='uv pip install'
alias uvr='uv pip install -r requirements.txt'

# --- Rust ---
alias cc='cargo check'
alias cb='cargo build'
alias cbr='cargo build --release'
alias cr='cargo run'
alias ct='cargo test'
alias cl='cargo clippy'
alias cfmt='cargo fmt'

# --- Go ---
alias gr='go run'
alias gb='go build'
alias gt='go test ./...'
alias gti='go mod tidy'

# --- Modern CLI Tools ---
# Better alternatives to traditional commands
alias cat='bat --paging=never'
alias catp='bat'  # bat with paging
alias find='fd'
alias grep='rg'
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias lt='eza --tree --icons'
alias cd='z'  # Use zoxide for smarter cd
alias zi='zoxide init zsh'
alias top='btm'
alias htop='btm'
alias ps='procs'
alias du='dust'
alias df='duf'
alias ping='gping'
alias man='tldr'  # Quick help with tealdeer

# --- FZF aliases ---
alias fzf-preview='fzf --preview "bat --style=numbers --color=always {}"'
alias fzf-cd='cd $(fd --type d | fzf)'
alias fzf-edit='$EDITOR $(fd --type f | fzf)'

# --- Git Delta ---
alias gdiff='git diff | delta'
alias glog='git log --oneline | delta'

# --- Atuin (shell history) ---
alias h='atuin search'
alias hi='atuin search -i'

# --- Container Tools ---
alias d='docker'
alias dc='docker-compose'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
alias dclogs='docker-compose logs -f'
alias dexec='docker exec -it'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias p='podman'
alias pps='podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# --- Other Utilities ---
# Start a simple web server in the current directory
serve() {
    python3 -m http.server "${1:-8000}"
}

# Create a directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Backup a file
bak() {
    cp -a "$1" "$1.bak"
}

# Get public IP
myip() {
    curl ifconfig.me
}

# Quick file find and edit
fe() {
    local file
    file=$(fd --type f | fzf --preview "bat --style=numbers --color=always {}") && $EDITOR "$file"
}

# Quick directory navigation
fcd() {
    local dir
    dir=$(fd --type d | fzf) && cd "$dir"
}

# Git fuzzy checkout
fco() {
    git branch --all | grep -v HEAD | fzf | sed 's/^..//' | xargs git checkout
}

# Process fuzzy kill
fkill() {
    local pid
    pid=$(procs | fzf --header-lines=1 | awk '{print $1}')
    if [ -n "$pid" ]; then
        kill -9 "$pid"
    fi
}

# Docker fuzzy container management
fdc() {
    local container
    container=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | fzf --header-lines=1 | awk '{print $1}')
    if [ -n "$container" ]; then
        docker exec -it "$container" /bin/bash
    fi
}
EOF

    log "SUCCESS" "Comprehensive aliases file created at ~/.aliases."
    next_step
}

# Generate installation summary
generate_installation_summary() {
    local total_time=$(($(date +%s) - INSTALL_START_TIME))
    
    echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                           📊 INSTALLATION SUMMARY REPORT                             ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BOLD}${WHITE}⏱️  Total Installation Time: ${GREEN}$(format_time $total_time)${NC}\n"
    
    # Show installed tools
    if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${BOLD}${GREEN}✅ SUCCESSFULLY INSTALLED (${#INSTALLED_TOOLS[@]} items):${NC}"
        for tool in "${INSTALLED_TOOLS[@]}"; do
            echo -e "   ${GREEN}•${NC} $tool"
        done
        echo ""
    fi
    
    # Show skipped tools
    if [[ ${#SKIPPED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${BOLD}${YELLOW}⏭️  SKIPPED (${#SKIPPED_TOOLS[@]} items):${NC}"
        for tool in "${SKIPPED_TOOLS[@]}"; do
            echo -e "   ${YELLOW}•${NC} $tool"
        done
        echo ""
    fi
    
    # Show failed tools
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${BOLD}${RED}❌ FAILED (${#FAILED_TOOLS[@]} items):${NC}"
        for tool in "${FAILED_TOOLS[@]}"; do
            echo -e "   ${RED}•${NC} $tool"
        done
        echo ""
    fi
    
    # Overall status
    local total_processed=$((${#INSTALLED_TOOLS[@]} + ${#SKIPPED_TOOLS[@]} + ${#FAILED_TOOLS[@]}))
    local success_rate=$((${#INSTALLED_TOOLS[@]} * 100 / total_processed))
    
    if [[ ${#FAILED_TOOLS[@]} -eq 0 ]]; then
        echo -e "${BOLD}${GREEN}🎯 Installation Status: SUCCESS (100% completion rate)${NC}"
    else
        echo -e "${BOLD}${YELLOW}⚠️  Installation Status: PARTIAL ($success_rate% success rate)${NC}"
    fi
    
    echo -e "\n${BOLD}${CYAN}📋 Next Steps:${NC}"
    echo -e "• ${CYAN}Log file:${NC} ${LOG_FILE}"
    echo -e "• ${CYAN}Backup directory:${NC} ${BACKUP_DIR}"
    echo -e "• ${CYAN}Reboot recommended${NC} for kernel modules and shell changes"
    echo -e "• ${CYAN}Run 'gh auth login'${NC} to authenticate with GitHub"
    echo -e "• ${CYAN}Configure terminal font${NC} to use installed Nerd Fonts"
    echo -e "• ${CYAN}Source ~/.zshrc${NC} to apply new shell settings"
    echo ""
}

# 18. Finalize Installation
finalize_setup() {
    log "HEADER" "STEP 18/$TOTAL_STEPS: FINALIZING SETUP"

    # Configure git to use delta for diffs
    log "INFO" "Configuring git to use delta for diffs..."
    if run_with_feedback "git config --global core.pager 'delta' && git config --global interactive.diffFilter 'delta --color-only' && git config --global delta.navigate 'true' && git config --global delta.side-by-side 'true' && git config --global delta.line-numbers 'true'" "Git delta configuration" "INSTALL"; then
        track_installed "Git Delta Configuration"
    else
        track_failed "Git Delta Configuration"
    fi

    # Initialize shell completions for installed tools
    log "INFO" "Setting up shell completions for installed tools..."
    
    # Create completion directories if they don't exist
    mkdir -p "$HOME/.zfunc"
    mkdir -p "$HOME/.zsh/cache"
    
    # Generate completions for installed tools
    if command_exists rustup; then
        log "INFO" "Generating Rust completions..."
        rustup completions zsh > "$HOME/.zfunc/_rustup" 2>/dev/null || true
        rustup completions zsh cargo > "$HOME/.zfunc/_cargo" 2>/dev/null || true
    fi
    
    if command_exists poetry; then
        log "INFO" "Generating Poetry completions..."
        poetry completions zsh > "$HOME/.zfunc/_poetry" 2>/dev/null || true
    fi
    
    if command_exists gh; then
        log "INFO" "Generating GitHub CLI completions..."
        gh completion -s zsh > "$HOME/.zfunc/_gh" 2>/dev/null || true
    fi
    
    # Set proper permissions for completion files
    if [[ -d "$HOME/.zfunc" ]]; then
        chmod 755 "$HOME/.zfunc"
        chmod 644 "$HOME/.zfunc"/* 2>/dev/null || true
    fi
    
    log "SUCCESS" "Shell completions configured successfully."
    
    log "SUCCESS" "All installation and configuration steps are complete!"
    
    # Generate comprehensive summary
    generate_installation_summary
    
    echo -e "${BOLD}${GREEN}🎉 Fedora Development Environment Setup is Finished! 🎉${NC}\n"

    next_step
}

# ============================================================================
# MAIN EXECUTION FLOW
# ============================================================================
main() {
    clear
    
    # Enhanced welcome screen
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                    🚀 FEDORA 42 DEVELOPMENT ENVIRONMENT SETUP                        ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BOLD}${WHITE}📋 This script will install and configure:${NC}"
    echo -e "   ${GREEN}•${NC} Modern development tools (Python, Rust, Go, C++)"
    echo -e "   ${GREEN}•${NC} Enhanced shell environment (ZSH, Oh My ZSH, Starship)"
    echo -e "   ${GREEN}•${NC} Container technologies (Docker, Podman)"
    echo -e "   ${GREEN}•${NC} Modern CLI utilities (ripgrep, bat, fd, exa, etc.)"
    echo -e "   ${GREEN}•${NC} Nerd Fonts for better terminal experience"
    echo -e "   ${GREEN}•${NC} GitHub CLI and development configurations"
    echo -e "   ${GREEN}•${NC} System optimizations and WSL compatibility"
    
    echo -e "\n${BOLD}${WHITE}📊 Installation Progress:${NC}"
    echo -e "   ${BLUE}•${NC} ${TOTAL_STEPS} total steps"
    echo -e "   ${BLUE}•${NC} Estimated time: 15-45 minutes (depends on internet speed)"
    echo -e "   ${BLUE}•${NC} Automatic backup of existing configurations"
    echo -e "   ${BLUE}•${NC} Detailed logging and progress tracking"
    
    echo -e "\n${BOLD}${WHITE}📄 Log and Backup Information:${NC}"
    echo -e "   ${CYAN}•${NC} Log file: ${LOG_FILE}"
    echo -e "   ${CYAN}•${NC} Backup directory: ${BACKUP_DIR}"
    
    # Create logs directory if it doesn't exist
    mkdir -p "$LOGS_DIR"
    
    echo -e "\n${BOLD}${YELLOW}⚠️  Prerequisites:${NC}"
    echo -e "   ${YELLOW}•${NC} Active internet connection"
    echo -e "   ${YELLOW}•${NC} Sudo privileges"
    echo -e "   ${YELLOW}•${NC} At least 10GB free disk space"
    echo -e "   ${YELLOW}•${NC} Fedora 42 (other versions may work but are not tested)"
    
    echo ""
    if ! confirm "🚀 Ready to begin the installation?" "y"; then
        echo -e "${RED}Installation aborted by user.${NC}"
        exit 0
    fi
    
    echo -e "\n${BOLD}${GREEN}🎯 Starting installation process...${NC}\n"
    
    create_backup_dir
    
    # Initialize step timing
    STEP_START_TIME=$(date +%s)

    # --- Run Installation Steps ---
    check_requirements
    update_system
    install_essential_packages
    install_nvidia_driver
    install_zsh_ohmyzsh
    install_starship
    install_python_tools
    install_rust
    install_golang
    install_cpp_tools
    install_modern_tools_dnf
    install_modern_tools_cargo
    install_container_tools
    install_fonts
    install_development_ides
    install_github_cli
    create_aliases
    finalize_setup
}

# --- Start the Script ---
main "$@"
