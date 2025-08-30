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

# Progress tracking
TOTAL_STEPS=19
CURRENT_STEP=0
INSTALL_START_TIME=$(date +%s)
STEP_START_TIME=$(date +%s)

# Installation tracking
INSTALLED_TOOLS=()
SKIPPED_TOOLS=()
FAILED_TOOLS=()

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
            # Clear screen for better UX before showing new step header
            clear
            echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║ 🚀 $message${NC}"
            echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}\n"
            echo "$timestamp: HEADER: $message" >> "$LOG_FILE"
            ;;
    esac
    
    # Also log to file with timestamp
    echo "$timestamp: [$level] $message" >> "$LOG_FILE"
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
# PROGRESS TRACKING AND INSTALLATION MANAGEMENT
# ============================================================================

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

    printf "\r${BLUE}[" | tee -a "$LOG_FILE"
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
        
        # Brief pause to let user see completion message before clearing to next step
        if [[ $CURRENT_STEP -lt $TOTAL_STEPS ]]; then
            echo -e "\n${CYAN}Moving to next step in 3 seconds...${NC}"
            sleep 3
        fi
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

# Docker-like progress display with limited lines and collapse
run_with_progress() {
    local command="$1"
    local description="$2"
    local log_level="${3:-INFO}"
    local max_lines="${4:-6}"
    
    log "$log_level" "Running: $description"
    
    # Create temporary file for output
    local temp_output
    temp_output=$(mktemp)
    
    # Progress display variables
    local progress_lines=()
    local lines_shown=0
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local spinner_idx=0
    
    echo -e "${CYAN}┌─ $description${NC}"
    
    # Start command and capture output
    eval "$command" > "$temp_output" 2>&1 &
    local pid=$!
    
    # Monitor progress
    while kill -0 "$pid" 2>/dev/null; do
        # Read current output
        if [[ -s "$temp_output" ]]; then
            # Get last few lines
            local current_lines
            mapfile -t current_lines < <(tail -n $max_lines "$temp_output" 2>/dev/null)
            
            # Clear previous display
            if [[ $lines_shown -gt 0 ]]; then
                for ((i=0; i<lines_shown; i++)); do
                    printf "\033[1A\033[K"
                done
            fi
            
            # Show current progress with spinner
            local spinner_char=${spinner_chars:$spinner_idx:1}
            lines_shown=0
            
            for line in "${current_lines[@]}"; do
                if [[ -n "$line" ]]; then
                    local clean_line
                    clean_line=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-70)
                    if [[ -n "$clean_line" ]]; then
                        echo -e "${CYAN}│${NC} $spinner_char $clean_line"
                        lines_shown=$((lines_shown + 1))
                    fi
                fi
            done
            
            # Update spinner
            spinner_idx=$(( (spinner_idx + 1) % ${#spinner_chars} ))
        fi
        
        sleep 0.5
    done
    
    # Wait for process to complete
    wait "$pid"
    local exit_code=$?
    
    # Clear progress display
    if [[ $lines_shown -gt 0 ]]; then
        for ((i=0; i<lines_shown; i++)); do
            printf "\033[1A\033[K"
        done
    fi
    
    # Show final collapsed status
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${CYAN}└─${NC} ${GREEN}✓${NC} $description ${GREEN}completed successfully${NC}"
        log "SUCCESS" "$description completed successfully"
    else
        echo -e "${CYAN}└─${NC} ${RED}✗${NC} $description ${RED}failed (exit code: $exit_code)${NC}"
        log "ERROR" "$description failed with exit code $exit_code"
        
        # Show error details for failed commands
        if [[ -s "$temp_output" ]]; then
            echo -e "${RED}   Error details:${NC}"
            tail -n 3 "$temp_output" | sed 's/^/   │ /'
        fi
    fi
    
    # Cleanup
    rm -f "$temp_output"
    
    return $exit_code
}

# Run command with enhanced feedback (kept for backward compatibility)
run_with_feedback() {
    local command="$1"
    local description="$2"
    local log_level="${3:-INFO}"
    
    # Use the new progress display
    run_with_progress "$command" "$description" "$log_level" 8
}

# Enhanced package installation with progress
install_packages() {
    local packages=("$@")
    local description="Installing packages: ${packages[*]}"
    
    log "INSTALL" "$description"
    
    case "$PACKAGE_MANAGER" in
        "apt")
            # Use apt with progress output
            sudo apt install -y "${packages[@]}" 2>&1 | while IFS= read -r line; do
                if [[ "$line" == *"Unpacking"* ]] || [[ "$line" == *"Setting up"* ]]; then
                    printf "\r${CYAN}📦 $line${NC}"
                elif [[ "$line" == *"Processing triggers"* ]]; then
                    printf "\r${GREEN}✅ Processing triggers...${NC}\n"
                fi
            done
            ;;
        "dnf")
            # Use dnf with progress output
            sudo dnf install -y "${packages[@]}" 2>&1 | while IFS= read -r line; do
                if [[ "$line" == *"Installing"* ]] || [[ "$line" == *"Downloading"* ]]; then
                    printf "\r${CYAN}📦 $line${NC}"
                elif [[ "$line" == *"Complete!"* ]]; then
                    printf "\r${GREEN}✅ Installation completed successfully${NC}\n"
                fi
            done
            ;;
        *)
            log "ERROR" "Unsupported package manager: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
    
    return ${PIPESTATUS[0]}
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

