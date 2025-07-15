#!/bin/bash

# ============================================================================
# Rocky Linux 9.5 X11 Development Environment Setup Script
# ============================================================================
#
# Description: Complete installation and configuration script for a modern
#              development environment on Rocky Linux 9.5 with X11.
#              Also supports WSL (Windows Subsystem for Linux) environments.
#
# Author:      Gishant (adapted)
# Version:     1.0
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
# Usage: ./setup-rocky9.5.sh
#
# Prerequisites:
# - A fresh installation of Rocky Linux 9.5 (X11 session) OR Rocky on WSL.
# - An active internet connection.
# - Sudo privileges for the current user.
# - At least 10GB of free disk space is recommended.
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
TOTAL_STEPS=18
CURRENT_STEP=0
readonly SCRIPT_DIR="$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)"
readonly LOGS_DIR="${SCRIPT_DIR}/logs"
readonly LOG_FILE="${LOGS_DIR}/rocky_setup_$(date +%Y%m%d_%H%M%S).log"
readonly BACKUP_DIR="${HOME}/.config_backup_$(date +%Y%m%d_%H%M%S)"

IS_WSL=false
INSTALL_START_TIME=$(date +%s)
STEP_START_TIME=$(date +%s)
INSTALLED_TOOLS=()
SKIPPED_TOOLS=()
FAILED_TOOLS=()

# --- Utility Functions ---

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
            clear
            echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║ 🚀 $message${NC}"
            echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}\n"
            echo "$timestamp: HEADER: $message" >> "$LOG_FILE"
            ;;
    esac
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

# Error handling function
handle_error() {
    local exit_code=$1
    local command="$2"
    local line_number=$3

    if [[ $exit_code -ne 0 ]]; then
        log "ERROR" "Command failed: '$command' (line $line_number, exit code: $exit_code)"
        echo -e "\n${RED}${BOLD}💥 An error occurred. The script cannot continue.${NC}"
        echo -e "${YELLOW}📋 Please check the log file for details: ${LOG_FILE}${NC}"
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
    if [[ $current -eq 0 ]]; then current=1; fi # Avoid division by zero
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
        
        if [[ $CURRENT_STEP -le $TOTAL_STEPS ]]; then
            echo -e "\n${CYAN}Moving to next step in 3 seconds...${NC}"
            sleep 3
        fi
    else
        echo ""
    fi
    
    STEP_START_TIME=$(date +%s)
}

# Run command with enhanced feedback
run_with_feedback() {
    local command="$1"
    local description="$2"
    
    log "PROGRESS" "$description"
    eval "$command" &>> "$LOG_FILE" &
    local pid=$!
    show_spinner $pid "$description"
    wait $pid
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "SUCCESS" "$description completed successfully."
        return 0
    else
        log "ERROR" "$description failed. Check logs for details."
        # The main trap will handle logging the specific command and line number.
        return $exit_code
    fi
}

# ============================================================================
# WSL DETECTION FUNCTION
# ============================================================================

# Check if running in WSL environment
detect_wsl() {
    if [[ -f "/proc/version" ]] && grep -qi "microsoft\|wsl" /proc/version; then
        IS_WSL=true
    elif [[ -f "/proc/sys/kernel/osrelease" ]] && grep -qi "microsoft\|wsl" /proc/sys/kernel/osrelease; then
        IS_WSL=true
    elif [[ "${WSL_DISTRO_NAME:-}" != "" ]]; then
        IS_WSL=true
    else
        IS_WSL=false
    fi
    return 0
}

# WSL-specific configuration function
configure_wsl_environment() {
    if [[ "$IS_WSL" == "true" ]]; then
        log "INFO" "Configuring WSL-specific environment settings..."
        
        if [[ ! -f "$HOME/.wslconfig" ]]; then
            log "INFO" "Setting up WSL display configuration..."
            local windows_host
            windows_host=$(ip route show | grep -i default | awk '{ print $3}')
            export DISPLAY="${windows_host}:0.0"
            
            if [[ -f "$HOME/.zshrc" ]]; then
                echo "# WSL Display Configuration" >> "$HOME/.zshrc"
                echo "export DISPLAY=\$(ip route show | grep -i default | awk '{ print \$3}'):0.0" >> "$HOME/.zshrc"
            fi
        fi
        
        if command_exists git; then
            log "INFO" "Configuring Git for WSL..."
            git config --global core.autocrlf input
            git config --global core.filemode false
        fi
        
        log "INFO" "WSL environment configuration completed."
    fi
}

