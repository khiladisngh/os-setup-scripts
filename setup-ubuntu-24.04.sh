#!/bin/bash

# ============================================================================
# Ubuntu 24.04 LTS GNOME Wayland Development Environment Setup Script
# ============================================================================
#
# Description: Complete installation and configuration script for a modern
#              development environment on Ubuntu 24.04 LTS GNOME with Wayland.
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
# Usage: ./setup-ubuntu-24.04.sh
#
# Prerequisites:
# - A fresh installation of Ubuntu 24.04 LTS GNOME (Wayland session) OR Ubuntu on WSL.
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
TOTAL_STEPS=16
CURRENT_STEP=0
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/ubuntu_setup_$(date +%Y%m%d_%H%M%S).log"
readonly BACKUP_DIR="${HOME}/.config_backup_$(date +%Y%m%d_%H%M%S)"

# WSL Detection
IS_WSL=false

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

# Enhanced logging function with timestamps and log levels
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
        "PROGRESS")
            echo -e "${MAGENTA}[PROGRESS]${NC} ${timestamp}: $message" | tee -a "$LOG_FILE"
            ;;
        "HEADER")
            echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║ $message${NC}"
            echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}\n"
            echo "$timestamp: HEADER: $message" >> "$LOG_FILE"
            ;;
    esac
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))

    printf "\r${BLUE}["
    for ((i=0; i<completed; i++)); do printf "█"; done
    for ((i=completed; i<width; i++)); do printf "░"; done
    printf "] %d%% (%d/%d)${NC}" "$percentage" "$current" "$total"
}

# Step progress function
next_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS
    echo ""
}

# Error handling function
handle_error() {
    local exit_code=$1
    local command="$2"
    local line_number=$3

    if [[ $exit_code -ne 0 ]]; then
        log "ERROR" "Command failed: '$command' (line $line_number, exit code: $exit_code)"
        echo -e "\n${RED}${BOLD}An error occurred. The script cannot continue.${NC}"
        echo -e "${YELLOW}Please check the log file for details: ${LOG_FILE}${NC}"
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

    # Check if running on Ubuntu
    if ! grep -q -i "ubuntu" /etc/os-release; then
        log "ERROR" "This script is designed for Ubuntu Linux."
        exit 1
    fi

    # Check Ubuntu version
    local ubuntu_version
    ubuntu_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    if [[ "$ubuntu_version" != "24.04" ]]; then
        log "WARNING" "This script is optimized for Ubuntu 24.04 LTS. You are on version $ubuntu_version."
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
    fi

    # Check for GNOME and Wayland (skip in WSL)
    if [[ "$IS_WSL" == "false" ]]; then
        if [[ "${XDG_CURRENT_DESKTOP:-}" != "ubuntu:GNOME" ]] || [[ "${XDG_SESSION_TYPE:-}" != "wayland" ]]; then
            log "WARNING" "This script is optimized for GNOME on Wayland."
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
    log "INFO" "Updating package lists and upgrading system packages. This may take a while..."
    sudo apt update && sudo apt upgrade -y
    log "SUCCESS" "System update completed."
    next_step
}