# Create backup directory
create_backup_dir() {
    log "INFO" "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    log "SUCCESS" "Backup directory created successfully"
}

# Backup a file before modifying it
backup_file() {
    local file_path="$1"
    local backup_name
    
    if [[ -f "$file_path" ]]; then
        backup_name="$(basename "$file_path").$(date +%Y%m%d_%H%M%S).bak"
        cp -a "$file_path" "$BACKUP_DIR/$backup_name"
        log "INFO" "Backed up $file_path to $BACKUP_DIR/$backup_name"
    else
        log "INFO" "File $file_path does not exist, no backup needed"
    fi
}

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
# ZSH, OH MY ZSH, AND PLUGINS
# ============================================================================

install_zsh_ohmyzsh() {
    log "HEADER" "STEP 6/$TOTAL_STEPS: ZSH & OH MY ZSH"

    log "INFO" "Installing ZSH..."
    case "$PACKAGE_MANAGER" in
        "apt")
            sudo apt install -y zsh
            ;;
        "dnf")
            sudo dnf install -y zsh
            ;;
    esac

    if [[ "$SHELL" != "/bin/zsh" ]] && [[ "$SHELL" != "/usr/bin/zsh" ]]; then
        log "INFO" "Changing default shell to ZSH for user $USER."
        if sudo chsh -s "$(which zsh)" "$USER"; then
            log "SUCCESS" "Default shell changed to ZSH."
        else
            log "ERROR" "Failed to change default shell to ZSH."
        fi
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
# Generated by WSL Setup Script
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
if command -v fzf &> /dev/null && fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
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
    if [[ -f /usr/share/bash-completion/completions/docker ]] && [[ -n "$ZSH_VERSION" ]]; then
        source /usr/share/bash-completion/completions/docker 2>/dev/null || true
    fi
fi

# Podman completion
if command -v podman &> /dev/null; then
    autoload -U +X bashcompinit && bashcompinit
    if [[ -f /usr/share/bash-completion/completions/podman ]] && [[ -n "$ZSH_VERSION" ]]; then
        source /usr/share/bash-completion/completions/podman 2>/dev/null || true
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

# Source aliases file if it exists
if [[ -f ~/.aliases ]]; then
    source ~/.aliases
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

# ============================================================================
# STARSHIP TERMINAL PROMPT
# ============================================================================

install_starship() {
    log "HEADER" "STEP 7/$TOTAL_STEPS: STARSHIP TERMINAL PROMPT"

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
Windows = "󰍲"
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
# PYTHON DEVELOPMENT TOOLS
# ============================================================================

install_python_tools() {
    log "HEADER" "STEP 8/$TOTAL_STEPS: PYTHON DEVELOPMENT TOOLS"

    log "INFO" "Installing Python build dependencies..."
    case "$PACKAGE_MANAGER" in
        "apt")
            sudo apt install -y gcc make patch zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libssl-dev tk-dev libffi-dev xz-utils
            ;;
        "dnf")
            sudo dnf install -y gcc make patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel
            ;;
    esac

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