# ============================================================================
# PRE-INSTALLATION CHECKS
# ============================================================================

check_requirements() {
    log "HEADER" "STEP 1/$TOTAL_STEPS: CHECKING SYSTEM REQUIREMENTS"
    
    detect_wsl
    if [[ "$IS_WSL" == "true" ]]; then
        log "INFO" "WSL environment detected. Adjusting configuration."
        log "INFO" "WSL Distro: ${WSL_DISTRO_NAME:-Unknown}"
    fi

    if ! grep -q -i "rocky" /etc/os-release; then
        log "ERROR" "This script is designed for Rocky Linux."
        exit 1
    fi

    local rocky_version
    rocky_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2)
    if [[ "$rocky_version" != "9.5" ]]; then
        log "WARNING" "This script is optimized for Rocky Linux 9.5. You are on version $rocky_version."
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
    fi

    if [[ "$IS_WSL" == "false" ]]; then
        if [[ "${XDG_SESSION_TYPE:-}" != "x11" ]]; then
            log "WARNING" "This script is optimized for an X11 session, but you are running ${XDG_SESSION_TYPE:-Not Set}."
            if ! confirm "Some settings might not apply correctly. Continue?"; then
                exit 1
            fi
        fi
    else
        log "INFO" "Skipping desktop environment checks in WSL."
    fi

    log "INFO" "Checking for sudo privileges..."
    if ! sudo -v; then
        log "ERROR" "Sudo privileges are required to run this script."
        exit 1
    fi

    log "INFO" "Checking internet connection..."
    if ! ping -c 1 -W 3 google.com &>/dev/null; then
        log "ERROR" "No internet connection detected. Please connect to the internet and try again."
        exit 1
    fi

    log "SUCCESS" "System requirements check passed."
    
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
    
    local updates_available
    updates_available=$(sudo dnf check-update --quiet 2>/dev/null | wc -l || true)
    
    if [[ $updates_available -eq 0 ]]; then
        log "SUCCESS" "System is already up to date"
        track_skipped "System Updates"
    else
        log "INFO" "Found $updates_available package updates available"
        log "PROGRESS" "Updating system packages. This may take a while..."
        
        if run_with_feedback "sudo dnf upgrade --refresh -y" "System package update"; then
            track_installed "System Updates"
        else
            track_failed "System Updates"
            # The script will exit here due to the error trap
        fi
    fi
    
    next_step
}

# --- Main Execution Flow ---
main() {
    clear
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                🚀 ROCKY LINUX 9.5 DEVELOPMENT ENVIRONMENT SETUP                      ║${NC}"
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
    echo -e "\n${BOLD}${YELLOW}⚠️  Prerequisites:${NC}"
    echo -e "   ${YELLOW}•${NC} Active internet connection"
    echo -e "   ${YELLOW}•${NC} Sudo privileges"
    echo -e "   ${YELLOW}•${NC} At least 10GB free disk space"
    echo -e "   ${YELLOW}•${NC} Rocky Linux 9.5 (other versions may work but are not tested)"
    echo ""
    if ! confirm "🚀 Ready to begin the installation?" "y"; then
        echo -e "${RED}Installation aborted by user.${NC}"
        exit 0
    fi
    
    echo -e "\n${BOLD}${GREEN}🎯 Starting installation process...${NC}\n"
    
    create_backup_dir
    
    STEP_START_TIME=$(date +%s)

    # --- Run Installation Steps ---
    check_requirements
    update_system
    # ...
    # Steps will be implemented here
    # ...
}

main "$@" 