#!/bin/bash

# ============================================================================
# macOS Development Environment Setup Script
# ============================================================================
#
# Description: Complete installation and configuration script for a modern
#              development environment on macOS.
#
# Author:      Gishant (Ported from Fedora Script)
# Version:     1.1
# Date:        July 2025
#
# Features:
# - Colorful verbose logging with progress indicators.
# - Interactive prompts for user choices.
# - Comprehensive error handling and dependency management.
# - Modular design with categorized installations.
# - Creates a backup of existing configuration files.
#
# Usage: ./setup-macos.sh
#
# Prerequisites:
# - A macOS environment.
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
TOTAL_STEPS=16
CURRENT_STEP=0
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOGS_DIR="${SCRIPT_DIR}/logs"
readonly LOG_FILE="${LOGS_DIR}/macos_setup_$(date +%Y%m%d_%H%M%S).log"
readonly BACKUP_DIR="${HOME}/.config_backup_$(date +%Y%m%d_%H%M%S)"

# Installation tracking
INSTALL_START_TIME=$(date +%s)
STEP_START_TIME=$(date +%s)
INSTALLED_TOOLS=()
SKIPPED_TOOLS=()
FAILED_TOOLS=()

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
        "INFO") echo -e "${BLUE}ℹ️  [INFO]${NC} $message" | tee -a "$LOG_FILE" ;;
        "SUCCESS") echo -e "${GREEN}✅ [SUCCESS]${NC} $message" | tee -a "$LOG_FILE" ;;
        "WARNING") echo -e "${YELLOW}⚠️  [WARNING]${NC} $message" | tee -a "$LOG_FILE" ;;
        "ERROR") echo -e "${RED}❌ [ERROR]${NC} $message" | tee -a "$LOG_FILE" ;;
        "PROGRESS") echo -e "${MAGENTA}🔄 [PROGRESS]${NC} $message" | tee -a "$LOG_FILE" ;;
        "INSTALL") echo -e "${CYAN}📦 [INSTALL]${NC} $message" | tee -a "$LOG_FILE" ;;
        "SKIP") echo -e "${YELLOW}⏭️  [SKIP]${NC} $message" | tee -a "$LOG_FILE" ;;
        "HEADER")
            clear
            echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║ 🚀 $message${NC}"
            echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}\n"
            echo "$timestamp: HEADER: $message" >> "$LOG_FILE"
            ;;
    esac
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

# Step progress function
next_step() {
    local step_end_time=$(date +%s)
    local step_duration=$((step_end_time - STEP_START_TIME))

    CURRENT_STEP=$((CURRENT_STEP + 1))

    if [[ $CURRENT_STEP -gt 1 ]]; then
        echo -e " ${GREEN}✓${NC} Step completed in $(format_time $step_duration)"
        if [[ $CURRENT_STEP -le $TOTAL_STEPS ]]; then
            echo -e "\n${CYAN}Moving to next step in 1 second...${NC}"
            sleep 1
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
    log "ERROR" "Command failed: '$command' (line $line_number, exit code: $exit_code)"
    echo -e "\n${RED}${BOLD}💥 An error occurred. The script cannot continue.${NC}"
    echo -e "${YELLOW}📋 Please check the log file for details: ${LOG_FILE}${NC}"
    exit $exit_code
}

trap 'handle_error $? "$BASH_COMMAND" $LINENO' ERR