# ============================================================================
# RUST DEVELOPMENT ENVIRONMENT
# ============================================================================

install_rust() {
    log "HEADER" "STEP 9/$TOTAL_STEPS: RUST DEVELOPMENT ENVIRONMENT"

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

# ============================================================================
# GO DEVELOPMENT ENVIRONMENT
# ============================================================================

install_golang() {
    log "HEADER" "STEP 10/$TOTAL_STEPS: GO DEVELOPMENT ENVIRONMENT"

    if command_exists go; then
        log "INFO" "Go is already installed. Skipping."
    else
        log "INFO" "Installing Go..."
        case "$PACKAGE_MANAGER" in
            "apt")
                sudo apt install -y golang-go
                ;;
            "dnf")
                sudo dnf install -y golang
                ;;
        esac
    fi

    log "INFO" "Setting up Go workspace directory..."
    mkdir -p "$HOME/go"

    log "SUCCESS" "Go development environment installed."
    next_step
}

# ============================================================================
# C++ DEVELOPMENT ENVIRONMENT
# ============================================================================

install_cpp_tools() {
    log "HEADER" "STEP 11/$TOTAL_STEPS: C++ DEVELOPMENT ENVIRONMENT"

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
        case "$PACKAGE_MANAGER" in
            "apt")
                if run_with_feedback "sudo apt install -y build-essential cmake gdb valgrind clang lldb" "C++ development tools" "INSTALL"; then
                    for tool in "${missing_tools[@]}"; do
                        track_installed "$tool"
                    done
                else
                    for tool in "${missing_tools[@]}"; do
                        track_failed "$tool"
                    done
                fi
                ;;
            "dnf")
                if run_with_feedback "sudo dnf group install -y 'C Development Tools and Libraries' 'Development Tools'" "C++ development groups" "INSTALL" &&
                    run_with_feedback "sudo dnf install -y cmake gdb valgrind clang lldb" "C++ development tools" "INSTALL"; then
                    for tool in "${missing_tools[@]}"; do
                        track_installed "$tool"
                    done
                else
                    for tool in "${missing_tools[@]}"; do
                        track_failed "$tool"
                    done
                fi
                ;;
        esac
    else
        log "SUCCESS" "All C++ development tools are already installed. Skipping."
        track_skipped "C++ Development Environment"
    fi

    next_step
}

# ============================================================================
# MODERN CLI TOOLS
# ============================================================================