# 3. NVIDIA Graphics Driver
install_nvidia_driver() {
    log "HEADER" "STEP 3/$TOTAL_STEPS: NVIDIA GRAPHICS DRIVER"

    # Skip NVIDIA drivers in WSL
    if [[ "$IS_WSL" == "true" ]]; then
        log "INFO" "Skipping NVIDIA driver installation in WSL environment."
        next_step
        return
    fi

    if ! lspci | grep -iq 'VGA.*NVIDIA'; then
        log "INFO" "No NVIDIA GPU detected. Skipping this step."
        next_step
        return
    fi

    if command_exists nvidia-smi; then
        log "INFO" "NVIDIA drivers are already installed. Skipping."
        next_step
        return
    fi

    if confirm "NVIDIA GPU detected. Do you want to install the proprietary drivers?"; then
        log "INFO" "Installing NVIDIA drivers..."
        sudo apt install -y nvidia-driver-535 nvidia-utils-535
        
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

# 4. ZSH, Oh My ZSH, and Plugins
install_zsh_ohmyzsh() {
    log "HEADER" "STEP 4/$TOTAL_STEPS: ZSH & OH MY ZSH"

    log "INFO" "Installing ZSH..."
    sudo apt install -y zsh

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

    cat > "$HOME/.zshrc" << 'EOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load.
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
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

# User configuration
export EDITOR='nvim' # Or your preferred editor
export LANG=en_US.UTF-8

# --- Tool-specific Configurations ---

# Starship Prompt
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# Zoxide (smarter cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &> /dev/null; then
  eval "$(pyenv init -)"
fi

# GoLang Path
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

# Rust/Cargo Path
export PATH="$HOME/.cargo/bin:$PATH"

# Custom Aliases
# Load custom aliases from a separate file for better organization.
if [[ -f ~/.aliases ]]; then
    source ~/.aliases
fi

# History configuration
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# Key bindings for history substring search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Initialize completions
autoload -U compinit
compinit
EOF

    log "SUCCESS" "ZSH, Oh My ZSH, and plugins installed and configured."
    next_step
}

# 5. Starship Terminal Prompt
install_starship() {
    log "HEADER" "STEP 5/$TOTAL_STEPS: STARSHIP TERMINAL PROMPT"

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
[](#9A348E)\
$os\
$username\
[](bg:#DA627D fg:#9A348E)\
$directory\
[](fg:#DA627D bg:#FCA17D)\
$git_branch\
$git_status\
[](fg:#FCA17D bg:#86BBD8)\
$c\
$rust\
$golang\
$python\
[](fg:#86BBD8 bg:#06969A)\
$docker_context\
[](fg:#06969A bg:#33658A)\
$time\
[ ](fg:#33658A)\
$line_break$character"""

[os]
style = "bg:#9A348E"
disabled = false
format = '[ $symbol ]($style)'

[os.symbols]
Ubuntu = ""
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
symbol = ""
style = "bg:#FCA17D"
format = '[[ $symbol $branch ](fg:#090c0c bg:#FCA17D)]($style)'

[git_status]
style = "bg:#FCA17D"
format = '[[($all_status$ahead_behind )](fg:#090c0c bg:#FCA17D)]($style)'

[c]
symbol = " "
style = "bg:#86BBD8"
format = '[[ $symbol ($version) ](fg:#090c0c bg:#86BBD8)]($style)'

[rust]
symbol = ""
style = "bg:#86BBD8"
format = '[[ $symbol ($version) ](fg:#090c0c bg:#86BBD8)]($style)'

[golang]
symbol = ""
style = "bg:#86BBD8"
format = '[[ $symbol ($version) ](fg:#090c0c bg:#86BBD8)]($style)'

[python]
symbol = ""
style = "bg:#86BBD8"
format = '[[ $symbol ($version) ](fg:#090c0c bg:#86BBD8)]($style)'

[docker_context]
symbol = ""
style = "bg:#06969A"
format = '[[ $symbol $context ](fg:#090c0c bg:#06969A)]($style)'

[time]
disabled = false
time_format = "%R"
style = "bg:#33658A"
format = '[[  $time ](fg:#fcfcfc bg:#33658A)]($style)'

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

# 6. Python Development (Pyenv, Poetry, uv)
install_python_tools() {
    log "HEADER" "STEP 6/$TOTAL_STEPS: PYTHON DEVELOPMENT TOOLS"

    log "INFO" "Installing Python build dependencies..."
    sudo apt install -y make build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

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

# 7. Rust Development Environment
install_rust() {
    log "HEADER" "STEP 7/$TOTAL_STEPS: RUST DEVELOPMENT ENVIRONMENT"

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

# 8. Go Development Environment
install_golang() {
    log "HEADER" "STEP 8/$TOTAL_STEPS: GO DEVELOPMENT ENVIRONMENT"

    if command_exists go; then
        log "INFO" "Go is already installed. Skipping."
    else
        log "INFO" "Installing Go..."
        # Install Go from the official repository
        sudo apt install -y golang-go
        
        # If we want the latest version, we could download it manually:
        # wget -O go.tar.gz https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
        # sudo tar -C /usr/local -xzf go.tar.gz
        # rm go.tar.gz
    fi

    log "INFO" "Setting up Go workspace directory..."
    mkdir -p "$HOME/go"

    log "SUCCESS" "Go development environment installed."
    next_step
}

# 9. C++ Development Environment
install_cpp_tools() {
    log "HEADER" "STEP 9/$TOTAL_STEPS: C++ DEVELOPMENT ENVIRONMENT"

    log "INFO" "Installing C++ build essentials and tools..."
    sudo apt install -y build-essential cmake gdb valgrind clang lldb

    log "SUCCESS" "C++ development environment installed."
    next_step
}

# 10. Modern Tools via APT
install_modern_tools_apt() {
    log "HEADER" "STEP 10/$TOTAL_STEPS: MODERN TOOLS (APT)"

    local tools=(
        ripgrep
        bat
        fd-find
        jq
        fzf
        htop
        tree
        unzip
        curl
        wget
        git
    )

    log "INFO" "Installing modern CLI tools via APT..."
    sudo apt install -y "${tools[@]}"

    # Create symlinks for fd (it's installed as fdfind on Ubuntu)
    if ! command_exists fd && command_exists fdfind; then
        sudo ln -sf $(which fdfind) /usr/local/bin/fd
    fi

    log "SUCCESS" "Modern tools from APT installed."
    next_step
}

# 11. Modern Tools via Cargo
install_modern_tools_cargo() {
    log "HEADER" "STEP 11/$TOTAL_STEPS: MODERN TOOLS (CARGO)"

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
        atuin
        duf
    )

    log "INFO" "Installing modern CLI tools via Cargo..."
    for tool in "${tools[@]}"; do
        if ! command_exists "$tool"; then
            log "INFO" "Installing $tool..."
            cargo install "$tool"
        else
            log "INFO" "$tool is already installed. Skipping."
        fi
    done

    log "SUCCESS" "Modern tools from Cargo installed."
    next_step
}

# 12. Container Tools (Docker, Podman)
install_container_tools() {
    log "HEADER" "STEP 12/$TOTAL_STEPS: CONTAINER TOOLS"

    if ! confirm "Install Docker and Podman?"; then
        log "INFO" "Skipping container tools installation."
        next_step
        return
    fi

    # WSL-specific container setup
    if [[ "$IS_WSL" == "true" ]]; then
        log "INFO" "WSL detected. Installing container tools compatible with WSL..."
        log "INFO" "Note: For best WSL experience, consider using Docker Desktop for Windows."
        
        # Install Docker (without systemd service management)
        log "INFO" "Installing Docker (without systemd service)..."
        # Remove any old versions
        sudo apt remove -y docker docker-engine docker.io containerd runc || true
        
        # Install Docker's GPG key and repository
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg lsb-release
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker packages
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        log "INFO" "Installing Podman..."
        sudo apt install -y podman

        log "INFO" "Adding current user ($USER) to the 'docker' group..."
        sudo usermod -aG docker "$USER"
        
        log "WARNING" "In WSL, Docker daemon needs to be started manually or use Docker Desktop."
        log "WARNING" "To start Docker: sudo dockerd &"
        log "WARNING" "Or install Docker Desktop for Windows for seamless integration."
        
    else
        # Regular Linux installation
        log "INFO" "Installing Docker..."
        # Remove any old versions
        sudo apt remove -y docker docker-engine docker.io containerd runc || true
        
        # Install Docker's GPG key and repository
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg lsb-release
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker packages
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        log "INFO" "Starting and enabling Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker

        log "INFO" "Adding current user ($USER) to the 'docker' group..."
        sudo usermod -aG docker "$USER"

        log "INFO" "Installing Podman..."
        sudo apt install -y podman

        log "WARNING" "You must log out and log back in for the Docker group changes to take effect."
    fi

    log "SUCCESS" "Container tools installed successfully."
    next_step
}

# 13. Fonts Installation (FiraCode and JetBrains Mono Nerd Fonts)
install_fonts() {
    log "HEADER" "STEP 13/$TOTAL_STEPS: NERD FONTS INSTALLATION"

    local font_dir="$HOME/.local/share/fonts"
    log "INFO" "Creating fonts directory at $font_dir"
    mkdir -p "$font_dir"

    local tmp_dir
    tmp_dir=$(mktemp -d)

    log "INFO" "Installing FiraCode Nerd Font..."
    wget -q --show-progress -P "$tmp_dir" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip
    unzip -o "$tmp_dir/FiraCode.zip" -d "$font_dir"

    log "INFO" "Installing JetBrainsMono Nerd Font..."
    wget -q --show-progress -P "$tmp_dir" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip
    unzip -o "$tmp_dir/JetBrainsMono.zip" -d "$font_dir"

    log "INFO" "Cleaning up temporary files..."
    rm -rf "$tmp_dir"

    log "INFO" "Updating font cache..."
    fc-cache -fv

    log "SUCCESS" "FiraCode and JetBrainsMono Nerd Fonts installed."
    log "INFO" "You may need to set the font in your terminal emulator's settings."
    next_step
}

# 14. GitHub CLI Installation
install_github_cli() {
    log "HEADER" "STEP 14/$TOTAL_STEPS: GITHUB CLI INSTALLATION"

    if command_exists gh; then
        log "INFO" "GitHub CLI is already installed. Skipping."
    else
        log "INFO" "Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install -y gh
    fi

    log "SUCCESS" "GitHub CLI installed."
    next_step
}

# 15. Create Comprehensive Aliases File
create_aliases() {
    log "HEADER" "STEP 15/$TOTAL_STEPS: CREATING ALIASES FILE"

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
alias ls='eza --icons'
alias ll='eza -l --icons'
alias la='eza -la --icons'
alias llt='eza -l --icons --sort=modified'
alias tree='eza --tree'
alias cat='bat --paging=never --style=plain'
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
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install -y'
alias remove='sudo apt remove -y'
alias search='apt search'
alias autoremove='sudo apt autoremove -y'
alias autoclean='sudo apt autoclean'

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
alias py3='python3'
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

# System information
sysinfo() {
    echo "=== System Information ==="
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
}
EOF

    log "SUCCESS" "Comprehensive aliases file created at ~/.aliases."
    next_step
}

# 16. Finalize Installation
finalize_setup() {
    log "HEADER" "STEP 16/$TOTAL_STEPS: FINALIZING SETUP"

    # Configure git to use delta for diffs
    log "INFO" "Configuring git to use delta for diffs..."
    git config --global core.pager "delta"
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate "true"
    git config --global delta.side-by-side "true"
    git config --global delta.line-numbers "true"

    log "SUCCESS" "All installation and configuration steps are complete!"
    echo -e "\n${BOLD}${GREEN}🎉 Ubuntu Development Environment Setup is Finished! 🎉${NC}\n"

    log "INFO" "A detailed log of this session is available at: ${LOG_FILE}"

    echo -e "${YELLOW}${BOLD}IMPORTANT - PLEASE READ THE FOLLOWING:${NC}"
    echo -e "1. ${CYAN}A full system restart is recommended${NC} to ensure all changes, especially kernel modules and shell settings, are applied correctly."
    echo -e "2. ${CYAN}Log out and log back in${NC} to start using Zsh as your default shell and for Docker permissions to apply."
    echo -e "3. Open a new terminal and run ${WHITE}'source ~/.zshrc'${NC} to apply the new settings in your current session."
    echo -e "4. Authenticate with GitHub by running: ${WHITE}'gh auth login'${NC}"
    echo -e "5. Set your new Nerd Font in your terminal's settings (e.g., GNOME Terminal -> Preferences -> Profiles)."
    echo -e "6. Review the generated ${WHITE}~/.aliases${NC} file to familiarize yourself with the new shortcuts."

    next_step
}

# ============================================================================
# MAIN EXECUTION FLOW
# ============================================================================
main() {
    clear
    echo -e "${BOLD}${CYAN}Welcome to the Ubuntu 24.04 LTS Development Environment Setup Script!${NC}"
    echo -e "This script will install and configure a suite of modern development tools."
    echo -e "A log file will be created at: ${LOG_FILE}\n"

    if ! confirm "Do you want to begin the installation?" "y"; then
        echo "Installation aborted by user."
        exit 0
    fi

    create_backup_dir

    # --- Run Installation Steps ---
    check_requirements
    update_system
    install_nvidia_driver
    install_zsh_ohmyzsh
    install_starship
    install_python_tools
    install_rust
    install_golang
    install_cpp_tools
    install_modern_tools_apt
    install_modern_tools_cargo
    install_container_tools
    install_fonts
    install_github_cli
    create_aliases
    finalize_setup
}

# --- Start the Script ---
main "$@"