# Interactive confirmation
confirm() {
    local message="$1"
    local default="${2:-n}"
    local prompt
    if [[ "$default" == "y" ]]; then prompt=" (Y/n): "; else prompt=" (y/N): "; fi
    while true; do
        read -rp "$(echo -e "${YELLOW}${message}${prompt}${NC}")" response
        response=${response:-$default}
        case "$response" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo -e "${RED}Please answer yes or no.${NC}" ;;
        esac
    done
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Backup a file if it exists
backup_file() {
    if [[ -f "$1" ]]; then
        log "INFO" "Backing up $1 to ${BACKUP_DIR}/"
        mkdir -p "$BACKUP_DIR"
        cp "$1" "${BACKUP_DIR}/"
    fi
}

# Track installed, skipped, or failed tools
track_installed() { INSTALLED_TOOLS+=("$1"); log "SUCCESS" "$1 has been installed."; }
track_skipped() { SKIPPED_TOOLS+=("$1"); log "SKIP" "$1 is already installed or handled."; }
track_failed() { FAILED_TOOLS+=("$1"); log "ERROR" "$1 installation failed."; }

# ============================================================================
# PRE-INSTALLATION CHECKS
# ============================================================================

check_requirements() {
    log "HEADER" "STEP 1/$TOTAL_STEPS: CHECKING SYSTEM REQUIREMENTS"
    
    # Check for macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log "ERROR" "This script is designed for macOS."
        exit 1
    fi
    log "SUCCESS" "macOS detected."

    # Check for Homebrew
    if ! command_exists brew; then
        log "ERROR" "Homebrew is not installed. Please install it from https://brew.sh"
        exit 1
    fi
    log "SUCCESS" "Homebrew is installed."

    # Check sudo privileges
    log "INFO" "Checking for sudo privileges..."
    if ! sudo -v; then
        log "ERROR" "Sudo privileges are required."
        exit 1
    fi
    log "SUCCESS" "Sudo privileges confirmed."

    # Check internet connection
    log "INFO" "Checking internet connection..."
    if ! ping -c 1 -W 3 google.com &>/dev/null; then
        log "ERROR" "No internet connection detected."
        exit 1
    fi
    log "SUCCESS" "Internet connection is active."
    
    next_step
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

# 2. System Update (Homebrew)
update_system() {
    log "HEADER" "STEP 2/$TOTAL_STEPS: SYSTEM UPDATE (HOMEBREW)"
    if confirm "Update Homebrew and upgrade existing packages?"; then
        log "PROGRESS" "Updating Homebrew..."
        brew update
        log "PROGRESS" "Upgrading installed packages..."
        brew upgrade
        track_installed "System Updates (Homebrew)"
    else
        track_skipped "System Updates (Homebrew)"
    fi
    next_step
}

# 3. Essential Packages
install_essential_packages() {
    log "HEADER" "STEP 3/$TOTAL_STEPS: ESSENTIAL PACKAGES"
    local essential_packages=(
        "curl" "wget" "git" "vim" "nano" "tree" "unzip" "zip" "gnupg"
    )
    local packages_to_install=()
    for pkg in "${essential_packages[@]}"; do
        if brew list "$pkg" &>/dev/null; then
            track_skipped "$pkg"
        else
            packages_to_install+=("$pkg")
        fi
    done

    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        log "PROGRESS" "Installing essential packages: ${packages_to_install[*]}"
        brew install "${packages_to_install[@]}"
        for pkg in "${packages_to_install[@]}"; do track_installed "$pkg"; done
    else
        log "SUCCESS" "All essential packages are already installed."
    fi
    next_step
}

# 4. ZSH, Oh My ZSH, and Plugins
install_zsh_ohmyzsh() {
    log "HEADER" "STEP 4/$TOTAL_STEPS: ZSH & OH MY ZSH"
    
    if ! brew list zsh &>/dev/null; then
        log "INFO" "Installing ZSH..."
        brew install zsh
    else
        log "INFO" "ZSH is already installed via Homebrew."
    fi

    if [[ "$SHELL" != "/bin/zsh" ]] && [[ "$SHELL" != "/usr/local/bin/zsh" ]]; then
        log "INFO" "Changing default shell to ZSH..."
        if sudo chsh -s "$(which zsh)" "$USER"; then
            log "SUCCESS" "Default shell changed. Please restart your terminal."
        else
            log "ERROR" "Failed to change shell."
        fi
    fi

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log "INFO" "Oh My Zsh is already installed."
    else
        log "INFO" "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    log "INFO" "Installing Oh My ZSH plugins..."
    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" || true
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" || true

    log "INFO" "Configuring .zshrc..."
    backup_file "$HOME/.zshrc"
    cat > "$HOME/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

# PATH configuration
export PATH="/usr/local/opt/openjdk/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then eval "$(pyenv init -)"; fi

# Starship Prompt
if command -v starship &>/dev/null; then eval "$(starship init zsh)"; fi

# Zoxide
if command -v zoxide &>/dev/null; then eval "$(zoxide init zsh)"; fi
EOF
    log "SUCCESS" "ZSH and Oh My ZSH configured."
    next_step
}

# 5. Starship Prompt
install_starship() {
    log "HEADER" "STEP 5/$TOTAL_STEPS: STARSHIP TERMINAL PROMPT"
    if ! command_exists starship; then
        log "INFO" "Installing Starship..."
        brew install starship
        track_installed "Starship"
    else
        track_skipped "Starship"
    fi

    log "INFO" "Creating Starship configuration..."
    mkdir -p "$HOME/.config"
    backup_file "$HOME/.config/starship.toml"
    curl -fsSL https://starship.rs/config-schema.json -o "$HOME/.config/starship.schema.json" # For editor autocompletion
    mkdir -p "$HOME/.config/starship"
    cat > "$HOME/.config/starship.toml" << 'EOF'
# Starship Prompt Configuration
add_newline = true

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"

[git_branch]
symbol = "🌱 "

[git_status]
disabled = false

[python]
symbol = "🐍 "
pyenv_version_name = true

[rust]
symbol = "🦀 "

[nodejs]
symbol = "⬢ "

[golang]
symbol = "🐹 "

[directory]
truncation_length = 3
truncate_to_repo = false

[cmd_duration]
min_time = 500
show_milliseconds = true
format = "took [$duration]($style)"

[hostname]
ssh_only = false
format = "[$hostname]($style) "

[username]
show_always = true
style_user = "bold yellow"
style_root = "bold red"

[package]
disabled = true
EOF
    log "SUCCESS" "Starship configured."
    next_step
}

# 6. Python Development (Pyenv, Poetry, uv)
install_python_tools() {
    log "HEADER" "STEP 6/$TOTAL_STEPS: PYTHON DEVELOPMENT TOOLS"
    brew install openssl readline sqlite3 xz zlib tcl-tk
    
    if ! command_exists pyenv; then
        log "INFO" "Installing pyenv..."
        brew install pyenv
        track_installed "pyenv"
    else
        track_skipped "pyenv"
    fi

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"

    local latest_python
    latest_python=$(pyenv install --list | grep -v - | grep -v b | grep -v rc | grep -E "^\s*3\.[0-9]+\.[0-9]+$" | tail -1 | xargs)
    if ! pyenv versions --bare | grep -q "^${latest_python}$"; then
        log "PROGRESS" "Installing Python ${latest_python} with pyenv..."
        pyenv install "$latest_python"
    fi
    pyenv global "$latest_python"
    track_installed "Python ${latest_python}"

    if ! command_exists poetry; then
        log "INFO" "Installing Poetry..."
        curl -sSL https://install.python-poetry.org | python3 -
        track_installed "Poetry"
    else
        track_skipped "Poetry"
    fi
    
    if ! command_exists uv; then
        log "INFO" "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        track_installed "uv"
    else
        track_skipped "uv"
    fi
    next_step
}

# 7. Rust Development
install_rust() {
    log "HEADER" "STEP 7/$TOTAL_STEPS: RUST DEVELOPMENT"
    if ! command_exists rustc; then
        log "INFO" "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        rustup component add rust-analyzer
        track_installed "Rust"
    else
        log "INFO" "Updating Rust..."
        rustup update
        track_skipped "Rust"
    fi
    next_step
}

# 8. Go Development
install_golang() {
    log "HEADER" "STEP 8/$TOTAL_STEPS: GO DEVELOPMENT"
    if ! command_exists go; then
        log "INFO" "Installing Go..."
        brew install go
        track_installed "Go"
    else
        track_skipped "Go"
    fi
    mkdir -p "$HOME/go"
    next_step
}

# 9. C++ Development
install_cpp_tools() {
    log "HEADER" "STEP 9/$TOTAL_STEPS: C++ DEVELOPMENT"
    if confirm "Install C++ tools (cmake, llvm)?"; then
        brew install cmake llvm
        track_installed "C++ Tools"
    else
        track_skipped "C++ Tools"
    fi
    next_step
}

# 10. Modern Tools (Brew)
install_modern_tools_brew() {
    log "HEADER" "STEP 10/$TOTAL_STEPS: MODERN TOOLS (BREW)"
    local tools=(
        atuin ripgrep bat fd duf jq fzf htop eza zoxide dust broot sd hexyl git-delta bottom procs gping hyperfine tealdeer
    )
    local tools_to_install=()
    for tool in "${tools[@]}"; do
        if ! command_exists "$tool" && ! brew list "$tool" &>/dev/null; then
            tools_to_install+=("$tool")
        else
            track_skipped "$tool"
        fi
    done
    if [[ ${#tools_to_install[@]} -gt 0 ]]; then
        log "PROGRESS" "Installing modern CLI tools: ${tools_to_install[*]}"
        brew install "${tools_to_install[@]}"
        for tool in "${tools_to_install[@]}"; do track_installed "$tool"; done
    else
        log "SUCCESS" "All modern CLI tools are already installed."
    fi
    next_step
}

# 11. Container Tools (Docker)
install_container_tools() {
    log "HEADER" "STEP 11/$TOTAL_STEPS: CONTAINER TOOLS (DOCKER)"
    if ! command_exists docker; then
        if confirm "Install Docker Desktop for Mac?"; then
            log "PROGRESS" "Installing Docker Desktop..."
            brew install --cask docker
            log "SUCCESS" "Docker Desktop installed. Please start it from your Applications folder."
            track_installed "Docker Desktop"
        else
            track_skipped "Docker Desktop"
        fi
    else
        track_skipped "Docker"
    fi
    next_step
}

# 12. Fonts (Nerd Fonts)
install_fonts() {
    log "HEADER" "STEP 12/$TOTAL_STEPS: NERD FONTS"
    if confirm "Install FiraCode and JetBrainsMono Nerd Fonts?"; then
        log "INFO" "Tapping the Nerd Fonts repository..."
        brew tap homebrew/cask-fonts
        log "PROGRESS" "Installing fonts..."
        brew install --cask font-firacode-nerd-font font-jetbrains-mono-nerd-font
        track_installed "Nerd Fonts"
    else
        track_skipped "Nerd Fonts"
    fi
    next_step
}

# 13. Development IDEs
install_development_ides() {
    log "HEADER" "STEP 13/$TOTAL_STEPS: DEVELOPMENT IDEs"
    if ! command_exists code; then
        if confirm "Install Visual Studio Code?"; then
            brew install --cask visual-studio-code
            track_installed "Visual Studio Code"
        else
            track_skipped "Visual Studio Code"
        fi
    else
        track_skipped "Visual Studio Code"
    fi
    next_step
}

# 14. GitHub CLI
install_github_cli() {
    log "HEADER" "STEP 14/$TOTAL_STEPS: GITHUB CLI"
    if ! command_exists gh; then
        brew install gh
        track_installed "GitHub CLI"
    else
        track_skipped "GitHub CLI"
    fi
    next_step
}

# 15. Aliases
create_aliases() {
    log "HEADER" "STEP 15/$TOTAL_STEPS: CREATING ALIASES"
    log "INFO" "Creating aliases file at ~/.aliases..."
    backup_file "$HOME/.aliases"
    # The aliases file from the Fedora script is largely cross-platform and can be reused here.
    # We will just ensure it's sourced correctly in .zshrc
    cp "${SCRIPT_DIR}/aliases.sh" "$HOME/.aliases" # Assumes aliases are in a separate file
    if ! grep -q "source ~/.aliases" "$HOME/.zshrc"; then
        echo "if [[ -f ~/.aliases ]]; then source ~/.aliases; fi" >> "$HOME/.zshrc"
    fi
    log "SUCCESS" "Aliases file created."
    next_step
}

# 16. Finalize Setup
finalize_setup() {
    log "HEADER" "STEP 16/$TOTAL_STEPS: FINALIZING SETUP"
    log "INFO" "Configuring git to use delta for diffs..."
    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
    track_installed "Git Delta Configuration"
    
    # Generate summary
    local total_time=$(($(date +%s) - INSTALL_START_TIME))
    clear
    echo -e "\n${BOLD}${CYAN}📊 INSTALLATION SUMMARY REPORT 📊${NC}\n"
    echo -e "${BOLD}${WHITE}⏱️  Total Time: ${GREEN}$(format_time $total_time)${NC}\n"
    
    if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${BOLD}${GREEN}✅ INSTALLED (${#INSTALLED_TOOLS[@]}):${NC}"
        printf " • %s\n" "${INSTALLED_TOOLS[@]}"
    fi
    
    if [[ ${#SKIPPED_TOOLS[@]} -gt 0 ]]; then
        echo -e "\n${BOLD}${YELLOW}⏭️  SKIPPED (${#SKIPPED_TOOLS[@]}):${NC}"
        printf " • %s\n" "${SKIPPED_TOOLS[@]}"
    fi

    echo -e "\n${BOLD}${GREEN}🎉 macOS Development Environment Setup is Finished! 🎉${NC}\n"
    echo -e "${CYAN}💡 Next Steps:${NC}"
    echo " • Restart your terminal to apply all changes."
    echo " • Run 'gh auth login' to authenticate with GitHub."
    echo " • Set your terminal font to a Nerd Font (e.g., FiraCode Nerd Font)."
    
    next_step
}

# ============================================================================
# MAIN EXECUTION FLOW
# ============================================================================
main() {
    clear
    echo -e "${BOLD}${CYAN}🚀 macOS DEVELOPMENT ENVIRONMENT SETUP 🚀${NC}\n"
    echo -e "${BOLD}${WHITE}This script will set up a complete development environment on your Mac.${NC}"
    
    mkdir -p "$LOGS_DIR"
    
    if ! confirm "Ready to begin the installation?" "y"; then
        echo -e "${RED}Installation aborted.${NC}"
        exit 0
    fi
    
    # --- Run Installation Steps ---
    check_requirements
    update_system
    install_essential_packages
    install_zsh_ohmyzsh
    install_starship
    install_python_tools
    install_rust
    install_golang
    install_cpp_tools
    install_modern_tools_brew
    install_container_tools
    install_fonts
    install_development_ides
    install_github_cli
    create_aliases
    finalize_setup
}

# --- Start the Script ---
main "$@"