install_modern_tools() {
    log "HEADER" "STEP 12/$TOTAL_STEPS: MODERN CLI TOOLS"

    local tools_apt=(
        "ripgrep"
        "bat"
        "fd-find"
        "duf"
        "jq"
        "fzf"
        "zoxide"
        "htop"
        "tree"
        "unzip"
        "zip"
    )

    local tools_dnf=(
        "ripgrep"
        "bat"
        "fd-find"
        "duf"
        "jq"
        "fzf"
        "zoxide"
        "htop"
        "tree"
        "unzip"
        "zip"
    )

    local tools_to_install=()
    case "$PACKAGE_MANAGER" in
        "apt")
            for tool in "${tools_apt[@]}"; do
                if ! command_exists "$tool"; then
                    tools_to_install+=("$tool")
                else
                    track_skipped "$tool"
                fi
            done
            ;;
        "dnf")
            for tool in "${tools_dnf[@]}"; do
                if ! command_exists "$tool"; then
                    tools_to_install+=("$tool")
                else
                    track_skipped "$tool"
                fi
            done
            ;;
    esac

    if [[ ${#tools_to_install[@]} -gt 0 ]]; then
        log "PROGRESS" "Installing ${#tools_to_install[@]} modern CLI tools: ${tools_to_install[*]}"
        if install_packages "${tools_to_install[@]}"; then
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
        track_skipped "Modern CLI Tools"
    fi

    # Install atuin via cargo (Rust tool)
    if ! command_exists atuin; then
        if command_exists cargo; then
            log "INFO" "Installing atuin via cargo..."
            if cargo install atuin; then
                track_installed "atuin"
            else
                track_failed "atuin"
            fi
        else
            log "WARNING" "Cargo not found, skipping atuin installation"
            track_failed "atuin"
        fi
    else
        track_skipped "atuin"
    fi

    next_step
}

# ============================================================================
# FONTS INSTALLATION
# ============================================================================

install_fonts() {
    log "HEADER" "STEP 13/$TOTAL_STEPS: NERD FONTS INSTALLATION"

    local font_dir="$HOME/.local/share/fonts"
    log "INFO" "Creating fonts directory at $font_dir"
    mkdir -p "$font_dir"

    # Check for existing font installations
    local firacode_installed=false
    local jetbrains_installed=false

    log "INFO" "Checking for existing font installations..."

    # Check for FiraCode Nerd Font
    if fc-list 2>/dev/null | grep -qi "FiraCode.*Nerd" || \
        ls "$font_dir" 2>/dev/null | grep -qi "FiraCode.*Nerd"; then
        firacode_installed=true
        track_skipped "FiraCode Nerd Font"
    fi

    # Check for JetBrainsMono Nerd Font
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono.*Nerd" || \
        ls "$font_dir" 2>/dev/null | grep -qi "JetBrainsMono.*Nerd"; then
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

# ============================================================================
# DEVELOPMENT IDEs AND EDITORS
# ============================================================================

install_development_ides() {
    log "HEADER" "STEP 14/$TOTAL_STEPS: DEVELOPMENT IDEs & EDITORS"

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
            case "$PACKAGE_MANAGER" in
                "apt")
                    log "INFO" "Adding Microsoft's GPG key and repository..."
                    sudo apt install -y wget apt-transport-https
                    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
                    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
                    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
                    rm -f packages.microsoft.gpg
                    sudo apt install -y apt-transport-https
                    sudo apt update
                    ;;
                "dnf")
                    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
                    ;;
            esac

            # Install VSCode
            if run_with_feedback "sudo $PACKAGE_MANAGER install -y code" "VSCode installation" "INSTALL"; then
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
    echo -e "   ${GREEN}•${NC} Neovim: Advanced text editor (run 'sudo $PACKAGE_MANAGER install neovim')"
    echo -e "   ${GREEN}•${NC} Emacs: Extensible text editor (run 'sudo $PACKAGE_MANAGER install emacs')"
    echo -e "   ${GREEN}•${NC} Qt Creator: For Qt/C++ development"
    echo -e "   ${GREEN}•${NC} KDevelop: KDE's integrated development environment"
    echo ""

    next_step
}

# ============================================================================
# GITHUB CLI INSTALLATION
# ============================================================================

install_github_cli() {
    log "HEADER" "STEP 15/$TOTAL_STEPS: GITHUB CLI INSTALLATION"

    if command_exists gh; then
        track_skipped "GitHub CLI"
    else
        log "PROGRESS" "Installing GitHub CLI..."
        case "$PACKAGE_MANAGER" in
            "apt")
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &&
                sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg &&
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null &&
                sudo apt update &&
                sudo apt install -y gh
                ;;
            "dnf")
                sudo dnf install -y gh
                ;;
        esac

        if command_exists gh; then
            track_installed "GitHub CLI"
        else
            track_failed "GitHub CLI"
        fi
    fi

    next_step
}

# ============================================================================
# COMPREHENSIVE ALIASES
# ============================================================================

create_aliases() {
    log "HEADER" "STEP 16/$TOTAL_STEPS: CREATING ALIASES FILE"

    log "INFO" "Creating comprehensive aliases file at ~/.aliases..."
    backup_file "$HOME/.aliases"
    cat > "$HOME/.aliases" << 'EOF'
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
#                    ★  ALIASES ★
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# --------------------------------------------------------------
# ► Shell & Convenience
# --------------------------------------------------------------
alias c='clear'                               # Clear the screen
alias q='exit'                                # Quick exit
alias ..='cd ..'                              # Go up one directory
alias ...='cd ../..'                          # Go up two directories
alias ....='cd ../../..'                      # Go up three directories
alias aliases='nano ~/.aliases'               # Quickly edit this file
alias reload='source ~/.bashrc'               # Reload shell configuration
alias h='history'                             # Shorthand for history
alias hg='history | grep'                     # Grep through history
alias cd='z'                                  # Use zoxide for smarter cd (if available)

# --------------------------------------------------------------
# ► File & Directory Management (Modern Replacements)
# --------------------------------------------------------------
# eza (replaces ls) - https://github.com/eza-community/eza
if command -v eza &> /dev/null; then
    alias ls='eza --icons --color=always --group-directories-first' # ls replacement with icons
    alias l='eza -l -h --git --icons --group-directories-first'     # Long format, human-readable sizes, git status
    alias la='eza -la --icons --group-directories-first'            # Long format, all files (including hidden)
    alias ll='la'                                                   # Common alias for `la`
    alias lt='la --sort=modified'                                   # Sort by modification time, newest first
    alias llt='eza -l --icons --sort=modified'                      # Long format sorted by time
    alias lS='la --sort=size'                                       # Sort by size, largest first
    alias tree='eza --tree --level=3 --long --icons --git'          # Tree view with details, up to 3 levels deep
fi

# bat (replaces cat) - https://github.com/sharkdp/bat
if command -v bat &> /dev/null; then
    alias cat='bat --theme="Dracula"'                               # Use bat instead of cat
    alias catp='bat'                                                # bat with paging
fi

# fd (replaces find) - https://github.com/sharkdp/fd
if command -v fd &> /dev/null; then
    alias find='fd'
fi

# ripgrep (replaces grep) - https://github.com/BurntSushi/ripgrep
if command -v rg &> /dev/null; then
    alias grep='rg'
fi

# dust (replaces du) & duf (replaces df)
if command -v dust &> /dev/null; then
    alias du='dust'                                                 # Show disk usage of directories
fi
if command -v duf &> /dev/null; then
    alias df='duf'                                                  # Show disk free space
fi

# procs (replaces ps)
if command -v procs &> /dev/null; then
    alias ps='procs'
fi

# gping (replaces ping)
if command -v gping &> /dev/null; then
    alias ping='gping'                                              # Use gping for a graphical ping
fi

# tealdeer (replaces man)
if command -v tldr &> /dev/null; then
    alias man='tldr'                                                # Quick help with tealdeer
fi

# --------------------------------------------------------------
# ► System & Package Management
# --------------------------------------------------------------
# System Monitoring
if command -v btm &> /dev/null; then
    alias top='btm'                                                 # Use bottom for system monitoring
    alias htop='btm'                                                # Also alias htop to bottom
fi
if command -v procs &> /dev/null; then
    alias procs='procs --tree'                                      # Use procs with tree view
fi

# Package Management (Debian/Ubuntu)
alias apti='sudo apt install'
alias apts='apt search'
alias aptu='sudo apt update && sudo apt upgrade'
alias aptr='sudo apt remove'
alias aptc='sudo apt autoremove && sudo apt autoclean'

# Package Management (Fedora/RHEL)
alias dnfi='sudo dnf install'
alias dnfs='sudo dnf search'
alias dnfu='sudo dnf upgrade --refresh'
alias dnfr='sudo dnf remove'
alias dnfc='sudo dnf autoremove'
alias update='sudo dnf upgrade --refresh -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'
alias search='dnf search'

# --------------------------------------------------------------
# ► Git Aliases (Productivity Boost)
# --------------------------------------------------------------
alias g='git'
alias ga='git add'
alias gaa='git add -A'                                          # Add all changes
alias gc='git commit -v'
alias gcm='git commit -m'
alias gca='git commit --amend'                                  # Amend the last commit
alias gcaa='git commit --amend --no-edit'                       # Amend without editing
alias gp='git push'
alias gpf='git push --force-with-lease'                         # Safer force push
alias gpl='git pull'
alias gco='git checkout'
alias gcb='git checkout -b'                                     # Create and checkout a new branch
alias gsw='git switch'                                          # Switch branches (modern)
alias gsc='git switch -c'                                       # Create and switch to a new branch
alias gb='git branch'
alias gbr='git branch'
alias gba='git branch -a'                                       # List all local and remote branches
alias gs='git status -sb'                                       # Short branch-aware status
alias gss='git status -s'                                       # Short status
alias gcl='git clone'
alias gsta='git stash'
alias gstp='git stash pop'
if command -v delta &> /dev/null; then
    alias gd='delta'                                            # Use delta for diffs
    alias gdiff='git diff | delta'                                  # Git diff with delta
    alias glogd='git log --oneline | delta'                         # Git log with delta
fi
alias glog="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gld="git log --pretty=format:'%C(yellow)%h\\ %ad%d\\ %Creset%s%C(blue)\\ [%cn]' --decorate --date=short"
alias gl='git log --oneline --graph --decorate'                 # Short git log
if command -v delta &> /dev/null; then
    alias glogd='git log --oneline | delta'                         # Git log with delta
fi
alias lazygit='lazygit'                                         # Launch the lazygit TUI
alias lg='lazygit'                                              # Short alias for lazygit

# --------------------------------------------------------------
# ► Networking
# --------------------------------------------------------------
alias myip="curl -s ifconfig.me && echo"                        # Get public IP address

# --------------------------------------------------------------
# ► Docker & Containers
# --------------------------------------------------------------
alias d='docker'

# Containers
alias dps='docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}"'
alias dpsa='docker ps -a'
alias dstopall='docker stop $(docker ps -aq)'                   # Stop all running containers
alias drmall='docker rm $(docker ps -aq)'                       # Remove all containers (must be stopped first)

# Images
alias di='docker images'
alias dirmall='docker rmi $(docker images -q)'                  # Remove all images (will fail if in use)
alias diprune='docker image prune -a'                           # Remove all dangling and unused images

# Volumes
alias dvl='docker volume ls'                                    # List volumes
alias dvprune='docker volume prune -f'                          # Remove all unused local volumes

# Logs and Execution
alias dlogs='docker logs -f'
alias dexec='docker exec -it'

# TUI
alias lazydocker='lazydocker'                                   # Launch the lazydocker TUI

# Docker Compose
alias dc='docker compose'
alias dcup='docker compose up'
alias dcud='docker compose up -d'                               # Start services in detached mode
alias dcdown='docker compose down'                              # Stop and remove containers, networks
alias dcd='docker compose down'                                 # Alternative alias
alias dcps='docker compose ps'                                  # List containers
alias dcl='docker compose logs -f --tail=100'                   # Follow logs for all services
alias dclogs='docker compose logs -f'                           # Alternative alias
alias dcb='docker compose build'                                # Build or rebuild services
alias dce='docker compose exec'                                 # Execute a command in a running container

# --------------------------------------------------------------
# ► Podman (Alternative to Docker)
# --------------------------------------------------------------
alias p='podman'
alias pps='podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias ppsa='podman ps -a'
alias pi='podman images'

# --------------------------------------------------------------
# ► Python Development
# --------------------------------------------------------------
alias py='python'

# Poetry
alias po='poetry'
alias poa='poetry add'
alias por='poetry remove'
alias poi='poetry install'
alias pou='poetry update'
alias porun='poetry run'
alias poshell='poetry shell'

# uv (Fast Python package manager)
alias uv='uv'
alias uvi='uv pip install'
alias uvr='uv pip install -r requirements.txt'

# --------------------------------------------------------------
# ► Rust Development
# --------------------------------------------------------------
alias cc='cargo check'
alias cb='cargo build'
alias cbr='cargo build --release'
alias cr='cargo run'
alias ct='cargo test'
alias cl='cargo clippy'
alias cfmt='cargo fmt'

# --------------------------------------------------------------
# ► Go Development
# --------------------------------------------------------------
alias gr='go run'
alias gb='go build'
alias gt='go test ./...'
alias gti='go mod tidy'

# --------------------------------------------------------------
# ► FZF Integration
# --------------------------------------------------------------
if command -v fzf &> /dev/null; then
    if command -v bat &> /dev/null; then
        alias fzf-preview='fzf --preview "bat --style=numbers --color=always {}"'
    fi
    if command -v fd &> /dev/null; then
        alias fzf-cd='cd $(fd --type d | fzf)'
        alias fzf-edit='$EDITOR $(fd --type f | fzf)'
    fi
fi

# --------------------------------------------------------------
# ► Atuin (Shell History)
# --------------------------------------------------------------
alias ha='atuin search'                                         # Atuin search
alias hai='atuin search -i'                                     # Atuin case-insensitive search

# --------------------------------------------------------------
# ► Utility Functions
# --------------------------------------------------------------
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
myip_func() {
    curl ifconfig.me
}

# Quick file find and edit
fe() {
    if command -v fd &> /dev/null && command -v fzf &> /dev/null && command -v bat &> /dev/null; then
        local file
        file=$(fd --type f | fzf --preview "bat --style=numbers --color=always {}") && $EDITOR "$file"
    else
        echo "fe() requires fd, fzf, and bat to be installed"
    fi
}

# Quick directory navigation
fcd() {
    if command -v fd &> /dev/null && command -v fzf &> /dev/null; then
        local dir
        dir=$(fd --type d | fzf) && cd "$dir"
    else
        echo "fcd() requires fd and fzf to be installed"
    fi
}

# Git fuzzy checkout
fco() {
    if command -v fzf &> /dev/null; then
        git branch --all | grep -v HEAD | fzf | sed 's/^..//' | xargs git checkout
    else
        echo "fco() requires fzf to be installed"
    fi
}

# Process fuzzy kill
fkill() {
    if command -v procs &> /dev/null && command -v fzf &> /dev/null; then
        local pid
        pid=$(procs | fzf --header-lines=1 | awk '{print $1}')
        if [ -n "$pid" ]; then
            kill -9 "$pid"
        fi
    else
        echo "fkill() requires procs and fzf to be installed"
    fi
}

# Docker fuzzy container management
fdc() {
    if command -v docker &> /dev/null && command -v fzf &> /dev/null; then
        local container
        container=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | fzf --header-lines=1 | awk '{print $1}')
        if [ -n "$container" ]; then
            docker exec -it "$container" /bin/bash
        fi
    else
        echo "fdc() requires docker and fzf to be installed"
    fi
}
EOF

    log "SUCCESS" "Comprehensive aliases file created at ~/.aliases."
    next_step
}

# ============================================================================
# WSL INTEGRATION TOOLS
# ============================================================================

setup_wsl_integration() {
    log "HEADER" "STEP 18/$TOTAL_STEPS: WSL INTEGRATION SETUP"
    
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
    next_step
}

# ============================================================================
# FINALIZATION
# ============================================================================

generate_installation_summary() {
    local total_time=$(($(date +%s) - INSTALL_START_TIME))

    # Clear screen for clean summary presentation
    clear

    echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                           📊 WSL INSTALLATION SUMMARY REPORT                           ║${NC}"
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
    echo -e "• ${CYAN}Test Windows integration:${NC} explorer.exe ."
    echo ""
}

finalize_setup() {
    log "HEADER" "STEP 19/$TOTAL_STEPS: FINALIZING SETUP"

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

    echo -e "${BOLD}${GREEN}🎉 WSL Development Environment Setup is Finished! 🎉${NC}\n"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    clear

    # Enhanced welcome screen
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                    🚀 WSL DEVELOPMENT ENVIRONMENT SETUP                        ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${BOLD}${WHITE}📋 This script will install and configure:${NC}"
    echo -e "   ${GREEN}•${NC} Modern development tools (Python, Rust, Go, C++)"
    echo -e "   ${GREEN}•${NC} Enhanced shell environment (ZSH, Oh My ZSH, Starship)"
    echo -e "   ${GREEN}•${NC} Container technologies (Docker, Podman)"
    echo -e "   ${GREEN}•${NC} Modern CLI utilities (ripgrep, bat, fd, exa, etc.)"
    echo -e "   ${GREEN}•${NC} Nerd Fonts for better terminal experience"
    echo -e "   ${GREEN}•${NC} GitHub CLI and development configurations"
    echo -e "   ${GREEN}•${NC} WSL-specific optimizations and Windows integration"

    echo -e "\n${BOLD}${WHITE}📊 Installation Progress:${NC}"
    echo -e "   ${BLUE}•${NC} ${TOTAL_STEPS} total steps"
    echo -e "   ${BLUE}•${NC} Estimated time: 20-45 minutes (depends on internet speed)"
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
    echo -e "   ${YELLOW}•${NC} WSL environment (Ubuntu/Fedora)"

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
    check_wsl_environment
    detect_distribution
    update_system
    configure_wsl_basics
    install_essential_tools
    install_zsh_ohmyzsh
    install_starship
    install_python_tools
    install_rust
    install_golang
    install_cpp_tools
    install_modern_tools
    install_container_tools
    install_fonts
    install_development_ides
    install_github_cli
    create_aliases
    setup_wsl_integration
    finalize_setup
}

# Start the script
main "$@"
